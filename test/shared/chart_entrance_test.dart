import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

/// A chart that says how far in it is.
Widget _chart(String name) => SizedBox(
  height: 100,
  child: ChartEntrance(
    shows: const [1],
    builder: (context, progress) => Text('$name $progress'),
  ),
);

double _progressOf(WidgetTester tester, String name) {
  final text = tester
      .widgetList<Text>(find.byType(Text, skipOffstage: false))
      .map((text) => text.data!)
      .firstWhere((data) => data.startsWith('$name '));
  return double.parse(text.substring(name.length + 1));
}

/// A list with one chart on screen and one far below.
Widget _page() => MaterialApp(
  home: Scaffold(
    body: ListView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(2000),
      children: [
        _chart('top'),
        const SizedBox(height: 1500),
        _chart('below'),
        const SizedBox(height: 1500),
      ],
    ),
  ),
);

void main() {
  testWidgets('a chart below the fold waits until it is scrolled to', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();
    expect(_progressOf(tester, 'top'), 1);
    expect(
      _progressOf(tester, 'below'),
      0,
      reason: 'built ahead of the screen, not yet seen',
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(_progressOf(tester, 'below'), 1);
  });

  testWidgets('a chart only passed on the way does not play', (tester) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();

    final list = tester.state<ScrollableState>(find.byType(Scrollable));
    list.position.jumpTo(1400);
    await tester.pump();
    await tester.pump(chartEntranceDwell ~/ 2);
    list.position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      _progressOf(tester, 'below'),
      0,
      reason: 'in view for less than the dwell',
    );
  });

  testWidgets('a chart on a page sliding in starts as it arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: _chart('pushed')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_progressOf(tester, 'pushed'), 0, reason: 'only setting off');

    // Drawn over the end of the slide, not after it settles.
    final route = ModalRoute.of(tester.element(find.text('pushed 0.0')))!;
    while (route.animation!.status != AnimationStatus.completed) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_progressOf(tester, 'pushed'), greaterThan(0));

    await tester.pumpAndSettle();
    expect(_progressOf(tester, 'pushed'), 1);
  });

  testWidgets('a chart that played keeps it when scrolled away and back', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    await tester.pumpAndSettle();
    expect(_progressOf(tester, 'top'), 1);

    final list = tester.state<ScrollableState>(find.byType(Scrollable));
    list.position.jumpTo(list.position.maxScrollExtent);
    await tester.pumpAndSettle();
    list.position.jumpTo(0);
    await tester.pump();
    expect(_progressOf(tester, 'top'), 1, reason: 'not drawn in again');
  });
}
