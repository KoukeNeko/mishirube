import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Picks the kind of exercise. Recently used first, then the handful most
/// people log, then everything by group: over time a person uses a few
/// types, so recall beats search.
class ActivityTypePicker extends StatelessWidget {
  const ActivityTypePicker({super.key, this.selected});

  final ActivityType? selected;

  @override
  Widget build(BuildContext context) {
    final recent = AppStoreScope.of(context).recentActivityTypes;
    return DetailPage(
      appBar: PageAppBar(
        title: '選擇運動',
        leading: AppBarLeading.none,
        onClose: () => Navigator.of(context).pop(),
      ),
      children: [
        if (recent.isNotEmpty) ...[
          Gutter(child: const SectionLabel('最近使用')),
          Gutter(
            child: _TypeChips(types: recent, selected: selected),
          ),
        ],
        Gutter(child: const SectionLabel('常用')),
        Gutter(
          child: _TypeChips(types: ActivityTypes.common, selected: selected),
        ),
        Gutter(child: const SectionLabel('所有運動')),
        for (final group in ActivityGroup.values)
          if (ActivityTypes.all.where((type) => type.group == group).toList()
              case final types when types.isNotEmpty) ...[
            Gutter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(group.label, style: AppTextStyles.caption),
              ),
            ),
            Gutter(
              child: _TypeChips(types: types, selected: selected),
            ),
          ],
      ],
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.types, required this.selected});

  final List<ActivityType> types;
  final ActivityType? selected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final type in types)
          SelectChip(
            label: type.label,
            icon: type.icon,
            iconColor: AppColors.activity,
            isSelected: type == selected,
            showsSelectionAsOutline: true,
            selectedColor: AppColors.activity,
            onTap: () => Navigator.of(context).pop(type),
          ),
      ],
    );
  }
}
