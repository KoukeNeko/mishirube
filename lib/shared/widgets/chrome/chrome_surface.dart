import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui show Gradient;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../app/theme.dart';

const _blurSigma = 24.0;
const _glassOpacity = 0.72;
const _borderOpacity = 0.6;

// The frosted rim, lit like the liquid glass: its shader catches light on
// the edge facing the light (up-left) and, at 80%, on the opposite edge, so
// the rim glints at both ends of the light axis and keeps the plain outline
// across it.
const _rimWidth = 1.0;
const _rimHighlight = 0.2;
const _rimOppositeHighlight = _rimHighlight * 0.8;

/// Liquid glass for the dock, tuned for a dark UI and away from the
/// package's default chrome-like rim: exact-colour tint, a soft specular
/// and Fresnel, and the darker edge iOS 27 uses for separation. Apple
/// publishes no values; these are set by eye.
LiquidGlassSettings _dockGlass(Color glassColor) => LiquidGlassSettings(
  // Clear mode composites the tint exactly (adaptive shifted a green「+」
  // towards olive) while keeping the rim and highlight.
  bodyMode: GlassBodyMode.clear,
  glassColor: glassColor,
  thickness: 20,
  blur: 8,
  lightIntensity: 0.25,
  fresnelStrength: 0.35,
  saturation: 1.1,
  chromaticAberration: 0.004,
  edgeAbsorption: 0.12,
);

/// Tint over liquid glass: light, so the refraction shows.
const _liquidTintOpacity = 0.35;

/// Frosted surface the floating chrome (dock, toasts) is built from. With
/// "Increase Contrast" on it becomes opaque so labels stay legible.
class ChromeSurface extends StatelessWidget {
  const ChromeSurface({
    super.key,
    required this.child,
    this.tint = AppColors.surface,
    this.borderColor = AppColors.outline,
    this.radius = AppRadius.chip,
    this.refracts = false,
    this.tintOpacity,
  });

  final Widget child;
  final Color tint;
  final Color borderColor;
  final double radius;

  /// Liquid glass instead of frost, where the device supports it: the dock
  /// (capsules and「+」) and the app bar's action pills.
  /// Smaller, scrolling or animated surfaces rendered it blocky, metallic
  /// or misplaced, so they stay frosted.
  final bool refracts;

  /// How much [tint] covers the surface; null uses the default for frost or
  /// glass. A solid-coloured control (the green「+」) sets it high.
  final double? tintOpacity;

  @override
  Widget build(BuildContext context) {
    final isHighContrast = MediaQuery.highContrastOf(context);
    // Ink from buttons inside paints here, so the clip around it contains it.
    final content = Material(type: MaterialType.transparency, child: child);
    if (isHighContrast) {
      return DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: borderColor.withValues(alpha: _borderOpacity),
            ),
          ),
          color: tint,
        ),
        child: content,
      );
    }
    if (refracts && ImageFilter.isShaderFilterSupported) {
      return LayoutBuilder(
        builder: (context, constraints) => GlassContainer(
          useOwnLayer: true,
          quality: GlassQuality.premium,
          // The shader needs a real corner radius, not the 999 pill value.
          shape: LiquidRoundedRectangle(
            borderRadius: constraints.maxHeight.isFinite
                ? math.min(radius, constraints.maxHeight / 2)
                : radius,
          ),
          clipBehavior: Clip.antiAlias,
          settings: _dockGlass(
            tint.withValues(alpha: tintOpacity ?? _liquidTintOpacity),
          ),
          child: content,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: CustomPaint(
          foregroundPainter: _FrostedRim(
            radius: radius,
            side: borderColor.withValues(alpha: _borderOpacity),
          ),
          child: ColoredBox(
            color: tint.withValues(alpha: tintOpacity ?? _glassOpacity),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _FrostedRim extends CustomPainter {
  const _FrostedRim({required this.radius, required this.side});

  final double radius;
  final Color side;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Lit from the same angle as the liquid glass (up-left; the package
    // measures it with y pointing up), in pixel space so a wide capsule
    // is not lit side-on.
    const angle = GlassDefaults.lightAngle;
    final toLight = Offset(math.cos(angle), -math.sin(angle));
    final reach =
        (size.width * toLight.dx.abs() + size.height * toLight.dy.abs()) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _rimWidth
      ..shader = ui.Gradient.linear(
        rect.center + toLight * reach,
        rect.center - toLight * reach,
        [
          Colors.white.withValues(alpha: _rimHighlight),
          side,
          side,
          Colors.white.withValues(alpha: _rimOppositeHighlight),
        ],
        const [0, 0.35, 0.65, 1],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(_rimWidth / 2),
        Radius.circular(math.min(radius, size.shortestSide / 2)),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FrostedRim oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.side != side;
}

/// Distance from the screen's bottom edge to floating bottom chrome (dock,
/// floating footers). On iOS it dips ~13pt into the home-indicator area like
/// Liquid Glass bars (6pt when compact); on Android it clears the gesture
/// area. Reads `viewPadding`, the physical inset SafeArea never consumes.
double floatingChromeBottomOffset(
  BuildContext context, {
  bool isCompact = false,
}) {
  final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return math.max(8, safeBottom - (isCompact ? 6 : 13));
  }
  return safeBottom + 8;
}
