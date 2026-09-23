import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How far a windowed iPad app's window controls reach into the top bar
/// from the leading edge, as measured by `WindowControls` in
/// `ios/Runner/SceneDelegate.swift`. They sit over the top-leading corner
/// but are not part of the safe area, so only the bar in that corner moves
/// its leading control clear of them, as UIKit bars do.
class WindowControls extends InheritedWidget {
  const WindowControls({
    super.key,
    required this.leadingInset,
    required super.child,
  });

  final double leadingInset;

  /// 0 away from the top-leading corner (a detail pane) and off iPad.
  static double leadingInsetOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WindowControls>()
          ?.leadingInset ??
      0;

  @override
  bool updateShouldNotify(WindowControls oldWidget) =>
      leadingInset != oldWidget.leadingInset;
}

/// Provides [WindowControls] for the whole window, following the native
/// measurement as the window moves in and out of full screen.
class WindowControlsScope extends StatefulWidget {
  const WindowControlsScope({super.key, required this.child});

  final Widget child;

  @override
  State<WindowControlsScope> createState() => _WindowControlsScopeState();
}

class _WindowControlsScopeState extends State<WindowControlsScope> {
  static const _channel = MethodChannel('mishirube/window_controls');

  static bool get _isMeasured => !kIsWeb && Platform.isIOS;

  var _leadingInset = 0.0;

  @override
  void initState() {
    super.initState();
    if (!_isMeasured) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'leadingInsetChanged') {
        _update(call.arguments as double);
      }
    });
    _channel.invokeMethod<double>('leadingInset').then((inset) {
      if (inset != null) _update(inset);
    });
  }

  void _update(double inset) {
    if (!mounted || inset == _leadingInset) return;
    setState(() => _leadingInset = inset);
  }

  @override
  void dispose() {
    if (_isMeasured) _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      WindowControls(leadingInset: _leadingInset, child: widget.child);
}
