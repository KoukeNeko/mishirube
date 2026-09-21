import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Which meal something was, when the user wants to say.
///
/// Optional, because the time is already the fact and the label is only
/// what they call it. A [suggested] label is shown as an offer to take
/// or leave, never pre-selected: something picked on the user's behalf
/// and saved without a look is the app classifying their meals for them.
class MealTypePicker extends StatelessWidget {
  const MealTypePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.suggested,
  });

  final MealType? selected;
  final MealType? suggested;

  /// Called with the new label, or null when the chosen one is tapped
  /// again to clear it.
  final ValueChanged<MealType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final offer = selected == null ? suggested : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChipWrap(
          options: MealType.values,
          labelOf: (type) => type.label,
          isSelected: (type) => type == selected,
          onTap: (type) => onChanged(type == selected ? null : type),
        ),
        if (offer != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            children: [
              Text('這個時間你通常記成「${offer.label}」', style: AppTextStyles.caption),
              LinkText(label: '套用', onTap: () => onChanged(offer)),
            ],
          ),
        ],
      ],
    );
  }
}
