import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'body_metrics.dart';

/// What the Trends page says changed, and what it shows moving over the
/// long run. Every finding compares the latest [trendWindowDays] with the
/// same stretch before it, and is only made when both stretches hold
/// enough records and the change is big enough to matter; otherwise the
/// function returns null and nothing is said. None of it judges a
/// direction as good or bad.
///
/// Bumped whenever a threshold or rule below changes.
const trendFindingsVersion = 1;

/// The stretch compared, and the one before it.
const trendWindowDays = 28;

/// Weeks each long-run line draws.
const trendLineWeeks = 12;

/// Nights each stretch needs before sleep is compared, and the change
/// worth saying.
const _minimumNights = 14;
const _sleepChangeMinutes = 20;

/// Days of steps each stretch needs (about 70% of it), and the change.
const _minimumStepDays = 20;
const _stepChangeShare = 0.1;

const _minimumHeartRateDays = 14;
const _restingHeartRateChange = 3.0;

/// Complete food days each stretch needs, and the change in energy.
const _minimumFoodDays = 14;
const _intakeChangeShare = 0.1;

/// Weighings the latest stretch needs (three a week), and the change in
/// the trend weight.
const _minimumWeighings = 12;
const _weightChangeKg = 0.5;

const _trainingChangePerWeek = 1.0;

/// Sessions an exercise needs in each stretch, and the change in its
/// best estimated max.
const _minimumStrengthSessions = 2;
const _strengthChangeShare = 0.05;

/// Workouts on each side of the sleep split, and the difference in load.
const _minimumPairs = 5;
const _volumeDifferenceShare = 0.05;

/// A finding, the area it is about, and how strongly it cleared its
/// threshold, for ranking.
typedef TrendFinding = ({TrendDomain domain, Insight insight, double strength});

/// The areas the long-run lines cover, in the order they are listed.
enum TrendDomain {
  body('身體'),
  training('訓練'),
  sleep('睡眠'),
  nutrition('飲食'),
  activity('活動');

  const TrendDomain(this.label);

  final String label;
}

/// One area over the long run: where it stands over the latest stretch,
/// how that compares with the stretch before, and its weekly values.
class TrendLine {
  const TrendLine({
    required this.domain,
    required this.value,
    required this.weekly,
    this.change,
  });

  final TrendDomain domain;
  final String value;

  /// Against the stretch before; null when that stretch has no records.
  final String? change;

  /// One value per week with records, oldest first.
  final List<double> weekly;
}

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);

/// The values of [days] in the latest [trendWindowDays] up to [today],
/// and in the stretch before.
({List<double> recent, List<double> prior}) _stretches(
  List<(DateTime, double)> days,
  DateTime today,
) {
  final end = _dayOf(today);
  final recentStart = end.subtract(const Duration(days: trendWindowDays - 1));
  final priorStart = recentStart.subtract(
    const Duration(days: trendWindowDays),
  );
  return (
    recent: [
      for (final (day, value) in days)
        if (!_dayOf(day).isBefore(recentStart) && !_dayOf(day).isAfter(end))
          value,
    ],
    prior: [
      for (final (day, value) in days)
        if (!_dayOf(day).isBefore(priorStart) &&
            _dayOf(day).isBefore(recentStart))
          value,
    ],
  );
}

double _mean(List<double> values) =>
    values.fold(0.0, (sum, value) => sum + value) / values.length;

String _percent(double share) => '${(share.abs() * 100).round()}%';

String _moreOrLess(double delta) => delta < 0 ? '少' : '多';

String _higherOrLower(double delta) => delta < 0 ? '低' : '高';

String _duration(double minutes) =>
    formatHoursMinutes(Duration(minutes: minutes.round()));

/// Average night asleep, from each night's minutes by the day it ended.
TrendFinding? sleepFinding(List<(DateTime, double)> nights, DateTime today) {
  final (:recent, :prior) = _stretches(nights, today);
  if (recent.length < _minimumNights || prior.length < _minimumNights) {
    return null;
  }
  final delta = _mean(recent) - _mean(prior);
  if (delta.abs() < _sleepChangeMinutes) return null;
  return (
    domain: TrendDomain.sleep,
    insight: Insight(
      statement:
          '近 4 週平均睡眠 ${_duration(_mean(recent))}，'
          '比前 4 週${_moreOrLess(delta)} ${delta.abs().round()} 分。',
      evidence: ['近 4 週 ${recent.length} 晚、前 4 週 ${prior.length} 晚', '只計夜間睡眠'],
    ),
    strength: delta.abs() / _sleepChangeMinutes,
  );
}

/// Average daily steps.
TrendFinding? stepsFinding(List<(DateTime, double)> days, DateTime today) {
  final (:recent, :prior) = _stretches(days, today);
  if (recent.length < _minimumStepDays || prior.length < _minimumStepDays) {
    return null;
  }
  final before = _mean(prior);
  if (before == 0) return null;
  final share = (_mean(recent) - before) / before;
  if (share.abs() < _stepChangeShare) return null;
  return (
    domain: TrendDomain.activity,
    insight: Insight(
      statement:
          '近 4 週平均每天 ${formatKcal(_mean(recent).round())} 步，'
          '比前 4 週${_moreOrLess(share)} ${_percent(share)}。',
      evidence: ['近 4 週 ${recent.length} 天、前 4 週 ${prior.length} 天有步數'],
    ),
    strength: share.abs() / _stepChangeShare,
  );
}

/// Average resting heart rate.
TrendFinding? restingHeartRateFinding(
  List<(DateTime, double)> days,
  DateTime today,
) {
  final (:recent, :prior) = _stretches(days, today);
  if (recent.length < _minimumHeartRateDays ||
      prior.length < _minimumHeartRateDays) {
    return null;
  }
  final delta = _mean(recent) - _mean(prior);
  if (delta.abs() < _restingHeartRateChange) return null;
  return (
    domain: TrendDomain.activity,
    insight: Insight(
      statement:
          '近 4 週平均靜止心率 ${_mean(recent).round()} 次/分，'
          '比前 4 週${_higherOrLower(delta)} ${delta.abs().round()} 次/分。',
      evidence: ['近 4 週 ${recent.length} 天、前 4 週 ${prior.length} 天有紀錄'],
    ),
    strength: delta.abs() / _restingHeartRateChange,
  );
}

/// Average energy eaten, over complete days only: a day with meals
/// missing would read as eating less.
TrendFinding? intakeFinding(
  List<(DateTime, double)> completeDays,
  DateTime today,
) {
  final (:recent, :prior) = _stretches(completeDays, today);
  if (recent.length < _minimumFoodDays || prior.length < _minimumFoodDays) {
    return null;
  }
  final before = _mean(prior);
  if (before == 0) return null;
  final share = (_mean(recent) - before) / before;
  if (share.abs() < _intakeChangeShare) return null;
  return (
    domain: TrendDomain.nutrition,
    insight: Insight(
      statement:
          '近 4 週平均每天吃 ${formatKcal(_mean(recent).round())} kcal，'
          '比前 4 週${_moreOrLess(share)} ${_percent(share)}。',
      evidence: [
        '只計紀錄完整的日子',
        '近 4 週 ${recent.length} 天、前 4 週 ${prior.length} 天',
      ],
    ),
    strength: share.abs() / _intakeChangeShare,
  );
}

/// How far the trend weight moved over the latest stretch, and over the
/// one before when that one was weighed often enough to say.
TrendFinding? weightFinding(List<BodyWeight> weights, DateTime today) {
  final trend = [for (final (at, _, value) in trendOf(weights)) (at, value)];
  final (:recent, :prior) = _stretches(trend, today);
  if (recent.length < _minimumWeighings) return null;
  final change = recent.last - recent.first;
  if (change.abs() < _weightChangeKg) return null;
  final direction = change < 0 ? '下降' : '上升';
  final before = prior.length >= _minimumWeighings
      ? prior.last - prior.first
      : null;
  return (
    domain: TrendDomain.body,
    insight: Insight(
      statement:
          '趨勢體重近 4 週$direction ${formatWeight(_round(change.abs()))} kg'
          '${before == null ? '' : '，前 4 週${before < 0 ? '下降' : '上升'} ${formatWeight(_round(before.abs()))} kg'}。',
      evidence: ['近 4 週 ${recent.length} 次量測', '趨勢體重為 7 天平均'],
    ),
    strength: change.abs() / _weightChangeKg,
  );
}

double _round(double kilograms) => (kilograms * 10).round() / 10;

/// Training sessions a week.
TrendFinding? trainingFinding(List<DateTime> starts, DateTime today) {
  final counted = [for (final start in starts) (start, 1.0)];
  final (:recent, :prior) = _stretches(counted, today);
  if (recent.isEmpty && prior.isEmpty) return null;
  const weeks = trendWindowDays / DateTime.daysPerWeek;
  final now = recent.length / weeks;
  final before = prior.length / weeks;
  final delta = now - before;
  if (prior.isEmpty || delta.abs() < _trainingChangePerWeek) return null;
  return (
    domain: TrendDomain.training,
    insight: Insight(
      statement:
          '近 4 週平均每週訓練 ${now.toStringAsFixed(1)} 次，'
          '前 4 週 ${before.toStringAsFixed(1)} 次。',
      evidence: ['近 4 週 ${recent.length} 次、前 4 週 ${prior.length} 次'],
    ),
    strength: delta.abs() / _trainingChangePerWeek,
  );
}

/// The exercise whose best estimated max moved most between the two
/// stretches, among those trained in both.
TrendFinding? strengthFinding(
  List<(String, ExerciseHistory)> exercises,
  DateTime today,
) {
  TrendFinding? strongest;
  for (final (name, history) in exercises) {
    final (:recent, :prior) = _stretches([
      for (final entry in history.recent)
        if (entry.oneRepMaxKg case final max?) (entry.date, max),
    ], today);
    if (recent.length < _minimumStrengthSessions ||
        prior.length < _minimumStrengthSessions) {
      continue;
    }
    double best(List<double> values) => values.reduce((a, b) => a > b ? a : b);
    final share = (best(recent) - best(prior)) / best(prior);
    if (share.abs() < _strengthChangeShare) continue;
    final strength = share.abs() / _strengthChangeShare;
    if (strongest != null && strongest.strength >= strength) continue;
    strongest = (
      domain: TrendDomain.training,
      insight: Insight(
        statement:
            '$name估計最大重量近 4 週 ${formatWeight(_round(best(recent)))} kg，'
            '比前 4 週${_higherOrLower(share)} ${_percent(share)}。',
        evidence: [
          '近 4 週 ${recent.length} 次、前 4 週 ${prior.length} 次訓練',
          'Epley 估計，非實測',
        ],
      ),
      strength: strength,
    );
  }
  return strongest;
}

/// Whether workouts after a longer night moved more load than those
/// after a shorter one. Each workout's load is taken against the average
/// of workouts with the same name, so a leg day is not set against an
/// arm day; nights are split at their median. A relation, not a cause.
Insight? sleepAndTrainingInsight(
  Map<DateTime, double> nightMinutesByDay,
  List<(DateTime, String, double)> workouts,
) {
  final byName = <String, List<double>>{};
  for (final (_, name, volume) in workouts) {
    if (volume > 0) byName.putIfAbsent(name, () => []).add(volume);
  }
  final pairs = [
    for (final (start, name, volume) in workouts)
      if (volume > 0 && byName[name]!.length >= 2)
        if (nightMinutesByDay[_dayOf(start)] case final minutes?)
          (minutes, volume / _mean(byName[name]!)),
  ];
  if (pairs.length < _minimumPairs * 2) return null;
  final sorted = [for (final (minutes, _) in pairs) minutes]..sort();
  final median = sorted[sorted.length ~/ 2];
  final longer = [
    for (final (minutes, load) in pairs)
      if (minutes >= median) load,
  ];
  final shorter = [
    for (final (minutes, load) in pairs)
      if (minutes < median) load,
  ];
  if (longer.length < _minimumPairs || shorter.length < _minimumPairs) {
    return null;
  }
  final difference = _mean(longer) - _mean(shorter);
  if (difference.abs() < _volumeDifferenceShare) return null;
  return Insight(
    statement:
        '前一晚睡得較久的訓練，訓練量平均'
        '${_moreOrLess(difference)} ${_percent(difference)}。',
    evidence: [
      '${pairs.length} 次訓練',
      '以 ${_duration(median)} 區分睡得較久或較少',
      '與同一訓練的平均相比',
      '關聯，不代表因果',
    ],
  );
}

/// Weekly averages of [days] over the last [trendLineWeeks] weeks up to
/// [today], skipping weeks without records.
List<double> _weekly(List<(DateTime, double)> days, DateTime today) {
  final end = _dayOf(today);
  final start = end.subtract(
    const Duration(days: trendLineWeeks * DateTime.daysPerWeek - 1),
  );
  final weeks = <int, List<double>>{};
  for (final (day, value) in days) {
    final date = _dayOf(day);
    if (date.isBefore(start) || date.isAfter(end)) continue;
    weeks.putIfAbsent(date.difference(start).inDays ~/ 7, () => []).add(value);
  }
  final keys = weeks.keys.toList()..sort();
  return [for (final key in keys) _mean(weeks[key]!)];
}

/// The trend weight where it stands, and how far it moved over the
/// latest stretch; null without a weighing in it.
TrendLine? bodyLine(List<BodyWeight> weights, DateTime today) {
  final trend = [for (final (at, _, value) in trendOf(weights)) (at, value)];
  final (:recent, prior: _) = _stretches(trend, today);
  if (recent.isEmpty) return null;
  final change = recent.last - recent.first;
  return TrendLine(
    domain: TrendDomain.body,
    value: '${formatWeight(_round(recent.last))} kg',
    change: recent.length < 2
        ? null
        : '4 週 ${change < 0 ? '−' : '+'}${formatWeight(_round(change.abs()))} kg',
    weekly: _weekly(trend, today),
  );
}

/// Sessions a week over the latest stretch; null without one.
TrendLine? trainingLine(List<DateTime> starts, DateTime today) {
  final counted = [for (final start in starts) (start, 1.0)];
  final (:recent, :prior) = _stretches(counted, today);
  if (recent.isEmpty) return null;
  const weeks = trendWindowDays / DateTime.daysPerWeek;
  final end = _dayOf(today);
  final start = end.subtract(
    const Duration(days: trendLineWeeks * DateTime.daysPerWeek - 1),
  );
  final perWeek = List<double>.filled(trendLineWeeks, 0);
  for (final day in starts) {
    final date = _dayOf(day);
    if (date.isBefore(start) || date.isAfter(end)) continue;
    perWeek[date.difference(start).inDays ~/ 7]++;
  }
  return TrendLine(
    domain: TrendDomain.training,
    value: '每週 ${(recent.length / weeks).toStringAsFixed(1)} 次',
    change: prior.isEmpty
        ? null
        : '前 4 週 ${(prior.length / weeks).toStringAsFixed(1)} 次',
    weekly: perWeek,
  );
}

/// The average night over the latest stretch; null without one.
TrendLine? sleepLine(List<(DateTime, double)> nights, DateTime today) {
  final (:recent, :prior) = _stretches(nights, today);
  if (recent.isEmpty) return null;
  final delta = prior.isEmpty ? null : _mean(recent) - _mean(prior);
  return TrendLine(
    domain: TrendDomain.sleep,
    value: '平均 ${_duration(_mean(recent))}',
    change: delta == null
        ? null
        : '比前 4 週${_moreOrLess(delta)} ${delta.abs().round()} 分',
    weekly: _weekly(nights, today),
  );
}

/// Energy eaten on complete days, and how many days were complete;
/// null without a food record in the latest stretch.
TrendLine? nutritionLine(
  List<(DateTime, double)> completeDays,
  int daysTracked,
  DateTime today,
) {
  if (daysTracked == 0) return null;
  final (:recent, prior: _) = _stretches(completeDays, today);
  return TrendLine(
    domain: TrendDomain.nutrition,
    value: recent.isEmpty
        ? '完整 0/$daysTracked 天'
        : '平均 ${formatKcal(_mean(recent).round())} kcal',
    change: recent.isEmpty ? null : '完整 ${recent.length}/$daysTracked 天',
    weekly: _weekly(completeDays, today),
  );
}

/// Average daily steps over the latest stretch; null without any.
TrendLine? activityLine(List<(DateTime, double)> steps, DateTime today) {
  final (:recent, :prior) = _stretches(steps, today);
  if (recent.isEmpty) return null;
  final before = prior.isEmpty ? null : _mean(prior);
  final share = before == null || before == 0
      ? null
      : (_mean(recent) - before) / before;
  return TrendLine(
    domain: TrendDomain.activity,
    value: '每天 ${formatKcal(_mean(recent).round())} 步',
    change: share == null
        ? null
        : '比前 4 週${_moreOrLess(share)} ${_percent(share)}',
    weekly: _weekly(steps, today),
  );
}
