import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

const _maxDuplicateCandidates = 3;

/// Coarse body regions offered when creating an exercise; details come later.
enum _BodyRegion {
  chest(MuscleGroup.chest),
  back(MuscleGroup.back),
  legs(MuscleGroup.quads),
  shoulders(MuscleGroup.shoulders),
  arms(MuscleGroup.arms),
  core(MuscleGroup.core);

  const _BodyRegion(this.muscle);

  final MuscleGroup muscle;

  String labelIn(AppLocalizations l10n) => switch (this) {
    chest => l10n.bodyRegionChest,
    back => l10n.bodyRegionBack,
    legs => l10n.bodyRegionLegs,
    shoulders => l10n.bodyRegionShoulders,
    arms => l10n.bodyRegionArms,
    core => l10n.bodyRegionCore,
  };
}

const _equipmentChoices = <Equipment?>[
  Equipment.barbell,
  Equipment.dumbbell,
  Equipment.cable,
  Equipment.machine,
  Equipment.bodyweight,
  null,
];

/// Pops with the new (or an existing duplicate) [ExerciseDefinition].
class CreateExerciseScreen extends StatefulWidget {
  const CreateExerciseScreen({super.key, this.initialName = '', this.editing});

  final String initialName;

  /// The exercise being edited; null when creating a new one.
  final ExerciseDefinition? editing;

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  late final _nameController = TextEditingController(
    text: widget.editing?.name ?? widget.initialName,
  );
  late TrackingType _trackingType =
      widget.editing?.trackingType ?? TrackingType.weightReps;
  late _BodyRegion _region = _regionOf(widget.editing) ?? _BodyRegion.chest;
  late Equipment? _equipment = widget.editing?.equipment ?? Equipment.dumbbell;
  String? _error;

  ExerciseDefinition? get _editing => widget.editing;

  static _BodyRegion? _regionOf(ExerciseDefinition? exercise) {
    final muscle = exercise?.primaryMuscles.firstOrNull;
    if (muscle == null) return null;
    for (final region in _BodyRegion.values) {
      if (region.muscle == muscle) return region;
    }
    return null;
  }

  String get _name => _nameController.text.trim();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Shown before creating, so a second 「啞鈴臥推」 does not start its own
  /// history.
  List<ExerciseDefinition> _possibleDuplicates() =>
      _name.isEmpty || _editing != null
      ? const []
      : AppStoreScope.of(context)
            .duplicateCandidatesFor(_name)
            .take(_maxDuplicateCandidates)
            .toList();

  void _submit() {
    final editing = _editing;
    final exercise = ExerciseDefinition(
      id: editing?.id ?? 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: _name,
      aliases: editing?.aliases ?? const [],
      personalAliases: editing?.personalAliases ?? const [],
      equipment: _equipment ?? Equipment.bodyweight,
      primaryMuscles: [_region.muscle],
      secondaryMuscles: editing?.secondaryMuscles ?? const [],
      pattern: editing?.pattern ?? MovementPattern.isolation,
      trackingType: _trackingType,
      source: editing?.source ?? ExerciseSource.custom,
      isFavorite: editing?.isFavorite ?? false,
      isHidden: editing?.isHidden ?? false,
      cues: editing?.cues ?? const [],
    );
    if (editing == null) {
      Navigator.of(context).pop(exercise);
      return;
    }
    try {
      AppStoreScope.read(context).updateExercise(exercise);
    } on TrackingChangeRefused catch (refusal) {
      setState(
        () => _error = context.l10n.trackingChangeRefused(
          count: refusal.sessionCount,
        ),
      );
      return;
    }
    Navigator.of(context).pop(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final duplicates = _possibleDuplicates();
    return DetailPage(
      appBar: PageAppBar(
        title: _editing == null
            ? context.l10n.createCustomExercise
            : context.l10n.editExercise,
        subtitle: _editing == null
            ? null
            : context.l10n.exerciseOfSource(
                source: _editing!.source.labelIn(context.l10n),
              ),
      ),
      footer: PrimaryButton(
        label: _editing == null
            ? context.l10n.createAndAdd
            : context.l10n.commonSave,
        onPressed: _name.isEmpty ? null : _submit,
      ),
      children: [
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
        if (duplicates.isNotEmpty)
          Gutter(
            child: _DuplicateWarning(
              candidates: duplicates,
              onUse: (exercise) => Navigator.of(context).pop(exercise),
            ),
          ),
        Gutter(child: SectionLabel(context.l10n.nameSection)),
        Gutter(
          child: AppTextField(
            controller: _nameController,
            hint: context.l10n.exerciseNameHint,
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.trackingTypeSection)),
        Gutter(
          child: ChipWrap(
            options: TrackingType.values,
            labelOf: (type) => type.labelIn(context.l10n),
            isSelected: (type) => type == _trackingType,
            onTap: (type) => setState(() => _trackingType = type),
          ),
        ),
        Gutter(
          child: Text(
            context.l10n.trackingTypeLocked,
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.primaryMuscleOrPattern)),
        Gutter(
          child: ChipWrap(
            options: _BodyRegion.values,
            labelOf: (region) => region.labelIn(context.l10n),
            isSelected: (region) => region == _region,
            onTap: (region) => setState(() => _region = region),
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.equipmentSection)),
        Gutter(
          child: ChipWrap(
            options: _equipmentChoices,
            labelOf: (equipment) =>
                equipment?.labelIn(context.l10n) ?? context.l10n.equipmentAny,
            isSelected: (equipment) => equipment == _equipment,
            onTap: (equipment) => setState(() => _equipment = equipment),
          ),
        ),
      ],
    );
  }
}

class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({required this.candidates, required this.onUse});

  final List<ExerciseDefinition> candidates;
  final ValueChanged<ExerciseDefinition> onUse;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: CardTone.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.l10n.possibleDuplicate,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final exercise in candidates) ...[
            NavCard(
              title: exercise.name,
              subtitle:
                  '${exercise.source.labelIn(context.l10n)} · '
                  '${context.l10n.entriesCount(count: exercise.recordCount)}',
              trailing: LinkText(
                label: context.l10n.useThis,
                onTap: () => onUse(exercise),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(context.l10n.duplicateAdvice, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
