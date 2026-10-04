import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_store.dart';
import '../l10n/l10n.dart';

const _channel = MethodChannel('mishirube/rest_notice');

Future<void> _call(String method, [Object? arguments]) async {
  try {
    await _channel.invokeMethod<void>(method, arguments);
  } on MissingPluginException {
    // A Mac, or a test: the rest is only shown in the app.
  }
}

/// A short sound for a rest or a timed set running out or about to, next to
/// the vibration, when the user has it on; the system's own, so it mixes
/// with music and keeps to the silent switch.
Future<void> playCue(AppStore store) async {
  if (store.isCueSound) await _call('cue');
}

/// Tells the system about the rest between sets and the set being timed,
/// so neither is missed with the app in the background or the device
/// locked: iOS alerts when they end (`RestNotice` in
/// `ios/Runner/AppDelegate.swift`) and shows the rest as a Live Activity,
/// Android shows the rest counting down and alerts when it ends
/// (`RestNoticeBridge.kt`). Follows the store's rest and timer wherever
/// they were started, lengthened or cut short, and settles both when the
/// app comes back to the front.
class RestNotice extends StatefulWidget {
  const RestNotice({super.key, required this.child});

  final Widget child;

  @override
  State<RestNotice> createState() => _RestNoticeState();
}

class _RestNoticeState extends State<RestNotice> with WidgetsBindingObserver {
  /// What the system was last told: nothing yet, so the first look at the
  /// store clears whatever an earlier run left behind.
  bool _isSynced = false;
  DateTime? _restEndsAt;
  DateTime? _restEndedAt;
  DateTime? _setEndsAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'skip' && mounted) {
        AppStoreScope.read(context).skipRest();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  /// Time may have run out while the app was away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final store = AppStoreScope.read(context);
    store.settleSetTimer();
    store.settleRest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppStoreScope.of(context);
    _syncRest(store);
    _syncSet(store);
    _isSynced = true;
  }

  void _syncRest(AppStore store) {
    final endsAt = store.restEndsAt;
    final endedAt = store.restEndedAt;
    if (_isSynced && endsAt == _restEndsAt && endedAt == _restEndedAt) return;
    final wasRunning = _restEndsAt != null;
    _restEndsAt = endsAt;
    _restEndedAt = endedAt;
    if (endsAt != null) {
      final l10n = context.l10n;
      final next = store.activeWorkout?.currentExercise.nextSetIn(l10n);
      _call('schedule', {
        'endsAt': endsAt.millisecondsSinceEpoch.toDouble(),
        'restingTitle': l10n.restResting,
        'endedTitle': l10n.restEnded,
        'skipLabel': l10n.skipRest,
        'body': next == null ? '' : l10n.restNextSet(set: next),
      });
    } else if (endedAt != null && wasRunning) {
      // Ran out: the alert is on its way or delivered, and stays.
      _call('ended');
    } else {
      _call('cancel');
    }
  }

  void _syncSet(AppStore store) {
    final timer = store.setTimer;
    final endsAt = timer?.dueAt;
    if (_isSynced && endsAt == _setEndsAt) return;
    final scheduled = _setEndsAt;
    _setEndsAt = endsAt;
    if (endsAt != null) {
      final exercise = store.activeWorkout?.exercises.firstWhere(
        (exercise) => exercise.sets.any((set) => identical(set, timer!.set)),
      );
      _call('scheduleSet', {
        'endsAt': endsAt.millisecondsSinceEpoch.toDouble(),
        'title': exercise?.exercise.name ?? '',
        'endedTitle': context.l10n.restEnded,
        'body': context.l10n.commonDone,
      });
    } else if (scheduled == null || scheduled.isAfter(store.now())) {
      // Stopped early or held, or nothing to clear but what a run left.
      // One that came due is let be: its alert is the user's to dismiss.
      _call('cancelSet');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
