import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../motion.dart';
import 'chrome_visibility.dart';
import 'collapsing_header.dart';

const _autoHideDuration = Duration(milliseconds: 250);

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
    this.autoHide = false,
  });

  final String title;
  final String? subtitle;

  /// Back/close control at the leading edge of the toolbar.
  final Widget? leading;
  final List<Widget> actions;

  /// A control that changes the whole page (e.g. 時間軸/月曆); stays pinned.
  final Widget? pinned;

  /// Height of [pinned]; defaults to a segmented control's height.
  final double? pinnedHeight;

  /// Tuck the compact toolbar away while the user reads downwards.
  final bool autoHide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shouldHide = autoHide && ChromeVisibility.isMinimizedOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeHeight = measureLargeTitleHeight(
          context,
          title: title,
          subtitle: subtitle,
          maxWidth: constraints.maxWidth - AppSpacing.screenGutter * 2,
        );
        final pinnedHeight = pinned == null
            ? 0.0
            : this.pinnedHeight ?? measurePinnedControlHeight(context);
        return TweenAnimationBuilder<double>(
          tween: Tween(end: shouldHide ? 1 : 0),
          duration: chromeDuration(context, _autoHideDuration),
          curve: Curves.easeOut,
          builder: (context, hideFraction, _) => CollapsingScrollView(
            header: CollapsingHeaderDelegate(
              toolbar: ToolbarMetrics.of(context),
              topInset: media.padding.top,
              largeHeight: largeHeight,
              large: LargeTitleBlock(title: title, subtitle: subtitle),
              compactTitle: Text(
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
              isHighContrast: media.highContrast,
              reduceMotion: media.disableAnimations,
            ),
            children: children,
          ),
        );
      },
    );
  }
}
