import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'chrome_surface.dart';
import 'collapsing_header.dart';
import 'collapsing_page.dart';
import 'edge_to_edge_layout.dart';
import '../toast/toast_host.dart';

enum AppBarLeading { back, none }

/// What a page shows in the shared app bar. Every page renders it through
/// [PageScaffold], so all headers collapse, blur and scale the same way.
class PageAppBar {
  const PageAppBar({
    required this.title,
    this.subtitle,
    this.leading = AppBarLeading.back,
    this.onBack,
    this.onClose,
    this.actions = const [],
    this.compactBar = CompactBarBehavior.pinned,
  });

  final String title;
  final String? subtitle;
  final AppBarLeading leading;
  final VoidCallback? onBack;

  /// Modal pages get a close button at the trailing edge.
  final VoidCallback? onClose;
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
    final onClose = appBar.onClose;
    return EdgeToEdgeScaffold(
      footer: footer,
      body: CollapsingPage(
        title: appBar.title,
        subtitle: appBar.subtitle,
        leading: appBar.leading == AppBarLeading.back
            ? IconButton(
                tooltip: '返回',
                constraints: BoxConstraints.tightFor(
                  width: ToolbarMetrics.of(context).actionHitSize,
                  height: ToolbarMetrics.of(context).actionHitSize,
                ),
                padding: EdgeInsets.zero,
                onPressed:
                    appBar.onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left, size: 30),
              )
            : null,
        actions: [
          ...appBar.actions,
          if (onClose != null)
            HeaderAction(
              icon: Icons.close,
              semanticLabel: '關閉',
              onTap: onClose,
            ),
        ],
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
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            _footerFadeHeight,
            AppSpacing.screenGutter,
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
