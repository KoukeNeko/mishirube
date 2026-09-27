import 'package:flutter/services.dart';

import '../backend/backend.dart';
import '../shared/format.dart';
import '../l10n/l10n.dart';

const _channel = MethodChannel('mishirube/bedtime');

/// Tells the system when to remind of bedtime each day, or that it should
/// not (`BedtimeReminder` in `ios/Runner/AppDelegate.swift`,
/// `BedtimeReminder.kt` on Android). The time follows the goal and the
/// usual waking, so it is set again when either may have moved: on
/// launch, and when the sleep page changes the goal or the switch.
Future<void> syncBedtimeReminder(Backend backend, AppLocalizations l10n) async {
  final at = backend.sleep.reminderTime();
  final plan = backend.sleep.tonightPlan();
  try {
    if (at == null || plan == null) {
      await _channel.invokeMethod<void>('cancel');
    } else {
      await _channel.invokeMethod<void>('schedule', {
        'hour': at.hour,
        'minute': at.minute,
        'title': l10n.bedtimeReminderTitle,
        'body': l10n.bedtimeReminderBody(
          bedtime: formatTimeOfDay(plan.bedtime),
          wake: formatTimeOfDay(plan.wake),
        ),
      });
    }
  } on MissingPluginException {
    // A Mac, or a test: no reminder to set.
  }
}
