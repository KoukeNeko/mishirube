import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// An exercise's sets as a table of the figures it is recorded by (weight
/// and reps, a time, a distance), typed in place, with a set taken off or
/// added at the end: how a 課表 plans them, and how a finished workout is
/// corrected.
class SetLoadTable extends StatelessWidget {
  const SetLoadTable({
    super.key,
    required this.trackingType,
    required this.loads,
    required this.onLoads,
    this.headerAction,
  });

  final TrackingType trackingType;
  final List<SetLoad> loads;

  /// The sets as they are after a change.
  final ValueChanged<List<SetLoad>> onLoads;

  /// A control at the end of the header, such as 載入.
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = trackingType;
    void change(int set, SetLoad Function(SetLoad load) edit) => onLoads([
      for (final (i, load) in loads.indexed) i == set ? edit(load) : load,
    ]);
    // The figures the exercise records, left to right, as columns.
    final columns =
        <({String heading, Widget Function(int i, SetLoad load) cell})>[
          if (type.usesWeight)
            (
              heading: 'kg',
              cell: (i, load) => InlineNumberField(
                text: formatWeight(load.weightKg),
                label: l10n.setNumberWeight(number: i + 1),
                decimal: true,
                onCommit: (text) {
                  if (double.tryParse(text) case final kg? when kg >= 0) {
                    change(i, (load) => load.copyWith(weightKg: kg));
                  }
                },
              ),
            ),
          if (type.usesReps)
            (
              heading: l10n.repsColumn,
              cell: (i, load) => InlineNumberField(
                text: '${load.reps}',
                label: l10n.setNumberReps(number: i + 1),
                decimal: false,
                onCommit: (text) {
                  if (int.tryParse(text) case final reps? when reps > 0) {
                    change(i, (load) => load.copyWith(reps: reps));
                  }
                },
              ),
            ),
          if (type.usesDistance)
            (
              heading: 'km',
              cell: (i, load) => InlineNumberField(
                text: formatKilometers(load.meters ?? 0),
                label: l10n.setNumberDistance(number: i + 1),
                decimal: true,
                onCommit: (text) {
                  if (double.tryParse(text) case final km? when km > 0) {
                    change(i, (load) => load.copyWith(meters: km * 1000));
                  }
                },
              ),
            ),
          if (type.usesTime)
            (
              heading: l10n.timeColumn,
              cell: (i, load) => DurationField(
                seconds: load.seconds ?? 0,
                label: l10n.setNumberTime(number: i + 1),
                onChanged: (seconds) =>
                    change(i, (load) => load.copyWith(seconds: seconds)),
              ),
            ),
        ];
    // One figure takes the width of two.
    final flex = columns.length == 1 ? 2 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(l10n.setColumn, style: AppTextStyles.caption),
            ),
            for (final (i, column) in columns.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: flex,
                child: Text(
                  column.heading,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
            if (headerAction case final action?) ...[
              const SizedBox(width: AppSpacing.xs),
              action,
            ],
          ],
        ),
        for (final (i, load) in loads.indexed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('${i + 1}', style: AppTextStyles.itemTitle),
                ),
                for (final (c, column) in columns.indexed) ...[
                  if (c > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(flex: flex, child: column.cell(i, load)),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: SecondaryButton(
                label: l10n.removeSet,
                icon: Icons.remove,
                isCompact: true,
                onPressed: loads.length <= 1
                    ? null
                    : () => onLoads(loads.sublist(0, loads.length - 1)),
              ),
            ),
            Expanded(
              child: SecondaryButton(
                label: l10n.addSet,
                icon: Icons.add,
                isCompact: true,
                onPressed: () => onLoads([...loads, loads.last]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// An exercise to plan or correct: its name, a way to take it out, and
/// its sets as a [SetLoadTable].
class ExerciseLoadsCard extends StatelessWidget {
  const ExerciseLoadsCard({
    super.key,
    required this.name,
    required this.trackingType,
    required this.loads,
    required this.onLoads,
    required this.onRemove,
  });

  final String name;
  final TrackingType trackingType;
  final List<SetLoad> loads;
  final ValueChanged<List<SetLoad>> onLoads;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: AppTextStyles.itemTitle)),
              ChipButton(
                label: context.l10n.removeAction,
                semanticLabel: context.l10n.removeNamed(name: name),
                onTap: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SetLoadTable(
            trackingType: trackingType,
            loads: loads,
            onLoads: onLoads,
          ),
        ],
      ),
    );
  }
}
