import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum ToastKind { info, success, warning }

const _infoDuration = Duration(milliseconds: 3500);
const _warningDuration = Duration(seconds: 5);
const _undoDuration = Duration(seconds: 30);

class ToastMessage {
  const ToastMessage({
    required this.id,
    required this.message,
    required this.kind,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  final int id;
  final String message;
  final ToastKind kind;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  bool get hasAction => onAction != null;
}

/// Owns the one visible toast, one waiting toast, their timers and where
/// the bottom chrome currently ends.
class ToastController extends ChangeNotifier {
  ToastMessage? _current;
  ToastMessage? _pending;
  Timer? _timer;
  int _nextId = 0;
  bool _isDisposed = false;
  final Map<Object, double> _obstructionTops = {};

  /// With VoiceOver/TalkBack navigation an actionable toast must not vanish
  /// on a timer before the user reaches its button.
  bool keepsActionableToasts = false;

  ToastMessage? get current => _current;

  /// Global y of the highest bottom chrome (dock, floating footer), if any.
  double? get obstructionTop => _obstructionTops.isEmpty
      ? null
      : _obstructionTops.values.reduce((a, b) => a < b ? a : b);

  void show(String message, {ToastKind kind = ToastKind.info}) {
    if (kind == ToastKind.warning) HapticFeedback.mediumImpact();
    _enqueue(
      ToastMessage(
        id: _nextId++,
        message: message,
        kind: kind,
        duration: kind == ToastKind.warning ? _warningDuration : _infoDuration,
      ),
    );
  }

  /// A reversible change: stays for 30 seconds with a「復原」action.
  void showUndo(String message, {required VoidCallback onUndo}) {
    _enqueue(
      ToastMessage(
        id: _nextId++,
        message: message,
        kind: ToastKind.success,
        duration: _undoDuration,
        actionLabel: '復原',
        onAction: onUndo,
      ),
    );
  }

  void _enqueue(ToastMessage toast) {
    // An undo on screen is the user's only way back, so plain messages wait
    // behind it instead of replacing it.
    if (_current case final current?
        when current.hasAction && !toast.hasAction) {
      _pending = toast;
      return;
    }
    _present(toast);
  }

  void _present(ToastMessage? toast) {
    _timer?.cancel();
    _current = toast;
    if (toast != null && !(toast.hasAction && keepsActionableToasts)) {
      _timer = Timer(toast.duration, () => dismiss(toast.id));
    }
    notifyListeners();
  }

  /// Dismisses the visible toast (only if it is still [id], when given).
  void dismiss([int? id]) {
    if (_current == null || (id != null && _current!.id != id)) return;
    final next = _pending;
    _pending = null;
    _present(next);
  }

  void runAction() {
    final onAction = _current?.onAction;
    if (onAction == null) return;
    HapticFeedback.selectionClick();
    dismiss();
    onAction();
  }

  void reportObstruction(Object owner, double? top) {
    // Chrome reports after the frame, which can land after the host is gone.
    if (_isDisposed) return;
    final previous = _obstructionTops[owner];
    if (previous == top) return;
    if (top == null) {
      _obstructionTops.remove(owner);
    } else {
      _obstructionTops[owner] = top;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

class ToastScope extends InheritedNotifier<ToastController> {
  const ToastScope({
    super.key,
    required ToastController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Reads the controller without rebuilding when toasts change.
  static ToastController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<ToastScope>();
    assert(element != null, 'ToastHost is missing above this context.');
    return (element!.widget as ToastScope).notifier!;
  }
}

void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
}) => ToastScope.read(context).show(message, kind: kind);
