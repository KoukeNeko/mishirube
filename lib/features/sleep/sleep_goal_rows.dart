import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/bedtime_reminder.dart';
import '../../app/theme.dart';
import '../../backend/application/sleep_service.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'sleep_view_model.dart';
import '../../l10n/l10n.dart';

/// The sleep goal, and the bedtime reminder once there is one: rows for
/// a [GroupedCard], the same on the sleep page and under 我的.
List<Widget> sleepGoalRows(BuildContext context, SleepViewModel model) => [
  NavRow(
    title: context.l10n.sleepGoal,
    trailing: Text(switch (model.goal) {
      final goal? => formatHoursMinutes(goal),
      null => context.l10n.notSet,
    }, style: AppTextStyles.caption),
    onTap: () => _editGoal(context, model),
  ),
  if (model.goal != null)
    SwitchRow(
      title: context.l10n.bedtimeReminder,
      subtitle: switch (model.tonightPlan) {
        final plan? => context.l10n.remindsAt(
          time: formatTimeOfDay(
            plan.bedtime.subtract(SleepService.reminderLead),
          ),
        ),
        null => null,
      },
      value: model.isReminderOn,
      onChanged: (isOn) {
        model.setReminder(isOn);
        syncBedtimeReminder(AppStoreScope.read(context).backend, context.l10n);
      },
    ),
];

Future<void> _editGoal(BuildContext context, SleepViewModel model) async {
  var minutes = (model.goal ?? const Duration(hours: 8)).inMinutes;
  final result = await showAppDialog<Duration?>(
    context,
    StatefulBuilder(
      builder: (context, setState) => AppDialog(
        title: context.l10n.sleepGoal,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatHoursMinutes(Duration(minutes: minutes)),
              style: AppTextStyles.hugeNumber.copyWith(
                color: AppColors.wellness,
              ),
            ),
            StepSlider(
              value: minutes.toDouble(),
              min: 300,
              max: 600,
              step: 15,
              color: AppColors.wellness,
              semanticLabel: context.l10n.sleepGoal,
              labelOf: (value) =>
                  formatHoursMinutes(Duration(minutes: value.round())),
              onChanged: (value) => setState(() => minutes = value.round()),
            ),
          ],
        ),
        actions: [
          DialogAction(
            label: context.l10n.commonSave,
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(Duration(minutes: minutes)),
          ),
          if (model.goal != null)
            DialogAction(
              label: context.l10n.clearGoal,
              tone: DialogTone.destructive,
              onTap: () => Navigator.of(context).pop(Duration.zero),
            ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  model.setGoal(result == Duration.zero ? null : result);
  syncBedtimeReminder(AppStoreScope.read(context).backend, context.l10n);
}
