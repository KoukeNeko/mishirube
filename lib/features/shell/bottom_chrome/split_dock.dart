import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';

import '../../../app/app_store.dart';
import '../../../app/theme.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/chrome/chrome_surface.dart';
import '../../../shared/widgets/content/elapsed_clock.dart';
import 'chrome_metrics.dart';
import 'press_feedback.dart';
import '../../../shared/haptics.dart';

/// Width of a tab's icon area; its height comes from [DockMetrics.iconBox].
const _indicatorWidth = 56.0;

class _TabSpec {
  const _TabSpec(this.tab, this.icon, this.selectedIcon, this.label);

  final HomeTab tab;
  final IconData icon;

  /// Filled variant, so selection is not signalled by colour alone.
  final IconData selectedIcon;
  final String label;
}

const _leadingTabs = [
  _TabSpec(HomeTab.today, Icons.my_location_outlined, Icons.my_location, '今天'),
  _TabSpec(HomeTab.log, Icons.list_alt_outlined, Icons.list_alt, '紀錄'),
];
const _trailingTabs = [
  _TabSpec(HomeTab.trends, Icons.insights_outlined, Icons.insights, '趨勢'),
  _TabSpec(HomeTab.me, Icons.person_outline, Icons.person, '我的'),
];

/// Two navigation capsules around a separate action button: tabs mean
/// "where am I", the centre means "record something" (or, minimised during
/// a workout, "go back to it").
class SplitDock extends StatelessWidget {
  const SplitDock({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.isMinimized,
    required this.workout,
    required this.onQuickLog,
    required this.onOpenWorkout,
    required this.quickLogProgress,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final bool isMinimized;
  final WorkoutSession? workout;
  final VoidCallback onQuickLog;
  final VoidCallback onOpenWorkout;

  /// Open progress of the quick-log menu, whose × stands in for「+」.
  final Animation<double> quickLogProgress;

  @override
  Widget build(BuildContext context) {
    final duration = chromeDuration(context, ChromeMetrics.morphDuration);
    final metrics = DockMetrics.of(context);
    final height = metrics.heightFor(isMinimized: isMinimized);
    final showTimer = isMinimized && workout != null;
    return AnimatedContainer(
      duration: duration,
      curve: ChromeMetrics.morphCurve,
      height: height,
      // The centre action is painted after both capsules: their glass blurs
      // whatever is painted before it, and would pick up its green.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Expanded(child: _capsule(_leadingTabs, metrics)),
              const SizedBox(width: ChromeMetrics.gap),
              // Holds the centre action's place, sized and animated with it.
              AnimatedContainer(
                duration: duration,
                curve: ChromeMetrics.morphCurve,
                width: showTimer ? ChromeMetrics.timerCapsuleWidth : height,
              ),
              const SizedBox(width: ChromeMetrics.gap),
              Expanded(child: _capsule(_trailingTabs, metrics)),
            ],
          ),
          // Hidden while the quick-log menu is open: its × replaces「+」
          // in the same spot, sharp above the blurred app.
          AnimatedBuilder(
            animation: quickLogProgress,
            builder: (context, child) => Opacity(
              key: const ValueKey('dock-center-visibility'),
              opacity: quickLogProgress.value > 0 ? 0 : 1,
              child: child,
            ),
            child: _CenterAction(
              size: height,
              metrics: metrics,
              workout: showTimer ? workout : null,
              onQuickLog: onQuickLog,
              onOpenWorkout: onOpenWorkout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _capsule(List<_TabSpec> tabs, DockMetrics metrics) {
    return _Capsule(
      tabs: tabs,
      metrics: metrics,
      selected: selected,
      showLabels: !isMinimized,
      onSelect: onSelect,
    );
  }
}

/// One glass capsule of tabs with its own selection lens. The lens never
/// travels to the other capsule: the centre action is a break between them.
class _Capsule extends StatefulWidget {
  const _Capsule({
    required this.tabs,
    required this.metrics,
    required this.selected,
    required this.showLabels,
    required this.onSelect,
  });

  final List<_TabSpec> tabs;
  final DockMetrics metrics;
  final HomeTab selected;
  final bool showLabels;
  final ValueChanged<HomeTab> onSelect;

  @override
  State<_Capsule> createState() => _CapsuleState();
}

class _CapsuleState extends State<_Capsule> {
  int? _pressedIndex;

  /// Tab under the finger while dragging; the selection itself only
  /// changes on release.
  int? _previewIndex;

  /// Lens centre in tab units (0 = first tab) while it follows the finger.
  double? _dragPosition;

  /// Whether releasing now would select [_previewIndex]; false while the
  /// finger is sideways off the capsule (e.g. over「+」).
  bool _isArmed = false;
  Size _size = Size.zero;

  int get _selectedIndex =>
      widget.tabs.indexWhere((spec) => spec.tab == widget.selected);

  bool get _isScrubbing => _dragPosition != null;

  void _select(HomeTab tab) {
    // A selection tick only when the selection actually changes; Android
    // tab bars do not buzz.
    if (tab != widget.selected) AppHaptics.selection(context);
    widget.onSelect(tab);
  }

  double get _cellWidth => _size.width / widget.tabs.length;

  void _startScrub(Offset position) {
    setState(() {
      _previewIndex = _selectedIndex < 0 ? null : _selectedIndex;
      _updateScrub(position);
    });
  }

  void _moveScrub(Offset position) {
    setState(() => _updateScrub(position));
  }

  void _updateScrub(Offset position) {
    // Only straying sideways (onto「+」or the gap) cancels; a finger that
    // drifts up or down while sliding still picks the tab below it.
    _isArmed = position.dx >= 0 && position.dx <= _size.width;
    // The lens tracks the finger 1:1 but never leaves the capsule.
    _dragPosition = (position.dx / _cellWidth - 0.5).clamp(
      0.0,
      widget.tabs.length - 1.0,
    );
    if (!_isArmed) return;
    final preview = _previewAt(position.dx);
    if (preview != _previewIndex) {
      _previewIndex = preview;
      AppHaptics.selection(context);
    }
  }

  int _previewAt(double x) {
    final raw = (x / _cellWidth).floor().clamp(0, widget.tabs.length - 1);
    final current = _previewIndex;
    if (current == null || raw == current) return raw;
    final boundary = math.max(raw, current) * _cellWidth;
    return (x - boundary).abs() >= ChromeMetrics.scrubHysteresis
        ? raw
        : current;
  }

  void _onScrubCancel() {
    if (_isScrubbing) _endScrub();
  }

  void _endScrub() {
    final preview = _previewIndex;
    final commit = _isArmed && preview != null;
    setState(() {
      _dragPosition = null;
      _previewIndex = null;
      _isArmed = false;
    });
    // The drag already ticked on each change, so no release haptic.
    if (commit && preview != _selectedIndex) {
      widget.onSelect(widget.tabs[preview].tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;
    final shownIndex = _isScrubbing
        ? _previewIndex
        : (selectedIndex < 0 ? null : selectedIndex);
    // VoiceOver users switch tabs by double-tapping; no drag to learn.
    final canScrub = !MediaQuery.accessibleNavigationOf(context);
    final capsule = LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: _SelectionLens(
                index: shownIndex,
                count: widget.tabs.length,
                dragPosition: _dragPosition,
                isPressed:
                    _isScrubbing ||
                    (_pressedIndex != null && _pressedIndex == selectedIndex),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < widget.tabs.length; i++)
                  Expanded(
                    child: _TabButton(
                      spec: widget.tabs[i],
                      metrics: widget.metrics,
                      isSelected: i == selectedIndex,
                      isHighlighted: i == shownIndex,
                      isScrubbing: _isScrubbing,
                      showLabel: widget.showLabels,
                      onTap: () => _select(widget.tabs[i].tab),
                      onPressedChanged: (isPressed) =>
                          setState(() => _pressedIndex = isPressed ? i : null),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
    return ChromeSurface(
      refracts: true,
      child: !canScrub
          ? capsule
          : RawGestureDetector(
              // Only the capsule, never the whole dock row: content beside
              // it keeps scrolling normally.
              // Two ways into a drag: slide sideways right away, or rest a
              // finger briefly and then slide. A tap that does neither
              // stays a tap.
              gestures: {
                HorizontalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      HorizontalDragGestureRecognizer
                    >(
                      HorizontalDragGestureRecognizer.new,
                      (recognizer) => recognizer
                        ..onStart = ((details) =>
                            _startScrub(details.localPosition))
                        ..onUpdate = ((details) =>
                            _moveScrub(details.localPosition))
                        ..onEnd = ((_) => _endScrub())
                        ..onCancel = _onScrubCancel,
                    ),
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: ChromeMetrics.scrubHoldDuration,
                      ),
                      (recognizer) => recognizer
                        ..onLongPressStart = ((details) =>
                            _startScrub(details.localPosition))
                        ..onLongPressMoveUpdate = ((details) =>
                            _moveScrub(details.localPosition))
                        ..onLongPressEnd = ((_) => _endScrub())
                        ..onLongPressCancel = _onScrubCancel,
                    ),
              },
              child: capsule,
            ),
    );
  }
}

/// Faint glass patch behind the selected tab. A tap springs it to the new
/// tab; a drag makes it follow the finger, slightly enlarged, and springs
/// it into place on release. It fades in when selection enters the capsule
/// and out when it leaves, rather than sliding across the centre action.
class _SelectionLens extends StatefulWidget {
  const _SelectionLens({
    required this.index,
    required this.count,
    required this.dragPosition,
    required this.isPressed,
  });

  /// Tab the lens rests on, or null when selection is in the other capsule.
  final int? index;
  final int count;

  /// Finger position in tab units while dragging.
  final double? dragPosition;
  final bool isPressed;

  @override
  State<_SelectionLens> createState() => _SelectionLensState();
}

class _SelectionLensState extends State<_SelectionLens>
    with SingleTickerProviderStateMixin {
  late final _position = AnimationController.unbounded(
    vsync: this,
    value: (widget.index ?? 0).toDouble(),
  );

  @override
  void didUpdateWidget(_SelectionLens oldWidget) {
    super.didUpdateWidget(oldWidget);
    final drag = widget.dragPosition;
    if (drag != null) {
      // Direct tracking: a spring chasing the finger would lag behind it.
      _position.value = drag;
      return;
    }
    final target = widget.index;
    if (target == null) return;
    final wasDragging = oldWidget.dragPosition != null;
    if (!wasDragging && target == oldWidget.index) return;
    if ((!wasDragging && oldWidget.index == null) ||
        prefersReducedMotion(context)) {
      _position.value = target.toDouble();
    } else {
      _position.animateWith(
        SpringSimulation(
          ChromeMetrics.lensSnapSpring,
          _position.value,
          target.toDouble(),
          _position.velocity,
        ),
      );
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const inset = ChromeMetrics.lensInset;
    final isDragging = widget.dragPosition != null;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.index == null && !isDragging ? 0 : 1,
        duration: chromeDuration(context, ChromeMetrics.lensFadeDuration),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / widget.count;
            // Concentric with the capsule, so it grows and shrinks with
            // the dock instead of floating at a fixed size inside it.
            final height = constraints.maxHeight - inset * 2;
            return AnimatedBuilder(
              animation: _position,
              builder: (context, child) => Stack(
                children: [
                  Positioned(
                    left: _position.value * cellWidth + inset,
                    top: inset,
                    width: cellWidth - inset * 2,
                    height: height,
                    child: child!,
                  ),
                ],
              ),
              child: AnimatedScale(
                scale: isDragging && !prefersReducedMotion(context)
                    ? ChromeMetrics.scrubLensScale
                    : 1,
                duration: ChromeMetrics.lensFadeDuration,
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  key: const ValueKey('dock-selection-lens'),
                  duration: ChromeMetrics.pressDuration,
                  decoration: ShapeDecoration(
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(
                          alpha: ChromeMetrics.lensBorderOpacity,
                        ),
                      ),
                    ),
                    color: Colors.white.withValues(
                      alpha: widget.isPressed
                          ? ChromeMetrics.lensPressedFillOpacity
                          : ChromeMetrics.lensFillOpacity,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.metrics,
    required this.isSelected,
    required this.isHighlighted,
    required this.isScrubbing,
    required this.showLabel,
    required this.onTap,
    required this.onPressedChanged,
  });

  final _TabSpec spec;
  final DockMetrics metrics;

  /// The tab that is actually selected (what assistive tech reports).
  final bool isSelected;

  /// Drawn as selected: the selected tab, or the one under a dragging
  /// finger.
  final bool isHighlighted;
  final bool isScrubbing;
  final bool showLabel;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    final color = isHighlighted ? AppColors.training : AppColors.textSecondary;
    final indicatorSize = Size(_indicatorWidth, metrics.iconBox);
    return Semantics(
      label: spec.label,
      selected: isSelected,
      button: true,
      // Excluding the child's semantics drops its tap too.
      onTap: onTap,
      excludeSemantics: true,
      // The whole cell is tappable. No ink: the press squeeze, the lens
      // and the selected state are the feedback. The cell is transparent,
      // so squeezing it squeezes just the icon and label.
      child: PressScale(
        pressedScale: ChromeMetrics.tabPressedScale,
        // Once a drag takes over, the lens is the feedback; the pressed
        // tab springs back instead of staying squeezed.
        isSuppressed: isScrubbing,
        onPressedChanged: onPressedChanged,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ChromeMetrics.minTapTarget,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.fromSize(
                    size: indicatorSize,
                    child: Icon(
                      isHighlighted ? spec.selectedIcon : spec.icon,
                      color: color,
                      size: metrics.iconSize,
                    ),
                  ),
                  if (showLabel) ...[
                    SizedBox(height: metrics.labelGap),
                    SizedBox(
                      height: metrics.labelHeight,
                      child: Text(
                        spec.label,
                        style: TextStyle(
                          color: color,
                          fontSize: metrics.labelSize,
                          height: metrics.labelHeight / metrics.labelSize,
                          // Semibold like system tab labels; bolder when
                          // selected so colour is not the only cue.
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「+」as tall as the capsules (a separate action, not a raised FAB) that
/// morphs into a timer capsule when a workout is minimised.
class _CenterAction extends StatelessWidget {
  const _CenterAction({
    required this.size,
    required this.metrics,
    required this.workout,
    required this.onQuickLog,
    required this.onOpenWorkout,
  });

  final double size;
  final DockMetrics metrics;

  /// Non-null only when the centre should show the running workout timer.
  final WorkoutSession? workout;
  final VoidCallback onQuickLog;
  final VoidCallback onOpenWorkout;

  @override
  Widget build(BuildContext context) {
    final duration = chromeDuration(context, ChromeMetrics.morphDuration);
    final session = workout;
    void activate() {
      // The primary action gets a firmer tap than tab selection.
      AppHaptics.tap();
      session == null ? onQuickLog() : onOpenWorkout();
    }

    return Semantics(
      button: true,
      label: session == null ? '新增紀錄' : '訓練進行中，回到訓練',
      onTap: activate,
      excludeSemantics: true,
      child: PressScale(
        pressedScale: ChromeMetrics.actionPressedScale,
        child: AnimatedContainer(
          duration: duration,
          curve: ChromeMetrics.morphCurve,
          width: session == null ? size : ChromeMetrics.timerCapsuleWidth,
          height: size,
          child: CenterActionSurface(
            child: GestureDetector(
              key: const ValueKey('dock-center-action'),
              behavior: HitTestBehavior.opaque,
              onTap: activate,
              child: AnimatedSwitcher(
                duration: duration,
                child: session == null
                    ? Icon(
                        Icons.add,
                        key: const ValueKey('plus'),
                        size: metrics.actionIconSize,
                        color: CenterActionSurface.foreground,
                      )
                    : _TimerLabel(
                        key: const ValueKey('timer'),
                        workout: session,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green glass of the centre action: the dock's liquid glass tinted almost
/// solid green, so it keeps the accent yet shares the capsules' rim and
/// light. The quick-log menu's × wears the same, since it stands in for
/// 「+」while the menu is open.
class CenterActionSurface extends StatelessWidget {
  const CenterActionSurface({super.key, required this.child});

  /// Colour of what sits on the surface: the「+」, ×, and workout timer.
  static const foreground = AppColors.onTraining;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChromeSurface(
      refracts: true,
      tint: AppColors.training,
      tintOpacity: 0.7,
      borderColor: AppColors.training,
      child: child,
    );
  }
}

class _TimerLabel extends StatelessWidget {
  const _TimerLabel({super.key, required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              workout.isPaused ? Icons.pause : Icons.circle,
              size: workout.isPaused ? 16 : 10,
              color: CenterActionSurface.foreground,
            ),
            const SizedBox(width: AppSpacing.xs),
            ElapsedClock(
              workout: workout,
              builder: (_, elapsed) => Text(
                elapsed,
                style: AppTextStyles.buttonLabel.copyWith(
                  color: CenterActionSurface.foreground,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
