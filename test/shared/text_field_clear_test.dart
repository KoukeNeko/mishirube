import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/l10n/l10n.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  Future<void> pumpField(WidgetTester tester, Widget field) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(body: field),
        ),
      );

  for (final (name, build)
      in <(String, Widget Function(TextEditingController))>[
        ('a text field', (c) => AppTextField(controller: c)),
        ('a search field', (c) => SearchField(controller: c, hint: '')),
      ]) {
    testWidgets('$name has a clear button while it has text', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpField(tester, build(controller));
      final clear = find.byTooltip('清除');
      expect(clear, findsNothing);

      controller.text = '牛丼套餐';
      await tester.pump();
      expect(clear, findsOneWidget);

      await tester.tap(clear);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(clear, findsNothing);
    });
  }

  testWidgets('a field of several lines has none', (tester) async {
    final controller = TextEditingController(text: '一行\n兩行');
    addTearDown(controller.dispose);
    await pumpField(tester, AppTextField(controller: controller, maxLines: 4));
    expect(find.byTooltip('清除'), findsNothing);
  });
}
