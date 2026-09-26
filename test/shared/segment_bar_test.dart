import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  testWidgets('each segment takes its share of the bar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 202,
              child: SegmentBar(
                segments: [
                  (1, Colors.red),
                  (0, Colors.green),
                  (3, Colors.blue),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final boxes = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(SegmentBar),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(
      [for (final box in boxes) box.color],
      [Colors.red, Colors.blue],
      reason: 'nothing to show for a zero',
    );
    double widthOf(Color color) => tester
        .getSize(
          find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == color,
          ),
        )
        .width;
    // 200 of the 202 points after the hairline between them, 1 : 3.
    expect(widthOf(Colors.red), closeTo(50, 1));
    expect(widthOf(Colors.blue), closeTo(150, 1));
    expect(
      tester.getSize(find.byType(SegmentBar)).height,
      12,
      reason: 'the segments fill the bar, not collapse to nothing',
    );
  });
}
