import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/set_schemes.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// The most sets and reps a scheme is asked for.
const _maxSets = 20;
const _maxReps = 99;

/// The step of a time and of a distance, in seconds and kilometres.
const _secondStep = 5;
const _kilometerStep = 0.1;
const _maxSeconds = 3600;
const _maxKilometers = 999.0;

/// Asks how the working sets of [exercise] should be spread: a scheme,
/// the weight it is built from, and how many sets and reps. An exercise
/// recorded by anything but weight and reps has only the straight scheme,
/// and its own figures in place of weight and reps. Resolves to the sets
/// the scheme makes, or null when dismissed.
Future<List<SetLoad>?> showSetSchemeSheet(
  BuildContext context, {
  required ExerciseSession exercise,
  required ExerciseHistory history,
  required DateTime now,
}) => showAppSheet<List<SetLoad>>(
  context,
  (_) => _SetSchemeSheet(exercise: exercise, history: history, now: now),
);

extension on SetScheme {
  String labelIn(AppLocalizations l10n) => switch (this) {
    SetScheme.straight => l10n.schemeStraight,
    SetScheme.ascending => l10n.schemeAscending,
    SetScheme.reverse => l10n.schemeReverse,
    SetScheme.fiveByFive => l10n.schemeFiveByFive,
    SetScheme.topSet => l10n.schemeTopSet,
    SetScheme.drop => l10n.schemeDrop,
  };

  String hintIn(AppLocalizations l10n) => switch (this) {
    SetScheme.straight => l10n.schemeStraightHint,
    SetScheme.ascending => l10n.schemeAscendingHint,
    SetScheme.reverse => l10n.schemeReverseHint,
    SetScheme.fiveByFive => l10n.schemeFiveByFiveHint,
    SetScheme.topSet => l10n.schemeTopSetHint,
    SetScheme.drop => l10n.schemeDropHint,
  };
}

class _SetSchemeSheet extends StatefulWidget {
  const _SetSchemeSheet({
    required this.exercise,
    required this.history,
    required this.now,
  });

  final ExerciseSession exercise;
  final ExerciseHistory history;
  final DateTime now;

  @override
  State<_SetSchemeSheet> createState() => _SetSchemeSheetState();
}

class _SetSchemeSheetState extends State<_SetSchemeSheet> {
  SetScheme _scheme = SetScheme.straight;
  late final _type = widget.exercise.exercise.trackingType;
  late final _source = _type.usesWeight
      ? mainWeightFrom(widget.history, widget.now)
      : null;

  late final List<WorkoutSet> _working = [
    for (final set in widget.exercise.sets)
      if (set.type == SetType.working) set,
  ];

  /// Where the scheme starts from: what was lifted lately, else at all,
  /// else what the exercise's first set is at now.
  late double _mainKg = _source?.kg ?? _working.firstOrNull?.weightKg ?? 0;
  late int _sets = _working.isEmpty ? 3 : _working.length.clamp(1, _maxSets);
  late int _reps = _working.firstOrNull?.reps.clamp(1, _maxReps) ?? 10;
  late int _seconds =
      _working.firstOrNull?.durationSeconds ??
      (_type == TrackingType.distance ? 0 : 30);
  late double _kilometers =
      (_working.firstOrNull?.distanceMeters ?? 1000) / 1000;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFixed = _scheme == SetScheme.fiveByFive;
    final loads = schemeSets(
      _scheme,
      mainKg: _mainKg,
      sets: _sets,
      reps: _type.usesReps ? _reps : 0,
      seconds: _type.usesTime && _seconds > 0 ? _seconds : null,
      meters: _type.usesDistance ? _kilometers * 1000 : null,
    );
    // Sets already done are not rewritten: they count toward the scheme,
    // and only the ones after them are listed.
    final done = _working.where((set) => set.isDone).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Gutter(
                  child: Text(
                    widget.exercise.exercise.name,
                    style: AppTextStyles.pageTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_type == TrackingType.weightReps) ...[
                  FilterChipBar<SetScheme>(
                    options: SetScheme.values,
                    selected: _scheme,
                    labelOf: (scheme) => scheme.labelIn(l10n),
                    onSelected: (scheme) => setState(() => _scheme = scheme),
                  ),
                  Gutter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        _scheme.hintIn(l10n),
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_type.usesWeight)
                  Gutter(
                    child: _StepperField(
                      label: l10n.mainWeight,
                      tag: switch (_source) {
                        (isRecent: true, kg: _) => l10n.mainWeightRecent,
                        (isRecent: false, kg: _) => l10n.mainWeightEver,
                        null => null,
                      },
                      value: formatWeight(_mainKg),
                      unit: 'kg',
                      decreaseLabel: l10n.decreaseBy(
                        amount: '${formatWeight(plateStepKg)} kg',
                      ),
                      increaseLabel: l10n.increaseBy(
                        amount: '${formatWeight(plateStepKg)} kg',
                      ),
                      onDecrease: _mainKg > 0
                          ? () => setState(
                              () =>
                                  _mainKg = math.max(0, _mainKg - plateStepKg),
                            )
                          : null,
                      onIncrease: () => setState(() => _mainKg += plateStepKg),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Gutter(
                  child: _StepperField(
                    label: l10n.setCountLabel,
                    value: '${isFixed ? fiveByFiveSets : _sets}',
                    decreaseLabel: l10n.oneSetLess,
                    increaseLabel: l10n.oneSetMore,
                    onDecrease: isFixed || _sets <= 1
                        ? null
                        : () => setState(() => _sets--),
                    onIncrease: isFixed || _sets >= _maxSets
                        ? null
                        : () => setState(() => _sets++),
                  ),
                ),
                if (_type.usesReps) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Gutter(
                    child: _StepperField(
                      label: l10n.repCountLabel,
                      value: '${isFixed ? fiveByFiveReps : _reps}',
                      decreaseLabel: l10n.oneRepLess,
                      increaseLabel: l10n.oneRepMore,
                      onDecrease: isFixed || _reps <= 1
                          ? null
                          : () => setState(() => _reps--),
                      onIncrease: isFixed || _reps >= _maxReps
                          ? null
                          : () => setState(() => _reps++),
                    ),
                  ),
                ],
                if (_type.usesTime) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Gutter(
                    child: _StepperField(
                      label: l10n.timeColumn,
                      value: formatClock(Duration(seconds: _seconds)),
                      decreaseLabel: l10n.decreaseBy(
                        amount: l10n.durationSeconds(seconds: _secondStep),
                      ),
                      increaseLabel: l10n.increaseBy(
                        amount: l10n.durationSeconds(seconds: _secondStep),
                      ),
                      // A distance's time is optional: 0 is none.
                      onDecrease: _seconds > 0
                          ? () => setState(
                              () => _seconds = math.max(
                                0,
                                _seconds - _secondStep,
                              ),
                            )
                          : null,
                      onIncrease: _seconds < _maxSeconds
                          ? () => setState(() => _seconds += _secondStep)
                          : null,
                    ),
                  ),
                ],
                if (_type.usesDistance) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Gutter(
                    child: _StepperField(
                      label: l10n.trackingTypeDistance,
                      value: formatKilometers(_kilometers * 1000),
                      unit: 'km',
                      decreaseLabel: l10n.decreaseBy(
                        amount: '$_kilometerStep km',
                      ),
                      increaseLabel: l10n.increaseBy(
                        amount: '$_kilometerStep km',
                      ),
                      onDecrease: _kilometers > _kilometerStep
                          ? () => setState(
                              () => _kilometers =
                                  ((_kilometers - _kilometerStep) * 100)
                                      .round() /
                                  100,
                            )
                          : null,
                      onIncrease: _kilometers < _maxKilometers
                          ? () => setState(
                              () => _kilometers =
                                  ((_kilometers + _kilometerStep) * 100)
                                      .round() /
                                  100,
                            )
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Gutter(
                  child: GroupedCard(
                    children: [
                      for (final (i, load) in loads.indexed.skip(done))
                        KeyValueRow(
                          label: l10n.setOrdinal(number: i + 1),
                          value: load.figuresIn(l10n, _type),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Gutter(
          child: Padding(
            padding: EdgeInsets.only(
              top: AppSpacing.md,
              bottom:
                  AppSpacing.screenGutter +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: PrimaryButton(
              label: l10n.applyAction,
              onPressed: () => Navigator.of(context).pop(loads),
            ),
          ),
        ),
      ],
    );
  }
}

/// A figure to step up and down, under what it is and, quieter, where
/// it comes from.
class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.decreaseLabel,
    required this.increaseLabel,
    required this.onDecrease,
    required this.onIncrease,
    this.unit,
    this.tag,
  });

  final String label;
  final String? tag;
  final String value;
  final String? unit;
  final String decreaseLabel;
  final String increaseLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: AppTextStyles.caption),
            if (tag case final tag?) ...[
              const Spacer(),
              Text(tag, style: AppTextStyles.caption),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ValueStepper(
          decreaseLabel: decreaseLabel,
          increaseLabel: increaseLabel,
          onDecrease: onDecrease,
          onIncrease: onIncrease,
          child: StepperReading(value: value, unit: unit),
        ),
      ],
    );
  }
}
