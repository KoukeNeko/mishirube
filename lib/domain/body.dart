/// Where on the body a tape measure went.
enum MeasurementSite {
  waist('腰圍'),
  hips('臀圍'),
  chest('胸圍'),
  arm('上臂'),
  thigh('大腿'),
  calf('小腿'),
  neck('頸圍');

  const MeasurementSite(this.label);

  final String label;
}

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
  });

  final String id;
  final DateTime measuredAt;
  final double weightKg;
  final String note;
}

/// A body figure other than weight and girth: height, and what a body
/// composition scale reports. Most of these a scale estimates from a
/// small current through the body rather than measures, and each brand
/// estimates differently, so a series is only comparable with itself.
enum BodyMetric {
  height('身高', 'cm', isEstimated: false),
  bodyFat('體脂率', '%'),
  skeletalMuscle('骨骼肌', 'kg'),
  muscleMass('肌肉量', 'kg'),
  leanMass('除脂體重', 'kg'),
  visceralFat('內臟脂肪', '級'),
  bodyWater('體水分', '%'),
  boneMass('骨量', 'kg'),
  basalMetabolicRate('基礎代謝', 'kcal');

  const BodyMetric(this.label, this.unit, {this.isEstimated = true});

  final String label;
  final String unit;

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
  });

  final String id;
  final DateTime measuredAt;
  final BodyMetric metric;
  final double value;
  final String note;
}

/// Sex as the energy equations take it: they differ by a constant, and
/// nothing else in the app asks.
enum Sex {
  female('女性'),
  male('男性');

  const Sex(this.label);

  final String label;
}
