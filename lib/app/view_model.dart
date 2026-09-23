import 'package:flutter/widgets.dart';

import '../backend/backend.dart';
import 'app_store.dart';

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

/// Creates a [ViewModel] for the widget below it, rebuilds that widget
/// when it changes, and disposes it with itself: a stateless screen's way
/// of owning its state.
class ViewModelBuilder<T extends ViewModel> extends StatefulWidget {
  const ViewModelBuilder({
    super.key,
    required this.create,
    required this.builder,
  });

  final T Function(Backend backend) create;
  final Widget Function(BuildContext context, T model) builder;

  @override
  State<ViewModelBuilder<T>> createState() => _ViewModelBuilderState<T>();
}

class _ViewModelBuilderState<T extends ViewModel>
    extends State<ViewModelBuilder<T>> {
  late final T _model = widget.create(AppStoreScope.read(context).backend);

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) => widget.builder(context, _model),
  );
}
