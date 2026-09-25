import '../../domain/domain.dart';

/// What the Trends page works out that no single chart shows (see
/// `research/56-trends-insights.md`): what the body actually burns,
/// judged from what was eaten and how the weight moved; how weekends
/// differ from weekdays; protein for the body weight; and how training
/// is spread across muscles. All of it is derived from the records on
/// each read; a function returns null when the records cannot support
/// it, and the page says what is missing.
///
/// Bumped whenever a threshold or rule below changes.
const trendInsightsVersion = 1;

/// Days energy balance is judged over, and what it needs in them.
const energyWindowDays = 21;
const minimumEnergyFoodDays = 14;
const minimumEnergyWeighings = 10;

/// Energy stored in a kilogram of body weight gained or lost. A round
/// figure for mixed tissue; the estimate is labelled as one.
const _kcalPerKg = 7700;

/// How far ahead the weight is projected at the current rate.
const forecastWeeks = 8;

/// Days weekday patterns and protein are read over, and the days each
/// side of a weekday split needs.
const patternWindowDays = 28;
const minimumDaysPerSide = 4;
const minimumProteinDays = 14;

/// A weekend difference worth saying: energy and waking.
const _weekendIntakeShare = 0.1;
const _weekendWakeMinutes = 45;

/// Protein per kilogram past which more adds nothing to training gains
/// (Morton et al. 2018).
const proteinTargetPerKg = 1.6;

/// Working sets a week for near-maximal growth (Schoenfeld et al. 2017).
const weeklySetTarget = 10;

/// Workouts in the window before training balance is said.
const minimumBalanceWorkouts = 4;

/// Beyond this either way, one side of a pair of muscles is trained
/// noticeably more than the other.
const _imbalanceRatio = 1.5;

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

double _mean(Iterable<double> values) =>
    values.fold(0.0, (sum, value) => sum + value) / values.length;

bool _isWeekend(DateTime day) =>
    day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

/// The entries of [days] within the last [windowDays] up to [today].
List<(DateTime, double)> _within(
  List<(DateTime, double)> days,
  DateTime today,
  int windowDays,
) {
  final end = _dayOf(today);
  final start = end.subtract(Duration(days: windowDays - 1));
  return [
    for (final (day, value) in days)
      if (!_dayOf(day).isBefore(start) && !_dayOf(day).isAfter(end))
        (day, value),
  ];
}

/// What the body burned over the last three weeks, from what was eaten
/// and how the trend weight moved: energy in less the energy the body
/// stored or gave up.
class EnergyBalance {
  const EnergyBalance({
    required this.expenditure,
    required this.intake,
    required this.weeklyChangeKg,
    required this.weightKg,
    required this.forecastKg,
    required this.foodDays,
    required this.weighings,
    required this.isIntakeLikelyUnderlogged,
  });

  /// Energy burned a day, estimated.
  final int expenditure;

  /// Average energy eaten on complete days.
  final int intake;

  /// Intake less expenditure: negative is a deficit.
  int get balance => intake - expenditure;

  /// How fast the trend weight moves, per week.
  final double weeklyChangeKg;

  /// The trend weight now, and where it lands in [forecastWeeks] weeks
  /// at the same rate.
  final double weightKg;
  final double forecastKg;

  final int foodDays;
  final int weighings;

  /// The estimate came out below what the body burns at rest: food is
  /// more likely missing from the records than the body running on less.
  final bool isIntakeLikelyUnderlogged;
}

/// Energy balance over [energyWindowDays], from each complete day's
/// energy eaten and the trend weight; null without enough of either.
/// [basalKcal] is what the body burns at rest a day, when a health
/// platform measured it.
EnergyBalance? energyBalance({
  required List<(DateTime, double)> completeDays,
  required List<(DateTime, double)> trendWeights,
  required DateTime today,
  double? basalKcal,
}) {
  final food = _within(completeDays, today, energyWindowDays);
  final weights = _within(trendWeights, today, energyWindowDays);
  if (food.length < minimumEnergyFoodDays ||
      weights.length < minimumEnergyWeighings) {
    return null;
  }
  final slope = _slopePerDay(weights);
  final intake = _mean([for (final (_, kcal) in food) kcal]);
  final expenditure = intake - slope * _kcalPerKg;
  final latest = weights.reduce((a, b) => a.$1.isAfter(b.$1) ? a : b).$2;
  return EnergyBalance(
    expenditure: expenditure.round(),
    intake: intake.round(),
    weeklyChangeKg: slope * DateTime.daysPerWeek,
    weightKg: latest,
    forecastKg: latest + slope * forecastWeeks * DateTime.daysPerWeek,
    foodDays: food.length,
    weighings: weights.length,
    isIntakeLikelyUnderlogged: basalKcal != null && expenditure < basalKcal,
  );
}

/// The least-squares slope of [points], per day.
double _slopePerDay(List<(DateTime, double)> points) {
  final origin = points.first.$1;
  final xs = [
    for (final (at, _) in points)
      at.difference(origin).inMinutes / Duration.minutesPerDay,
  ];
  final ys = [for (final (_, value) in points) value];
  final meanX = _mean(xs);
  final meanY = _mean(ys);
  var covariance = 0.0;
  var variance = 0.0;
  for (var i = 0; i < xs.length; i++) {
    covariance += (xs[i] - meanX) * (ys[i] - meanY);
    variance += (xs[i] - meanX) * (xs[i] - meanX);
  }
  return variance == 0 ? 0 : covariance / variance;
}

/// How a figure runs on weekends against weekdays.
class WeekendGap {
  const WeekendGap({
    required this.weekday,
    required this.weekend,
    required this.weekdays,
    required this.weekends,
  });

  final double weekday;
  final double weekend;
  final int weekdays;
  final int weekends;

  double get difference => weekend - weekday;
}

/// Weekend against weekday average of [days] over [patternWindowDays];
/// null with too few days on either side.
WeekendGap? _weekendGap(List<(DateTime, double)> days, DateTime today) {
  final recent = _within(days, today, patternWindowDays);
  final weekend = [
    for (final (day, value) in recent)
      if (_isWeekend(day)) value,
  ];
  final weekday = [
    for (final (day, value) in recent)
      if (!_isWeekend(day)) value,
  ];
  if (weekend.length < minimumDaysPerSide ||
      weekday.length < minimumDaysPerSide) {
    return null;
  }
  return WeekendGap(
    weekday: _mean(weekday),
    weekend: _mean(weekend),
    weekdays: weekday.length,
    weekends: weekend.length,
  );
}

/// Energy eaten on weekends against weekdays, over complete days; null
/// unless the gap is a tenth of the weekday figure or more.
WeekendGap? weekendIntake(
  List<(DateTime, double)> completeDays,
  DateTime today,
) {
  final gap = _weekendGap(completeDays, today);
  if (gap == null || gap.weekday == 0) return null;
  return (gap.difference / gap.weekday).abs() < _weekendIntakeShare
      ? null
      : gap;
}

/// How much of the weekdays' deficit the weekends take back, as a share;
/// null when weekdays are not in deficit or weekends eat no more.
double? weekendOffset(EnergyBalance balance, WeekendGap intake) {
  final weekdayDeficit = balance.expenditure - intake.weekday;
  if (weekdayDeficit <= 0 || intake.difference <= 0) return null;
  const weekendDays = 2;
  const weekdays = 5;
  return weekendDays * intake.difference / (weekdays * weekdayDeficit);
}

/// Waking time on weekends against weekdays, in minutes after midnight
/// of the day woken; null unless 45 minutes or more apart.
WeekendGap? weekendWake(List<DateTime> wokeAt, DateTime today) {
  final gap = _weekendGap([
    for (final at in wokeAt) (at, (at.hour * 60 + at.minute).toDouble()),
  ], today);
  if (gap == null || gap.difference.abs() < _weekendWakeMinutes) return null;
  return gap;
}

/// Protein eaten for the body weight.
class ProteinIntake {
  const ProteinIntake({
    required this.perKg,
    required this.weightKg,
    required this.days,
    this.trainingDayPerKg,
    this.restDayPerKg,
  });

  /// Grams per kilogram a day, on complete days.
  final double perKg;
  final double weightKg;
  final int days;

  /// The same on days trained and days not, when each has enough days.
  final double? trainingDayPerKg;
  final double? restDayPerKg;

  /// Grams a day short of [proteinTargetPerKg]; zero when there.
  int get shortGrams => perKg >= proteinTargetPerKg
      ? 0
      : ((proteinTargetPerKg - perKg) * weightKg).round();
}

/// Protein over [patternWindowDays] against [weightKg], the trend weight
/// now; null with too few complete days.
ProteinIntake? proteinIntake({
  required List<(DateTime, double)> completeDayGrams,
  required double weightKg,
  required Set<DateTime> trainingDays,
  required DateTime today,
}) {
  final days = _within(completeDayGrams, today, patternWindowDays);
  if (days.length < minimumProteinDays || weightKg <= 0) return null;
  double? perKgOf(bool trained) {
    final grams = [
      for (final (day, value) in days)
        if (trainingDays.contains(_dayOf(day)) == trained) value,
    ];
    return grams.length < minimumDaysPerSide ? null : _mean(grams) / weightKg;
  }

  return ProteinIntake(
    perKg: _mean([for (final (_, grams) in days) grams]) / weightKg,
    weightKg: weightKg,
    days: days.length,
    trainingDayPerKg: perKgOf(true),
    restDayPerKg: perKgOf(false),
  );
}

/// Muscles trained against each other; the second number is how many
/// times more the first side is trained than the second.
enum MusclePair {
  pushPull(
    '推',
    '拉',
    {MuscleGroup.chest, MuscleGroup.frontDelts, MuscleGroup.triceps},
    {
      MuscleGroup.lats,
      MuscleGroup.upperBack,
      MuscleGroup.rearDelts,
      MuscleGroup.biceps,
      MuscleGroup.back,
    },
  ),
  quadsHamstrings('股四頭', '腿後', {MuscleGroup.quads}, {MuscleGroup.hamstrings});

  const MusclePair(this.first, this.second, this.firstSide, this.secondSide);

  final String first;
  final String second;
  final Set<MuscleGroup> firstSide;
  final Set<MuscleGroup> secondSide;
}

/// How training is spread across muscles over the last four weeks.
class TrainingBalance {
  const TrainingBalance({
    required this.enough,
    required this.short,
    required this.imbalances,
  });

  /// Muscles at [weeklySetTarget] sets a week or more, and those trained
  /// but below it, fewest first, with their sets a week.
  final List<(MuscleGroup, int)> enough;
  final List<(MuscleGroup, int)> short;

  /// Pairs where one side gets [_imbalanceRatio] times the other or
  /// more, with that ratio as the larger side against the smaller.
  final List<(MusclePair, int, int)> imbalances;
}

/// Sets a week per muscle, from [weeklySets], judged against the dose
/// for growth and between opposing muscles; null before
/// [minimumBalanceWorkouts] workouts.
TrainingBalance? trainingBalance(
  List<(MuscleGroup, int)> weeklySets,
  int workouts,
) {
  if (workouts < minimumBalanceWorkouts || weeklySets.isEmpty) return null;
  final byMuscle = {for (final (muscle, sets) in weeklySets) muscle: sets};
  int sideSets(Set<MuscleGroup> side) =>
      side.fold(0, (sum, muscle) => sum + (byMuscle[muscle] ?? 0));
  return TrainingBalance(
    enough: [
      for (final entry in weeklySets)
        if (entry.$2 >= weeklySetTarget) entry,
    ],
    short: [
      for (final entry in weeklySets.reversed)
        if (entry.$2 < weeklySetTarget) entry,
    ],
    imbalances: [
      for (final pair in MusclePair.values)
        if ((sideSets(pair.firstSide), sideSets(pair.secondSide))
            case (final a, final b)
            when a > 0 &&
                b > 0 &&
                (a / b >= _imbalanceRatio || b / a >= _imbalanceRatio))
          (pair, a, b),
    ],
  );
}
