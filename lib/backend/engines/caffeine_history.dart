import '../../domain/domain.dart';
import 'caffeine.dart';
import 'nutrition_summary.dart';
import 'sleep_metrics.dart';

/// Days the caffeine page looks back over, ending with yesterday: today
/// is still going, so it is not a day yet.
const caffeineHistoryDays = 28;

/// Complete weekdays, and complete weekend days, each side needs before
/// its average is shown.
const minimumDaysForCaffeineAverage = 4;

/// The hours of the day each time-of-day band starts at; the first
/// starts at midnight.
const caffeineBandStartHours = [0, 12, 15, 18, 21];

/// Sources the page lists.
const caffeineSourceLimit = 5;

/// One record that carried caffeine.
class CaffeineRecord {
  const CaffeineRecord({
    required this.at,
    required this.meal,
    required this.milligrams,
  });

  final DateTime at;
  final MealEvent meal;
  final double milligrams;
}

/// A day's caffeine records, oldest first, and whether the day's food was
/// logged in full: only then is its total a day's intake, not a floor.
class CaffeineDay {
  const CaffeineDay({
    required this.day,
    required this.isComplete,
    required this.records,
  });

  final DateTime day;
  final bool isComplete;
  final List<CaffeineRecord> records;

  double get total => records.fold(0, (sum, record) => sum + record.milligrams);

  CaffeineRecord? get first => records.firstOrNull;
  CaffeineRecord? get last => records.lastOrNull;

  /// The day's total, or null for a day that was not logged in full: a
  /// gap, never a zero.
  double? get completeTotal => isComplete ? total : null;
}

/// Where the caffeine of [CaffeineHistory] came from, by name.
class CaffeineSource {
  const CaffeineSource({
    required this.name,
    required this.milligrams,
    required this.count,
  });

  final String name;
  final double milligrams;
  final int count;
}

/// The last [caffeineHistoryDays] days of caffeine, as the records say it;
/// nothing is added for a day nobody logged.
class CaffeineHistory {
  const CaffeineHistory._({
    required this.days,
    required this.atBedtime,
    required this.sources,
    required this.bands,
    required this.weekdayAverage,
    required this.weekendAverage,
  });

  /// Oldest first, one per day, yesterday last.
  final List<CaffeineDay> days;

  /// Each day's estimated caffeine at the usual bedtime of its evening,
  /// aligned with [days]; null for a day not logged in full, and null
  /// throughout without a usual bedtime.
  final List<double?> atBedtime;

  /// The most caffeine first, [caffeineSourceLimit] at most.
  final List<CaffeineSource> sources;

  /// Milligrams in each band of [caffeineBandStartHours], over every
  /// record of the days.
  final List<double> bands;

  /// Of the complete days; null below [minimumDaysForCaffeineAverage].
  final double? weekdayAverage;
  final double? weekendAverage;

  List<CaffeineDay> get _completeDays => [
    for (final day in days)
      if (day.isComplete) day,
  ];

  /// The average total of the complete days; null with none.
  double? get average {
    final complete = _completeDays;
    if (complete.isEmpty) return null;
    return complete.fold(0.0, (sum, day) => sum + day.total) / complete.length;
  }

  /// The highest total of the complete days; null with none.
  double? get highest {
    final complete = _completeDays;
    if (complete.isEmpty) return null;
    return complete.map((day) => day.total).reduce((a, b) => a > b ? a : b);
  }
}

/// The band of [caffeineBandStartHours] the hour of [at] falls in.
int caffeineBandOf(DateTime at) =>
    caffeineBandStartHours.lastIndexWhere((start) => at.hour >= start);

/// How far [at] is from the usual bedtime of its day, or null when the
/// usual bedtime is unknown or already past. A bedtime before noon is
/// after midnight, so it falls on the next morning.
Duration? caffeineBeforeBedtime(DateTime at, Duration? usualBedtime) {
  if (usualBedtime == null) return null;
  final day = DateTime(at.year, at.month, at.day);
  final bedtime =
      (usualBedtime < const Duration(hours: 12)
              ? DateTime(day.year, day.month, day.day + 1)
              : day)
          .add(usualBedtime);
  final before = bedtime.difference(at);
  return before.isNegative || before == Duration.zero ? null : before;
}

/// [meals] over the [caffeineHistoryDays] days before [today], as
/// [CaffeineHistory]. [meals] reach back a day before the first of them,
/// so the first bedtime has what was drunk before it. [usualBedtime] is a
/// time after midnight ([regularityOf]); null leaves [atBedtime] empty.
CaffeineHistory caffeineHistory(
  Iterable<(DateTime, MealEvent)> meals, {
  required DateTime today,
  Duration? usualBedtime,
}) {
  final midnight = DateTime(today.year, today.month, today.day);
  final firstDay = DateTime(
    midnight.year,
    midnight.month,
    midnight.day - caffeineHistoryDays,
  );
  final all = meals.toList();
  final mealsByDay = <DateTime, List<MealEvent>>{};
  final recordsByDay = <DateTime, List<CaffeineRecord>>{};
  for (final (at, meal) in all) {
    if (at.isBefore(firstDay) || !at.isBefore(midnight)) continue;
    final day = DateTime(at.year, at.month, at.day);
    (mealsByDay[day] ??= []).add(meal);
    if (meal.nutrients[Nutrient.caffeine] case final milligrams?
        when milligrams > 0) {
      (recordsByDay[day] ??= []).add(
        CaffeineRecord(at: at, meal: meal, milligrams: milligrams),
      );
    }
  }
  final days = [
    for (var i = 0; i < caffeineHistoryDays; i++)
      () {
        final day = DateTime(firstDay.year, firstDay.month, firstDay.day + i);
        return CaffeineDay(
          day: day,
          isComplete: switch (mealsByDay[day]) {
            final meals? => summariseDay(meals).isComplete,
            null => false,
          },
          records: [...?recordsByDay[day]]
            ..sort((a, b) => a.at.compareTo(b.at)),
        );
      }(),
  ];

  final intakes = caffeineIntakes(all);
  final atBedtime = [
    for (final day in days)
      if (usualBedtime == null || !day.isComplete)
        null
      else
        caffeineAtUsualBedtime(
          intakes,
          DateTime(day.day.year, day.day.month, day.day.day + 1),
          usualBedtime,
        ),
  ];

  final bands = List.filled(caffeineBandStartHours.length, 0.0);
  final bySource = <String, ({double milligrams, int count})>{};
  for (final day in days) {
    for (final record in day.records) {
      bands[caffeineBandOf(record.at)] += record.milligrams;
      final seen = bySource[record.meal.name];
      bySource[record.meal.name] = (
        milligrams: (seen?.milligrams ?? 0) + record.milligrams,
        count: (seen?.count ?? 0) + 1,
      );
    }
  }
  final sources =
      [
        for (final MapEntry(:key, :value) in bySource.entries)
          CaffeineSource(
            name: key,
            milligrams: value.milligrams,
            count: value.count,
          ),
      ]..sort((a, b) {
        final byMilligrams = b.milligrams.compareTo(a.milligrams);
        if (byMilligrams != 0) return byMilligrams;
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });

  double? averageOf(bool Function(DateTime day) isIncluded) {
    final included = [
      for (final day in days)
        if (day.isComplete && isIncluded(day.day)) day.total,
    ];
    if (included.length < minimumDaysForCaffeineAverage) return null;
    return included.fold(0.0, (sum, total) => sum + total) / included.length;
  }

  bool isWeekend(DateTime day) =>
      day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  return CaffeineHistory._(
    days: days,
    atBedtime: atBedtime,
    sources: sources.take(caffeineSourceLimit).toList(),
    bands: bands,
    weekdayAverage: averageOf((day) => !isWeekend(day)),
    weekendAverage: averageOf(isWeekend),
  );
}
