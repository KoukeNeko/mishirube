import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'application/catalog_service.dart';
import 'application/insights_service.dart';
import 'application/journal_service.dart';
import 'application/nutrition_service.dart';
import 'application/training_service.dart';
import 'storage/database.dart';
import 'storage/exercise_repository.dart';
import 'storage/journal_repository.dart';
import 'storage/meal_repository.dart';
import 'storage/routine_repository.dart';
import 'storage/timeline_query.dart';
import 'storage/workout_repository.dart';

const _databaseFileName = 'mishirube.sqlite3';

/// The SQLite store and the repositories over it. Screens go through the
/// services on [Backend] instead; this layer serves the backend itself,
/// its tests, and import and export.
class Storage {
  Storage(this.db)
    : exercises = ExerciseRepository(db),
      routines = RoutineRepository(db),
      workouts = WorkoutRepository(db),
      meals = MealRepository(db),
      journal = JournalRepository(db) {
    timeline = TimelineQuery(db, [
      WorkoutTimelineSource(workouts, exercises),
      MealTimelineSource(meals),
      BodyWeightTimelineSource(journal),
      SleepTimelineSource(journal),
      // After sleep: a check-in is the more specific thing to say about a
      // day that has both.
      WellnessTimelineSource(journal),
    ]);
  }

  final AppDatabase db;
  final ExerciseRepository exercises;
  final RoutineRepository routines;
  final WorkoutRepository workouts;
  final MealRepository meals;
  final JournalRepository journal;
  late final TimelineQuery timeline;
}

/// The app's local-first backend: one SQLite file, the repositories over
/// it, and the use cases the app works through. Nothing here waits on a
/// network.
class Backend {
  Backend(AppDatabase database) : storage = Storage(database) {
    catalog = CatalogService(db, storage.exercises);
    training = TrainingService(
      db,
      storage.workouts,
      storage.exercises,
      storage.routines,
    );
    nutrition = NutritionService(db, storage.meals);
    journal = JournalService(db, storage.journal);
    insights = InsightsService(
      db,
      storage.workouts,
      storage.exercises,
      storage.meals,
      storage.journal,
    );
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

  final Storage storage;
  late final CatalogService catalog;
  late final TrainingService training;
  late final NutritionService nutrition;
  late final JournalService journal;
  late final InsightsService insights;

  AppDatabase get db => storage.db;

  TimelineQuery get timeline => storage.timeline;

  void close() => db.close();
}
