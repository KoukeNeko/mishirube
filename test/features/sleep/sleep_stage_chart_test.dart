import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/sleep_stage_chart.dart';

void main() {
  final bed = DateTime(2026, 9, 23, 2);
  SleepSample stretch(int from, int to, SleepStage stage) => SleepSample(
    start: bed.add(Duration(minutes: from)),
    end: bed.add(Duration(minutes: to)),
    stage: stage,
  );
  final night = [
    stretch(0, 60, SleepStage.core),
    stretch(60, 120, SleepStage.deep),
    stretch(120, 180, SleepStage.rem),
    stretch(180, 240, SleepStage.awake),
  ];

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 400, child: SleepStageChart(stages: night)),
        ),
      ),
    ),
  );

  testWidgets('touching the chart reads out the stretch at that time', (
    tester,
  ) async {
    await pump(tester);
    final chart = tester.getRect(find.byType(CustomPaint).last);
    expect(find.textContaining('深層 ·'), findsNothing);

    // Three eighths of the night: inside the deep stretch.
    await tester.tapAt(
      Offset(chart.left + chart.width * 3 / 8, chart.center.dy),
    );
    await tester.pump();
    expect(find.text('深層 · 03:00–04:00 · 1:00'), findsOneWidget);

    await tester.dragFrom(
      Offset(chart.left + chart.width * 3 / 8, chart.center.dy),
      Offset(chart.width / 4, 0),
    );
    await tester.pump();
    expect(find.textContaining('REM · 04:00–05:00'), findsOneWidget);
  });

  testWidgets('each stage row is tall enough to read a short stretch', (
    tester,
  ) async {
    await pump(tester);
    final chart = tester.getRect(find.byType(CustomPaint).last);
    expect(chart.height, greaterThanOrEqualTo(4 * 52));
    expect(chart.width, 400, reason: 'the whole width, no label column');
  });
}
