import 'package:flutter/foundation.dart';

import '../backend/backend.dart';

/// The state of one screen or feature, read from [backend] and rebuilt
/// whenever anything is written to it — by this screen or any other —
/// so no screen needs to know which others show the same records.
///
/// A screen creates its view model when it is built and disposes it with
/// itself; what outlives a screen belongs in the database, or in
/// `AppStore` when it is state of the app as a whole.
abstract class ViewModel extends ChangeNotifier {
  ViewModel(this.backend) {
    backend.db.changes.addListener(notifyListeners);
  }

  final Backend backend;

  DateTime now() => backend.db.now();

  @override
  void dispose() {
    backend.db.changes.removeListener(notifyListeners);
    super.dispose();
  }
}
