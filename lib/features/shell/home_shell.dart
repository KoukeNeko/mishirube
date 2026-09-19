import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../shared/widgets/chrome/chrome_visibility.dart';
import '../log/log_screen.dart';
import '../me/me_screen.dart';
import '../today/today_screen.dart';
import '../training/active_workout_screen.dart';
import '../training/workout_summary_screen.dart';
import '../trends/trends_screen.dart';
import 'bottom_chrome/app_bottom_chrome.dart';
import 'bottom_chrome/quick_log_menu.dart';

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

  Future<void> _confirmFinish(AppStore store) async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('結束這次訓練？'),
        content: const Text('已完成的組數會存成紀錄。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('繼續訓練'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('結束'),
          ),
        ],
      ),
    );
    if (shouldFinish != true || !mounted) return;
    store.finishWorkout();
    pushPage(context, const WorkoutSummaryScreen());
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
          workout: store.activeWorkout,
          onQuickLog: _openQuickLog,
          onOpenWorkout: () => pushPage(context, const ActiveWorkoutScreen()),
          onTogglePause: store.togglePause,
          onFinishWorkout: () => _confirmFinish(store),
        ),
      ),
    );
  }
}
