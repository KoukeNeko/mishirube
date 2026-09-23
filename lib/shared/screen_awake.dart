import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _channel = MethodChannel('mishirube/screen_awake');

/// Keeps the screen from dimming and locking while [child] is on screen
/// (`ScreenAwake` in `ios/Runner/AppDelegate.swift`, `MainActivity.kt`
/// on Android). Where the platform has no such switch it does nothing.
class ScreenAwake extends StatefulWidget {
  const ScreenAwake({super.key, required this.child});

  final Widget child;

  @override
  State<ScreenAwake> createState() => _ScreenAwakeState();
}

class _ScreenAwakeState extends State<ScreenAwake> {
  @override
  void initState() {
    super.initState();
    _keepOn(true);
  }

  @override
  void dispose() {
    _keepOn(false);
    super.dispose();
  }

  static Future<void> _keepOn(bool isOn) async {
    try {
      await _channel.invokeMethod<void>('keepOn', isOn);
    } on MissingPluginException {
      // A Mac, or a test: nothing to keep on.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
