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

  /// Time spent actually doing it: a running pause freezes the clock and
  /// finished pauses are subtracted.
  Duration elapsedAt(DateTime now);

  /// What the chrome calls it while it runs.
  String get label;

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
  Duration elapsedAt(DateTime now) => workout.elapsedAt(now);

  @override
  String get label => '訓練';

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
  Duration elapsedAt(DateTime now) => activity.elapsedAt(now);

  @override
  String get label => activity.type.label;

  @override
  RecordCategory get category => RecordCategory.activity;
}
