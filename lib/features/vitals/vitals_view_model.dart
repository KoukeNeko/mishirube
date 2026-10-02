import '../../app/view_model.dart';
import '../../backend/backend.dart';
import '../../domain/domain.dart';

/// The heart and the vitals page: what a health platform read of each,
/// at its last reading, and which of them Today's card holds. Nothing is
/// typed in here.
class VitalsViewModel extends ViewModel {
  VitalsViewModel(super.backend);

  /// How far back the page looks for a reading.
  static const readingsWindow = Duration(days: 90);

  /// The vitals in the order the page lists them; blood pressure stands
  /// as its systolic figure, its pair beside it.
  static const vitalsOrder = [
    ActivityMetric.bloodPressureSystolic,
    ActivityMetric.bodyTemperature,
    ActivityMetric.respiratoryRate,
    ActivityMetric.oxygenSaturation,
  ];

  /// Every reading the page can list, in its order: the heart's, then
  /// the vitals.
  static final readingsOrder = [
    for (final metric in ActivityMetric.values)
      if (metric.group == ActivityMetricGroup.heart) metric,
    ...vitalsOrder,
  ];

  /// How many readings Today's card holds.
  static const pinnedLimit = 3;

  static const _pinnedKey = 'today.vitals';

  /// [metric]'s last day with a reading within [readingsWindow] of
  /// today, and that day's figure.
  static (DateTime, double)? latestIn(Backend backend, ActivityMetric metric) {
    final today = backend.db.now();
    return backend.activity
        .daily(metric, today.subtract(readingsWindow), today)
        .lastOrNull;
  }

  /// The readings pinned to Today's card, in the page's order, never
  /// in an order of how far each is from usual; empty until one is
  /// pinned, when the card picks its own.
  static List<ActivityMetric> pinnedIn(Backend backend) {
    final names = (backend.db.setting(_pinnedKey) ?? '').split(',').toSet();
    return [
      for (final metric in readingsOrder)
        if (names.contains(metric.name)) metric,
    ];
  }

  /// Each metric of [group]'s last reading.
  Map<ActivityMetric, (DateTime, double)> latestOf(ActivityMetricGroup group) =>
      {
        for (final metric in ActivityMetric.values)
          if (metric.group == group) metric: ?latestIn(backend, metric),
      };

  /// [metric] on each day from [from] to [to], oldest first.
  List<(DateTime, double)> daily(
    ActivityMetric metric,
    DateTime from,
    DateTime to,
  ) => backend.activity.daily(metric, from, to);

  List<ActivityMetric> get pinned => pinnedIn(backend);

  /// Pins [metric] to Today's card, or takes it off; past
  /// [pinnedLimit] nothing more is pinned.
  void setPinned(ActivityMetric metric, bool isPinned) {
    final pinned = {...this.pinned};
    if (isPinned && pinned.length >= pinnedLimit) return;
    isPinned ? pinned.add(metric) : pinned.remove(metric);
    backend.db.setSetting(
      _pinnedKey,
      [for (final metric in pinned) metric.name].join(','),
    );
  }
}
