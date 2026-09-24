import '../../domain/domain.dart';

/// Bumped whenever a rule below changes.
const bodyMetricsVersion = 1;

/// Days of weighings a trend weight averages over: long enough that a
/// salty dinner or a glass of water does not move it, short enough to
/// follow a real change within a week or two.
const trendWindow = Duration(days: 7);

/// Body mass index, kg/m², from a weight and a height; null without a
/// height to divide by.
double? bmiOf(double weightKg, double? heightCm) {
  if (heightCm == null || heightCm <= 0) return null;
  final metres = heightCm / 100;
  return weightKg / (metres * metres);
}

/// The Health Promotion Administration's adult bands, which are lower
/// than the WHO's because they were set for Taiwanese adults.
enum BmiBand {
  under('體重過輕'),
  healthy('健康體重'),
  over('過重'),
  obese('肥胖');

  const BmiBand(this.label);

  final String label;
}

BmiBand bmiBandOf(double bmi) => switch (bmi) {
  < 18.5 => BmiBand.under,
  < 24 => BmiBand.healthy,
  < 27 => BmiBand.over,
  _ => BmiBand.obese,
};

/// Fat-free mass index, kg/m²: lean mass for a height, which unlike BMI
/// does not count muscle as excess. Null without both.
double? ffmiOf(double? leanKg, double? heightCm) {
  if (leanKg == null) return null;
  return bmiOf(leanKg, heightCm);
}

/// Each weighing with the average of the weighings in the [trendWindow]
/// up to it, oldest first: the line to read a trend from, where a single
/// day's figure swings with water and food.
List<(DateTime, double weight, double trend)> trendOf(
  List<BodyWeight> weights,
) {
  final sorted = [...weights]
    ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  return [
    for (final (index, weight) in sorted.indexed)
      () {
        final from = weight.measuredAt.subtract(trendWindow);
        final window = [
          for (final other in sorted.take(index + 1))
            if (other.measuredAt.isAfter(from)) other.weightKg,
        ];
        return (
          weight.measuredAt,
          weight.weightKg,
          window.reduce((a, b) => a + b) / window.length,
        );
      }(),
  ];
}

/// How much the trend moved over [trend], first to last; null with fewer
/// than two points.
double? trendChange(List<(DateTime, double, double)> trend) {
  if (trend.length < 2) return null;
  return trend.last.$3 - trend.first.$3;
}
