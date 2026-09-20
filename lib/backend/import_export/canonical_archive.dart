import 'dart:convert';

import '../storage/database.dart';
import '../storage/schema.dart';

/// Identifies a MISHIRUBE archive file.
const archiveFormat = 'mishirube-archive';

/// Version of the archive layout. It moves independently of the database
/// schema: internal tables can change while backups stay readable.
const archiveFormatVersion = 1;

/// Thrown when an archive cannot be restored; nothing has been changed.
class ArchiveFormatException implements Exception {
  const ArchiveFormatException(this.message);

  final String message;

  @override
  String toString() => 'ArchiveFormatException: $message';
}

enum _Kind { text, integer, real, boolean, time, json }

class _Column {
  const _Column(this.name, this.kind, {this.isNullable = false});

  final String name;
  final _Kind kind;
  final bool isNullable;

  /// The archive uses camelCase keys; the database snake_case columns.
  String get key => name.replaceAllMapped(
    RegExp('_([a-z0-9])'),
    (match) => match[1]!.toUpperCase(),
  );
}

class _Table {
  const _Table(this.key, this.name, this.columns, {required this.orderBy});

  final String key;
  final String name;
  final List<_Column> columns;
  final String orderBy;
}

const _entity = [
  _Column('created_at', _Kind.time),
  _Column('updated_at', _Kind.time),
  _Column('deleted_at', _Kind.time, isNullable: true),
  _Column('revision', _Kind.integer),
  _Column('source', _Kind.text),
  _Column('import_batch_id', _Kind.text, isNullable: true),
];

/// Every table in the archive, parents before children so a restore can
/// insert in this order and delete in reverse.
const _tables = [
  _Table('settings', 'settings', [
    _Column('key', _Kind.text),
    _Column('value', _Kind.text),
  ], orderBy: 'key'),
  _Table('importBatches', 'import_batches', [
    _Column('id', _Kind.text),
    _Column('source', _Kind.text),
    _Column('file_name', _Kind.text, isNullable: true),
    _Column('content_sha256', _Kind.text),
    _Column('imported_at', _Kind.time),
    _Column('undone_at', _Kind.time, isNullable: true),
    _Column('summary', _Kind.text, isNullable: true),
  ], orderBy: 'id'),
  _Table('exercises', 'exercises', [
    _Column('id', _Kind.text),
    _Column('name', _Kind.text),
    _Column('aliases', _Kind.json),
    _Column('personal_aliases', _Kind.json),
    _Column('equipment', _Kind.text),
    _Column('primary_muscles', _Kind.json),
    _Column('secondary_muscles', _Kind.json),
    _Column('pattern', _Kind.text),
    _Column('tracking_type', _Kind.text),
    _Column('ownership', _Kind.text),
    _Column('cues', _Kind.json),
    _Column('is_favorite', _Kind.boolean),
    _Column('is_hidden', _Kind.boolean),
    _Column('is_in_home_gym', _Kind.boolean),
    ..._entity,
  ], orderBy: 'id'),
  _Table('externalExerciseNames', 'external_exercise_names', [
    _Column('source', _Kind.text),
    _Column('name', _Kind.text),
    _Column('exercise_id', _Kind.text),
    _Column('import_batch_id', _Kind.text, isNullable: true),
  ], orderBy: 'source, name'),
  _Table('routines', 'routines', [
    _Column('id', _Kind.text),
    _Column('name', _Kind.text),
    _Column('program_name', _Kind.text),
    _Column('estimated_minutes', _Kind.integer),
    ..._entity,
  ], orderBy: 'id'),
  _Table('routineExercises', 'routine_exercises', [
    _Column('routine_id', _Kind.text),
    _Column('position', _Kind.integer),
    _Column('exercise_id', _Kind.text),
    _Column('sets', _Kind.integer),
    _Column('reps', _Kind.integer),
    _Column('rir', _Kind.integer, isNullable: true),
    _Column('target_weight_kg', _Kind.real),
    _Column('progression_label', _Kind.text),
    _Column('is_unilateral', _Kind.boolean),
  ], orderBy: 'routine_id, position'),
  _Table('workouts', 'workouts', [
    _Column('id', _Kind.text),
    _Column('routine_id', _Kind.text, isNullable: true),
    _Column('name', _Kind.text),
    _Column('status', _Kind.text),
    _Column('started_at', _Kind.time),
    _Column('finished_at', _Kind.time, isNullable: true),
    _Column('paused_at', _Kind.time, isNullable: true),
    _Column('paused_total_ms', _Kind.integer),
    _Column('current_exercise', _Kind.integer),
    _Column('notes', _Kind.text, isNullable: true),
    _Column('fingerprint', _Kind.text, isNullable: true),
    ..._entity,
  ], orderBy: 'id'),
  _Table('workoutExercises', 'workout_exercises', [
    _Column('workout_id', _Kind.text),
    _Column('position', _Kind.integer),
    _Column('exercise_id', _Kind.text),
    _Column('exercise_name', _Kind.text),
    _Column('is_pr_candidate', _Kind.boolean),
  ], orderBy: 'workout_id, position'),
  _Table('workoutSets', 'workout_sets', [
    _Column('workout_id', _Kind.text),
    _Column('exercise_position', _Kind.integer),
    _Column('position', _Kind.integer),
    _Column('set_type', _Kind.text),
    _Column('weight_kg', _Kind.real),
    _Column('reps', _Kind.integer),
    _Column('rir', _Kind.integer, isNullable: true),
    _Column('rpe', _Kind.real, isNullable: true),
    _Column('duration_s', _Kind.integer, isNullable: true),
    _Column('distance_m', _Kind.real, isNullable: true),
    _Column('previous_weight_kg', _Kind.real, isNullable: true),
    _Column('previous_reps', _Kind.integer, isNullable: true),
    _Column('is_done', _Kind.boolean),
  ], orderBy: 'workout_id, exercise_position, position'),
  _Table('meals', 'meals', [
    _Column('id', _Kind.text),
    _Column('name', _Kind.text),
    _Column('eaten_at', _Kind.time),
    _Column('kcal', _Kind.integer),
    _Column('protein_g', _Kind.integer),
    _Column('carb_g', _Kind.integer),
    _Column('fat_g', _Kind.integer),
    _Column('quality_tag', _Kind.text),
    _Column('is_estimated', _Kind.boolean),
    _Column('is_favorite', _Kind.boolean),
    ..._entity,
  ], orderBy: 'id'),
  _Table('mealDishes', 'meal_dishes', [
    _Column('meal_id', _Kind.text),
    _Column('position', _Kind.integer),
    _Column('name', _Kind.text),
    _Column('quantity_label', _Kind.text),
    _Column('subtitle', _Kind.text),
  ], orderBy: 'meal_id, position'),
  _Table('dishComponents', 'dish_components', [
    _Column('meal_id', _Kind.text),
    _Column('dish_position', _Kind.integer),
    _Column('position', _Kind.integer),
    _Column('name', _Kind.text),
    _Column('amount_label', _Kind.text),
    _Column('source_label', _Kind.text),
  ], orderBy: 'meal_id, dish_position, position'),
  _Table('bodyWeights', 'body_weights', [
    _Column('id', _Kind.text),
    _Column('measured_at', _Kind.time),
    _Column('weight_kg', _Kind.real),
    _Column('note', _Kind.text),
    ..._entity,
  ], orderBy: 'id'),
  _Table('activities', 'activities', [
    _Column('id', _Kind.text),
    _Column('type', _Kind.text),
    _Column('native_type', _Kind.text, isNullable: true),
    _Column('started_at', _Kind.time),
    _Column('ended_at', _Kind.time),
    _Column('elapsed_ms', _Kind.integer),
    _Column('distance_m', _Kind.real, isNullable: true),
    _Column('elevation_gain_m', _Kind.real, isNullable: true),
    _Column('effort', _Kind.integer, isNullable: true),
    _Column('note', _Kind.text),
    _Column('status', _Kind.text),
    _Column('paused_at', _Kind.time, isNullable: true),
    _Column('paused_ms', _Kind.integer),
    ..._entity,
  ], orderBy: 'id'),
  _Table('weeklyGoals', 'weekly_goals', [
    _Column('id', _Kind.text),
    _Column('effective_from', _Kind.time),
    _Column('target_days', _Kind.integer),
    ..._entity,
  ], orderBy: 'id'),
  _Table('goalPauses', 'goal_pauses', [
    _Column('id', _Kind.text),
    _Column('started_at', _Kind.time),
    _Column('ended_at', _Kind.time, isNullable: true),
    _Column('note', _Kind.text),
    ..._entity,
  ], orderBy: 'id'),
  _Table('sleepEntries', 'sleep_entries', [
    _Column('id', _Kind.text),
    _Column('slept_at', _Kind.time),
    _Column('duration_minutes', _Kind.integer),
    _Column('score', _Kind.integer, isNullable: true),
    _Column('note', _Kind.text),
    ..._entity,
  ], orderBy: 'id'),
  _Table('wellnessEntries', 'wellness_entries', [
    _Column('id', _Kind.text),
    _Column('recorded_at', _Kind.time),
    _Column('kind', _Kind.text),
    _Column('score', _Kind.integer),
    _Column('note', _Kind.text),
    ..._entity,
  ], orderBy: 'id'),
  _Table('auditEvents', 'audit_events', [
    _Column('id', _Kind.integer),
    _Column('occurred_at', _Kind.time),
    _Column('entity_type', _Kind.text),
    _Column('entity_id', _Kind.text),
    _Column('action', _Kind.text),
    _Column('source', _Kind.text),
    _Column('import_batch_id', _Kind.text, isNullable: true),
    _Column('payload', _Kind.json, isNullable: true),
  ], orderBy: 'id'),
];

/// Settings key holding archive sections this version does not know, so
/// they survive a restore and the next export.
const _extensionsKey = 'archive_extensions';

/// Exports the whole store – tombstones and audit trail included – as a
/// versioned JSON archive with deterministic ordering.
Map<String, Object?> exportArchive(AppDatabase db) {
  final data = <String, Object?>{
    for (final table in _tables)
      table.key: [
        for (final row in db.select(
          'SELECT * FROM ${table.name} ORDER BY ${table.orderBy}',
        ))
          if (!(table.name == 'settings' && row['key'] == _extensionsKey))
            {
              for (final column in table.columns)
                column.key: _toArchive(column, row[column.name]),
            },
      ],
  };
  final extensions = db.setting(_extensionsKey);
  return {
    'format': archiveFormat,
    'formatVersion': archiveFormatVersion,
    'exportedAt': db.now().toUtc().toIso8601String(),
    'schemaVersion': latestSchemaVersion,
    'data': data,
    'extensions': extensions == null
        ? <String, Object?>{}
        : jsonDecode(extensions),
  };
}

String encodeArchive(Map<String, Object?> archive) =>
    const JsonEncoder.withIndent('  ').convert(archive);

/// Replaces everything in [db] with [archive]. The archive is validated in
/// full first; on any problem it throws [ArchiveFormatException] and the
/// store is left untouched.
void restoreArchive(AppDatabase db, Object? archive) {
  if (archive is! Map<String, Object?>) {
    throw const ArchiveFormatException('封存檔不是 JSON 物件');
  }
  if (archive['format'] != archiveFormat) {
    throw const ArchiveFormatException('不是 MISHIRUBE 封存檔');
  }
  final version = archive['formatVersion'];
  if (version is! int || version < 1) {
    throw const ArchiveFormatException('封存檔版本無法辨識');
  }
  if (version > archiveFormatVersion) {
    throw ArchiveFormatException('封存檔版本 $version 比這個 App 新，請先更新');
  }
  final data = archive['data'];
  if (data is! Map<String, Object?>) {
    throw const ArchiveFormatException('封存檔缺少 data');
  }
  final extensions = archive['extensions'] ?? const <String, Object?>{};
  if (extensions is! Map<String, Object?>) {
    throw const ArchiveFormatException('extensions 必須是物件');
  }

  final rowsByTable = {
    for (final table in _tables)
      table: [
        for (final (index, record) in _records(data, table.key).indexed)
          _rowFrom(table, record, index),
      ],
  };

  db.transaction(() {
    for (final table in _tables.reversed) {
      db.execute('DELETE FROM ${table.name}');
    }
    for (final MapEntry(key: table, value: rows) in rowsByTable.entries) {
      final names = table.columns.map((column) => column.name).join(', ');
      final placeholders = List.filled(table.columns.length, '?').join(', ');
      for (final row in rows) {
        db.execute(
          'INSERT INTO ${table.name} ($names) VALUES ($placeholders)',
          row,
        );
      }
    }
    if (extensions.isNotEmpty) {
      db.execute('INSERT INTO settings (key, value) VALUES (?, ?)', [
        _extensionsKey,
        jsonEncode(extensions),
      ]);
    }
  });
}

List<Object?> _records(Map<String, Object?> data, String key) {
  final records = data[key] ?? const [];
  if (records is! List) throw ArchiveFormatException('$key 必須是陣列');
  return records;
}

List<Object?> _rowFrom(_Table table, Object? record, int index) {
  if (record is! Map<String, Object?>) {
    throw ArchiveFormatException('${table.key}[$index] 必須是物件');
  }
  return [
    for (final column in table.columns)
      _fromArchive(column, record[column.key], '${table.key}[$index]'),
  ];
}

Object? _toArchive(_Column column, Object? value) {
  if (value == null) return null;
  return switch (column.kind) {
    _Kind.text || _Kind.integer => value,
    _Kind.real => (value as num).toDouble(),
    _Kind.boolean => value == 1,
    _Kind.time => DateTime.fromMillisecondsSinceEpoch(
      value as int,
      isUtc: true,
    ).toIso8601String(),
    _Kind.json => jsonDecode(value as String),
  };
}

Object? _fromArchive(_Column column, Object? value, String where) {
  if (value == null) {
    if (column.isNullable) return null;
    throw ArchiveFormatException('$where.${column.key} 不可為空');
  }
  Never invalid() => throw ArchiveFormatException('$where.${column.key} 格式錯誤');
  return switch (column.kind) {
    _Kind.text => value is String ? value : invalid(),
    _Kind.integer => value is int ? value : invalid(),
    _Kind.real => value is num ? value.toDouble() : invalid(),
    _Kind.boolean => value is bool ? (value ? 1 : 0) : invalid(),
    _Kind.time =>
      value is String
          ? (DateTime.tryParse(value) ?? invalid()).millisecondsSinceEpoch
          : invalid(),
    _Kind.json => value is List || value is Map ? jsonEncode(value) : invalid(),
  };
}
