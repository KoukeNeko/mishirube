import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
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
      // How sets are recorded is part of how the history reads, so an
      // exercise already in a workout or a routine keeps the way it was
      // recorded, as `CatalogService.update` refuses to change it. An
      // update to the library only sets it for an exercise not used yet.
      final isUsed =
          mine != null &&
          db.select(
            'SELECT 1 FROM workout_exercises WHERE exercise_id = ? '
            'UNION ALL SELECT 1 FROM routine_exercises WHERE exercise_id = ? '
            'LIMIT 1',
            [exercise.id, exercise.id],
          ).isNotEmpty;
      final next = mine == null
          ? exercise
          : ExerciseDefinition(
              id: exercise.id,
              name: exercise.name,
              aliases: exercise.aliases,
              equipment: exercise.equipment,
              primaryMuscles: exercise.primaryMuscles,
              secondaryMuscles: exercise.secondaryMuscles,
              pattern: exercise.pattern,
              trackingType: isUsed ? mine.trackingType : exercise.trackingType,
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
            );
      // Most of an update leaves most of the library as it was.
      if (mine != null && exercises.matchesCatalogue(next)) continue;
      exercises.save(next, source: ChangeSource.catalogue);
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
      cues: [for (final cue in row['cues'] as List? ?? const []) cue as String],
    ),
];

/// Puts the notices the pictures' licences ask for on the open-source
/// licences page. The text of `third_party/workout-guide/` ships here
/// because that folder is not bundled with the app.
void registerExerciseDemoLicences() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Workout Guide（exercise pictures）'],
      'The exercise pictures are the pose frames of Workout Guide '
      '(https://github.com/bryllim/workout-guide) by Bryl Lim, licensed under '
      'the Creative Commons Attribution-ShareAlike 4.0 International license '
      '(CC BY-SA 4.0, https://creativecommons.org/licenses/by-sa/4.0/legalcode). '
      'Copyright (c) 2026 Bryl Lim, except where its ATTRIBUTION.md names an '
      'upstream source.\n\n'
      'The original pose artwork comes from Everkinetic '
      '(https://github.com/everkinetic/data), also CC BY-SA 4.0.\n\n'
      'Changes: the SVG frames were converted to 384 × 384 WebP images, '
      'named by this app\'s exercise ids; the drawings themselves were not '
      'edited. The converted pictures are distributed under CC BY-SA 4.0 as '
      'unprotected files in assets/exercises/frames/. A variant of an '
      'exercise may show the frames of the exercise it is a version of.',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Workout Guide（exercise list）'],
      'MIT License\n\n'
      'Copyright (c) 2026 Bryl Lim\n\n'
      'Permission is hereby granted, free of charge, to any person obtaining '
      'a copy of this software and associated documentation files (the '
      '"Software"), to deal in the Software without restriction, including '
      'without limitation the rights to use, copy, modify, merge, publish, '
      'distribute, sublicense, and/or sell copies of the Software, and to '
      'permit persons to whom the Software is furnished to do so, subject to '
      'the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be '
      'included in all copies or substantial portions of the Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, '
      'EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF '
      'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND '
      'NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS '
      'BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN '
      'ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN '
      'CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
      'SOFTWARE.',
    );
  });
}
