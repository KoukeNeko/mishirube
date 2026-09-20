import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../app/navigation.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'create_exercise_screen.dart';

/// Asks for the names this user wants to find [exercise] by.
Future<void> _editAliases(
  BuildContext context,
  ExerciseDefinition exercise,
) async {
  final store = AppStoreScope.read(context);
  final controller = TextEditingController(
    text: exercise.personalAliases.join('、'),
  );
  final entered = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('我的別名'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '用、分隔，例如：深蹲、squat'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('儲存'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (entered == null || !context.mounted) return;
  store.setPersonalAliases(exercise, [
    for (final alias in entered.split(RegExp('[、,，]')))
      if (alias.trim().isNotEmpty) alias.trim(),
  ]);
  showToast(context, '別名只影響你自己的搜尋');
}

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
    final store = AppStoreScope.of(context);
    // The stored definition, so favourite changes show up while open.
    final exercise = store.exercises.firstWhere(
      (candidate) => candidate == this.exercise,
      orElse: () => this.exercise,
    );
    final history = store.exerciseHistory(exercise);
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
                  onPressed: () => showToast(context, '替代動作只在訓練進行中提供'),
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
        Gutter(child: const _DemoPlaceholder()),
        Gutter(child: _SpecCard(exercise: exercise)),
        if (exercise.cues.isNotEmpty) ...[
          Gutter(child: const SectionLabel('重點提示')),
          Gutter(child: _CueList(cues: exercise.cues)),
        ],
        Gutter(child: const SectionLabel('你的紀錄')),
        if (history.last != null)
          Gutter(child: _HistoryCard(history: history))
        else
          Gutter(child: const InfoBanner(message: '還沒有這個動作的紀錄，做過一次之後這裡會顯示歷史。')),
        Gutter(child: const SectionLabel('管理')),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: exercise.isFavorite ? '取消收藏' : '加入收藏',
                onTap: () {
                  store.toggleFavorite(exercise);
                  showToast(context, '已更新收藏', kind: ToastKind.success);
                },
              ),
              if (exercise.source != ExerciseSource.builtIn)
                NavRow(
                  title: '編輯動作',
                  subtitle: '名稱、器材、部位',
                  onTap: () => pushModalPage<void>(
                    context,
                    CreateExerciseScreen(editing: exercise),
                  ),
                ),
              NavRow(
                title: '編輯我的別名',
                subtitle: exercise.personalAliases.isEmpty
                    ? '目前用內建名稱：${exercise.aliases.join('、')}'
                    : exercise.personalAliases.join('、'),
                onTap: () => _editAliases(context, exercise),
              ),
              NavRow(
                title: exercise.isHidden ? '取消隱藏' : '隱藏這個動作',
                subtitle: exercise.isHidden ? '目前不會出現在選擇器' : null,
                onTap: () {
                  store.toggleHidden(exercise);
                  showToast(context, '隱藏不會刪除歷史紀錄');
                },
              ),
            ],
          ),
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
  const _HistoryCard({required this.history});

  static const _recentCount = 3;

  final ExerciseHistory history;

  @override
  Widget build(BuildContext context) {
    final estimate = history.estimatedOneRepMaxKg;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatRow(
            stats: [
              StatBlock(
                value: formatWeight(history.last!.weightKg),
                unit: 'kg',
                label: '上次工作組',
              ),
              StatBlock(
                value: estimate == null ? '—' : estimate.round().toString(),
                unit: estimate == null ? null : 'kg',
                label: '估計最大重量',
                valueColor: AppColors.training,
              ),
              StatBlock(
                value: '${history.sessionCount}',
                unit: '次',
                label: '訓練紀錄',
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          for (final entry in history.recent.take(_recentCount))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    '${entry.date.month} / ${entry.date.day}',
                    style: AppTextStyles.itemTitle,
                  ),
                  const Spacer(),
                  Text(
                    '${formatWeight(entry.weightKg)} kg × ${entry.reps}'
                    '${entry.rir == null ? '' : ' · RIR ${entry.rir}'}',
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
