import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  Future<StreamController<Offset>> pumpFill(
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
            height: 120,
            child: LevelFill(
              level: 0.5,
              color: Colors.blue,
              motion: motion.stream,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return motion;
  }

  testWidgets('tilting and shaking set the water moving, then it rests', (
    tester,
  ) async {
    final motion = await pumpFill(tester);

    // Held upright and still: nothing to answer.
    motion.add(const Offset(0, 9.8));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    // Turned clockwise: the surface leans back towards level.
    motion.add(const Offset(-4, 8.9));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue, reason: 'it rocks');

    // A shake across the screen.
    motion.add(const Offset(-14, 8.9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue, reason: 'it sloshes');

    // Would time out if the water never came to rest.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with less motion asked for, the water stays still', (
    tester,
  ) async {
    final motion = await pumpFill(tester, reduceMotion: true);

    motion.add(const Offset(0, 9.8));
    motion.add(const Offset(-14, 8.9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
