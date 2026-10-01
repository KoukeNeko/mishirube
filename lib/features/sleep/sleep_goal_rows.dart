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
      final goal? => formatDuration(context.l10n, goal),
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
  // A schedule the user picks, drawn on the nights' charts as lines; off
  // until set, and nothing is scored against it (research/85).
  for (final (title, minutes, set, start) in [
    (
      context.l10n.targetBedtime,
      model.targetBedtime,
      model.setTargetBedtime,
      const TimeOfDay(hour: 23, minute: 0),
    ),
    (
      context.l10n.targetWake,
      model.targetWake,
      model.setTargetWake,
      const TimeOfDay(hour: 7, minute: 0),
    ),
  ])
    NavRow(
      title: title,
      trailing: Text(
        minutes == null ? context.l10n.notSet : formatMinutesOfDay(minutes),
        style: AppTextStyles.caption,
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: minutes == null
              ? start
              : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        );
        if (picked != null) set(picked.hour * 60 + picked.minute);
      },
    ),
  if (model.targetBedtime != null || model.targetWake != null)
    NavRow(
      title: context.l10n.clearTargetSchedule,
      isDestructive: true,
      showChevron: false,
      onTap: () {
        model.setTargetBedtime(null);
        model.setTargetWake(null);
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
              formatDuration(context.l10n, Duration(minutes: minutes)),
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
              labelOf: (value) => formatDuration(
                context.l10n,
                Duration(minutes: value.round()),
              ),
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
