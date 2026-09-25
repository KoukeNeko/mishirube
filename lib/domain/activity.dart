import 'package:flutter/material.dart';

import '../shared/format.dart';

/// What a kind of exercise can be measured by. The form asks the type what
/// it supports instead of testing for particular sports.
enum ActivityCapability {
  /// A distance worth recording (running, cycling, swimming).
  distance,

  /// Distance over time is meaningful, so a pace can be shown.
  pace,

  /// Climbing is part of the effort.
  elevation,
}

/// How the picker groups the types.
enum ActivityGroup {
  walkRun('走路與跑步'),
  cycling('自行車'),
  water('水上運動'),
  ball('球類'),
  indoor('室內器材'),
  mindBody('身心與伸展'),
  other('其他');

  const ActivityGroup(this.label);

  final String label;
}

/// A kind of exercise. These are part of the app, not user data: the id is
/// what a record stores, so renaming a label never rewrites history.
class ActivityType {
  const ActivityType({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    this.capabilities = const {},
  });

  final String id;
  final String label;
  final IconData icon;
  final ActivityGroup group;
  final Set<ActivityCapability> capabilities;

  bool get tracksDistance => capabilities.contains(ActivityCapability.distance);

  bool get tracksPace => capabilities.contains(ActivityCapability.pace);

  bool get tracksElevation =>
      capabilities.contains(ActivityCapability.elevation);

  @override
  bool operator ==(Object other) => other is ActivityType && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The types the app knows. Unknown ids (from an import) keep their
/// original name and fall back to [ActivityTypes.other].
abstract final class ActivityTypes {
  static const running = ActivityType(
    id: 'running',
    label: '跑步',
    icon: Icons.directions_run,
    group: ActivityGroup.walkRun,
    capabilities: {
      ActivityCapability.distance,
      ActivityCapability.pace,
      ActivityCapability.elevation,
    },
  );

  static const walking = ActivityType(
    id: 'walking',
    label: '健走',
    icon: Icons.directions_walk,
    group: ActivityGroup.walkRun,
    capabilities: {
      ActivityCapability.distance,
      ActivityCapability.pace,
      ActivityCapability.elevation,
    },
  );

  static const hiking = ActivityType(
    id: 'hiking',
    label: '健行',
    icon: Icons.terrain,
    group: ActivityGroup.walkRun,
    capabilities: {ActivityCapability.distance, ActivityCapability.elevation},
  );

  static const cycling = ActivityType(
    id: 'cycling',
    label: '騎自行車',
    icon: Icons.directions_bike,
    group: ActivityGroup.cycling,
    capabilities: {
      ActivityCapability.distance,
      ActivityCapability.pace,
      ActivityCapability.elevation,
    },
  );

  static const swimming = ActivityType(
    id: 'swimming',
    label: '游泳',
    icon: Icons.pool,
    group: ActivityGroup.water,
    capabilities: {ActivityCapability.distance, ActivityCapability.pace},
  );

  static const rowing = ActivityType(
    id: 'rowing',
    label: '划船機',
    icon: Icons.rowing,
    group: ActivityGroup.indoor,
    capabilities: {ActivityCapability.distance, ActivityCapability.pace},
  );

  static const elliptical = ActivityType(
    id: 'elliptical',
    label: '橢圓機',
    icon: Icons.fitness_center,
    group: ActivityGroup.indoor,
    capabilities: {ActivityCapability.distance},
  );

  static const stairs = ActivityType(
    id: 'stairs',
    label: '爬樓梯',
    icon: Icons.stairs,
    group: ActivityGroup.indoor,
    capabilities: {ActivityCapability.elevation},
  );

  static const basketball = ActivityType(
    id: 'basketball',
    label: '籃球',
    icon: Icons.sports_basketball,
    group: ActivityGroup.ball,
  );

  static const badminton = ActivityType(
    id: 'badminton',
    label: '羽球',
    icon: Icons.sports_tennis,
    group: ActivityGroup.ball,
  );

  static const yoga = ActivityType(
    id: 'yoga',
    label: '瑜伽',
    icon: Icons.self_improvement,
    group: ActivityGroup.mindBody,
  );

  static const other = ActivityType(
    id: 'other',
    label: '其他運動',
    icon: Icons.sports,
    group: ActivityGroup.other,
  );

  /// Offered first in the picker, before the full list.
  static const common = [running, walking, cycling, swimming, yoga, hiking];

  static const all = [
    running,
    walking,
    hiking,
    cycling,
    swimming,
    rowing,
    elliptical,
    stairs,
    basketball,
    badminton,
    yoga,
    other,
  ];

  static ActivityType byId(String id) =>
      all.firstWhere((type) => type.id == id, orElse: () => other);
}

/// One session of general exercise: a stretch of time doing something,
/// rather than sets of an exercise.
class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.duration,
    this.distanceMeters,
    this.elevationGainMeters,
    this.effort,
    this.note = '',
    this.nativeType,
  });

  final String id;
  final ActivityType type;
  final DateTime startedAt;
  final Duration duration;
  final double? distanceMeters;
  final double? elevationGainMeters;

  /// How hard it felt, 1–10. Null when the user did not say.
  final int? effort;
  final String note;

  /// The source's own name for the type, kept when it is one we do not
  /// know, so a later mapping can reinterpret it.
  final String? nativeType;

  DateTime get endedAt => startedAt.add(duration);

  /// What the session reads as in a list: how long, and how far where
  /// that means something.
  String get description => [
    '${duration.inMinutes} 分',
    if (distanceMeters case final metres?) '${formatWeight(metres / 1000)} km',
  ].join(' · ');

  /// Seconds per kilometre, for types where that reads as a pace. Null
  /// without a distance to divide by.
  Duration? get pace {
    final metres = distanceMeters;
    if (!type.tracksPace || metres == null || metres <= 0) return null;
    return Duration(
      milliseconds: (duration.inMilliseconds * 1000 / metres).round(),
    );
  }
}

/// Exercise that has started but not finished: it has a clock instead of
/// a duration, and becomes an [ActivitySession] when it stops.
class LiveActivity {
  LiveActivity({
    required this.id,
    required this.type,
    required this.startedAt,
    this.pausedAt,
    this.pausedTotal = Duration.zero,
  });

  final String id;
  final ActivityType type;
  final DateTime startedAt;
  DateTime? pausedAt;
  Duration pausedTotal;

  bool get isPaused => pausedAt != null;

  Duration elapsedAt(DateTime now) =>
      (pausedAt ?? now).difference(startedAt) - pausedTotal;
}

/// How the activity page groups its metrics, following Apple Health's
/// categories.
enum ActivityMetricGroup {
  movement('日常活動'),
  heart('心臟與心肺'),
  mobility('行動能力'),
  running('跑步'),
  cycling('騎車'),
  swimmingWheelchair('游泳與輪椅');

  const ActivityMetricGroup(this.label);

  final String label;
}

/// A figure a health platform keeps about movement and fitness. A
/// counted one ([isCumulative]) is read as hourly totals the platform
/// has already de-duplicated across a phone and a watch; a measured one
/// as each day's average. Neither is typed in: they come only from the
/// platform, and a metric no source records is never shown. Some exist
/// on one platform only; they simply never come back from the other.
enum ActivityMetric {
  steps('步數', '步', ActivityMetricGroup.movement, isCumulative: true),

  /// Metres, shown in kilometres. Apple Health's is walking and running;
  /// Health Connect's is every distance.
  distance(
    '距離',
    'km',
    ActivityMetricGroup.movement,
    isCumulative: true,
    displayScale: 0.001,
    decimals: 1,
  ),
  activeEnergy(
    '動態能量',
    'kcal',
    ActivityMetricGroup.movement,
    isCumulative: true,
  ),

  /// What the body burns at rest; Health Connect's is its basal rate
  /// over the hour.
  basalEnergy('靜止能量', 'kcal', ActivityMetricGroup.movement, isCumulative: true),

  /// Apple Watch's exercise minutes: time at a brisk walk's effort or
  /// more.
  exerciseTime('運動時間', '分', ActivityMetricGroup.movement, isCumulative: true),

  /// Minutes on one's feet, not the stand hours of Apple's ring.
  standTime('站立時間', '分', ActivityMetricGroup.movement, isCumulative: true),
  floors('爬樓', '層', ActivityMetricGroup.movement, isCumulative: true),
  elevationGained(
    '爬升高度',
    'm',
    ActivityMetricGroup.movement,
    isCumulative: true,
  ),
  timeInDaylight('日光時間', '分', ActivityMetricGroup.movement, isCumulative: true),
  heartRate('平均心率', '次/分', ActivityMetricGroup.heart),
  restingHeartRate('靜止心率', '次/分', ActivityMetricGroup.heart),
  walkingHeartRate('步行平均心率', '次/分', ActivityMetricGroup.heart),

  /// The two platforms measure variability differently; they are not
  /// one figure.
  hrvSdnn('心率變異度（SDNN）', 'ms', ActivityMetricGroup.heart),
  hrvRmssd('心率變異度（RMSSD）', 'ms', ActivityMetricGroup.heart),
  heartRateRecovery('一分鐘心率恢復', '次/分', ActivityMetricGroup.heart),
  vo2Max('最大攝氧量', 'mL/kg/min', ActivityMetricGroup.heart, decimals: 1),

  /// Apple Watch's estimate of effort, in METs.
  physicalEffort('身體耗力', 'MET', ActivityMetricGroup.heart, decimals: 1),

  /// Metres per second, shown in km/h.
  walkingSpeed(
    '步行速度',
    'km/h',
    ActivityMetricGroup.mobility,
    displayScale: 3.6,
    decimals: 1,
  ),

  /// Metres, shown in centimetres.
  walkingStepLength(
    '步長',
    'cm',
    ActivityMetricGroup.mobility,
    displayScale: 100,
  ),

  /// Fractions, shown as percentages.
  walkingAsymmetry(
    '步行不對稱',
    '%',
    ActivityMetricGroup.mobility,
    displayScale: 100,
    decimals: 1,
  ),
  doubleSupport(
    '雙腳支撐時間',
    '%',
    ActivityMetricGroup.mobility,
    displayScale: 100,
    decimals: 1,
  ),
  walkingSteadiness(
    '步行穩定度',
    '%',
    ActivityMetricGroup.mobility,
    displayScale: 100,
  ),
  stairAscentSpeed('上樓速度', 'm/s', ActivityMetricGroup.mobility, decimals: 2),
  stairDescentSpeed('下樓速度', 'm/s', ActivityMetricGroup.mobility, decimals: 2),
  sixMinuteWalk('六分鐘步行距離', 'm', ActivityMetricGroup.mobility),
  runningSpeed(
    '跑步速度',
    'km/h',
    ActivityMetricGroup.running,
    displayScale: 3.6,
    decimals: 1,
  ),
  runningPower('跑步功率', 'W', ActivityMetricGroup.running),
  runningStrideLength('跑步步幅', 'm', ActivityMetricGroup.running, decimals: 2),
  groundContactTime('觸地時間', 'ms', ActivityMetricGroup.running),
  verticalOscillation('垂直振幅', 'cm', ActivityMetricGroup.running, decimals: 1),
  cyclingDistance(
    '騎車距離',
    'km',
    ActivityMetricGroup.cycling,
    isCumulative: true,
    displayScale: 0.001,
    decimals: 1,
  ),
  cyclingSpeed(
    '騎車速度',
    'km/h',
    ActivityMetricGroup.cycling,
    displayScale: 3.6,
    decimals: 1,
  ),
  cyclingPower('騎車功率', 'W', ActivityMetricGroup.cycling),
  cyclingCadence('踏頻', 'rpm', ActivityMetricGroup.cycling),
  functionalThresholdPower('功能性閾值功率', 'W', ActivityMetricGroup.cycling),
  swimmingDistance(
    '游泳距離',
    'm',
    ActivityMetricGroup.swimmingWheelchair,
    isCumulative: true,
  ),
  swimmingStrokes(
    '划水次數',
    '次',
    ActivityMetricGroup.swimmingWheelchair,
    isCumulative: true,
  ),
  wheelchairPushes(
    '輪椅推動',
    '次',
    ActivityMetricGroup.swimmingWheelchair,
    isCumulative: true,
  ),
  wheelchairDistance(
    '輪椅距離',
    'km',
    ActivityMetricGroup.swimmingWheelchair,
    isCumulative: true,
    displayScale: 0.001,
    decimals: 1,
  );

  const ActivityMetric(
    this.label,
    this.unit,
    this.group, {
    this.isCumulative = false,
    this.displayScale = 1,
    this.decimals = 0,
  });

  /// What a day's movement leads with, in order: the figures a device
  /// on its own can count come first.
  static const headline = [steps, distance, activeEnergy, exerciseTime, floors];

  final String label;
  final String unit;
  final ActivityMetricGroup group;
  final bool isCumulative;

  /// The most a counted metric can come to in a day, in its stored unit.
  /// Past it a sample is not a hard day but a broken one: a device or
  /// app once wrote 4,294,967,295 steps (a 32-bit counter's -1) to Apple
  /// Health, and one such day outweighs a year of real ones.
  double? get maxPerDay => switch (this) {
    steps => 200000,
    distance => 500000,
    activeEnergy || basalEnergy => 20000,
    exerciseTime || standTime || timeInDaylight => 1440,
    floors => 3000,
    elevationGained => 20000,
    _ => null,
  };

  /// Whether [value] could be true of a sample of this metric: a counted
  /// one within a day's most, and neither one negative.
  bool isPlausible(double value) =>
      value.isFinite && value >= 0 && value <= (maxPerDay ?? double.infinity);

  /// From the stored unit to [unit].
  final double displayScale;
  final int decimals;

  /// [stored] in [unit], as the app writes numbers: whole thousands
  /// grouped, as calories are.
  String format(double stored) {
    final value = stored * displayScale;
    if (decimals > 0) return value.toStringAsFixed(decimals);
    return formatKcal(value.round());
  }
}

/// What a platform counted or measured over one stretch: an hour for a
/// counted metric, a day for a measured one.
class ActivitySample {
  const ActivitySample({
    required this.metric,
    required this.start,
    required this.end,
    required this.value,
  });

  final ActivityMetric metric;
  final DateTime start;
  final DateTime end;

  /// In the metric's stored unit.
  final double value;

  @override
  bool operator ==(Object other) =>
      other is ActivitySample &&
      other.metric == metric &&
      other.start == start &&
      other.end == end &&
      other.value == value;

  @override
  int get hashCode => Object.hash(metric, start, end, value);
}
