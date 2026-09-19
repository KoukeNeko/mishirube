import 'package:flutter/material.dart';

import '../../../app/app_store.dart';
import '../../../app/theme.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/chrome_surface.dart';
import '../../../shared/widgets/elapsed_clock.dart';
import 'chrome_metrics.dart';

/// Width of a tab's icon area; its height comes from [DockMetrics.iconBox].
const _indicatorWidth = 56.0;

class _TabSpec {
  const _TabSpec(this.tab, this.icon, this.selectedIcon, this.label);

  final HomeTab tab;
  final IconData icon;

  /// Filled variant, so selection is not signalled by colour alone.
  final IconData selectedIcon;
  final String label;
}

const _leadingTabs = [
  _TabSpec(HomeTab.today, Icons.my_location_outlined, Icons.my_location, '今天'),
  _TabSpec(HomeTab.log, Icons.list_alt_outlined, Icons.list_alt, '紀錄'),
];
const _trailingTabs = [
  _TabSpec(HomeTab.trends, Icons.insights_outlined, Icons.insights, '趨勢'),
  _TabSpec(HomeTab.me, Icons.person_outline, Icons.person, '我的'),
];

/// Two navigation capsules around a separate action button: tabs mean
/// "where am I", the centre means "record something" (or, minimised during
/// a workout, "go back to it").
class SplitDock extends StatelessWidget {
  const SplitDock({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isMinimized,
    required this.workout,
    required this.onQuickLog,
    required this.onOpenWorkout,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final bool isMinimized;
  final WorkoutSession? workout;
  final VoidCallback onQuickLog;
  final VoidCallback onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    final duration = chromeDuration(context, ChromeMetrics.morphDuration);
    final metrics = DockMetrics.of(context);
    final height = metrics.heightFor(isMinimized: isMinimized);
    final showTimer = isMinimized && workout != null;
    return AnimatedContainer(
      duration: duration,
      curve: ChromeMetrics.morphCurve,
      height: height,
      child: Row(
        children: [
          Expanded(child: _capsule(_leadingTabs, metrics)),
          const SizedBox(width: ChromeMetrics.gap),
          _CenterAction(
            size: height,
            metrics: metrics,
            workout: showTimer ? workout : null,
            onQuickLog: onQuickLog,
            onOpenWorkout: onOpenWorkout,
          ),
          const SizedBox(width: ChromeMetrics.gap),
          Expanded(child: _capsule(_trailingTabs, metrics)),
        ],
      ),
    );
  }

  Widget _capsule(List<_TabSpec> tabs, DockMetrics metrics) {
    return ChromeSurface(
      child: Row(
        children: [
          for (final spec in tabs)
            Expanded(
              child: _TabButton(
                spec: spec,
                metrics: metrics,
                isSelected: spec.tab == selected,
                showLabel: !isMinimized,
                onTap: () => onSelect(spec.tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.metrics,
    required this.isSelected,
    required this.showLabel,
    required this.onTap,
  });

  final _TabSpec spec;
  final DockMetrics metrics;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.training : AppColors.textSecondary;
    final indicatorSize = Size(_indicatorWidth, metrics.iconBox);
    return Semantics(
      label: spec.label,
      selected: isSelected,
      button: true,
      excludeSemantics: true,
      // The whole cell is tappable. No ink: the selected state is the
      // feedback, as with system tab bars.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ChromeMetrics.minTapTarget,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.fromSize(
                  size: indicatorSize,
                  child: Icon(
                    isSelected ? spec.selectedIcon : spec.icon,
                    color: color,
                    size: metrics.iconSize,
                  ),
                ),
                if (showLabel) ...[
                  SizedBox(height: metrics.labelGap),
                  SizedBox(
                    height: metrics.labelHeight,
                    child: Text(
                      spec.label,
                      style: TextStyle(
                        color: color,
                        fontSize: metrics.labelSize,
                        height: metrics.labelHeight / metrics.labelSize,
                        // Semibold like system tab labels; bolder when
                        // selected so colour is not the only cue.
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「+」as tall as the capsules (a separate action, not a raised FAB) that
/// morphs into a timer capsule when a workout is minimised.
class _CenterAction extends StatelessWidget {
  const _CenterAction({
    required this.size,
    required this.metrics,
    required this.workout,
    required this.onQuickLog,
    required this.onOpenWorkout,
  });

  final double size;
  final DockMetrics metrics;

  /// Non-null only when the centre should show the running workout timer.
  final WorkoutSession? workout;
  final VoidCallback onQuickLog;
  final VoidCallback onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    final duration = chromeDuration(context, ChromeMetrics.morphDuration);
    final session = workout;
    return Semantics(
      button: true,
      label: session == null ? '新增紀錄' : '訓練進行中，回到訓練',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duration,
        curve: ChromeMetrics.morphCurve,
        width: session == null ? size : ChromeMetrics.timerCapsuleWidth,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.training,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          boxShadow: [
            BoxShadow(
              color: AppColors.training.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: GestureDetector(
          key: const ValueKey('dock-center-action'),
          behavior: HitTestBehavior.opaque,
          onTap: session == null ? onQuickLog : onOpenWorkout,
          child: AnimatedSwitcher(
            duration: duration,
            child: session == null
                ? Icon(
                    Icons.add,
                    key: const ValueKey('plus'),
                    size: metrics.iconSize + 8,
                    color: AppColors.onTraining,
                  )
                : _TimerLabel(key: const ValueKey('timer'), workout: session),
          ),
        ),
      ),
    );
  }
}

class _TimerLabel extends StatelessWidget {
  const _TimerLabel({super.key, required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              workout.isPaused ? Icons.pause : Icons.circle,
              size: workout.isPaused ? 16 : 10,
              color: AppColors.onTraining,
            ),
            const SizedBox(width: AppSpacing.xs),
            ElapsedClock(
              workout: workout,
              builder: (_, elapsed) => Text(
                elapsed,
                style: AppTextStyles.buttonLabel.copyWith(
                  color: AppColors.onTraining,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
