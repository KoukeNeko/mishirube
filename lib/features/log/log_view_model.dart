import '../../app/view_model.dart';
import '../../domain/domain.dart';

/// The log: each month's records, and how far back they go.
class LogViewModel extends ViewModel {
  LogViewModel(super.backend);

  /// Records for the month starting [month].
  MonthRecords month(DateTime month) => backend.timeline.month(month);

  /// The first month the log can go back to.
  DateTime get earliestMonth {
    final today = now();
    return backend.timeline.earliestMonth() ??
        DateTime(today.year, today.month);
  }

  static const _calendarKey = 'log.shows_calendar';

  /// Whether the log opens on the calendar: the view last chosen, kept.
  bool get showsCalendar => backend.db.setting(_calendarKey) == 'true';

  void setShowsCalendar(bool shows) =>
      backend.db.setSetting(_calendarKey, '$shows');

  /// Whether [id] is a sleep, which opens on the sleep page.
  bool isSleep(String id) => backend.journal.entry(id) is SleepEntry;
}
