import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/chrome/chrome_surface.dart';
import '../../../shared/widgets/content/elapsed_clock.dart';
import 'chrome_metrics.dart';

/// Persistent bar above the dock while a workout runs, so the other tabs
/// stay reachable mid-session.
class WorkoutAccessory extends StatelessWidget {
  const WorkoutAccessory({
    super.key,
    required this.workout,
    required this.onTogglePause,
    required this.onOpen,
    required this.onFinish,
  });

  final WorkoutSession workout;
  final VoidCallback onTogglePause;
  final VoidCallback onOpen;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final isPaused = workout.isPaused;
    return SizedBox(
      height: ChromeMetrics.accessoryHeight,
      child: ChromeSurface(
        tint: AppColors.trainingSurface,
        borderColor: AppColors.trainingOutline,
        child: Row(
          children: [
            _AccessoryIcon(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              tooltip: isPaused ? '繼續訓練' : '暫停訓練',
              onTap: onTogglePause,
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: isPaused ? '訓練已暫停，回到訓練' : '訓練進行中，回到訓練',
                excludeSemantics: true,
                child: InkWell(
                  key: const ValueKey('workout-accessory-open'),
                  onTap: onOpen,
                  customBorder: const StadiumBorder(),
                  child: SizedBox.expand(child: _Status(workout: workout)),
                ),
              ),
            ),
            _AccessoryIcon(
              icon: Icons.stop_rounded,
              tooltip: '結束訓練',
              onTap: onFinish,
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) {
    final color = workout.isPaused ? AppColors.warning : AppColors.training;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: ElapsedClock(
            workout: workout,
            builder: (_, elapsed) => Text(
              '${workout.isPaused ? '已暫停' : '訓練進行中'} · $elapsed',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.itemTitle.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessoryIcon extends StatelessWidget {
  const _AccessoryIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: ChromeMetrics.accessoryHeight,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        color: AppColors.textPrimary,
        icon: Icon(icon),
      ),
    );
  }
}
