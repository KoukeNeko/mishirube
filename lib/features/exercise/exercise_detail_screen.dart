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
import '../../l10n/l10n.dart';

/// Asks for the names this user wants to find [exercise] by.
Future<void> _editAliases(
  BuildContext context,
  ExerciseDefinition exercise,
) async {
  final store = AppStoreScope.read(context);
  final entered = await showTextDialog(
    context,
    title: context.l10n.myAliases,
    initial: joinList(context.l10n, exercise.personalAliases),
    hint: context.l10n.aliasesHint,
  );
  if (entered == null || !context.mounted) return;
  store.setPersonalAliases(exercise, [
    for (final alias in entered.split(RegExp('[、,，]')))
      if (alias.trim().isNotEmpty) alias.trim(),
  ]);
  showToast(context, context.l10n.aliasesUpdated);
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
    showToast(context, context.l10n.cannotMergeSelf, kind: ToastKind.warning);
    return;
  }
  final confirmed = await showAppDialog<bool>(
    context,
    AppDialog(
      title: context.l10n.mergeTitle(
        duplicate: duplicate.name,
        canonical: canonical.name,
      ),
      message: context.l10n.mergeMessage(canonical: canonical.name),
      actions: [
        DialogAction(
          label: context.l10n.mergeInto(canonical: canonical.name),
          tone: DialogTone.destructive,
          onTap: () => Navigator.of(context).pop(true),
        ),
        DialogAction(
          label: context.l10n.commonCancel,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  store.mergeExercise(duplicate: duplicate, canonical: canonical);
  Navigator.of(context).pop();
  showToast(
    context,
    context.l10n.mergedInto(canonical: canonical.name),
    kind: ToastKind.success,
  );
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
        subtitle:
            '${exercise.equipment.labelIn(context.l10n)} · '
            '${context.l10n.exerciseOfSource(source: exercise.source.labelIn(context.l10n))}',
      ),
      footer: canAdd
          ? PrimaryButton(
              label: context.l10n.addThisExercise,
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
          Gutter(child: SectionLabel(context.l10n.otherVariations)),
          Gutter(
            child: GroupedCard(
              children: [
                for (final other in others)
                  NavRow(
                    title: other.name,
                    subtitle: other.equipment.labelIn(context.l10n),
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
          Gutter(child: SectionLabel(context.l10n.cuesSection)),
          Gutter(child: _CueList(cues: exercise.cues)),
        ],
        Gutter(child: SectionLabel(context.l10n.recordTitle)),
        if (history.last != null)
          Gutter(
            child: _HistoryCard(exercise: exercise, history: history),
          )
        else
          Gutter(child: InfoBanner(message: context.l10n.noEntriesSentence)),
        Gutter(child: SectionLabel(context.l10n.manageSection)),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: exercise.isFavorite
                    ? context.l10n.removeFavorite
                    : context.l10n.addFavorite,
                onTap: () {
                  store.toggleFavorite(exercise);
                  showToast(
                    context,
                    exercise.isFavorite
                        ? context.l10n.favoriteRemoved
                        : context.l10n.favoriteAdded,
                    kind: ToastKind.success,
                  );
                },
              ),
              if (exercise.source != ExerciseSource.builtIn)
                NavRow(
                  title: context.l10n.editExercise,
                  subtitle: context.l10n.editExerciseDetail,
                  onTap: () => pushModalPage<void>(
                    context,
                    CreateExerciseScreen(editing: exercise),
                  ),
                ),
              NavRow(
                title: context.l10n.editMyAliases,
                subtitle: exercise.personalAliases.isEmpty
                    ? context.l10n.builtInNames(
                        names: joinList(context.l10n, exercise.aliases),
                      )
                    : joinList(context.l10n, exercise.personalAliases),
                onTap: () => _editAliases(context, exercise),
              ),
              if (exercise.source != ExerciseSource.builtIn)
                NavRow(
                  title: context.l10n.mergeIntoAnother,
                  subtitle: context.l10n.mergeIntoAnotherDetail,
                  onTap: () => _mergeInto(context, exercise),
                ),
              NavRow(
                title: exercise.isHidden
                    ? context.l10n.unhide
                    : context.l10n.hideExercise,
                onTap: () {
                  store.toggleHidden(exercise);
                  showToast(
                    context,
                    exercise.isHidden
                        ? context.l10n.unhidden(name: exercise.name)
                        : context.l10n.hidden(name: exercise.name),
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
    final secondary = joinList(
      context.l10n,
      exercise.secondaryMuscles.map((m) => m.labelIn(context.l10n)),
    );
    final regions = joinList(context.l10n, {
      for (final muscle in exercise.primaryMuscles)
        muscle.region.labelIn(context.l10n),
    });
    return GroupedCard(
      children: [
        KeyValueRow(label: context.l10n.bodyPartLabel, value: regions),
        KeyValueRow(
          label: context.l10n.primaryMuscles,
          value: exercise.muscleSummary(context.l10n),
        ),
        if (secondary.isNotEmpty)
          KeyValueRow(label: context.l10n.secondaryMuscles, value: secondary),
        KeyValueRow(
          label: context.l10n.equipmentSection,
          value: exercise.equipment.labelIn(context.l10n),
        ),
        KeyValueRow(
          label: context.l10n.movementPatternLabel,
          value: exercise.pattern.labelIn(context.l10n),
        ),
        KeyValueRow(
          label: context.l10n.lateralityLabel,
          value: exercise.laterality.labelIn(context.l10n),
        ),
        KeyValueRow(
          label: context.l10n.trackingTypeSection,
          value: exercise.trackingType.labelIn(context.l10n),
        ),
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
  const _HistoryCard({required this.exercise, required this.history});

  static const _recentCount = 3;

  final ExerciseDefinition exercise;
  final ExerciseHistory history;

  /// Each session's estimated max, oldest first, for the trend line.
  List<double> get _estimates => [
    for (final entry in history.recent.reversed) ?entry.oneRepMaxKg,
  ];

  @override
  Widget build(BuildContext context) {
    final estimate = history.estimatedOneRepMaxKg;
    // A max is only estimated from weight and reps.
    final estimatesMax = exercise.trackingType == TrackingType.weightReps;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatRow(
            stats: [
              if (estimatesMax)
                StatBlock(
                  value: formatWeight(history.last!.weightKg),
                  unit: 'kg',
                  label: context.l10n.lastWorkingSet,
                )
              else
                StatBlock(
                  value: history.last!.figuresIn(
                    context.l10n,
                    exercise.trackingType,
                  ),
                  label: context.l10n.lastWorkingSet,
                ),
              if (estimatesMax)
                StatBlock(
                  value: estimate == null ? '—' : estimate.round().toString(),
                  unit: estimate == null ? null : 'kg',
                  label: context.l10n.estimatedMax,
                  valueColor: AppColors.training,
                ),
              StatBlock(
                value: '${history.sessionCount}',
                unit: context.l10n.sessionsUnit,
                label: context.l10n.trainingEntries,
              ),
            ],
          ),
          if (_estimates case final estimates when estimates.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: context.l10n.estimatedMaxTrend(count: estimates.length),
              excludeSemantics: true,
              child: Sparkline(
                values: estimates,
                color: AppColors.training,
                isEstimate: true,
              ),
            ),
          ],
          const Divider(height: AppSpacing.xl),
          for (final entry in history.recent.take(_recentCount))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    context.dates.compactMonthDay(entry.date),
                    style: AppTextStyles.itemTitle,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${entry.figuresIn(context.l10n, exercise.trackingType)}'
                      '${entry.rir == null ? '' : ' · RIR ${entry.rir}'}',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          TagWrap(
            labels: [
              if (estimatesMax) context.l10n.epleyEstimate,
              context.l10n.last90Days,
            ],
          ),
        ],
      ),
    );
  }
}
