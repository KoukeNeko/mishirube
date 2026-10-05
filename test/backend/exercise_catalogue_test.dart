import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/exercise_search.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/backend/seed/exercise_catalogue.dart';
import 'package:mishirube/backend/seed/seed.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';

import '../support/harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final shipped = parseExerciseCatalogue(
    jsonDecode(File(exerciseCatalogueFile).readAsStringSync())
        as Map<String, dynamic>,
  );

  String normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');

  test('the library is whole: names, muscles, frames and unique ids', () {
    expect(shipped.length, greaterThan(250));
    expect({for (final e in shipped) e.id}, hasLength(shipped.length));
    final idShape = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
    for (final exercise in shipped) {
      expect(exercise.id, matches(idShape));
      expect(
        exercise.id,
        isNot(matches(RegExp('^(custom|strong|seed)-'))),
        reason: 'those belong to what the user made or imported',
      );
      expect(exercise.name, isNotEmpty);
      expect(exercise.primaryMuscles, isNotEmpty, reason: exercise.id);
      expect(
        exercise.primaryMuscles.length,
        lessThanOrEqualTo(2),
        reason: exercise.id,
      );
      expect(exercise.secondaryMuscles.length, lessThanOrEqualTo(4));
      expect(
        exercise.primaryMuscles.toSet().intersection(
          exercise.secondaryMuscles.toSet(),
        ),
        isEmpty,
        reason: '${exercise.id} lists a muscle as both',
      );
      expect(
        [
          ...exercise.primaryMuscles,
          ...exercise.secondaryMuscles,
        ].where((m) => m.isGeneral),
        isEmpty,
        reason: '${exercise.id} names a muscle, not a whole region',
      );
      expect(exercise.family, matches(idShape), reason: exercise.id);
    }
  });

  test('names are the way they are said, and each says one exercise', () {
    final byName = <String, String>{};
    final byAlias = <String, List<ExerciseDefinition>>{};
    for (final exercise in shipped) {
      final name = normalized(exercise.name);
      expect(
        byName.putIfAbsent(name, () => exercise.id),
        exercise.id,
        reason: 'two exercises are named ${exercise.name}',
      );
      final own = <String>{name};
      for (final alias in exercise.aliases) {
        final key = normalized(alias);
        expect(key.length, greaterThan(1), reason: '${exercise.id}: $alias');
        expect(
          own.add(key),
          isTrue,
          reason: '${exercise.id} names itself $alias twice',
        );
        byAlias.putIfAbsent(key, () => []).add(exercise);
      }
      expect(exercise.aliases, isNotEmpty, reason: exercise.id);
      expect(
        exercise.aliases.first,
        matches(RegExp(r"^[A-Za-z0-9 \-'/()&.,+°]+$")),
        reason: '${exercise.id}: the English name comes first',
      );
      expect(
        '${exercise.name}${exercise.aliases}${exercise.cues}',
        isNot(contains('你')),
      );
      expect(
        '${exercise.name}${exercise.aliases}${exercise.cues}',
        isNot(contains('還沒')),
      );
      // The words Taiwan uses (research 93): 弓箭步 not 弓步, 抬腿 for a
      // hanging leg raise, 瑜伽球 for the stability ball.
      expect(
        exercise.name,
        isNot(matches(RegExp('(?<!箭)弓步|健身球|穩定球|懸垂.*舉腿'))),
        reason: '${exercise.id}: ${exercise.name}',
      );
    }
    // A name another exercise already has belongs to that exercise, and an
    // alias belongs to one exercise: typing it, or importing it, finds
    // one thing. The exception is a part of the body people name an
    // exercise by.
    const sharedByBodyPart = {'上胸', '下胸', '二頭', '三頭', '後三角', '側三角'};
    for (final MapEntry(key: alias, value: owners) in byAlias.entries) {
      final named = byName[alias];
      if (named != null) {
        expect(
          owners.map((e) => e.id).toSet().difference({named}),
          isEmpty,
          reason: '$alias is the name of $named, and an alias of another',
        );
      }
      if (sharedByBodyPart.contains(alias)) continue;
      expect(
        owners.map((e) => e.id).toList(),
        hasLength(1),
        reason: '$alias names more than one exercise',
      );
    }
  });

  test('pictures are three poses of its own or of the exercise it is a '
      'version of', () {
    final byId = {for (final e in shipped) e.id: e};
    for (final exercise in shipped) {
      expect(
        exercise.frames.length,
        anyOf(0, 3),
        reason: '${exercise.id} has ${exercise.frames.length} poses',
      );
      for (final frame in exercise.frames) {
        expect(File(frame).existsSync(), isTrue, reason: frame);
      }
      final owner = exercise.demoFromId;
      if (owner == null) continue;
      expect(byId[owner], isNotNull, reason: '${exercise.id} shows $owner');
      expect(
        byId[owner]!.demoFromId,
        isNull,
        reason: '${exercise.id} shows the poses of $owner, which are not its',
      );
      expect(
        exercise.frames,
        byId[owner]!.frames,
        reason: '${exercise.id} shows part of $owner',
      );
    }
  });

  test('how an exercise is recorded fits what it is', () {
    for (final exercise in shipped) {
      if (exercise.pattern == MovementPattern.stretch) {
        expect(
          exercise.trackingType,
          TrackingType.duration,
          reason: exercise.id,
        );
      }
      if (exercise.equipment == Equipment.cardio) {
        expect(
          exercise.trackingType,
          anyOf(TrackingType.duration, TrackingType.distance),
          reason: '${exercise.id}: a machine is timed or measured',
        );
      }
      expect(exercise.cues.length, lessThanOrEqualTo(3), reason: exercise.id);
      for (final cue in exercise.cues) {
        expect(cue.trim(), isNotEmpty);
        expect(
          cue.length,
          lessThanOrEqualTo(24),
          reason: '${exercise.id}: $cue',
        );
      }
    }
  });

  test('an exercise that shipped is still in the library', () {
    // The ids a release shipped are only ever added to: a workout, a
    // routine and a record point at them. A deliberate retirement is a
    // merge, written in the loader, and is removed from the file here.
    final golden = File('test/golden/exercise_ids.txt');
    final ids = {for (final e in shipped) e.id};
    if (!golden.existsSync()) {
      golden
        ..createSync(recursive: true)
        ..writeAsStringSync('${(ids.toList()..sort()).join('\n')}\n');
      fail('Wrote a new golden file: check ${golden.path} into git.');
    }
    final shippedBefore = golden.readAsLinesSync().where((id) => id.isNotEmpty);
    expect(
      shippedBefore.where((id) => !ids.contains(id)),
      isEmpty,
      reason: 'ids that shipped went missing',
    );
  });

  test('every exercise the app shipped before keeps its id', () {
    final ids = {for (final e in shipped) e.id};
    for (final demo in DemoExercises.catalog) {
      if (demo.source != ExerciseSource.builtIn) continue;
      expect(ids, contains(demo.id), reason: demo.name);
    }
  });

  test('loading keeps what the user made of an exercise, once', () async {
    final backend = Backend.inMemory(clock: FakeClock().now);
    addTearDown(backend.close);
    seedDemoData(backend, FakeClock().now());
    final exercises = backend.storage.exercises;
    exercises.setHidden('front-squat', isHidden: true);
    exercises.setPersonalAliases('back-squat', ['背蹲']);

    await loadExerciseCatalogue(backend.db, exercises);

    final squat = exercises.byId('back-squat')!;
    expect(squat.frames, hasLength(3), reason: 'the library took it over');
    expect(squat.personalAliases, ['背蹲']);
    expect(squat.isFavorite, isTrue, reason: 'the demo starred it');
    expect(exercises.byId('front-squat')!.isHidden, isTrue);
    expect(exercises.byId('cable-woodchop'), isNotNull);

    // A second launch with the same file reads nothing.
    final revision = backend.db
        .select("SELECT revision FROM exercises WHERE id = 'back-squat'")
        .single['revision'];
    await loadExerciseCatalogue(backend.db, exercises);
    expect(
      backend.db
          .select("SELECT revision FROM exercises WHERE id = 'back-squat'")
          .single['revision'],
      revision,
    );

    // The library's exercises are not demo data the demo switch hides.
    backend.provenance.setShowsDemo(false);
    expect(exercises.byId('back-squat'), isNotNull);
    expect(
      backend.db
          .select("SELECT source FROM exercises WHERE id = 'back-squat'")
          .single['source'],
      ChangeSource.catalogue.name,
    );
  });

  test('an update to the library leaves the exercises it did not change '
      'alone', () async {
    final backend = Backend.inMemory(clock: FakeClock().now);
    addTearDown(backend.close);
    seedDemoData(backend, FakeClock().now());
    final exercises = backend.storage.exercises;
    await loadExerciseCatalogue(backend.db, exercises);
    int count(String sql) => backend.db.select(sql).single['n'] as int;
    final audited = count(
      "SELECT COUNT(*) AS n FROM audit_events WHERE entity_type = 'exercise'",
    );
    final revision = count('SELECT SUM(revision) AS n FROM exercises');

    // The next launch finds a library it has not loaded (any other file
    // reads that way) whose exercises are all as they are stored.
    backend.db.setSetting('exercises.catalogue', 'an earlier version');
    await loadExerciseCatalogue(backend.db, exercises);

    expect(
      count(
        "SELECT COUNT(*) AS n FROM audit_events WHERE entity_type = 'exercise'",
      ),
      audited,
      reason: 'nothing was written for an exercise that did not change',
    );
    expect(count('SELECT SUM(revision) AS n FROM exercises'), revision);
  });

  test('the library holds are recorded by time', () {
    final byId = {for (final e in shipped) e.id: e};
    for (final id in [
      'plank',
      'side-plank',
      'wall-sit',
      'hollow-body-hold',
      'dead-hang',
      'l-sit-hold',
    ]) {
      expect(byId[id]!.trackingType, TrackingType.duration, reason: id);
    }
  });

  test('an update never changes how a used exercise is recorded', () async {
    final backend = Backend.inMemory(clock: FakeClock().now);
    addTearDown(backend.close);
    seedDemoData(backend, FakeClock().now());
    final exercises = backend.storage.exercises;
    // Someone who logged a plank as weight and reps, and one who has not
    // used the wall sit.
    ExerciseDefinition asWeightReps(String id) => ExerciseDefinition(
      id: id,
      name: id,
      equipment: Equipment.bodyweight,
      primaryMuscles: const [MuscleGroup.core],
      pattern: MovementPattern.isolation,
    );
    exercises
      ..save(asWeightReps('plank'))
      ..save(asWeightReps('wall-sit'));
    final workout = backend.training.startFree([exercises.byId('plank')!]);
    backend.training
      ..begin(workout)
      ..toggleSet(workout, 0)
      ..finish(workout);

    await loadExerciseCatalogue(backend.db, exercises);

    expect(
      exercises.byId('plank')!.trackingType,
      TrackingType.weightReps,
      reason: 'its logged sets keep meaning weight and reps',
    );
    expect(
      exercises.byId('plank')!.frames,
      hasLength(3),
      reason: 'the rest updates',
    );
    expect(exercises.history('plank').sessionCount, 1);
    expect(exercises.byId('wall-sit')!.trackingType, TrackingType.duration);
  });

  test('searching the whole library stays quick, and finds each exercise by '
      'its name', () {
    // The search runs on the UI isolate for every key typed.
    final watch = Stopwatch()..start();
    for (final query in ['臥推', 'bench press', '杠铃卧推', '啞鈴', '弓箭步', 'cable']) {
      searchExercises(shipped, query: query);
    }
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));

    for (final exercise in shipped) {
      final found = searchExercises(shipped, query: exercise.name);
      expect(
        found.take(5).map((result) => result.exercise.id),
        contains(exercise.id),
        reason: 'typing its own name finds ${exercise.name}',
      );
    }
  });

  test('the pictures\' licences are on the licences page', () async {
    registerExerciseDemoLicences();

    final text = StringBuffer();
    await for (final entry in LicenseRegistry.licenses) {
      if (entry.packages.any((package) => package.contains('Workout Guide'))) {
        text.writeln(entry.paragraphs.map((p) => p.text).join('\n'));
      }
    }
    expect(text.toString(), contains('CC BY-SA 4.0'));
    expect(text.toString(), contains('github.com/everkinetic/data'));
    expect(text.toString(), contains('Changes:'), reason: 'BY-SA asks for it');
    expect(text.toString(), contains('MIT License'));
  });

  test(
    'every exercise written for the app says where it was found to exist',
    () {
      // Only the fact that an exercise exists comes from elsewhere: the open
      // datasets that list it, or pages that show it. Never their wording or
      // pictures.
      final ledger = jsonDecode(
        File('tool/exercise_data/provenance.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final core =
          (jsonDecode(File('tool/exercise_data/core.json').readAsStringSync())
                  as Map<String, dynamic>)['exercises']
              as List<dynamic>;
      final coreIds = {for (final row in core) (row as Map)['id']};
      final written = {
        for (final exercise in shipped)
          if (!coreIds.contains(exercise.id)) exercise.id,
      };
      expect(
        ledger.keys.toSet(),
        written,
        reason: 'one record each, no strays',
      );
      for (final MapEntry(:key, :value) in ledger.entries) {
        final record = value as Map<String, dynamic>;
        expect(
          (record['datasets'] as List? ?? const []).length +
              (record['pages'] as List? ?? const []).length,
          greaterThan(0),
          reason: key,
        );
      }
    },
  );
}
