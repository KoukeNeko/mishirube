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
          MealTypeOffer(offer: offer, onTake: () => onChanged(offer)),
        ],
      ],
    );
  }
}

/// 「這個時間你通常記成『午餐』 · 套用」: a label the user's own habit
/// suggests, offered and never applied on its own.
class MealTypeOffer extends StatelessWidget {
  const MealTypeOffer({super.key, required this.offer, required this.onTake});

  final MealType offer;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        Text('常用：${offer.label}', style: AppTextStyles.caption),
        LinkText(label: '套用', onTap: onTake),
      ],
    );
  }
}

/// Asks which meal this is, from the page title. Resolves to a record so
/// that choosing「不指定」 (null) can be told apart from backing out.
Future<(MealType?,)?> showMealTypeDialog(
  BuildContext context, {
  required MealType? selected,
}) => showAppDialog<(MealType?,)>(
  context,
  AppDialog(
    title: '這是哪一餐',
    isChoiceList: true,
    actions: [
      for (final type in MealType.values)
        DialogAction(
          icon: mealTypeIcon(type),
          label: type.label,
          isSelected: type == selected,
          tone: type == selected ? DialogTone.primary : DialogTone.normal,
          onTap: () => Navigator.of(context).pop((type,)),
        ),
      DialogAction(
        icon: Icons.schedule,
        label: '不指定',
        isSelected: selected == null,
        tone: selected == null ? DialogTone.primary : DialogTone.normal,
        onTap: () => Navigator.of(context).pop((null,)),
      ),
    ],
  ),
);

/// The picture beside a meal's name: the sun rising, high, set, and a
/// cup for the in-between.
IconData mealTypeIcon(MealType type) => switch (type) {
  MealType.breakfast => Icons.wb_twilight,
  MealType.lunch => Icons.wb_sunny_outlined,
  MealType.dinner => Icons.nightlight_outlined,
  MealType.snack => Icons.local_cafe_outlined,
};
