import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  const step = Duration(minutes: 10);
  final origin = DateTime(2026, 9, 30, 12);

  /// A curve falling away from [peak] at the 40th point, as a cup does.
  List<double> falling({double peak = 100, int shift = 0}) => [
    for (var i = 0; i < 144; i++)
      i + shift < 40 ? 0 : peak * (0.5 + 0.5 * (1 - (i + shift - 40) / 104)),
  ];

  Widget chart(
    List<double> values, {
    DateTime? at,
    bool reduceMotion = false,
    double reference = 35,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: CurveChart(
        values: values,
        origin: at ?? origin,
        step: step,
        nowIndex: 48,
        color: Colors.brown,
        start: '04:00',
        now: '12:00',
        end: '04:00',
        reference: reference,
        height: 88,
      ),
    ),
  );

  testWidgets('the curve draws itself in, then the dot beats and rests', (
    tester,
  ) async {
    await tester.pumpWidget(chart(falling()));
    expect(tester.hasRunningAnimations, isTrue, reason: 'drawing in');

    await tester.pump(const Duration(milliseconds: 950));
    expect(tester.hasRunningAnimations, isTrue, reason: 'above the reference');

    // Would time out if the dot never came to rest.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('below the reference the dot has nothing to beat for', (
    tester,
  ) async {
    await tester.pumpWidget(chart(falling(peak: 40), reference: 100));
    await tester.pump(const Duration(milliseconds: 950));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with less motion asked for, it is drawn still', (tester) async {
    await tester.pumpWidget(chart(falling(), reduceMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(chart(falling(peak: 160), reduceMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse, reason: 'a change, too');
  });

  testWidgets('a new step grows the curve; a window moving on does not', (
    tester,
  ) async {
    await tester.pumpWidget(chart(falling()));
    await tester.pumpAndSettle();

    // The same curve, its window a step later: every value is the one
    // a step along, and nothing has changed but the time.
    await tester.pumpWidget(chart(falling(shift: 1), at: origin.add(step)));
    expect(tester.hasRunningAnimations, isFalse, reason: 'the window moved');

    // Another cup: the curve is higher from its time on.
    await tester.pumpWidget(
      chart([
        for (final (i, v) in falling(shift: 1).indexed)
          i < 60 ? v : v + 80 * (1 - (i - 60) / 84),
      ], at: origin.add(step)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue, reason: 'it grows');
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
