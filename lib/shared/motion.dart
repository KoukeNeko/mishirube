import 'package:flutter/widgets.dart';

/// Whether the user asked for less motion. Android reports this as
/// `disableAnimations`; iOS reports Reduce Motion separately and never sets
/// `disableAnimations`, so both have to be checked.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

/// Honours the system "Reduce Motion" setting for chrome animations.
Duration chromeDuration(BuildContext context, Duration duration) =>
    prefersReducedMotion(context) ? Duration.zero : duration;

/// The Material 3 Expressive spring tokens (androidx `MotionTokens`), as
/// Flutter spring descriptions. Compose springs have unit mass, so the
/// damping ratio and stiffness carry over as they are. Run them on an
/// unbounded controller, which a bounded one would clamp, and only when
/// [prefersReducedMotion] is false.
abstract final class M3eSprings {
  /// Position, size and shape that settle fast, with a little overshoot:
  /// the corners of a held segment.
  static final spatialFast = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 800,
    ratio: 0.6,
  );
}
