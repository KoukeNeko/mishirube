import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/body_metrics.dart';
import 'package:mishirube/domain/domain.dart';

void main() {
  test('BMI needs a height, and falls in the Taiwanese bands', () {
    expect(bmiOf(70, null), isNull);
    expect(bmiOf(72.4, 175), closeTo(23.64, 0.01));
    expect(bmiBandOf(18.4), BmiBand.under);
    expect(bmiBandOf(23.9), BmiBand.healthy);
    expect(bmiBandOf(24), BmiBand.over, reason: 'lower than the WHO 25');
    expect(bmiBandOf(27), BmiBand.obese);
    expect(ffmiOf(58, 175), closeTo(18.94, 0.01));
    expect(ffmiOf(null, 175), isNull);
  });

  test('the trend averages the week up to each weighing', () {
    BodyWeight on(int day, double kg) => BodyWeight(
      id: '$day',
      measuredAt: DateTime(2026, 9, day, 7),
      weightKg: kg,
    );
    final trend = trendOf([on(3, 71), on(1, 72), on(2, 73), on(10, 70)]);

    expect([for (final point in trend) point.$1.day], [1, 2, 3, 10]);
    expect(trend[2].$3, 72, reason: 'days 1–3');
    expect(trend[3].$3, 70, reason: 'the first week has left the window');
    expect(trendChange(trend), -2);
    expect(trendChange(trend.take(1).toList()), isNull);
  });
}
