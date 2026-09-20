import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

/// Indented list of a dish's components with a guide line on the left.
class ComponentList extends StatelessWidget {
  const ComponentList({
    super.key,
    required this.components,
    this.showSource = false,
  });

  final List<FoodComponent> components;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.xxs),
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.outline, width: 2)),
      ),
      child: Column(
        children: [
          for (final component in components)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      component.name,
                      style: AppTextStyles.body.copyWith(fontSize: 14),
                    ),
                  ),
                  Text(
                    component.amountLabel,
                    style: AppTextStyles.itemTitle.copyWith(fontSize: 15),
                  ),
                  if (showSource) ...[
                    const SizedBox(width: AppSpacing.xs),
                    SizedBox(
                      width: 84,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TagChip(label: component.source),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
