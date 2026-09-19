import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'chrome_metrics.dart';

const _glassOpacity = 0.72;
const _borderOpacity = 0.6;

/// Frosted capsule the floating chrome is built from. With "Increase
/// Contrast" on it becomes an opaque surface so labels stay legible.
class ChromeSurface extends StatelessWidget {
  const ChromeSurface({
    super.key,
    required this.child,
    this.tint = AppColors.surface,
    this.borderColor = AppColors.outline,
  });

  final Widget child;
  final Color tint;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final isHighContrast = MediaQuery.highContrastOf(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      side: BorderSide(color: borderColor.withValues(alpha: _borderOpacity)),
    );
    final surface = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        color: isHighContrast ? tint : tint.withValues(alpha: _glassOpacity),
      ),
      // Ink from buttons inside paints here, so the clip below contains it.
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (isHighContrast) return surface;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ChromeMetrics.blurSigma,
          sigmaY: ChromeMetrics.blurSigma,
        ),
        child: surface,
      ),
    );
  }
}
