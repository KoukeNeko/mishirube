import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  const minutes = [420, 360, 480, 450];

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              width: 400,
              child: ChartScrubber(
                count: minutes.length,
                indexAt: ChartScrubber.slots(minutes.length),
                idle: '平均',
                readoutOf: (index) => '第 ${index + 1} 晚 ${minutes[index]}',
                builder: (context, selected) => MiniBarChart(
                  bars: [for (final m in minutes) ('', m)],
                  selected: selected,
                ),
              ),
            ),
            const SizedBox(height: 200, child: Text('別處')),
          ],
        ),
      ),
    ),
  );

  testWidgets('touching a bar reads it out, and sliding reads the next', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('平均'), findsOneWidget);
    final chart = tester.getRect(find.byType(MiniBarChart));

    await tester.tapAt(chart.centerLeft + const Offset(10, 0));
    await tester.pump();
    expect(find.text('第 1 晚 420'), findsOneWidget);

    final drag = await tester.startGesture(
      chart.centerLeft + const Offset(10, 0),
    );
    await drag.moveBy(const Offset(40, 0));
    await drag.moveBy(Offset(chart.width - 60, 0));
    await tester.pump();
    expect(find.text('第 4 晚 450'), findsOneWidget);
    await drag.up();
  });

  testWidgets('a tap elsewhere puts the reading away', (tester) async {
    await pump(tester);
    await tester.tapAt(tester.getCenter(find.byType(MiniBarChart)));
    await tester.pump();
    expect(find.text('平均'), findsNothing);

    await tester.tap(find.text('別處'));
    await tester.pump();
    expect(find.text('平均'), findsOneWidget);
  });
}
