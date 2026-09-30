import '../../app/view_model.dart';
import '../../backend/engines/caffeine.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';

/// The parts of Today a user can hide. What is in progress and the next
/// step are not among them: they are the page's reason to exist.
enum TodaySection {
  glance,
  activity,
  intake,
  caffeine,
  vitals,
  week,
  records,
  insights;

  String labelIn(AppLocalizations l10n) => switch (this) {
    glance => l10n.todaySectionGlance,
    activity => l10n.todaySectionActivity,
    intake => l10n.moduleNutrition,
    caffeine => l10n.nutrientCaffeine,
    vitals => l10n.activityMetricGroupVitals,
    week => l10n.todaySectionWeek,
    records => l10n.todaySectionRecords,
    insights => l10n.todaySectionInsights,
  };
}

/// What Today reads that the rest of the app does not already hand it:
/// the day's records across every area, the meal that usually comes
/// next, the week's active days, and which sections are shown.
class TodayViewModel extends ViewModel {
  TodayViewModel(super.backend);

  static const _hiddenKey = 'today.hidden';
  static const _orderKey = 'today.order';
  static const _onlyWithDataKey = 'today.onlyWithData';

  DateTime get _today {
    final time = now();
    return DateTime(time.year, time.month, time.day);
  }

  bool _isToday(DateTime time) =>
      time.year == _today.year &&
      time.month == _today.month &&
      time.day == _today.day;

  /// Every record of today, oldest first.
  List<TimelineEntry> get records => backend.timeline.day(_today);

  /// Whether [id] is a sleep, which opens on the sleep page.
  bool isSleep(String id) => backend.journal.entry(id) is SleepEntry;

  /// The meal the user usually logs about now, when none of that meal is
  /// logged yet today; null when their history does not say, rather
  /// than a guess from the clock.
  MealType? get nextMeal {
    final suggested = backend.nutrition.suggestedMealType(now());
    if (suggested == null) return null;
    final logged = backend.nutrition
        .mealsOn(_today)
        .any((meal) => meal.mealType == suggested);
    return logged ? null : suggested;
  }

  /// The workout finished today, if one was.
  WorkoutSession? get workoutToday => switch (backend.training.lastFinished()) {
    final workout? when _isToday(workout.startedAt) => workout,
    _ => null,
  };

  /// How long a night the user aims for, when they have set it.
  Duration? get sleepGoal => backend.sleep.goal;

  /// Today's figure for each activity metric the health platform has one
  /// for.
  Map<ActivityMetric, double> get activityTotals =>
      backend.activity.dayTotals(_today);

  /// [metric] hour by hour today; null without a reading.
  List<double>? activityHours(ActivityMetric metric) =>
      backend.activity.hourly(metric, _today);

  /// The caffeine likely still in the body around now ([caffeineAround]).
  ({List<(DateTime, double)> curve, int nowIndex})? get caffeine {
    final at = now();
    return caffeineAround(
      caffeineIntakes(
        backend.nutrition.between(
          at.subtract(caffeineCurveBack + const Duration(days: 1)),
          at,
        ),
      ),
      at: at,
    );
  }

  /// Today's vitals, each at the day's figure.
  Map<ActivityMetric, double> get vitals {
    final totals = backend.activity.dayTotals(_today);
    return {
      for (final MapEntry(key: metric, value: value) in totals.entries)
        if (metric.group == ActivityMetricGroup.vitals) metric: value,
    };
  }

  /// Whether a vital was taken on purpose today, a blood pressure or a
  /// body temperature: a watch's background readings alone would put the
  /// card on Today every day.
  static bool isTaken(Map<ActivityMetric, double> vitals) =>
      vitals.containsKey(ActivityMetric.bloodPressureSystolic) ||
      vitals.containsKey(ActivityMetric.bodyTemperature);

  /// The plain water the day's level fills towards; null draws none.
  int? get waterReferenceMl => backend.nutrition.waterReferenceMl;

  /// Water drunk today.
  WaterLogged get water => summariseWater(backend.nutrition.mealsOn(_today));

  /// The days of this week, Monday first, each with whether anything was
  /// trained or done on it; and the week's goal when one is set.
  ({List<(DateTime, bool)> days, int active, int? target}) get week {
    final overview = backend.goal.overview();
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    final days = [
      for (var i = 0; i < DateTime.daysPerWeek; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ];
    return (
      days: [for (final day in days) (day, overview.activeDays.contains(day))],
      active: overview.thisWeek.activeDays,
      target: overview.hasGoal ? overview.thisWeek.targetDays : null,
    );
  }

  Set<TodaySection> get hidden => {
    for (final name in (backend.db.setting(_hiddenKey) ?? '').split(','))
      ?TodaySection.values.asNameMap()[name],
  };

  void setShown(TodaySection section, bool isShown) {
    final hidden = {...this.hidden};
    isShown ? hidden.remove(section) : hidden.add(section);
    backend.db.setSetting(
      _hiddenKey,
      [for (final section in hidden) section.name].join(','),
    );
  }

  void showAll() => backend.db.setSetting(_hiddenKey, '');

  /// The sections in the order the user put them; one added since takes
  /// the place it has among the others by default.
  List<TodaySection> get order {
    final stored = [
      for (final name in (backend.db.setting(_orderKey) ?? '').split(','))
        ?TodaySection.values.asNameMap()[name],
    ];
    final order = [...stored];
    for (final section in TodaySection.values) {
      if (order.contains(section)) continue;
      // After whichever section comes before it by default.
      final before = TodaySection.values
          .take(section.index)
          .lastWhere(order.contains, orElse: () => section);
      order.insert(before == section ? 0 : order.indexOf(before) + 1, section);
    }
    return order;
  }

  void setOrder(List<TodaySection> order) => backend.db.setSetting(
    _orderKey,
    [for (final section in order) section.name].join(','),
  );

  /// Moves the section at [from] to [to], its place once it is out.
  void move(int from, int to) {
    final order = [...this.order];
    order.insert(to, order.removeAt(from));
    setOrder(order);
  }

  /// Whether a section with nothing to show today is left out, rather
  /// than shown empty.
  bool get showsOnlyWithData => backend.db.setting(_onlyWithDataKey) != 'false';

  void setShowsOnlyWithData(bool value) =>
      backend.db.setSetting(_onlyWithDataKey, '$value');
}
