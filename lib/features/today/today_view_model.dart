import '../../app/view_model.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';

/// The parts of Today a user can hide. What is in progress and the next
/// step are not among them: they are the page's reason to exist.
enum TodaySection {
  glance('今日指標'),
  intake('今日攝取'),
  week('本週'),
  records('今天的紀錄'),
  insights('值得注意');

  const TodaySection(this.label);

  final String label;
}

/// What Today reads that the rest of the app does not already hand it:
/// the day's records across every area, the meal that usually comes
/// next, the week's active days, and which sections are shown.
class TodayViewModel extends ViewModel {
  TodayViewModel(super.backend);

  static const _hiddenKey = 'today.hidden';

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
}
