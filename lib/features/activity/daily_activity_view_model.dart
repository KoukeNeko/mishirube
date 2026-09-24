import '../../app/view_model.dart';
import '../../domain/domain.dart';

/// The activity pages: a day's movement as the health platform counted
/// it, and one metric over time. Everything is read from the records on
/// each build; nothing here is typed in.
class DailyActivityViewModel extends ViewModel {
  DailyActivityViewModel(super.backend, {DateTime? day})
    : _day = _dateOf(day ?? backend.db.now());

  DateTime _day;

  static DateTime _dateOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Midnight of the day shown.
  DateTime get day => _day;

  DateTime get today => _dateOf(now());

  bool get canGoForward => _day.isBefore(today);

  /// Moves the page [days] days, never past today.
  void step(int days) {
    final next = DateTime(_day.year, _day.month, _day.day + days);
    if (next.isAfter(today)) return;
    _day = next;
    notifyListeners();
  }

  /// The metrics any source recorded; one nobody records is never shown.
  List<ActivityMetric> get metrics => backend.activity.recordedMetrics();

  /// Each metric's figure on the day shown, for the ones that have one.
  Map<ActivityMetric, double> get totals => backend.activity.dayTotals(_day);

  /// [metric] hour by hour on the day shown; null without a reading.
  List<double>? hourly(ActivityMetric metric) =>
      backend.activity.hourly(metric, _day);

  /// [metric] per day over the [days] ending with the day shown.
  List<(DateTime, double)> daily(ActivityMetric metric, int days) =>
      backend.activity.daily(
        metric,
        DateTime(_day.year, _day.month, _day.day - days + 1),
        _day,
      );

  ({double low, double high})? usualRange(ActivityMetric metric) =>
      backend.activity.usualRange(metric, _day);

  /// Exercise logged or read on the day shown.
  List<ActivitySession> get sessions => backend.activity.on(_day);
}
