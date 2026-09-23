import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../window_layout.dart';
import '../chrome/chrome_surface.dart';
import '../controls/pill.dart';
import 'collapsing_header.dart';
import 'collapsing_page.dart';
import 'edge_to_edge_layout.dart';
import 'list_detail_layout.dart';
import '../../toast/toast_host.dart';

/// Page layouts add no horizontal padding; each element on a page spaces
/// itself from the screen edges by wrapping itself in a Gutter. Elements
/// that should run edge to edge (horizontal chip rows) skip it and pad their
/// own content instead.
class Gutter extends StatelessWidget {
  const Gutter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: PageColumn.gutterOf(context), child: child);
  }
}

enum AppBarLeading { back, none }

/// The chevron reads as a back control at this size; the pill's default
/// icon size is meant for the smaller action glyphs.
const _backIconSize = 24.0;

/// The leading back control of every app bar. [icon] and [tooltip] change
/// it into, for example, a collapse chevron; [onPressed] defaults to
/// popping the route.
class AppBarBackButton extends StatelessWidget {
  const AppBarBackButton({
    super.key,
    this.icon = Icons.chevron_left,
    this.tooltip = '返回',
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final metrics = ToolbarMetrics.of(context);
    final press = onPressed ?? () => Navigator.of(context).maybePop();
    return Semantics(
      button: true,
      label: tooltip,
      // Excluding the child's semantics drops its tap too.
      onTap: press,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        // Taps on the margin around the circle still count.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: press,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: metrics.actionHitSize,
              minHeight: metrics.actionHitSize,
            ),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              // The same floating glass as the trailing actions, so both
              // ends of the bar are made of one material.
              child: ChromeSurface(
                refracts: true,
                tint: AppColors.surfaceRaised,
                child: Pill(
                  onTap: press,
                  // Going back is not an action to confirm by feel.
                  isSilent: true,
                  color: Colors.transparent,
                  horizontalPadding: 0,
                  child: Icon(icon, size: _backIconSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a page shows in the shared app bar. Every page renders it through
/// [PageScaffold], so all headers collapse, blur and scale the same way.
class PageAppBar {
  const PageAppBar({
    required this.title,
    this.subtitle,
    this.leading = AppBarLeading.back,
    this.onBack,
    this.actions = const [],
    this.compactBar = CompactBarBehavior.pinned,
  });

  final String title;
  final String? subtitle;
  final AppBarLeading leading;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final CompactBarBehavior compactBar;
}

/// Scaffold whose body runs edge to edge under an optional floating footer.
class EdgeToEdgeScaffold extends StatelessWidget {
  const EdgeToEdgeScaffold({super.key, required this.body, this.footer});

  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EdgeToEdgeLayout(body: body, footer: footer),
    );
  }
}

/// A standard page: the shared collapsing app bar, scrolling [children]
/// and an optional floating [footer].
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.appBar,
    required this.children,
    this.footer,
    this.pinned,
    this.pinnedHeight,
  });

  final PageAppBar appBar;
  final List<Widget> children;
  final Widget? footer;
  final Widget? pinned;
  final double? pinnedHeight;

  @override
  Widget build(BuildContext context) {
    return EdgeToEdgeScaffold(
      footer: footer,
      body: CollapsingPage(
        title: appBar.title,
        subtitle: appBar.subtitle,
        leading:
            appBar.leading == AppBarLeading.back && !isDetailPaneRoot(context)
            ? AppBarBackButton(onPressed: appBar.onBack)
            : null,
        actions: appBar.actions,
        pinned: pinned,
        pinnedHeight: pinnedHeight,
        compactBar: appBar.compactBar,
        children: children,
      ),
    );
  }
}

/// Pushed page with the shared app bar and an optional floating action.
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.appBar,
    required this.children,
    this.footer,
  });

  final PageAppBar appBar;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      appBar: appBar,
      footer: footer == null ? null : BottomActionBar(child: footer!),
      children: children,
    );
  }
}

const _footerFadeHeight = AppSpacing.xl;
const _footerFadeOpacity = 0.92;
const _floatingButtonElevation = 8.0;

/// Floating footer: buttons hover over the content on a soft fade instead
/// of sitting on a solid bar. Only the controls take touches; the fade lets
/// taps through to the content underneath.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.caption});

  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final isHighContrast = MediaQuery.highContrastOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.45],
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background.withValues(
                      alpha: isHighContrast ? 1 : _footerFadeOpacity,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        LayoutBuilder(
          // A button stretched across a tablet reads as a bar, not a
          // button, so the footer keeps to the readable width.
          builder: (context, constraints) {
            final column = contentColumnInsets(
              context,
              constraints.maxWidth,
              maxWidth: readableMaxWidth,
            );
            return Padding(
              padding: EdgeInsets.fromLTRB(
                column.left + AppSpacing.screenGutter,
                _footerFadeHeight,
                column.right + AppSpacing.screenGutter,
                floatingChromeBottomOffset(context),
              ),
              child: FilledButtonTheme(
                data: const FilledButtonThemeData(
                  style: ButtonStyle(
                    elevation: WidgetStatePropertyAll(_floatingButtonElevation),
                    shadowColor: WidgetStatePropertyAll(Colors.black),
                  ),
                ),
                child: ToastObstruction(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      child,
                      if (caption != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(caption!, style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Two buttons side by side, e.g.「取消 / 確認匯入」.
class ButtonPair extends StatelessWidget {
  const ButtonPair({
    super.key,
    required this.secondary,
    required this.primary,
    this.primaryFlex = 1,
  });

  final Widget secondary;
  final Widget primary;
  final int primaryFlex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(flex: primaryFlex, child: primary),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppTextStyles.overline)),
          ?trailing,
        ],
      ),
    );
  }
}

/// A section of a page as one widget: its label, then its items, spaced
/// as the page spaces its own elements. For a section built by a class
/// of its own; a page that writes its sections inline puts the label and
/// the items straight into its children, which the page spaces the same.
/// Items keep to the column with [Gutter], as page elements do.
class PageSection extends StatelessWidget {
  const PageSection({
    super.key,
    required this.label,
    this.trailing,
    required this.children,
  });

  final String label;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: pageItemSpacing,
      children: [
        Gutter(child: SectionLabel(label, trailing: trailing)),
        ...children,
      ],
    );
  }
}
