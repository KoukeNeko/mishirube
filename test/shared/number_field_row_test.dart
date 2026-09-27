import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';
import 'package:mishirube/l10n/l10n.dart';

void main() {
  testWidgets('the field is a full box, easy to hit, and takes a number', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NumberFieldRow(
            fieldKey: const ValueKey('fat'),
            label: '體脂率',
            unit: '%',
            caption: '上次 18.2 % · 9/19',
            controller: controller,
          ),
        ),
      ),
    );

    final field = tester.getSize(find.byKey(const ValueKey('fat')));
    expect(field.height, greaterThanOrEqualTo(44), reason: 'a touch target');
    expect(field.width, 120);
    expect(find.text('上次 18.2 % · 9/19'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fat')));
    await tester.enterText(find.byKey(const ValueKey('fat')), '17.9');
    expect(controller.text, '17.9');
  });
}
