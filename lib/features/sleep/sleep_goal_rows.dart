import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/bedtime_reminder.dart';
import '../../app/theme.dart';
import '../../backend/application/sleep_service.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'sleep_view_model.dart';

/// The sleep goal, and the bedtime reminder once there is one: rows for
/// a [GroupedCard], the same on the sleep page and under 我的.
List<Widget> sleepGoalRows(BuildContext context, SleepViewModel model) => [
  NavRow(
    title: '睡眠目標',
    trailing: Text(switch (model.goal) {
      final goal? => formatHoursMinutes(goal),
      null => '未設定',
    }, style: AppTextStyles.caption),
    onTap: () => _editGoal(context, model),
  ),
  if (model.goal != null)
    SwitchRow(
      title: '就寢提醒',
      subtitle: switch (model.tonightPlan) {
        final plan? =>
          '${formatTimeOfDay(plan.bedtime.subtract(SleepService.reminderLead))} 提醒',
        null => null,
      },
      value: model.isReminderOn,
      onChanged: (isOn) {
        model.setReminder(isOn);
        syncBedtimeReminder(AppStoreScope.read(context).backend);
      },
    ),
];

Future<void> _editGoal(BuildContext context, SleepViewModel model) async {
  var minutes = (model.goal ?? const Duration(hours: 8)).inMinutes;
  final result = await showAppDialog<Duration?>(
    context,
    StatefulBuilder(
      builder: (context, setState) => AppDialog(
        title: '睡眠目標',
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
              semanticLabel: '睡眠目標',
              labelOf: (value) =>
                  formatHoursMinutes(Duration(minutes: value.round())),
              onChanged: (value) => setState(() => minutes = value.round()),
            ),
          ],
        ),
        actions: [
          DialogAction(
            label: '儲存',
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(Duration(minutes: minutes)),
          ),
          if (model.goal != null)
            DialogAction(
              label: '清除目標',
              tone: DialogTone.destructive,
              onTap: () => Navigator.of(context).pop(Duration.zero),
            ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    ),
  );
  if (result == null || !context.mounted) return;
  model.setGoal(result == Duration.zero ? null : result);
  syncBedtimeReminder(AppStoreScope.read(context).backend);
}
