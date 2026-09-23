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
}
