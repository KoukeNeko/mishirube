import 'package:flutter/widgets.dart';

/// Whether the app chrome is currently minimised because the user is
/// scrolling down. Provided by the home shell; defaults to expanded.
class ChromeVisibility extends InheritedWidget {
  const ChromeVisibility({
    super.key,
    required this.isMinimized,
    required super.child,
  });

  final bool isMinimized;

  static bool isMinimizedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ChromeVisibility>()
          ?.isMinimized ??
      false;

  @override
  bool updateShouldNotify(ChromeVisibility oldWidget) =>
      oldWidget.isMinimized != isMinimized;
}
