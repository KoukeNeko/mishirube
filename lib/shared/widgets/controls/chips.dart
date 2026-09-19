import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'pill.dart';

enum TagTone {
  neutral(AppColors.surfaceRaised, AppColors.textSecondary),
  training(AppColors.trainingSurface, AppColors.training),
  nutrition(AppColors.nutritionSurface, AppColors.nutrition),
  warning(AppColors.warningSurface, AppColors.warning),
  solidTraining(AppColors.training, AppColors.onTraining);

  const TagTone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

/// Small read-only label: evidence, data quality, confidence, source.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.tone = TagTone.neutral});

  final String label;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs - 2,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: tone.foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TagWrap extends StatelessWidget {
  const TagWrap({super.key, required this.labels, this.tone = TagTone.neutral});

  final List<String> labels;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [for (final label in labels) TagChip(label: label, tone: tone)],
    );
  }
}

/// Tappable pill used for filters and single/multi choices.
class SelectChip extends StatelessWidget {
  const SelectChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = AppColors.training,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final chip = Pill(
      onTap: onTap,
      color: isSelected ? selectedColor : AppColors.surfaceRaised,
      foregroundColor: isSelected
          ? AppColors.onTraining
          : AppColors.textPrimary,
      child: Text(label),
    );
    return Semantics(selected: isSelected, button: true, child: chip);
  }
}

/// Row of equally sized options where exactly one is selected.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.selectedColor = AppColors.training,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onChanged;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: SelectChip(
              label: labelOf(options[i]),
              isSelected: options[i] == selected,
              selectedColor: selectedColor,
              onTap: () => onChanged(options[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Coloured dot + label, e.g.「● 體重」.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Wrapping group of [SelectChip]s for single or multi selection.
class ChipWrap<T> extends StatelessWidget {
  const ChipWrap({
    super.key,
    required this.options,
    required this.labelOf,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = AppColors.training,
  });

  final List<T> options;
  final String Function(T option) labelOf;
  final bool Function(T option) isSelected;
  final ValueChanged<T> onTap;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in options)
          SelectChip(
            label: labelOf(option),
            isSelected: isSelected(option),
            selectedColor: selectedColor,
            onTap: () => onTap(option),
          ),
      ],
    );
  }
}
