import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  testWidgets('the share is filled in, as wide as its part of the track', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: ShareBar(share: 0.5, color: Color(0xFF00FF00)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fill = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          (widget.decoration as ShapeDecoration).color ==
              const Color(0xFF00FF00),
    );
    expect(tester.getSize(fill), const Size(150, 16));
  });

  testWidgets('a split bar fills its height once drawn in', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: SegmentBar(
              segments: [(1, Color(0xFF00FF00)), (3, Color(0xFF0000FF))],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final parts = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .map((box) => tester.getSize(find.byWidget(box)))
        .toList();
    expect(parts, hasLength(2));
    expect(parts.every((size) => size.height == 12), isTrue);
    expect(parts[0].width + parts[1].width + 2, closeTo(300, 1));
  });
}
