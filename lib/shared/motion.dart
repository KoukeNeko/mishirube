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
