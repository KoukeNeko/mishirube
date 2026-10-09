import '../../app/view_model.dart';
import '../../backend/application/sleep_service.dart';
import '../../backend/engines/body_metrics.dart';
import '../../backend/engines/caffeine.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../vitals/vitals_view_model.dart';

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

  /// The records of another day are no longer today's.
  String labelIn(AppLocalizations l10n, {bool isToday = true}) =>
      switch (this) {
        glance => l10n.todaySectionGlance,
        activity => l10n.todaySectionActivity,
        intake => l10n.moduleNutrition,
        caffeine => l10n.nutrientCaffeine,
        vitals => l10n.vitalsTitle,
        week => l10n.todaySectionWeek,
        records => isToday ? l10n.todaySectionRecords : l10n.tabLog,
        insights => l10n.todaySectionInsights,
      };
}

/// What Today reads that the rest of the app does not already hand it:
/// the day's records across every area, the meal that usually comes
/// next, the week's active days, and which sections are shown.
///
/// It shows today until another day is picked; what only means something
/// now (the meal that comes next, the caffeine in the body, what is worth
/// noticing) is left to today.
class TodayViewModel extends ViewModel {
  TodayViewModel(super.backend);

  static const _hiddenKey = 'today.hidden';
  static const _orderKey = 'today.order';
  static const _onlyWithDataKey = 'today.onlyWithData';

  /// Midnight of the day the clock says it is.
  DateTime get today {
    final time = now();
    return DateTime(time.year, time.month, time.day);
  }

  /// The day picked, null while the page follows the clock: a page left
  /// on today is still today after midnight.
  DateTime? _picked;

  /// Midnight of the day shown.
  DateTime get day => _picked ?? today;

  bool get isToday => _picked == null;

  void pick(DateTime day) {
    _picked = day == today ? null : day;
    notifyListeners();
  }

  /// The days within five weeks of the shown one that have any record,
  /// for the week strip to mark.
  Set<DateTime> get markedDays {
    final marked = <DateTime>{};
    for (var back = -35; back <= 35; back += 7) {
      final week = DateTime(day.year, day.month, day.day + back);
      final month = DateTime(week.year, week.month);
      for (final date in backend.timeline.categoriesIn(month).keys) {
        marked.add(DateTime(month.year, month.month, date));
      }
    }
    return marked;
  }

  /// Every record of the day, oldest first.
  List<TimelineEntry> get records => backend.timeline.day(day);

  /// The showers and baths that ended on the day, oldest first.
  List<BathEntry> get baths => backend.journal.bathsOn(day);

  /// Whether [id] is a sleep, which opens on the sleep page.
  bool isSleep(String id) => backend.journal.entry(id) is SleepEntry;

  /// The meal the user usually logs about now, when none of that meal is
  /// logged yet today; null when their history does not say, rather
  /// than a guess from the clock, and on any other day.
  MealType? get nextMeal {
    if (!isToday) return null;
    final suggested = backend.nutrition.suggestedMealType(now());
    if (suggested == null) return null;
    final logged = backend.nutrition
        .mealsOn(day)
        .any((meal) => meal.mealType == suggested);
    return logged ? null : suggested;
  }

  /// The workouts finished on the day, newest first.
  List<WorkoutSession> get workouts => backend.training.finishedOn(day);

  /// Food eaten on the day and how complete the log is. Plain water is
  /// 喝水's, not a record of food.
  DaySummary get intake => summariseDay([
    for (final meal in backend.nutrition.mealsOn(day))
      if (!meal.isWater) meal,
  ], isOver: !isToday);

  /// The night the sleep tile shows: the latest while it is today, as
  /// last night is what a morning asks about, else the night that ended
  /// on the day.
  SleepRecord? get night => isToday
      ? backend.sleep.lastNight()
      : backend.sleep
            .day(day)
            .where((record) => record.entry.kind == SleepKind.night)
            .firstOrNull;

  /// The weight card as of the day: the latest weighing, and the week's
  /// trend up to it.
  ({
    BodyWeight? latest,
    List<(DateTime, double, double)> week,
    double? weekChange,
  })
  get weight {
    final end = isToday
        ? backend.db.nowInclusive
        : DateTime(day.year, day.month, day.day + 1);
    return weightSummaryOf(
      backend.journal.weightsBetween(
        end.subtract(const Duration(days: 14)),
        end,
      ),
      end,
    );
  }

  /// How long a night the user aims for, when they have set it.
  Duration? get sleepGoal => backend.sleep.goal;

  /// Time asleep in the naps of [day].
  Duration napTimeOn(DateTime day) => backend.sleep.napTimeOn(day);

  /// Today's figure for each activity metric the health platform has one
  /// for.
  Map<ActivityMetric, double> get activityTotals =>
      backend.activity.dayTotals(day);

  /// [metric] hour by hour today; null without a reading.
  List<double>? activityHours(ActivityMetric metric) =>
      backend.activity.hourly(metric, day);

  /// The caffeine likely still in the body around now ([caffeineAround]).
  ({List<(DateTime, double)> curve, int nowIndex})? get caffeine =>
      backend.nutrition.caffeineNow();

  /// Today's resting heart rate and vitals, each at the day's figure.
  Map<ActivityMetric, double> get vitals {
    final totals = backend.activity.dayTotals(day);
    return {
      for (final MapEntry(key: metric, value: value) in totals.entries)
        if (metric == ActivityMetric.restingHeartRate ||
            metric.group == ActivityMetricGroup.vitals)
          metric: value,
    };
  }

  /// What Today's card holds, in its order: the readings pinned to it,
  /// each at its last reading, or with none pinned, today's resting
  /// heart rate and vitals. Blood pressure comes as its pair.
  Map<ActivityMetric, (DateTime, double)> get vitalReadings {
    final pinned = VitalsViewModel.pinnedIn(backend);
    if (pinned.isEmpty) {
      final vitals = this.vitals;
      return {
        for (final metric in const [
          ActivityMetric.restingHeartRate,
          ActivityMetric.bloodPressureSystolic,
          ActivityMetric.bloodPressureDiastolic,
          ActivityMetric.bodyTemperature,
          ActivityMetric.oxygenSaturation,
          ActivityMetric.respiratoryRate,
        ])
          if (vitals[metric] case final value?) metric: (day, value),
      };
    }
    return {
      for (final metric in [
        for (final metric in pinned) ...[
          metric,
          if (metric == ActivityMetric.bloodPressureSystolic)
            ActivityMetric.bloodPressureDiastolic,
        ],
      ])
        metric: ?VitalsViewModel.latestIn(
          backend,
          metric,
          day: isToday ? null : day,
        ),
    };
  }

  /// Whether the user chose what Today's card holds: it then shows
  /// whenever any of it was ever read.
  bool get hasPinnedVitals => VitalsViewModel.pinnedIn(backend).isNotEmpty;

  /// [metric] on each day from [from] to [to], oldest first.
  List<(DateTime, double)> daily(
    ActivityMetric metric,
    DateTime from,
    DateTime to,
  ) => backend.activity.daily(metric, from, to);

  /// Whether today's card earns its place: a vital taken on purpose, a
  /// blood pressure or a body temperature, or the day's resting heart
  /// rate, one figure a day as the steps are. A watch's background
  /// readings of breathing and oxygen alone would put it there every day
  /// with nothing to say.
  static bool earnsCard(Map<ActivityMetric, double> vitals) =>
      vitals.containsKey(ActivityMetric.bloodPressureSystolic) ||
      vitals.containsKey(ActivityMetric.bodyTemperature) ||
      vitals.containsKey(ActivityMetric.restingHeartRate);

  /// The day's energy target; null while the body it is worked out from
  /// is not set.
  double? get kcalTarget => backend.nutrition.targetsOn(day).kcal;

  /// The plain water the day's level fills towards; null draws none.
  int? get waterReferenceMl => backend.nutrition.waterReferenceMl;

  /// Water drunk on the day.
  WaterLogged get water => summariseWater(backend.nutrition.mealsOn(day));

  /// The days of this week, Monday first, each with whether anything was
  /// trained or done on it; and the week's goal when one is set.
  ({List<(DateTime, bool)> days, int active, int? target}) get week {
    final overview = backend.goal.overview();
    final monday = today.subtract(Duration(days: today.weekday - 1));
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
