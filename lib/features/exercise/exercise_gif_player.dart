import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A frame this long is the movement's rest, not a step of it, and stays
/// as it is.
const _hold = Duration(milliseconds: 400);

/// What a browser does with a frame that says no delay at all.
const _defaultDelay = Duration(milliseconds: 100);

/// Which frame an animation is on at [time] into its loop, and how far on
/// the way to the next: during a step of the movement the picture runs from
/// one frame to the next in step with the clock, so it moves at the
/// screen's rate and not the file's (ExerciseDB's are 12 frames at 10 per
/// second). A rest is not run through, or the figure would slide while it
/// should stand.
({int frame, double toNext}) gifPosition(List<Duration> delays, Duration time) {
  final steps = [
    for (final delay in delays)
      delay <= const Duration(milliseconds: 10) ? _defaultDelay : delay,
  ];
  final total = steps.fold(Duration.zero, (sum, step) => sum + step);
  if (steps.length < 2 || total == Duration.zero) return (frame: 0, toNext: 0);
  var rest = Duration(microseconds: time.inMicroseconds % total.inMicroseconds);
  for (final (index, step) in steps.indexed) {
    if (rest < step) {
      final isRest = step >= _hold;
      return (
        frame: index,
        toNext: isRest ? 0 : rest.inMicroseconds / step.inMicroseconds,
      );
    }
    rest -= step;
  }
  return (frame: 0, toNext: 0);
}

/// An animated GIF played with [gifPosition], looping while it is not
/// [isPaused]. A file that cannot be read as a picture is reported by
/// [onBroken] and not drawn.
class ExerciseGifPlayer extends StatefulWidget {
  const ExerciseGifPlayer({
    super.key,
    required this.file,
    required this.isPaused,
    required this.onBroken,
  });

  final File file;
  final bool isPaused;
  final VoidCallback onBroken;

  @override
  State<ExerciseGifPlayer> createState() => _ExerciseGifPlayerState();
}

class _ExerciseGifPlayerState extends State<ExerciseGifPlayer>
    with SingleTickerProviderStateMixin {
  final _frames = <ui.Image>[];
  var _delays = <Duration>[];
  AnimationController? _clock;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final frames = <ui.Image>[];
    final delays = <Duration>[];
    try {
      final codec = await ui.instantiateImageCodec(
        await widget.file.readAsBytes(),
      );
      for (var i = 0; i < codec.frameCount; i++) {
        final info = await codec.getNextFrame();
        frames.add(info.image);
        delays.add(info.duration);
      }
      codec.dispose();
    } on Exception {
      for (final frame in frames) {
        frame.dispose();
      }
      frames.clear();
    }
    if (frames.isEmpty) {
      // A cached file that is not a picture (cut off, or replaced): the
      // owner drops it so the next time fetches it again.
      if (mounted) widget.onBroken();
      return;
    }
    if (!mounted) {
      for (final frame in frames) {
        frame.dispose();
      }
      return;
    }
    final loop = delays.fold(Duration.zero, (sum, delay) => sum + delay);
    setState(() {
      _frames.addAll(frames);
      _delays = delays;
      _clock = AnimationController(
        vsync: this,
        duration: loop == Duration.zero ? _defaultDelay : loop,
      );
      if (!widget.isPaused) _clock!.repeat();
    });
  }

  @override
  void didUpdateWidget(ExerciseGifPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clock = _clock;
    if (clock == null || oldWidget.isPaused == widget.isPaused) return;
    widget.isPaused ? clock.stop() : clock.repeat();
  }

  @override
  void dispose() {
    _clock?.dispose();
    for (final frame in _frames) {
      frame.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = _clock;
    if (clock == null) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _GifPainter(_frames, _delays, clock),
    );
  }
}

class _GifPainter extends CustomPainter {
  _GifPainter(this.frames, this.delays, this.clock) : super(repaint: clock);

  final List<ui.Image> frames;
  final List<Duration> delays;
  final AnimationController clock;

  @override
  void paint(Canvas canvas, Size size) {
    final time = (clock.duration ?? Duration.zero) * clock.value;
    final at = gifPosition(delays, time);
    void draw(ui.Image image, {double opacity = 1}) {
      // A square picture in a square box; fitted, not stretched, if not.
      final scale = size.shortestSide / image.width;
      final shown = Size(image.width * scale, image.height * scale);
      canvas.drawImageRect(
        image,
        Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
        Alignment.center.inscribe(shown, Offset.zero & size),
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }

    draw(frames[at.frame]);
    if (at.toNext > 0) {
      draw(frames[(at.frame + 1) % frames.length], opacity: at.toNext);
    }
  }

  @override
  bool shouldRepaint(_GifPainter oldDelegate) =>
      oldDelegate.frames != frames || oldDelegate.delays != delays;
}
