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

InputDecoration _decoration({required String hint, Widget? prefixIcon}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(_fieldRadius),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textTertiary),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppColors.surface,
    // Without vertical padding the fill is drawn at the text row's own
    // 48 and sits at the top of the 56 box, so anything placed beside the
    // field at the field's height looks larger than it.
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
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
  const SearchField({
    super.key,
    required this.controller,
    this.hint = '搜尋動作、別名或器材⋯⋯',
  });

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
