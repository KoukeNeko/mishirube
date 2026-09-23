import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/window_controls.dart';

void main() {
  const channel = MethodChannel('mishirube/window_controls');

  testWidgets(
    "a Mac's title bar is a top inset, gone in full screen",
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'topInset' ? 28.0 : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      late double top;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: WindowControlsScope(
            child: Builder(
              builder: (context) {
                top = MediaQuery.paddingOf(context).top;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(top, 28);

      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('topInsetChanged', 0.0),
        ),
        (_) {},
      );
      await tester.pump();
      expect(top, 0);
    },
    // Only a Mac host runs the Mac runner's side of this.
    skip: !Platform.isMacOS,
  );
}
