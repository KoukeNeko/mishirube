import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'database_open_failure.dart';

/// The iOS file-protection boundary, shared by startup and health imports.
/// A readiness check is a hint, not a substitute for handling an open failure:
/// the device can lock again immediately after it answers.
class StorageAccess extends ChangeNotifier {
  StorageAccess()
    : _requiresProtectedData =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static final instance = StorageAccess();
  static const channel = MethodChannel('mishirube/storage_access');

  final bool _requiresProtectedData;
  bool? _available;
  bool _listening = false;
  bool _disposed = false;
  int _revision = 0;
  Future<bool>? _checking;

  bool get available => !_requiresProtectedData || _available == true;
  bool get knownUnavailable => _requiresProtectedData && _available == false;

  Future<bool> check() {
    if (!_requiresProtectedData) return SynchronousFuture(true);
    return _checking ??= _read().whenComplete(() => _checking = null);
  }

  Future<bool> _read() async {
    if (!_listening) {
      channel.setMethodCallHandler((call) async {
        if (call.method == 'availabilityChanged' && call.arguments is bool) {
          _revision++;
          _setAvailable(call.arguments as bool);
        }
      });
      _listening = true;
    }
    final revision = _revision;
    final value = await channel.invokeMethod<bool>('isAvailable');
    if (value == null) {
      throw PlatformException(code: 'missing-storage-availability');
    }
    // A notification newer than the query must win over a delayed reply.
    if (_revision == revision) _setAvailable(value == true);
    return available;
  }

  void _setAvailable(bool value) {
    if (_disposed || _available == value) return;
    _available = value;
    notifyListeners();
  }

  Future<void> requireAvailable() async {
    if (!await check()) throw const ProtectedDataUnavailable();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_listening) channel.setMethodCallHandler(null);
    super.dispose();
  }
}
