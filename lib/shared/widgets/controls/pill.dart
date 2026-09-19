import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../page/collapsing_header.dart';
import '../../haptics.dart';

const _pillLabelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
const _pillVerticalPadding = AppSpacing.xs;

/// Height of a [Pill] with a one-line label: the toolbar action size, grown
/// only when large text needs it.
double pillHeight(BuildContext context) {
  final label = measureTextHeight(
    context,
    '時間軸',
    _pillLabelStyle,
    maxWidth: double.infinity,
  );
  return math.max(
    ToolbarMetrics.of(context).actionVisualSize,
    label + _pillVerticalPadding * 2,
  );
}

/// The shared pill surface behind header actions, chips and segmented
/// controls, so they share one height, shape, fill and label style. Callers
/// add their own semantics and touch target.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.child,
    required this.onTap,
    this.color = AppColors.surfaceRaised,
    this.foregroundColor = AppColors.textPrimary,
    this.horizontalPadding = AppSpacing.md,
    this.isSelection = false,
    this.outlineColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color foregroundColor;
  final double horizontalPadding;

  /// Draws a rim in this colour, e.g. to mark a selected chip without
  /// filling it.
  final Color? outlineColor;

  /// Picks an option (chip, segment) rather than acting: ticks like a
  /// selection instead of tapping like a button.
  final bool isSelection;

  @override
  Widget build(BuildContext context) {
    final size = ToolbarMetrics.of(context).actionVisualSize;
    return Material(
      color: color,
      shape: StadiumBorder(
        side: outlineColor == null
            ? BorderSide.none
            : BorderSide(color: outlineColor!, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                isSelection ? AppHaptics.selection(context) : AppHaptics.tap();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: size, minHeight: size),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: _pillVerticalPadding,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: IconTheme.merge(
                data: IconThemeData(size: 18, color: foregroundColor),
                child: DefaultTextStyle.merge(
                  style: _pillLabelStyle.copyWith(color: foregroundColor),
                  textAlign: TextAlign.center,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
