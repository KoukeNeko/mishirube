import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../motion.dart';

/// Water in a box seen side on, simulated with the one-dimensional
/// shallow water (Saint-Venant) equations: the depth of each column and
/// the flow between neighbours, carried along by itself, so a wave
/// steepens as it runs and piles up where it meets a wall. Gravity has a
/// part down the screen, which levels the surface, and a part across it,
/// from tilting or shaking the device, which pushes the water to one side.
///
/// Where the surface rises fast enough it throws off drops, which fly
/// under the same gravity and fall back in. Written in flux form, with
/// each drop carrying the water it left with, so water is only ever
/// moved, never made or lost.
///
/// Lengths are in logical pixels and times in seconds.
class ShallowWater {
  ShallowWater({
    required this.width,
    required this.height,
    required double level,
    this.columns = 72,
    int? seed,
  }) : depth = List.filled(columns, level.clamp(0, 1) * height),
       _flow = List.filled(columns + 1, 0),
       _calm = List.filled(columns, 0),
       _random = math.Random(seed);

  final double width;
  final double height;
  final int columns;

  /// Each column's depth, left to right.
  final List<double> depth;

  /// The horizontal velocity at each face between columns, left to right;
  /// the two ends are walls, where it is always zero.
  final List<double> _flow;

  /// Drops in the air.
  final List<WaterDrop> drops = [];

  /// How long each column waits, in seconds, before it can throw a drop:
  /// set where one just left or landed, so a drop's own ripple does not
  /// throw the next, which would keep the water splashing forever.
  final List<double> _calm;
  static const _calmAfter = 0.3;

  /// A landing drop's water is spread over this many columns each side,
  /// as a drop's splash spreads, instead of standing as a spike.
  static const _landingSpread = 3;
  final math.Random _random;

  /// A drop's radius, and so the water it carries.
  static const dropRadius = 1.6;
  static const _dropArea = math.pi * dropRadius * dropRadius;

  /// How fast the surface has to rise, in px/s, to throw a drop off.
  static const _sprayFrom = 110.0;

  /// The most drops in the air at once.
  static const _mostDrops = 36;

  /// Water still to be poured in, or drained out when negative, as area.
  double _pending = 0;
  double _pourRate = 0;

  /// How long pouring the difference takes.
  static const pourTime = 0.7;

  /// Drag against the walls and within the water, per second: what
  /// brings the sloshing to rest.
  static const drag = 1.4;

  /// Spreads a sharp change in velocity across neighbours, in px²/s,
  /// the way viscosity does: enough to keep the steps stable, little
  /// enough to leave the ripples on the surface.
  static const viscosity = 80.0;

  /// The longest step the equations are advanced by at once; a frame is
  /// split into as many as it takes.
  static const maxStep = 1 / 300;

  double get columnWidth => width / columns;

  /// How much water there is, as area, the drops in the air included.
  double get volume =>
      depth.fold(0.0, (sum, d) => sum + d) * columnWidth +
      drops.fold(0.0, (sum, drop) => sum + drop.area);

  /// Whether nothing is moving: no flow to speak of, nothing being
  /// poured and no drop in the air.
  bool isStill({double below = 0.5}) =>
      speed < below && !isPouring && drops.isEmpty;

  /// The fastest the water moves anywhere, in px/s.
  double get speed => _flow.fold(0.0, (most, u) => math.max(most, u.abs()));

  bool get isPouring => _pending != 0;

  /// Pours in, or drains, until the water stands at [level] of the height.
  void pourTo(double level) {
    _pending = level.clamp(0, 1) * height * width - volume;
    _pourRate = _pending.abs() / pourTime;
  }

  /// Advances by [dt] under gravity in px/s²: [down] towards the bottom
  /// of the screen, [right] towards its right edge.
  void step(double dt, {required double down, required double right}) {
    // Short enough that no wave crosses more than a third of a column
    // in a step (the CFL condition) and viscosity cannot overshoot:
    // longer, and the equations blow up instead of the water moving.
    final deepest = depth.fold(0.0, math.max);
    final wave = math.sqrt(math.max(down, 0) * deepest) + speed;
    final longest = [
      maxStep,
      if (wave > 0) columnWidth / (3 * wave),
      columnWidth * columnWidth / (4 * viscosity),
    ].reduce(math.min);
    final steps = math.max(1, (dt / longest).ceil());
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      _pour(h);
      final before = List<double>.of(depth);
      _advance(h, down, right);
      _spray(h, before);
      _fly(h, down, right);
    }
  }

  /// Throws a drop off where the surface is rising fast: most often at a
  /// wall a wave has run into, or where two meet.
  void _spray(double h, List<double> before) {
    for (var i = 0; i < columns; i++) {
      if (_calm[i] > 0) {
        _calm[i] -= h;
        continue;
      }
      if (drops.length >= _mostDrops) continue;
      final rising = (depth[i] - before[i]) / h;
      if (rising < _sprayFrom) continue;
      // The faster it rises, the likelier a drop, a few a second at most.
      if (_random.nextDouble() > (rising - _sprayFrom) * h * 0.08) continue;
      final area = math.min(_dropArea, depth[i] * columnWidth * 0.05);
      if (area <= 0) continue;
      depth[i] -= area / columnWidth;
      _calm[i] = _calmAfter;
      final across = (_flow[i] + _flow[i + 1]) / 2;
      drops.add(
        WaterDrop(
          x: (i + 0.5) * columnWidth,
          y: height - depth[i],
          vx: across + (_random.nextDouble() - 0.5) * 40,
          vy: -rising * (0.8 + _random.nextDouble() * 0.6),
          area: area,
        ),
      );
    }
  }

  /// Moves each drop under gravity until it falls back into the water,
  /// giving its water back to the column it lands in.
  void _fly(double h, double down, double right) {
    for (var d = drops.length - 1; d >= 0; d--) {
      final drop = drops[d]
        ..vx += right * h
        ..vy += down * h;
      drop
        ..x += drop.vx * h
        ..y += drop.vy * h;
      if (drop.x < dropRadius || drop.x > width - dropRadius) {
        drop
          ..x = drop.x.clamp(dropRadius, width - dropRadius)
          ..vx *= -0.3;
      }
      if (drop.y < dropRadius) {
        drop
          ..y = dropRadius
          ..vy = 0;
      }
      final column = (drop.x / columnWidth).floor().clamp(0, columns - 1);
      if (drop.vy > 0 && drop.y >= height - depth[column]) {
        final first = math.max(0, column - _landingSpread);
        final last = math.min(columns - 1, column + _landingSpread);
        for (var i = first; i <= last; i++) {
          depth[i] += drop.area / ((last - first + 1) * columnWidth);
          _calm[i] = _calmAfter;
        }
        drops.removeAt(d);
      }
    }
  }

  /// Water arrives in the middle quarter, as from a glass held above; it
  /// leaves evenly, as through the bottom.
  void _pour(double h) {
    if (_pending == 0) return;
    final amount = _pending > 0
        ? math.min(_pending, _pourRate * h)
        : math.max(_pending, -_pourRate * h);
    _pending -= amount;
    if (amount > 0) {
      final first = columns * 3 ~/ 8;
      final last = columns * 5 ~/ 8;
      for (var i = first; i < last; i++) {
        depth[i] += amount / ((last - first) * columnWidth);
      }
    } else {
      for (var i = 0; i < columns; i++) {
        depth[i] = math.max(0, depth[i] + amount / width);
      }
    }
  }

  void _advance(double h, double down, double right) {
    final dx = columnWidth;
    // Momentum: the surface's slope drives the water downhill, gravity
    // across the screen pushes it sideways, the water carries its own
    // speed along (taken upstream), and drag and viscosity slow it.
    final previous = List<double>.of(_flow);
    for (var f = 1; f < columns; f++) {
      final u = previous[f];
      final slope = (depth[f] - depth[f - 1]) / dx;
      final spread = (previous[f - 1] - 2 * u + previous[f + 1]) / (dx * dx);
      final carried = u > 0
          ? u * (u - previous[f - 1]) / dx
          : u * (previous[f + 1] - u) / dx;
      _flow[f] =
          (u + h * (-down * slope + right - carried + viscosity * spread)) *
          (1 - drag * h);
    }
    // Mass: what crosses each face, carried at the depth it comes from
    // and never more than that column holds.
    final flux = List<double>.filled(columns + 1, 0);
    for (var f = 1; f < columns; f++) {
      final u = _flow[f];
      final from = u > 0 ? f - 1 : f;
      final most = depth[from] * dx / (2 * h);
      flux[f] = (u * depth[from]).clamp(-most, most);
    }
    for (var i = 0; i < columns; i++) {
      depth[i] = math.max(0, depth[i] - h * (flux[i + 1] - flux[i]) / dx);
    }
  }
}

/// A drop thrown off the surface, flying until it falls back in.
class WaterDrop {
  WaterDrop({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.area,
  });

  double x;
  double y;
  double vx;
  double vy;

  /// The water it carries, as area.
  final double area;
}

/// A level rising from the bottom to [level] of the height, drawn behind
/// what sits on it: how full something is. Past 1 it stays full, neither
/// overflowing nor changing colour.
///
/// The water is simulated ([ShallowWater]). A change of [level] is
/// poured in and ripples out; given the device's [motion], tilting it
/// lets the water run to the low side until its surface is level with
/// the ground, and a shake sets it sloshing against the sides until drag
/// brings it to rest. Once still it stops redrawing, so a tile left on
/// screen costs nothing. With Reduce Motion it is drawn still and flat.
class LevelFill extends StatefulWidget {
  const LevelFill({
    super.key,
    required this.level,
    required this.color,
    this.motion,
  });

  final double level;
  final Color color;

  /// Acceleration across the screen, gravity included, in m/s²: x to the
  /// right, y towards the top edge.
  final Stream<Offset>? motion;

  @override
  State<LevelFill> createState() => _LevelFillState();
}

class _LevelFillState extends State<LevelFill>
    with SingleTickerProviderStateMixin {
  /// Logical pixels to a metre, as the water feels gravity: chosen so a
  /// wave crosses a Today tile in about a third of a second, as it would
  /// in a glass a hand's width across.
  static const _pixelsPerMetre = 360.0;

  /// Down the screen, gravity never counts for less than this, in m/s²,
  /// so a device lying flat still holds its water level.
  static const _leastDown = 3.0;

  /// How much a new reading counts against the smoothed one: enough to
  /// follow a shake, little enough to hide the sensor's jitter.
  static const _smoothing = 0.35;

  /// Below these the water is taken to be at rest: a flow in px/s, and a
  /// change of lean since it came to rest.
  static const _restingSpeed = 0.5;
  static const _nudge = 0.01;

  late final Ticker _ticker = createTicker(_tick);
  StreamSubscription<Offset>? _subscription;
  ShallowWater? _water;

  /// Acceleration as the water feels it, smoothed; upright and still
  /// until the first reading.
  Offset _felt = const Offset(0, 9.8);

  /// The lean ([_lean]) the water last came to rest at.
  double _restingLean = 0;
  Duration _lastTick = Duration.zero;

  bool get _isStill => prefersReducedMotion(context);

  double get _level => widget.level.clamp(0.0, 1.0);

  /// Across over down: the slope a surface at rest takes.
  double _lean(Offset felt) => -felt.dx / math.max(felt.dy, _leastDown);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listen();
  }

  @override
  void didUpdateWidget(LevelFill old) {
    super.didUpdateWidget(old);
    if (widget.level != old.level) {
      final water = _water;
      if (water == null || _isStill) {
        _water = null;
      } else {
        water.pourTo(_level);
        _start();
      }
    }
    if (old.motion != widget.motion) {
      _subscription?.cancel();
      _subscription = null;
      _listen();
    }
  }

  void _listen() {
    if (_subscription != null || widget.motion == null || _isStill) return;
    var isFirst = true;
    _subscription = widget.motion!.listen((reading) {
      if (isFirst) {
        // Where the device already is, not a jolt.
        isFirst = false;
        _felt = reading;
        _restingLean = _lean(reading);
        _settleTo(_restingLean);
        return;
      }
      _felt = _felt + (reading - _felt) * _smoothing;
      final shake = (reading - _felt).dx.abs();
      if ((_lean(_felt) - _restingLean).abs() > _nudge || shake > 1) {
        _start();
      }
    });
  }

  /// Lays the water at rest at [lean] at once, as it would already be.
  void _settleTo(double lean) {
    final water = _water;
    if (water == null) return;
    _layAt(water, lean);
    setState(() {});
  }

  static void _layAt(ShallowWater water, double lean) {
    final mean = water.volume / water.width;
    for (var i = 0; i < water.columns; i++) {
      final x = (i + 0.5) * water.columnWidth - water.width / 2;
      water.depth[i] = math.max(0, mean + x * lean);
    }
  }

  void _start() {
    if (_ticker.isActive || _water == null) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final water = _water;
    if (water == null) return;
    final dt = math.min(
      (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond,
      1 / 30,
    );
    _lastTick = elapsed;
    if (dt <= 0) return;
    water.step(
      dt,
      down: math.max(_felt.dy, _leastDown) * _pixelsPerMetre,
      right: -_felt.dx * _pixelsPerMetre,
    );
    setState(() {});
    if (water.isStill(below: _restingSpeed)) {
      _restingLean = _lean(_felt);
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
  Widget build(BuildContext context) => ExcludeSemantics(
    // Its own layer: a tick redraws the water, not the page around it,
    // which would otherwise be drawn again every frame the water moves.
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final water = _water;
          if (water == null ||
              water.width != size.width ||
              water.height != size.height) {
            // Laid at the lean the device already has, not flat.
            _water = ShallowWater(
              width: size.width,
              height: size.height,
              level: _level,
            );
            _layAt(_water!, _restingLean);
          }
          return CustomPaint(
            painter: _WaterPainter(
              depth: List.of(_water!.depth),
              drops: [for (final drop in _water!.drops) Offset(drop.x, drop.y)],
              color: widget.color,
            ),
            size: size,
          );
        },
      ),
    ),
  );
}

class _WaterPainter extends CustomPainter {
  _WaterPainter({
    required this.depth,
    required this.drops,
    required this.color,
  });

  final List<double> depth;
  final List<Offset> drops;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final drop in drops) {
      canvas.drawCircle(
        drop,
        ShallowWater.dropRadius,
        Paint()..color = color.withValues(alpha: 0.6),
      );
    }
    if (depth.every((d) => d <= 0)) return;
    final dx = size.width / depth.length;
    Offset at(int i) => Offset((i + 0.5) * dx, size.height - depth[i]);
    // A smooth surface through the columns: each curve runs from one
    // midpoint to the next, bending at the column between.
    final surface = Path()..moveTo(0, size.height - depth.first);
    for (var i = 0; i < depth.length - 1; i++) {
      final mid = (at(i) + at(i + 1)) / 2;
      surface.quadraticBezierTo(at(i).dx, at(i).dy, mid.dx, mid.dy);
    }
    surface.lineTo(size.width, size.height - depth.last);
    final water = Path.from(surface)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    // Lighter near the surface, where light comes through, deeper below.
    final surfaceTop = size.height - depth.reduce(math.max);
    canvas.drawPath(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.14)],
        ).createShader(Rect.fromLTRB(0, surfaceTop, size.width, size.height)),
    );
    canvas.drawPath(
      surface,
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_WaterPainter old) =>
      old.color != color ||
      !_sameDepths(old.depth, depth) ||
      old.drops.length != drops.length ||
      drops.isNotEmpty;

  static bool _sameDepths(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
