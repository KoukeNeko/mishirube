import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  group('the corners of a segment', () {
    BorderRadius at(int row, int rows, int column, int columns) =>
        segmentRadius(row: row, rows: rows, column: column, columns: columns);
    const outer = Radius.circular(segmentOuterRadius);
    const inner = Radius.circular(segmentInnerRadius);

    test('a lone segment is a card, round on every side', () {
      expect(at(0, 1, 0, 1), const BorderRadius.all(outer));
    });

    test('a column of rows is round at the top and the bottom only', () {
      expect(
        at(0, 3, 0, 1),
        const BorderRadius.vertical(top: outer, bottom: inner),
      );
      expect(at(1, 3, 0, 1), const BorderRadius.all(inner));
      expect(
        at(2, 3, 0, 1),
        const BorderRadius.vertical(top: inner, bottom: outer),
      );
    });

    test('two side by side are round on the outside only', () {
      expect(
        at(0, 1, 0, 2),
        const BorderRadius.horizontal(left: outer, right: inner),
      );
      expect(
        at(0, 1, 1, 2),
        const BorderRadius.horizontal(left: inner, right: outer),
      );
    });

    test('in a grid each corner is round where it meets the group edge', () {
      expect(
        at(0, 2, 1, 2),
        const BorderRadius.only(
          topLeft: inner,
          topRight: outer,
          bottomLeft: inner,
          bottomRight: inner,
        ),
      );
      expect(
        at(1, 2, 0, 2),
        const BorderRadius.only(
          topLeft: inner,
          topRight: inner,
          bottomLeft: outer,
          bottomRight: inner,
        ),
      );
    });
  });

  testWidgets(
    'a segment is a button that opens, and one without a tap is not',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SegmentedGroup(
              rows: [
                [
                  Segment(
                    onTap: () => taps++,
                    child: const SizedBox(height: 56, child: Text('a')),
                  ),
                  const Segment(child: SizedBox(height: 56, child: Text('b'))),
                ],
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'nothing to do, nothing to open');
    },
  );

  testWidgets('a figure without a value says so and draws no bar', (
    tester,
  ) async {
    Widget stat({String? value}) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SegmentStat(
          label: '睡眠',
          color: AppColors.wellness,
          mark: (tint) => Icon(Icons.bedtime_outlined, color: tint),
          placeholder: '沒有紀錄',
          value: value,
          progress: 0.5,
        ),
      ),
    );

    await tester.pumpWidget(stat());
    expect(find.text('沒有紀錄'), findsOneWidget);
    expect(find.byType(ThickProgress), findsNothing);

    await tester.pumpWidget(stat(value: '7 小時'));
    expect(find.text('沒有紀錄'), findsNothing);
    expect(find.byType(ThickProgress), findsOneWidget);
  });

  testWidgets('a bar runs to a new length, and stops at the target', (
    tester,
  ) async {
    Widget bar(double progress) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: ThickProgress(progress: progress, color: Colors.orange),
        ),
      ),
    );

    await tester.pumpWidget(bar(0.25));
    await tester.pumpAndSettle();
    await tester.pumpWidget(bar(1.5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue, reason: 'on its way');
    await tester.pumpAndSettle();
    expect(
      tester.widget<ThickProgress>(find.byType(ThickProgress)).progress,
      1.5,
      reason: 'it is told what it is; it draws only as far as full',
    );
  });
}
