import '../../domain/domain.dart';

/// One area's contribution to the log: its rows, its one-line summary of a
/// day, and anything it wants to say about that day.
///
/// The timeline merges sources; it does not know how a workout or a meal
/// turns into a row. A new kind of record adds a source instead of another
/// block inside the query.
abstract class TimelineSource {
  /// Which dot on the calendar this source feeds. Sources sharing a
  /// category (sleep and check-ins) are summarised in registration order,
  /// the last one winning.
  RecordCategory get category;

  /// Rows for `[start, end)`, each with when it happened.
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end);

  /// Per day of the month, the line shown under the calendar.
  Map<int, String> summariesIn(DateTime start, DateTime end);

  /// Per day of the month, a warning about the day as a whole, such as an
  /// incomplete food log. Most sources have none.
  Map<int, String> warningsIn(DateTime start, DateTime end) => const {};

  /// The oldest record this source holds, for how far the log goes back.
  DateTime? earliest();
}
