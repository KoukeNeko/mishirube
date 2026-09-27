import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  testWidgets('a row in a grouped card slides over its action, opaque', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupedCard(
            children: [
              SwipeAction(
                label: '移除',
                semanticLabel: '移除「藍莓」',
                radius: 0,
                onAction: () {},
                child: const NavRow(title: '藍莓'),
              ),
            ],
          ),
        ),
      ),
    );
    final before = tester.getRect(find.text('藍莓'));

    await tester.drag(find.text('藍莓'), const Offset(-40, 0));
    await tester.pump();

    expect(tester.getRect(find.text('藍莓')).left, lessThan(before.left));
    final background = find
        .ancestor(of: find.text('藍莓'), matching: find.byType(ColoredBox))
        .first;
    expect(
      tester.widget<ColoredBox>(background).color,
      AppColors.surface,
      reason: 'the red behind it must not show through the row',
    );
    expect(
      tester.getRect(background).left,
      lessThan(tester.getRect(find.byType(SwipeAction)).left),
      reason: 'the background moves with the row',
    );
  });
}
