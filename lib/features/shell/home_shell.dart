import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/window_layout.dart';
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

  /// One per tab, so what the dock and the add menu open lands beside the
  /// selected tab's list when there are two panes.
  final _layouts = [
    for (final _ in HomeTab.values) GlobalKey<ListDetailLayoutState>(),
  ];

  /// Opens [page] beside the selected tab's list, or over the shell when
  /// the window has one pane.
  Future<T?> _open<T>(Widget page) {
    final tab = AppStoreScope.read(context).selectedTab;
    return _layouts[tab.index].currentState?.showBeside<T>(page) ??
        pushPage<T>(context, page);
  }

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

  /// The main pane's width when the window shows two panes, which the dock
  /// keeps to; null when the page is the whole window.
  double? _mainWidth(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    return showsTwoPanes(context)
        ? mainPaneExtent(context, window.width)
        : null;
  }

  void _openQuickLog() {
    // The menu's close button is drawn where the expanded「+」sits.
    _setMinimized(false);
    showQuickLogMenu(
      context,
      recess: _quickLogProgress,
      width: _mainWidth(context),
      onOpen: _open,
    );
  }

  void _openSession(ActiveSession session) => _open<void>(switch (session) {
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
        actions: [
          DialogAction(
            label: '結束並儲存',
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(_FinishChoice.finish),
          ),
          DialogAction(
            label: switch (session) {
              ActiveWorkout() => '放棄這次訓練',
              ActiveActivity() => '放棄這次運動',
            },
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(_FinishChoice.discard),
          ),
          // The way out goes last, where a stacked Cancel belongs.
          DialogAction(
            label: '繼續$label',
            onTap: () => Navigator.of(context).pop(_FinishChoice.keepGoing),
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
        showToast(context, '已放棄這次$label');
      case _FinishChoice.finish:
        switch (session) {
          case ActiveWorkout():
            store.finishWorkout();
            _open<void>(const WorkoutSummaryScreen());
          case ActiveActivity():
            final finished = store.finishActivity();
            if (finished == null) return;
            _open<void>(ActivityDetailScreen(activityId: finished.id));
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
                // With two panes every tab is a main page and what is
                // opened from it, so the dock stays put between tabs.
                children: [
                  ListDetailLayout(
                    key: _layouts[HomeTab.today.index],
                    list: const TodayScreen(),
                    placeholder: const DetailPanePlaceholder(
                      icon: Icons.my_location_outlined,
                      label: '未選取項目',
                    ),
                  ),
                  ListDetailLayout(
                    key: _layouts[HomeTab.log.index],
                    list: const LogScreen(),
                    placeholder: const DetailPanePlaceholder(
                      icon: Icons.list_alt,
                      label: '未選取紀錄',
                    ),
                  ),
                  ListDetailLayout(
                    key: _layouts[HomeTab.trends.index],
                    list: const TrendsScreen(),
                    placeholder: const DetailPanePlaceholder(
                      icon: Icons.insights_outlined,
                      label: '未選取項目',
                    ),
                  ),
                  ListDetailLayout(
                    key: _layouts[HomeTab.me.index],
                    list: const MeScreen(),
                    placeholder: const DetailPanePlaceholder(
                      icon: Icons.person_outline,
                      label: '未選取項目',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _MainPaneDock(
          width: _mainWidth(context),
          child: AppBottomChrome(
            selected: store.selectedTab,
            onSelect: (tab) => _selectTab(store, tab),
            isMinimized: _isChromeMinimized,
            session: store.activeSession,
            onQuickLog: _openQuickLog,
            onOpenSession: () {
              if (store.activeSession case final session?) {
                _openSession(session);
              }
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
      ),
    );
  }
}

/// The dock where a phone has it: along the bottom of the page, which with
/// two panes is the main pane on the leading side rather than the window.
class _MainPaneDock extends StatelessWidget {
  const _MainPaneDock({required this.width, required this.child});

  /// The main pane's width, or null when the page is the whole window.
  final double? width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = this.width;
    if (width == null) return child;
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        end: MediaQuery.sizeOf(context).width - width,
      ),
      // The pane's far edge is not the screen's, so it has no inset there.
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: !isLtr,
        removeRight: isLtr,
        child: child,
      ),
    );
  }
}
