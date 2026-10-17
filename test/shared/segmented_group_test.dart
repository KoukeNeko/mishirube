import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

  group('a held segment', () {
    /// The right corner of the first of two segments side by side, which is
    /// tight at rest.
    double innerCorner(WidgetTester tester) {
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text('a'), matching: find.byType(Material))
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      return (shape.borderRadius as BorderRadius).topRight.x;
    }

    Widget group({required Widget Function(Widget) around}) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: around(
          SegmentedGroup(
            rows: [
              [
                Segment(
                  onTap: () {},
                  child: const SizedBox(height: 56, child: Text('a')),
                ),
                Segment(
                  onTap: () {},
                  child: const SizedBox(height: 56, child: Text('b')),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    testWidgets('opens its tight corners, and closes them when let go', (
      tester,
    ) async {
      await tester.pumpWidget(group(around: (child) => child));
      expect(innerCorner(tester), segmentInnerRadius);

      final touch = await tester.startGesture(tester.getCenter(find.text('a')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 400));
      expect(innerCorner(tester), closeTo(segmentOuterRadius, 0.5));

      await touch.up();
      await tester.pumpAndSettle();
      expect(innerCorner(tester), closeTo(segmentInnerRadius, 0.01));
    });

    testWidgets('stays as it is when the touch becomes a scroll', (
      tester,
    ) async {
      await tester.pumpWidget(
        group(around: (child) => ListView(children: [child])),
      );
      final touch = await tester.startGesture(tester.getCenter(find.text('a')));
      await touch.moveBy(const Offset(0, -80));
      // The first frame only starts a spring, so there are two.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 400));
      expect(innerCorner(tester), closeTo(segmentInnerRadius, 0.01));
      await touch.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a labelled segment is one button that carries its label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SegmentedGroup(
            rows: [
              [
                Segment(
                  onTap: () {},
                  semanticLabel: '週一，有紀錄',
                  child: const SizedBox(height: 56, child: Text('一')),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('週一，有紀錄'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      find.semantics.byAction(SemanticsAction.tap),
      findsOneWidget,
      reason: 'no nameless button beside the label',
    );
    semantics.dispose();
  });

  testWidgets('a row keeps its figure on the row at a large text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.4)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SegmentedGroup(
              rows: [
                [
                  Segment(
                    child: SegmentRow(
                      title: '血壓',
                      caption: '10 月 9 日',
                      trailing: const SizedBox(width: 72, height: 24),
                      value: '118/76 mmHg',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: 'it shrinks, not overflows');
    expect(find.text('118/76 mmHg'), findsOneWidget);
  });

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

  testWidgets('a bar fills in as a chart does, and again when it changes', (
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
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue, reason: 'drawn in on show');
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(bar(0.5));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue, reason: 'and on a change');
    await tester.pumpAndSettle();
  });

  testWidgets('a bar for work under way runs to a new length, and stops at '
      'the target', (tester) async {
    Widget bar(double progress) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: ThickProgress(
            progress: progress,
            color: Colors.orange,
            drawsIn: false,
          ),
        ),
      ),
    );

    await tester.pumpWidget(bar(0.25));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse, reason: 'there as it is');
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

  testWidgets('a choice lights the one picked, says so, and picks another', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final picked = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SegmentedGroup(
            rows: [
              choiceButtons<int>(
                options: const [1, 2, 3],
                labelOf: (days) => '$days 天',
                isSelected: (days) => days == 2,
                onTap: picked.add,
              ),
            ],
          ),
        ),
      ),
    );

    Color surfaceOf(String label) => tester
        .widget<Material>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        )
        .color!;
    expect(surfaceOf('2 天'), AppColors.training);
    expect(surfaceOf('1 天'), AppColors.surface);
    expect(
      find.semantics.byFlag(SemanticsFlag.isSelected),
      findsOneWidget,
      reason: 'the picked one says it is selected',
    );

    await tester.tap(find.text('3 天'));
    expect(picked, [3]);
    semantics.dispose();
  });
}
