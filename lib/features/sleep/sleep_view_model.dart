import '../../app/view_model.dart';
import '../../backend/application/sleep_service.dart';
import '../../backend/engines/sleep_metrics.dart';
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

  /// The average night asleep over the four weeks before the day shown,
  /// for reading the day's night against; null without one.
  Duration? get usualNight {
    final nights = [
      for (final night in backend.sleep.nights(
        _day.subtract(const Duration(days: 28)),
        _day,
      ))
        if (night.measure == SleepMeasure.asleep) night,
    ];
    if (nights.isEmpty) return null;
    return nights.fold(Duration.zero, (sum, n) => sum + n.duration) ~/
        nights.length;
  }

  /// How long a night the user aims for; null until set.
  Duration? get goal => backend.sleep.goal;

  void setGoal(Duration? goal) => backend.sleep.setGoal(goal);

  /// How far the last seven nights fell short of the goal, net; null
  /// without a goal or a night.
  Duration? get weekShortfall {
    final goal = this.goal;
    final nights = nightsAsleep(DateTime.daysPerWeek);
    if (goal == null || nights.isEmpty) return null;
    return shortfall(nights, goal);
  }

  /// When to sleep tonight to reach the goal and wake as usual; only on
  /// today, with a goal and enough nights.
  ({DateTime bedtime, DateTime wake})? get tonightPlan =>
      day == today ? backend.sleep.tonightPlan() : null;

  bool get isReminderOn => backend.sleep.isReminderOn;

  void setReminder(bool isOn) => backend.sleep.setReminder(isOn);

  /// The average time in each stage over the [days] ending with the day
  /// shown, from the nights that were staged.
  ({Map<SleepStage, Duration> stages, int nights}) averageStages(int days) {
    final end = _day.add(const Duration(days: 1));
    return backend.sleep.averageStages(end.subtract(Duration(days: days)), end);
  }

  /// Each night's average of [measure] over the [days] ending with the
  /// day shown, oldest first.
  List<double> nightlyAverages(OvernightMeasure measure, int days) {
    final end = _day.add(const Duration(days: 1));
    return backend.sleep.nightlyAverages(
      measure,
      end.subtract(Duration(days: days)),
      end,
    );
  }

  /// The usual range of [measure] over the four weeks before the day.
  ({double low, double high})? baseline(OvernightMeasure measure) => baselineOf(
    backend.sleep.nightlyAverages(
      measure,
      _day.subtract(const Duration(days: 28)),
      _day,
    ),
  );

  /// Nights after training, late caffeine or a late meal against nights
  /// without.
  ({
    SleepComparison? training,
    SleepComparison? lateCaffeine,
    SleepComparison? lateMeal,
  })
  get factors => backend.sleep.factors();

  /// Shows a sleep from another source that recorded it.
  void chooseSource(String id, String source) =>
      backend.sleep.chooseSource(id, source);

  void delete(String id) => backend.journal.delete(id);

  void restore(String id) => backend.journal.restore(id);
}
