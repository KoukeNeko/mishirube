import 'package:flutter/services.dart';

const _channel = MethodChannel('mishirube/app_info');

/// `1.0.0 (1)`: the version the platform installed (`AppInfo` in
/// `ios/Runner/AppDelegate.swift`, `MainActivity.kt` on Android). Null
/// where the platform does not say: a Mac, a test.
Future<String?> appVersion() async {
  try {
    final info = await _channel.invokeMapMethod<String, String>('version');
    return switch (info) {
      {'version': final version, 'build': final build}
          when version.isNotEmpty =>
        build.isEmpty ? version : '$version ($build)',
      _ => null,
    };
  } on MissingPluginException {
    return null;
  }
}
