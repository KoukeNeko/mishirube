import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
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

  test('the library is whole: names, muscles, frames and unique ids', () {
    expect(shipped.length, greaterThan(250));
    expect({for (final e in shipped) e.id}, hasLength(shipped.length));
    for (final exercise in shipped) {
      expect(exercise.name, isNotEmpty);
      expect(exercise.primaryMuscles, isNotEmpty, reason: exercise.id);
      expect(
        [...exercise.primaryMuscles, ...exercise.secondaryMuscles]
            .where((m) => m.isGeneral),
        isEmpty,
        reason: '${exercise.id} names a muscle, not a whole region',
      );
      expect(exercise.family, isNotEmpty, reason: exercise.id);
      expect(exercise.frames, hasLength(3), reason: exercise.id);
      for (final frame in exercise.frames) {
        expect(File(frame).existsSync(), isTrue, reason: frame);
      }
    }
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
}
