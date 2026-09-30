import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// What the set editor answers: the set as it now reads, or that it goes.
sealed class SetEdit {
  const SetEdit();
}

class SetChanged extends SetEdit {
  const SetChanged({
    required this.weightKg,
    required this.reps,
    required this.rir,
    this.seconds,
    this.meters,
  });

  final double weightKg;
  final int reps;
  final int? rir;

  /// The time and the distance, for the exercises that record them.
  final int? seconds;
  final double? meters;
}

class SetRemoved extends SetEdit {
  const SetRemoved();
}

/// The reserve a set can be marked with; beyond 4 the number stops
/// meaning much to the lifter.
const _rirChoices = [0, 1, 2, 3, 4];

/// How far a distance is stepped, in kilometres, and a time, in seconds.
const _kilometerStep = 0.1;
const _secondStep = 5;

/// Asks what one set was: the figures its exercise [trackingType] records
/// — weight and reps, each a step at a time or typed, a time, a distance —
/// and, for reps, the reps left in reserve.
Future<SetEdit?> showSetEditor(
  BuildContext context, {
  required String title,
  required WorkoutSet set,
  required TrackingType trackingType,
  required Equipment equipment,
  ExerciseHistoryEntry? reference,
}) => showAppDialog<SetEdit>(
  context,
  _SetEditor(
    title: title,
    set: set,
    trackingType: trackingType,
    equipment: equipment,
    reference: reference,
  ),
);

class _SetEditor extends StatefulWidget {
  const _SetEditor({
    required this.title,
    required this.set,
    required this.trackingType,
    required this.equipment,
    required this.reference,
  });

  final String title;
  final WorkoutSet set;
  final TrackingType trackingType;
  final ExerciseHistoryEntry? reference;

  /// A barbell's weight is also read as the plates to load.
  final Equipment equipment;

  @override
  State<_SetEditor> createState() => _SetEditorState();
}

class _SetEditorState extends State<_SetEditor> {
  late final _weight = TextEditingController(
    text: formatWeight(widget.set.weightKg),
  );
  late final _reps = TextEditingController(text: '${widget.set.reps}');
  late final _distance = TextEditingController(
    text: formatKilometers(widget.set.distanceMeters ?? 0),
  );
  late int _seconds = widget.set.durationSeconds ?? 0;
  late int? _rir = widget.set.rir;

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _distance.dispose();
    super.dispose();
  }

  double get _weightKg => double.tryParse(_weight.text) ?? 0;
  int get _repCount => int.tryParse(_reps.text) ?? 0;
  double get _kilometers => double.tryParse(_distance.text) ?? 0;

  void _stepDistance(double by) {
    final next = ((_kilometers + by) * 100).round() / 100;
    setState(
      () => _distance.text = formatKilometers(next.clamp(0, 9999) * 1000),
    );
  }

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
    final type = widget.trackingType;
    final percent = relativeLoadPercent(_weightKg, widget.reference);
    final l10n = context.l10n;
    // Each figure the exercise records, one under the other.
    final steppers = <Widget>[
      if (type.usesWeight)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stepper(
              controller: _weight,
              unit: 'kg',
              allowsDecimal: true,
              decreaseLabel: l10n.decreaseBy(
                amount: '${formatWeight(plateStepKg)} kg',
              ),
              increaseLabel: l10n.increaseBy(
                amount: '${formatWeight(plateStepKg)} kg',
              ),
              onDecrease: () => _stepWeight(-plateStepKg),
              onIncrease: () => _stepWeight(plateStepKg),
              onChanged: () => setState(() {}),
            ),
            if (type == TrackingType.weightReps &&
                widget.equipment == Equipment.barbell)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text(
                  _platesLabel(l10n, _weightKg),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
          ],
        ),
      if (type.usesReps)
        _Stepper(
          controller: _reps,
          unit: l10n.repsColumn,
          allowsDecimal: false,
          decreaseLabel: l10n.oneRepLess,
          increaseLabel: l10n.oneRepMore,
          onDecrease: () => _stepReps(-1),
          onIncrease: () => _stepReps(1),
          onChanged: () => setState(() {}),
        ),
      if (type.usesTime)
        ValueStepper(
          decreaseLabel: l10n.decreaseBy(
            amount: l10n.durationSeconds(seconds: _secondStep),
          ),
          increaseLabel: l10n.increaseBy(
            amount: l10n.durationSeconds(seconds: _secondStep),
          ),
          onDecrease: _seconds > 0
              ? () => setState(
                  () => _seconds = math.max(0, _seconds - _secondStep),
                )
              : null,
          onIncrease: () => setState(() => _seconds += _secondStep),
          child: StepperReading(
            value: formatClock(Duration(seconds: _seconds)),
          ),
        ),
      if (type.usesDistance)
        _Stepper(
          controller: _distance,
          unit: 'km',
          allowsDecimal: true,
          decreaseLabel: l10n.decreaseBy(amount: '$_kilometerStep km'),
          increaseLabel: l10n.increaseBy(amount: '$_kilometerStep km'),
          onDecrease: () => _stepDistance(-_kilometerStep),
          onIncrease: () => _stepDistance(_kilometerStep),
          onChanged: () => setState(() {}),
        ),
    ];
    return AppDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, stepper) in steppers.indexed) ...[
            if (i > 0 && stepper is! Padding)
              const SizedBox(height: AppSpacing.sm),
            stepper,
          ],
          if (percent case final percent?) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.relativeLoadPercent(percent: percent.round()),
              style: AppTextStyles.body,
            ),
            Text(
              '${l10n.estimatedMax} ${formatWeight(widget.reference!.oneRepMaxKg!)} kg · '
              '${context.dates.monthDay(widget.reference!.date)} · ${l10n.epleyEstimate}',
              style: AppTextStyles.caption,
            ),
          ],
          if (type.usesReps) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('RIR', style: AppTextStyles.overline),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                SelectChip(
                  label: l10n.notLogged,
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
        ],
      ),
      actions: [
        DialogAction(
          label: context.l10n.commonSave,
          tone: DialogTone.primary,
          onTap: () => Navigator.of(context).pop(
            SetChanged(
              weightKg: type.usesWeight ? _weightKg : 0,
              reps: type.usesReps ? _repCount : 0,
              rir: type.usesReps ? _rir : null,
              seconds: type.usesTime ? _seconds : null,
              meters: type.usesDistance ? _kilometers * 1000 : null,
            ),
          ),
        ),
        DialogAction(
          label: context.l10n.deleteThisSet,
          tone: DialogTone.destructive,
          onTap: () => Navigator.of(context).pop(const SetRemoved()),
        ),
        DialogAction(
          label: context.l10n.commonCancel,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// What to load on each side of a 20 kg bar.
String _platesLabel(AppLocalizations l10n, double totalKg) =>
    switch (platesPerSide(totalKg)) {
      null => l10n.platesImpossible,
      [] => l10n.emptyBar,
      final plates => l10n.platesPerSide(
        plates: plates.map(formatWeight).join(' + '),
      ),
    };

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
    required this.onChanged,
  });

  final TextEditingController controller;
  final String unit;
  final bool allowsDecimal;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueStepper(
      decreaseLabel: decreaseLabel,
      increaseLabel: increaseLabel,
      onDecrease: onDecrease,
      onIncrease: onIncrease,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          IntrinsicWidth(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
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
    );
  }
}
