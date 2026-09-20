import 'package:flutter/material.dart';

import '../../../app/app_store.dart';
import '../../../domain/domain.dart';
import '../../../shared/toast/toast_host.dart';
import 'chrome_metrics.dart';
import 'split_dock.dart';
import 'session_accessory.dart';

/// Floating bottom chrome: the session accessory (when something is
/// running and the chrome is expanded) stacked above the split dock.
class AppBottomChrome extends StatelessWidget {
  const AppBottomChrome({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isMinimized,
    required this.session,
    required this.onQuickLog,
    required this.onOpenSession,
    required this.onTogglePause,
    required this.onFinish,
    required this.quickLogProgress,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final bool isMinimized;
  final ActiveSession? session;
  final VoidCallback onQuickLog;
  final VoidCallback onOpenSession;
  final VoidCallback onTogglePause;
  final VoidCallback onFinish;
  final Animation<double> quickLogProgress;

  @override
  Widget build(BuildContext context) {
    final duration = chromeDuration(context, ChromeMetrics.morphDuration);
    final running = session;
    final showAccessory = running != null && !isMinimized;
    final metrics = DockMetrics.of(context);
    // No SafeArea: like the native Liquid Glass tab bar, the dock dips into
    // the home-indicator area instead of stacking on top of it.
    return ToastObstruction(
      child: AnimatedPadding(
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
                      child: SessionAccessory(
                        session: running,
                        onTogglePause: onTogglePause,
                        onOpen: onOpenSession,
                        onFinish: onFinish,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            SplitDock(
              selected: selected,
              onSelect: onSelect,
              isMinimized: isMinimized,
              session: session,
              onQuickLog: onQuickLog,
              onOpenSession: onOpenSession,
              quickLogProgress: quickLogProgress,
            ),
          ],
        ),
      ),
    );
  }
}
