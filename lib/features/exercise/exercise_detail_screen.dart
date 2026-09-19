import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../shared/widgets/widgets.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.canAdd = false,
  });

  final ExerciseDefinition exercise;

  /// When opened from the picker, the footer offers「加入這個動作」.
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final hasHistory = exercise.recordCount > 0;
    return DetailPage(
      appBar: PageAppBar(
        title: exercise.name,
        subtitle: '${exercise.equipment.label} · ${exercise.source.label}動作',
      ),
      footer: canAdd
          ? Row(
              children: [
                SquareIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: '看替代動作',
                  size: 60,
                  onPressed: () => showMockSnackBar(context, '替代動作只在訓練進行中提供'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: '加入這個動作',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            )
          : null,
      children: [
        const _DemoPlaceholder(),
        _SpecCard(exercise: exercise),
        if (exercise.cues.isNotEmpty) ...[
          const SectionLabel('重點提示'),
          _CueList(cues: exercise.cues),
        ],
        const SectionLabel('你的紀錄'),
        if (hasHistory)
          const _HistoryCard()
        else
          const InfoBanner(message: '還沒有這個動作的紀錄，做過一次之後這裡會顯示歷史。'),
        const SectionLabel('管理'),
        GroupedCard(
          children: [
            NavRow(
              title: exercise.isFavorite ? '取消收藏' : '加入收藏',
              onTap: () => showMockSnackBar(context, '已更新收藏'),
            ),
            NavRow(
              title: '編輯我的別名',
              subtitle: exercise.aliases.join('、'),
              onTap: () => showMockSnackBar(context, '別名只影響你自己的搜尋'),
            ),
            NavRow(
              title: '隱藏這個動作',
              onTap: () => showMockSnackBar(context, '隱藏不會刪除歷史紀錄'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DemoPlaceholder extends StatelessWidget {
  const _DemoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl + AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_arrow_outlined, color: AppColors.textTertiary),
          SizedBox(width: AppSpacing.xs),
          Text('[ 示範動畫 ]', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.exercise});

  final ExerciseDefinition exercise;

  @override
  Widget build(BuildContext context) {
    final secondary = exercise.secondaryMuscles.map((m) => m.label).join('、');
    return GroupedCard(
      children: [
        KeyValueRow(label: '器材', value: exercise.equipment.label),
        KeyValueRow(label: '主要肌群', value: exercise.muscleSummary),
        if (secondary.isNotEmpty) KeyValueRow(label: '次要肌群', value: secondary),
        KeyValueRow(label: '動作模式', value: exercise.pattern.label),
        KeyValueRow(label: '追蹤方式', value: exercise.trackingType.label),
        const KeyValueRow(label: '重量計算', value: '總重量'),
      ],
    );
  }
}

class _CueList extends StatelessWidget {
  const _CueList({required this.cues});

  final List<String> cues;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < cues.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.training,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(child: Text(cues[i], style: AppTextStyles.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatRow(
            stats: [
              StatBlock(value: '80', unit: 'kg', label: '上次工作組'),
              StatBlock(
                value: '117',
                unit: 'kg',
                label: '估計最大重量',
                valueColor: AppColors.training,
              ),
              StatBlock(value: '24', unit: '次', label: '訓練紀錄'),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          for (final (date, result) in MockExercises.recentHistory)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Text(date, style: AppTextStyles.itemTitle),
                  const Spacer(),
                  Text(
                    result,
                    style: AppTextStyles.caption.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          const TagWrap(labels: ['最大重量為 Epley 估計', '近 90 天']),
        ],
      ),
    );
  }
}
