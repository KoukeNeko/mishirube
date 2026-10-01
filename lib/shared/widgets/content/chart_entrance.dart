import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../motion.dart';

/// How long a chart takes to draw itself in.
const chartEntranceDuration = Duration(milliseconds: 700);

/// Draws a chart in when it first appears and again when what it shows
/// changes, as Google Health's charts rise into place: [builder] gets
/// how far in it is, from 0 to 1. A reading picking a point is not a
/// change, so it never replays. With Reduce Motion the chart is drawn
/// whole at once.
class ChartEntrance extends StatefulWidget {
  const ChartEntrance({super.key, required this.shows, required this.builder});

  /// What the chart shows; a list that differs replays the entrance.
  final List<Object?> shows;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<ChartEntrance> createState() => _ChartEntranceState();
}

class _ChartEntranceState extends State<ChartEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: chartEntranceDuration,
  );
  bool _hasStarted = false;

  void _play() {
    if (prefersReducedMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStarted) return;
    _hasStarted = true;
    _play();
  }

  @override
  void didUpdateWidget(ChartEntrance old) {
    super.didUpdateWidget(old);
    if (!listEquals(old.shows, widget.shows)) _play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

/// How far in the [index]th of [count] parts is at [progress]: the first
/// sets off at once and the last after [stagger] of the time, each easing
/// to a stop, so bars rise one after another rather than as a block.
double staggeredProgress(
  double progress,
  int index,
  int count, {
  double stagger = 0.35,
}) {
  final delay = count <= 1 ? 0.0 : stagger * index / (count - 1);
  return Curves.easeOutCubic.transform(
    ((progress - delay) / (1 - stagger)).clamp(0.0, 1.0),
  );
}

/// [progress] eased out, for a part that comes in as a whole.
double easedProgress(double progress) =>
    Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
