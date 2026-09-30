import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Shows a panel that rises from the foot of the screen, for a choice that
/// takes more than a dialog holds: a few controls and what they make. The
/// [builder] lays out the panel; it decides its own height and, for what
/// is taller than the room, its own scrolling.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: builder,
  );
}
