import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/engines/session_analysis.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'activity_view_model.dart';
import 'record_activity_screen.dart';
import 'route_map.dart';

/// Walking, running and hiking read as pace; everything else as speed.
const _paceTypes = {'running', 'walking', 'hiking'};

/// The five zones' colours, cool to hot.
const _zoneColors = [
  AppColors.body,
  AppColors.activity,
  AppColors.training,
  AppColors.warning,
  AppColors.nutrition,
];

/// One session. One logged in the app shows what was typed in; one read
/// from Apple Health or Health Connect also shows everything the device
/// recorded during it, read from the platform as the page opens: the
/// route, the figures, the splits, heart rate and its zones, the minutes
/// after, and every other series the device kept. A part the device did
/// not record is not shown at all.
class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  Future<ActivityDetail?>? _detail;

  void _delete(ActivityViewModel model, ActivitySession activity) {
    final toast = ToastScope.read(context);
    model.delete(activity.id);
    Navigator.of(context).pop();
    toast.showUndo(
      '已刪除${activity.type.label}',
      onUndo: () => model.restore(activity.id),
    );
  }

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: ActivityViewModel.new,
    builder: (context, model) {
      final activity = model.byId(widget.activityId);
      if (activity == null) {
        // The record is gone (undo not taken); the screen closes itself
        // rather than showing an empty shell.
        return const DetailPage(
          appBar: PageAppBar(title: '運動'),
          children: [Gutter(child: InfoBanner(message: '這筆紀錄已經刪除。'))],
        );
      }
      _detail ??= AppStoreScope.read(context).activityDetail(activity);
      return FutureBuilder(
        future: _detail,
        builder: (context, snapshot) =>
            _page(model, activity, snapshot.data, failed: snapshot.hasError),
      );
    },
  );

  Widget _page(
    ActivityViewModel model,
    ActivitySession activity,
    ActivityDetail? detail, {
    required bool failed,
  }) {
    final showsPace = _paceTypes.contains(activity.type.id);
    final heartRate = detail?.series[ActivitySeries.heartRate] ?? const [];
    final splits = detail == null
        ? const <RouteSplit>[]
        : routeSplits(detail.route, heartRate);
    final zones = heartRateZones(
      heartRate,
      age: detail?.age,
      restingHeartRate: model.restingHeartRateBefore(activity.startedAt),
    );
    return DetailPage(
      appBar: PageAppBar(
        title: activity.type.label,
        subtitle:
            '${activity.startedAt.month} 月 ${activity.startedAt.day} 日 · '
            '${formatTimeOfDay(activity.startedAt)} – '
            '${formatTimeOfDay(activity.endedAt)}',
      ),
      children: [
        if (failed) Gutter(child: const InfoBanner(message: '無法讀取健康資料的詳細紀錄。')),
        if (detail != null && RouteMap.isSupported && detail.route.length > 1)
          Gutter(
            child: _MapCard(
              route: detail.route,
              onTap: () => pushModalPage<void>(
                context,
                _RouteMapScreen(title: activity.type.label, detail: detail),
              ),
            ),
          ),
        if (_context(detail) case final tags when tags.isNotEmpty)
          Gutter(child: TagWrap(labels: tags)),
        PageSection(
          label: '詳細資料',
          children: [
            Gutter(
              child: _FigureGrid(
                figures: _figures(activity, detail, showsPace),
              ),
            ),
          ],
        ),
        if (splits.isNotEmpty)
          PageSection(
            label: '分段 · 每 1 km',
            children: [
              Gutter(
                child: _SplitTable(splits: splits, showsPace: showsPace),
              ),
            ],
          ),
        if (heartRate.isNotEmpty)
          PageSection(
            label: '心率',
            children: [
              Gutter(
                child: _SeriesCard(
                  series: ActivitySeries.heartRate,
                  points: heartRate,
                  start: activity.startedAt,
                ),
              ),
              if (zones != null) Gutter(child: _ZoneCard(zones: zones)),
            ],
          ),
        if (detail != null && detail.recovery.length > 1)
          PageSection(
            label: '運動後心率',
            children: [
              Gutter(
                child: _RecoveryCard(
                  points: detail.recovery,
                  end: activity.endedAt,
                ),
              ),
            ],
          ),
        if (detail != null)
          for (final series in ActivitySeries.values)
            if (series != ActivitySeries.heartRate)
              if (detail.series[series] case final points?
                  when points.length > 1)
                PageSection(
                  label: series == ActivitySeries.speed && showsPace
                      ? '配速'
                      : series.label,
                  children: [
                    Gutter(
                      child: _SeriesCard(
                        series: series,
                        points: points,
                        start: activity.startedAt,
                        showsPace: showsPace,
                      ),
                    ),
                  ],
                ),
        if (activity.note.isNotEmpty)
          PageSection(
            label: '備註',
            children: [
              Gutter(
                child: AppCard(
                  child: Text(activity.note, style: AppTextStyles.body),
                ),
              ),
            ],
          ),
        PageSection(
          label: '管理',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: '編輯內容',
                    subtitle: '類型、時間、時長',
                    onTap: () => pushModalPage<void>(
                      context,
                      RecordActivityScreen(activity: activity),
                    ),
                  ),
                  NavRow(
                    title: '刪除這筆紀錄',
                    onTap: () => _delete(model, activity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Where, on what, and in what weather.
  static List<String> _context(ActivityDetail? detail) => [
    ?detail?.place,
    ?detail?.device,
    if (detail?.isIndoor case final indoor?) indoor ? '室內' : '戶外',
    if (detail?.temperatureCelsius case final temperature?)
      '${temperature.round()}°C',
    if (detail?.humidityPercent case final humidity?) '濕度 ${humidity.round()}%',
  ];

  /// The session's figures, the platform's where it has them and what
  /// was logged otherwise.
  static List<_Figure> _figures(
    ActivitySession activity,
    ActivityDetail? detail,
    bool showsPace,
  ) {
    final time = detail?.activeDuration ?? activity.duration;
    final meters = detail?.distanceMeters ?? activity.distanceMeters;
    final climb = detail?.elevationGainMeters ?? activity.elevationGainMeters;
    final heart = rangeOf(detail?.series[ActivitySeries.heartRate] ?? const []);
    final power = rangeOf(detail?.series[ActivitySeries.power] ?? const []);
    final cadence = rangeOf(detail?.series[ActivitySeries.cadence] ?? const []);
    final metersPerSecond = meters == null || time == Duration.zero
        ? null
        : meters / time.inSeconds;
    final effort = detail?.effort ?? activity.effort?.toDouble();
    return [
      (label: '運動時間', value: formatClock(time), unit: null, color: null),
      if (meters != null && meters > 0)
        (
          label: '距離',
          value: (meters / 1000).toStringAsFixed(2),
          unit: 'km',
          color: AppColors.body,
        ),
      if (detail?.activeKcal case final kcal?)
        (
          label: '動態能量',
          value: '${kcal.round()}',
          unit: 'kcal',
          color: AppColors.nutrition,
        ),
      if (detail?.totalKcal case final kcal?)
        (
          label: '總能量',
          value: '${kcal.round()}',
          unit: 'kcal',
          color: AppColors.nutrition,
        ),
      if (climb != null)
        (
          label: '爬升',
          value: '${climb.round()}',
          unit: 'm',
          color: AppColors.training,
        ),
      if (metersPerSecond != null && metersPerSecond > 0)
        showsPace
            ? (
                label: '平均配速',
                value: _pace(metersPerSecond),
                unit: '/km',
                color: AppColors.activity,
              )
            : (
                label: '平均速度',
                value: (metersPerSecond * 3.6).toStringAsFixed(1),
                unit: 'km/h',
                color: AppColors.activity,
              ),
      if (heart != null)
        (
          label: '平均心率',
          value: '${heart.average.round()}',
          unit: '次/分',
          color: AppColors.heart,
        ),
      if (heart != null)
        (
          label: '最高心率',
          value: '${heart.high.round()}',
          unit: '次/分',
          color: AppColors.heart,
        ),
      if (power != null)
        (
          label: '平均功率',
          value: '${power.average.round()}',
          unit: 'W',
          color: AppColors.warning,
        ),
      if (cadence != null)
        (
          label: '平均踏頻',
          value: '${cadence.average.round()}',
          unit: 'rpm',
          color: AppColors.warning,
        ),
      if (detail?.steps case final steps? when showsPace && steps > 0)
        (label: '步數', value: formatKcal(steps.round()), unit: '步', color: null),
      if (detail?.swimmingStrokes case final strokes? when strokes > 0)
        (label: '划水次數', value: '${strokes.round()}', unit: '次', color: null),
      if (effort != null)
        (
          label: detail?.effort == null && detail?.estimatedEffort != null
              ? '費力程度（估計）'
              : '費力程度',
          value: effort.round().toString(),
          unit: '/ 10',
          color: null,
        )
      else if (detail?.estimatedEffort case final estimated?)
        (
          label: '費力程度（估計）',
          value: estimated.round().toString(),
          unit: '/ 10',
          color: null,
        ),
    ];
  }
}

/// `5:32`, minutes and seconds per kilometre.
String _pace(double metersPerSecond) =>
    formatClock(Duration(seconds: (1000 / metersPerSecond).round()));

typedef _Figure = ({String label, String value, String? unit, Color? color});

/// The figures two to a row, each coloured by what it measures.
class _FigureGrid extends StatelessWidget {
  const _FigureGrid({required this.figures});

  final List<_Figure> figures;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - AppSpacing.md) / 2;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final figure in figures)
                SizedBox(
                  width: width,
                  child: StatBlock(
                    value: figure.value,
                    unit: figure.unit,
                    label: figure.label,
                    valueColor: figure.color ?? AppColors.textPrimary,
                    valueStyle: AppTextStyles.bigNumber.copyWith(fontSize: 26),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The route, still, at the top of the page; tapping opens it to move
/// around.
class _MapCard extends StatelessWidget {
  const _MapCard({required this.route, required this.onTap});

  static const _height = 220.0;

  final List<RoutePoint> route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '路線地圖',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RouteMap(route: route),
              // Over the platform view, so the tap reaches Flutter.
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The route to pan and zoom.
class _RouteMapScreen extends StatelessWidget {
  const _RouteMapScreen({required this.title, required this.detail});

  static const _height = 520.0;

  final String title;
  final ActivityDetail detail;

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(title: title, subtitle: detail.place),
      children: [
        Gutter(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              height: _height,
              child: RouteMap(route: detail.route, isInteractive: true),
            ),
          ),
        ),
      ],
    );
  }
}

/// Each kilometre: how long it took, how fast, and the heart rate.
class _SplitTable extends StatelessWidget {
  const _SplitTable({required this.splits, required this.showsPace});

  final List<RouteSplit> splits;
  final bool showsPace;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> cells) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: 28, child: cells[0]),
          for (final cell in cells.skip(1)) Expanded(child: cell),
        ],
      ),
    );
    const numberStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return AppCard(
      child: Column(
        children: [
          row([
            const SizedBox(),
            const Text('時間', style: AppTextStyles.caption),
            Text(showsPace ? '配速' : '平均速度', style: AppTextStyles.caption),
            const Text('心率', style: AppTextStyles.caption),
          ]),
          for (final split in splits)
            row([
              Text('${split.index}', style: AppTextStyles.caption),
              Text(
                formatClock(split.duration),
                style: numberStyle.copyWith(color: AppColors.textPrimary),
              ),
              Text(
                _speed(split),
                style: numberStyle.copyWith(color: AppColors.activity),
              ),
              Text(
                split.averageHeartRate == null
                    ? '—'
                    : '${split.averageHeartRate!.round()} 次/分',
                style: numberStyle.copyWith(color: AppColors.heart),
              ),
            ]),
        ],
      ),
    );
  }

  String _speed(RouteSplit split) {
    final metersPerSecond = split.meters / split.duration.inSeconds;
    return showsPace
        ? '${_pace(metersPerSecond)} /km'
        : '${(metersPerSecond * 3.6).toStringAsFixed(1)} km/h';
  }
}

/// A series over the session: its average and range, and a line to read
/// at any moment.
class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.points,
    required this.start,
    this.showsPace = false,
  });

  final ActivitySeries series;
  final List<SeriesPoint> points;
  final DateTime start;
  final bool showsPace;

  bool get _isPace => series == ActivitySeries.speed && showsPace;

  Color get _color => switch (series) {
    ActivitySeries.heartRate => AppColors.heart,
    ActivitySeries.speed => AppColors.activity,
    ActivitySeries.altitude => AppColors.training,
    _ => AppColors.warning,
  };

  String _format(double value) => switch (series) {
    ActivitySeries.speed when _isPace =>
      value <= 0 ? '—' : '${_pace(value)} /km',
    ActivitySeries.speed => '${(value * 3.6).toStringAsFixed(1)} km/h',
    ActivitySeries.strideLength => '${value.toStringAsFixed(2)} m',
    ActivitySeries.verticalOscillation => '${value.toStringAsFixed(1)} cm',
    _ => '${value.round()} ${series.unit}',
  };

  @override
  Widget build(BuildContext context) {
    final shown = downsample(points);
    final range = rangeOf(points)!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wraps the range under the average when both do not fit.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              Text(
                '平均 ${_format(range.average)}',
                style: AppTextStyles.itemTitle.copyWith(color: _color),
              ),
              Text(
                _isPace
                    ? '${_format(range.high)}–${_format(range.low)}'
                    : '${_format(range.low)}–${_format(range.high)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ChartScrubber(
            count: shown.length,
            indexAt: ChartScrubber.points(shown.length),
            idle:
                '${formatTimeOfDay(start)} – '
                '${formatTimeOfDay(start.add(points.last.at))}',
            readoutOf: (index) =>
                '${formatTimeOfDay(start.add(shown[index].at))} · '
                '${_format(shown[index].value)}',
            builder: (context, selected) => Sparkline(
              values: [for (final point in shown) point.value],
              color: _color,
              height: 72,
              selected: selected,
            ),
          ),
        ],
      ),
    );
  }
}

/// Time in each heart rate zone, and the range each covers.
class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.zones});

  final ({List<int> lowerBounds, List<Duration> durations, bool usesReserve})
  zones;

  @override
  Widget build(BuildContext context) {
    final longest = zones.durations.fold(
      Duration.zero,
      (a, b) => a > b ? a : b,
    );
    String range(int index) {
      final bounds = zones.lowerBounds;
      if (index == 0) return '< ${bounds[1]} 次/分';
      if (index == bounds.length - 1) return '≥ ${bounds[index]} 次/分';
      return '${bounds[index]}–${bounds[index + 1] - 1} 次/分';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < zones.durations.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '區間 ${i + 1}',
                          style: AppTextStyles.itemTitle.copyWith(
                            color: _zoneColors[i],
                          ),
                        ),
                        Text(range(i), style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: longest == Duration.zero
                            ? 0
                            : zones.durations[i].inSeconds / longest.inSeconds,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: _zoneColors[i],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    formatClock(zones.durations[i]),
                    style: AppTextStyles.itemTitle,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          TagWrap(
            labels: [zones.usesReserve ? '依儲備心率估計' : '依年齡估計最大心率', '本 App 的區間'],
          ),
        ],
      ),
    );
  }
}

/// Heart rate in the minutes after the end, and where it stood at the
/// end and each minute after.
class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.points, required this.end});

  final List<SeriesPoint> points;
  final DateTime end;

  double? _at(Duration after) {
    final near = points.where(
      (point) => (point.at - after).abs() <= const Duration(seconds: 20),
    );
    return near.isEmpty ? null : near.first.value;
  }

  @override
  Widget build(BuildContext context) {
    final marks = [
      for (final minutes in const [0, 1, 2])
        if (_at(Duration(minutes: minutes)) case final bpm?)
          StatBlock(
            value: '${bpm.round()}',
            unit: '次/分',
            label: minutes == 0 ? '結束時' : '$minutes 分後',
            valueColor: AppColors.heart,
            valueStyle: AppTextStyles.bigNumber.copyWith(fontSize: 22),
          ),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChartScrubber(
            count: points.length,
            indexAt: ChartScrubber.points(points.length),
            idle: '${formatTimeOfDay(end)} 起 3 分鐘',
            readoutOf: (index) =>
                '${formatTimeOfDay(end.add(points[index].at))} · '
                '${points[index].value.round()} 次/分',
            builder: (context, selected) => Sparkline(
              values: [for (final point in points) point.value],
              color: AppColors.heart,
              height: 56,
              selected: selected,
            ),
          ),
          if (marks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            StatRow(stats: marks),
          ],
        ],
      ),
    );
  }
}
