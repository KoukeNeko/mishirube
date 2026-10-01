import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/usual_range.dart';

void main() {
  final day0 = DateTime(2026, 9, 1);
  List<(DateTime, double)> daily(List<double> values) => [
    for (final (index, value) in values.indexed)
      (day0.add(Duration(days: index)), value),
  ];

  test('the usual range is the lowest to the highest of the days before', () {
    final days = daily([for (var i = 0; i < 21; i++) 50.0 + i % 20]);
    final ranges = rollingUsualRanges(days);
    expect(ranges.take(14), everyElement(isNull), reason: '13 days before');
    expect(ranges[14], (low: 50.0, high: 63.0), reason: '14 days before');
    expect(ranges.last, (
      low: 50.0,
      high: 69.0,
    ), reason: 'the day itself left out');
  });

  test('the window holds 28 days back, not the 29th', () {
    final day = DateTime(2026, 10, 30);
    final days = [
      (day.subtract(const Duration(days: 29)), 200.0),
      for (var back = 28; back >= 15; back--)
        (day.subtract(Duration(days: back)), 60.0),
    ];
    expect(usualRangeBefore(days, day), (low: 60.0, high: 60.0));
  });

  test('a day without a figure is not a figure', () {
    expect(usualRangeOf([for (var i = 0; i < 13; i++) 1.0]), isNull);
    expect(usualRangeOf([for (var i = 0; i < 14; i++) 1.0]), isNotNull);
  });

  test('on an edge is within', () {
    const range = (low: 12.0, high: 20.0);
    expect(positionIn(11.9, range), UsualPosition.below);
    expect(positionIn(12, range), UsualPosition.within);
    expect(positionIn(20, range), UsualPosition.within);
    expect(positionIn(20.1, range), UsualPosition.above);
    expect(positionIn(21, null), isNull);
  });

  test('ordinary days fall outside about 2 in n + 1 times', () {
    // Interchangeable days: a new one is outside the lowest and highest
    // of the 28 before it with a chance of 2/29, some 7%.
    final random = math.Random(7);
    final days = daily([for (var i = 0; i < 4000; i++) random.nextDouble()]);
    final ranges = rollingUsualRanges(days);
    var judged = 0;
    var outside = 0;
    for (final (index, (_, value)) in days.indexed) {
      if (positionIn(value, ranges[index]) case final position?) {
        judged++;
        if (position != UsualPosition.within) outside++;
      }
    }
    expect(outside / judged, closeTo(2 / 29, 0.015));
  });
}
