import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../app/navigation.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'exercise_picker_screen.dart';
import '../trends/muscle_map.dart';
import 'create_exercise_screen.dart';
import 'exercise_demo.dart';

/// Asks for the names this user wants to find [exercise] by.
Future<void> _editAliases(
  BuildContext context,
  ExerciseDefinition exercise,
) async {
  final store = AppStoreScope.read(context);
  final entered = await showTextDialog(
    context,
    title: '我的別名',
    initial: exercise.personalAliases.join('、'),
    hint: '用、分隔，例如：深蹲、squat',
  );
  if (entered == null || !context.mounted) return;
  store.setPersonalAliases(exercise, [
    for (final alias in entered.split(RegExp('[、,，]')))
      if (alias.trim().isNotEmpty) alias.trim(),
  ]);
  showToast(context, '已更新別名');
}

/// Folds this exercise into another one, after the user picks which and
/// says yes. Offered for the exercises a user can end up with twice.
Future<void> _mergeInto(
  BuildContext context,
  ExerciseDefinition duplicate,
) async {
  final store = AppStoreScope.read(context);
  final picked = await pushModalPage<List<ExerciseDefinition>>(
    context,
    const ExercisePickerScreen(purpose: PickerPurpose.single),
  );
  final canonical = picked?.firstOrNull;
  if (canonical == null || !context.mounted) return;
  if (canonical.id == duplicate.id) {
    showToast(context, '不能和自己合併', kind: ToastKind.warning);
    return;
  }
  final confirmed = await showAppDialog<bool>(
    context,
    AppDialog(
      title: '把「${duplicate.name}」併入「${canonical.name}」？',
      message:
          '過去的紀錄改算在「${canonical.name}」下，動作不再出現在選擇器。'
          '紀錄的內容不會被改寫，但這個合併無法復原。',
      actions: [
        DialogAction(
          label: '併入「${canonical.name}」',
          tone: DialogTone.destructive,
          onTap: () => Navigator.of(context).pop(true),
        ),
        DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  store.mergeExercise(duplicate: duplicate, canonical: canonical);
  Navigator.of(context).pop();
  showToast(context, '已併入「${canonical.name}」', kind: ToastKind.success);
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
          ? PrimaryButton(
              label: '加入這個動作',
              onPressed: () => Navigator.of(context).pop(true),
            )
          : null,
      children: [
        if (exercise.frames.isNotEmpty) ...[
          Gutter(
            child: AppCard(
              child: ExerciseDemo(name: exercise.name, frames: exercise.frames),
            ),
          ),
          Gutter(child: const ExerciseDemoCredit()),
        ],
        Gutter(child: _SpecCard(exercise: exercise)),
        Gutter(
          child: AppCard(
            child: MuscleRoleMap(
              primary: exercise.primaryMuscles,
              secondary: exercise.secondaryMuscles,
            ),
          ),
        ),
        if (_sameMovement(store, exercise) case final others
            when others.isNotEmpty) ...[
          Gutter(child: const SectionLabel('同一動作的其他做法')),
          Gutter(
            child: GroupedCard(
              children: [
                for (final other in others)
                  NavRow(
                    title: other.name,
                    subtitle: other.equipment.label,
                    onTap: () => pushModalPage<void>(
                      context,
                      ExerciseDetailScreen(exercise: other),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (exercise.cues.isNotEmpty) ...[
          Gutter(child: const SectionLabel('重點提示')),
          Gutter(child: _CueList(cues: exercise.cues)),
        ],
        Gutter(child: const SectionLabel('紀錄')),
        if (history.last != null)
          Gutter(child: _HistoryCard(history: history))
        else
          Gutter(child: const InfoBanner(message: '沒有紀錄。')),
        Gutter(child: const SectionLabel('管理')),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: exercise.isFavorite ? '取消收藏' : '加入收藏',
                onTap: () {
                  store.toggleFavorite(exercise);
                  showToast(
                    context,
                    exercise.isFavorite ? '已取消收藏' : '已加入收藏',
                    kind: ToastKind.success,
                  );
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
              if (exercise.source != ExerciseSource.builtIn)
                NavRow(
                  title: '合併到另一個動作',
                  subtitle: '重複建立時，把紀錄併到同一個動作下',
                  onTap: () => _mergeInto(context, exercise),
                ),
              NavRow(
                title: exercise.isHidden ? '取消隱藏' : '隱藏這個動作',
                onTap: () {
                  store.toggleHidden(exercise);
                  showToast(
                    context,
                    exercise.isHidden
                        ? '已取消隱藏「${exercise.name}」'
                        : '已隱藏「${exercise.name}」',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Other versions of the same movement — a dumbbell press beside the
/// barbell one — that are shown in pickers.
List<ExerciseDefinition> _sameMovement(
  AppStore store,
  ExerciseDefinition exercise,
) => exercise.family.isEmpty
    ? const []
    : [
        for (final other in store.exercises)
          if (other.family == exercise.family &&
              other.id != exercise.id &&
              !other.isHidden)
            other,
      ];

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.exercise});

  final ExerciseDefinition exercise;

  @override
  Widget build(BuildContext context) {
    final secondary = exercise.secondaryMuscles.map((m) => m.label).join('、');
    final regions = {
      for (final muscle in exercise.primaryMuscles) muscle.region.label,
    }.join('、');
    return GroupedCard(
      children: [
        KeyValueRow(label: '部位', value: regions),
        KeyValueRow(label: '主要肌群', value: exercise.muscleSummary),
        if (secondary.isNotEmpty) KeyValueRow(label: '次要肌群', value: secondary),
        KeyValueRow(label: '器材', value: exercise.equipment.label),
        KeyValueRow(label: '動作模式', value: exercise.pattern.label),
        KeyValueRow(label: '左右', value: exercise.laterality.label),
        KeyValueRow(label: '追蹤方式', value: exercise.trackingType.label),
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

  /// Each session's estimated max, oldest first, for the trend line.
  List<double> get _estimates => [
    for (final entry in history.recent.reversed) ?entry.oneRepMaxKg,
  ];

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
          if (_estimates case final estimates when estimates.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: '估計最大重量走勢，${estimates.length} 次訓練',
              excludeSemantics: true,
              child: Sparkline(values: estimates, color: AppColors.training),
            ),
          ],
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${formatWeight(entry.weightKg)} kg × ${entry.reps}'
                      '${entry.rir == null ? '' : ' · RIR ${entry.rir}'}',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          const TagWrap(labels: ['Epley 估計', '近 90 天']),
        ],
      ),
    );
  }
}
