import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/domain.dart';
import '../../../shared/widgets/chrome/chrome_surface.dart';
import '../../../shared/widgets/content/elapsed_clock.dart';
import 'chrome_metrics.dart';
import '../../../shared/haptics.dart';
import '../../../l10n/l10n.dart';

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
    final isReady = session.isReady;
    final l10n = context.l10n;
    final name = session.name(l10n);
    return SizedBox(
      height: ChromeMetrics.accessoryHeight,
      child: ChromeSurface(
        tint: switch (session.category) {
          RecordCategory.activity => AppColors.activitySurface,
          RecordCategory.wellness => AppColors.wellnessSurface,
          _ => AppColors.trainingSurface,
        },
        borderColor: switch (session.category) {
          RecordCategory.activity => AppColors.activityOutline,
          RecordCategory.wellness => AppColors.wellnessOutline,
          _ => AppColors.trainingOutline,
        },
        child: Row(
          children: [
            // Scheduled, there is nothing to pause or to end yet: the bar
            // only leads back to the workout, where it is begun.
            // Nothing to pause in a bath; the space stays so the status
            // sits in the middle between the two ends.
            if (!isReady && !session.canPause)
              const SizedBox.square(dimension: ChromeMetrics.accessoryHeight),
            if (!isReady && session.canPause)
              _Yielding(
                morph: morph,
                child: _AccessoryIcon(
                  icon: isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  tooltip: isPaused
                      ? l10n.sessionResume(session: name)
                      : l10n.sessionPause(session: name),
                  onTap: onTogglePause,
                ),
              ),
            Expanded(
              child: Semantics(
                button: true,
                label: switch ((isReady, isPaused)) {
                  (true, _) => l10n.sessionScheduledOpen(session: name),
                  (_, true) => l10n.sessionPausedOpen(session: name),
                  _ => l10n.sessionRunningOpen(session: name),
                },
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
            if (!isReady)
              _Yielding(
                morph: morph,
                isTrailing: true,
                child: _AccessoryIcon(
                  icon: Icons.stop_rounded,
                  tooltip: l10n.sessionEnd(session: name),
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
      ActiveBath() => AppColors.wellness,
      ActiveWorkout() => AppColors.training,
    };
    final style = AppTextStyles.itemTitle.copyWith(
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        // What it is gives way as the bar narrows; the clock beside it is
        // what carries over into the capsule, so it never moves out.
        Flexible(
          child: AnimatedBuilder(
            animation: morph,
            builder: (context, _) {
              final gone = (morph.value.clamp(0.0, 1.0) / _labelGoesBy).clamp(
                0.0,
                1.0,
              );
              if (gone == 1) return const SizedBox.shrink();
              return ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: 1 - gone,
                  child: Opacity(
                    opacity: 1 - gone,
                    child: Text(
                      session.isReady
                          ? context.l10n.workoutScheduled
                          : '${session.isPaused ? context.l10n.sessionPausedStatus : context.l10n.sessionRunningStatus(session: session.name(context.l10n))} · ',
                      maxLines: 1,
                      softWrap: false,
                      style: style,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // No time runs while it is only scheduled.
        if (!session.isReady)
          ElapsedClock(
            session: session,
            builder: (_, elapsed) => Text(elapsed, style: style),
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
