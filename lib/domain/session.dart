import 'activity.dart';
import 'records.dart';
import 'training.dart';

/// What is running right now. The app allows exactly one at a time, so
/// the chrome asks this instead of checking each kind of session, and a
/// new kind has to answer the same questions.
sealed class ActiveSession {
  const ActiveSession();

  DateTime get startedAt;

  bool get isPaused;

  /// Arranged but not yet under way: there is no time to pause, and
  /// nothing done to finish. Only a workout can be.
  bool get isReady;

  /// Time spent actually doing it: a running pause freezes the clock and
  /// finished pauses are subtracted.
  Duration elapsedAt(DateTime now);

  RecordCategory get category;
}

/// A workout being logged set by set.
final class ActiveWorkout extends ActiveSession {
  const ActiveWorkout(this.workout);

  final WorkoutSession workout;

  @override
  DateTime get startedAt => workout.startedAt;

  @override
  bool get isPaused => workout.isPaused;

  @override
  bool get isReady => workout.isReady;

  @override
  Duration elapsedAt(DateTime now) => workout.elapsedAt(now);

  @override
  RecordCategory get category => RecordCategory.training;
}

/// Exercise being timed as it happens, which becomes an
/// [ActivitySession] once it stops.
final class ActiveActivity extends ActiveSession {
  const ActiveActivity(this.activity);

  final LiveActivity activity;

  @override
  DateTime get startedAt => activity.startedAt;

  @override
  bool get isPaused => activity.isPaused;

  @override
  bool get isReady => false;

  @override
  Duration elapsedAt(DateTime now) => activity.elapsedAt(now);

  @override
  RecordCategory get category => RecordCategory.activity;
}
