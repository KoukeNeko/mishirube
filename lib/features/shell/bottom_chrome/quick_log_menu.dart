import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../app/theme.dart';
import '../../../domain/domain.dart';
import '../../../shared/widgets/chrome/chrome_surface.dart';
import '../../../shared/window_layout.dart';
import '../../record/record_options.dart';
import 'chrome_metrics.dart';
import 'press_feedback.dart';
import 'split_dock.dart';
import '../../../shared/haptics.dart';
import '../../../l10n/l10n.dart';

/// Long enough for the panel to be seen growing out of the「+」.
const _menuDuration = Duration(milliseconds: 400);

/// Between the panel and the ×.
const _panelGap = 10.0;

/// The panel's corner is a tile's corner plus the inset the tiles keep from
/// its edge, so the two curves run concentric.
const _tileRadius = AppRadius.small;
const _panelPadding = AppSpacing.sm;
const _panelRadius = _tileRadius + _panelPadding;
const _tileGap = AppSpacing.xs;

/// What a tile keeps clear of its edges, sideways.
const _tileInset = AppSpacing.xxs;

/// The smallest the panel is drawn, so it never has no size at all.
const _minScale = 0.02;

/// How much the panel's glass is tinted. More than the dock's, which has
/// short labels over a page it knows; up to eleven tiles are read over
/// whatever the page behind happens to hold.
const _panelTintOpacity = 0.5;

/// One row of the panel: the categories it holds, how many tiles stand
/// side by side, and whether they are the larger kind.
typedef _PanelRow = ({Set<RecordCategory> categories, int columns, bool large});

/// The panel's rows from the top to the one nearest the thumb. A row takes
/// whole categories, so a category is never split between two rows. What
/// is done through the day (a session, a meal, a drink) gets the larger
/// tiles at the bottom; the readings of the body and the states above it
/// are a short reach further.
const _rows = <_PanelRow>[
  (categories: {RecordCategory.wellness}, columns: 3, large: false),
  (categories: {RecordCategory.body}, columns: 3, large: false),
  (
    categories: {
      RecordCategory.training,
      RecordCategory.activity,
      RecordCategory.nutrition,
    },
    columns: 4,
    large: true,
  ),
];

/// How far the app sinks back behind the menu. Deliberately lighter than a
/// real sheet (~0.92): the user is picking an action, not leaving the page.
/// A Flutter-drawn scale also cannot move the system status bar, so a bigger
/// step would look detached from it.
const _recessScale = 0.975;
const _recessDimIOS = 0.42;

/// Material's FAB menu does not push content back, so Android only dims.
const _recessDimAndroid = 0.32;

const quickLogMenuKey = ValueKey('quick-log-menu');

/// The glass the tiles sit on.
const quickLogPanelKey = ValueKey('quick-log-panel');

/// A panel of tiles that comes up out of the dock's「+」, one for every
/// record type whose module is switched on. A second, fuller list behind
/// a「更多」would only have held the same things one tap further away.
///
/// [recess] is pointed at the menu's animation so [QuickLogScrim] and
/// [QuickLogRecess] can push the app back in step with the menu.
///
/// [width] is the main pane's when the window shows two, since the dock and
/// its「+」are in that pane rather than across the whole window.
///
/// [onOpen] opens the page an option leads to: beside the list when there
/// are two panes, since the menu sits above the shell and cannot see them.
Future<void> showQuickLogMenu(
  BuildContext context, {
  required ProxyAnimation recess,
  required void Function(Widget page) onOpen,
  double? width,
}) {
  final route = RawDialogRoute<void>(
    barrierDismissible: true,
    barrierLabel: context.l10n.quickLogClose,
    // The recessed app carries the dimming.
    barrierColor: Colors.transparent,
    transitionDuration: chromeDuration(context, _menuDuration),
    pageBuilder: (_, animation, _) => width == null
        ? _QuickLogMenu(animation: animation, onOpen: onOpen)
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: width,
              child: _QuickLogMenu(animation: animation, onOpen: onOpen),
            ),
          ),
    // No route-wide fade: the panel arrives through its own transition, and
    // × must be fully there the moment the dock's「+」hides under it.
    // Closing plays the same animation backwards, so the panel folds back
    // into 「+」.
    transitionBuilder: (_, _, _, child) => child,
  );
  final future = Navigator.of(context).push(route);
  recess.parent = route.animation;
  return future;
}

/// Dims the whole app, dock included, while the quick-log menu is open, so
/// the menu is the only thing in focus. The app is not blurred as well:
/// the panel is glass and does that for what is under it.
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
      // Only the dimming changes with the animation, so the app is kept
      // from painting again for it.
      child: RepaintBoundary(child: child),
      // The tree shape never changes with the animation, so the app keeps
      // its state.
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(animation.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
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
  const _QuickLogMenu({required this.animation, required this.onOpen});

  final Animation<double> animation;
  final void Function(Widget page) onOpen;

  @override
  Widget build(BuildContext context) {
    final options = enabledRecordOptions(context);
    final metrics = DockMetrics.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The panel spans the dock, edge to edge.
        final column = contentColumnInsets(
          context,
          constraints.maxWidth,
          maxWidth: ChromeMetrics.dockMaxWidth,
        );
        final inset = metrics.insetFor(isMinimized: false);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            column.left + inset,
            0,
            column.right + inset,
            metrics.bottomOffset(context, isMinimized: false),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              key: quickLogMenuKey,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: _Panel(
                      animation: animation,
                      options: options,
                      onOpen: onOpen,
                      originSize: metrics.height,
                    ),
                  ),
                ),
                const SizedBox(height: _panelGap),
                _CloseButton(animation: animation, size: metrics.height),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The panel: glass that grows out of the「+」, and the tiles on it.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.animation,
    required this.options,
    required this.onOpen,
    required this.originSize,
  });

  final Animation<double> animation;
  final List<RecordOption> options;
  final void Function(Widget page) onOpen;

  /// The size of the「+」it grows out of.
  final double originSize;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final spec in _rows)
        (
          spec: spec,
          options: [
            for (final option in options)
              if (spec.categories.contains(option.category)) option,
          ],
        ),
    ].where((row) => row.options.isNotEmpty).toList();
    final tiles = Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        // Scrolls only when a short screen or large text cannot fit every
        // type; reversed so the rows nearest the thumb show.
        reverse: true,
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, row) in rows.indexed) ...[
              // A larger row stands a little apart, as a group does.
              if (i > 0)
                SizedBox(height: row.spec.large ? _panelPadding : _tileGap),
              _TileRow(
                options: row.options,
                columns: row.spec.columns,
                large: row.spec.large,
                onOpen: onOpen,
              ),
            ],
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      child: tiles,
      builder: (context, tiles) {
        // Growing, the panel is a spring, which starts slowly enough to be
        // seen leaving the「+」; going back it is drawn in.
        final scale =
            (animation.status == AnimationStatus.reverse
                    ? Curves.easeInCubic
                    : const _GrowthCurve())
                .transform(animation.value);
        // The tiles are there once the panel is big enough to hold them.
        final shown = ((scale - 0.3) / 0.4).clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _GrowingGlass(scale: scale, originSize: originSize),
            ),
            // The tiles size the stack, and the glass is as big as they are.
            // Scaled about the「+」like the glass, so they grow with it.
            Transform.translate(
              offset: Offset(0, (_panelGap + originSize / 2) * (1 - scale)),
              child: Transform.scale(
                scale: math.max(scale, _minScale),
                alignment: Alignment.bottomCenter,
                child: Opacity(opacity: shown, child: tiles),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The panel's glass: the panel as it is, scaled about the「+」, so it
/// grows out of the button and the button's top is where it is born. It is
/// laid out afresh each frame rather than scaled or faded, which glass
/// cannot be ([ChromeSurface]).
class _GrowingGlass extends StatelessWidget {
  const _GrowingGlass({required this.scale, required this.originSize});

  final double scale;
  final double originSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panel = Offset.zero & constraints.biggest;
        // The「+」is centred below the panel, a gap and half its size.
        final origin = Offset(
          panel.center.dx,
          panel.bottom + _panelGap + originSize / 2,
        );
        final s = math.max(scale, _minScale);
        Offset scaled(Offset point) => origin + (point - origin) * s;
        final rect = Rect.fromPoints(
          scaled(panel.topLeft),
          scaled(panel.bottomRight),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: rect,
              child: ChromeSurface(
                key: quickLogPanelKey,
                refracts: true,
                // A disc while it is small, the panel's corner when it is not.
                radius: lerpDouble(
                  rect.shortestSide / 2,
                  _panelRadius,
                  s.clamp(0.0, 1.0),
                )!,
                tintOpacity: _panelTintOpacity,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The chrome's spring, with a hint of overshoot, as a curve over the
/// route's animation, so the panel's growth can be driven by it.
class _GrowthCurve extends Curve {
  const _GrowthCurve();

  static final _spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 400),
    bounce: 0.25,
  );

  /// How many seconds of the spring one run of the route plays.
  static final _seconds = _menuDuration.inMilliseconds / 1000;

  @override
  double transformInternal(double t) =>
      SpringSimulation(_spring, 0, 1, 0).x(t * _seconds);
}

/// A row of tiles of one width, [columns] to a line. A line with fewer
/// leaves the rest of it empty instead of stretching what is there.
class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.options,
    required this.columns,
    required this.large,
    required this.onOpen,
  });

  final List<RecordOption> options;
  final int columns;
  final bool large;
  final void Function(Widget page) onOpen;

  @override
  Widget build(BuildContext context) {
    // A tile's width is told to its label, which cannot ask for it from
    // under the IntrinsicHeight.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - _tileGap * (columns - 1)) / columns;
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: _tileGap,
          children: [
            for (var first = 0; first < options.length; first += columns)
              // A tile as tall as the tallest beside it, as a label that
              // wraps makes one.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _tileGap,
                  children: [
                    for (var i = first; i < first + columns; i++)
                      Expanded(
                        child: i < options.length
                            ? _Tile(
                                option: options[i],
                                large: large,
                                width: tileWidth,
                                onTap: () => openRecordOption(
                                  context,
                                  options[i],
                                  onOpen,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.option,
    required this.large,
    required this.width,
    required this.onTap,
  });

  final RecordOption option;
  final bool large;

  /// How wide the tile is, for its label.
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = option.title(context.l10n);
    final detail = option.detail?.call(context);
    void tap() {
      AppHaptics.tap();
      onTap();
    }

    return Semantics(
      button: true,
      label: [title, ?detail].join(' '),
      onTap: tap,
      excludeSemantics: true,
      // Squeezes like the dock's tabs.
      child: PressScale(
        pressedScale: ChromeMetrics.tabPressedScale,
        // A faint patch of the same glass, as the dock's selection lens is.
        child: Material(
          color: Colors.white.withValues(alpha: ChromeMetrics.lensFillOpacity),
          borderRadius: BorderRadius.circular(_tileRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: large ? 84 : 64),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _tileInset,
                  vertical: large ? AppSpacing.sm : AppSpacing.xs + 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option.icon,
                      color: option.color,
                      size: large ? 26 : 22,
                    ),
                    SizedBox(height: large ? 6 : AppSpacing.xxs),
                    // The amount shares the label's line, so every tile in a
                    // row keeps its icon and label at one height.
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xxs,
                      children: [
                        _TileLabel(
                          title,
                          maxWidth: width - 2 * _tileInset,
                          style: AppTextStyles.itemTitle.copyWith(
                            fontSize: large ? 14 : 13,
                            height: 1.25,
                          ),
                        ),
                        if (detail != null)
                          Text(
                            detail,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile's label: on one line, a little smaller if that is all it takes,
/// wrapped when it would take more. A label one character too long would
/// otherwise leave that character alone on a second line.
class _TileLabel extends StatelessWidget {
  const _TileLabel(this.text, {required this.maxWidth, required this.style});

  final String text;
  final double maxWidth;
  final TextStyle style;

  /// The smallest a label shrinks to before it wraps instead.
  static const _minScale = 0.85;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final scale = painter.width == 0 ? 1.0 : maxWidth / painter.width;
    painter.dispose();
    if (scale >= 1 || scale < _minScale) {
      return Text(text, textAlign: TextAlign.center, style: style);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, style: style),
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
      label: context.l10n.commonClose,
      onTap: close,
      excludeSemantics: true,
      child: Tooltip(
        message: context.l10n.commonClose,
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
                  // Turns into × well before the panel finishes arriving.
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
