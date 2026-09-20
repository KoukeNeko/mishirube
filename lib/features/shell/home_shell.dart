import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/activity_detail_screen.dart';
import '../activity/live_activity_screen.dart';
import '../log/log_screen.dart';
import '../me/me_screen.dart';
import '../today/today_screen.dart';
import '../training/active_workout_screen.dart';
import '../training/workout_summary_screen.dart';
import '../trends/trends_screen.dart';
import 'bottom_chrome/app_bottom_chrome.dart';
import 'bottom_chrome/quick_log_menu.dart';

/// What the user chose in the "finish this session?" dialog.
enum _FinishChoice { keepGoing, discard, finish }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _isChromeMinimized = false;

  /// Follows the quick-log menu's animation while it is open.
  final _quickLogProgress = ProxyAnimation(kAlwaysDismissedAnimation);

  void _setMinimized(bool value) {
    if (_isChromeMinimized != value) {
      setState(() => _isChromeMinimized = value);
    }
  }

  /// Scrolling down tucks the chrome away; scrolling up or reaching the top
  /// brings it back, mirroring iOS tab bar minimisation.
  bool _onScroll(UserScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    // The direction is reported before the offset moves, so pixels are only
    // trustworthy once scrolling has come to rest.
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _setMinimized(true);
      case ScrollDirection.forward:
        _setMinimized(false);
      case ScrollDirection.idle:
        if (metrics.pixels <= metrics.minScrollExtent) _setMinimized(false);
    }
    return false;
  }

  void _selectTab(AppStore store, HomeTab tab) {
    _setMinimized(false);
    store.selectTab(tab);
  }

  void _openQuickLog() {
    // The menu's close button is drawn where the expanded「+」sits.
    _setMinimized(false);
    showQuickLogMenu(context, recess: _quickLogProgress);
  }

  void _openSession(ActiveSession session) =>
      pushPage(context, switch (session) {
        ActiveWorkout() => const ActiveWorkoutScreen(),
        ActiveActivity() => const LiveActivityScreen(),
      });

  Future<void> _confirmFinish(AppStore store, ActiveSession session) async {
    final label = session.label;
    final choice = await showAppDialog<_FinishChoice>(
      context,
      AppDialog(
        title: '結束這次$label？',
        message: switch (session) {
          ActiveWorkout() => '已完成的組數會存成紀錄；放棄則不會算成一次訓練。',
          ActiveActivity() => '結束會存成一筆運動紀錄；放棄則什麼都不留。',
        },
        actions: (dialogContext) => [
          PrimaryButton(
            label: '結束',
            onPressed: () =>
                Navigator.of(dialogContext).pop(_FinishChoice.finish),
          ),
          SecondaryButton(
            label: '繼續$label',
            onPressed: () =>
                Navigator.of(dialogContext).pop(_FinishChoice.keepGoing),
          ),
          Center(
            child: LinkText(
              label: '放棄',
              color: AppColors.warning,
              onTap: () =>
                  Navigator.of(dialogContext).pop(_FinishChoice.discard),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case null || _FinishChoice.keepGoing:
        return;
      case _FinishChoice.discard:
        switch (session) {
          case ActiveWorkout():
            store.discardWorkout();
          case ActiveActivity():
            store.discardActivity();
        }
        showToast(context, '已放棄這次$label，沒有存成紀錄');
      case _FinishChoice.finish:
        switch (session) {
          case ActiveWorkout():
            store.finishWorkout();
            pushPage(context, const WorkoutSummaryScreen());
          case ActiveActivity():
            final finished = store.finishActivity();
            if (finished == null) return;
            pushPage(context, ActivityDetailScreen(activityId: finished.id));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    return QuickLogScrim(
      animation: _quickLogProgress,
      child: Scaffold(
        // Content scrolls underneath the floating, translucent chrome.
        extendBody: true,
        // Pages paint their own headers behind the status bar.
        body: ChromeVisibility(
          isMinimized: _isChromeMinimized,
          child: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: QuickLogRecess(
              animation: _quickLogProgress,
              child: IndexedStack(
                index: store.selectedTab.index,
                children: const [
                  TodayScreen(),
                  LogScreen(),
                  TrendsScreen(),
                  MeScreen(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: AppBottomChrome(
          selected: store.selectedTab,
          onSelect: (tab) => _selectTab(store, tab),
          isMinimized: _isChromeMinimized,
          session: store.activeSession,
          onQuickLog: _openQuickLog,
          onOpenSession: () {
            if (store.activeSession case final session?) _openSession(session);
          },
          onTogglePause: store.togglePause,
          onFinish: () {
            if (store.activeSession case final session?) {
              _confirmFinish(store, session);
            }
          },
          quickLogProgress: _quickLogProgress,
        ),
      ),
    );
  }
}
