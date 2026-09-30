import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  testWidgets('nothing recorded is a gap, a zero is a line on the axis', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: MiniBarChart(
              bars: [('一', 10), ('二', 0), ('三', null)],
              showLabels: false,
            ),
          ),
        ),
      ),
    );

    final bars = tester
        .widgetList<Container>(find.byType(Container))
        .map((bar) => bar.constraints?.maxHeight)
        .toList();
    expect(bars, [80, greaterThan(0)], reason: 'no bar for the empty day');
  });

  testWidgets('the period still going has its label on a capsule', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: MiniBarChart(bars: [('一', 3), ('二', 5), ('三', 1)]),
          ),
        ),
      ),
    );

    Color? fillOf(String label) =>
        (tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: find.text(label),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration)
            .color;
    expect(fillOf('三'), AppColors.surfaceRaised);
    expect(fillOf('一'), Colors.transparent);
  });
}
