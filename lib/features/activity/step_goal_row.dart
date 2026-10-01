import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'daily_activity_view_model.dart';
import '../../l10n/l10n.dart';

/// The daily step goal as a row for a [GroupedCard], the same on the
/// steps page and under 我的: the goal or 未設定, opening its picker.
Widget stepGoalRow(BuildContext context, DailyActivityViewModel model) =>
    NavRow(
      title: context.l10n.stepGoal,
      trailing: Text(switch (model.stepGoal) {
        final goal? => _steps(context, goal),
        null => context.l10n.notSet,
      }, style: AppTextStyles.caption),
      onTap: () => _editStepGoal(context, model),
    );

/// `7,500 步`: a count of steps as the goal is written.
String _steps(BuildContext context, int steps) =>
    context.l10n.stepsValue(steps: formatKcal(steps));

Future<void> _editStepGoal(
  BuildContext context,
  DailyActivityViewModel model,
) async {
  final current = model.stepGoal;
  // Where the slider starts, not a recommendation: the app picks no goal.
  var steps = current ?? 5000;
  final result = await showAppDialog<int?>(
    context,
    StatefulBuilder(
      builder: (context, setState) => AppDialog(
        title: context.l10n.stepGoal,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _steps(context, steps),
              style: AppTextStyles.hugeNumber.copyWith(
                color: AppColors.activity,
              ),
            ),
            StepSlider(
              value: steps.toDouble(),
              min: 2000,
              max: 20000,
              step: 500,
              color: AppColors.activity,
              semanticLabel: context.l10n.stepGoal,
              labelOf: (value) => _steps(context, value.round()),
              onChanged: (value) => setState(() => steps = value.round()),
            ),
          ],
        ),
        actions: [
          DialogAction(
            label: context.l10n.commonSave,
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(steps),
          ),
          if (current != null)
            DialogAction(
              label: context.l10n.clearGoal,
              tone: DialogTone.destructive,
              onTap: () => Navigator.of(context).pop(0),
            ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;
  model.setStepGoal(result == 0 ? null : result);
}
