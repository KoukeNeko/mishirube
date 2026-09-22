import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme.dart';
import '../motion.dart';
import '../window_layout.dart';
import '../widgets/chrome/chrome_surface.dart';
import '../widgets/content/stats.dart';
import 'toast_controller.dart';

/// Space between a toast and the chrome it floats above.
const _chromeGap = 10.0;

const _gutter = 16.0;
const _maxWidth = 370.0;
const _minHeight = 52.0;
const _radius = 20.0;
const _enterDuration = Duration(milliseconds: 200);
const _exitDuration = Duration(milliseconds: 150);
const _moveDuration = Duration(milliseconds: 250);

/// Hosts app-wide toasts above the navigator, so any route (and dialogs)
/// can show one and it survives pushes and pops.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  final _controller = ToastController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller.keepsActionableToasts = MediaQuery.accessibleNavigationOf(
      context,
    );
    return ToastScope(
      controller: _controller,
      child: Stack(
        children: [
          widget.child,
          _ToastLayer(controller: _controller),
        ],
      ),
    );
  }
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer({required this.controller});

  final ToastController controller;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer> {
  /// The toast on screen, and whether the keyboard was up when it came.
  int? _toastId;
  bool _cameWithKeyboard = false;

  ToastController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final media = MediaQuery.of(context);
        final reduceMotion = prefersReducedMotion(context);
        final toast = controller.current;
        final keyboard = media.viewInsets.bottom;
        // Where a toast sits is settled when it appears, and it never jumps
        // to the other end of the screen: under the top bar it covered the
        // page's title and search field. One that was already showing
        // stays put when the keyboard comes up and is simply covered while
        // the user types — its undo is still there afterwards. One that
        // appears with the keyboard up sits just above it, and follows it
        // back down when it goes.
        if (toast?.id != _toastId) {
          _toastId = toast?.id;
          _cameWithKeyboard = keyboard > 0;
        }
        final obstructionTop = controller.obstructionTop;
        final chromeBottom = obstructionTop == null
            ? floatingChromeBottomOffset(context)
            : media.size.height - obstructionTop + _chromeGap;
        final bottom = _cameWithKeyboard
            ? math.max(chromeBottom, keyboard + _chromeGap)
            : chromeBottom;
        // Never across a hinge: on the leading side of one, like dialogs.
        final span = usableSpan(context, media.size.width);
        return AnimatedPositioned(
          duration: reduceMotion ? Duration.zero : _moveDuration,
          curve: Curves.easeOut,
          left: span.start + _gutter,
          right: media.size.width - span.end + _gutter,
          bottom: bottom,
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Material(
                type: MaterialType.transparency,
                child: AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : _enterDuration,
                  reverseDuration: reduceMotion ? Duration.zero : _exitDuration,
                  transitionBuilder: (child, animation) => _ToastTransition(
                    animation: animation,
                    fadeOnly: reduceMotion,
                    child: child,
                  ),
                  child: toast == null
                      ? const SizedBox(key: ValueKey('no-toast'))
                      : _ToastCard(
                          key: ValueKey(toast.id),
                          toast: toast,
                          controller: controller,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToastTransition extends StatelessWidget {
  const _ToastTransition({
    required this.animation,
    required this.fadeOnly,
    required this.child,
  });

  final Animation<double> animation;
  final bool fadeOnly;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = FadeTransition(opacity: animation, child: child);
    if (fadeOnly) return fade;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        scale: Tween(begin: 0.97, end: 1.0).animate(curved),
        child: fade,
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({super.key, required this.toast, required this.controller});

  final ToastMessage toast;
  final ToastController controller;

  (IconData, Color) get _icon => switch (toast.kind) {
    _ when toast.hasAction => (Icons.undo_rounded, AppColors.training),
    ToastKind.success => (Icons.check_circle_rounded, AppColors.training),
    ToastKind.warning => (Icons.error_outline_rounded, AppColors.warning),
    ToastKind.info => (Icons.info_outline_rounded, AppColors.textSecondary),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _icon;
    final actionLabel = toast.actionLabel;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Dismissible(
        key: ValueKey(toast.id),
        onDismissed: (_) => controller.dismiss(toast.id),
        child: ChromeSurface(
          radius: _radius,
          tint: AppColors.surfaceRaised,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              actionLabel == null ? AppSpacing.md : AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: _minHeight - AppSpacing.sm * 2,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: iconColor, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          toast.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (actionLabel != null)
                        TextButton(
                          onPressed: controller.runAction,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.training,
                            minimumSize: const Size(48, 44),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(actionLabel),
                        ),
                    ],
                  ),
                ),
                if (toast.hasAction && !controller.keepsActionableToasts)
                  _UndoCountdown(duration: toast.duration),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin bar and remaining seconds for an undo window. Kept out of the
/// semantics tree so screen readers are not told every second.
class _UndoCountdown extends StatefulWidget {
  const _UndoCountdown({required this.duration});

  final Duration duration;

  @override
  State<_UndoCountdown> createState() => _UndoCountdownState();
}

class _UndoCountdownState extends State<_UndoCountdown>
    with SingleTickerProviderStateMixin {
  late final _elapsed = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.xs,
          right: AppSpacing.xs,
        ),
        child: AnimatedBuilder(
          animation: _elapsed,
          builder: (context, _) {
            final remaining = 1 - _elapsed.value;
            final seconds = (remaining * widget.duration.inSeconds).ceil();
            return Row(
              children: [
                Expanded(child: ProgressLine(progress: remaining, height: 3)),
                const SizedBox(width: AppSpacing.xs),
                Text('${seconds}s', style: AppTextStyles.caption),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Marks floating bottom chrome (dock, floating footers) so toasts float
/// above it. Only the current route's chrome counts: a page pushed on top
/// hides the dock underneath.
class ToastObstruction extends SingleChildRenderObjectWidget {
  const ToastObstruction({super.key, required super.child});

  bool _isOnCurrentRoute(BuildContext context) =>
      ModalRoute.of(context)?.isCurrent ?? true;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderToastObstruction(
        controller: ToastScope.read(context),
        isActive: _isOnCurrentRoute(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderToastObstruction renderObject,
  ) {
    renderObject
      ..controller = ToastScope.read(context)
      ..isActive = _isOnCurrentRoute(context);
  }
}

/// Reports its global top edge whenever it paints, which also covers
/// animations (the dock shrinking) that never rebuild the widget.
class RenderToastObstruction extends RenderProxyBox {
  RenderToastObstruction({required this.controller, required this._isActive});

  ToastController controller;
  bool _isActive;
  double? _reportedTop;

  set isActive(bool value) {
    if (_isActive == value) return;
    _isActive = value;
    if (value) {
      markNeedsPaint();
    } else {
      _report(null);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_isActive) _report(localToGlobal(Offset.zero).dy);
  }

  @override
  void detach() {
    _report(null);
    super.detach();
  }

  void _report(double? top) {
    if (top == _reportedTop) return;
    _reportedTop = top;
    // Listeners rebuild, which is not allowed during paint or teardown.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => controller.reportObstruction(this, _reportedTop),
    );
  }
}
