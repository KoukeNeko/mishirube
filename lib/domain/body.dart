/// Where on the body a tape measure went. The app measures what people
/// actually track at home; body composition needs equipment this app
/// cannot stand behind, so it is not offered as a guess.
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
