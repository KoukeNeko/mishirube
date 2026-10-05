import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../controls/buttons.dart';
import '../page/collapsing_header.dart' show pageItemSpacing;
import '../page/page_layout.dart';
import 'chrome_surface.dart';

/// Shows a panel that rises from the foot of the screen, for a choice that
/// takes more than a dialog holds: a few controls and what they make. The
/// [builder] lays out the panel; it decides its own height and, for what
/// is taller than the room, its own scrolling.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: builder,
  );
}

/// A sheet that scrolls: its [children] are spaced like a page's, by
/// [pageItemSpacing] inside the gutter, and slide under a title bar of
/// liquid glass at the top and, with a [footer], floating buttons at the
/// foot.
class AppSheetScaffold extends StatefulWidget {
  const AppSheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;

  /// Page items: each wraps itself in a [Gutter], or runs edge to edge.
  final List<Widget> children;

  /// Buttons that float over the foot of the sheet ([BottomActionBar]).
  final Widget? footer;

  @override
  State<AppSheetScaffold> createState() => _AppSheetScaffoldState();
}

class _AppSheetScaffoldState extends State<AppSheetScaffold> {
  final _titleKey = GlobalKey();
  final _footerKey = GlobalKey();

  /// The room the bars take, measured: the content starts below the one and
  /// ends above the other.
  double _titleHeight = 0;
  double _footerHeight = 0;

  void _measure() {
    double heightOf(GlobalKey key) =>
        (key.currentContext?.findRenderObject() as RenderBox?)?.size.height ??
        0;
    final title = heightOf(_titleKey);
    final footer = heightOf(_footerKey);
    if (!mounted || (title == _titleHeight && footer == _footerHeight)) return;
    setState(() {
      _titleHeight = title;
      _footerHeight = footer;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final media = MediaQuery.of(context);
    final footer = widget.footer;
    return Stack(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height - media.viewPadding.top,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: _titleHeight + pageItemSpacing,
              bottom: _footerHeight + pageItemSpacing,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: pageItemSpacing,
              children: widget.children,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: KeyedSubtree(
            key: _titleKey,
            child: _SheetTitleBar(title: widget.title),
          ),
        ),
        if (footer != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: KeyedSubtree(
              key: _footerKey,
              child: BottomActionBar(child: footer),
            ),
          ),
      ],
    );
  }
}

/// The sheet's title and its close control on liquid glass, inset by the
/// gutter like the pills of a page's bar.
class _SheetTitleBar extends StatelessWidget {
  const _SheetTitleBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Gutter(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: ChromeSurface(
          refracts: true,
          tint: AppColors.barControl,
          tintOpacity: barControlTintOpacity,
          radius: AppRadius.card,
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.itemTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SquareIconButton(
                  icon: Icons.close,
                  tooltip: context.l10n.commonClose,
                  background: Colors.transparent,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
