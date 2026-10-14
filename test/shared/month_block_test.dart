import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/l10n/l10n.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  // September 2026 starts on a Tuesday.
  final month = DateTime(2026, 9);
  final today = DateTime(2026, 9, 17);

  Widget page({
    ValueChanged<DateTime>? onSelect,
    bool showsTitle = true,
    Widget Function(BuildContext, DateTime)? weekTrailing,
    DateTime? selected,
  }) => MaterialApp(
    theme: buildAppTheme(),
    locale: const Locale('zh', 'TW'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: MonthBlock(
          month: month,
          firstWeekday: DateTime.monday,
          categories: const {
            3: [RecordCategory.training],
          },
          today: today,
          selected: selected,
          onSelect: onSelect,
          showsTitle: showsTitle,
          trailingWidth: weekTrailing == null ? 0 : 56,
          weekTrailing: weekTrailing,
        ),
      ),
    ),
  );

  testWidgets('a day is picked, but not one to come, and not without a way', (
    tester,
  ) async {
    final picked = <int>[];
    await tester.pumpWidget(page(onSelect: (day) => picked.add(day.day)));
    await tester.tap(find.text('10'));
    await tester.tap(find.text('24'), warnIfMissed: false);
    expect(picked, [10], reason: 'the 24th is to come');

    picked.clear();
    await tester.pumpWidget(page());
    await tester.tap(find.text('10'), warnIfMissed: false);
    expect(picked, isEmpty);
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('9月10日')),
      isNot(matchesSemantics(isButton: true)),
      reason: 'nothing to press',
    );
    semantics.dispose();
  });

  testWidgets('the month names itself over its first day, unless told not to', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    expect(find.text('9月'), findsOneWidget);
    await tester.pumpWidget(page(showsTitle: false));
    expect(find.text('9月'), findsNothing);
  });

  testWidgets('what ends each week is given the week its row starts', (
    tester,
  ) async {
    final starts = <DateTime>[];
    await tester.pumpWidget(
      page(
        weekTrailing: (context, start) {
          starts.add(start);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(starts, [
      for (final day in [31, 7, 14, 21, 28])
        day == 31 ? DateTime(2026, 8, 31) : DateTime(2026, 9, day),
    ], reason: 'Mondays, the first in the month before');
  });

  test('a month is as tall as its weeks', () {
    expect(monthWeeks(month, DateTime.monday), 5);
    expect(monthWeeks(month, DateTime.sunday), 5);
    expect(
      monthBlockHeight(month, DateTime.monday, showsTitle: false),
      5 * monthRowHeight,
    );
    expect(
      monthBlockHeight(month, DateTime.monday),
      5 * monthRowHeight + monthTitleHeight,
    );
  });
}
