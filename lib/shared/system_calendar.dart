import 'package:flutter/services.dart';

const _channel = MethodChannel('mishirube/system_calendar');

/// The weekday a week starts on in the device's settings, as
/// [DateTime.monday] … [DateTime.sunday] (`SystemCalendar` in
/// `ios/Runner/AppDelegate.swift`, `MainActivity.kt` on Android). Null
/// where the platform does not say: a Mac, a test.
Future<int?> systemFirstWeekday() async {
  try {
    // Foundation and java.util.Calendar both count Sunday as 1.
    return switch (await _channel.invokeMethod<int>('firstWeekday')) {
      final day? when day >= 1 && day <= 7 =>
        day == 1 ? DateTime.sunday : day - 1,
      _ => null,
    };
  } on MissingPluginException {
    return null;
  }
}
