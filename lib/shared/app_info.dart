import 'package:flutter/services.dart';

const _channel = MethodChannel('mishirube/app_info');

/// `1.0.0 (1)`: the version the platform installed (`AppInfo` in
/// `ios/Runner/AppDelegate.swift`, `MainActivity.kt` on Android). Null
/// where the platform does not say: a Mac, a test.
Future<String?> appVersion() async {
  final info = await installedAppInfo();
  if (info == null) return null;
  return info.build.isEmpty ? info.version : '${info.version} (${info.build})';
}

/// The installed metadata used by the privacy page and local diagnostics.
Future<({String version, String build})?> installedAppInfo() async {
  try {
    final info = await _channel.invokeMapMethod<String, String>('version');
    return switch (info) {
      {'version': final version, 'build': final build}
          when version.isNotEmpty =>
        (version: version, build: build),
      _ => null,
    };
  } on MissingPluginException {
    return null;
  }
}
