import 'dart:ui' show DisplayFeature;

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

void usePhoneViewport(WidgetTester tester) => useWindow(tester, phone);

/// A window the app runs in: its size, the system's insets around it and
/// any fold or hinge across it.
class WindowCase {
  const WindowCase(
    this.name,
    this.size, {
    this.padding = const FakeViewPadding(),
    this.displayFeatures = const [],
  });

  final String name;
  final Size size;
  final FakeViewPadding padding;
  final List<DisplayFeature> displayFeatures;

  @override
  String toString() => name;
}

const phone = WindowCase(
  'phone',
  phoneSize,
  padding: FakeViewPadding(top: phoneTopInset, bottom: phoneBottomInset),
);

/// The same phone on its side: the notch moves to the leading edge and
/// the height is compact, so it keeps the dock.
const phoneLandscape = WindowCase(
  'phone landscape',
  Size(844, 390),
  padding: FakeViewPadding(
    left: phoneTopInset,
    right: phoneTopInset,
    bottom: 21,
  ),
);

/// A 10.5" tablet, one of Android's reference sizes for adaptive apps.
const tablet = WindowCase(
  'tablet',
  Size(1280, 800),
  padding: FakeViewPadding(top: 24, bottom: 20),
);

void useWindow(WidgetTester tester, WindowCase window) {
  tester.view
    ..physicalSize = window.size
    ..devicePixelRatio = 1
    ..padding = window.padding
    ..viewPadding = window.padding
    ..displayFeatures = window.displayFeatures;
  addTearDown(tester.view.reset);
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required AppStore store,
  WindowCase window = phone,
}) async {
  useWindow(tester, window);
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
