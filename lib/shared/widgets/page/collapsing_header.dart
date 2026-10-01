import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show ProgressiveBlur;

import '../../../app/theme.dart';
import '../../motion.dart';
import '../../window_controls.dart';
import '../../window_layout.dart';
import '../chrome/chrome_surface.dart';
import '../controls/inputs.dart';
import '../controls/pill.dart';

const _blurSigma = 24.0;
const _glassOpacity = 0.72;
const _largeTopPadding = 4.0;
const _largeBottomPadding = 4.0;

/// Breathing room between the (collapsed) bar and the first card; matches
/// the prototype's title-to-card rhythm.
const _contentTopGap = AppSpacing.md;

/// The gap between a page's elements, and between a section's label and
/// its items ([PageSection]).
const pageItemSpacing = AppSpacing.sm;
const _snapDuration = Duration(milliseconds: 220);
const _subtitleGap = 2.0;
const _subtitleMaxLines = 2;

/// A record's name is the title of its page and can be long; the compact
/// bar still keeps it to one line.
const _titleMaxLines = 2;
const _pinnedVerticalPadding = 8.0;

/// Progress (0–1) after which the compact title replaces the large one.
const _titleSwapPoint = 0.5;
const _compactFadeStart = 0.6;

const largeTitleStyle = AppTextStyles.screenTitle;
final largeSubtitleStyle = AppTextStyles.caption.copyWith(fontSize: 14);

/// iOS headline: 17pt semibold on a 22pt line.
const compactTitleStyle = TextStyle(
  fontSize: 17,
  fontWeight: FontWeight.w600,
  height: 22 / 17,
  color: AppColors.textPrimary,
);

/// Top bar geometry per platform.
class ToolbarMetrics {
  const ToolbarMetrics._({
    required this.height,
    required this.controlRowHeight,
    required this.actionVisualSize,
    required this.actionHitSize,
  });

  /// iOS 27: a 44pt control row directly under the safe area plus 10pt of
  /// space below it. Centring the row in the full 54pt would push it down.
  static const ios = ToolbarMetrics._(
    height: 54,
    controlRowHeight: 44,
    actionVisualSize: 44,
    actionHitSize: 44,
  );

  /// Material top app bar: 56dp with centred contents, 48dp touch targets.
  static const android = ToolbarMetrics._(
    height: 56,
    controlRowHeight: 56,
    actionVisualSize: 40,
    actionHitSize: 48,
  );

  static ToolbarMetrics of(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? ios
        : android;
  }

  final double height;
  final double controlRowHeight;
  final double actionVisualSize;
  final double actionHitSize;
}

/// Laid-out height of [text] with the ambient font and the user's text size.
double measureTextHeight(
  BuildContext context,
  String text,
  TextStyle style, {
  required double maxWidth,
  int maxLines = 1,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
    // The first frame can be laid out at zero width (e.g. launched with
    // the screen off), leaving a negative width once gutters are taken.
  )..layout(maxWidth: math.max(0, maxWidth));
  final height = painter.height;
  painter.dispose();
  return height;
}

/// Space between the top of the pinned slot and its control, for a slot of
/// [slotHeight] holding a control [measured] as in [pinnedSlotHeight].
double pinnedControlTopInset({
  required double measured,
  required double slotHeight,
  required ToolbarMetrics toolbar,
  required bool isBar,
}) {
  if (!isBar) return _pinnedVerticalPadding;
  final control = measured - _pinnedVerticalPadding * 2;
  final row = slotHeight - (toolbar.height - toolbar.controlRowHeight);
  return (row - control) / 2;
}

/// Bottom padding of the large title block. Above a pinned control it tops
/// up the control's own inset to the content gap; that space collapses with
/// the title, so a pinned row acting as the bar keeps the bar's layout.
double largeTitleBottomPadding({double? pinnedTopInset}) {
  if (pinnedTopInset == null) return _largeBottomPadding;
  return math.max(0, _contentTopGap - pinnedTopInset);
}

/// Height of the large title block, measured with the user's text size so
/// Dynamic Type grows the header instead of overflowing it.
double measureLargeTitleHeight(
  BuildContext context, {
  required String title,
  required double maxWidth,
  String? subtitle,
  double bottomPadding = _largeBottomPadding,
}) {
  final titleHeight = measureTextHeight(
    context,
    title,
    largeTitleStyle,
    maxWidth: maxWidth,
    maxLines: _titleMaxLines,
  );
  final subtitleHeight = subtitle == null
      ? 0.0
      : _subtitleGap +
            measureTextHeight(
              context,
              subtitle,
              largeSubtitleStyle,
              maxWidth: maxWidth,
              maxLines: _subtitleMaxLines,
            );
  return _largeTopPadding + titleHeight + subtitleHeight + bottomPadding;
}

/// Height of a pinned row holding a [SegmentedChoice]-style control.
double measurePinnedControlHeight(BuildContext context) {
  return pillHeight(context) + _pinnedVerticalPadding * 2;
}

/// Height of a pinned row holding something [content] tall.
double measurePinnedHeight(double content) =>
    content + _pinnedVerticalPadding * 2;

/// Height of a pinned row holding a [SearchField].
double measurePinnedSearchHeight() =>
    searchFieldHeight + _pinnedVerticalPadding * 2;

/// Height of the pinned slot, given its [measured] height (control plus the
/// normal vertical padding). Without a compact bar the pinned row *is* the
/// bar at its smallest, so it takes the toolbar's height and layout and only
/// grows when large text needs it.
double pinnedSlotHeight({
  required double measured,
  required ToolbarMetrics toolbar,
  required bool isBar,
}) {
  if (!isBar) return measured;
  final control = measured - _pinnedVerticalPadding * 2;
  return math.max(
    toolbar.height,
    control + toolbar.height - toolbar.controlRowHeight,
  );
}

/// A page header that starts as content (large title) and collapses into a
/// compact toolbar. The toolbar only turns into glass once content scrolls
/// beneath it, like iOS scroll-edge effects.
class CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  CollapsingHeaderDelegate({
    required this.toolbar,
    required this.topInset,
    required this.largeHeight,
    required this.large,
    required this.compactTitle,
    this.leading,
    this.actions = const [],
    this.pinned,
    this.pinnedHeight = 0,
    this.pinnedMeetsContent = false,
    this.hideToolbarFraction = 0,
    this.scrollsToolbarAway = false,
    this.glassOpacity,
    this.isHighContrast = false,
    this.reduceMotion = false,
  });

  final ToolbarMetrics toolbar;
  final double topInset;
  final double largeHeight;
  final Widget large;
  final Widget compactTitle;
  final Widget? leading;
  final List<Widget> actions;
  final Widget? pinned;
  final double pinnedHeight;

  /// Whether the pinned row sits tight between the bar and the content,
  /// with no space round it: a calendar's weekdays, right under the bar
  /// where a week strip has its own, and straight on the grid.
  final bool pinnedMeetsContent;

  /// 0 shows the compact toolbar; 1 tucks it away (auto-hide while reading).
  final double hideToolbarFraction;

  /// No compact bar: once the large title has gone the toolbar row scrolls
  /// away too, leaving only the pinned control (if any) and the status bar.
  final bool scrollsToolbarAway;

  /// The glass, from the page instead of the collapse: for a page drawn
  /// over a picture (a workout's map), whose bar stays clear until the
  /// page itself runs under it, which only the page can tell.
  final ValueListenable<double>? glassOpacity;
  final bool isHighContrast;
  final bool reduceMotion;

  double get _visibleToolbarHeight =>
      toolbar.height * (1 - hideToolbarFraction);

  @override
  double get minExtent =>
      topInset +
      (scrollsToolbarAway ? 0 : _visibleToolbarHeight) +
      pinnedHeight;

  /// How far the header shrinks before it stops, i.e. the range to snap in.
  double get collapseRange =>
      largeHeight + (scrollsToolbarAway ? toolbar.height : 0);

  @override
  double get maxExtent =>
      topInset + toolbar.height + largeHeight + pinnedHeight;

  double _progress(double shrinkOffset) {
    if (largeHeight <= 0) return 1;
    final progress = (shrinkOffset / largeHeight).clamp(0.0, 1.0);
    if (!reduceMotion) return progress;
    return progress < _titleSwapPoint ? 0 : 1;
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = _progress(shrinkOffset);
    final chromeOpacity = overlapsContent ? 1.0 : progress;
    final showsCompactTitle =
        !scrollsToolbarAway && progress >= _titleSwapPoint;
    // The large title goes first, then (without a compact bar) the toolbar.
    final toolbarHeight = scrollsToolbarAway
        ? (toolbar.height -
              (shrinkOffset - largeHeight).clamp(0.0, toolbar.height))
        : _visibleToolbarHeight;
    final toolbarOpacity = scrollsToolbarAway
        ? toolbarHeight / toolbar.height
        : 1 - hideToolbarFraction;
    final compactOpacity =
        ((progress - _compactFadeStart) / (1 - _compactFadeStart)).clamp(
          0.0,
          1.0,
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (glassOpacity case final glass?)
          ValueListenableBuilder(
            valueListenable: glass,
            builder: (context, opacity, _) => _HeaderBackground(
              opacity: opacity,
              isHighContrast: isHighContrast,
            ),
          )
        else
          _HeaderBackground(
            opacity: chromeOpacity,
            isHighContrast: isHighContrast,
          ),
        _ContentColumn(
          child: Column(
            // Stretch so the large title can sit at the leading edge.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topInset),
              SizedBox(
                height: toolbarHeight,
                child: _InColumn(
                  child: ClipRect(
                    // Sliding away, the bar passes under the status bar like
                    // scrolled content; a clip here would cut it off at the
                    // inset. Tucking away (auto-hide) it must not cover the
                    // title below.
                    clipBehavior: scrollsToolbarAway
                        ? Clip.none
                        : Clip.hardEdge,
                    child: Opacity(
                      opacity: toolbarOpacity,
                      // The control row hangs from the top of the bar; on iOS
                      // the bar's extra height is space below it. Scrolling
                      // away, the whole bar slides up under the status bar, so
                      // that space stays between the actions and the pinned
                      // control instead of the control eating into the actions.
                      child: OverflowBox(
                        alignment: scrollsToolbarAway
                            ? Alignment.bottomCenter
                            : Alignment.topCenter,
                        minHeight: toolbar.height,
                        maxHeight: toolbar.height,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: toolbar.controlRowHeight,
                            child: _Toolbar(
                              leading: leading,
                              actions: actions,
                              title: ExcludeSemantics(
                                excluding: !showsCompactTitle,
                                child: Semantics(
                                  header: true,
                                  child: Opacity(
                                    opacity: scrollsToolbarAway
                                        ? 0
                                        : compactOpacity,
                                    child: compactTitle,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _InColumn(
                  child: ClipRect(
                    // Bottom-aligned so shrinking reads as the title scrolling up.
                    child: OverflowBox(
                      alignment: AlignmentDirectional.bottomStart,
                      minHeight: largeHeight,
                      maxHeight: largeHeight,
                      child: ExcludeSemantics(
                        excluding: showsCompactTitle,
                        child: Opacity(
                          opacity: (1 - progress / _titleSwapPoint).clamp(
                            0.0,
                            1.0,
                          ),
                          child: large,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (pinned != null)
                SizedBox(
                  height: pinnedHeight,
                  // As the bar, the control sits where toolbar controls do:
                  // in the control row, with the bar's extra space below.
                  // Horizontal spacing is the pinned element's own (see
                  // Gutter), not the slot's.
                  child: Padding(
                    padding: scrollsToolbarAway
                        ? EdgeInsets.only(
                            bottom: toolbar.height - toolbar.controlRowHeight,
                          )
                        : pinnedMeetsContent
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            vertical: _pinnedVerticalPadding,
                          ),
                    child: scrollsToolbarAway ? Center(child: pinned) : pinned,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // Every input can change per frame (text size, hide animation), and
  // rebuilding a header is cheap.
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

/// The page's content column for what sits on the header's full-width
/// glass: the title and controls keep to it (see [_InColumn]), and a
/// pinned row lays itself out by it (see `Gutter`).
class _ContentColumn extends StatelessWidget {
  const _ContentColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => PageColumn(
        insets: contentColumnInsets(context, constraints.maxWidth),
        child: child,
      ),
    );
  }
}

/// Keeps the title and toolbar to the content column, so they line up with
/// the cards below them.
class _InColumn extends StatelessWidget {
  const _InColumn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: PageColumn.of(context), child: child);
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({
    required this.opacity,
    required this.isHighContrast,
  });

  final double opacity;
  final bool isHighContrast;

  @override
  Widget build(BuildContext context) {
    return ScrollEdgeGlass(opacity: opacity);
  }
}

/// Frosted layer shown behind top chrome while content scrolls beneath it,
/// with a hairline at its lower edge. "Increase Contrast" makes it opaque.
class ScrollEdgeGlass extends StatelessWidget {
  const ScrollEdgeGlass({super.key, required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    final isHighContrast = MediaQuery.highContrastOf(context);
    final tint = AppColors.background.withValues(
      alpha: isHighContrast ? opacity : opacity * _glassOpacity,
    );
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        border: Border(
          bottom: BorderSide(
            color: AppColors.outline.withValues(alpha: opacity),
          ),
        ),
      ),
    );
    if (isHighContrast) return surface;
    return ClipRect(
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: surface,
      ),
    );
  }
}

/// A frost behind [child] that is strongest at its top edge and fades
/// to nothing at its bottom, for a header a list scrolls under: what
/// passes beneath melts away rather than ending on a hard line.
/// "Increase Contrast" makes it opaque.
class _FadingEdgeGlass extends StatelessWidget {
  const _FadingEdgeGlass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.highContrastOf(context)) {
      return ColoredBox(color: AppColors.background, child: child);
    }
    return Stack(
      children: [
        const Positioned.fill(child: ProgressiveBlur(maxSigma: _blurSigma)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: _glassOpacity),
                  AppColors.background.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _Toolbar extends StatefulWidget {
  const _Toolbar({
    required this.title,
    required this.leading,
    required this.actions,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  final _search = ValueNotifier<double>(0);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leading = widget.leading;
    final actions = widget.actions;
    // Like page content, the bar adds no inset of its own: each slot keeps
    // its distance from the screen edge, the same 20pt gutter as the page.
    //
    // The title is centred on the bar rather than in the space left over,
    // so it stays put however many actions a page has. It gives way when
    // the sides need the room.
    return LayoutBuilder(
      builder: (context, constraints) => ToolbarWidth(
        width: constraints.maxWidth,
        child: ToolbarSearch(
          notifier: _search,
          child: NavigationToolbar(
            centerMiddle: true,
            middleSpacing: AppSpacing.sm,
            leading: leading == null
                ? null
                : Padding(
                    // The control is a glass pill like the actions opposite it,
                    // so its edge keeps the same gutter as theirs, past any
                    // window controls in the corner.
                    padding: EdgeInsetsDirectional.only(
                      start:
                          AppSpacing.screenGutter +
                          WindowControls.leadingInsetOf(context),
                    ),
                    // A search opening across the bar pushes it off the
                    // leading edge, as it does the actions beside it.
                    child: ValueListenableBuilder(
                      valueListenable: _search,
                      builder: (context, opened, child) => IgnorePointer(
                        ignoring: opened > 0,
                        child: ExcludeSemantics(
                          excluding: opened > 0,
                          child: Opacity(
                            opacity: 1 - opened,
                            child: FractionalTranslation(
                              translation: Offset(-1.5 * opened, 0),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      child: leading,
                    ),
                  ),
            middle: widget.title,
            trailing: actions.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++)
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: AppSpacing.xs,
                            end: i == actions.length - 1
                                ? AppSpacing.screenGutter
                                : 0,
                          ),
                          child: actions[i],
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// How far a search field in the toolbar has opened, from 0 to 1, for
/// the slot across from it to make way.
class ToolbarSearch extends InheritedNotifier<ValueNotifier<double>> {
  const ToolbarSearch({
    super.key,
    required ValueNotifier<double> super.notifier,
    required super.child,
  });

  /// The bar's, without rebuilding with it; null outside a toolbar.
  static ValueNotifier<double>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ToolbarSearch>()?.notifier;
}

/// How wide the toolbar is, for an action that grows across it (a search
/// field). The actions sit in a row that gives them no width to measure,
/// and the window is the wrong answer: beside a rail, in a list pane or
/// beside a fold the bar is narrower than the screen.
class ToolbarWidth extends InheritedWidget {
  const ToolbarWidth({super.key, required this.width, required super.child});

  final double width;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolbarWidth>()!.width;

  @override
  bool updateShouldNotify(ToolbarWidth oldWidget) => width != oldWidget.width;
}

/// Large title + subtitle block shown before the header collapses.
class LargeTitleBlock extends StatelessWidget {
  const LargeTitleBlock({
    super.key,
    required this.title,
    this.subtitle,
    this.bottomPadding = _largeBottomPadding,
  });

  final String title;
  final String? subtitle;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        _largeTopPadding,
        AppSpacing.screenGutter,
        bottomPadding,
      ),
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: _titleMaxLines,
              overflow: TextOverflow.ellipsis,
              style: largeTitleStyle,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: _subtitleGap),
              Text(
                subtitle!,
                maxLines: _subtitleMaxLines,
                overflow: TextOverflow.ellipsis,
                style: largeSubtitleStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Toolbar action: a glass pill (icon, optional short label) centred in a
/// platform-sized touch target (see [ToolbarMetrics]).
class HeaderAction extends StatelessWidget {
  const HeaderAction({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final metrics = ToolbarMetrics.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      // Excluding the child's semantics drops its tap too.
      onTap: onTap,
      excludeSemantics: true,
      // Taps on the margin around the pill still count.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: metrics.actionHitSize,
            minHeight: metrics.actionHitSize,
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            // Floating chrome over content: the dock's liquid glass, with the
            // pill's own fill cleared so the glass shows.
            child: ChromeSurface(
              refracts: true,
              tint: AppColors.barControl,
              tintOpacity: barControlTintOpacity,
              child: Pill(
                onTap: onTap,
                color: Colors.transparent,
                horizontalPadding: label == null ? 0 : AppSpacing.sm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon),
                    if (label != null) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Text(label!),
                    ],
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

/// Scroll view with a [CollapsingHeaderDelegate] pinned on top and the
/// standard gutter/rhythm for its children.
class CollapsingScrollView extends StatefulWidget {
  const CollapsingScrollView({
    super.key,
    required this.header,
    required this.children,
    this.bottomPadding = AppSpacing.xxl,
    this.hasTopGap = true,
  });

  final CollapsingHeaderDelegate header;
  final List<Widget> children;
  final double bottomPadding;

  /// Whether the content starts a gap below the header, or right under
  /// it, as a calendar's grid does under its pinned weekdays.
  final bool hasTopGap;

  @override
  State<CollapsingScrollView> createState() => _CollapsingScrollViewState();
}

class _CollapsingScrollViewState extends State<CollapsingScrollView> {
  final _controller = ScrollController();

  /// Only a scroll the user drove should snap; programmatic scrolls such as
  /// `ensureVisible` must land exactly where they asked.
  bool _isUserDriven = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle) {
      _isUserDriven = true;
    } else if (notification is ScrollEndNotification) {
      _snapIfHalfCollapsed(notification.metrics.pixels);
    }
    return false;
  }

  /// Like iOS large titles, never come to rest half collapsed.
  void _snapIfHalfCollapsed(double offset) {
    final wasUserDriven = _isUserDriven;
    _isUserDriven = false;
    final range = widget.header.collapseRange;
    if (!wasUserDriven || offset <= 0 || offset >= range) return;
    final target = offset < range / 2 ? 0.0 : range;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      if (prefersReducedMotion(context)) {
        _controller.jumpTo(target);
      } else {
        _controller.animateTo(
          target,
          duration: _snapDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      // The scroll view and its rows stay as wide as the page: a drag in the
      // safe-area margin still scrolls it, and a row of chips still runs off
      // the screen. Each element keeps to the column itself.
      child: LayoutBuilder(
        builder: (context, constraints) => PageColumn(
          insets: contentColumnInsets(context, constraints.maxWidth),
          child: CustomScrollView(
            controller: _controller,
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: widget.header),
              _pageItems(
                context,
                widget.children,
                hasTopGap: widget.hasTopGap,
                bottomPadding: widget.bottomPadding,
              ),
              // Minimum page height: always enough to collapse the header fully,
              // so content that shrinks (a day without records, a narrow filter)
              // cannot pull a collapsed header back open.
              SliverLayoutBuilder(
                builder: (context, constraints) => SliverToBoxAdapter(
                  child: SizedBox(
                    height: math.max(
                      0,
                      constraints.viewportMainAxisExtent +
                          widget.header.collapseRange -
                          constraints.precedingScrollExtent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page's items with the page's rhythm between them. Only vertical
/// clearance for the floating chrome; each element brings its own
/// horizontal spacing (see Gutter).
Widget _pageItems(
  BuildContext context,
  List<Widget> children, {
  required bool hasTopGap,
  required double bottomPadding,
}) => SliverPadding(
  padding: EdgeInsets.only(
    top: hasTopGap ? _contentTopGap : 0,
    bottom: bottomPadding + MediaQuery.paddingOf(context).bottom,
  ),
  sliver: SliverList.separated(
    itemCount: children.length,
    separatorBuilder: (_, _) => const SizedBox(height: pageItemSpacing),
    itemBuilder: (_, index) => children[index],
  ),
);

/// A [CollapsingHeaderDelegate] with no large title over a block held at
/// the top of the page, whose own scrolling runs up behind the header, as
/// a calendar's months do; the children scroll in their own list below
/// the block, never under the header.
class HeldBlockView extends StatelessWidget {
  const HeldBlockView({
    super.key,
    required this.header,
    required this.held,
    required this.children,
    this.listHeader,
    this.bottomPadding = AppSpacing.xxl,
    this.hasTopGap = true,
  });

  final CollapsingHeaderDelegate header;

  /// The block, given the header's height to start its content under;
  /// as tall as it lays out, the list taking the rest.
  final Widget Function(double headerHeight) held;

  /// Kept at the top of the list, which scrolls under it.
  final Widget? listHeader;
  final List<Widget> children;
  final double bottomPadding;
  final bool hasTopGap;

  @override
  Widget build(BuildContext context) {
    final headerHeight = header.maxExtent;
    return LayoutBuilder(
      builder: (context, constraints) => PageColumn(
        insets: contentColumnInsets(context, constraints.maxWidth),
        child: Stack(
          children: [
            Column(
              children: [
                held(headerHeight),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      if (listHeader case final listHeader?)
                        PinnedHeaderSliver(
                          child: _FadingEdgeGlass(child: listHeader),
                        ),
                      _pageItems(
                        context,
                        children,
                        hasTopGap: hasTopGap,
                        bottomPadding: bottomPadding,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: header.build(context, 0, false),
            ),
          ],
        ),
      ),
    );
  }
}
