import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../motion.dart';

/// Its child held at the left edge as if pinned there, the right edge
/// bobbing up and down as the device is shaken: sheared, never bent,
/// like a springy strip clamped at one end, until damping brings it to
/// rest. With Reduce Motion it stays still.
class ShakeShear extends StatefulWidget {
  const ShakeShear({super.key, required this.motion, required this.child});

  /// Acceleration across the screen, gravity included, in m/s²: x to the
  /// right, y towards the top edge.
  final Stream<Offset>? motion;
  final Widget child;

  @override
  State<ShakeShear> createState() => _ShakeShearState();
}

class _ShakeShearState extends State<ShakeShear>
    with SingleTickerProviderStateMixin {
  /// About five swings a second, each about two thirds of the one
  /// before: a few clear wobbles, not a jelly.
  static const _stiffness = 1000.0;
  static const _damping = 5.0;

  /// How fast the slope gathers, per second², for each m/s² the device
  /// is jolted by.
  static const _gain = 10.0;

  /// The steepest slope: about 15 logical pixels at the free end of a
  /// Today tile's chart.
  static const _reach = 0.1;

  /// How long, in seconds, gravity takes to follow the device's lean:
  /// the reading beyond it is the jolt.
  static const _gravityLag = 0.15;

  /// Jolts below this, in m/s², are the sensor's jitter.
  static const _jitter = 0.5;

  static const _maxStep = 1 / 240;

  late final Ticker _ticker = createTicker(_tick);
  StreamSubscription<Offset>? _subscription;

  Offset? _reading;
  Offset? _gravity;

  /// Acceleration towards the top edge beyond gravity, in m/s².
  double get _jolt =>
      (_reading ?? Offset.zero).dy - (_gravity ?? Offset.zero).dy;

  /// How far the free end is down the screen for each unit of width,
  /// and how fast that changes.
  double _deflection = 0;
  double _velocity = 0;
  Duration _lastTick = Duration.zero;

  bool get _isStill => prefersReducedMotion(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isStill) {
      _stop();
    } else {
      _listen();
    }
  }

  @override
  void didUpdateWidget(ShakeShear old) {
    super.didUpdateWidget(old);
    if (old.motion != widget.motion) {
      _subscription?.cancel();
      _subscription = null;
      _listen();
    }
  }

  void _listen() {
    if (_subscription != null || widget.motion == null || _isStill) return;
    _subscription = widget.motion!.listen((reading) {
      _reading = reading;
      // Where the device already is, not a jolt.
      _gravity ??= reading;
      if (_jolt.abs() > _jitter && !_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    });
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    _ticker.stop();
    _deflection = 0;
    _velocity = 0;
  }

  void _tick(Duration elapsed) {
    final dt = math.min(
      (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond,
      1 / 30,
    );
    _lastTick = elapsed;
    if (dt <= 0) return;
    // Followed over time rather than per reading, so the jolt dies away
    // even when readings stop.
    _gravity = Offset.lerp(_gravity, _reading, 1 - math.exp(-dt / _gravityLag));
    final steps = math.max(1, (dt / _maxStep).ceil());
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      // Jolted towards the top edge, the free end lags behind, down the
      // screen.
      final pull =
          _jolt * _gain - _stiffness * _deflection - _damping * _velocity;
      _velocity += pull * h;
      _deflection += _velocity * h;
      if (_deflection.abs() > _reach) {
        _deflection = _deflection.clamp(-_reach, _reach);
        _velocity = 0;
      }
    }
    setState(() {});
    if (_deflection.abs() < 0.0003 &&
        _velocity.abs() < 0.007 &&
        _jolt.abs() <= _jitter) {
      _deflection = 0;
      _velocity = 0;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    // Its own layer: a tick redraws the strip, not the page around it,
    // which would otherwise be drawn again every frame it bobs.
    child: Transform(
      alignment: Alignment.centerLeft,
      transform: Matrix4.identity()..setEntry(1, 0, _deflection),
      child: widget.child,
    ),
  );
}
