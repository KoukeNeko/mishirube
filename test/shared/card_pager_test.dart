import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../support/harness.dart';

void main() {
  Future<void> pumpPager(WidgetTester tester, int count) {
    usePhoneViewport(tester);
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              CardPager(
                children: [
                  for (var i = 0; i < count; i++)
                    AppCard(child: Text('Card $i')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Finder card(int index) => find.ancestor(
    of: find.text('Card $index'),
    matching: find.byType(AppCard),
  );

  double screenWidth(WidgetTester tester) =>
      tester.view.physicalSize.width / tester.view.devicePixelRatio;

  testWidgets('a lone card is as wide as the page column', (tester) async {
    await pumpPager(tester, 1);

    expect(tester.getTopLeft(card(0)).dx, AppSpacing.screenGutter);
    expect(
      tester.getSize(card(0)).width,
      screenWidth(tester) - 2 * AppSpacing.screenGutter,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  testWidgets('the next card shows past the edge of the screen', (
    tester,
  ) async {
    await pumpPager(tester, 3);

    expect(tester.getTopLeft(card(0)).dx, AppSpacing.screenGutter);
    final next = card(1);
    expect(tester.getTopLeft(next).dx, lessThan(screenWidth(tester)));
    expect(tester.getTopRight(next).dx, greaterThan(screenWidth(tester)));
    expect(
      tester.getTopLeft(card(0)).dy,
      tester.getTopLeft(next).dy,
      reason: 'in one row',
    );
  });

  testWidgets('a swipe stops on a card, never between two', (tester) async {
    await pumpPager(tester, 3);

    // Far enough to be nearer the second card than the first.
    await tester.drag(find.byType(CardPager), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card(1)).dx, AppSpacing.screenGutter);

    // Not far enough: back to where it was.
    await tester.drag(find.byType(CardPager), const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(card(1)).dx, AppSpacing.screenGutter);

    await tester.fling(find.byType(CardPager), const Offset(-100, 0), 1500);
    await tester.pumpAndSettle();
    expect(
      tester.getTopRight(card(2)).dx,
      screenWidth(tester) - AppSpacing.screenGutter,
      reason: 'the last one, against the margin',
    );
  });

  testWidgets(
    'the last card rests against the margin, the one before showing',
    (tester) async {
      await pumpPager(tester, 2);

      await tester.fling(find.byType(CardPager), const Offset(-300, 0), 2000);
      await tester.pumpAndSettle();

      expect(
        tester.getTopRight(card(1)).dx,
        screenWidth(tester) - AppSpacing.screenGutter,
      );
      expect(tester.getTopRight(card(0)).dx, greaterThan(0));
      expect(tester.getTopLeft(card(0)).dx, lessThan(0));
    },
  );
}
