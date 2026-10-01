import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../motion.dart';

/// How long a chart takes to draw itself in, once it starts.
const chartEntranceDuration = Duration(milliseconds: 600);

/// How long a chart scrolled into view must stay before it starts, so
/// one passed on the way elsewhere does not play (see
/// `research/84-chart-entrance-timing.md`; a judgement, not a figure
/// from the literature). A chart in view as its page arrives starts
/// without it.
const chartEntranceDwell = Duration(milliseconds: 150);

/// How far its page has slid in when a chart starts: the drawing
/// overlaps the end of the slide rather than waiting for it to settle.
const _arrivedShare = 0.6;

/// The share of a chart that must be on screen before it counts as seen.
const _visibleShare = 0.5;

/// Draws a chart in once it is seen, and again when what it shows
/// changes, as Google Health's charts rise into place: [builder] gets
/// how far in it is, from 0 to 1.
///
/// It waits until its page has mostly slid in, its tab is the one
/// showing and half of it is on screen, so the drawing is watched rather
/// than over before anyone looks; one brought into view by scrolling
/// waits a moment more (see `research/84-chart-entrance-timing.md`). It plays once: having played
/// it keeps its place in a list, so scrolling away and back does not
/// replay it. A change to what it shows replays it at once, the user
/// having just asked for it. A reading picking a point is not a change.
/// With Reduce Motion the chart is drawn whole at once.
class ChartEntrance extends StatefulWidget {
  const ChartEntrance({super.key, required this.shows, required this.builder});

  /// What the chart shows; a list that differs replays the entrance.
  final List<Object?> shows;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<ChartEntrance> createState() => _ChartEntranceState();
}

class _ChartEntranceState extends State<ChartEntrance>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  // The dwell runs as the first stretch of the controller, drawing
  // nothing, so it goes by frame like the drawing and is undone the same
  // way when the chart leaves view.
  late final _controller = AnimationController(
    vsync: this,
    duration: chartEntranceDwell + chartEntranceDuration,
  );

  static final _dwellShare =
      chartEntranceDwell.inMicroseconds /
      (chartEntranceDwell + chartEntranceDuration).inMicroseconds;

  Animation<double>? _route;
  ScrollPosition? _position;
  bool _isTabShowing = true;
  bool _isStill = false;

  /// Whether it has played since it was made, and whether it still has
  /// a drawing to play.
  bool _hasPlayed = false;
  bool _isPending = true;
  bool _isCheckQueued = false;

  /// Whether the next check was asked for by a scroll, which brings a
  /// chart into view in passing.
  bool _isScrolled = false;

  @override
  bool get wantKeepAlive => _hasPlayed;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
  }

  /// Once the drawing begins it has played, and keeps its place.
  void _onTick() {
    if (_hasPlayed || _controller.value < _dwellShare) return;
    _hasPlayed = true;
    updateKeepAlive();
  }

  double get _progress => _isStill
      ? 1
      : ((_controller.value - _dwellShare) / (1 - _dwellShare)).clamp(0.0, 1.0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isStill = prefersReducedMotion(context);
    _isTabShowing = TickerMode.valuesOf(context).enabled;
    final route = ModalRoute.of(context)?.animation;
    if (route != _route) {
      _route?.removeListener(_queueCheck);
      _route = route?..addListener(_queueCheck);
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_onScroll);
      _position = position?..addListener(_onScroll);
    }
    _queueCheck();
  }

  @override
  void didUpdateWidget(ChartEntrance old) {
    super.didUpdateWidget(old);
    if (listEquals(old.shows, widget.shows)) return;
    _isPending = true;
    _controller
      ..stop()
      ..value = 0;
    _queueCheck();
  }

  /// Whether it is lingering before the drawing begins.
  bool get _isDwelling =>
      _controller.isAnimating && _controller.value < _dwellShare;

  void _onScroll() {
    _isScrolled = true;
    _queueCheck();
  }

  /// Checks once the frame is laid out, when where the chart sits is
  /// known.
  void _queueCheck() {
    if (_isCheckQueued || !(_isPending || _isDwelling)) return;
    _isCheckQueued = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _isCheckQueued = false;
        final isScrolled = _isScrolled;
        _isScrolled = false;
        if (mounted) _check(isScrolled: isScrolled);
      })
      ..ensureVisualUpdate();
  }

  bool get _isReady =>
      _isTabShowing &&
      (_route == null ||
          _route!.status == AnimationStatus.completed ||
          (_route!.status == AnimationStatus.forward &&
              _route!.value >= _arrivedShare)) &&
      _isVisibleEnough();

  /// Whether half the chart is inside the viewport it scrolls in, or as
  /// much of it as the viewport can hold.
  bool _isVisibleEnough() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    // Outside any scrolling list, being laid out is being on screen.
    if (RenderAbstractViewport.maybeOf(box) case final RenderBox viewport) {
      final shown = MatrixUtils.transformRect(
        box.getTransformTo(viewport),
        Offset.zero & box.size,
      ).intersect(Offset.zero & viewport.size);
      if (shown.isEmpty) return false;
      final whole =
          math.min(box.size.width, viewport.size.width) *
          math.min(box.size.height, viewport.size.height);
      return shown.width * shown.height >= _visibleShare * whole;
    }
    return true;
  }

  void _check({required bool isScrolled}) {
    if (_isStill) {
      _isPending = false;
      return;
    }
    if (!_isReady) {
      // Out of view before the drawing began: wait for the next look.
      if (_isDwelling) {
        _controller
          ..stop()
          ..value = 0;
        _isPending = true;
      }
      return;
    }
    if (!_isPending || _controller.isAnimating) return;
    _isPending = false;
    // Only a chart scrolled into view lingers first; one there as its
    // page arrives, or one whose data the user just changed, starts now.
    _controller.forward(from: isScrolled && !_hasPlayed ? 0 : _dwellShare);
  }

  @override
  void dispose() {
    _route?.removeListener(_queueCheck);
    _position?.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(context, _progress),
    );
  }
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
