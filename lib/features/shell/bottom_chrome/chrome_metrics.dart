import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    required this.bottomOffsetFor,
  });

  /// Proportions of the iOS 26/27 Liquid Glass tab bar (62pt glass that
  /// dips ~13pt into the home-indicator area instead of sitting above it).
  static final ios = DockMetrics._(
    height: 62,
    minimizedHeight: 48,
    horizontalInset: 21,
    minimizedHorizontalInset: 28,
    iconSize: 20,
    iconBox: 28,
    labelSize: 11,
    labelHeight: 13,
    labelGap: 1,
    bottomOffsetFor: ({required safeBottom, required isMinimized}) =>
        math.max(8, safeBottom - (isMinimized ? 6 : 13)),
  );

  /// Material 3 navigation bar proportions, kept clear of the gesture area.
  static final android = DockMetrics._(
    height: 64,
    minimizedHeight: 52,
    horizontalInset: 16,
    minimizedHorizontalInset: 24,
    iconSize: 24,
    iconBox: 30,
    labelSize: 12,
    labelHeight: 15,
    labelGap: 2,
    bottomOffsetFor: ({required safeBottom, required isMinimized}) =>
        safeBottom + 8,
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
  final double Function({required double safeBottom, required bool isMinimized})
  bottomOffsetFor;

  double heightFor({required bool isMinimized}) =>
      isMinimized ? minimizedHeight : height;

  double insetFor({required bool isMinimized}) =>
      isMinimized ? minimizedHorizontalInset : horizontalInset;

  /// Distance from the screen's bottom edge to the dock's bottom edge.
  /// Reads `viewPadding`, the physical inset, which SafeArea never consumes.
  double bottomOffset(BuildContext context, {required bool isMinimized}) =>
      bottomOffsetFor(
        safeBottom: MediaQuery.viewPaddingOf(context).bottom,
        isMinimized: isMinimized,
      );
}
