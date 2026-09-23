import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/app_store.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

const _maxDuplicateCandidates = 3;

/// Coarse body regions offered when creating an exercise; details come later.
enum _BodyRegion {
  chest('胸', MuscleGroup.chest),
  back('背', MuscleGroup.back),
  legs('腿', MuscleGroup.quads),
  shoulders('肩', MuscleGroup.shoulders),
  arms('手臂', MuscleGroup.arms),
  core('核心', MuscleGroup.core);

  const _BodyRegion(this.label, this.muscle);

  final String label;
  final MuscleGroup muscle;
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
        () => _error =
            '已有 ${refusal.sessionCount} 次紀錄用這個追蹤方式，改了會讓舊紀錄變成另一種意思。'
            '要換成別的追蹤方式，請建立一個新動作。',
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
        title: _editing == null ? '建立自訂動作' : '編輯動作',
        subtitle: _editing == null ? null : '${_editing!.source.label}動作',
      ),
      footer: PrimaryButton(
        label: _editing == null ? '建立並加入' : '儲存',
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
        Gutter(child: const SectionLabel('名稱')),
        Gutter(
          child: AppTextField(controller: _nameController, hint: '例如：啞鈴臥推'),
        ),
        Gutter(child: const SectionLabel('追蹤方式')),
        Gutter(
          child: ChipWrap(
            options: TrackingType.values,
            labelOf: (type) => type.label,
            isSelected: (type) => type == _trackingType,
            onTap: (type) => setState(() => _trackingType = type),
          ),
        ),
        Gutter(
          child: const Text('建立後不能改成不相容的追蹤方式。', style: AppTextStyles.caption),
        ),
        Gutter(child: const SectionLabel('主要肌群或動作模式')),
        Gutter(
          child: ChipWrap(
            options: _BodyRegion.values,
            labelOf: (region) => region.label,
            isSelected: (region) => region == _region,
            onTap: (region) => setState(() => _region = region),
          ),
        ),
        Gutter(child: const SectionLabel('器材')),
        Gutter(
          child: ChipWrap(
            options: _equipmentChoices,
            labelOf: (equipment) => equipment?.label ?? '不指定',
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
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.warning, size: 20),
              SizedBox(width: AppSpacing.xs),
              Text(
                '可能已經有這個動作',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final exercise in candidates) ...[
            NavCard(
              title: exercise.name,
              subtitle:
                  '${exercise.source.label} · ${exercise.recordCount} 筆紀錄',
              trailing: LinkText(label: '使用這個', onTap: () => onUse(exercise)),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const Text('選既有動作，歷史與個人紀錄才不會被拆成好幾份。', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
