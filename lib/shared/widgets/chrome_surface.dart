import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

const _blurSigma = 24.0;
const _glassOpacity = 0.72;
const _borderOpacity = 0.6;

/// Frosted surface the floating chrome (dock, toasts) is built from. With
/// "Increase Contrast" on it becomes opaque so labels stay legible.
class ChromeSurface extends StatelessWidget {
  const ChromeSurface({
    super.key,
    required this.child,
    this.tint = AppColors.surface,
    this.borderColor = AppColors.outline,
    this.radius = AppRadius.chip,
  });

  final Widget child;
  final Color tint;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isHighContrast = MediaQuery.highContrastOf(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
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
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: surface,
      ),
    );
  }
}
