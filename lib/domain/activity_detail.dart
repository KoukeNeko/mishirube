/// A reading taken during a session, as time from its start.
typedef SeriesPoint = ({Duration at, double value});

/// One point of a session's GPS route: where, how high, when (from the
/// start) and how fast, in metres per second.
typedef RoutePoint = ({
  double latitude,
  double longitude,
  double altitude,
  Duration at,
  double speed,
});

/// The time series a session can have, each in the unit the page shows.
enum ActivitySeries {
  heartRate('心率', '次/分'),

  /// Metres per second; shown as km/h, or as pace for walking and running.
  speed('速度', 'km/h'),
  power('功率', 'W'),
  cadence('踏頻', 'rpm'),
  strideLength('步幅', 'm'),
  groundContactTime('觸地時間', 'ms'),
  verticalOscillation('垂直振幅', 'cm'),

  /// From the route.
  altitude('高度', 'm');

  const ActivitySeries(this.label, this.unit);

  final String label;
  final String unit;
}

/// A stretch the source marked inside a session: a lap, or a segment
/// such as a swim set or an interval.
class ActivityInterval {
  const ActivityInterval({
    required this.isLap,
    required this.start,
    required this.end,
  });

  final bool isLap;
  final Duration start;
  final Duration end;

  Duration get duration => end - start;
}

/// What a health platform recorded during one imported session, read
/// when its page opens and never stored: the route in particular stays
/// on the platform. Every part is optional, since what exists depends on
/// the device that recorded it.
class ActivityDetail {
  const ActivityDetail({
    this.activeDuration,
    this.device,
    this.place,
    this.isIndoor,
    this.temperatureCelsius,
    this.humidityPercent,
    this.elevationGainMeters,
    this.activeKcal,
    this.totalKcal,
    this.distanceMeters,
    this.steps,
    this.swimmingStrokes,
    this.lapLengthMeters,
    this.series = const {},
    this.recovery = const [],
    this.route = const [],
    this.intervals = const [],
    this.effort,
    this.estimatedEffort,
    this.age,
  });

  /// Time actually moving, pauses taken out; null when the platform
  /// does not keep pauses.
  final Duration? activeDuration;

  /// The watch or app that recorded it.
  final String? device;

  /// The city it started in, and nothing more precise.
  final String? place;
  final bool? isIndoor;
  final double? temperatureCelsius;
  final double? humidityPercent;
  final double? elevationGainMeters;
  final double? activeKcal;

  /// Active and resting energy together.
  final double? totalKcal;
  final double? distanceMeters;
  final double? steps;
  final double? swimmingStrokes;
  final double? lapLengthMeters;
  final Map<ActivitySeries, List<SeriesPoint>> series;

  /// Heart rate in the minutes after it ended, as time from the end.
  final List<SeriesPoint> recovery;
  final List<RoutePoint> route;
  final List<ActivityInterval> intervals;

  /// How hard it was, 1–10: the user's rating, and the platform's
  /// estimate.
  final double? effort;
  final double? estimatedEffort;

  /// The user's age on the day, from the platform, for heart rate zones.
  final int? age;
}
