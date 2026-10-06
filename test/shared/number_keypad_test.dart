import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/l10n/l10n.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../support/harness.dart';

const _kg1 = ValueKey('kg1');
const _reps1 = ValueKey('reps1');
const _kg2 = ValueKey('kg2');
const _reps2 = ValueKey('reps2');
const _body = ValueKey('body');
const _keypad = ValueKey('number-keypad');

/// Two sets of weight and reps, as the set tables lay them out.
Future<List<String>> _pump(
  WidgetTester tester, {
  ValueListenable<bool> showsFields = const AlwaysStoppedAnimation(true),
}) async {
  usePhoneViewport(tester);
  final committed = <String>[];
  Widget field(Key key, String text, {required bool decimal}) => Expanded(
    child: InlineNumberField(
      key: key,
      text: text,
      label: '$key',
      decimal: decimal,
      onCommit: committed.add,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      locale: testLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => NumberKeypadHost(child: child!),
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: showsFields,
          builder: (context, shows, _) => Container(
            key: _body,
            child: shows
                ? Column(
                    children: [
                      Row(
                        children: [
                          field(_kg1, '8.5', decimal: true),
                          field(_reps1, '10', decimal: false),
                        ],
                      ),
                      Row(
                        children: [
                          field(_kg2, '8', decimal: true),
                          field(_reps2, '10', decimal: false),
                        ],
                      ),
                    ],
                  )
                : null,
          ),
        ),
      ),
    ),
  );
  return committed;
}

TextField _textField(WidgetTester tester, Key field) =>
    tester.widget<TextField>(
      find.descendant(of: find.byKey(field), matching: find.byType(TextField)),
    );

String _text(WidgetTester tester, Key field) =>
    _textField(tester, field).controller!.text;

Future<void> _tapField(WidgetTester tester, Key field) async {
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(InkWell, label));
  await tester.pump();
}

void main() {
  testWidgets('a figure is selected on focus and typing replaces it', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(_keypad), findsNothing);

    await _tapField(tester, _kg1);
    expect(find.byKey(_keypad), findsOneWidget);
    expect(
      _textField(tester, _kg1).controller!.selection,
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    expect(_textField(tester, _kg1).keyboardType, TextInputType.none);

    await _press(tester, '7');
    expect(_text(tester, _kg1), '7');
    await _press(tester, '2');
    expect(_text(tester, _kg1), '72');
    expect(
      _textField(tester, _kg1).focusNode!.hasFocus,
      isTrue,
      reason: 'a press on the keypad is not a tap outside the field',
    );
  });

  testWidgets('backspace clears a selected figure, then one digit at a time', (
    tester,
  ) async {
    await _pump(tester);
    await _tapField(tester, _kg1);

    await tester.tap(find.widgetWithIcon(InkWell, Icons.backspace_outlined));
    await tester.pump();
    expect(_text(tester, _kg1), '');

    await _press(tester, '4');
    await _press(tester, '2');
    await tester.tap(find.widgetWithIcon(InkWell, Icons.backspace_outlined));
    await tester.pump();
    expect(_text(tester, _kg1), '4');
  });

  testWidgets('a decimal point comes once, and not where reps are typed', (
    tester,
  ) async {
    await _pump(tester);
    await _tapField(tester, _kg1);

    await _press(tester, '.');
    expect(_text(tester, _kg1), '0.', reason: 'not a bare point');
    await _press(tester, '5');
    await _press(tester, '.');
    expect(_text(tester, _kg1), '0.5');

    await _tapField(tester, _reps1);
    await _press(tester, '.');
    expect(_text(tester, _reps1), '10');
  });

  testWidgets('the step keys move the figure, never below nothing', (
    tester,
  ) async {
    await _pump(tester);
    await _tapField(tester, _kg1);

    await _press(tester, '+1');
    expect(_text(tester, _kg1), '9.5');
    await _press(tester, '-5');
    expect(_text(tester, _kg1), '4.5');
    await _press(tester, '-5');
    expect(_text(tester, _kg1), '0');
    await _press(tester, '+5');
    await _press(tester, '3');
    expect(
      _text(tester, _kg1),
      '3',
      reason: 'a step leaves the figure selected',
    );

    await _tapField(tester, _reps1);
    await _press(tester, '+5');
    expect(_text(tester, _reps1), '15');
  });

  testWidgets('next and previous walk the table row by row, then done', (
    tester,
  ) async {
    final committed = await _pump(tester);
    await _tapField(tester, _kg1);
    final previous = find.widgetWithText(InkWell, '上一項');
    expect(tester.widget<InkWell>(previous).onTap, isNull, reason: 'first');

    await _press(tester, '7');
    for (final field in [_reps1, _kg2, _reps2]) {
      await _press(tester, '下一項');
      await tester.pump();
      expect(_textField(tester, field).focusNode!.hasFocus, isTrue);
    }
    expect(committed, [
      '7',
    ], reason: 'what was typed is handed over on leaving');
    expect(find.widgetWithText(InkWell, '下一項'), findsNothing);

    await _press(tester, '上一項');
    await tester.pump();
    expect(_textField(tester, _kg2).focusNode!.hasFocus, isTrue);
    await _press(tester, '下一項');
    await _press(tester, '完成');
    await tester.pumpAndSettle();
    expect(find.byKey(_keypad), findsNothing);
  });

  testWidgets('the page makes room for the keypad as for a keyboard', (
    tester,
  ) async {
    await _pump(tester);
    expect(tester.getSize(find.byKey(_body)).height, phoneSize.height);

    await _tapField(tester, _kg1);
    final panel = tester.getRect(find.byKey(_keypad));
    expect(panel.bottom, phoneSize.height);
    expect(
      tester.getRect(find.byKey(_body)).bottom,
      panel.top,
      reason: 'the scaffold ends where the keypad begins',
    );
    expect(
      panel.height,
      greaterThanOrEqualTo(4 * 48 + phoneBottomInset),
      reason: 'four touch-sized rows and the home indicator',
    );

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(_keypad), findsNothing);
    expect(tester.getSize(find.byKey(_body)).height, phoneSize.height);
  });

  testWidgets('a focused figure that goes away takes the keypad with it', (
    tester,
  ) async {
    final showsFields = ValueNotifier(true);
    addTearDown(showsFields.dispose);
    await _pump(tester, showsFields: showsFields);
    await _tapField(tester, _kg1);
    expect(find.byKey(_keypad), findsOneWidget);

    showsFields.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(_keypad), findsNothing);
  });

  testWidgets('walking on keeps the figure above the page footer', (
    tester,
  ) async {
    usePhoneViewport(tester);
    const footerHeight = 120.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        locale: testLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, child) => NumberKeypadHost(child: child!),
        home: EdgeToEdgeScaffold(
          body: ListView(
            // The page's own padding: a list that took it from the media
            // would hide the footer from the figures in it.
            padding: const EdgeInsets.only(bottom: footerHeight),
            children: [
              for (var i = 0; i < 12; i++)
                InlineNumberField(
                  key: ValueKey('set$i'),
                  text: '$i',
                  label: 'set $i',
                  decimal: false,
                  onCommit: (_) {},
                ),
            ],
          ),
          footer: const SizedBox(height: footerHeight),
        ),
      ),
    );
    await _tapField(tester, const ValueKey('set0'));
    for (var i = 1; i < 12; i++) {
      await _press(tester, '下一項');
      await tester.pumpAndSettle();
    }

    final field = tester.getRect(find.byKey(const ValueKey('set11')));
    final footerTop = tester.getRect(find.byKey(_keypad)).top - footerHeight;
    expect(field.bottom, lessThanOrEqualTo(footerTop));
  });
}
