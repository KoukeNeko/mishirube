import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../app/app_store.dart';
import '../../../domain/domain.dart';
import '../../../shared/toast/toast_host.dart';
import '../../../shared/window_layout.dart';
import 'chrome_metrics.dart';
import 'session_accessory.dart';
import 'split_dock.dart';

/// Floating bottom chrome: the session accessory sits above the split
/// dock and, as the chrome minimises, is squeezed into the timer capsule
/// the centre action turns into. Both are driven by one progress, so
/// they read as one piece of glass changing shape rather than two
/// widgets taking turns.
class AppBottomChrome extends StatefulWidget {
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
  State<AppBottomChrome> createState() => _AppBottomChromeState();
}

class _AppBottomChromeState extends State<AppBottomChrome>
    with SingleTickerProviderStateMixin {
  /// 0 is the expanded chrome, 1 the minimised one. Everything that
  /// changes between the two reads this.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    value: widget.isMinimized ? 1 : 0,
    duration: ChromeMetrics.morphDuration,
  );

  @override
  void didUpdateWidget(AppBottomChrome old) {
    super.didUpdateWidget(old);
    if (old.isMinimized != widget.isMinimized) _animate();
  }

  /// Carries the current speed into the new direction, so scrolling up
  /// and down quickly bends the shape around instead of stopping it dead.
  void _animate() {
    final target = widget.isMinimized ? 1.0 : 0.0;
    if (chromeDuration(context, ChromeMetrics.morphDuration) == Duration.zero) {
      _morph.value = target;
      return;
    }
    _morph.animateWith(
      SpringSimulation(
        ChromeMetrics.morphSpring,
        _morph.value,
        target,
        _morph.velocity,
        // Lands exactly on the end state; a spring's own tolerance would
        // leave the dock a fraction of a point off its resting height.
        snapToEnd: true,
      ),
    );
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.session;
    final metrics = DockMetrics.of(context);
    final expandedInset = metrics.insetFor(isMinimized: false);
    final minimizedInset = metrics.insetFor(isMinimized: true);
    final expandedOffset = metrics.bottomOffset(context, isMinimized: false);
    final minimizedOffset = metrics.bottomOffset(context, isMinimized: true);
    // No SafeArea: like the native Liquid Glass tab bar, the dock dips into
    // the home-indicator area instead of stacking on top of it.
    return ToastObstruction(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = contentColumnInsets(
            context,
            constraints.maxWidth,
            maxWidth: ChromeMetrics.dockMaxWidth,
          );
          return AnimatedBuilder(
            animation: _morph,
            builder: (context, child) {
              final t = _morph.value.clamp(0.0, 1.0);
              final inset = lerpDouble(expandedInset, minimizedInset, t)!;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  column.left + inset,
                  0,
                  column.right + inset,
                  lerpDouble(expandedOffset, minimizedOffset, t)!,
                ),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (running != null)
                  _CollapsingAccessory(
                    morph: _morph,
                    session: running,
                    onTogglePause: widget.onTogglePause,
                    onOpen: widget.onOpenSession,
                    onFinish: widget.onFinish,
                  )
                else
                  const SizedBox(width: double.infinity),
                SplitDock(
                  selected: widget.selected,
                  onSelect: widget.onSelect,
                  morph: _morph,
                  session: widget.session,
                  onQuickLog: widget.onQuickLog,
                  onOpenSession: widget.onOpenSession,
                  quickLogProgress: widget.quickLogProgress,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The accessory on its way into the timer capsule: it narrows to the
/// capsule's width, loses the height it was taking up, and fades out
/// only at the end, once it is the same shape as what replaces it.
class _CollapsingAccessory extends StatelessWidget {
  const _CollapsingAccessory({
    required this.morph,
    required this.session,
    required this.onTogglePause,
    required this.onOpen,
    required this.onFinish,
  });

  final Animation<double> morph;
  final ActiveSession session;
  final VoidCallback onTogglePause;
  final VoidCallback onOpen;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final expandedHeight = ChromeMetrics.accessoryHeight + ChromeMetrics.gap;
    return AnimatedBuilder(
      animation: morph,
      child: SessionAccessory(
        morph: morph,
        session: session,
        onTogglePause: onTogglePause,
        onOpen: onOpen,
        onFinish: onFinish,
      ),
      builder: (context, child) {
        // The spring is the curve; easing it again would double up.
        final t = morph.value.clamp(0.0, 1.0);
        final opacity =
            ((ChromeMetrics.accessoryFadeEnd - t) /
                    (ChromeMetrics.accessoryFadeEnd -
                        ChromeMetrics.accessoryFadeStart))
                .clamp(0.0, 1.0);
        // Once it has faded into the capsule it leaves the tree, so the
        // clock is not read out twice and not ticked for nothing.
        if (opacity == 0) return const SizedBox(width: double.infinity);
        // The bar is gone from the layout before it is gone from sight:
        // what is left is already the size of the capsule it lands on.
        return SizedBox(
          height: lerpDouble(expandedHeight, 0, t),
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: expandedHeight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: ChromeMetrics.gap),
              child: Opacity(
                opacity: opacity,
                child: FractionallySizedBox(
                  widthFactor: 1,
                  child: _NarrowingBox(t: t, child: child!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Narrows from the full width to the timer capsule's width, so the last
/// thing visible is the same shape as the capsule underneath it.
class _NarrowingBox extends StatelessWidget {
  const _NarrowingBox({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth;
        final width = lerpDouble(full, ChromeMetrics.timerCapsuleWidth, t)!;
        return Center(
          child: SizedBox(width: width.clamp(0.0, full), child: child),
        );
      },
    );
  }
}
