import '../../domain/domain.dart';
import 'trend_engine.dart';

/// Bumped whenever a rule below changes, so an insight can say which
/// version produced it.
const insightEngineVersion = 1;

/// Weekly weight changes smaller than this are noise, not a trend.
const _steadyWeightKgPerWeek = 0.1;

/// A drop in weekly sets worth mentioning.
const _meaningfulVolumeDrop = 0.2;

/// Days of the window that must hold a measurement for the data to count
/// as complete.
const _completeShare = 0.8;

/// Insights are deterministic: same records in, same wording out, and
/// nothing is stated that the records cannot support. When there is too
/// little data the engine returns null rather than guessing.
///
/// Every insight carries its evidence: what it was computed from, how
/// complete that data is, and the window it covers.

/// Where the weight is heading over [trend]'s window.
Insight? weightTrendInsight(MeasurementTrend trend, {required int dayCount}) {
  final perWeek = trend.changePerWeek;
  if (perWeek == null) return null;
  final size = perWeek.abs();
  final direction = perWeek < 0 ? '下降' : '上升';
  final statement = size < _steadyWeightKgPerWeek
      ? '體重在這段期間大致持平，沒有明顯變化。'
      : '體重以每週約 ${size.toStringAsFixed(1)} kg 的速度$direction。';
  return Insight(
    statement: statement,
    evidence: [
      '依據 ${trend.values.length} 筆體重紀錄',
      ..._quality(trend.values.length, dayCount),
      _window(trend.days),
    ],
  );
}

/// Whether this week has already met [goalPerWeek] training sessions.
Insight? weeklyTrainingInsight(
  List<WeeklyBar> weeks, {
  required int goalPerWeek,
}) {
  if (weeks.isEmpty) return null;
  final (_, thisWeek) = weeks.last;
  if (thisWeek == 0) return null;
  final statement = thisWeek >= goalPerWeek
      ? '這是本週第 $thisWeek 次訓練，達成每週 $goalPerWeek 次的目標。'
      : '本週已完成 $thisWeek 次訓練，距離每週 $goalPerWeek 次還差 ${goalPerWeek - thisWeek} 次。';
  return Insight(
    statement: statement,
    evidence: ['依據本週訓練紀錄', '每週目標 $goalPerWeek 次'],
  );
}

/// A drop in weekly working sets for one exercise, and whether the
/// estimated max followed it down.
Insight? volumeTrendInsight(
  String exerciseName,
  List<WeeklyBar> weeklySets, {
  required int sessionCount,
  required bool isMaxHolding,
}) {
  if (weeklySets.length < 2 || sessionCount == 0) return null;
  final first = weeklySets.first.$2;
  final last = weeklySets.last.$2;
  if (first == 0 || last >= first * (1 - _meaningfulVolumeDrop)) return null;
  final maxNote = isMaxHolding ? '，估計最大重量沒有跟著掉' : '，估計最大重量也跟著下降';
  return Insight(
    statement: '$exerciseName的每週組數從 $first 組掉到 $last 組$maxNote。',
    evidence: [
      '依據 $sessionCount 次訓練紀錄',
      '不含熱身組',
      _window(weeklySets.length * DateTime.daysPerWeek),
    ],
  );
}

List<String> _quality(int points, int dayCount) => [
  if (dayCount > 0 && points >= dayCount * _completeShare)
    '資料完整'
  else
    '資料不完整，只有 $points / $dayCount 天有紀錄',
];

String _window(int days) => days % DateTime.daysPerWeek == 0 && days <= 56
    ? '近 ${days ~/ DateTime.daysPerWeek} 週'
    : '近 $days 天';
