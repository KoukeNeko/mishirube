import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/haptics.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/window_controls.dart';
import '../../shared/window_layout.dart';
import '../record/record_options.dart';
import 'bottom_chrome/chrome_metrics.dart';
import 'bottom_chrome/press_feedback.dart';
import 'bottom_chrome/split_dock.dart';
import 'home_tabs.dart';

/// Space between the navigation's glass and the window's edges, and
/// between its pieces: the dock's gap.
const _gap = ChromeMetrics.gap;

/// Height of a tab in the sidebar, where its name sits beside the icon.
const _sidebarTabHeight = 44.0;

/// Height of a tab in the rail, with its name under the icon.
const _railTabHeight = 56.0;

/// Corner radius of every piece of glass here, so the「+」, the session
/// and the tabs' pane read as one set. The lens sits inside the pane,
/// concentric with it.
const _radius = AppRadius.card;
const _lensRadius = _radius - ChromeMetrics.lensInset;

/// Height of the record button and the running session under it.
const _actionHeight = 48.0;
const _sessionHeight = 40.0;

/// The tabs once the window can spare a column for them: the dock's
/// pieces stood on end. A rail of icons, or with room for their names a
/// sidebar; the green「+」above them, the running session under it, and
/// the tabs on one pane of glass with the dock's selection lens.
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
    final padding = MediaQuery.paddingOf(context);
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    // A windowed iPad draws its window controls over this corner, which
    // the safe area does not cover; start below them, where a bar would
    // have been.
    final controls = WindowControls.leadingInsetOf(context) > 0
        ? ToolbarMetrics.of(context).height
        : 0.0;
    final session = this.session;
    final tabs = ChromeSurface(
      refracts: true,
      radius: _radius,
      child: Padding(
        padding: const EdgeInsets.all(ChromeMetrics.lensInset),
        child: Column(
          children: [
            for (final spec in homeTabs)
              _SideTab(
                spec: spec,
                isExtended: isExtended,
                isSelected: spec.tab == selected,
                onTap: () {
                  if (spec.tab != selected) AppHaptics.selection(context);
                  onSelect(spec.tab);
                },
              ),
          ],
        ),
      ),
    );
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: EdgeInsets.only(
          top: padding.top + controls,
          bottom: padding.bottom,
          left: isLtr ? padding.left : 0,
          right: isLtr ? 0 : padding.right,
        ),
        child: SizedBox(
          width: isExtended ? sidebarWidth : railWidth,
          height: double.infinity,
          // The tabs' glass runs to the bottom of the window. A phone on
          // its side is too short for that: the column scrolls rather than
          // cutting off its last tab.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(_gap),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - _gap * 2,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RecordButton(
                        isExtended: isExtended,
                        controller: recordMenu,
                        onOpen: onOpen,
                      ),
                      if (session != null) ...[
                        const SizedBox(height: _gap),
                        _SessionButton(
                          isExtended: isExtended,
                          session: session,
                          onOpen: onOpenSession,
                        ),
                      ],
                      const SizedBox(height: _gap),
                      Expanded(child: tabs),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab: the dock's icon, label and lens, with a lighter lens under a
/// pointer so a mouse sees what it would pick.
class _SideTab extends StatefulWidget {
  const _SideTab({
    required this.spec,
    required this.isExtended,
    required this.isSelected,
    required this.onTap,
  });

  final HomeTabSpec spec;
  final bool isExtended;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SideTab> createState() => _SideTabState();
}

class _SideTabState extends State<_SideTab> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final isSelected = widget.isSelected;
    final color = isSelected ? AppColors.training : AppColors.textSecondary;
    final label = Text(
      spec.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: widget.isExtended ? 15 : 11,
        // Bolder when selected, as in the dock, so colour is not the only
        // cue.
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    final icon = Icon(
      isSelected ? spec.selectedIcon : spec.icon,
      color: color,
      size: 24,
    );
    final lensOpacity = isSelected
        ? (_isPressed
              ? ChromeMetrics.lensPressedFillOpacity
              : ChromeMetrics.lensFillOpacity)
        : (_isHovered ? ChromeMetrics.lensFillOpacity / 2 : 0.0);
    return Semantics(
      label: spec.label,
      selected: isSelected,
      button: true,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: PressScale(
          pressedScale: ChromeMetrics.tabPressedScale,
          onPressedChanged: (isPressed) =>
              setState(() => _isPressed = isPressed),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: ChromeMetrics.pressDuration,
              height: widget.isExtended ? _sidebarTabHeight : _railTabHeight,
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(_lensRadius),
                  ),
                  side: BorderSide(
                    color: Colors.white.withValues(
                      alpha: isSelected ? ChromeMetrics.lensBorderOpacity : 0,
                    ),
                  ),
                ),
                color: Colors.white.withValues(alpha: lensOpacity),
              ),
              child: widget.isExtended
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          icon,
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: label),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [icon, const SizedBox(height: 2), label],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dock's green「+」, opening every type the user logs as a list
/// under it: the quick-log pills grow up from the bottom of a phone,
/// which is not where this button is.
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
      alignmentOffset: const Offset(0, _gap),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.surfaceRaised),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: const WidgetStatePropertyAll(Colors.black),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.all(ChromeMetrics.lensInset),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
            side: BorderSide(color: AppColors.outline),
          ),
        ),
      ),
      menuChildren: [
        for (final option in enabledRecordOptions(context))
          MenuItemButton(
            style: MenuItemButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              textStyle: AppTextStyles.itemTitle,
              minimumSize: const Size(200, 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              shape: const StadiumBorder(),
            ),
            leadingIcon: Icon(option.icon, color: option.color, size: 22),
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
        void toggle() {
          AppHaptics.tap();
          controller.isOpen ? controller.close() : controller.open();
        }

        final plus = Icon(
          Icons.add,
          color: CenterActionSurface.foreground,
          size: 26,
        );
        final button = Semantics(
          button: true,
          label: '新增紀錄',
          onTap: toggle,
          excludeSemantics: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: PressScale(
              pressedScale: ChromeMetrics.actionPressedScale,
              child: SizedBox(
                height: _actionHeight,
                child: CenterActionSurface(
                  radius: _radius,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: toggle,
                    child: Center(
                      child: isExtended
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                plus,
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '新增紀錄',
                                  style: AppTextStyles.itemTitle.copyWith(
                                    color: CenterActionSurface.foreground,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            )
                          : plus,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        return isExtended ? button : Tooltip(message: '新增紀錄', child: button);
      },
    );
  }
}

/// The running workout or exercise on the dock accessory's tinted glass:
/// its clock, and a way back to it.
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
    final isActivity = session.category == RecordCategory.activity;
    final color = switch (session) {
      _ when session.isPaused => AppColors.warning,
      ActiveActivity() => AppColors.activity,
      ActiveWorkout() => AppColors.training,
    };
    final style = AppTextStyles.caption.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final status = session.isPaused ? '$label已暫停' : '$label進行中';
    return Tooltip(
      message: status,
      child: Semantics(
        button: true,
        label: '$status，回到$label',
        onTap: onOpen,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: PressScale(
            pressedScale: ChromeMetrics.actionPressedScale,
            child: SizedBox(
              height: _sessionHeight,
              child: ChromeSurface(
                radius: _radius,
                tint: isActivity
                    ? AppColors.activitySurface
                    : AppColors.trainingSurface,
                borderColor: isActivity
                    ? AppColors.activityOutline
                    : AppColors.trainingOutline,
                child: GestureDetector(
                  key: const ValueKey('side-session-open'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    // A long session's clock scales down rather than spill
                    // out of the rail.
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
                              session.isPaused ? '已暫停 · ' : '$status · ',
                              style: style,
                            ),
                          ElapsedClock(
                            session: session,
                            builder: (_, elapsed) =>
                                Text(elapsed, style: style),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
