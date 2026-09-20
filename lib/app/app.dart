import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/home_shell.dart';
import '../shared/toast/toast_host.dart';
import 'app_store.dart';
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
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('zh', 'TW'),
        builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemOverlayStyle,
          child: ToastHost(child: child ?? const SizedBox.shrink()),
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
