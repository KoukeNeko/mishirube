import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/window_controls.dart';
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
import 'side_navigation.dart';

/// What the user chose in the "finish this session?" dialog.
enum _FinishChoice { keepGoing, discard, finish }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _isChromeMinimized = false;

  /// The tabs' pages, kept by key so a window resized past a breakpoint
  /// moves them beside the rail, or back above the dock, without losing
  /// where they were.
  final _content = GlobalKey();

  /// The rail's record menu, for opening it from the keyboard.
  final _recordMenu = MenuController();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Handles the shortcuts whatever has focus, since a page taking or
  /// dropping it leaves the shell's own focus behind; but only while the
  /// shell is on top, so a dialog or a page pushed over it keeps its keys.
  bool _onKey(KeyEvent event) {
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final shortcuts = _shortcuts(AppStoreScope.read(context));
    for (final MapEntry(key: activator, value: run) in shortcuts.entries) {
      if (activator.accepts(event, HardwareKeyboard.instance)) {
        run();
        return true;
      }
    }
    return false;
  }

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
    if (tabPlacementOf(context) != TabPlacement.dock) return false;
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
    if (tabPlacementOf(context) != TabPlacement.dock) {
      _recordMenu.open();
      return;
    }
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

  /// A keyboard's way round: Command (Control off Apple) with 1 to 4 for
  /// the tabs and N for a new record. Not on the web, where the browser
  /// already owns them.
  Map<ShortcutActivator, VoidCallback> _shortcuts(AppStore store) {
    if (kIsWeb) return const {};
    final isApple = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    SingleActivator withModifier(LogicalKeyboardKey key) => SingleActivator(
      key,
      meta: isApple,
      control: !isApple,
      includeRepeats: false,
    );
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    return {
      for (final tab in HomeTab.values)
        withModifier(digits[tab.index]): () => _selectTab(store, tab),
      withModifier(LogicalKeyboardKey.keyN): _openQuickLog,
    };
  }

  void _openActiveSession(AppStore store) {
    if (store.activeSession case final session?) _openSession(session);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final placement = tabPlacementOf(context);
    final hasDock = placement == TabPlacement.dock;
    final content = KeyedSubtree(
      key: _content,
      child: QuickLogRecess(
        animation: _quickLogProgress,
        child: IndexedStack(
          index: store.selectedTab.index,
          // With two panes every tab is a main page and what is
          // opened from it, so the navigation stays put between tabs.
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
    );
    return QuickLogScrim(
      animation: _quickLogProgress,
      child: Scaffold(
        // Content scrolls underneath the floating, translucent chrome.
        extendBody: true,
        // Pages paint their own headers behind the status bar.
        body: ChromeVisibility(
          isMinimized: hasDock && _isChromeMinimized,
          child: NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: hasDock
                ? content
                : Row(
                    children: [
                      SideNavigation(
                        isExtended: placement == TabPlacement.sidebar,
                        selected: store.selectedTab,
                        onSelect: (tab) => _selectTab(store, tab),
                        recordMenu: _recordMenu,
                        onOpen: _open,
                        session: store.activeSession,
                        onOpenSession: () => _openActiveSession(store),
                      ),
                      Expanded(
                        child: _BesideNavigation(
                          navigationWidth: placement.width,
                          child: content,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        bottomNavigationBar: hasDock
            ? _MainPaneDock(
                width: _mainWidth(context),
                child: AppBottomChrome(
                  selected: store.selectedTab,
                  onSelect: (tab) => _selectTab(store, tab),
                  isMinimized: _isChromeMinimized,
                  session: store.activeSession,
                  onQuickLog: _openQuickLog,
                  onOpenSession: () => _openActiveSession(store),
                  onTogglePause: store.togglePause,
                  onFinish: () {
                    if (store.activeSession case final session?) {
                      _confirmFinish(store, session);
                    }
                  },
                  quickLogProgress: _quickLogProgress,
                ),
              )
            : null,
      ),
    );
  }
}

/// The pages beside the rail or sidebar, which starts where the window
/// does: the safe area on that side is the navigation's, the window
/// controls are over it rather than the pages, and a fold is measured
/// from the pages' own edge.
class _BesideNavigation extends StatelessWidget {
  const _BesideNavigation({required this.navigationWidth, required this.child});

  final double navigationWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    EdgeInsets trim(EdgeInsets insets) =>
        isLtr ? insets.copyWith(left: 0) : insets.copyWith(right: 0);
    final shift = isLtr ? navigationWidth : 0.0;
    return MediaQuery(
      data: media.copyWith(
        padding: trim(media.padding),
        viewPadding: trim(media.viewPadding),
        displayFeatures: [
          for (final feature in media.displayFeatures)
            DisplayFeature(
              bounds: feature.bounds.shift(Offset(-shift, 0)),
              type: feature.type,
              state: feature.state,
            ),
        ],
      ),
      child: WindowControls(leadingInset: 0, child: child),
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
