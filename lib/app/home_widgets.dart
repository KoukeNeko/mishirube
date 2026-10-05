import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../features/caffeine/caffeine_screen.dart';
import '../features/goal/goal_screen.dart';
import '../features/nutrition/daily_nutrition_screen.dart';
import '../features/sleep/sleep_screen.dart';
import '../features/training/training_screen.dart';
import '../features/water/water_screen.dart';
import '../features/body/body_screen.dart';
import 'app_store.dart';
import 'widget_snapshot.dart';
import '../l10n/l10n.dart';

const _channel = MethodChannel('mishirube/widgets');

/// How long after the last write the snapshot is worked out: a run of
/// writes (a meal's dishes, a health read) is one snapshot.
const _settle = Duration(seconds: 1);

/// Keeps the home-screen widgets in step with the records: their figures
/// are worked out here and handed to the widgets (`WidgetBridge` in
/// `ios/Runner/WidgetBridge.swift`, drawn by `ios/RestActivity/`), which
/// draw them later, with the app closed. A tap on a widget comes back as
/// a link (`mishirube://water`) and opens that page.
class HomeWidgets extends StatefulWidget {
  const HomeWidgets({super.key, required this.child});

  final Widget child;

  @override
  State<HomeWidgets> createState() => _HomeWidgetsState();
}

class _HomeWidgetsState extends State<HomeWidgets> with WidgetsBindingObserver {
  Timer? _pending;

  /// The last snapshot handed over, without its time, so a write that
  /// changed nothing the widgets draw does not reload them.
  String? _sent;

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') _open(call.arguments as String);
    });
    if (_isSupported) _takeLaunchLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    _pending?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read here so a change to the records or the language comes back.
    AppStoreScope.of(context);
    context.l10n;
    _schedule();
  }

  /// Leaving the app is when the widgets are next looked at.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _pending?.cancel();
      _send();
    }
  }

  void _schedule() {
    if (!_isSupported) return;
    _pending?.cancel();
    _pending = Timer(_settle, _send);
  }

  Future<void> _send() async {
    if (!mounted || !_isSupported) return;
    final snapshot = widgetSnapshot(AppStoreScope.read(context), context.l10n);
    final unchanged = Map<String, Object?>.of(snapshot)..remove('generatedAt');
    final key = jsonEncode(unchanged);
    if (key == _sent) return;
    _sent = key;
    try {
      await _channel.invokeMethod<void>('update', jsonEncode(snapshot));
    } on MissingPluginException {
      // A Mac or a test: no widgets to keep up.
    }
  }

  Future<void> _takeLaunchLink() async {
    try {
      final link = await _channel.invokeMethod<String>('takeLaunchLink');
      if (link != null) _open(link);
    } on MissingPluginException {
      // No widgets here.
    }
  }

  static const _tabs = {
    'today': HomeTab.today,
    'log': HomeTab.log,
    'trends': HomeTab.trends,
    'me': HomeTab.me,
  };

  static final _pages = <String, Widget Function()>{
    'nutrition': () => const DailyNutritionScreen(),
    'water': () => const WaterScreen(),
    'caffeine': () => const CaffeineScreen(),
    'sleep': () => const SleepScreen(),
    'weight': () => const BodyScreen(),
    'goal': () => const GoalScreen(),
    'training': () => const TrainingScreen(),
  };

  /// Opens what a widget's link names. The home shell is not there yet
  /// when the app was started by the tap, so it is waited for a few
  /// frames.
  void _open(String link, {int tries = 0}) {
    if (!mounted) return;
    final store = AppStoreScope.read(context);
    final name = Uri.tryParse(link)?.host;
    final page = _pages[name];
    final tab = _tabs[name];
    if (page == null && tab == null) return;
    if (store.opensFromChrome == null) {
      if (tries < 10) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _open(link, tries: tries + 1),
        );
      }
      return;
    }
    store.selectTab(tab ?? HomeTab.today);
    if (page != null) store.openFromChrome(page());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
