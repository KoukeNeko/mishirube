import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/app_store.dart';
import '../../data/models.dart';
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
  const CreateExerciseScreen({super.key, this.initialName = ''});

  final String initialName;

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  late final _nameController = TextEditingController(text: widget.initialName);
  TrackingType _trackingType = TrackingType.weightReps;
  _BodyRegion _region = _BodyRegion.chest;
  Equipment? _equipment = Equipment.dumbbell;

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

  List<ExerciseDefinition> _possibleDuplicates() {
    if (_name.isEmpty) return const [];
    return AppStoreScope.of(context).exercises
        .where((exercise) => exercise.matchesQuery(_name))
        .take(_maxDuplicateCandidates)
        .toList();
  }

  void _create() {
    final exercise = ExerciseDefinition(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: _name,
      equipment: _equipment ?? Equipment.bodyweight,
      primaryMuscles: [_region.muscle],
      pattern: MovementPattern.isolation,
      trackingType: _trackingType,
      source: ExerciseSource.custom,
    );
    Navigator.of(context).pop(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final duplicates = _possibleDuplicates();
    return DetailPage(
      appBar: PageAppBar(
        title: '建立自訂動作',
        subtitle: '只需要四個欄位',
        leading: AppBarLeading.none,
        onClose: () => Navigator.of(context).pop(),
      ),
      footer: PrimaryButton(
        label: '建立並加入',
        onPressed: _name.isEmpty ? null : _create,
      ),
      children: [
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
          child: const Text(
            '追蹤方式決定歷史怎麼被解讀。之後要改成不相容的方式，必須建立新動作。',
            style: AppTextStyles.caption,
          ),
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
        Gutter(
          child: const Text(
            '別名、說明、媒體與次要肌群之後都能補。',
            style: AppTextStyles.caption,
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
            AppCard(
              tone: CardTone.neutral,
              radius: AppRadius.small,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: AppTextStyles.itemTitle),
                        Text(
                          '${exercise.source.label} · ${exercise.recordCount} 筆紀錄',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  LinkText(label: '使用這個', onTap: () => onUse(exercise)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          const Text('選既有動作，歷史與個人紀錄才不會被拆成好幾份。', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
