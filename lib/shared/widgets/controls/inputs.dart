import 'package:flutter/material.dart';

import '../../../app/theme.dart';

const _fieldHeight = 56.0;

InputDecoration _decoration({required String hint, Widget? prefixIcon}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.small + 4),
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textTertiary),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: const BorderSide(color: AppColors.trainingOutline),
    ),
  );
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
        textInputAction: TextInputAction.search,
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
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTextStyles.body.copyWith(fontSize: 17),
        decoration: _decoration(hint: hint),
      ),
    );
  }
}
