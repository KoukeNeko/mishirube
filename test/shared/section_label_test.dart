import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  /// Where [text]'s baseline sits on screen.
  double baselineOf(WidgetTester tester, String text) {
    final finder = find.descendant(
      of: find.text(text, findRichText: true),
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      finder.evaluate().isEmpty ? find.text(text, findRichText: true) : finder,
    );
    return paragraph.localToGlobal(Offset.zero).dy +
        paragraph.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  for (final (name, trailing) in [
    ('a count', Text('3 餐', style: AppTextStyles.caption)),
    // As the day's 熱量 label has it: the link's text at the bottom of
    // its touch target.
    (
      'a link',
      LinkText(label: '變更', alignment: Alignment.bottomRight, onTap: () {}),
    ),
  ]) {
    testWidgets('$name beside a label reads on the label\'s line', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SectionLabel('餐點', trailing: trailing),
                const SectionLabel('每日指標'),
              ],
            ),
          ),
        ),
      );
      final label = baselineOf(tester, '餐點');
      final beside = baselineOf(tester, name == 'a count' ? '3 餐' : '變更');
      expect(beside, closeTo(label, 1));
      final heights = [
        for (final element in find.byType(SectionLabel).evaluate())
          tester.getSize(find.byWidget(element.widget)).height,
      ];
      expect(
        heights.first,
        heights.last,
        reason: 'what sits beside a label does not make it taller',
      );
    });
  }
}
