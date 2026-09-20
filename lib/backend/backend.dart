import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'database.dart';
import 'exercise_repository.dart';
import 'journal_repository.dart';
import 'meal_repository.dart';
import 'routine_repository.dart';
import 'timeline_query.dart';
import 'workout_repository.dart';

const _databaseFileName = 'mishirube.sqlite3';

/// The app's local-first backend: one SQLite file and the repositories and
/// queries built on it. Nothing here waits on a network.
class Backend {
  Backend(this.db)
    : exercises = ExerciseRepository(db),
      routines = RoutineRepository(db),
      workouts = WorkoutRepository(db),
      meals = MealRepository(db),
      journal = JournalRepository(db) {
    timeline = TimelineQuery(db, workouts, meals, journal);
  }

  factory Backend.inMemory({DateTime Function()? clock}) =>
      Backend(AppDatabase.inMemory(clock: clock));

  /// Opens the database in the app's private support directory; it is an
  /// implementation detail, not a user document.
  static Future<Backend> openOnDevice() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    // Android has no usable /tmp for SQLite's temporary files.
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
    return Backend(AppDatabase.open(p.join(directory.path, _databaseFileName)));
  }

  final AppDatabase db;
  final ExerciseRepository exercises;
  final RoutineRepository routines;
  final WorkoutRepository workouts;
  final MealRepository meals;
  final JournalRepository journal;
  late final TimelineQuery timeline;

  void close() => db.close();
}
