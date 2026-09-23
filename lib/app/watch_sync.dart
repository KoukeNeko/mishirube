import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../domain/domain.dart';
import '../shared/format.dart';
import 'app_store.dart';

const _channel = MethodChannel('mishirube/watch');

/// Keeps a paired watch showing the running workout: the exercise, the
/// set to do and the rest (`WatchBridge` in `ios/Runner/AppDelegate.swift`,
/// the app in `ios/MishirubeWatch/`). A set logged on the watch comes
/// back here and is logged as from the workout page.
class WatchSync extends StatefulWidget {
  const WatchSync({super.key, required this.child});

  final Widget child;

  @override
  State<WatchSync> createState() => _WatchSyncState();
}

class _WatchSyncState extends State<WatchSync> {
  Map<String, Object?>? _sent;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'logNextSet' && mounted) {
        AppStoreScope.read(context).logNextSet();
      }
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = _stateOf(AppStoreScope.of(context));
    if (_same(state, _sent)) return;
    _sent = state;
    _send(state);
  }

  /// What the watch shows; an empty map when no workout runs.
  static Map<String, Object?> _stateOf(AppStore store) {
    final workout = store.activeWorkout;
    if (workout == null) return const {};
    final exercise = workout.currentExercise;
    final next = exercise.nextSetIndex;
    final set = next == null ? null : exercise.sets[next];
    return {
      'workout': workout.routineName,
      'exercise': exercise.exercise.name,
      'set': set == null
          ? '完成'
          : '${set.type == SetType.working ? '' : '${set.type.label} · '}'
                '${formatWeight(set.weightKg)} kg × ${set.reps}',
      'progress': '${workout.completedSets} / ${workout.totalSets} 組',
      'restEndsAt': store.restEndsAt?.millisecondsSinceEpoch.toDouble(),
      'hasNext': set != null,
    };
  }

  static bool _same(Map<String, Object?> a, Map<String, Object?>? b) =>
      b != null &&
      a.length == b.length &&
      a.entries.every((entry) => b[entry.key] == entry.value);

  static Future<void> _send(Map<String, Object?> state) async {
    try {
      await _channel.invokeMethod<void>('update', state);
    } on MissingPluginException {
      // Android, a Mac or a test: no watch to keep up.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
