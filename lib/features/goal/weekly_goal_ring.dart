import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

const _trackWidth = 10.0;

/// How far this week has got, as a ring. Takes plain numbers: the same
/// ring is the page's hero and, small, the entry in the toolbar.
class WeeklyGoalRing extends StatelessWidget {
  const WeeklyGoalRing({
    super.key,
    required this.value,
    required this.target,
    this.size = 148,
    this.strokeWidth = _trackWidth,
    this.isPaused = false,
    this.child,
  });

  final int value;
  final int target;
  final double size;
  final double strokeWidth;
  final bool isPaused;

  /// What sits inside the ring; the page puts the numbers there.
  final Widget? child;

  @override
  Widget build(BuildContext context) => ProgressRing(
    progress: isPaused || target <= 0 ? 0 : value / target,
    color: isPaused ? AppColors.textTertiary : AppColors.training,
    semanticLabel: isPaused
        ? context.l10n.thisWeekPaused
        : context.l10n.thisWeekActiveDays(active: value, target: target),
    size: size,
    strokeWidth: strokeWidth,
    child: child,
  );
}
