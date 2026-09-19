import 'package:flutter/widgets.dart';

/// Lays a full-screen [body] under an optional [header] and [footer] that
/// float on top of it, and hands the body their measured heights as
/// `MediaQuery.padding`. This is the same trick [Scaffold] uses for
/// `extendBody`: sizes are known only during layout, so they travel to the
/// body through its constraints and a [LayoutBuilder].
class EdgeToEdgeLayout extends StatelessWidget {
  const EdgeToEdgeLayout({
    super.key,
    required this.body,
    this.header,
    this.footer,
  });

  final Widget body;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return CustomMultiChildLayout(
      delegate: _EdgeToEdgeDelegate(
        fallbackTop: mediaQuery.padding.top,
        fallbackBottom: mediaQuery.padding.bottom,
      ),
      children: [
        // Paint order: body first so the chrome floats above it.
        LayoutId(
          id: _Slot.body,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final insets = constraints as _ChromeInsetConstraints;
              return MediaQuery(
                data: mediaQuery.copyWith(
                  padding: mediaQuery.padding.copyWith(
                    top: insets.top,
                    bottom: insets.bottom,
                  ),
                ),
                child: body,
              );
            },
          ),
        ),
        if (header != null) LayoutId(id: _Slot.header, child: header!),
        if (footer != null) LayoutId(id: _Slot.footer, child: footer!),
      ],
    );
  }
}

enum _Slot { body, header, footer }

class _ChromeInsetConstraints extends BoxConstraints {
  _ChromeInsetConstraints({
    required BoxConstraints base,
    required this.top,
    required this.bottom,
  }) : super(
         minWidth: base.minWidth,
         maxWidth: base.maxWidth,
         minHeight: base.minHeight,
         maxHeight: base.maxHeight,
       );

  final double top;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is _ChromeInsetConstraints &&
      super == other &&
      other.top == top &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(super.hashCode, top, bottom);
}

class _EdgeToEdgeDelegate extends MultiChildLayoutDelegate {
  _EdgeToEdgeDelegate({
    required this.fallbackTop,
    required this.fallbackBottom,
  });

  /// Used when there is no header/footer: the plain safe-area insets.
  final double fallbackTop;
  final double fallbackBottom;

  @override
  void performLayout(Size size) {
    final chromeConstraints = BoxConstraints(
      minWidth: size.width,
      maxWidth: size.width,
      maxHeight: size.height,
    );
    var top = fallbackTop;
    var bottom = fallbackBottom;
    if (hasChild(_Slot.header)) {
      top = layoutChild(_Slot.header, chromeConstraints).height;
      positionChild(_Slot.header, Offset.zero);
    }
    if (hasChild(_Slot.footer)) {
      bottom = layoutChild(_Slot.footer, chromeConstraints).height;
      positionChild(_Slot.footer, Offset(0, size.height - bottom));
    }
    layoutChild(
      _Slot.body,
      _ChromeInsetConstraints(
        base: BoxConstraints.tight(size),
        top: top,
        bottom: bottom,
      ),
    );
    positionChild(_Slot.body, Offset.zero);
  }

  @override
  bool shouldRelayout(_EdgeToEdgeDelegate oldDelegate) =>
      oldDelegate.fallbackTop != fallbackTop ||
      oldDelegate.fallbackBottom != fallbackBottom;
}
