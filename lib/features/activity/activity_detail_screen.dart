import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'record_activity_screen.dart';

/// One logged session: what it was, and the two things anyone wants to do
/// with it afterwards — correct it, or take it back.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activityId});

  final String activityId;

  void _delete(BuildContext context, ActivitySession activity) {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    store.deleteActivity(activity.id);
    Navigator.of(context).pop();
    toast.showUndo(
      '已刪除${activity.type.label}',
      onUndo: () => store.restoreActivity(activity.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = AppStoreScope.of(context).activityById(activityId);
    if (activity == null) {
      // The record is gone (undo not taken); the screen closes itself
      // rather than showing an empty shell.
      return const DetailPage(
        appBar: PageAppBar(title: '運動'),
        children: [Gutter(child: InfoBanner(message: '這筆紀錄已經刪除。'))],
      );
    }
    final pace = activity.pace;
    return DetailPage(
      appBar: PageAppBar(
        title: activity.type.label,
        subtitle:
            '${activity.startedAt.month} 月 ${activity.startedAt.day} 日 · '
            '${formatTimeOfDay(activity.startedAt)} – '
            '${formatTimeOfDay(activity.endedAt)}',
      ),
      children: [
        Gutter(
          child: AppCard(
            child: StatRow(
              stats: [
                StatBlock(
                  value: '${activity.duration.inMinutes}',
                  label: '分鐘',
                  valueColor: AppColors.activity,
                ),
                if (activity.distanceMeters case final metres?)
                  StatBlock(value: formatWeight(metres / 1000), label: '公里'),
                if (pace != null)
                  StatBlock(value: formatHoursMinutes(pace), label: '配速 /km'),
                if (activity.effort case final effort?)
                  StatBlock(value: '$effort', label: '強度 / 10'),
              ],
            ),
          ),
        ),
        if (activity.note.isNotEmpty) ...[
          Gutter(child: const SectionLabel('備註')),
          Gutter(
            child: AppCard(
              child: Text(activity.note, style: AppTextStyles.body),
            ),
          ),
        ],
        Gutter(child: const SectionLabel('管理')),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: '編輯內容',
                subtitle: '類型、時間、時長',
                onTap: () => pushModalPage<void>(
                  context,
                  RecordActivityScreen(activity: activity),
                ),
              ),
              NavRow(
                title: '刪除這筆紀錄',
                subtitle: '可以在提示中復原',
                onTap: () => _delete(context, activity),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
