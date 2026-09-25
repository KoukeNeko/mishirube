import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../motion.dart';
import '../../window_layout.dart';
import '../chrome/chrome_visibility.dart';
import 'collapsing_header.dart';

const _autoHideDuration = Duration(milliseconds: 250);

/// What a page's small (compact) bar does once the large title is gone.
enum CompactBarBehavior {
  /// Always shown.
  pinned,

  /// Tucked away while the user reads downwards, back on scrolling up.
  autoHide,

  /// Never shown: the bar scrolls away with the large title.
  none,
}

/// Root tab page: large title + subtitle that collapse into a glass
/// toolbar, an optional pinned view-mode control, and scrolling content.
class CollapsingPage extends StatelessWidget {
  const CollapsingPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.pinned,
    this.pinnedHeight,
    this.compactBar = CompactBarBehavior.pinned,
  });

  /// Null for a page whose tab already names it: no large title, only
  /// the toolbar and what is pinned under it.
  final String? title;
  final String? subtitle;

  /// Back/close control at the leading edge of the toolbar.
  final Widget? leading;
  final List<Widget> actions;

  /// A control that changes the whole page (e.g. 時間軸/月曆); stays pinned.
  final Widget? pinned;

  /// Height of [pinned]; defaults to a segmented control's height.
  final double? pinnedHeight;

  /// What happens to the small bar once the large title has scrolled away.
  final CompactBarBehavior compactBar;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shouldHide =
        compactBar == CompactBarBehavior.autoHide &&
        ChromeVisibility.isMinimizedOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final toolbar = ToolbarMetrics.of(context);
        final isBar = compactBar == CompactBarBehavior.none;
        final measuredPinned = pinned == null
            ? 0.0
            : this.pinnedHeight ?? measurePinnedControlHeight(context);
        final pinnedHeight = pinned == null
            ? 0.0
            : pinnedSlotHeight(
                measured: measuredPinned,
                toolbar: toolbar,
                isBar: isBar,
              );
        final largeBottomPadding = largeTitleBottomPadding(
          pinnedTopInset: pinned == null
              ? null
              : pinnedControlTopInset(
                  measured: measuredPinned,
                  slotHeight: pinnedHeight,
                  toolbar: toolbar,
                  isBar: isBar,
                ),
        );
        final title = this.title;
        final largeHeight = title == null
            ? 0.0
            : measureLargeTitleHeight(
                context,
                title: title,
                subtitle: subtitle,
                maxWidth:
                    constraints.maxWidth -
                    contentColumnInsets(
                      context,
                      constraints.maxWidth,
                    ).horizontal -
                    AppSpacing.screenGutter * 2,
                bottomPadding: largeBottomPadding,
              );
        return TweenAnimationBuilder<double>(
          tween: Tween(end: shouldHide ? 1 : 0),
          duration: chromeDuration(context, _autoHideDuration),
          curve: Curves.easeOut,
          builder: (context, hideFraction, _) => CollapsingScrollView(
            header: CollapsingHeaderDelegate(
              toolbar: toolbar,
              topInset: media.padding.top,
              largeHeight: largeHeight,
              large: title == null
                  ? const SizedBox.shrink()
                  : LargeTitleBlock(
                      title: title,
                      subtitle: subtitle,
                      bottomPadding: largeBottomPadding,
                    ),
              compactTitle: title == null
                  ? const SizedBox.shrink()
                  : Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compactTitleStyle,
                    ),
              leading: leading,
              actions: actions,
              pinned: pinned,
              pinnedHeight: pinnedHeight,
              hideToolbarFraction: hideFraction,
              scrollsToolbarAway: compactBar == CompactBarBehavior.none,
              isHighContrast: media.highContrast,
              reduceMotion: prefersReducedMotion(context),
            ),
            children: children,
          ),
        );
      },
    );
  }
}
