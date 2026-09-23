import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's haptic vocabulary. Buttons call these instead of
/// `HapticFeedback` directly, so every control of a kind feels the same.
abstract final class AppHaptics {
  /// A button press: a light tap. Back controls stay silent, like the
  /// system's.
  static void tap() => HapticFeedback.lightImpact();

  /// A photo taken: firmer than a tap, like a camera's shutter.
  static void shutter() => HapticFeedback.mediumImpact();

  /// A timer ran out: the strongest of the set, felt through a pocket.
  static void alert() => HapticFeedback.heavyImpact();

  /// The chosen option changed (tabs, chips, segments). iOS ticks; Android
  /// selection controls stay silent, as Material's do.
  static void selection(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      HapticFeedback.selectionClick();
    }
  }
}
