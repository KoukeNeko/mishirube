import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

Widget _page(ProgressLine line) => MaterialApp(
  home: Scaffold(body: Center(child: line)),
);

double? _valueOf(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value;

void main() {
  testWidgets('a figure against its target fills in as a chart does', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(const ProgressLine(progress: 0.6, drawsIn: true)),
    );
    expect(_valueOf(tester), 0, reason: 'drawn in from nothing');
    await tester.pump();
    await tester.pump(chartEntranceDuration * 0.3);
    expect(_valueOf(tester), inExclusiveRange(0, 0.6));
    await tester.pumpAndSettle();
    expect(_valueOf(tester), closeTo(0.6, 1e-9));
  });

  testWidgets('work under way shows where it is at once', (tester) async {
    await tester.pumpWidget(_page(const ProgressLine(progress: 0.6)));
    expect(_valueOf(tester), 0.6);
  });
}
