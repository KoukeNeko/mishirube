import 'package:flutter/material.dart';

import '../../../app/app_store.dart';
import '../../../data/models.dart';
import 'chrome_metrics.dart';
import 'split_dock.dart';
import 'workout_accessory.dart';

/// Floating bottom chrome: the workout accessory (when a workout runs and
/// the chrome is expanded) stacked above the split dock.
class AppBottomChrome extends StatelessWidget {
  const AppBottomChrome({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isMinimized,
    required this.workout,
    required this.onQuickLog,
    required this.onOpenWorkout,
    required this.onTogglePause,
    required this.onFinishWorkout,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final bool isMinimized;
  final WorkoutSession? workout;
  final VoidCallback onQuickLog;
  final VoidCallback onOpenWorkout;
  final VoidCallback onTogglePause;
  final VoidCallback onFinishWorkout;

  @override
  Widget build(BuildContext context) {
    final duration = chromeDuration(context, ChromeMetrics.morphDuration);
    final session = workout;
    final showAccessory = session != null && !isMinimized;
    final metrics = DockMetrics.of(context);
    // No SafeArea: like the native Liquid Glass tab bar, the dock dips into
    // the home-indicator area instead of stacking on top of it.
    return AnimatedPadding(
      duration: duration,
      curve: ChromeMetrics.fadeCurve,
      padding: EdgeInsets.fromLTRB(
        metrics.insetFor(isMinimized: isMinimized),
        0,
        metrics.insetFor(isMinimized: isMinimized),
        metrics.bottomOffset(context, isMinimized: isMinimized),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: duration,
            curve: ChromeMetrics.fadeCurve,
            alignment: Alignment.bottomCenter,
            child: showAccessory
                ? Padding(
                    padding: const EdgeInsets.only(bottom: ChromeMetrics.gap),
                    child: WorkoutAccessory(
                      workout: session,
                      onTogglePause: onTogglePause,
                      onOpen: onOpenWorkout,
                      onFinish: onFinishWorkout,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          SplitDock(
            selected: selected,
            onSelect: onSelect,
            isMinimized: isMinimized,
            workout: workout,
            onQuickLog: onQuickLog,
            onOpenWorkout: onOpenWorkout,
          ),
        ],
      ),
    );
  }
}
