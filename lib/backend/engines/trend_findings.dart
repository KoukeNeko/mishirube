import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'body_metrics.dart';

/// What the Trends page says changed, and what it shows moving over the
/// long run (see `research/55-trend-windows.md`). Each figure is set
/// against a baseline on its own time scale: recovery, food and
/// training the latest four weeks against the twelve before, steps the
/// latest 90 days against the year (as Apple Fitness does), estimated
/// maxes eight weeks against eight. Without enough history for that
/// baseline, the four weeks before stand in, and the card says which.
/// A finding is only made when both stretches hold enough records and
/// the change is big enough to matter; otherwise the function returns
/// null and nothing is said. None of it judges a direction as good or
/// bad.
///
/// Bumped whenever a threshold or rule below changes.
const trendFindingsVersion = 2;

/// The latest stretch most figures are read over.
const trendWindowDays = 28;

/// How far back the findings and lines read: a year, for steps.
const trendHistoryDays = 365;

/// Weeks each long-run line draws.
const trendLineWeeks = 26;

/// Nights the latest stretch needs before sleep is compared (and three
/// times that for a twelve-week baseline), and the change worth saying.
const _minimumNights = 14;
const _sleepChangeMinutes = 20;

/// Days of steps four weeks need (about 70% of them), and the change.
const _minimumStepDays = 20;

/// Days of steps the latest 90 need, and the year: half a year of
/// history, as Apple Fitness asks before it shows a trend.
const _minimumStepDaysOf90 = 60;
const _minimumStepDaysOfYear = 180;
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

/// Sessions an exercise needs in each eight weeks, and the change in
/// its best estimated max.
const _minimumStrengthSessions = 2;
const _strengthWindowDays = 56;
const _strengthChangeShare = 0.05;

/// Workouts on each side of the sleep split, and the difference in load.
const _minimumPairs = 5;
const _volumeDifferenceShare = 0.05;

/// A finding: the area it is about, the statement with its evidence,
/// how strongly it cleared its threshold (for ranking), and the same in
/// parts for a card: a short headline, where the figure stands, how it
/// moved, what it was set against, and its weekly values.
typedef TrendFinding = ({
  TrendDomain domain,
  Insight insight,
  double strength,
  String headline,
  String value,
  String change,
  String comparison,
  List<double> weekly,
});

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

/// A latest stretch and the baseline it is set against: the days
/// before it, or, when [baselineIncludesRecent], the longer stretch
/// ending today. Each needs its least number of records.
class _Window {
  const _Window({
    required this.recentDays,
    required this.baselineDays,
    required this.minimumRecent,
    required this.minimumBaseline,
    required this.recentLabel,
    required this.baselineLabel,
    this.baselineIncludesRecent = false,
  });

  /// The latest four weeks against the twelve before, falling back to
  /// the four before when there is not yet the history.
  static List<_Window> weeks(int minimumRecent) => [
    _Window(
      recentDays: trendWindowDays,
      baselineDays: 3 * trendWindowDays,
      minimumRecent: minimumRecent,
      minimumBaseline: 3 * minimumRecent,
      recentLabel: '近 4 週',
      baselineLabel: '前 12 週',
    ),
    _Window(
      recentDays: trendWindowDays,
      baselineDays: trendWindowDays,
      minimumRecent: minimumRecent,
      minimumBaseline: minimumRecent,
      recentLabel: '近 4 週',
      baselineLabel: '前 4 週',
    ),
  ];

  final int recentDays;
  final int baselineDays;
  final bool baselineIncludesRecent;
  final int minimumRecent;
  final int minimumBaseline;
  final String recentLabel;
  final String baselineLabel;

  /// `與前 12 週相比`, or `近 90 天與過去一年相比`.
  String get comparison => baselineIncludesRecent
      ? '$recentLabel與$baselineLabel相比'
      : '與$baselineLabel相比';
}

/// The values of [days] in [window]'s latest stretch up to [today], and
/// in its baseline.
({List<double> recent, List<double> prior}) _stretches(
  List<(DateTime, double)> days,
  DateTime today, [
  _Window window = const _Window(
    recentDays: trendWindowDays,
    baselineDays: trendWindowDays,
    minimumRecent: 0,
    minimumBaseline: 0,
    recentLabel: '近 4 週',
    baselineLabel: '前 4 週',
  ),
]) {
  final end = _dayOf(today);
  final recentStart = end.subtract(Duration(days: window.recentDays - 1));
  final baselineEnd = window.baselineIncludesRecent
      ? end.add(const Duration(days: 1))
      : recentStart;
  final baselineStart = baselineEnd.subtract(
    Duration(days: window.baselineDays),
  );
  return (
    recent: [
      for (final (day, value) in days)
        if (!_dayOf(day).isBefore(recentStart) && !_dayOf(day).isAfter(end))
          value,
    ],
    prior: [
      for (final (day, value) in days)
        if (!_dayOf(day).isBefore(baselineStart) &&
            _dayOf(day).isBefore(baselineEnd))
          value,
    ],
  );
}

/// The first of [windows] whose stretches both hold enough of [days],
/// with their values; null when none does.
({List<double> recent, List<double> prior, _Window window})? _compare(
  List<(DateTime, double)> days,
  DateTime today,
  List<_Window> windows,
) {
  for (final window in windows) {
    final (:recent, :prior) = _stretches(days, today, window);
    if (recent.length >= window.minimumRecent &&
        prior.length >= window.minimumBaseline) {
      return (recent: recent, prior: prior, window: window);
    }
  }
  return null;
}

/// Steps: the latest 90 days against the year once there is half a
/// year of them, else four weeks against the weeks before.
final _stepWindows = [
  const _Window(
    recentDays: 90,
    baselineDays: trendHistoryDays,
    baselineIncludesRecent: true,
    minimumRecent: _minimumStepDaysOf90,
    minimumBaseline: _minimumStepDaysOfYear,
    recentLabel: '近 90 天',
    baselineLabel: '過去一年',
  ),
  ..._Window.weeks(_minimumStepDays),
];

const _strengthWindow = _Window(
  recentDays: _strengthWindowDays,
  baselineDays: _strengthWindowDays,
  minimumRecent: _minimumStrengthSessions,
  minimumBaseline: _minimumStrengthSessions,
  recentLabel: '近 8 週',
  baselineLabel: '前 8 週',
);

double _mean(List<double> values) =>
    values.fold(0.0, (sum, value) => sum + value) / values.length;

String _percent(double share) => '${(share.abs() * 100).round()}%';

/// `+32` or `−0.6`: a change with its sign, a true minus for a fall.
String _signed(double delta, {bool weight = false}) {
  final magnitude = weight
      ? formatWeight(delta.abs())
      : delta.abs().round().toString();
  return '${delta < 0 ? '−' : '+'}$magnitude';
}

String _signedPercent(double share) =>
    '${share < 0 ? '−' : '+'}${_percent(share)}';

String _moreOrLess(double delta) => delta < 0 ? '少' : '多';

String _higherOrLower(double delta) => delta < 0 ? '低' : '高';

String _duration(double minutes) =>
    formatHoursMinutes(Duration(minutes: minutes.round()));

/// Average night asleep, from each night's minutes by the day it ended.
TrendFinding? sleepFinding(List<(DateTime, double)> nights, DateTime today) {
  final compared = _compare(nights, today, _Window.weeks(_minimumNights));
  if (compared == null) return null;
  final (:recent, :prior, :window) = compared;
  final delta = _mean(recent) - _mean(prior);
  if (delta.abs() < _sleepChangeMinutes) return null;
  return (
    domain: TrendDomain.sleep,
    headline: '睡眠時間${delta < 0 ? '減少' : '增加'}',
    value: _duration(_mean(recent)),
    change: '${_signed(delta.round().toDouble())} 分',
    comparison: window.comparison,
    weekly: _weekly(nights, today),
    insight: Insight(
      statement:
          '${window.recentLabel}平均睡眠 ${_duration(_mean(recent))}，'
          '比${window.baselineLabel}${_moreOrLess(delta)} ${delta.abs().round()} 分。',
      evidence: [
        '${window.recentLabel} ${recent.length} 晚、'
            '${window.baselineLabel} ${prior.length} 晚',
        '只計夜間睡眠',
      ],
    ),
    strength: delta.abs() / _sleepChangeMinutes,
  );
}

/// Average daily steps.
TrendFinding? stepsFinding(List<(DateTime, double)> days, DateTime today) {
  final compared = _compare(days, today, _stepWindows);
  if (compared == null) return null;
  final (:recent, :prior, :window) = compared;
  final before = _mean(prior);
  if (before == 0) return null;
  final share = (_mean(recent) - before) / before;
  if (share.abs() < _stepChangeShare) return null;
  return (
    domain: TrendDomain.activity,
    headline: '步數${share < 0 ? '減少' : '增加'}',
    value: '每天 ${formatKcal(_mean(recent).round())} 步',
    change: _signedPercent(share),
    comparison: window.comparison,
    weekly: _weekly(days, today),
    insight: Insight(
      statement:
          '${window.recentLabel}平均每天 ${formatKcal(_mean(recent).round())} 步，'
          '比${window.baselineLabel}${_moreOrLess(share)} ${_percent(share)}。',
      evidence: [
        '${window.recentLabel} ${recent.length} 天、'
            '${window.baselineLabel} ${prior.length} 天有步數',
      ],
    ),
    strength: share.abs() / _stepChangeShare,
  );
}

/// Average resting heart rate.
TrendFinding? restingHeartRateFinding(
  List<(DateTime, double)> days,
  DateTime today,
) {
  final compared = _compare(days, today, _Window.weeks(_minimumHeartRateDays));
  if (compared == null) return null;
  final (:recent, :prior, :window) = compared;
  final delta = _mean(recent) - _mean(prior);
  if (delta.abs() < _restingHeartRateChange) return null;
  return (
    domain: TrendDomain.activity,
    headline: '靜止心率${delta < 0 ? '下降' : '上升'}',
    value: '${_mean(recent).round()} 次/分',
    change: '${_signed(delta.round().toDouble())} 次/分',
    comparison: window.comparison,
    weekly: _weekly(days, today),
    insight: Insight(
      statement:
          '${window.recentLabel}平均靜止心率 ${_mean(recent).round()} 次/分，'
          '比${window.baselineLabel}${_higherOrLower(delta)} ${delta.abs().round()} 次/分。',
      evidence: [
        '${window.recentLabel} ${recent.length} 天、'
            '${window.baselineLabel} ${prior.length} 天有紀錄',
      ],
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
  final compared = _compare(
    completeDays,
    today,
    _Window.weeks(_minimumFoodDays),
  );
  if (compared == null) return null;
  final (:recent, :prior, :window) = compared;
  final before = _mean(prior);
  if (before == 0) return null;
  final share = (_mean(recent) - before) / before;
  if (share.abs() < _intakeChangeShare) return null;
  return (
    domain: TrendDomain.nutrition,
    headline: '攝取熱量${share < 0 ? '減少' : '增加'}',
    value: '${formatKcal(_mean(recent).round())} kcal',
    change: _signedPercent(share),
    comparison: window.comparison,
    weekly: _weekly(completeDays, today),
    insight: Insight(
      statement:
          '${window.recentLabel}平均每天吃 ${formatKcal(_mean(recent).round())} kcal，'
          '比${window.baselineLabel}${_moreOrLess(share)} ${_percent(share)}。',
      evidence: [
        '只計紀錄完整的日子',
        '${window.recentLabel} ${recent.length} 天、'
            '${window.baselineLabel} ${prior.length} 天',
      ],
    ),
    strength: share.abs() / _intakeChangeShare,
  );
}

/// Days the trend weight is also read back over, for the longer view
/// beside the four weeks.
const _weightLongDays = 90;

/// How far the trend weight moved over the latest four weeks: weight is
/// read by its change, not its average. Beside it, how far it moved
/// over 90 days, when it was weighed that far back.
TrendFinding? weightFinding(List<BodyWeight> weights, DateTime today) {
  final trend = [for (final (at, _, value) in trendOf(weights)) (at, value)];
  final (:recent, prior: _) = _stretches(trend, today);
  if (recent.length < _minimumWeighings) return null;
  final change = recent.last - recent.first;
  if (change.abs() < _weightChangeKg) return null;
  final direction = change < 0 ? '下降' : '上升';
  final longStart = _dayOf(today)
      .subtract(const Duration(days: _weightLongDays - 1));
  final long = [
    for (final (at, value) in trend)
      if (!_dayOf(at).isBefore(longStart)) (at, value),
  ];
  final longChange =
      long.isNotEmpty &&
          !_dayOf(
            long.first.$1,
          ).isAfter(longStart.add(const Duration(days: DateTime.daysPerWeek)))
      ? long.last.$2 - long.first.$2
      : null;
  return (
    domain: TrendDomain.body,
    headline: '趨勢體重$direction',
    value: '${formatWeight(_round(recent.last))} kg',
    change: '4 週 ${_signed(_round(change), weight: true)} kg',
    comparison: longChange == null
        ? '近 4 週變化'
        : '近 90 天 ${_signed(_round(longChange), weight: true)} kg',
    weekly: _weekly(trend, today),
    insight: Insight(
      statement:
          '趨勢體重近 4 週$direction ${formatWeight(_round(change.abs()))} kg'
          '${longChange == null ? '' : '，近 90 天${longChange < 0 ? '下降' : '上升'} ${formatWeight(_round(longChange.abs()))} kg'}。',
      evidence: ['近 4 週 ${recent.length} 次量測', '趨勢體重為 7 天平均'],
    ),
    strength: change.abs() / _weightChangeKg,
  );
}

double _round(double kilograms) => (kilograms * 10).round() / 10;

/// The longest of the four-week windows that training goes back far
/// enough to fill: a week without a workout counts as none, but only
/// once training had begun.
_Window? _trainingWindow(List<DateTime> starts, DateTime today) {
  if (starts.isEmpty) return null;
  final first = _dayOf(starts.reduce((a, b) => a.isBefore(b) ? a : b));
  final end = _dayOf(today);
  return [
    for (final window in _Window.weeks(0))
      if (!first.isAfter(
        end.subtract(
          Duration(days: window.recentDays + window.baselineDays - 1),
        ),
      ))
        window,
  ].firstOrNull;
}

/// Training sessions a week, the latest four weeks against the twelve
/// before, or the four before while training goes back less far.
TrendFinding? trainingFinding(List<DateTime> starts, DateTime today) {
  final window = _trainingWindow(starts, today);
  if (window == null) return null;
  final (:recent, :prior) = _stretches(
    [for (final start in starts) (start, 1.0)],
    today,
    window,
  );
  final now = recent.length / (window.recentDays / DateTime.daysPerWeek);
  final before = prior.length / (window.baselineDays / DateTime.daysPerWeek);
  final delta = now - before;
  if (prior.isEmpty || delta.abs() < _trainingChangePerWeek) return null;
  return (
    domain: TrendDomain.training,
    headline: '訓練次數${delta < 0 ? '減少' : '增加'}',
    value: '每週 ${now.toStringAsFixed(1)} 次',
    change: '${window.baselineLabel} ${before.toStringAsFixed(1)} 次',
    comparison: window.comparison,
    weekly: _weeklyCounts(starts, today),
    insight: Insight(
      statement:
          '${window.recentLabel}平均每週訓練 ${now.toStringAsFixed(1)} 次，'
          '${window.baselineLabel} ${before.toStringAsFixed(1)} 次。',
      evidence: [
        '${window.recentLabel} ${recent.length} 次、'
            '${window.baselineLabel} ${prior.length} 次',
      ],
    ),
    strength: delta.abs() / _trainingChangePerWeek,
  );
}

/// The exercise whose best estimated max moved most between the latest
/// eight weeks and the eight before, among those trained in both:
/// strength moves over months, not weeks.
TrendFinding? strengthFinding(
  List<(String, ExerciseHistory)> exercises,
  DateTime today,
) {
  TrendFinding? strongest;
  for (final (name, history) in exercises) {
    final maxes = [
      for (final entry in history.recent)
        if (entry.oneRepMaxKg case final max?) (entry.date, max),
    ];
    final compared = _compare(maxes, today, const [_strengthWindow]);
    if (compared == null) continue;
    final (:recent, :prior, :window) = compared;
    double best(List<double> values) => values.reduce((a, b) => a > b ? a : b);
    final share = (best(recent) - best(prior)) / best(prior);
    if (share.abs() < _strengthChangeShare) continue;
    final strength = share.abs() / _strengthChangeShare;
    if (strongest != null && strongest.strength >= strength) continue;
    strongest = (
      domain: TrendDomain.training,
      headline: '$name估計最大重量${share < 0 ? '下降' : '上升'}',
      value: '${formatWeight(_round(best(recent)))} kg',
      change: _signedPercent(share),
      comparison: window.comparison,
      weekly: _weekly(maxes, today, reduce: best),
      insight: Insight(
        statement:
            '$name估計最大重量${window.recentLabel} ${formatWeight(_round(best(recent)))} kg，'
            '比${window.baselineLabel}${_higherOrLower(share)} ${_percent(share)}。',
        evidence: [
          '${window.recentLabel} ${recent.length} 次、'
              '${window.baselineLabel} ${prior.length} 次訓練',
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

/// Weekly averages of [days] (or what [reduce] makes of each week) over
/// the last [trendLineWeeks] weeks up to [today], skipping weeks without
/// records.
List<double> _weekly(
  List<(DateTime, double)> days,
  DateTime today, {
  double Function(List<double> values) reduce = _mean,
}) {
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
  return [for (final key in keys) reduce(weeks[key]!)];
}

/// How many of [times] fell in each of the last [trendLineWeeks] weeks
/// up to [today], from the first week with one: the weeks before any
/// record are not weeks of zero.
List<double> _weeklyCounts(List<DateTime> times, DateTime today) {
  final end = _dayOf(today);
  final start = end.subtract(
    const Duration(days: trendLineWeeks * DateTime.daysPerWeek - 1),
  );
  final perWeek = List<double>.filled(trendLineWeeks, 0);
  for (final time in times) {
    final date = _dayOf(time);
    if (date.isBefore(start) || date.isAfter(end)) continue;
    perWeek[date.difference(start).inDays ~/ 7]++;
  }
  final first = perWeek.indexWhere((count) => count > 0);
  return first < 0 ? const [] : perWeek.sublist(first);
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

/// Sessions a week over the latest four weeks, against the baseline
/// training goes back far enough for; null without one.
TrendLine? trainingLine(List<DateTime> starts, DateTime today) {
  final counted = [for (final start in starts) (start, 1.0)];
  final (:recent, prior: _) = _stretches(counted, today);
  if (recent.isEmpty) return null;
  const weeks = trendWindowDays / DateTime.daysPerWeek;
  final window = _trainingWindow(starts, today);
  final prior = window == null
      ? null
      : _stretches(counted, today, window).prior.length /
            (window.baselineDays / DateTime.daysPerWeek);
  return TrendLine(
    domain: TrendDomain.training,
    value: '每週 ${(recent.length / weeks).toStringAsFixed(1)} 次',
    change: prior == null
        ? null
        : '${window!.baselineLabel} ${prior.toStringAsFixed(1)} 次',
    weekly: _weeklyCounts(starts, today),
  );
}

/// `比前 12 週`, or `近 90 天比過去一年`: what a line's change is set
/// against.
String _against(_Window window) => window.baselineIncludesRecent
    ? '${window.recentLabel}比${window.baselineLabel}'
    : '比${window.baselineLabel}';

/// The average night over the latest four weeks; null without one.
TrendLine? sleepLine(List<(DateTime, double)> nights, DateTime today) {
  final (:recent, prior: _) = _stretches(nights, today);
  if (recent.isEmpty) return null;
  final compared = _compare(nights, today, _Window.weeks(1));
  final delta = compared == null
      ? null
      : _mean(compared.recent) - _mean(compared.prior);
  return TrendLine(
    domain: TrendDomain.sleep,
    value: '平均 ${_duration(_mean(recent))}',
    change: delta == null
        ? null
        : '${_against(compared!.window)}${_moreOrLess(delta)} ${delta.abs().round()} 分',
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

/// Average daily steps over the steps' window, against its baseline;
/// null without any.
TrendLine? activityLine(List<(DateTime, double)> steps, DateTime today) {
  final compared =
      _compare(steps, today, [..._stepWindows, ..._Window.weeks(1)]) ??
      _compare(steps, today, [
        const _Window(
          recentDays: trendWindowDays,
          baselineDays: trendWindowDays,
          minimumRecent: 1,
          minimumBaseline: 0,
          recentLabel: '近 4 週',
          baselineLabel: '前 4 週',
        ),
      ]);
  if (compared == null) return null;
  final (:recent, :prior, :window) = compared;
  final before = prior.isEmpty ? null : _mean(prior);
  final share = before == null || before == 0
      ? null
      : (_mean(recent) - before) / before;
  return TrendLine(
    domain: TrendDomain.activity,
    value: '每天 ${formatKcal(_mean(recent).round())} 步',
    change: share == null
        ? null
        : '${_against(window)}${_moreOrLess(share)} ${_percent(share)}',
    weekly: _weekly(steps, today),
  );
}
