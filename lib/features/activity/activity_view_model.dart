import '../../app/view_model.dart';
import '../../domain/domain.dart';

/// Sessions of general exercise logged after the fact: recording,
/// correcting and removing them. Timing one live is the store's, since it
/// shares the one running session with workouts.
class ActivityViewModel extends ViewModel {
  ActivityViewModel(super.backend);

  /// The kinds of exercise used recently, newest first.
  List<ActivityType> get recentTypes => backend.activity.recentTypes();

  /// Where the duration field starts for [type].
  Duration startingDuration(ActivityType type) =>
      backend.activity.startingDuration(type);

  /// A logged session, or null once it has been removed.
  ActivitySession? byId(String id) => backend.activity.byId(id);

  ActivitySession log({
    required ActivityType type,
    required DateTime startedAt,
    required Duration duration,
    double? distanceMeters,
    double? elevationGainMeters,
    int? effort,
    String note = '',
  }) => backend.activity.log(
    type: type,
    startedAt: startedAt,
    duration: duration,
    distanceMeters: distanceMeters,
    elevationGainMeters: elevationGainMeters,
    effort: effort,
    note: note,
  );

  /// Saves a correction to a session already logged.
  void update(ActivitySession activity) => backend.activity.edit(activity);

  /// Removes a session; [restore] takes it back.
  void delete(String id) => backend.activity.delete(id);

  void restore(String id) => backend.activity.restore(id);
}
