import 'package:flutter/material.dart';

import '../../../shared/widgets/chrome/chrome_surface.dart';

export '../../../shared/motion.dart';

/// Motion and material values shared by every platform.
abstract final class ChromeMetrics {
  static const gap = 8.0;
  static const minTapTarget = 44.0;
  static const accessoryHeight = 54.0;
  static const timerCapsuleWidth = 136.0;

  static const morphDuration = Duration(milliseconds: 320);
  static const morphCurve = Curves.easeOutBack;
  static const fadeCurve = Curves.easeOut;

  /// Press feedback: a quick squeeze on touch, a spring back on release.
  /// Tabs squeeze less than the primary action in the centre.
  static const tabPressedScale = 0.96;
  static const actionPressedScale = 0.94;
  static const pressDuration = Duration(milliseconds: 70);

  /// Slightly underdamped: alive, but never visibly overshoots.
  static const pressSpring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 32,
  );

  /// Selection lens: a faint patch of the same glass, not a second layer.
  static const lensInset = 4.0;
  static const lensFillOpacity = 0.07;
  static const lensPressedFillOpacity = 0.12;
  static const lensBorderOpacity = 0.1;
  static const lensFadeDuration = Duration(milliseconds: 150);

  /// Where the lens settles after a tap or a drag: a hint of overshoot,
  /// the same model as SwiftUI's `spring(duration:bounce:)`.
  static final lensSnapSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 280),
    bounce: 0.12,
  );

  /// Dragging across a capsule's tabs, like the iOS 26 tab bar: sliding
  /// sideways starts it at once; resting a finger this long first also
  /// does. Apple publishes no values; these are the design's own.
  static const scrubHoldDuration = Duration(milliseconds: 200);
  static const scrubLensScale = 1.04;

  /// Dead band around a tab boundary, so a finger resting on it does not
  /// flip the preview (and buzz) back and forth.
  static const scrubHysteresis = 6.0;
}

/// Platform geometry of the floating dock. The quick-log menu reads the
/// same values so its close button lands exactly on top of「+」.
class DockMetrics {
  const DockMetrics._({
    required this.height,
    required this.minimizedHeight,
    required this.horizontalInset,
    required this.minimizedHorizontalInset,
    required this.iconSize,
    required this.iconBox,
    required this.labelSize,
    required this.labelHeight,
    required this.labelGap,
  });

  /// Proportions of the iOS 26/27 Liquid Glass tab bar (62pt glass that
  /// dips ~13pt into the home-indicator area instead of sitting above it).
  static const ios = DockMetrics._(
    height: 62,
    minimizedHeight: 48,
    horizontalInset: 21,
    minimizedHorizontalInset: 28,
    iconSize: 20,
    iconBox: 28,
    labelSize: 11,
    labelHeight: 13,
    labelGap: 1,
  );

  /// Material 3 navigation bar proportions, kept clear of the gesture area.
  static const android = DockMetrics._(
    height: 64,
    minimizedHeight: 52,
    horizontalInset: 16,
    minimizedHorizontalInset: 24,
    iconSize: 24,
    iconBox: 30,
    labelSize: 12,
    labelHeight: 15,
    labelGap: 2,
  );

  static DockMetrics of(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? ios
        : android;
  }

  final double height;
  final double minimizedHeight;
  final double horizontalInset;
  final double minimizedHorizontalInset;
  final double iconSize;
  final double iconBox;
  final double labelSize;
  final double labelHeight;
  final double labelGap;

  /// Glyph of the centre action; the quick-log menu's × uses it too, so
  /// the two match when one replaces the other.
  double get actionIconSize => iconSize + 8;

  double heightFor({required bool isMinimized}) =>
      isMinimized ? minimizedHeight : height;

  double insetFor({required bool isMinimized}) =>
      isMinimized ? minimizedHorizontalInset : horizontalInset;

  /// Distance from the screen's bottom edge to the dock's bottom edge.
  double bottomOffset(BuildContext context, {required bool isMinimized}) =>
      floatingChromeBottomOffset(context, isCompact: isMinimized);
}
