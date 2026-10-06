import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../haptics.dart';
import '../../motion.dart';
import '../../window_layout.dart';

const _slideDuration = Duration(milliseconds: 220);

const _keyHeight = 48.0;
const _keyGap = 8.0;
const _panelPadding = 8.0;
const _rows = 4;
const _columns = 5;
const _smallStep = 1;
const _largeStep = 5;

/// What the keys occupy, without the safe area under them.
const _keysHeight = _rows * _keyHeight + (_rows - 1) * _keyGap;

final _keyStyle = AppTextStyles.bigNumber.copyWith(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  letterSpacing: 0,
);

/// A field the keypad types into; [InlineNumberField] is one.
abstract interface class KeypadField {
  TextEditingController get controller;
  FocusNode get focusNode;

  /// Whether a decimal point may be typed.
  bool get allowsDecimal;

  /// Room to leave around the field when it is scrolled into view: under
  /// the page's footer is as hidden as under the keypad.
  EdgeInsets get scrollPadding;

  /// Where the field is, to find the one before and the one after it.
  BuildContext get context;
}

/// The app's own number keypad, in place of the system's: it rises when a
/// [KeypadField] takes focus and hides when none has it.
///
/// It lives above the navigator and tells the pages under it that it is a
/// keyboard of its height, through `MediaQuery.viewInsets`. Scaffolds,
/// footers, dialogs and toasts then make room for it the way they do for
/// the system's, with nothing of their own.
class NumberKeypadHost extends StatefulWidget {
  const NumberKeypadHost({super.key, required this.child});

  final Widget child;

  static NumberKeypadHostState of(BuildContext context) {
    final host = context.findAncestorStateOfType<NumberKeypadHostState>();
    assert(host != null, 'A KeypadField needs a NumberKeypadHost above it.');
    return host!;
  }

  @override
  State<NumberKeypadHost> createState() => NumberKeypadHostState();
}

class NumberKeypadHostState extends State<NumberKeypadHost>
    with SingleTickerProviderStateMixin {
  final _fields = <KeypadField>[];

  /// The field with focus, if any, and what the keypad shows of it. The
  /// latter stays as it was while the keypad slides away.
  KeypadField? _active;
  var _allowsDecimal = false;
  var _hasPrevious = false;
  var _hasNext = false;

  late final _slide = AnimationController(vsync: this, duration: _slideDuration)
    ..addListener(_keepActiveVisible);
  late final _position = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    _position.dispose();
    _slide.dispose();
    super.dispose();
  }

  void attach(KeypadField field) => _fields.add(field);

  void detach(KeypadField field) => _fields.remove(field);

  /// Follows the focus, which also tells when a field with it goes away.
  void _focusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    final field = _fields.where((f) => f.focusNode == focus).firstOrNull;
    if (field == _active) return;
    setState(() {
      _active = field;
      if (field != null) {
        final order = _inReadingOrder(field);
        final at = order.indexOf(field);
        _allowsDecimal = field.allowsDecimal;
        _hasPrevious = at > 0;
        _hasNext = at < order.length - 1;
      }
    });
    if (field == null) {
      _slide.reverse();
    } else {
      _slide.forward();
    }
  }

  /// The fields on the field's own page, row by row, left to right.
  List<KeypadField> _inReadingOrder(KeypadField field) {
    final scope = field.focusNode.enclosingScope;
    Offset at(KeypadField f) =>
        (f.context.findRenderObject()! as RenderBox).localToGlobal(Offset.zero);
    return [
      for (final f in _fields)
        if (f.focusNode.enclosingScope == scope) f,
    ]..sort((a, b) {
      final (pa, pb) = (at(a), at(b));
      final byRow = pa.dy.round().compareTo(pb.dy.round());
      return byRow != 0 ? byRow : pa.dx.compareTo(pb.dx);
    });
  }

  /// The page shrinks as the keypad rises, so the field being typed in is
  /// kept in view all the way up, as the system's keyboard has it.
  void _keepActiveVisible() {
    if (_slide.status != AnimationStatus.forward) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active case final field? when field.context.mounted) {
        final box = field.context.findRenderObject() as RenderBox?;
        box?.showOnScreen(
          rect: field.scrollPadding.inflateRect(Offset.zero & box.size),
        );
      }
    });
  }

  TextSelection _selectionOf(TextEditingValue value) => value.selection.isValid
      ? value.selection
      : TextSelection.collapsed(offset: value.text.length);

  /// Puts [text] where [range] was, with the cursor after it.
  void _replace(KeypadField field, TextRange range, String text) {
    field.controller.value = TextEditingValue(
      text: field.controller.text.replaceRange(range.start, range.end, text),
      selection: TextSelection.collapsed(offset: range.start + text.length),
    );
  }

  void _type(String character) {
    final field = _active;
    if (field == null) return;
    final value = field.controller.value;
    final selection = _selectionOf(value);
    var text = character;
    if (character == '.') {
      final kept = value.text.replaceRange(selection.start, selection.end, '');
      if (!field.allowsDecimal || kept.contains('.')) return;
      if (selection.start == 0) text = '0.';
    }
    _replace(field, selection, text);
  }

  void _backspace() {
    final field = _active;
    if (field == null) return;
    final value = field.controller.value;
    final selection = _selectionOf(value);
    final range = selection.isCollapsed
        ? TextRange(start: math.max(0, selection.start - 1), end: selection.end)
        : selection;
    _replace(field, range, '');
  }

  /// Steps the figure and selects it, so what is typed next replaces it.
  void _step(int by) {
    final field = _active;
    if (field == null) return;
    final next = math.max(
      0.0,
      (double.tryParse(field.controller.text) ?? 0) + by,
    );
    final text = field.allowsDecimal
        ? next.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')
        : '${next.round()}';
    field.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  }

  void _move(int by) {
    final field = _active;
    if (field == null) return;
    final order = _inReadingOrder(field);
    final to = order.indexOf(field) + by;
    if (to >= 0 && to < order.length) {
      order[to].focusNode.requestFocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    _slide.duration = chromeDuration(context, _slideDuration);
    final height = _keysHeight + 2 * _panelPadding + media.viewPadding.bottom;
    return AnimatedBuilder(
      animation: _position,
      child: widget.child,
      builder: (context, child) {
        final inset = height * _position.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            MediaQuery(
              data: media.copyWith(
                viewInsets: media.viewInsets.copyWith(
                  bottom: math.max(media.viewInsets.bottom, inset),
                ),
                padding: media.padding.copyWith(
                  bottom: math.max(0, media.padding.bottom - inset),
                ),
              ),
              child: child!,
            ),
            if (!_slide.isDismissed)
              Positioned(
                left: 0,
                right: 0,
                bottom: inset - height,
                height: height,
                child: _KeypadPanel(
                  key: const ValueKey('number-keypad'),
                  allowsDecimal: _allowsDecimal,
                  hasPrevious: _hasPrevious,
                  hasNext: _hasNext,
                  onType: _type,
                  onBackspace: _backspace,
                  onStep: _step,
                  onMove: _move,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KeypadPanel extends StatelessWidget {
  const _KeypadPanel({
    super.key,
    required this.allowsDecimal,
    required this.hasPrevious,
    required this.hasNext,
    required this.onType,
    required this.onBackspace,
    required this.onStep,
    required this.onMove,
  });

  final bool allowsDecimal;
  final bool hasPrevious;
  final bool hasNext;
  final ValueChanged<String> onType;
  final VoidCallback onBackspace;
  final ValueChanged<int> onStep;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Material(
          color: AppColors.surface,
          shape: const Border(top: BorderSide(color: AppColors.outline)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Wide windows keep the keys within a column, as footers do.
              final column = contentColumnInsets(
                context,
                constraints.maxWidth,
                maxWidth: readableMaxWidth,
              );
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  column.left + _panelPadding,
                  _panelPadding,
                  column.right + _panelPadding,
                  _panelPadding + safeBottom,
                ),
                child: _keys(l10n),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The keys on a grid of five columns and four rows: the digits on the
  /// first three, the steps and the way on and off on the last two.
  Widget _keys(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - (_columns - 1) * _keyGap) / _columns;
        Widget cell(int column, int row, _Key key, {int span = 1}) =>
            Positioned(
              left: column * (width + _keyGap),
              top: row * (_keyHeight + _keyGap),
              width: span * width + (span - 1) * _keyGap,
              height: _keyHeight,
              child: key,
            );
        _Key step(int by) => _Key(
          label: by < 0
              ? l10n.decreaseBy(amount: '${-by}')
              : l10n.increaseBy(amount: '$by'),
          text: by < 0 ? '$by' : '+$by',
          onTap: () => onStep(by),
        );
        return SizedBox(
          height: _keysHeight,
          child: Stack(
            children: [
              for (var digit = 1; digit <= 9; digit++)
                cell(
                  (digit - 1) % 3,
                  (digit - 1) ~/ 3,
                  _Key(label: '$digit', onTap: () => onType('$digit')),
                ),
              cell(
                0,
                3,
                _Key(
                  label: '.',
                  onTap: allowsDecimal ? () => onType('.') : null,
                ),
              ),
              cell(1, 3, _Key(label: '0', onTap: () => onType('0'))),
              cell(
                2,
                3,
                _Key(
                  label: l10n.deleteAction,
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                ),
              ),
              cell(3, 0, step(-_smallStep)),
              cell(4, 0, step(_smallStep)),
              cell(3, 1, step(-_largeStep)),
              cell(4, 1, step(_largeStep)),
              cell(
                3,
                2,
                span: 2,
                _Key(
                  label: l10n.previousField,
                  style: AppTextStyles.buttonLabel,
                  onTap: hasPrevious ? () => onMove(-1) : null,
                ),
              ),
              cell(
                3,
                3,
                span: 2,
                _Key(
                  label: hasNext ? l10n.nextField : l10n.commonDone,
                  style: AppTextStyles.buttonLabel,
                  fill: AppColors.training,
                  foreground: AppColors.onTraining,
                  onTap: () => onMove(1),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One key: an [icon] or its [text] (the [label] when none is given), and
/// nothing to press while it has no [onTap].
class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.text,
    this.icon,
    this.style,
    this.fill = AppColors.surfaceRaised,
    this.foreground = AppColors.textPrimary,
  });

  final String label;
  final String? text;
  final IconData? icon;

  /// The text's style, the digits' by default.
  final TextStyle? style;
  final VoidCallback? onTap;
  final Color fill;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.textTertiary : foreground;
    final radius = BorderRadius.circular(AppRadius.small);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: fill,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          canRequestFocus: false,
          onTap: onTap == null
              ? null
              : () {
                  AppHaptics.tap();
                  onTap!();
                },
          child: Center(
            // Scaled down as one, so large text shrinks the label rather
            // than spilling out of the key.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: icon == null
                  ? Text(
                      text ?? label,
                      style: (style ?? _keyStyle).copyWith(color: color),
                    )
                  : Icon(icon, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
