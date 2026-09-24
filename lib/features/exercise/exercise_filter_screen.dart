import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Full-screen filter; pops with the new [ExerciseFilter].
class ExerciseFilterScreen extends StatefulWidget {
  const ExerciseFilterScreen({super.key, required this.initial});

  final ExerciseFilter initial;

  @override
  State<ExerciseFilterScreen> createState() => _ExerciseFilterScreenState();
}

class _ExerciseFilterScreenState extends State<ExerciseFilterScreen> {
  late ExerciseFilter _filter = widget.initial;

  int get _matchCount =>
      AppStoreScope.of(context).exercises.where(_filter.matches).length;

  void _update(ExerciseFilter filter) => setState(() => _filter = filter);

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: PageAppBar(
        title: '篩選',
        subtitle: '已套用 ${_filter.activeCount} 個條件',
      ),
      footer: PrimaryButton(
        label: '顯示 $_matchCount 個動作',
        onPressed: () => Navigator.of(context).pop(_filter),
      ),
      children: [
        Gutter(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SecondaryButton(
              label: '清除全部',
              isCompact: true,
              onPressed: () => _update(const ExerciseFilter()),
            ).withWidth(120),
          ),
        ),
        // One row a region: the region as a whole first where there is
        // one, then each muscle in it.
        for (final region in BodyRegion.values)
          Gutter(
            child: _FilterGroup(
              title: region.label,
              options: [
                for (final muscle in MuscleGroup.values)
                  if (muscle.region == region && muscle.isGeneral) muscle,
                for (final muscle in MuscleGroup.values)
                  if (muscle.region == region && !muscle.isGeneral) muscle,
              ],
              labelOf: (muscle) =>
                  muscle.isGeneral ? '整個${muscle.label}' : muscle.label,
              selected: _filter.muscles,
              onToggle: (muscle) => _update(
                _filter.copyWith(muscles: toggled(_filter.muscles, muscle)),
              ),
            ),
          ),
        Gutter(
          child: _FilterGroup(
            title: '器材',
            options: Equipment.values,
            labelOf: (item) => item.label,
            selected: _filter.equipment,
            onToggle: (item) => _update(
              _filter.copyWith(equipment: toggled(_filter.equipment, item)),
            ),
          ),
        ),
        Gutter(
          child: _FilterGroup(
            title: '動作模式',
            options: MovementPattern.values,
            labelOf: (pattern) => pattern.label,
            selected: _filter.patterns,
            onToggle: (pattern) => _update(
              _filter.copyWith(patterns: toggled(_filter.patterns, pattern)),
            ),
          ),
        ),
        Gutter(
          child: _FilterGroup(
            title: '追蹤方式',
            options: TrackingType.values,
            labelOf: (type) => type.label,
            selected: _filter.trackingTypes,
            onToggle: (type) => _update(
              _filter.copyWith(
                trackingTypes: toggled(_filter.trackingTypes, type),
              ),
            ),
          ),
        ),
        Gutter(
          child: _FilterGroup(
            title: '來源',
            options: ExerciseSource.values,
            labelOf: (source) => source.label,
            selected: _filter.sources,
            onToggle: (source) => _update(
              _filter.copyWith(sources: toggled(_filter.sources, source)),
            ),
          ),
        ),
      ],
    );
  }
}

extension on Widget {
  Widget withWidth(double width) => SizedBox(width: width, child: this);
}

class _FilterGroup<T> extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<T> options;
  final String Function(T option) labelOf;
  final Set<T> selected;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        ChipWrap(
          options: options,
          labelOf: labelOf,
          isSelected: selected.contains,
          onTap: onToggle,
        ),
      ],
    );
  }
}
