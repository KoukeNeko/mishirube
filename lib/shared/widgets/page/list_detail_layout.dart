import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../window_layout.dart';

/// A list and the page picked from it. With room for two panes (see
/// [showsTwoPanes]) the page opens beside the list; otherwise it
/// is pushed over it, as anywhere else. The list does not know which: it
/// calls `pushPage`, which asks [DetailPane].
///
/// With a hinge or a half-opened fold down the middle the panes meet at
/// it, one each side, instead of one of them straddling it.
class ListDetailLayout extends StatefulWidget {
  const ListDetailLayout({
    super.key,
    required this.list,
    required this.placeholder,
  });

  final Widget list;

  /// The detail pane before anything has been picked.
  final Widget placeholder;

  @override
  State<ListDetailLayout> createState() => ListDetailLayoutState();
}

class ListDetailLayoutState extends State<ListDetailLayout> {
  /// Keeps the list's state (scroll offset, filters) when a resize adds or
  /// removes the pane beside it.
  final _listKey = GlobalKey();
  final _paneKey = GlobalKey<NavigatorState>();

  /// The page open in the pane, carried over as a pushed page when the
  /// window narrows to one pane, so what the user was reading stays.
  Widget? _shown;
  bool _wasTwoPanes = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTwoPanes = showsTwoPanes(context);
    if (_wasTwoPanes && !isTwoPanes) {
      if (_shown case final page?) {
        _shown = null;
        // After this frame: the pane is going away in it, and a route
        // cannot be pushed while the tree is being built.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context)
              .push<void>(MaterialPageRoute(builder: (_) => page));
        });
      }
    }
    _wasTwoPanes = isTwoPanes;
  }

  /// Opens [page] in the pane, for what is opened from outside the list
  /// (the dock, the add menu); null when there is no pane to open it in.
  Future<T?>? showBeside<T>(Widget page) =>
      showsTwoPanes(context) ? _show<T>(page) : null;

  Future<T?> _show<T>(Widget page) {
    _shown = page;
    final route = _PaneRootRoute<T>(page);
    // Closed from inside (a page that pops itself when saved), it is no
    // longer what the user is reading.
    route.popped.then((_) {
      if (identical(_shown, page)) _shown = null;
    });
    // One page at a time: picking another replaces it and whatever was
    // opened from it, and the placeholder stays underneath.
    return _paneKey.currentState!.pushAndRemoveUntil<T>(
      route,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = KeyedSubtree(key: _listKey, child: widget.list);
    if (!showsTwoPanes(context)) return list;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fold = dividingFold(context, width);
        final isLtr = Directionality.of(context) == TextDirection.ltr;
        final listExtent = mainPaneExtent(context, width);
        final media = MediaQuery.of(context);
        // Neither pane reaches across the fold, so neither sees it; and
        // only the pane at a screen edge keeps that edge's inset.
        MediaQueryData paneMedia({required bool isList}) {
          final keepsLeft = isList == isLtr;
          EdgeInsets trim(EdgeInsets insets) =>
              keepsLeft ? insets.copyWith(right: 0) : insets.copyWith(left: 0);
          return media.copyWith(
            displayFeatures: const [],
            padding: trim(media.padding),
            viewPadding: trim(media.viewPadding),
          );
        }

        return Row(
          children: [
            SizedBox(
              width: listExtent,
              child: MediaQuery(
                data: paneMedia(isList: true),
                child: DetailPane._(show: _show, child: list),
              ),
            ),
            if (fold == null || fold.width == 0)
              const VerticalDivider(width: 1, thickness: 1)
            else
              SizedBox(width: fold.width),
            Expanded(
              child: MediaQuery(
                data: paneMedia(isList: false),
                child: NavigatorPopHandler(
                  // The system back gesture goes back inside the pane
                  // first, as it does in a pushed page.
                  onPopWithResult: (_) => _paneKey.currentState?.maybePop(),
                  child: Navigator(
                    key: _paneKey,
                    onGenerateRoute: (_) => PageRouteBuilder<void>(
                      pageBuilder: (_, _, _) =>
                          Scaffold(body: Center(child: widget.placeholder)),
                      transitionDuration: Duration.zero,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Where a page picked from a [ListDetailLayout]'s list opens, while the
/// window has room for the pane. Only the list sees it: a page inside the
/// pane pushes onto the pane's own navigator, so drilling down stays there.
class DetailPane extends InheritedWidget {
  const DetailPane._({required this.show, required super.child});

  final Future<T?> Function<T>(Widget page) show;

  static DetailPane? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DetailPane>();

  @override
  bool updateShouldNotify(DetailPane oldWidget) => false;
}

/// The page a pane opens with appears at once, the way picking a row on a
/// tablet swaps the detail rather than sliding a new page in.
class _PaneRootRoute<T> extends PageRouteBuilder<T> {
  _PaneRootRoute(Widget page)
    : super(
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
}

/// Whether [context] is in the first page of a detail pane, which has
/// nothing of its own to go back to: the list is right beside it.
bool isDetailPaneRoot(BuildContext context) =>
    ModalRoute.of(context) is _PaneRootRoute;

/// What an empty detail pane shows: which kind of thing goes there.
class DetailPanePlaceholder extends StatelessWidget {
  const DetailPanePlaceholder({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.sm),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
