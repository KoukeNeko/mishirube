import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';

/// How long each pose shows before the next.
const _poseDuration = Duration(milliseconds: 750);
const _fade = Duration(milliseconds: 250);

/// An exercise shown as the poses of one repetition, played in a loop —
/// down and back up again — for as long as it is on screen; a tap pauses
/// it. With reduced motion the poses stand side by side instead, since
/// the whole movement must be readable without anything moving.
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({super.key, required this.name, required this.frames});

  final String name;

  /// Asset paths of the poses, in order.
  final List<String> frames;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo> {
  Timer? _timer;
  int _step = 0;
  bool _isPaused = false;

  /// The poses there and back: 1, 2, 3, 2, 1, 2 …
  List<int> get _order => [
    for (var i = 0; i < widget.frames.length; i++) i,
    for (var i = widget.frames.length - 2; i > 0; i--) i,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    _timer = prefersReducedMotion(context) || widget.frames.length < 2
        ? null
        : Timer.periodic(_poseDuration, (_) {
            if (!_isPaused) setState(() => _step++);
          });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = widget.frames;
    final label = '${widget.name}示範，${frames.length} 個姿勢';
    if (prefersReducedMotion(context)) {
      return Semantics(
        label: label,
        image: true,
        excludeSemantics: true,
        child: Row(
          children: [
            for (final frame in frames)
              Expanded(child: Image.asset(frame, fit: BoxFit.contain)),
          ],
        ),
      );
    }
    final order = _order;
    final frame = frames[order[_step % order.length]];
    return Semantics(
      label: label,
      image: true,
      button: true,
      value: _isPaused ? '已暫停' : '播放中',
      onTap: () => setState(() => _isPaused = !_isPaused),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _isPaused = !_isPaused),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: AnimatedSwitcher(
                duration: _fade,
                child: Image.asset(
                  frame,
                  key: ValueKey(frame),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
            if (_isPaused)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Icon(
                  Icons.pause_circle_outline,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The credit the demonstration's licence asks for, under the pictures.
class ExerciseDemoCredit extends StatelessWidget {
  const ExerciseDemoCredit({super.key});

  @override
  Widget build(BuildContext context) =>
      const TagWrap(labels: ['圖：Workout Guide／Everkinetic · CC BY-SA 4.0']);
}
