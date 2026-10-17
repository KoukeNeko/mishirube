import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/storage/database.dart';
import '../backend/storage/database_diagnostics.dart';
import '../backend/storage/storage_access.dart';
import '../l10n/l10n.dart';
import '../shared/widgets/widgets.dart';
import 'app.dart';
import 'app_store.dart';
import 'theme.dart';

/// Owns initialization and its resulting store. No normal app widgets (and
/// thus no health, watch or widget side effects) exist before it succeeds.
class AppStartup extends StatefulWidget {
  const AppStartup({
    super.key,
    required this.openStore,
    required this.storageAccess,
    this.onReady,
  });

  final Future<AppStore> Function() openStore;
  final StorageAccess storageAccess;
  final void Function(AppStore store)? onReady;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> with WidgetsBindingObserver {
  AppStore? _store;
  DatabaseOpenFailure? _failure;
  DatabaseOpenFailure? _pendingDiagnostic;
  bool _opening = false;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.storageAccess.addListener(_availabilityChanged);
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_opening || _store != null || !mounted) return;
    setState(() {
      _opening = true;
      _failure = null;
    });
    try {
      await widget.storageAccess.requireAvailable();
      if (_pendingDiagnostic case final pending?) {
        await DatabaseDiagnostics.failedOnDevice(pending);
        _pendingDiagnostic = null;
      }
      if (!mounted) return;
      final store = await widget.openStore();
      if (!mounted) {
        store.disposeWithBackend();
        return;
      }
      setState(() => _store = store);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _activated = true;
        widget.onReady?.call(store);
      });
    } catch (error, stack) {
      final failure = DatabaseOpenFailure.from(
        error,
        stack,
        stage: DatabaseOpenStage.initialization,
      );
      if (!widget.storageAccess.knownUnavailable) {
        await DatabaseDiagnostics.failedOnDevice(failure);
      } else {
        _pendingDiagnostic = failure;
      }
      if (mounted) {
        setState(
          () => _failure = widget.storageAccess.knownUnavailable
              ? DatabaseOpenFailure(
                  kind: DatabaseFailureKind.unavailable,
                  stage: failure.stage,
                  cause: failure.cause,
                  stackTrace: failure.stackTrace,
                  existingFile: failure.existingFile,
                )
              : failure,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        // An unlock notification may have arrived while the failed attempt
        // was still unwinding. Do not lose it or start two attempts.
        if (_failure?.kind == DatabaseFailureKind.unavailable &&
            widget.storageAccess.available) {
          scheduleMicrotask(_open);
        }
      }
    }
  }

  void _availabilityChanged() {
    if (!widget.storageAccess.available) return;
    if (_store == null) {
      unawaited(_open());
    } else if (_activated) {
      unawaited(_store!.syncHealthInBackground());
    }
  }

  Future<void> _resume() async {
    if (_store == null) {
      await _open();
      return;
    }
    try {
      if (await widget.storageAccess.check() && mounted && _activated) {
        await _store!.syncHealthInBackground();
      }
    } on Exception catch (error, stack) {
      await DatabaseDiagnostics.failedOnDevice(
        DatabaseOpenFailure.from(error, stack, stage: DatabaseOpenStage.access),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_resume());
    if (state == AppLifecycleState.hidden && _activated) {
      unawaited(_store?.writeHealthInBackground());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.storageAccess.removeListener(_availabilityChanged);
    _store?.disposeWithBackend();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_store case final store?) return MishirubeApp(store: store);
    return MaterialApp(
      title: 'MISHIRUBE',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: appSystemOverlayStyle,
        child: BackdropGroup(child: child!),
      ),
      home: Builder(
        builder: (context) {
          final l10n = context.l10n;
          final kind = _failure?.kind;
          final waiting = kind == DatabaseFailureKind.unavailable;
          final title = _opening
              ? l10n.startupLoading
              : switch (kind) {
                  DatabaseFailureKind.unavailable => l10n.startupLocked,
                  DatabaseFailureKind.corrupt ||
                  DatabaseFailureKind.missing => l10n.startupUnreadable,
                  DatabaseFailureKind.incompatibleVersion =>
                    l10n.startupVersionMismatch,
                  _ => l10n.startupFailed,
                };
          final message = _opening
              ? null
              : switch (kind) {
                  DatabaseFailureKind.unavailable => l10n.startupUnlockHint,
                  DatabaseFailureKind.corrupt ||
                  DatabaseFailureKind.missing => l10n.startupPreserveHint,
                  DatabaseFailureKind.incompatibleVersion =>
                    l10n.startupUpdateHint,
                  _ => l10n.startupRetryHint,
                };
          return PageScaffold(
            appBar: const PageAppBar(
              title: 'MISHIRUBE',
              leading: AppBarLeading.none,
            ),
            children: [
              Gutter(
                child: Semantics(
                  liveRegion: true,
                  child: EmptyStateCard(
                    icon: waiting ? Icons.lock_outline : Icons.storage_outlined,
                    title: title,
                    message: message,
                    action: _opening
                        ? null
                        : PrimaryButton(
                            label: l10n.retry,
                            onPressed: () => unawaited(_open()),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
