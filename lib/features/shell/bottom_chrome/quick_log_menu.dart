import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../record/record_options.dart';
import 'chrome_metrics.dart';
import 'press_feedback.dart';
import 'split_dock.dart';
import '../../../shared/haptics.dart';

const _menuDuration = Duration(milliseconds: 280);

const _staggerStep = 0.12;
const _itemSpacing = 10.0;
const _itemHeight = 52.0;

/// How far the app sinks back behind the menu. Deliberately lighter than a
/// real sheet (~0.92): the user is picking an action, not leaving the page.
/// A Flutter-drawn scale also cannot move the system status bar, so a bigger
/// step would look detached from it.
const _recessScale = 0.975;
const _recessDimIOS = 0.42;

/// A light blur, so the page reads as out of focus behind the menu yet
/// still shows where the user is. Stronger (Control Center territory)
/// would lose that context and cost too much at 120 Hz.
const _recessBlurSigma = 8.0;

/// Material's FAB menu does not push content back, so Android only dims.
const _recessDimAndroid = 0.32;

const quickLogMenuKey = ValueKey('quick-log-menu');

/// Staggered action list that grows out of the dock's「+」, offering every
/// record type whose module is switched on. A second, fuller list behind
/// a「更多」would only have held the same things one tap further away.
///
/// [recess] is pointed at the menu's animation so [QuickLogScrim] and
/// [QuickLogRecess] can push the app back in step with the menu.
Future<void> showQuickLogMenu(
  BuildContext context, {
  required ProxyAnimation recess,
}) {
  final route = RawDialogRoute<void>(
    barrierDismissible: true,
    barrierLabel: '關閉快速記錄',
    // The recessed app carries the dimming.
    barrierColor: Colors.transparent,
    transitionDuration: chromeDuration(context, _menuDuration),
    pageBuilder: (_, animation, _) => _QuickLogMenu(animation: animation),
    // No route-wide fade: the items stagger in on their own, and × must be
    // fully there the moment the dock's「+」hides under it. Closing plays
    // the same animation backwards, so the menu folds back into 「+」.
    transitionBuilder: (_, _, _, child) => child,
  );
  final future = Navigator.of(context).push(route);
  recess.parent = route.animation;
  return future;
}

/// Dims and softly blurs the whole app, dock included, while the quick-log
/// menu is open, so the menu is the only thing in focus.
class QuickLogScrim extends StatelessWidget {
  const QuickLogScrim({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isIOS =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final dim = isIOS ? _recessDimIOS : _recessDimAndroid;
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      // The tree shape never changes with the animation, so the app keeps
      // its state; the filter is only switched on while it has an effect.
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(animation.value);
        final sigma = _recessBlurSigma * t;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Filters the app itself rather than a full-screen backdrop,
            // which Flutter documents as the cheaper way to blur a subtree.
            ImageFiltered(
              enabled: t > 0,
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: child,
            ),
            IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: dim * t)),
            ),
          ],
        );
      },
    );
  }
}

/// Pushes page content back while the quick-log menu is open. Only the
/// content shrinks: the page background still fills the screen and the
/// dock keeps its size. iOS only, and not with Reduce Motion.
class QuickLogRecess extends StatelessWidget {
  const QuickLogRecess({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final scales =
        (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) &&
        !prefersReducedMotion(context);
    // The tree shape never changes with the animation, so pages keep their
    // state while the menu opens and closes.
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.scale(
        scale: scales
            ? lerpDouble(
                1,
                _recessScale,
                Curves.easeOutCubic.transform(animation.value),
              )!
            : 1,
        child: child,
      ),
    );
  }
}

class _QuickLogMenu extends StatelessWidget {
  const _QuickLogMenu({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final options = enabledRecordOptions(context);
    final metrics = DockMetrics.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: metrics.bottomOffset(context, isMinimized: false),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          key: quickLogMenuKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrolls only when a short screen or large text cannot fit
            // every type; reversed so the ones nearest the thumb show.
            Flexible(
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < options.length; i++)
                      _Staggered(
                        animation: animation,
                        // Items nearest the button appear first.
                        order: options.length - 1 - i,
                        child: _MenuItem(
                          icon: options[i].icon,
                          color: options[i].color,
                          label: options[i].title,
                          onTap: () => openRecordOption(context, options[i]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Each item already carries the gap below it, so × sits the
            // same distance from the last type as the pills do from each
            // other.
            _CloseButton(animation: animation, size: metrics.height),
          ],
        ),
      ),
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.order,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = math.min(order * _staggerStep, 0.6);
    // Leaving is the arrival played backwards, stagger included.
    final moved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: ChromeMetrics.morphCurve),
      reverseCurve: Interval(start, 1, curve: ChromeMetrics.morphCurve),
    );
    // The movement overshoots on purpose; opacity cannot, so it runs on
    // its own curve.
    final faded = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: ChromeMetrics.fadeCurve),
      reverseCurve: Interval(start, 1, curve: ChromeMetrics.fadeCurve),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: _itemSpacing),
      child: FadeTransition(
        opacity: faded,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(moved),
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(moved),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceRaised,
      shape: const StadiumBorder(),
      // With only a light scrim, a shadow keeps the pills above the page.
      elevation: 8,
      shadowColor: Colors.black,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppHaptics.tap();
          onTap();
        },
        child: SizedBox(
          height: _itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(label, style: AppTextStyles.itemTitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sits exactly where「+」was and turns into ×.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.animation, required this.size});

  final Animation<double> animation;

  /// Matches the expanded dock's「+」so × covers it exactly.
  final double size;

  @override
  Widget build(BuildContext context) {
    void close() {
      AppHaptics.tap();
      Navigator.of(context).pop();
    }

    return Semantics(
      button: true,
      label: '關閉',
      onTap: close,
      excludeSemantics: true,
      child: Tooltip(
        message: '關閉',
        excludeFromSemantics: true,
        // Squeezes like the「+」it replaces.
        child: PressScale(
          pressedScale: ChromeMetrics.actionPressedScale,
          child: SizedBox.square(
            dimension: size,
            child: CenterActionSurface(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: close,
                child: Center(
                  // Turns into × well before the items finish arriving.
                  child: RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.125).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(
                          0,
                          0.45,
                          curve: Curves.easeOutCubic,
                        ),
                        // Closing turns it back first, too.
                        reverseCurve: const Interval(
                          0.55,
                          1,
                          curve: Curves.easeInCubic,
                        ),
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      size: DockMetrics.of(context).actionIconSize,
                      color: CenterActionSurface.foreground,
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
