import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/theme.dart';
import 'package:mishirube/shared/toast/toast_host.dart';

/// iPhone-class logical size used by the design mock.
const phoneSize = Size(390, 844);

/// Dynamic Island status bar and home indicator insets of an iPhone 17.
const phoneTopInset = 59.0;
const phoneBottomInset = 34.0;

/// Clock that tests can move forward explicitly.
class FakeClock {
  DateTime current = DateTime(2026, 9, 19, 19, 43);

  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}

void usePhoneViewport(WidgetTester tester) {
  const insets = FakeViewPadding(top: phoneTopInset, bottom: phoneBottomInset);
  tester.view
    ..physicalSize = phoneSize
    ..devicePixelRatio = 1
    ..padding = insets
    ..viewPadding = insets;
  addTearDown(tester.view.reset);
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required AppStore store,
}) async {
  usePhoneViewport(tester);
  await tester.pumpWidget(
    AppStoreScope(
      store: store,
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (_, child) => ToastHost(child: child!),
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

/// Replaces the tree so periodic timers (clocks, rest timer) are disposed.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}
