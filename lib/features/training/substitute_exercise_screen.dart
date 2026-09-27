import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_detail_screen.dart';
import '../exercise/exercise_picker_screen.dart';
import '../../l10n/l10n.dart';

/// How far a swap reaches. There is no program above the template, so
/// there is no third option to offer.
enum _ReplaceScope {
  todayOnly,
  template;

  String title(AppLocalizations l10n) => switch (this) {
    todayOnly => l10n.replaceTodayOnly,
    template => l10n.replaceInRoutine,
  };

  String subtitle(AppLocalizations l10n) => switch (this) {
    todayOnly => l10n.replaceTodayOnlyDetail,
    template => l10n.replaceInRoutineDetail,
  };
}

class SubstituteExerciseScreen extends StatefulWidget {
  const SubstituteExerciseScreen({super.key});

  @override
  State<SubstituteExerciseScreen> createState() =>
      _SubstituteExerciseScreenState();
}

class _SubstituteExerciseScreenState extends State<SubstituteExerciseScreen> {
  /// The suggestion chosen; null when one from the whole library is.
  int? _selectedCandidate = 0;

  /// One chosen from the whole library rather than the suggestions.
  ExerciseDefinition? _picked;
  _ReplaceScope _scope = _ReplaceScope.todayOnly;

  ExerciseDefinition? _replacement(List<SubstitutionOption> candidates) =>
      switch (_selectedCandidate) {
        final i? when i < candidates.length => candidates[i].exercise,
        _ => _picked,
      };

  /// Any exercise, from the library with its search and filters.
  Future<void> _pickAny() async {
    final picked = await pushModalPage<List<ExerciseDefinition>>(
      context,
      const ExercisePickerScreen(purpose: PickerPurpose.single),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _picked = picked.first;
      _selectedCandidate = null;
    });
  }

  void _replace(List<SubstitutionOption> candidates, String routineName) {
    final store = AppStoreScope.read(context);
    final replacement = _replacement(candidates);
    if (replacement == null) return;
    store.replaceCurrentExercise(
      replacement,
      updateTemplate: _scope == _ReplaceScope.template,
    );
    Navigator.of(context).pop();
    showToast(context, switch (_scope) {
      _ReplaceScope.todayOnly => context.l10n.replacedToday(
        name: replacement.name,
      ),
      _ReplaceScope.template => context.l10n.replacedInRoutine(
        routine: routineName,
        name: replacement.name,
      ),
    }, kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final workout = AppStoreScope.of(context).activeWorkout;
    if (workout == null) return const Scaffold();
    final current = workout.currentExercise.exercise;
    final candidates = AppStoreScope.of(context).substitutesFor(current);
    final selected = _replacement(candidates);
    final needsWeightReset =
        selected != null && selected.equipment != current.equipment;

    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.replacePattern(
          pattern: current.pattern.labelIn(context.l10n),
        ),
        subtitle: context.l10n.todaysExerciseNumber(
          routine: workout.routineName,
          number: workout.currentExerciseIndex + 1,
        ),
      ),
      footer: ButtonPair(
        secondary: SecondaryButton(
          label: context.l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        primary: PrimaryButton(
          label: context.l10n.replaceAction,
          onPressed: selected == null
              ? null
              : () => _replace(candidates, workout.routineName),
        ),
      ),
      children: [
        if (candidates.isNotEmpty)
          Gutter(child: SectionLabel(context.l10n.candidateExercises)),
        for (var i = 0; i < candidates.length; i++)
          Gutter(
            child: _CandidateCard(
              exercise: candidates[i].exercise,
              reasons: [
                for (final reason in candidates[i].reasons)
                  reason.text(context.l10n),
              ],
              isSelected: i == _selectedCandidate,
              onTap: () => setState(() => _selectedCandidate = i),
            ),
          ),
        if (_picked case final picked?)
          Gutter(
            child: _CandidateCard(
              exercise: picked,
              reasons: const [],
              isSelected: _selectedCandidate == null,
              onTap: () => setState(() => _selectedCandidate = null),
            ),
          ),
        Gutter(
          child: DashedActionCard(
            label: context.l10n.chooseFromAll,
            onTap: _pickAny,
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.applyScope)),
        for (final scope in _ReplaceScope.values)
          Gutter(
            child: RadioRow(
              title: scope.title(context.l10n),
              subtitle: scope.subtitle(context.l10n),
              isSelected: scope == _scope,
              onTap: () => setState(() => _scope = scope),
            ),
          ),
        if (needsWeightReset)
          Gutter(
            child: InfoBanner(
              tone: CardTone.warning,
              message: context.l10n.equipmentChangeWarning(
                from: current.equipment.labelIn(context.l10n),
                to: selected.equipment.labelIn(context.l10n),
              ),
            ),
          ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.exercise,
    required this.reasons,
    required this.isSelected,
    required this.onTap,
  });

  final ExerciseDefinition exercise;

  /// Why it is a fair swap; none for one picked from the library.
  final List<String> reasons;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      '${exercise.equipment.labelIn(context.l10n)} · ${exercise.muscleSummary(context.l10n)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              SquareIconButton(
                icon: Icons.info_outline,
                tooltip: context.l10n.exerciseInfo,
                size: 40,
                onPressed: () =>
                    pushPage(context, ExerciseDetailScreen(exercise: exercise)),
              ),
            ],
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            TagWrap(
              labels: reasons,
              tone: isSelected ? TagTone.training : TagTone.neutral,
            ),
          ],
        ],
      ),
    );
  }
}
