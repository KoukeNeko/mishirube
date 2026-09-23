import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/window_controls.dart';
import '../../shared/window_layout.dart';
import '../record/record_options.dart';
import 'home_tabs.dart';

/// The tabs once the window can spare a column for them: a rail of icons,
/// or, with room for their names, a sidebar. Recording something sits at
/// the top, as the rail's one action, with a running session under it;
/// neither is a place to go, so neither is a tab.
///
/// Unlike the dock it never tucks away while a page scrolls: it takes no
/// height from the page, and a pointer finds it where it always is.
class SideNavigation extends StatelessWidget {
  const SideNavigation({
    super.key,
    required this.isExtended,
    required this.selected,
    required this.onSelect,
    required this.recordMenu,
    required this.onOpen,
    required this.session,
    required this.onOpenSession,
  });

  /// A sidebar with each tab's name, rather than a rail of icons.
  final bool isExtended;
  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;

  /// Opens the record menu from elsewhere: a keyboard shortcut.
  final MenuController recordMenu;

  /// Opens the page a record option leads to.
  final void Function(Widget page) onOpen;
  final ActiveSession? session;
  final VoidCallback onOpenSession;

  @override
  Widget build(BuildContext context) {
    // The rail keeps to the safe area itself. A windowed iPad also draws
    // its window controls over this corner, which the safe area does not
    // cover; the rail starts below them, where a bar would have been.
    final controls = WindowControls.leadingInsetOf(context) > 0
        ? ToolbarMetrics.of(context).height
        : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: BorderDirectional(
          end: const BorderSide(color: AppColors.outline),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: controls),
        // A phone on its side is short: the rail scrolls rather than
        // cutting off its last tab.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: _rail(session)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rail(ActiveSession? session) {
    return NavigationRail(
      extended: isExtended,
      minWidth: railWidth,
      minExtendedWidth: sidebarWidth,
      backgroundColor: Colors.transparent,
      labelType: isExtended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      selectedIndex: selected.index,
      onDestinationSelected: (index) => onSelect(HomeTab.values[index]),
      indicatorColor: AppColors.surfaceRaised,
      selectedIconTheme: const IconThemeData(color: AppColors.training),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: AppTextStyles.caption.copyWith(
        color: AppColors.textPrimary,
      ),
      unselectedLabelTextStyle: AppTextStyles.caption,
      leading: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          bottom: AppSpacing.md,
        ),
        child: Column(
          children: [
            _RecordButton(
              isExtended: isExtended,
              controller: recordMenu,
              onOpen: onOpen,
            ),
            if (session != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _SessionButton(
                isExtended: isExtended,
                session: session,
                onOpen: onOpenSession,
              ),
            ],
          ],
        ),
      ),
      destinations: [
        for (final spec in homeTabs)
          NavigationRailDestination(
            icon: Icon(spec.icon),
            selectedIcon: Icon(spec.selectedIcon),
            label: Text(spec.label),
          ),
      ],
    );
  }
}

/// Width of what sits above the sidebar's tabs, inside its margins.
const _sidebarItemWidth = sidebarWidth - AppSpacing.md * 2;

/// The record menu: every type the user logs, as a list under the button
/// rather than the dock's pills, which grow up from the bottom of a phone.
class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.isExtended,
    required this.controller,
    required this.onOpen,
  });

  final bool isExtended;
  final MenuController controller;
  final void Function(Widget page) onOpen;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: controller,
      menuChildren: [
        for (final option in enabledRecordOptions(context))
          MenuItemButton(
            leadingIcon: Icon(option.icon, color: option.color),
            onPressed: () {
              if (option.destination case final destination?) {
                onOpen(destination());
              } else {
                option.onSelect!(context);
              }
            },
            child: Text(option.title),
          ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        const shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
        );
        if (isExtended) {
          return SizedBox(
            width: _sidebarItemWidth,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.training,
                foregroundColor: AppColors.onTraining,
                minimumSize: const Size.fromHeight(48),
                shape: shape,
              ),
              onPressed: toggle,
              icon: const Icon(Icons.add),
              label: const Text('新增紀錄'),
            ),
          );
        }
        return IconButton.filled(
          tooltip: '新增紀錄',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.training,
            foregroundColor: AppColors.onTraining,
            fixedSize: const Size.square(56),
            shape: shape,
          ),
          onPressed: toggle,
          icon: const Icon(Icons.add),
        );
      },
    );
  }
}

/// The running workout or exercise: its clock, and a way back to it.
class _SessionButton extends StatelessWidget {
  const _SessionButton({
    required this.isExtended,
    required this.session,
    required this.onOpen,
  });

  final bool isExtended;
  final ActiveSession session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final label = session.label;
    final color = switch (session) {
      _ when session.isPaused => AppColors.warning,
      ActiveActivity() => AppColors.activity,
      ActiveWorkout() => AppColors.training,
    };
    final style = AppTextStyles.caption.copyWith(
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Tooltip(
      message: session.isPaused ? '$label已暫停' : '$label進行中',
      child: Material(
        color: AppColors.surfaceRaised,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('side-session-open'),
          onTap: onOpen,
          child: SizedBox(
            width: isExtended ? _sidebarItemWidth : 64,
            height: 36,
            // A long session's clock scales down rather than spill out of
            // the rail.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    session.isPaused ? Icons.pause : Icons.circle,
                    size: 8,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  if (isExtended)
                    Text(
                      session.isPaused ? '已暫停 · ' : '$label進行中 · ',
                      style: style,
                    ),
                  ElapsedClock(
                    session: session,
                    builder: (_, elapsed) => Text(elapsed, style: style),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
