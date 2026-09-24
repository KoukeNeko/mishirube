import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_detail_screen.dart';

/// How far a swap reaches. There is no program above the template, so
/// there is no third option to offer.
enum _ReplaceScope {
  todayOnly('只替換今天', '只有這次用新動作'),
  template('也更新這個訓練', '之後都改用新動作');

  const _ReplaceScope(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class SubstituteExerciseScreen extends StatefulWidget {
  const SubstituteExerciseScreen({super.key});

  @override
  State<SubstituteExerciseScreen> createState() =>
      _SubstituteExerciseScreenState();
}

class _SubstituteExerciseScreenState extends State<SubstituteExerciseScreen> {
  int _selectedCandidate = 0;
  _ReplaceScope _scope = _ReplaceScope.todayOnly;

  void _replace(List<SubstitutionOption> candidates, String routineName) {
    final store = AppStoreScope.read(context);
    final replacement = candidates[_selectedCandidate].exercise;
    store.replaceCurrentExercise(
      replacement,
      updateTemplate: _scope == _ReplaceScope.template,
    );
    Navigator.of(context).pop();
    showToast(context, switch (_scope) {
      _ReplaceScope.todayOnly => '今天改做「${replacement.name}」',
      _ReplaceScope.template => '今天與之後的「$routineName」都改做「${replacement.name}」',
    }, kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final workout = AppStoreScope.of(context).activeWorkout;
    if (workout == null) return const Scaffold();
    final current = workout.currentExercise.exercise;
    final candidates = AppStoreScope.of(context).substitutesFor(current);
    final selected = candidates.isEmpty ? null : candidates[_selectedCandidate];
    final needsWeightReset =
        selected != null && selected.exercise.equipment != current.equipment;

    return DetailPage(
      appBar: PageAppBar(
        title: '替換 ${current.pattern.label}',
        subtitle:
            '今天的「${workout.routineName}」· 第 '
            '${workout.currentExerciseIndex + 1} 個動作',
      ),
      footer: ButtonPair(
        secondary: SecondaryButton(
          label: '取消',
          onPressed: () => Navigator.of(context).pop(),
        ),
        primary: PrimaryButton(
          label: '替換',
          onPressed: candidates.isEmpty
              ? null
              : () => _replace(candidates, workout.routineName),
        ),
      ),
      children: [
        Gutter(child: const SectionLabel('候選動作')),
        for (var i = 0; i < candidates.length; i++)
          Gutter(
            child: _CandidateCard(
              option: candidates[i],
              isSelected: i == _selectedCandidate,
              onTap: () => setState(() => _selectedCandidate = i),
            ),
          ),
        Gutter(child: const SectionLabel('套用範圍')),
        for (final scope in _ReplaceScope.values)
          Gutter(
            child: RadioRow(
              title: scope.title,
              subtitle: scope.subtitle,
              isSelected: scope == _scope,
              onTap: () => setState(() => _scope = scope),
            ),
          ),
        if (needsWeightReset)
          Gutter(
            child: InfoBanner(
              tone: CardTone.warning,
              message:
                  '${current.equipment.label}換${selected.exercise.equipment.label}'
                  '沒有可靠的重量換算：保留組數、次數與 RIR，重量重新設定。',
            ),
          ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final SubstitutionOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exercise = option.exercise;
    return AppCard(
      tone: isSelected ? CardTone.training : CardTone.neutral,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RadioDot(isSelected: isSelected),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: AppTextStyles.itemTitle),
                    Text(
                      '${exercise.equipment.label} · ${exercise.muscleSummary}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              SquareIconButton(
                icon: Icons.info_outline,
                tooltip: '動作說明',
                size: 40,
                onPressed: () =>
                    pushPage(context, ExerciseDetailScreen(exercise: exercise)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TagWrap(
            labels: option.reasons,
            tone: isSelected ? TagTone.training : TagTone.neutral,
          ),
        ],
      ),
    );
  }
}
