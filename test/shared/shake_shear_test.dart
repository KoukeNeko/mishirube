import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  Future<StreamController<Offset>> pumpShear(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    final motion = StreamController<Offset>.broadcast();
    addTearDown(motion.close);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(
          child: SizedBox(
            width: 160,
            height: 28,
            child: ShakeShear(
              motion: motion.stream,
              child: const ColoredBox(key: Key('chart'), color: Colors.blue),
            ),
          ),
        ),
      ),
    );
    // Held upright and still.
    motion.add(const Offset(0, 9.8));
    await tester.pump();
    return motion;
  }

  final chart = find.byKey(const Key('chart'));

  testWidgets('a shake bobs the right edge, the left one pinned, then rests', (
    tester,
  ) async {
    final motion = await pumpShear(tester);
    final left = tester.getTopLeft(chart);
    final right = tester.getTopRight(chart);

    motion.add(const Offset(0, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(chart), left, reason: 'pinned');
    expect(tester.getTopRight(chart).dy, isNot(closeTo(right.dy, 0.5)));

    motion.add(const Offset(0, 9.8));
    // Would time out if it never came to rest.
    await tester.pumpAndSettle();
    expect(tester.getTopRight(chart), right);
  });

  testWidgets('with less motion asked for, it stays still', (tester) async {
    final motion = await pumpShear(tester, reduceMotion: true);

    motion.add(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
