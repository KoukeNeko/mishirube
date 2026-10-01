import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/sleep_regularity_card.dart';
import 'package:mishirube/l10n/l10n.dart';

void main() {
  final day = DateTime(2026, 9, 30);

  /// A night ending [back] days before [day] at [wake], after eight hours.
  SleepEntry night(int back, {int wake = 7}) {
    final woke = DateTime(day.year, day.month, day.day - back, wake);
    return SleepEntry(
      id: '$back',
      sleptAt: woke,
      duration: const Duration(hours: 8),
      startedAt: woke.subtract(const Duration(hours: 8)),
    );
  }

  Future<void> pumpCard(WidgetTester tester, List<SleepEntry> nights) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SleepRegularityCard(nights: nights, day: day),
            ),
          ),
        ),
      );

  testWidgets('four weeks of the same night read 100, against the four '
      'before', (tester) async {
    await pumpCard(tester, [for (var back = 0; back < 56; back++) night(back)]);

    expect(find.text('100'), findsOneWidget);
    expect(find.text('睡眠規律指數 · 近 28 天'), findsOneWidget);
    expect(find.text('前 28 天 100'), findsOneWidget);
    expect(find.text('23:00 · ±0 分'), findsOneWidget);
    expect(find.text('週末與平日睡眠中點相同'), findsOneWidget);
    expect(find.textContaining('/ 100'), findsNothing, reason: 'not a score');
  });

  testWidgets('weekends two hours later read so, in words', (tester) async {
    await pumpCard(tester, [
      for (var back = 0; back < 28; back++)
        night(
          back,
          wake: switch (day.subtract(Duration(days: back)).weekday) {
            DateTime.saturday || DateTime.sunday => 9,
            _ => 7,
          },
        ),
    ]);
    expect(find.text('週末睡眠中點晚 2:00'), findsOneWidget);
  });

  testWidgets('too few nights say what the index needs', (tester) async {
    await pumpCard(tester, [for (var back = 0; back < 9; back++) night(back)]);

    expect(find.text('需要近 28 天有 14 晚記下入睡與起床時間（目前 9 晚）'), findsOneWidget);
    expect(find.text('睡眠規律指數 · 近 28 天'), findsNothing);
  });
}
