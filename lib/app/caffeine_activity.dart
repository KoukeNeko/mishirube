import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../backend/engines/caffeine.dart';
import '../domain/domain.dart';
import '../shared/format.dart';
import 'app_store.dart';
import '../l10n/l10n.dart';

const _channel = MethodChannel('mishirube/caffeine_activity');

/// The time shown is rounded up to this: the caffeine curve is drawn in
/// ten-minute steps, and the estimate is no finer than that.
const _step = Duration(minutes: 10);

/// Puts caffeine over the bedtime reference on the lock screen and in the
/// Dynamic Island, with the time it falls under it (`CaffeineActivity`
/// in `ios/Runner/AppDelegate.swift`). Another cup moves the time; the
/// app coming back ends one whose time has passed, or starts it again
/// after the system ended it. One swiped away stays away until a later
/// cup, which the native side keeps track of; one ended from 今天
/// ([CaffeineActivityScope.end]) likewise, kept with the records.
class CaffeineActivity extends StatefulWidget {
  const CaffeineActivity({super.key, required this.child});

  final Widget child;

  /// Live Activities are iOS's alone.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  State<CaffeineActivity> createState() => _CaffeineActivityState();
}

class _CaffeineActivityState extends State<CaffeineActivity>
    with WidgetsBindingObserver {
  /// What was last handed over, so a write that changed nothing shown
  /// does not update the activity.
  String? _sent;

  /// The cup the activity is for, and whether the system is showing it.
  DateTime? _cupAt;
  bool _isShowing = false;

  /// Counts the calls made, so only the latest one's answer is kept.
  int _calls = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here so a change to the records or the language comes back.
    AppStoreScope.of(context);
    context.l10n;
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _update(force: true);
  }

  void _update({bool force = false}) {
    if (!CaffeineActivity.isSupported) return;
    final store = AppStoreScope.read(context);
    final backend = store.backend;
    final endedFor = backend.nutrition.caffeineActivityEndedFor;
    final over =
        store.enabledModules.contains(AppModule.nutrition) &&
            backend.nutrition.isCaffeineActivityOn
        ? switch (backend.nutrition.caffeineOverReference()) {
            final over? when endedFor == null || over.at.isAfter(endedFor) =>
              over,
            _ => null,
          }
        : null;
    final arguments = over == null
        ? null
        : _arguments(over, backend.sleep.tonightPlan()?.bedtime);
    final key = jsonEncode(arguments);
    if (key == _sent && !force) return;
    _sent = key;
    _cupAt = over?.at;
    _call(arguments);
  }

  /// Ends the activity for the cup it is for, until a later one.
  void _end() {
    if (_cupAt case final cupAt?) {
      AppStoreScope.read(context).backend.nutrition.endCaffeineActivity(cupAt);
    }
  }

  Map<String, Object?> _arguments(
    ({DateTime at, MealEvent meal, DateTime below}) over,
    DateTime? bedtime,
  ) {
    final l10n = context.l10n;
    final below = _roundedUp(over.below);
    // Only a bedtime the caffeine is still over the reference at: one
    // after the time it falls under says nothing the time does not.
    final shownBedtime =
        bedtime != null && bedtime.isAfter(over.at) && bedtime.isBefore(below)
        ? bedtime
        : null;
    final milligrams = over.meal.nutrients[Nutrient.caffeine]!;
    return {
      'cupAt': over.at.millisecondsSinceEpoch.toDouble(),
      'belowAt': below.millisecondsSinceEpoch.toDouble(),
      'bedtimeAt': shownBedtime?.millisecondsSinceEpoch.toDouble(),
      'title': l10n.nutrientCaffeine,
      'cup': '${over.meal.name} · ${withUnit(formatAmount(milligrams), 'mg')}',
      'cupTime': formatTimeOfDay(over.at),
      'belowLabel': l10n.caffeineBelowReference,
      'belowDoneLabel': l10n.caffeineBelowReferenceDone,
      'belowTime': formatTimeOfDay(below),
      'bedtime': shownBedtime == null
          ? null
          : '${l10n.suggestedBedtime} ${formatTimeOfDay(shownBedtime)}',
      'basis': l10n.halfLifeBasis(hours: formatAmount(caffeineHalfLifeHours)),
    };
  }

  /// [at] on the next ten minutes of the clock, as read where the user is.
  static DateTime _roundedUp(DateTime at) {
    final floor = DateTime(
      at.year,
      at.month,
      at.day,
      at.hour,
      at.minute - at.minute % _step.inMinutes,
    );
    return floor == at ? at : floor.add(_step);
  }

  /// Shows [arguments], or ends the activity when there are none, and
  /// keeps whether the system shows it: it may not, swiped away or with
  /// Live Activities turned off in Settings.
  Future<void> _call(Map<String, Object?>? arguments) async {
    final call = ++_calls;
    bool isShowing;
    try {
      isShowing = arguments == null
          ? await _channel.invokeMethod<void>('end').then((_) => false)
          : await _channel.invokeMethod<bool>('show', arguments) ?? false;
    } on MissingPluginException {
      // A Mac, or a test: the caffeine is only shown in the app.
      isShowing = false;
    }
    if (!mounted || call != _calls || isShowing == _isShowing) return;
    setState(() => _isShowing = isShowing);
  }

  @override
  Widget build(BuildContext context) => CaffeineActivityScope._(
    isShowing: _isShowing,
    end: _end,
    child: widget.child,
  );
}

/// Whether caffeine is on the lock screen now, for 今天 to offer to end
/// it there.
class CaffeineActivityScope extends InheritedWidget {
  const CaffeineActivityScope._({
    required this.isShowing,
    required this.end,
    required super.child,
  });

  final bool isShowing;

  /// Ends it for the cup it is for; the next cup shows it again.
  final VoidCallback end;

  /// Null outside the app, where there is no lock screen to show it on.
  static CaffeineActivityScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CaffeineActivityScope>();

  @override
  bool updateShouldNotify(CaffeineActivityScope oldWidget) =>
      isShowing != oldWidget.isShowing;
}
