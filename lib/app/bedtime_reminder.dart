import 'package:flutter/services.dart';

import '../backend/backend.dart';
import '../shared/format.dart';

const _channel = MethodChannel('mishirube/bedtime');

/// Tells the system when to remind of bedtime each day, or that it should
/// not (`BedtimeReminder` in `ios/Runner/AppDelegate.swift`,
/// `BedtimeReminder.kt` on Android). The time follows the goal and the
/// usual waking, so it is set again when either may have moved: on
/// launch, and when the sleep page changes the goal or the switch.
Future<void> syncBedtimeReminder(Backend backend) async {
  final at = backend.sleep.reminderTime();
  final plan = backend.sleep.tonightPlan();
  try {
    if (at == null || plan == null) {
      await _channel.invokeMethod<void>('cancel');
    } else {
      await _channel.invokeMethod<void>('schedule', {
        'hour': at.hour,
        'minute': at.minute,
        'title': '準備就寢',
        'body':
            '${formatTimeOfDay(plan.bedtime)} 就寢，'
            '${formatTimeOfDay(plan.wake)} 起床',
      });
    }
  } on MissingPluginException {
    // A Mac, or a test: no reminder to set.
  }
}
