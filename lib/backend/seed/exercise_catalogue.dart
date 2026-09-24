import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/domain.dart';
import '../storage/database.dart';
import '../storage/exercise_repository.dart';

const exerciseCatalogueFile = 'assets/exercises/catalogue.json';

/// The setting that says which version of the library was last loaded.
const _loadedKey = 'exercises.catalogue';

/// Loads the built-in exercise library (see
/// `tool/build_exercise_catalogue.py`), when the bundled file differs from
/// the one last loaded: an app update brings its corrections, and an
/// ordinary launch reads nothing.
///
/// What the user made of an exercise — a favourite, a hidden one, their
/// own names for it, whether their gym has it — is theirs and kept.
Future<void> loadExerciseCatalogue(
  AppDatabase db,
  ExerciseRepository exercises,
) async {
  final text = await rootBundle.loadString(exerciseCatalogueFile);
  final version = sha256.convert(utf8.encode(text)).toString();
  if (db.setting(_loadedKey) == version) return;
  final shipped = parseExerciseCatalogue(
    jsonDecode(text) as Map<String, dynamic>,
  );
  db.transaction(() {
    for (final exercise in shipped) {
      final mine = exercises.byId(exercise.id);
      exercises.save(
        mine == null
            ? exercise
            : ExerciseDefinition(
                id: exercise.id,
                name: exercise.name,
                aliases: exercise.aliases,
                equipment: exercise.equipment,
                primaryMuscles: exercise.primaryMuscles,
                secondaryMuscles: exercise.secondaryMuscles,
                pattern: exercise.pattern,
                trackingType: exercise.trackingType,
                laterality: exercise.laterality,
                family: exercise.family,
                frames: exercise.frames,
                // The library has no cues of its own yet; the ones already
                // written stay.
                cues: exercise.cues.isEmpty ? mine.cues : exercise.cues,
                personalAliases: mine.personalAliases,
                isFavorite: mine.isFavorite,
                isHidden: mine.isHidden,
                isInHomeGym: mine.isInHomeGym,
              ),
        source: ChangeSource.catalogue,
      );
    }
    db.setSetting(_loadedKey, version);
  });
}

/// The exercises the library file describes.
List<ExerciseDefinition> parseExerciseCatalogue(Map<String, dynamic> file) => [
  for (final row
      in (file['exercises']! as List<dynamic>).cast<Map<String, dynamic>>())
    ExerciseDefinition(
      id: row['id']! as String,
      name: row['name']! as String,
      aliases: [for (final alias in row['aliases']! as List) alias as String],
      equipment: Equipment.values.byName(row['equipment']! as String),
      primaryMuscles: [
        for (final name in row['primaryMuscles']! as List)
          MuscleGroup.values.byName(name as String),
      ],
      secondaryMuscles: [
        for (final name in row['secondaryMuscles']! as List)
          MuscleGroup.values.byName(name as String),
      ],
      pattern: MovementPattern.values.byName(row['pattern']! as String),
      trackingType: TrackingType.values.byName(row['trackingType']! as String),
      laterality: Laterality.values.byName(row['laterality']! as String),
      family: row['family']! as String,
      frames: [for (final frame in row['frames']! as List) frame as String],
    ),
];
