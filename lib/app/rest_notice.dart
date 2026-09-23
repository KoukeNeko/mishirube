import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_store.dart';

const _channel = MethodChannel('mishirube/rest_notice');

/// Tells the system about the rest between sets, so it is not missed
/// with the app in the background or the device locked: iOS alerts when
/// it ends (`RestNotice` in `ios/Runner/AppDelegate.swift`), Android
/// shows it counting down (`RestNoticeBridge.kt`). Follows the store's
/// rest wherever it was started, lengthened or cut short.
class RestNotice extends StatefulWidget {
  const RestNotice({super.key, required this.child});

  final Widget child;

  @override
  State<RestNotice> createState() => _RestNoticeState();
}

class _RestNoticeState extends State<RestNotice> {
  DateTime? _scheduled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = AppStoreScope.of(context);
    final endsAt = store.restEndsAt;
    if (endsAt == _scheduled) return;
    _scheduled = endsAt;
    if (endsAt == null) {
      _call('cancel');
    } else {
      final next = store.activeWorkout?.currentExercise.exercise.name;
      _call('schedule', {
        'endsAt': endsAt.millisecondsSinceEpoch.toDouble(),
        'restingTitle': '休息中',
        'endedTitle': '休息結束',
        'body': next == null ? '' : '下一組 · $next',
      });
    }
  }

  static Future<void> _call(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // A Mac, or a test: the rest is only shown in the app.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
