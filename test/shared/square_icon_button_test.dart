import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  for (final size in [36.0, 40.0, 48.0]) {
    testWidgets('a $size-point square keeps its icon in the middle', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SquareIconButton(
                icon: Icons.call_split,
                size: size,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final button = tester.getRect(find.byType(SquareIconButton));
      final icon = tester.getRect(find.byIcon(Icons.call_split));
      expect(button.size, Size.square(size));
      expect(icon.center.dx, closeTo(button.center.dx, 0.5));
      expect(icon.center.dy, closeTo(button.center.dy, 0.5));
      // The glyph is drawn from its box's corner: one wider than the box
      // spills out to one side, off the middle.
      final glyph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byIcon(Icons.call_split),
          matching: find.byType(RichText),
        ),
      );
      expect(
        glyph.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(icon.width),
        reason: 'the glyph fits the box it is centred in',
      );
    });
  }
}
