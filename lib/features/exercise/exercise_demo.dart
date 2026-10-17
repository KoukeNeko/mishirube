import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';
import 'exercise_gif_player.dart';

/// How long each pose shows before the next.
const _poseDuration = Duration(milliseconds: 750);
const _fade = Duration(milliseconds: 250);

/// Whether there is a demonstration to show for [exercise]: its poses, or
/// an animation to download.
bool hasExerciseDemo(BuildContext context, ExerciseDefinition exercise) =>
    exercise.frames.isNotEmpty ||
    AppStoreScope.of(context).gifs.has(exercise.id);

/// An exercise's demonstration: the animation when it is on the device,
/// fetched when it is not, and the poses meanwhile and when it cannot be
/// had. A tap pauses it.
class ExerciseDemo extends StatefulWidget {
  const ExerciseDemo({super.key, required this.exercise});

  final ExerciseDefinition exercise;

  @override
  State<ExerciseDemo> createState() => _ExerciseDemoState();
}

class _ExerciseDemoState extends State<ExerciseDemo> {
  File? _gif;
  bool _isLoading = false;
  bool _isPaused = false;
  bool _isStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isStarted) return;
    _isStarted = true;
    // Reduce Motion leaves it standing, as it does the poses.
    _isPaused = prefersReducedMotion(context);
    _gif = AppStoreScope.read(context).gifs.cached(widget.exercise.id);
    if (_gif == null) _fetch();
  }

  Future<void> _fetch() async {
    final gifs = AppStoreScope.read(context).gifs;
    if (!gifs.has(widget.exercise.id)) return;
    setState(() => _isLoading = true);
    final file = await gifs.fetch(widget.exercise.id);
    if (!mounted) return;
    setState(() {
      _gif = file;
      _isLoading = false;
    });
  }

  /// The file on the device is not a picture: it goes, and the poses show.
  void _dropGif() {
    AppStoreScope.read(context).gifs.discard(widget.exercise.id);
    setState(() => _gif = null);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final gif = _gif;
    if (gif != null) {
      return Semantics(
        label: exercise.name,
        image: true,
        button: true,
        value: _isPaused
            ? context.l10n.sessionPausedStatus
            : context.l10n.playing,
        onTap: () => setState(() => _isPaused = !_isPaused),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _isPaused = !_isPaused),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: ExerciseGifPlayer(
                file: gif,
                isPaused: _isPaused,
                onBroken: _dropGif,
              ),
            ),
          ),
        ),
      );
    }
    if (exercise.frames.isNotEmpty) {
      return _PoseDemo(name: exercise.name, frames: exercise.frames);
    }
    // Nothing to show until the download is over.
    return AspectRatio(
      aspectRatio: 1,
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator.adaptive()
            : SecondaryButton(
                label: context.l10n.retry,
                icon: Icons.refresh,
                onPressed: _fetch,
              ),
      ),
    );
  }
}

/// An exercise shown as the poses of one repetition, played in a loop —
/// down and back up again — for as long as it is on screen; a tap pauses
/// it. With reduced motion the poses stand side by side instead, since
/// the whole movement must be readable without anything moving.
class _PoseDemo extends StatefulWidget {
  const _PoseDemo({required this.name, required this.frames});

  final String name;

  /// Asset paths of the poses, in order.
  final List<String> frames;

  @override
  State<_PoseDemo> createState() => _PoseDemoState();
}

class _PoseDemoState extends State<_PoseDemo> {
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
    final label = context.l10n.exerciseDemoLabel(
      name: widget.name,
      count: frames.length,
    );
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
      value: _isPaused
          ? context.l10n.sessionPausedStatus
          : context.l10n.playing,
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

/// The credit the demonstration's licence asks for, under the pictures,
/// and whose they are when they belong to another exercise: a variant
/// shows the movement of the one it is a version of, unless it has an
/// animation of its own.
class ExerciseDemoCredit extends StatelessWidget {
  const ExerciseDemoCredit({super.key, required this.exercise});

  final ExerciseDefinition exercise;

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final hasGif = store.gifs.has(exercise.id);
    final owner = switch (exercise.demoFromId) {
      final id? when !hasGif =>
        store.exercises.where((other) => other.id == id).firstOrNull,
      _ => null,
    };
    return TagWrap(
      labels: [
        if (owner != null) context.l10n.exerciseDemoOf(name: owner.name),
        if (hasGif) context.l10n.exerciseGifCredit,
        if (exercise.frames.isNotEmpty) context.l10n.exerciseDemoCredit,
      ],
    );
  }
}

/// The first pose of an exercise, small, for telling exercises apart in a
/// list: the start of the movement, white line work on the surface the
/// demonstration is drawn for. Decoded at the size it shows, so a list of
/// a thousand does not hold a thousand full pictures.
class ExerciseThumb extends StatelessWidget {
  const ExerciseThumb({super.key, required this.frames});

  static const size = 44.0;

  final List<String> frames;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: frames.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: Image.asset(
                  frames.first,
                  fit: BoxFit.contain,
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
              ),
      ),
    );
  }
}
