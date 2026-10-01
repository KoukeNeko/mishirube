import '../../app/view_model.dart';
import '../../domain/domain.dart';

/// The heart and the vitals page: what a health platform read of each,
/// at its last reading. Nothing is typed in here.
class VitalsViewModel extends ViewModel {
  VitalsViewModel(super.backend);

  /// Each metric of [group]'s last day with a reading within
  /// [readingsWindow], and that day's figure.
  Map<ActivityMetric, (DateTime, double)> latestOf(ActivityMetricGroup group) {
    final today = backend.db.now();
    return {
      for (final metric in ActivityMetric.values)
        if (metric.group == group)
          metric: ?backend.activity
              .daily(metric, today.subtract(readingsWindow), today)
              .lastOrNull,
    };
  }

  /// How far back the page looks for a reading.
  static const readingsWindow = Duration(days: 90);
}
