import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../window_layout.dart';
import '../page/page_layout.dart';

/// How much narrower than the page column each card is, so the next one
/// shows past the edge of the screen.
const _peek = AppSpacing.xl;

const _gap = AppSpacing.xs;

/// Cards swiped sideways, one stopping at a time. The row runs edge to
/// edge and each card is a little narrower than the page column, so the
/// next shows past the edge of the screen and the row reads as one that
/// goes on. A lone card is not a row: it is as wide as the column.
class CardPager extends StatelessWidget {
  const CardPager({super.key, required this.children})
    : assert(children.length > 0);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.length == 1) return Gutter(child: children.single);
    final gutter = PageColumn.gutterOf(context);
    return LayoutBuilder(
      builder: (context, space) {
        final width = math.max(1.0, space.maxWidth - gutter.horizontal - _peek);
        return SingleChildScrollView(
          // A scroll position keeps the stops it was made with, so a new
          // width or number of cards starts the row again from the first.
          key: ValueKey((width, children.length)),
          scrollDirection: Axis.horizontal,
          padding: gutter,
          physics: _StopPhysics(width + _gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _gap,
              children: [
                for (final card in children)
                  SizedBox(width: width, child: card),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Settles a scroll on a card rather than between two: the nearest one,
/// or the next in the direction of a fling, never more than one away.
class _StopPhysics extends ScrollPhysics {
  const _StopPhysics(this.stop, {super.parent});

  /// The distance from one card to the next.
  final double stop;

  @override
  _StopPhysics applyTo(ScrollPhysics? ancestor) =>
      _StopPhysics(stop, parent: buildParent(ancestor));

  double _targetOf(ScrollMetrics position, Tolerance tolerance, double speed) {
    var card = position.pixels / stop;
    if (speed < -tolerance.velocity) {
      card -= 0.5;
    } else if (speed > tolerance.velocity) {
      card += 0.5;
    }
    return (card.roundToDouble() * stop)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double speed) {
    // Past an end and not heading back, the parent's bounce brings it in.
    if ((speed <= 0 && position.pixels <= position.minScrollExtent) ||
        (speed >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, speed);
    }
    final tolerance = toleranceFor(position);
    final target = _targetOf(position, tolerance, speed);
    if (target == position.pixels) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      speed,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
