import '../../app/view_model.dart';
import '../../backend/engines/body_metrics.dart';
import '../../domain/domain.dart';

/// The body page: weight and its trend, height and what follows from it,
/// what a body composition scale reported, and tape measurements. Every
/// figure is read from the records; the derived ones are worked out on
/// each read.
class BodyViewModel extends ViewModel {
  BodyViewModel(super.backend);

  DateTime get _end => backend.db.nowInclusive;

  /// Weighings over [window] with each one's trend, oldest first.
  List<(DateTime, double weight, double trend)> weightTrend(Duration window) {
    // The trend at the window's start needs the week before it too.
    final weights = backend.journal.weightsBetween(
      _end.subtract(window + trendWindow),
      _end,
    );
    final from = _end.subtract(window);
    return [
      for (final point in trendOf(weights))
        if (!point.$1.isBefore(from)) point,
    ];
  }

  BodyWeight? get latestWeight => backend.journal
      .weightsBetween(_end.subtract(const Duration(days: 3650)), _end)
      .lastOrNull;

  Map<BodyMetric, BodyReading> get latestReadings =>
      backend.journal.latestBodyReadings();

  Map<MeasurementSite, BodyMeasurement> get latestMeasurements =>
      backend.journal.latestMeasurements();

  /// Readings of [metric] over [window], oldest first.
  List<(DateTime, double)> readings(BodyMetric metric, Duration window) => [
    for (final reading in backend.journal.bodyReadingsBetween(
      metric,
      _end.subtract(window),
      _end,
    ))
      (reading.measuredAt, reading.value),
  ];

  /// Tape measurements of [site] over [window], oldest first.
  List<(DateTime, double)> measurements(
    MeasurementSite site,
    Duration window,
  ) => [
    for (final measurement in backend.journal.measurementsBetween(
      _end.subtract(window),
      _end,
    ))
      if (measurement.site == site)
        (measurement.measuredAt, measurement.centimetres),
  ];

  double? get _height => latestReadings[BodyMetric.height]?.value;

  double? get bmi => switch (latestWeight) {
    final weight? => bmiOf(weight.weightKg, _height),
    null => null,
  };

  double? get ffmi =>
      ffmiOf(latestReadings[BodyMetric.leanMass]?.value, _height);

  /// Fat mass from the latest weight and body fat, when both are there.
  double? get fatMassKg {
    final weight = latestWeight?.weightKg;
    final fat = latestReadings[BodyMetric.bodyFat]?.value;
    if (weight == null || fat == null) return null;
    return weight * fat / 100;
  }

  double? get waistToHip {
    final waist = latestMeasurements[MeasurementSite.waist]?.centimetres;
    final hips = latestMeasurements[MeasurementSite.hips]?.centimetres;
    if (waist == null || hips == null || hips == 0) return null;
    return waist / hips;
  }
}
