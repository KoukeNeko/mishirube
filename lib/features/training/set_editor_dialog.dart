import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// What the set editor answers: the set as it now reads, or that it goes.
sealed class SetEdit {
  const SetEdit();
}

class SetChanged extends SetEdit {
  const SetChanged({
    required this.weightKg,
    required this.reps,
    required this.rir,
  });

  final double weightKg;
  final int reps;
  final int? rir;
}

class SetRemoved extends SetEdit {
  const SetRemoved();
}

/// The reserve a set can be marked with; beyond 4 the number stops
/// meaning much to the lifter.
const _rirChoices = [0, 1, 2, 3, 4];

/// Asks what one set was: weight and reps, each a step at a time or
/// typed, and the reps left in reserve.
Future<SetEdit?> showSetEditor(
  BuildContext context, {
  required String title,
  required WorkoutSet set,
}) => showAppDialog<SetEdit>(context, _SetEditor(title: title, set: set));

class _SetEditor extends StatefulWidget {
  const _SetEditor({required this.title, required this.set});

  final String title;
  final WorkoutSet set;

  @override
  State<_SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends State<_SetEditor> {
  late final _weight = TextEditingController(
    text: formatWeight(widget.set.weightKg),
  );
  late final _reps = TextEditingController(text: '${widget.set.reps}');
  late int? _rir = widget.set.rir;

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  double get _weightKg => double.tryParse(_weight.text) ?? 0;
  int get _repCount => int.tryParse(_reps.text) ?? 0;

  void _stepWeight(double by) {
    final next = roundToPlate((_weightKg + by).clamp(0, double.infinity));
    setState(() => _weight.text = formatWeight(next));
  }

  void _stepReps(int by) {
    final next = (_repCount + by).clamp(0, 999);
    setState(() => _reps.text = '$next');
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stepper(
            controller: _weight,
            unit: 'kg',
            allowsDecimal: true,
            decreaseLabel: '減少 ${formatWeight(plateStepKg)} kg',
            increaseLabel: '增加 ${formatWeight(plateStepKg)} kg',
            onDecrease: () => _stepWeight(-plateStepKg),
            onIncrease: () => _stepWeight(plateStepKg),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Stepper(
            controller: _reps,
            unit: '次',
            allowsDecimal: false,
            decreaseLabel: '少 1 次',
            increaseLabel: '多 1 次',
            onDecrease: () => _stepReps(-1),
            onIncrease: () => _stepReps(1),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('RIR', style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              SelectChip(
                label: '未記',
                isSelected: _rir == null,
                onTap: () => setState(() => _rir = null),
              ),
              for (final rir in _rirChoices)
                SelectChip(
                  label: '$rir',
                  isSelected: _rir == rir,
                  onTap: () => setState(() => _rir = rir),
                ),
            ],
          ),
        ],
      ),
      actions: [
        DialogAction(
          label: '儲存',
          tone: DialogTone.primary,
          onTap: () => Navigator.of(context)
              .pop(SetChanged(weightKg: _weightKg, reps: _repCount, rir: _rir)),
        ),
        DialogAction(
          label: '刪除這一組',
          tone: DialogTone.destructive,
          onTap: () => Navigator.of(context).pop(const SetRemoved()),
        ),
        DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// A number with a step down and a step up beside it; the number itself
/// can be typed over.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.controller,
    required this.unit,
    required this.allowsDecimal,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onDecrease,
    required this.onIncrease,
  });

  final TextEditingController controller;
  final String unit;
  final bool allowsDecimal;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SquareIconButton(
          icon: Icons.remove,
          tooltip: decreaseLabel,
          onPressed: onDecrease,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              IntrinsicWidth(
                child: TextField(
                  controller: controller,
                  onTapOutside: dismissKeyboardOnTapOutside,
                  textAlign: TextAlign.end,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: allowsDecimal,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(allowsDecimal ? r'[0-9.]' : r'[0-9]'),
                    ),
                  ],
                  style: AppTextStyles.bigNumber.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(unit, style: AppTextStyles.caption),
            ],
          ),
        ),
        SquareIconButton(
          icon: Icons.add,
          tooltip: increaseLabel,
          onPressed: onIncrease,
        ),
      ],
    );
  }
}
