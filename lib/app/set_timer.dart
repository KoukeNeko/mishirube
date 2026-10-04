import '../domain/domain.dart';

/// A set being timed as it happens: the time it takes is what gets logged
/// when it is done.
class SetTimer {
  SetTimer(this.set, this.startedAt);

  /// The set being timed; it changes when the set is edited, which
  /// replaces it.
  WorkoutSet set;

  /// When it would have started had it never been held: moved on by every
  /// hold, so the time counted is what is between it and now.
  DateTime startedAt;

  /// When it was held, while it is.
  DateTime? pausedAt;

  bool get isPaused => pausedAt != null;

  /// When it reaches the time the set was planned for, while it runs
  /// toward one: null when held or counting up.
  DateTime? get dueAt {
    final planned = set.durationSeconds ?? 0;
    return isPaused || planned <= 0
        ? null
        : startedAt.add(Duration(seconds: planned));
  }

  Duration elapsedAt(DateTime now) => (pausedAt ?? now).difference(startedAt);
}
