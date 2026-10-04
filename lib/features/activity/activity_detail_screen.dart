import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/engines/session_analysis.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';
import '../me/me_screen.dart';
import 'activity_view_model.dart';
import 'record_activity_screen.dart';
import 'route_map.dart';
import '../../l10n/l10n.dart';

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

  /// How far the page has scrolled, for the map behind it.
  final _scrolled = ValueNotifier(0.0);

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  void _delete(ActivityViewModel model, ActivitySession activity) {
    final toast = ToastScope.read(context);
    model.delete(activity.id);
    Navigator.of(context).pop();
    toast.showUndo(
      context.l10n.activityDeleted(
        activity: activity.type.labelIn(context.l10n),
      ),
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
        return DetailPage(
          appBar: PageAppBar(title: context.l10n.moduleActivity),
          children: [
            Gutter(
              child: InfoBanner(message: context.l10n.recordDeletedNotice),
            ),
          ],
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
    final route = detail?.route ?? const <RoutePoint>[];
    final hasMap = RouteMap.isSupported && route.length > 1;
    final media = MediaQuery.of(context);
    final toolbar = ToolbarMetrics.of(context);
    final hero = _Hero(
      activity: activity,
      detail: detail,
      source: model.isFromHealth(activity.id)
          ? AppStoreScope.of(context).healthSourceName
          : null,
    );
    void openMap() =>
        pushModalPage<void>(context, _RouteMapScreen(detail: detail!));
    final page = CollapsingScrollView(
      header: CollapsingHeaderDelegate(
        toolbar: toolbar,
        topInset: media.padding.top,
        largeHeight: hasMap ? _mapHeight : 0,
        // The bar is only its buttons, clear over the map and over the
        // page alike, as Apple Fitness has it.
        glassOpacity: const AlwaysStoppedAnimation(0),
        isHighContrast: media.highContrast,
        reduceMotion: prefersReducedMotion(context),
        leading: isDetailPaneRoot(context) ? null : const AppBarBackButton(),
        actions: [
          if (hasMap)
            HeaderAction(
              icon: Icons.map_outlined,
              semanticLabel: context.l10n.activityRouteMap,
              onTap: openMap,
            ),
        ],
        // The title is on the page, as Apple Fitness has it; the bar
        // holds only its buttons.
        compactTitle: const SizedBox.shrink(),
        // The stretch of map left clear above the title; it opens the
        // map.
        large: hasMap
            ? Semantics(
                button: true,
                label: context.l10n.activityRouteMap,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: openMap),
                ),
              )
            : const SizedBox.shrink(),
      ),
      children: [
        hero,
        if (failed)
          Gutter(
            child: InfoBanner(message: context.l10n.healthDetailUnreadable),
          ),
        PageSection(
          label: context.l10n.activityDetailsSection,
          children: [
            Gutter(
              child: FigureGrid(
                figures: _figures(context.l10n, activity, detail, showsPace),
              ),
            ),
          ],
        ),
        if (splits.isNotEmpty)
          PageSection(
            label: context.l10n.activitySplitsSection,
            children: [
              Gutter(
                child: _SplitTable(splits: splits, showsPace: showsPace),
              ),
            ],
          ),
        if (heartRate.isNotEmpty)
          HeartRateSection(
            heartRate: heartRate,
            start: activity.startedAt,
            age: detail?.age ?? model.ageOn(activity.startedAt),
            restingHeartRate: model.restingHeartRateBefore(activity.startedAt),
          ),
        if (detail != null && detail.recovery.length > 1)
          PageSection(
            label: context.l10n.activityRecoverySection,
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
                      ? context.l10n.activityPace
                      : series.labelIn(context.l10n),
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
            label: context.l10n.notesSection,
            children: [
              Gutter(
                child: AppCard(
                  child: Text(activity.note, style: AppTextStyles.body),
                ),
              ),
            ],
          ),
        // What a health platform recorded is the platform's to change;
        // only a session logged here can be corrected or taken back.
        if (!model.isFromHealth(activity.id))
          PageSection(
            label: context.l10n.manageSection,
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    NavRow(
                      title: context.l10n.activityEdit,
                      subtitle: context.l10n.activityEditDetail,
                      onTap: () => pushModalPage<void>(
                        context,
                        RecordActivityScreen(activity: activity),
                      ),
                    ),
                    NavRow(
                      title: context.l10n.recordDelete,
                      isDestructive: true,
                      onTap: () => _delete(model, activity),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
    return EdgeToEdgeScaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            _scrolled.value = notification.metrics.pixels;
          }
          return false;
        },
        // Measured below the Scaffold so text uses Material's line height.
        child: Builder(
          builder: (context) => Stack(
            children: [
              // Like Apple Fitness: the route lies under the whole top of
              // the page and stays there, blurring and darkening as the
              // page scrolls over it.
              if (hasMap)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height:
                      media.padding.top +
                      toolbar.height +
                      _mapHeight +
                      hero.textHeight(context),
                  child: _MapBackdrop(
                    route: route,
                    topInset: media.padding.top + toolbar.height,
                    bottomInset: hero.textHeight(context),
                    scrolled: _scrolled,
                  ),
                ),
              page,
            ],
          ),
        ),
      ),
    );
  }

  /// The session's figures, the platform's where it has them and what
  /// was logged otherwise.
  static List<Figure> _figures(
    AppLocalizations l10n,
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
      (
        label: l10n.activityActiveTime,
        value: formatClock(time),
        unit: null,
        color: null,
      ),
      if (meters != null && meters > 0)
        (
          label: l10n.activityDistance,
          value: (meters / 1000).toStringAsFixed(2),
          unit: 'km',
          color: AppColors.body,
        ),
      if (detail?.activeKcal case final kcal?)
        (
          label: l10n.activityMetricActiveEnergy,
          value: '${kcal.round()}',
          unit: 'kcal',
          color: AppColors.nutrition,
        ),
      if (detail?.totalKcal case final kcal?)
        (
          label: l10n.activityTotalEnergy,
          value: '${kcal.round()}',
          unit: 'kcal',
          color: AppColors.nutrition,
        ),
      if (climb != null)
        (
          label: l10n.activityClimb,
          value: '${climb.round()}',
          unit: 'm',
          color: AppColors.training,
        ),
      if (metersPerSecond != null && metersPerSecond > 0)
        showsPace
            ? (
                label: l10n.activityAveragePace,
                value: _pace(metersPerSecond),
                unit: '/km',
                color: AppColors.activity,
              )
            : (
                label: l10n.activityAverageSpeed,
                value: (metersPerSecond * 3.6).toStringAsFixed(1),
                unit: 'km/h',
                color: AppColors.activity,
              ),
      if (heart != null)
        (
          label: l10n.activityMetricHeartRate,
          value: '${heart.average.round()}',
          unit: l10n.unitBpm,
          color: AppColors.heart,
        ),
      if (heart != null)
        (
          label: l10n.activityMaxHeartRate,
          value: '${heart.high.round()}',
          unit: l10n.unitBpm,
          color: AppColors.heart,
        ),
      if (power != null)
        (
          label: l10n.activityAveragePower,
          value: '${power.average.round()}',
          unit: 'W',
          color: AppColors.warning,
        ),
      if (cadence != null)
        (
          label: l10n.activityAverageCadence,
          value: '${cadence.average.round()}',
          unit: 'rpm',
          color: AppColors.warning,
        ),
      if (detail?.steps case final steps? when showsPace && steps > 0)
        (
          label: l10n.activityMetricSteps,
          value: formatKcal(steps.round()),
          unit: l10n.activityMetricUnitSteps,
          color: null,
        ),
      if (detail?.swimmingStrokes case final strokes? when strokes > 0)
        (
          label: l10n.activityMetricSwimmingStrokes,
          value: '${strokes.round()}',
          unit: l10n.activityMetricUnitSwimmingStrokes,
          color: null,
        ),
      if (effort != null)
        (
          label: detail?.effort == null && detail?.estimatedEffort != null
              ? l10n.activityEffortEstimated
              : l10n.activityEffort,
          value: effort.round().toString(),
          unit: '/ 10',
          color: null,
        )
      else if (detail?.estimatedEffort case final estimated?)
        (
          label: l10n.activityEffortEstimated,
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

/// How much of the map shows above the title.
const _mapHeight = 280.0;

/// How blurred and how dark the map is once the page has scrolled over
/// it: still there, as a trace.
const _mapBlur = 18.0;
const _mapDarkening = 0.7;

/// How much further the page scrolls, once the map is fully blurred, for
/// what is left of it to fade into the page's own background.
const _mapFadeOut = 240.0;

const _heroPlaceStyle = AppTextStyles.itemTitle;
const _heroTitleStyle = AppTextStyles.screenTitle;
final _heroDistanceStyle = AppTextStyles.bigNumber.copyWith(
  color: AppColors.training,
);
const _heroLineStyle = AppTextStyles.caption;
const _heroStatValueStyle = AppTextStyles.itemTitle;
const _heroGap = AppSpacing.xxs;

/// The top of a session's page, as Apple Fitness has it: where, what,
/// how far, when and on what, then the weather, over the bottom of the
/// map when there is one. It scrolls with the page; its height is
/// measured so the map can frame the route above it.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.activity,
    required this.detail,
    required this.source,
  });

  final ActivitySession activity;
  final ActivityDetail? detail;

  /// The health platform it was read from; null when logged here.
  final String? source;

  String _title(AppLocalizations l10n) => switch (detail?.isIndoor) {
    true => l10n.activityIndoor(activity: activity.type.labelIn(l10n)),
    false => l10n.activityOutdoor(activity: activity.type.labelIn(l10n)),
    null => activity.type.labelIn(l10n),
  };

  double? get _meters => detail?.distanceMeters ?? activity.distanceMeters;

  String _when(BuildContext context) =>
      '${context.dates.fullDate(activity.startedAt)} · '
      '${formatTimeOfDay(activity.startedAt)}'
      ' – ${formatTimeOfDay(activity.endedAt)}';

  String? get _recordedBy => switch ((detail?.device, source)) {
    (final device?, final source?) => '$device · $source',
    (final device?, null) => device,
    (null, final source?) => source,
    _ => null,
  };

  List<({IconData icon, Color color, String value, String label})> _conditions(
    AppLocalizations l10n,
  ) => [
    if (detail?.temperatureCelsius case final temperature?)
      (
        icon: Icons.wb_sunny_outlined,
        color: AppColors.warning,
        value: '${temperature.round()}°',
        label: l10n.weatherLabel,
      ),
    if (detail?.humidityPercent case final humidity?)
      (
        icon: Icons.water_drop_outlined,
        color: AppColors.activity,
        value: '${humidity.round()}%',
        label: l10n.humidityLabel,
      ),
  ];

  /// The text under the map, bottom padding included.
  double textHeight(BuildContext context) {
    double line(String text, TextStyle style) =>
        measureTextHeight(context, text, style, maxWidth: double.infinity);
    final lines = [
      if (detail?.place case final place?) line(place, _heroPlaceStyle),
      line(_title(context.l10n), _heroTitleStyle),
      if (_meters case final meters? when meters > 0)
        line('0.00', _heroDistanceStyle),
      line(_when(context), _heroLineStyle),
      if (_recordedBy case final by?) line(by, _heroLineStyle),
    ];
    return lines.fold(0.0, (sum, height) => sum + height) +
        _heroGap * (lines.length - 1) +
        (_conditions(context.l10n).isEmpty
            ? 0
            : AppSpacing.md +
                  line('25°', _heroStatValueStyle) +
                  line(context.l10n.weatherLabel, _heroLineStyle)) +
        AppSpacing.lg;
  }

  @override
  Widget build(BuildContext context) {
    Widget line(String text, TextStyle style) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final place = detail?.place;
    final meters = _meters;
    final recordedBy = _recordedBy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: _heroGap,
            children: [
              if (place != null)
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(child: line(place, _heroPlaceStyle)),
                  ],
                ),
              line(_title(context.l10n), _heroTitleStyle),
              if (meters != null && meters > 0)
                line(
                  '${(meters / 1000).toStringAsFixed(2)} km',
                  _heroDistanceStyle,
                ),
              line(_when(context), _heroLineStyle),
              if (recordedBy != null)
                Row(
                  children: [
                    const Icon(
                      Icons.watch_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(child: line(recordedBy, _heroLineStyle)),
                  ],
                ),
              if (_conditions(context.l10n) case final conditions
                  when conditions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md - _heroGap),
                  child: Row(
                    spacing: AppSpacing.xl,
                    children: [
                      for (final condition in conditions)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  condition.icon,
                                  size: 18,
                                  color: condition.color,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                line(condition.value, _heroStatValueStyle),
                              ],
                            ),
                            line(condition.label, _heroLineStyle),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The route behind the page's header, fading into the page where the
/// title sits so the text stays readable.
class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop({
    required this.route,
    required this.topInset,
    required this.bottomInset,
    required this.scrolled,
  });

  final List<RoutePoint> route;

  /// How far the page over it has scrolled.
  final ValueListenable<double> scrolled;

  /// What covers the map at its top (status bar and buttons) and at its
  /// bottom (the title), so the route is framed in what shows.
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RouteSnapshot(
          route: route,
          topInset: topInset,
          bottomInset: bottomInset,
        ),
        // Blurs and darkens as the page scrolls over it, leaving a trace of
        // the map behind the figures.
        ValueListenableBuilder(
          valueListenable: scrolled,
          builder: (context, offset, _) {
            final progress = (offset / _mapHeight).clamp(0.0, 1.0);
            if (progress == 0) return const SizedBox.shrink();
            // Darkens with the blur, then, blurred through, slowly the
            // rest of the way into the page's background.
            final fadeOut = ((offset - _mapHeight) / _mapFadeOut).clamp(
              0.0,
              1.0,
            );
            final darkness =
                progress * _mapDarkening + fadeOut * (1 - _mapDarkening);
            return ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: progress * _mapBlur,
                  sigmaY: progress * _mapBlur,
                ),
                child: ColoredBox(
                  color: AppColors.background.withValues(alpha: darkness),
                ),
              ),
            );
          },
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.45, 1],
                colors: [
                  AppColors.background.withValues(alpha: 0),
                  AppColors.background.withValues(alpha: 0.1),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The route to pan and zoom, filling the window as Apple Fitness's map
/// does, with only a way back floating over it.
class _RouteMapScreen extends StatelessWidget {
  const _RouteMapScreen({required this.detail});

  final ActivityDetail detail;

  @override
  Widget build(BuildContext context) {
    final toolbar = ToolbarMetrics.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return EdgeToEdgeScaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RouteMap(
              route: detail.route,
              isInteractive: true,
              topInset: top + toolbar.height,
            ),
          ),
          Positioned(
            top: top + (toolbar.height - toolbar.actionHitSize) / 2,
            left: AppSpacing.screenGutter - AppSpacing.xs,
            // Frosted: the map under it is a native view liquid glass
            // cannot read.
            child: const AppBarBackButton(refracts: false),
          ),
        ],
      ),
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
            Text(context.l10n.splitTime, style: AppTextStyles.caption),
            Text(
              showsPace
                  ? context.l10n.activityPace
                  : context.l10n.activityAverageSpeed,
              style: AppTextStyles.caption,
            ),
            Text(
              context.l10n.activitySeriesHeartRate,
              style: AppTextStyles.caption,
            ),
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
                    : '${split.averageHeartRate!.round()} ${context.l10n.unitBpm}',
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

/// A session's heart rate: its chart with the average and range, and
/// the time in each zone, or the row that asks for the birth year the
/// zones need. Shared by a session read from the platform and a
/// workout logged here.
class HeartRateSection extends StatelessWidget {
  const HeartRateSection({
    super.key,
    required this.heartRate,
    required this.start,
    required this.age,
    required this.restingHeartRate,
  });

  /// The readings, each as the time since [start].
  final List<SeriesPoint> heartRate;
  final DateTime start;

  /// The age the zones' maximum is estimated from; null when not known.
  final int? age;
  final double? restingHeartRate;

  @override
  Widget build(BuildContext context) {
    final zones = heartRateZones(
      heartRate,
      age: age,
      restingHeartRate: restingHeartRate,
    );
    return PageSection(
      label: context.l10n.activitySeriesHeartRate,
      children: [
        Gutter(
          child: _SeriesCard(
            series: ActivitySeries.heartRate,
            points: heartRate,
            start: start,
          ),
        ),
        if (zones != null)
          Gutter(child: _ZoneCard(zones: zones))
        // Zones read the maximum from an age, which is not set: say
        // so rather than assume one.
        else if (heartRate.length > 1 && age == null)
          Gutter(
            child: GroupedCard(
              children: [
                NavRow(
                  title: context.l10n.heartZonesTitle,
                  trailing: Text(
                    context.l10n.needsBirthYear,
                    style: AppTextStyles.caption,
                  ),
                  onTap: () => editBirthYear(context),
                ),
              ],
            ),
          ),
      ],
    );
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

  String _format(AppLocalizations l10n, double value) => switch (series) {
    ActivitySeries.speed when _isPace =>
      value <= 0 ? '—' : '${_pace(value)} /km',
    ActivitySeries.speed => '${(value * 3.6).toStringAsFixed(1)} km/h',
    ActivitySeries.strideLength => '${value.toStringAsFixed(2)} m',
    ActivitySeries.verticalOscillation => '${value.toStringAsFixed(1)} cm',
    _ => withUnit('${value.round()}', series.unitIn(l10n)),
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
                context.l10n.statAverage(
                  value: _format(context.l10n, range.average),
                ),
                style: AppTextStyles.itemTitle.copyWith(color: _color),
              ),
              Text(
                _isPace
                    ? '${_format(context.l10n, range.high)}–${_format(context.l10n, range.low)}'
                    : '${_format(context.l10n, range.low)}–${_format(context.l10n, range.high)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ChartScrubber(
            count: shown.length,
            indexAt: ChartScrubber.points(shown.length),
            idle:
                '${formatTimeOfDay(start)}–'
                '${formatTimeOfDay(start.add(points.last.at))}',
            readoutOf: (index) =>
                '${formatTimeOfDay(start.add(shown[index].at))} · '
                '${_format(context.l10n, shown[index].value)}',
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
      final bpm = context.l10n.unitBpm;
      if (index == 0) return '< ${bounds[1]} $bpm';
      if (index == bounds.length - 1) return '≥ ${bounds[index]} $bpm';
      return '${bounds[index]}–${bounds[index + 1] - 1} $bpm';
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
                          context.l10n.heartZone(number: i + 1),
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
            labels: [
              zones.usesReserve
                  ? context.l10n.heartZonesByReserve
                  : context.l10n.heartZonesByAge,
              context.l10n.heartZonesOwn,
            ],
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
            unit: context.l10n.unitBpm,
            label: minutes == 0
                ? context.l10n.recoveryAtEnd
                : context.l10n.recoveryAfter(minutes: minutes),
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
            idle: context.l10n.recoveryWindow(time: formatTimeOfDay(end)),
            readoutOf: (index) =>
                '${formatTimeOfDay(end.add(points[index].at))} · '
                '${points[index].value.round()} ${context.l10n.unitBpm}',
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
