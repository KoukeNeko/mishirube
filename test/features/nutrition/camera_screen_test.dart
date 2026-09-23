import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/nutrition/camera_screen.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('without a camera the library still gives a photo', (
    tester,
  ) async {
    String? popped;
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => CameraScreen(
                    title: '食物',
                    pickFromLibrary: () async => '/lunch.jpg',
                    findCameras: () async => const [],
                    findLatestPhoto: (_) async => null,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
      store: store,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tests have no camera behind the plugin, as a Mac has none.
    expect(find.text('沒有可用的相機'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('拍照')),
      matchesSemantics(isButton: true, hasEnabledState: true, label: '拍照'),
      reason: 'the shutter is off with nothing to take a photo with',
    );

    await tester.tap(find.byTooltip('從相簿選取'));
    await tester.pumpAndSettle();
    expect(popped, '/lunch.jpg');
    await disposeTree(tester);
  });

  testWidgets('the library button shows the newest photo when it can', (
    tester,
  ) async {
    // A 1×1 PNG.
    final photo = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwAD'
      'hgGAWjR9awAAAABJRU5ErkJggg==',
    );
    int? asked;
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    await pumpScreen(
      tester,
      CameraScreen(
        title: '食物',
        pickFromLibrary: () async => null,
        findCameras: () async => const [],
        findLatestPhoto: (pixels) async {
          asked = pixels;
          return photo;
        },
      ),
      store: store,
    );
    await tester.pumpAndSettle();

    expect(asked, greaterThan(0), reason: 'asked at the screen\'s density');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).image?.image is MemoryImage,
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('從相簿選取'), findsOneWidget);
    await disposeTree(tester);
  });
}
