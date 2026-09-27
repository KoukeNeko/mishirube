import 'package:flutter/material.dart';

import '../../app/view_model.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'activity_view_model.dart';
import '../../l10n/l10n.dart';

/// Picks the kind of exercise. Recently used first, then the handful most
/// people log, then everything by group: over time a person uses a few
/// types, so recall beats search.
class ActivityTypePicker extends StatelessWidget {
  const ActivityTypePicker({super.key, this.selected});

  final ActivityType? selected;

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: ActivityViewModel.new,
    builder: (context, activity) => _page(context, activity.recentTypes),
  );

  Widget _page(BuildContext context, List<ActivityType> recent) {
    return DetailPage(
      appBar: PageAppBar(title: context.l10n.activityPickTitle),
      children: [
        if (recent.isNotEmpty) ...[
          Gutter(child: SectionLabel(context.l10n.recentlyUsed)),
          Gutter(
            child: _TypeChips(types: recent, selected: selected),
          ),
        ],
        Gutter(child: SectionLabel(context.l10n.commonlyUsed)),
        Gutter(
          child: _TypeChips(types: ActivityTypes.common, selected: selected),
        ),
        Gutter(child: SectionLabel(context.l10n.activityAllTypes)),
        for (final group in ActivityGroup.values)
          if (ActivityTypes.all.where((type) => type.group == group).toList()
              case final types when types.isNotEmpty) ...[
            Gutter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  group.labelIn(context.l10n),
                  style: AppTextStyles.caption,
                ),
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
            label: type.labelIn(context.l10n),
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
