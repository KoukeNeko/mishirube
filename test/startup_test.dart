import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/app/home_widgets.dart';
import 'package:mishirube/app/startup.dart';
import 'package:mishirube/app/watch_sync.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/backend/storage/storage_access.dart';
import 'package:mishirube/features/onboarding/onboarding_screen.dart';
import 'package:mishirube/l10n/l10n.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

void main() {
  late Directory directory;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const appInfo = MethodChannel('mishirube/app_info');
  setUp(() {
    directory = Directory.systemTemp.createTempSync('mishirube_startup_');
    messenger.setMockMethodCallHandler(paths, (_) async => directory.path);
    messenger.setMockMethodCallHandler(
      appInfo,
      (_) async => {'version': '1.0.0', 'build': '1'},
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(paths, null);
    messenger.setMockMethodCallHandler(appInfo, null);
    messenger.setMockMethodCallHandler(StorageAccess.channel, null);
    debugDefaultTargetPlatformOverride = null;
    directory.deleteSync(recursive: true);
  });

  StorageAccess accessFor(TargetPlatform platform) {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = platform;
    final access = StorageAccess();
    debugDefaultTargetPlatformOverride = previous;
    addTearDown(access.dispose);
    return access;
  }

  Future<void> availability(WidgetTester tester, bool value) async {
    await messenger.handlePlatformMessage(
      StorageAccess.channel.name,
      StorageAccess.channel.codec.encodeMethodCall(
        MethodCall('availabilityChanged', value),
      ),
      (_) {},
    );
    await tester.pump();
  }

  void expectNoApp() {
    expect(find.byType(MishirubeApp), findsNothing);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeWidgets), findsNothing);
    expect(find.byType(WatchSync), findsNothing);
    expect(find.byType(AppStoreScope), findsNothing);
  }

  DatabaseOpenFailure failure(DatabaseFailureKind kind) => DatabaseOpenFailure(
    kind: kind,
    stage: DatabaseOpenStage.opening,
    cause: StateError('synthetic open failure'),
    stackTrace: StackTrace.current,
    existingFile: true,
  );

  testWidgets(
    'failure has no app side effects; retry opens the original store once',
    (tester) async {
      usePhoneViewport(tester);
      final access = accessFor(TargetPlatform.android);
      final path = '${directory.path}/store.sqlite3';
      AppDatabase.open(path)
        ..setSetting('probe', 'original')
        ..close();
      final pending = Completer<AppStore>();
      var opens = 0;
      var ready = 0;
      await tester.pumpWidget(
        AppStartup(
          storageAccess: access,
          openStore: () async {
            opens++;
            if (opens == 1) throw failure(DatabaseFailureKind.busy);
            return pending.future;
          },
          onReady: (_) => ready++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(testL10n.startupFailed), findsOneWidget);
      expectNoApp();
      expect(ready, 0);
      await tester.tap(find.text(testL10n.retry));
      await tester.tap(find.text(testL10n.retry));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(opens, 2, reason: 'retry and foreground join one initialization');
      expectNoApp();
      expect(find.byType(PrimaryButton), findsNothing);
      final backend = Backend(AppDatabase.open(path));
      final store = AppStore(
        backend: backend,
        clock: FakeClock().now,
        isOnboarded: true,
      );
      pending.complete(store);
      await tester.pumpAndSettle();
      expect(find.byType(MishirubeApp), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(store.backend.db.setting('probe'), 'original');
      expect(ready, 1);
      await disposeTree(tester);
      expect(
        () => backend.db.setting('probe'),
        throwsStateError,
        reason: 'startup owns and closes the successful backend',
      );
    },
  );

  testWidgets(
    'locked storage waits; unlock and foreground create only one store',
    (tester) async {
      usePhoneViewport(tester);
      final access = accessFor(TargetPlatform.iOS);
      var available = false;
      messenger.setMockMethodCallHandler(
        StorageAccess.channel,
        (_) async => available,
      );
      var opens = 0;
      var ready = 0;
      final pending = Completer<AppStore>();
      await tester.pumpWidget(
        AppStartup(
          storageAccess: access,
          openStore: () {
            opens++;
            return pending.future;
          },
          onReady: (_) => ready++,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(testL10n.startupLocked), findsOneWidget);
      expect(opens, 0);
      expect(
        directory.listSync(),
        isEmpty,
        reason: 'no SQLite or diagnostic IO while locked',
      );
      expectNoApp();
      available = true;
      await availability(tester, true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await availability(tester, true);
      expect(opens, 1);
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      pending.complete(store);
      await tester.pumpAndSettle();
      expect(ready, 1);
      expect(find.byType(MishirubeApp), findsOneWidget);
      await disposeTree(tester);
    },
  );

  testWidgets('a newer availability event wins over a stale native response', (
    tester,
  ) async {
    final access = accessFor(TargetPlatform.iOS);
    final response = Completer<bool>();
    var queries = 0;
    messenger.setMockMethodCallHandler(StorageAccess.channel, (_) {
      queries++;
      return response.future;
    });
    final first = access.check();
    final second = access.check();
    expect(identical(first, second), isTrue);
    await availability(tester, true);
    response.complete(false);
    expect(await first, isTrue);
    expect(access.available, isTrue);
    expect(queries, 1);
    await availability(tester, false);
    expect(access.knownUnavailable, isTrue);
  });

  testWidgets(
    'native query failure is a retryable error, not a claim that storage is locked',
    (tester) async {
      usePhoneViewport(tester);
      final access = accessFor(TargetPlatform.iOS);
      messenger.setMockMethodCallHandler(
        StorageAccess.channel,
        (_) async => throw PlatformException(code: 'query-failed'),
      );
      var opens = 0;
      await tester.pumpWidget(
        AppStartup(
          storageAccess: access,
          openStore: () async {
            opens++;
            return AppStore();
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(testL10n.startupFailed), findsOneWidget);
      expect(find.text(testL10n.startupLocked), findsNothing);
      expect(opens, 0);
      expectNoApp();
      await disposeTree(tester);
    },
  );

  testWidgets(
    'disposing during initialization closes a late store without activating it',
    (tester) async {
      final access = accessFor(TargetPlatform.android);
      final pending = Completer<AppStore>();
      var ready = 0;
      await tester.pumpWidget(
        AppStartup(
          storageAccess: access,
          openStore: () => pending.future,
          onReady: (_) => ready++,
        ),
      );
      await tester.pump();
      await disposeTree(tester);
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      pending.complete(store);
      await tester.pump();
      expect(ready, 0);
      expect(() => store.backend.db.setting('probe'), throwsStateError);
      expect(tester.takeException(), isNull);
    },
  );

  test('non-iOS platforms never invoke the protection channel', () async {
    var queries = 0;
    messenger.setMockMethodCallHandler(StorageAccess.channel, (_) async {
      queries++;
      return false;
    });
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      final access = accessFor(platform);
      await access.requireAvailable();
      expect(access.available, isTrue);
    }
    expect(queries, 0);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('startup errors remain actionable in $locale with large text', (
      tester,
    ) async {
      usePhoneViewport(tester);
      tester.platformDispatcher.localesTestValue = [locale];
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.platformDispatcher.localesTestValue = [testLocale];
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final access = accessFor(TargetPlatform.iOS);
      var available = true;
      messenger.setMockMethodCallHandler(
        StorageAccess.channel,
        (_) async => available,
      );
      final l10n = lookupAppLocalizations(locale);
      for (final kind in [
        DatabaseFailureKind.busy,
        DatabaseFailureKind.corrupt,
        DatabaseFailureKind.incompatibleVersion,
        DatabaseFailureKind.unavailable,
      ]) {
        available = kind != DatabaseFailureKind.unavailable;
        await tester.pumpWidget(
          AppStartup(
            key: ValueKey(kind),
            storageAccess: access,
            openStore: () async => throw failure(kind),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(switch (kind) {
            DatabaseFailureKind.corrupt => l10n.startupUnreadable,
            DatabaseFailureKind.incompatibleVersion =>
              l10n.startupVersionMismatch,
            DatabaseFailureKind.unavailable => l10n.startupLocked,
            _ => l10n.startupFailed,
          }),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text(l10n.retry));
        expect(find.byType(PrimaryButton), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
          findsWidgets,
        );
        expectNoApp();
        expect(tester.takeException(), isNull);
      }
      await disposeTree(tester);
    });
  }
}
