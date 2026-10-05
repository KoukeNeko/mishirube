import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../backend/engines/training_metrics.dart';
import '../domain/domain.dart';
import 'app_store.dart';
import '../l10n/l10n.dart';

const _channel = MethodChannel('mishirube/watch');

/// Keeps a paired watch showing the workout and able to run it: what to
/// do next, the rest, the clock, the exercises, today's workout to start.
/// Apple Watch through `WatchBridge` in `ios/Runner/AppDelegate.swift`
/// (the app in `ios/MishirubeWatch/`), Wear OS through `WearBridge.kt`
/// (the app in `android/wear/`). The watch asks for what a person does
/// on the workout page: log the next set (with its weight and reps as
/// the wrist left them), lengthen or skip the rest, pause, begin, switch
/// exercise, finish. The
/// phone keeps the records, so each request is applied here, as from the
/// page. The watch's heart rate comes back too, as
/// `AppStore.liveHeartRate`.
class WatchSync extends StatefulWidget {
  const WatchSync({super.key, required this.child});

  final Widget child;

  @override
  State<WatchSync> createState() => _WatchSyncState();
}

class _WatchSyncState extends State<WatchSync> {
  String? _sent;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      final store = AppStoreScope.read(context);
      final arguments = switch (call.arguments) {
        final Map<Object?, Object?> map => map,
        _ => const <Object?, Object?>{},
      };
      switch (call.method) {
        case 'logNextSet':
          // A request about a set that has since been done, a tap that came
          // twice or late, would log the one after it.
          final workout = store.activeWorkout;
          final key = arguments['setKey'];
          if (workout != null && key != null && key != setKeyOf(workout)) {
            return;
          }
          // The steppers' figures, when the watch changed them, go in first.
          _editNextSet(store, arguments);
          store.logNextSet();
        case 'extendRest':
          store.extendRest(
            Duration(seconds: (arguments['seconds'] as num).round()),
          );
        case 'skipRest':
          store.skipRest();
        case 'togglePause':
          store.togglePause();
        case 'beginWorkout':
          store.beginWorkout();
        case 'startWorkout':
          store.startWorkout();
        case 'finishWorkout':
          store.finishWorkout();
        case 'selectExercise':
          final index = (arguments['index'] as num).round();
          final count = store.activeWorkout?.exercises.length ?? 0;
          if (index >= 0 && index < count) store.selectExercise(index);
        case 'heartRate':
          store.takeHeartRate(
            (arguments['bpm'] as num).round(),
            DateTime.fromMillisecondsSinceEpoch(
              (arguments['time'] as num).round(),
            ),
          );
      }
    });
  }

  /// Which set is to be done next: the watch sends it back with a request
  /// to log it.
  static String setKeyOf(WorkoutSession workout) =>
      '${workout.currentExerciseIndex}:${workout.completedSets}';

  /// Sets the weight and reps of the set to do next, as the watch's
  /// steppers left them: only the ones it sent.
  static void _editNextSet(AppStore store, Map<Object?, Object?> arguments) {
    if (arguments['weightKg'] == null && arguments['reps'] == null) return;
    final exercise = store.activeWorkout?.currentExercise;
    final index = exercise?.nextSetIndex;
    if (exercise == null || index == null) return;
    final set = exercise.sets[index];
    store.editSet(
      index,
      weightKg: (arguments['weightKg'] as num?)?.toDouble() ?? set.weightKg,
      reps: (arguments['reps'] as num?)?.round() ?? set.reps,
      rir: set.rir,
      seconds: set.durationSeconds,
      meters: set.distanceMeters,
    );
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = stateOf(AppStoreScope.of(context), context.l10n);
    // Compared as text: it holds lists, which `==` would never find equal.
    final encoded = jsonEncode(state);
    if (encoded == _sent) return;
    _sent = encoded;
    _send(state);
  }

  /// The words on the watch, in the app's language: the watch has none of
  /// its own. `{}` in a template is where the watch puts its number.
  static Map<String, String> labelsOf(AppLocalizations l10n) {
    String template(String Function(int number) say) =>
        say(8).replaceFirst('8', '{}');
    return {
      'noWorkout': l10n.watchNoWorkout,
      'notConnected': l10n.watchNotConnected,
      'start': l10n.startExercising,
      'logSet': l10n.watchLogSet,
      'rest': l10n.restTitle,
      'skip': l10n.watchSkip,
      'pause': l10n.commonPause,
      'resume': l10n.commonResume,
      'finish': l10n.finishWorkout,
      'confirmTitle': l10n.sessionEndTitle(session: l10n.moduleTraining),
      'confirmSave': l10n.sessionFinishAndSave,
      'confirmKeep': l10n.sessionKeepGoing(session: l10n.moduleTraining),
      'exercises': l10n.exercisesLabel,
      'controls': l10n.watchControls,
      'restEnded': l10n.restEnded,
      'done': l10n.commonDone,
      'heartRate': l10n.activitySeriesHeartRate,
      'stop': l10n.watchStop,
      'sets': template((number) => l10n.setsCount(count: number)),
      'reps': template((number) => l10n.repsValue(reps: number)),
    };
  }

  /// What the watch shows. Without a workout it is today's one, ready to
  /// start; only the words when there is nothing to start either.
  static Map<String, Object?> stateOf(AppStore store, AppLocalizations l10n) {
    final workout = store.activeWorkout;
    final labels = labelsOf(l10n);
    if (workout == null) {
      final routine = store.selectedRoutine;
      if (routine == null) return {'phase': 'none', 'labels': labels};
      return {
        'phase': 'idle',
        'labels': labels,
        'routine': routine.name,
        'routineSets': routine.totalSets,
        'canStart': store.activeSession == null,
      };
    }
    final exercise = workout.currentExercise;
    final type = exercise.exercise.trackingType;
    final next = exercise.nextSetIndex;
    final set = next == null ? null : exercise.sets[next];
    final now = store.now();
    final elapsed = workout.elapsedAt(now);
    return {
      'labels': labels,
      'phase': workout.isReady
          ? 'ready'
          : workout.isPaused
          ? 'paused'
          : 'running',
      'workout': workout.routineName,
      'exercise': exercise.exercise.name,
      'set': set == null
          ? l10n.commonDone
          : '${set.type == SetType.working ? '' : '${set.type.labelIn(l10n)} · '}'
                '${set.figuresIn(l10n, type)}',
      'progress': l10n.setsProgress(
        done: workout.completedSets,
        total: workout.totalSets,
      ),
      'restEndsAt': store.restEndsAt?.millisecondsSinceEpoch.toDouble(),
      'restLength': store.restEndsAt == null
          ? null
          : store.restLength.inMilliseconds,
      'setEndsAt': store.setTimer?.dueAt?.millisecondsSinceEpoch.toDouble(),
      'hasNext': set != null,
      'setKey': setKeyOf(workout),
      // Running, the clock is the moment it would have started at; held,
      // it is the time so far.
      'clockAt': workout.isPaused
          ? null
          : now.subtract(elapsed).millisecondsSinceEpoch.toDouble(),
      'elapsedMs': workout.isPaused ? elapsed.inMilliseconds : null,
      'index': workout.currentExerciseIndex,
      'exercises': [
        for (final item in workout.exercises)
          {
            'name': item.exercise.name,
            'done': item.completedSets,
            'total': item.sets.length,
          },
      ],
      'weightKg': set != null && type.usesWeight ? set.weightKg : null,
      'reps': set != null && type.usesReps ? set.reps : null,
      'weightStep': plateStepKg,
    };
  }

  static Future<void> _send(Map<String, Object?> state) async {
    try {
      await _channel.invokeMethod<void>('update', state);
    } on MissingPluginException {
      // A Mac or a test: no watch to keep up.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
