import '../../domain/domain.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/format.dart';
import 'body_metrics.dart';

/// Each area's long-run line on the Trends page, and the relation
/// between sleep and training (see `research/55-trend-windows.md`).
/// Each line sets its latest stretch against a baseline on its own time
/// scale: sleep and training the latest four weeks against the twelve
/// before, steps the latest 90 days against the year (as Apple Fitness
/// does). Without enough history for that baseline, the four weeks
/// before stand in, and the line says which. None of it judges a
/// direction as good or bad.
///
/// Bumped whenever a threshold or rule below changes.
const trendFindingsVersion = 3;

/// The latest stretch most figures are read over.
const trendWindowDays = 28;

/// How far back the lines read: a year, for steps.
const trendHistoryDays = 365;

/// Weeks each long-run line draws.
const trendLineWeeks = 26;

/// Records the latest four weeks need before a line sets them against
/// a baseline, and three times that for a twelve-week one: a week's
/// worth, so a line compares stretches rather than a handful of days.
const _minimumLineDays = 7;

/// Days of steps four weeks need (about 70% of them).
const _minimumStepDays = 20;

/// Days of steps the latest 90 need, and the year: half a year of
/// history, as Apple Fitness asks before it shows a trend.
const _minimumStepDaysOf90 = 60;
const _minimumStepDaysOfYear = 180;

/// Workouts on each side of the sleep split, and the difference in load.
const _minimumPairs = 5;
const _volumeDifferenceShare = 0.05;

/// The areas the long-run lines cover, in the order they are listed.
enum TrendDomain { body, training, sleep, nutrition, activity }

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

  /// One value per week from the first with records, oldest first; a
  /// week without records since then is null, a gap rather than a zero.
  final List<double?> weekly;
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
    required this.recent,
    required this.baseline,
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
      recent: _Span.last4Weeks,
      baseline: _Span.prior12Weeks,
    ),
    _Window(
      recentDays: trendWindowDays,
      baselineDays: trendWindowDays,
      minimumRecent: minimumRecent,
      minimumBaseline: minimumRecent,
      recent: _Span.last4Weeks,
      baseline: _Span.prior4Weeks,
    ),
  ];

  final int recentDays;
  final int baselineDays;
  final bool baselineIncludesRecent;
  final int minimumRecent;
  final int minimumBaseline;
  final _Span recent;
  final _Span baseline;
}

/// The stretches a trend is read over.
enum _Span {
  last4Weeks,
  prior4Weeks,
  prior12Weeks,
  last90Days,
  pastYear;

  String labelIn(AppLocalizations l10n) => switch (this) {
    last4Weeks => l10n.last4Weeks,
    prior4Weeks => l10n.prior4Weeks,
    prior12Weeks => l10n.prior12Weeks,
    last90Days => l10n.last90Days,
    pastYear => l10n.pastYear,
  };
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
    recent: _Span.last4Weeks,
    baseline: _Span.prior4Weeks,
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
    recent: _Span.last90Days,
    baseline: _Span.pastYear,
  ),
  ..._Window.weeks(_minimumStepDays),
];

double _mean(List<double> values) =>
    values.fold(0.0, (sum, value) => sum + value) / values.length;

String _percent(double share) => '${(share.abs() * 100).round()}%';

/// [amount] more or less than [window]'s baseline, as [delta] has it.
String _change(
  AppLocalizations l10n,
  _Window window,
  double delta,
  String amount,
) => (delta < 0 ? l10n.changeLess : l10n.changeMore)(
  against: _against(l10n, window),
  amount: amount,
);

String _duration(AppLocalizations l10n, double minutes) =>
    formatDuration(l10n, Duration(minutes: minutes.round()));

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

/// Whether workouts after a longer night moved more load than those
/// after a shorter one. Each workout's load is taken against the average
/// of workouts with the same name, so a leg day is not set against an
/// arm day; nights are split at their median. A relation, not a cause.
Insight? sleepAndTrainingInsight(
  AppLocalizations l10n,
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
    kind: InsightKind.sleepAndTraining,
    statement: (difference < 0 ? l10n.sleepLoadLess : l10n.sleepLoadMore)(
      percent: _percent(difference),
    ),
    evidence: [
      l10n.workoutsCount(count: pairs.length),
      l10n.sleepSplitAt(time: _duration(l10n, median)),
      l10n.againstSameWorkout,
      l10n.correlationCaveat,
    ],
  );
}

/// Weekly averages of [days] (or what [reduce] makes of each week) over
/// the last [trendLineWeeks] weeks up to [today], from the first week
/// with records; a week without any after it is null.
List<double?> _weekly(
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
  if (weeks.isEmpty) return const [];
  final first = weeks.keys.reduce((a, b) => a < b ? a : b);
  return [
    for (var week = first; week < trendLineWeeks; week++)
      if (weeks[week] case final values?) reduce(values) else null,
  ];
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
TrendLine? bodyLine(
  AppLocalizations l10n,
  List<BodyWeight> weights,
  DateTime today,
) {
  final trend = [for (final (at, _, value) in trendOf(weights)) (at, value)];
  final (:recent, prior: _) = _stretches(trend, today);
  if (recent.isEmpty) return null;
  final change = recent.last - recent.first;
  return TrendLine(
    domain: TrendDomain.body,
    value: '${formatWeight(_round(recent.last))} kg',
    change: recent.length < 2
        ? null
        : l10n.weightChange4Weeks(
            change:
                '${change < 0 ? '−' : '+'}${formatWeight(_round(change.abs()))}',
          ),
    weekly: _weekly(trend, today),
  );
}

/// Sessions a week over the latest four weeks, against the baseline
/// training goes back far enough for; null without one.
TrendLine? trainingLine(
  AppLocalizations l10n,
  List<DateTime> starts,
  DateTime today,
) {
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
    value: l10n.perWeekTimes(count: (recent.length / weeks).toStringAsFixed(1)),
    change: prior == null
        ? null
        : l10n.baselineTimes(
            baseline: window!.baseline.labelIn(l10n),
            count: prior.toStringAsFixed(1),
          ),
    weekly: _weeklyCounts(starts, today),
  );
}

/// `比前 12 週`, or `近 90 天比過去一年`: what a line's change is set
/// against.
String _against(AppLocalizations l10n, _Window window) =>
    window.baselineIncludesRecent
    ? l10n.againstRecentBaseline(
        recent: window.recent.labelIn(l10n),
        baseline: window.baseline.labelIn(l10n),
      )
    : l10n.againstBaseline(baseline: window.baseline.labelIn(l10n));

/// The average night over the latest four weeks; null without one.
TrendLine? sleepLine(
  AppLocalizations l10n,
  List<(DateTime, double)> nights,
  DateTime today,
) {
  final (:recent, prior: _) = _stretches(nights, today);
  if (recent.isEmpty) return null;
  final compared = _compare(nights, today, _Window.weeks(_minimumLineDays));
  final delta = compared == null
      ? null
      : _mean(compared.recent) - _mean(compared.prior);
  return TrendLine(
    domain: TrendDomain.sleep,
    value: l10n.statAverage(value: _duration(l10n, _mean(recent))),
    change: delta == null
        ? null
        : _change(
            l10n,
            compared!.window,
            delta,
            l10n.durationMinutes(minutes: delta.abs().round()),
          ),
    weekly: _weekly(nights, today),
  );
}

/// Energy eaten on complete days, and how many days were complete;
/// null without a food record in the latest stretch.
TrendLine? nutritionLine(
  AppLocalizations l10n,
  List<(DateTime, double)> completeDays,
  int daysTracked,
  DateTime today,
) {
  if (daysTracked == 0) return null;
  final (:recent, prior: _) = _stretches(completeDays, today);
  return TrendLine(
    domain: TrendDomain.nutrition,
    value: recent.isEmpty
        ? l10n.completeDays(complete: 0, tracked: daysTracked)
        : l10n.statAverage(value: '${formatKcal(_mean(recent).round())} kcal'),
    change: recent.isEmpty
        ? null
        : l10n.completeDays(complete: recent.length, tracked: daysTracked),
    weekly: _weekly(completeDays, today),
  );
}

/// Average daily steps over the steps' window, against its baseline;
/// null without any.
TrendLine? activityLine(
  AppLocalizations l10n,
  List<(DateTime, double)> steps,
  DateTime today,
) {
  final compared =
      _compare(steps, today, [
        ..._stepWindows,
        ..._Window.weeks(_minimumLineDays),
      ]) ??
      _compare(steps, today, [
        const _Window(
          recentDays: trendWindowDays,
          baselineDays: trendWindowDays,
          minimumRecent: 1,
          minimumBaseline: 0,
          recent: _Span.last4Weeks,
          baseline: _Span.prior4Weeks,
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
    value: l10n.perDaySteps(steps: formatKcal(_mean(recent).round())),
    change: share == null
        ? null
        : _change(l10n, window, share, _percent(share)),
    weekly: _weekly(steps, today),
  );
}
