import '../../app/view_model.dart';
import '../../backend/application/sleep_service.dart';
import '../../domain/domain.dart';

/// The sleep page: the day being shown, its sleeps, the nights before it,
/// and which source a sleep is shown from.
class SleepViewModel extends ViewModel {
  SleepViewModel(super.backend, {DateTime? day})
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

  /// The day's sleeps: its night first, then its naps.
  List<SleepRecord> get sleeps => backend.sleep.day(_day);

  SleepRecord? get night => sleeps
      .where((record) => record.entry.kind == SleepKind.night)
      .firstOrNull;

  List<SleepRecord> get naps => [
    for (final record in sleeps)
      if (record.entry.kind == SleepKind.nap) record,
  ];

  /// Nights measured as time asleep over the [days] ending with the day
  /// shown, oldest first. Naps and time in bed are not nights asleep.
  List<SleepEntry> nightsAsleep(int days) {
    final end = _day.add(const Duration(days: 1));
    return [
      for (final night in backend.sleep.nights(
        end.subtract(Duration(days: days)),
        end,
      ))
        if (night.measure == SleepMeasure.asleep) night,
    ];
  }

  /// Shows a sleep from another source that recorded it.
  void chooseSource(String id, String source) =>
      backend.sleep.chooseSource(id, source);

  void delete(String id) => backend.journal.delete(id);

  void restore(String id) => backend.journal.restore(id);
}
