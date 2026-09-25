import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';

const _fieldHeight = 56.0;

/// How tall a [SearchField] is, for a page that pins one in its header.
const searchFieldHeight = _fieldHeight;

/// Puts the keyboard away when a tap lands outside the field.
///
/// Pass this to every `TextField`'s `onTapOutside`. Flutter's own default
/// only does this on desktop, and on a phone a keyboard that will not go
/// away covers half the screen.
void dismissKeyboardOnTapOutside(PointerDownEvent _) =>
    FocusManager.instance.primaryFocus?.unfocus();

/// The corner of every input, and of anything that sits beside one.
const _fieldRadius = AppRadius.small + 4;

InputDecoration _decoration({
  required String hint,
  Widget? prefixIcon,
  Color fill = AppColors.surface,
  double horizontalPadding = AppSpacing.md,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(_fieldRadius),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textTertiary),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: fill,
    // Without vertical padding the fill is drawn at the text row's own
    // 48 and sits at the top of the 56 box, so anything placed beside the
    // field at the field's height looks larger than it.
    contentPadding: EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: 18,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.trainingOutline),
    ),
  );
}

/// An icon button that sits beside a [SearchField] — filters, most often.
///
/// Same height, corner and fill as the field, so the two read as one row
/// rather than a field and a smaller square that happens to be next to it.
class SearchFieldButton extends StatelessWidget {
  const SearchFieldButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _fieldHeight,
      child: IconButton(
        tooltip: tooltip,
        onPressed: () {
          AppHaptics.tap();
          onPressed();
        },
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textSecondary,
          fixedSize: const Size.square(_fieldHeight),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_fieldRadius),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _fieldHeight,
      child: TextField(
        controller: controller,
        onTapOutside: dismissKeyboardOnTapOutside,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: AppTextStyles.body,
        decoration: _decoration(
          hint: hint,
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint = '',
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final int maxLines;

  /// The keyboard to raise; a field that takes a number asks for one.
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // A field that takes several lines grows with them.
      height: maxLines == 1 ? _fieldHeight : null,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onTapOutside: dismissKeyboardOnTapOutside,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTextStyles.body.copyWith(fontSize: 17),
        textAlignVertical: TextAlignVertical.center,
        decoration: _decoration(hint: hint),
      ),
    );
  }
}

/// A number to fill in, as one row: what it is, with an optional quieter
/// line under it, a full field to type in, and its unit. Every row of a
/// form of figures has this shape — a nutrition label, a body
/// composition scale's reading, tape measurements — so each is as easy
/// to hit as the next.
class NumberFieldRow extends StatelessWidget {
  const NumberFieldRow({
    super.key,
    required this.label,
    required this.unit,
    required this.controller,
    this.caption,
    this.fieldKey,
  });

  final String label;
  final String unit;
  final TextEditingController controller;

  /// Context for the figure, such as the last one recorded.
  final String? caption;

  /// For finding the field itself, in tests.
  final Key? fieldKey;

  static const _fieldWidth = 120.0;
  static const _unitWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.body),
              if (caption != null) Text(caption, style: AppTextStyles.caption),
            ],
          ),
        ),
        SizedBox(
          width: _fieldWidth,
          child: AppTextField(
            key: fieldKey,
            controller: controller,
            // Not `0`: an empty field is a figure nobody wrote down.
            hint: '—',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: _unitWidth,
          child: Text(unit, style: AppTextStyles.caption),
        ),
      ],
    );
  }
}

/// A figure typed in place, in a table of them: a set's weight or reps. What was typed is handed over when the field
/// is left or submitted; until then the set keeps its figure.
class InlineNumberField extends StatefulWidget {
  const InlineNumberField({
    super.key,
    required this.text,
    required this.label,
    required this.decimal,
    required this.onCommit,
  });

  final String text;

  /// What a screen reader calls the field: `第 1 組重量`.
  final String label;

  /// Whether a decimal point may be typed.
  final bool decimal;
  final ValueChanged<String> onCommit;

  @override
  State<InlineNumberField> createState() => _InlineNumberFieldState();
}

class _InlineNumberFieldState extends State<InlineNumberField> {
  late final _controller = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(InlineNumberField old) {
    super.didUpdateWidget(old);
    // A figure changed elsewhere shows unless it is being typed over.
    if (!_focus.hasFocus && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text != widget.text) widget.onCommit(text);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _fieldHeight,
      child: Semantics(
        label: widget.label,
        textField: true,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          onTapOutside: dismissKeyboardOnTapOutside,
          onSubmitted: (_) => _commit(),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(
            decimal: widget.decimal,
          ),
          textAlignVertical: TextAlignVertical.center,
          style: AppTextStyles.body.copyWith(
            fontSize: 17,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          // The app's field, raised a step: it sits on a card, whose fill
          // is the field's own.
          decoration: _decoration(
            hint: '',
            fill: AppColors.surfaceRaised,
            horizontalPadding: AppSpacing.xs,
          ),
        ),
      ),
    );
  }
}
