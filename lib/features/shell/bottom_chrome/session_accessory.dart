import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/domain.dart';
import '../../../shared/widgets/chrome/chrome_surface.dart';
import '../../../shared/widgets/content/elapsed_clock.dart';
import 'chrome_metrics.dart';
import '../../../shared/haptics.dart';

/// Persistent bar above the dock while a session runs, whichever kind it
/// is, so the other tabs stay reachable meanwhile.
class SessionAccessory extends StatelessWidget {
  const SessionAccessory({
    super.key,
    required this.session,
    required this.onTogglePause,
    required this.onOpen,
    required this.onFinish,
  });

  final ActiveSession session;
  final VoidCallback onTogglePause;
  final VoidCallback onOpen;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final isPaused = session.isPaused;
    final label = session.label;
    return SizedBox(
      height: ChromeMetrics.accessoryHeight,
      child: ChromeSurface(
        tint: switch (session.category) {
          RecordCategory.activity => AppColors.activitySurface,
          _ => AppColors.trainingSurface,
        },
        borderColor: switch (session.category) {
          RecordCategory.activity => AppColors.activityOutline,
          _ => AppColors.trainingOutline,
        },
        child: Row(
          children: [
            _AccessoryIcon(
              icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              tooltip: isPaused ? '繼續$label' : '暫停$label',
              onTap: onTogglePause,
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: isPaused ? '$label已暫停，回到$label' : '$label進行中，回到$label',
                // Excluding the child's semantics drops its tap too.
                onTap: onOpen,
                excludeSemantics: true,
                child: InkWell(
                  key: const ValueKey('session-accessory-open'),
                  onTap: () {
                    AppHaptics.tap();
                    onOpen();
                  },
                  customBorder: const StadiumBorder(),
                  child: SizedBox.expand(child: _Status(session: session)),
                ),
              ),
            ),
            _AccessoryIcon(
              icon: Icons.stop_rounded,
              tooltip: '結束$label',
              onTap: onFinish,
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final color = switch (session) {
      _ when session.isPaused => AppColors.warning,
      ActiveActivity() => AppColors.activity,
      ActiveWorkout() => AppColors.training,
    };
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
            session: session,
            builder: (_, elapsed) => Text(
              '${session.isPaused ? '已暫停' : '${session.label}進行中'} · $elapsed',
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
        onPressed: () {
          AppHaptics.tap();
          onTap();
        },
        color: AppColors.textPrimary,
        icon: Icon(icon),
      ),
    );
  }
}
