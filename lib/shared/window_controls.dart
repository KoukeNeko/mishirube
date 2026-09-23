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
///
/// On a Mac the app draws its own top bar: the title bar is see-through,
/// with the window controls over the app. Its height is a top inset like
/// a phone's status bar, so pages and the rail start below it and leave
/// it to drag the window by; in full screen, where it hides, it is 0.
class WindowControlsScope extends StatefulWidget {
  const WindowControlsScope({super.key, required this.child});

  final Widget child;

  @override
  State<WindowControlsScope> createState() => _WindowControlsScopeState();
}

class _WindowControlsScopeState extends State<WindowControlsScope> {
  static const _channel = MethodChannel('mishirube/window_controls');

  /// Only the iPad and Mac runners measure anything. A test runs on the
  /// host, so the Mac also has to be what the app is drawn for.
  static bool get _isIPad => !kIsWeb && Platform.isIOS;
  static bool get _isMac =>
      !kIsWeb &&
      Platform.isMacOS &&
      defaultTargetPlatform == TargetPlatform.macOS;

  var _leadingInset = 0.0;
  var _topInset = 0.0;

  @override
  void initState() {
    super.initState();
    if (!_isIPad && !_isMac) return;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'leadingInsetChanged':
          _update(leading: call.arguments as double);
        case 'topInsetChanged':
          _update(top: call.arguments as double);
      }
    });
    if (_isIPad) {
      _channel.invokeMethod<double>('leadingInset').then((inset) {
        if (inset != null) _update(leading: inset);
      });
    } else {
      _channel.invokeMethod<double>('topInset').then((inset) {
        if (inset != null) _update(top: inset);
      });
    }
  }

  void _update({double? leading, double? top}) {
    if (!mounted) return;
    setState(() {
      _leadingInset = leading ?? _leadingInset;
      _topInset = top ?? _topInset;
    });
  }

  @override
  void dispose() {
    if (_isIPad || _isMac) _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = WindowControls(
      leadingInset: _leadingInset,
      child: widget.child,
    );
    if (_topInset == 0) return child;
    final media = MediaQuery.of(context);
    EdgeInsets below(EdgeInsets insets) =>
        insets.copyWith(top: insets.top + _topInset);
    return MediaQuery(
      data: media.copyWith(
        padding: below(media.padding),
        viewPadding: below(media.viewPadding),
      ),
      child: child,
    );
  }
}
