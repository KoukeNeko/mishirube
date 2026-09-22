import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../app/theme.dart';

/// Material 3's expanded width, measured on the window the app is given
/// and never on the device: a tablet in split screen is compact, a phone
/// driving an external display is not. From here a list and the page
/// picked from it sit side by side.
const expandedWidth = 840.0;

/// Whether a main page and what is opened from it sit side by side: in a
/// window of expanded width, or on any foldable opened like a book, where
/// the fold already splits the screen into two sides and one page on half
/// of it would leave the other half empty.
bool showsTwoPanes(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= expandedWidth || dividingFold(context, width) != null;
}

/// How wide the main pane is beside the page opened from it, in a window
/// [width] wide: a share of the window, so on a large tablet it does not
/// read as a strip, but never narrower than Material's first pane and
/// never wider than the widest phone with its dock, so the main page keeps
/// the layout it has on a phone.
double mainPaneWidthFor(double width) => (width * 0.4).clamp(360.0, 480.0);

/// How wide the main pane is in a region [width] wide showing two panes:
/// [mainPaneWidthFor], or up to a [dividingFold] so the panes meet at it.
double mainPaneExtent(BuildContext context, double width) {
  final fold = dividingFold(context, width);
  if (fold == null) return mainPaneWidthFor(width);
  return switch (Directionality.of(context)) {
    TextDirection.ltr => fold.left,
    TextDirection.rtl => width - fold.right,
  };
}

/// Widest the page column grows. Past this, lines of text and rows with a
/// label at one end and its value at the other stop reading as one thing,
/// so a wider page centres the column instead of stretching it.
const contentMaxWidth = 640.0;

/// The hinge or half-opened fold running down a region [width] wide, in
/// the region's coordinates, or null when nothing divides it into sides.
///
/// What counts as dividing the screen is Flutter's own rule, the one its
/// dialogs and sheets already follow. A fold across the region (tabletop)
/// does not give it sides, so it is left to scroll past.
///
/// The display features in [context]'s [MediaQuery] must be in the
/// region's coordinates: a page that does not start at the window's edge
/// (a list-detail pane) is handed none.
Rect? dividingFold(BuildContext context, double width) {
  final separating = DisplayFeatureSubScreen.avoidBounds(
    MediaQueryData(displayFeatures: MediaQuery.displayFeaturesOf(context)),
  );
  for (final bounds in separating) {
    final runsDown = bounds.height > bounds.width;
    if (runsDown && bounds.right > 0 && bounds.left < width) return bounds;
  }
  return null;
}

/// The part of a region [width] wide that content may use: inside the
/// safe area (a phone on its side has its notch at one end), and on the
/// leading side of a [dividingFold].
({double start, double end}) usableSpan(BuildContext context, double width) {
  final padding = MediaQuery.paddingOf(context);
  var start = padding.left;
  var end = width - padding.right;
  if (dividingFold(context, width) case final fold?) {
    switch (Directionality.of(context)) {
      case TextDirection.ltr:
        end = math.min(end, fold.left);
      case TextDirection.rtl:
        start = math.max(start, fold.right);
    }
  }
  return (start: start, end: math.max(start, end));
}

/// Insets from the edges of a region [width] wide to its content column:
/// no wider than [maxWidth], centred in the [usableSpan].
EdgeInsets contentColumnInsets(
  BuildContext context,
  double width, {
  double maxWidth = contentMaxWidth,
}) {
  final span = usableSpan(context, width);
  final spare = math.max(0.0, span.end - span.start - maxWidth);
  return EdgeInsets.only(
    left: span.start + spare / 2,
    right: width - span.end + spare / 2,
  );
}

/// The content column of the page around [context], as insets from the
/// page's edges. `Gutter` keeps an element to it, so cards line up in a
/// wide window; an element that runs edge to edge (a row of chips that
/// scrolls sideways) pads its content by it instead, so the first chip
/// lines up with the cards and the row still runs off the screen.
class PageColumn extends InheritedWidget {
  const PageColumn({super.key, required this.insets, required super.child});

  final EdgeInsets insets;

  /// Zero outside a page (a sheet, a dialog), which has no column.
  static EdgeInsets of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageColumn>()?.insets ??
      EdgeInsets.zero;

  /// From the page's edges to an element's content: the column, then the
  /// page gutter inside it.
  static EdgeInsets gutterOf(BuildContext context) {
    final column = of(context);
    return EdgeInsets.only(
      left: column.left + AppSpacing.screenGutter,
      right: column.right + AppSpacing.screenGutter,
    );
  }

  @override
  bool updateShouldNotify(PageColumn oldWidget) => insets != oldWidget.insets;
}
