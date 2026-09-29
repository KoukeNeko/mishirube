/// Where on the body a tape measure went.
enum MeasurementSite { waist, hips, chest, arm, thigh, calf, neck }

/// One tape measurement, in centimetres.
class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.measuredAt,
    required this.site,
    required this.centimetres,
    this.note = '',
  });

  final String id;
  final DateTime measuredAt;
  final MeasurementSite site;
  final double centimetres;
  final String note;
}

class BodyWeight {
  const BodyWeight({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    this.note = '',
    this.sessionId,
  });

  final String id;
  final DateTime measuredAt;
  final double weightKg;
  final String note;

  /// The body composition measurement it was weighed in, shared with that
  /// measurement's [BodyReading]s; null for a weighing on its own.
  final String? sessionId;
}

/// A body figure other than weight and girth: height, and what a body
/// composition scale reports. Most of these a scale estimates from a
/// small current through the body rather than measures, and each brand
/// estimates differently, so a series is only comparable with itself.
enum BodyMetric {
  height(isEstimated: false),
  bodyFat,
  skeletalMuscle,
  muscleMass,
  leanMass,
  visceralFat,
  bodyWater,
  boneMass,
  basalMetabolicRate;

  const BodyMetric({this.isEstimated = true});

  /// Worked out by the scale rather than measured.
  final bool isEstimated;
}

/// One reading of a [BodyMetric].
class BodyReading {
  const BodyReading({
    required this.id,
    required this.measuredAt,
    required this.metric,
    required this.value,
    this.note = '',
    this.sessionId,
  });

  final String id;
  final DateTime measuredAt;
  final BodyMetric metric;
  final double value;
  final String note;

  /// The measurement it was read in, as one scale gives its figures
  /// together with the weight; null for one taken on its own.
  final String? sessionId;
}

/// What one body composition measurement recorded: the weight and each
/// figure, taken at once and kept together.
class BodySession {
  const BodySession({
    required this.id,
    required this.measuredAt,
    this.weight,
    this.readings = const [],
  });

  final String id;
  final DateTime measuredAt;
  final BodyWeight? weight;
  final List<BodyReading> readings;

  /// Every record in it, weight first, for deleting or restoring it whole.
  List<String> get recordIds => [?weight?.id, for (final r in readings) r.id];
}

/// Sex as the energy equations take it: they differ by a constant, and
/// nothing else in the app asks.
enum Sex { female, male }
