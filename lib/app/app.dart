import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/me/privacy_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/home_shell.dart';
import '../shared/toast/toast_host.dart';
import '../shared/window_controls.dart';
import 'app_store.dart';
import 'rest_notice.dart';
import 'watch_sync.dart';
import 'theme.dart';

class MishirubeApp extends StatefulWidget {
  const MishirubeApp({super.key, this.store});

  /// The app passes one backed by the on-device database; without it a
  /// seeded in-memory store is used.
  final AppStore? store;

  @override
  State<MishirubeApp> createState() => _MishirubeAppState();
}

class _MishirubeAppState extends State<MishirubeApp> {
  late final AppStore _store = widget.store ?? AppStore();
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Health Connect opens the app to have it explain what it does with
    // health data; that is the privacy page, on top of whatever is open.
    _store.onHealthPrivacyRequest(_showPrivacy);
  }

  /// The request can come before the first frame, when there is no
  /// navigator to push onto yet.
  void _showPrivacy() {
    final navigator = _navigator.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPrivacy());
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
    );
  }

  @override
  void dispose() {
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStoreScope(
      store: _store,
      child: MaterialApp(
        title: 'MISHIRUBE',
        navigatorKey: _navigator,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('zh', 'TW'),
        builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemOverlayStyle,
          child: WindowControlsScope(
            child: RestNotice(
              child: WatchSync(
                child: ToastHost(child: child ?? const SizedBox.shrink()),
              ),
            ),
          ),
        ),
        home: const _RootGate(),
      ),
    );
  }
}

/// Shows onboarding until the user picks their modules, then the home shell.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final isOnboarded = AppStoreScope.of(context).isOnboarded;
    return isOnboarded ? const HomeShell() : const OnboardingScreen();
  }
}
