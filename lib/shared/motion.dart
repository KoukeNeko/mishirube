import 'package:flutter/widgets.dart';

/// Honours the system "Reduce Motion" setting for chrome animations.
Duration chromeDuration(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
