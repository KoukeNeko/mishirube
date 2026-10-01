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
    await tester.pumpAndSettle();

    final bars = tester
        .widgetList<Container>(find.byType(Container))
        .map((bar) => bar.constraints?.maxHeight)
        .toList();
    expect(bars, [80, greaterThan(0)], reason: 'no bar for the empty day');
  });

  Widget chart({required bool reduceMotion, List<(String, int?)>? bars}) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              child: MiniBarChart(
                bars: bars ?? const [('一', 10), ('二', 10)],
                showLabels: false,
              ),
            ),
          ),
        ),
      );

  List<double?> heights(WidgetTester tester) => [
    for (final bar in tester.widgetList<Container>(find.byType(Container)))
      bar.constraints?.maxHeight,
  ];

  testWidgets('bars rise into place, the first ahead of the next', (
    tester,
  ) async {
    await tester.pumpWidget(chart(reduceMotion: false));
    expect(heights(tester), everyElement(0), reason: 'drawn in from nothing');
    await tester.pump(chartEntranceDwell);
    expect(heights(tester), everyElement(0), reason: 'a moment in view first');

    await tester.pump(chartEntranceDuration * 0.3);
    final [first, second] = heights(tester);
    expect(first!, greaterThan(second!), reason: 'one after another');

    await tester.pumpAndSettle();
    expect(heights(tester), [80, 80]);

    // A reading picking a bar is no change to what the chart shows.
    await tester.pumpWidget(chart(reduceMotion: false));
    await tester.pump();
    expect(heights(tester), [80, 80], reason: 'the same bars do not replay');

    await tester.pumpWidget(
      chart(reduceMotion: false, bars: const [('一', 5), ('二', 10)]),
    );
    await tester.pump();
    expect(heights(tester), everyElement(lessThan(80)), reason: 'new bars do');
    await tester.pumpAndSettle();
  });

  testWidgets('with Reduce Motion the bars are drawn whole at once', (
    tester,
  ) async {
    await tester.pumpWidget(chart(reduceMotion: true));
    expect(heights(tester), [80, 80]);
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
