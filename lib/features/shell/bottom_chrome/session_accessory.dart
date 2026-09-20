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
    required this.morph,
    required this.session,
    required this.onTogglePause,
    required this.onOpen,
    required this.onFinish,
  });

  /// 0 while the chrome is expanded, 1 once it is minimised. The side
  /// controls give way first; the clock is the one thing both this and
  /// the capsule it collapses into show, so it stays to the end.
  final Animation<double> morph;

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
            _Yielding(
              morph: morph,
              child: _AccessoryIcon(
                icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                tooltip: isPaused ? '繼續$label' : '暫停$label',
                onTap: onTogglePause,
              ),
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
                  child: SizedBox.expand(
                    child: _Status(session: session, morph: morph),
                  ),
                ),
              ),
            ),
            _Yielding(
              morph: morph,
              isTrailing: true,
              child: _AccessoryIcon(
                icon: Icons.stop_rounded,
                tooltip: '結束$label',
                onTap: onFinish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.session, required this.morph});

  final ActiveSession session;
  final Animation<double> morph;

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
              // What it is drops away as the bar narrows; the clock is
              // what carries over into the capsule.
              '${_says(morph) ? '${session.isPaused ? '已暫停' : '${session.label}進行中'} · ' : ''}$elapsed',
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

/// A control that gives way as the bar narrows: it slides towards the
/// middle and fades, well before the bar itself goes.
class _Yielding extends StatelessWidget {
  const _Yielding({
    required this.morph,
    required this.child,
    this.isTrailing = false,
  });

  final Animation<double> morph;
  final Widget child;
  final bool isTrailing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: morph,
      child: child,
      builder: (context, child) {
        final t = (morph.value.clamp(0.0, 1.0) / _yieldBy).clamp(0.0, 1.0);
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(
            offset: Offset((isTrailing ? -1 : 1) * t * _yieldShift, 0),
            child: IgnorePointer(ignoring: t > 0.5, child: child),
          ),
        );
      },
    );
  }
}

/// The side controls are gone by the time the bar is a quarter of the
/// way in, and the label soon after.
const _yieldBy = 0.25;
const _yieldShift = 10.0;
const _labelGoesBy = 0.35;

bool _says(Animation<double> morph) => morph.value < _labelGoesBy;

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
