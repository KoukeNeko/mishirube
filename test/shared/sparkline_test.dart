import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  Finder sparklinePaint() => find.descendant(
    of: find.byType(Sparkline),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString() == '_SparklinePainter',
    ),
  );

  Future<void> pumpSparkline(WidgetTester tester, List<double?> values) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 300, child: Sparkline(values: values)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('readings far apart are joined by one line', (tester) async {
    await pumpSparkline(tester, [60, null, null, null, 80, null, 70]);

    expect(
      tester.renderObject(sparklinePaint()),
      paints
        ..path()
        ..circle(),
      reason: 'a line through the three readings, then the end dot',
    );
    // Not a dot for each reading standing alone.
    expect(
      tester.renderObject(sparklinePaint()),
      isNot(
        paints
          ..circle()
          ..circle()
          ..circle(),
      ),
    );
  });

  testWidgets('a single reading is a dot, with no line', (tester) async {
    await pumpSparkline(tester, [null, null, 70, null]);

    expect(tester.renderObject(sparklinePaint()), isNot(paints..path()));
    expect(tester.renderObject(sparklinePaint()), paints..circle());
  });
}
