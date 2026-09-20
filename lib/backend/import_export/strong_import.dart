import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/domain.dart';
import '../backend.dart';
import '../storage/database.dart';
import 'csv.dart';

/// Source name for Strong in import batches and exercise name mappings.
const strongSource = 'strong';

const _kilogramsPerPound = 0.45359237;

/// Strong publishes no CSV schema. Two layouts are known: the current one
/// (6.2.3+, `;`-separated, kilograms and seconds in the headers) and the
/// older one (`,`-separated, bare `Weight` and `45m`-style durations).
enum StrongDialect { current, legacy }

enum WeightUnit { kg, lb }

/// Thrown when a file is not a Strong export at all.
class StrongFormatException implements Exception {
  const StrongFormatException(this.message);

  final String message;

  @override
  String toString() => 'StrongFormatException: $message';
}

/// A row the import could not take as is. [isSkipped] rows are left out;
/// the others are imported with the noted change.
class StrongIssue {
  const StrongIssue(this.row, this.message, {this.isSkipped = true});

  /// 1-based data row, header excluded.
  final int row;
  final String message;
  final bool isSkipped;
}

enum ExerciseMatchKind {
  /// Mapped by an earlier import.
  remembered,

  /// Same name or alias as a catalog exercise.
  matched,

  /// No catalog exercise fits; an imported exercise will be created.
  created,
}

class StrongExerciseMatch {
  const StrongExerciseMatch(this.strongName, this.kind, this.exercise);

  final String strongName;
  final ExerciseMatchKind kind;

  /// For [ExerciseMatchKind.created], the definition to be created.
  final ExerciseDefinition exercise;
}

class _PlannedWorkout {
  _PlannedWorkout(this.name, this.startedAt, this.fingerprint);

  final String name;
  final DateTime startedAt;
  final String fingerprint;
  Duration? duration;
  final notes = <String>[];
  final setsByExercise = <String, List<WorkoutSet>>{};
  bool isDuplicate = false;

  int get setCount =>
      setsByExercise.values.fold(0, (sum, sets) => sum + sets.length);
}

/// What an import would do, computed without writing anything.
class StrongImportPlan {
  StrongImportPlan._({
    required this.fileName,
    required this.contentSha256,
    required this.dialect,
    required this.rowsRead,
    required this.restTimerRows,
    required this.issues,
    required this.exercises,
    required this.isAlreadyImported,
    required this._workouts,
  });

  final String fileName;
  final String contentSha256;
  final StrongDialect dialect;

  /// Data rows in the file, header excluded.
  final int rowsRead;

  /// Strong's rest-timer rows; they carry no set and are ignored.
  final int restTimerRows;
  final List<StrongIssue> issues;

  /// Keyed by the exercise name used in Strong.
  final Map<String, StrongExerciseMatch> exercises;

  /// The same file was imported before and not undone.
  final bool isAlreadyImported;
  final List<_PlannedWorkout> _workouts;

  Iterable<_PlannedWorkout> get _new => _workouts.where((w) => !w.isDuplicate);

  /// Workouts that would be created; already-imported ones are skipped.
  int get newWorkouts => _new.length;
  int get duplicateWorkouts => _workouts.length - newWorkouts;
  int get newSets => _new.fold(0, (sum, w) => sum + w.setCount);

  int setsOfType(SetType type) => _new.fold(
    0,
    (sum, w) =>
        sum +
        w.setsByExercise.values
            .expand((sets) => sets)
            .where((set) => set.type == type)
            .length,
  );

  Iterable<StrongExerciseMatch> get createdExercises =>
      exercises.values.where((m) => m.kind == ExerciseMatchKind.created);
}

class StrongImportResult {
  const StrongImportResult({
    required this.batchId,
    required this.workouts,
    required this.sets,
    required this.exercisesCreated,
  });

  final String batchId;
  final int workouts;
  final int sets;
  final int exercisesCreated;
}

/// Imports a Strong CSV export: [dryRun] reports, [commit] writes it all in
/// one transaction as an import batch, and [undo] tombstones that batch.
///
/// Imports are idempotent: the same file is refused, and workouts already
/// imported from an overlapping export are skipped, identified by their
/// start time and name since Strong rows carry no ids.
class StrongImporter {
  StrongImporter(this._backend);

  final Backend _backend;

  AppDatabase get _db => _backend.db;

  StrongImportPlan dryRun(
    String content, {
    required String fileName,
    WeightUnit legacyWeightUnit = WeightUnit.kg,
  }) {
    final sha256Hex = sha256.convert(utf8.encode(content)).toString();
    final firstLine = content.split('\n').first;
    final delimiter =
        ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length
        ? ';'
        : ',';
    final List<List<String>> rows;
    try {
      rows = parseCsv(content, delimiter: delimiter);
    } on FormatException {
      throw const StrongFormatException('CSV 格式損毀');
    }
    if (rows.isEmpty) throw const StrongFormatException('檔案是空的');
    final header = [for (final name in rows.first) name.trim()];
    final column = {for (final (i, name) in header.indexed) name: i};
    final dialect = column.containsKey('Weight (kg)')
        ? StrongDialect.current
        : StrongDialect.legacy;
    final weightColumn = dialect == StrongDialect.current
        ? 'Weight (kg)'
        : 'Weight';
    final required = [
      'Date',
      'Workout Name',
      'Exercise Name',
      'Set Order',
      weightColumn,
      'Reps',
    ];
    final missing = required.where((name) => !column.containsKey(name));
    if (missing.isNotEmpty) {
      throw StrongFormatException('不是可辨識的 Strong 匯出檔（缺少 ${missing.join('、')}）');
    }

    final issues = <StrongIssue>[];
    final workouts = <String, _PlannedWorkout>{};
    final exerciseNames = <String>{};
    final trackingSeen = <String, Set<TrackingType>>{};
    var restTimerRows = 0;

    for (final (index, fields) in rows.skip(1).indexed) {
      final row = index + 1;
      if (fields.every((field) => field.trim().isEmpty)) continue;
      String? field(String name) {
        final i = column[name];
        if (i == null || i >= fields.length) return null;
        final value = fields[i].trim();
        return value.isEmpty ? null : value;
      }

      final setOrder = field('Set Order') ?? '';
      if (setOrder == 'Rest Timer') {
        restTimerRows++;
        continue;
      }
      final type = switch (setOrder) {
        'W' => SetType.warmup,
        'D' => SetType.drop,
        'F' => SetType.failure,
        _ when int.tryParse(setOrder) != null => SetType.working,
        _ => null,
      };
      if (type == null) {
        issues.add(StrongIssue(row, '無法辨識的組別「$setOrder」'));
        continue;
      }
      final startedAt = _parseDate(field('Date'));
      if (startedAt == null) {
        issues.add(StrongIssue(row, '日期格式無法解析「${field('Date') ?? ''}」'));
        continue;
      }
      final exerciseName = field('Exercise Name');
      final workoutName = field('Workout Name') ?? 'Strong 訓練';
      if (exerciseName == null) {
        issues.add(StrongIssue(row, '缺少動作名稱'));
        continue;
      }

      var weight = double.tryParse(field(weightColumn) ?? '0');
      final reps = double.tryParse(field('Reps') ?? '0')?.round();
      if (weight == null || reps == null || weight < 0 || reps < 0) {
        issues.add(StrongIssue(row, '重量或次數不是數字'));
        continue;
      }
      final rowUnit = switch (field('Weight Unit')?.toLowerCase()) {
        'lbs' || 'lb' => WeightUnit.lb,
        'kg' || 'kgs' => WeightUnit.kg,
        _ =>
          dialect == StrongDialect.current ? WeightUnit.kg : legacyWeightUnit,
      };
      if (rowUnit == WeightUnit.lb) {
        weight = double.parse((weight * _kilogramsPerPound).toStringAsFixed(2));
        issues.add(StrongIssue(row, '單位是磅，已換算成公斤', isSkipped: false));
      }
      final rpe = double.tryParse(field('RPE') ?? '');
      if (rpe != null && (rpe < 1 || rpe > 10)) {
        issues.add(
          StrongIssue(row, 'RPE「$rpe」超出 1–10，已略過該值', isSkipped: false),
        );
      }
      final seconds = double.tryParse(field('Seconds') ?? '')?.round();
      final distance = double.tryParse(
        field(
              dialect == StrongDialect.current
                  ? 'Distance (meters)'
                  : 'Distance',
            ) ??
            '',
      );

      final key = dialect == StrongDialect.current && field('Workout #') != null
          ? 'n${field('Workout #')}'
          : '${startedAt.toIso8601String()}|$workoutName';
      final workout = workouts.putIfAbsent(
        key,
        () => _PlannedWorkout(
          workoutName,
          startedAt,
          sha256
              .convert(
                utf8.encode(
                  '$strongSource|${startedAt.toIso8601String()}|$workoutName',
                ),
              )
              .toString(),
        ),
      );
      workout.duration ??= _parseDuration(
        dialect == StrongDialect.current
            ? field('Duration (sec)')
            : field('Duration'),
      );
      if (field('Workout Notes') case final notes?
          when !workout.notes.contains(notes)) {
        workout.notes.add(notes);
      }
      if (field('Notes') case final notes?) {
        final line = '$exerciseName：$notes';
        if (!workout.notes.contains(line)) workout.notes.add(line);
      }
      exerciseNames.add(exerciseName);
      (trackingSeen[exerciseName] ??= {}).add(switch ((
        weight,
        reps,
        seconds,
        distance,
      )) {
        (_, _, _, final d?) when d > 0 => TrackingType.distance,
        (0, 0, final s?, _) when s > 0 => TrackingType.duration,
        (0, _, _, _) => TrackingType.reps,
        _ => TrackingType.weightReps,
      });
      (workout.setsByExercise[exerciseName] ??= []).add(
        WorkoutSet(
          weightKg: weight,
          reps: reps,
          previousWeightKg: weight,
          previousReps: reps,
          rpe: rpe != null && rpe >= 1 && rpe <= 10 ? rpe : null,
          type: type,
          durationSeconds: seconds == null || seconds == 0 ? null : seconds,
          distanceMeters: distance == null || distance == 0 ? null : distance,
          isDone: true,
        ),
      );
    }

    for (final workout in workouts.values) {
      if (workout.duration == null) {
        issues.add(
          StrongIssue(
            0,
            '「${workout.name}」（${_dateLabel(workout.startedAt)}）沒有訓練時長',
            isSkipped: false,
          ),
        );
      }
      workout.isDuplicate = _backend.storage.workouts.hasFingerprint(
        workout.fingerprint,
      );
    }

    final catalog = _backend.storage.exercises.all();
    return StrongImportPlan._(
      fileName: fileName,
      contentSha256: sha256Hex,
      dialect: dialect,
      rowsRead: rows.length - 1,
      restTimerRows: restTimerRows,
      issues: issues,
      isAlreadyImported: _db.select(
        'SELECT 1 FROM import_batches WHERE content_sha256 = ? '
        'AND undone_at IS NULL',
        [sha256Hex],
      ).isNotEmpty,
      exercises: {
        for (final name in exerciseNames)
          name: _match(name, catalog, trackingSeen[name]!),
      },
      workouts: [...workouts.values]
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
    );
  }

  StrongExerciseMatch _match(
    String strongName,
    List<ExerciseDefinition> catalog,
    Set<TrackingType> tracking,
  ) {
    final byId = {for (final e in catalog) e.id: e};
    if (_backend.storage.exercises.mappedId(strongSource, strongName)
        case final id? when byId.containsKey(id)) {
      return StrongExerciseMatch(
        strongName,
        ExerciseMatchKind.remembered,
        byId[id]!,
      );
    }
    final (baseName, equipment) = _splitEquipment(strongName);
    final wanted = _normalize(strongName);
    final wantedBase = _normalize(baseName);
    for (final exercise in catalog) {
      final names = [exercise.name, ...exercise.aliases].map(_normalize);
      final isExact = names.contains(wanted);
      final isBaseWithEquipment =
          equipment != null &&
          exercise.equipment == equipment &&
          names.contains(wantedBase);
      if (isExact || isBaseWithEquipment) {
        return StrongExerciseMatch(
          strongName,
          ExerciseMatchKind.matched,
          exercise,
        );
      }
    }
    return StrongExerciseMatch(
      strongName,
      ExerciseMatchKind.created,
      ExerciseDefinition(
        id: 'strong-${sha256.convert(utf8.encode(strongName)).toString().substring(0, 16)}',
        name: strongName,
        equipment: equipment ?? Equipment.bodyweight,
        primaryMuscles: const [],
        pattern: MovementPattern.isolation,
        // Mixed tracking falls back to weight and reps, which holds all.
        trackingType: tracking.length == 1
            ? tracking.single
            : TrackingType.weightReps,
        source: ExerciseSource.imported,
      ),
    );
  }

  /// Writes [plan] as one import batch. Refuses a file that is already
  /// imported; skips workouts an earlier import already brought in.
  StrongImportResult commit(StrongImportPlan plan) {
    if (plan.isAlreadyImported) {
      throw StateError('This file was already imported.');
    }
    return _db.transaction(() {
      final batchId = _db.newId();
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO import_batches (id, source, file_name, content_sha256, '
        'imported_at, summary) VALUES (?, ?, ?, ?, ?, ?)',
        [
          batchId,
          strongSource,
          plan.fileName,
          plan.contentSha256,
          now,
          jsonEncode({
            'workouts': plan.newWorkouts,
            'sets': plan.newSets,
            'skippedRows': plan.issues.where((i) => i.isSkipped).length,
          }),
        ],
      );

      var created = 0;
      final idByName = <String, String>{};
      for (final match in plan.exercises.values) {
        final exercise = match.exercise;
        if (match.kind == ExerciseMatchKind.created) {
          if (_backend.storage.exercises.byId(exercise.id) == null) {
            _backend.storage.exercises.save(
              exercise,
              source: ChangeSource.strongImport,
              importBatchId: batchId,
            );
            created++;
          } else {
            // Created by an import that was undone: bring it back under
            // this batch. A live one is simply reused.
            _db.execute(
              'UPDATE exercises SET deleted_at = NULL, import_batch_id = ?, '
              'updated_at = ?, revision = revision + 1 '
              'WHERE id = ? AND deleted_at IS NOT NULL',
              [batchId, now, exercise.id],
            );
          }
        }
        idByName[match.strongName] = exercise.id;
        if (match.kind != ExerciseMatchKind.remembered) {
          _backend.storage.exercises.mapExternalName(
            strongSource,
            match.strongName,
            exercise.id,
            importBatchId: batchId,
          );
        }
      }

      final exercises = {
        for (final MapEntry(key: name, value: id) in idByName.entries)
          name: _backend.storage.exercises.byId(id)!,
      };
      for (final planned in plan._new) {
        final workout =
            WorkoutSession(
                id: _db.newId(),
                routineName: planned.name,
                startedAt: planned.startedAt,
                notes: planned.notes.isEmpty ? null : planned.notes.join('\n'),
                exercises: [
                  for (final MapEntry(key: name, value: sets)
                      in planned.setsByExercise.entries)
                    ExerciseSession(exercise: exercises[name]!, sets: sets),
                ],
              )
              ..finishedAt = planned.startedAt.add(
                planned.duration ?? Duration.zero,
              )
              ..currentExerciseIndex = planned.setsByExercise.length - 1;
        _backend.storage.workouts.save(
          workout,
          action: 'import',
          source: ChangeSource.strongImport,
          importBatchId: batchId,
          fingerprint: planned.fingerprint,
        );
      }
      _db.audit(
        entityType: 'import_batch',
        entityId: batchId,
        action: 'import',
        source: ChangeSource.strongImport,
        importBatchId: batchId,
      );
      return StrongImportResult(
        batchId: batchId,
        workouts: plan.newWorkouts,
        sets: plan.newSets,
        exercisesCreated: created,
      );
    });
  }

  /// Takes back everything [batchId] brought in. Nothing is hard deleted:
  /// rows are tombstoned and the batch is marked undone, so the same file
  /// can be imported again.
  void undo(String batchId) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      for (final table in ['workouts', 'exercises']) {
        _db.execute(
          'UPDATE $table SET deleted_at = ?, updated_at = ?, '
          'revision = revision + 1 '
          'WHERE import_batch_id = ? AND deleted_at IS NULL',
          [now, now, batchId],
        );
      }
      _db.execute(
        'DELETE FROM external_exercise_names WHERE import_batch_id = ?',
        [batchId],
      );
      _db.execute('UPDATE import_batches SET undone_at = ? WHERE id = ?', [
        now,
        batchId,
      ]);
      _db.audit(
        entityType: 'import_batch',
        entityId: batchId,
        action: 'undo',
        source: ChangeSource.strongImport,
        importBatchId: batchId,
      );
    });
  }
}

const _equipmentNames = {
  'barbell': Equipment.barbell,
  'dumbbell': Equipment.dumbbell,
  'cable': Equipment.cable,
  'machine': Equipment.machine,
  'kettlebell': Equipment.kettlebell,
  'bodyweight': Equipment.bodyweight,
  'smith machine': Equipment.smithMachine,
};

/// Strong names equipment in parentheses: `Bench Press (Barbell)`.
(String, Equipment?) _splitEquipment(String name) {
  final match = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*$').firstMatch(name);
  if (match == null) return (name, null);
  return (match[1]!, _equipmentNames[match[2]!.toLowerCase()]);
}

String _normalize(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), ' ').trim();

/// Strong writes local times as `yyyy-MM-dd HH:mm:ss`; ISO 8601 is also
/// accepted. Anything else is rejected rather than guessed.
DateTime? _parseDate(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$',
  ).firstMatch(value);
  if (match == null) return DateTime.tryParse(value)?.toLocal();
  final [year, month, day, hour, minute] = [
    for (var i = 1; i <= 5; i++) int.parse(match[i]!),
  ];
  return DateTime(year, month, day, hour, minute, int.parse(match[6] ?? '0'));
}

/// Seconds (`3480`) or Strong's older `1h 5m` / `45m` / `30s` style.
Duration? _parseDuration(String? value) {
  if (value == null) return null;
  if (double.tryParse(value) case final seconds?) {
    return Duration(seconds: seconds.round());
  }
  final parts = RegExp(r'(\d+)\s*([hms])').allMatches(value).toList();
  if (parts.isEmpty) return null;
  var total = Duration.zero;
  for (final part in parts) {
    final amount = int.parse(part[1]!);
    total += switch (part[2]) {
      'h' => Duration(hours: amount),
      'm' => Duration(minutes: amount),
      _ => Duration(seconds: amount),
    };
  }
  return total;
}

String _dateLabel(DateTime time) => '${time.month}/${time.day}';
