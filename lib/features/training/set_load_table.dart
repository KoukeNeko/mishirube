import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// An exercise's sets as a table of weight and reps typed in place, with
/// a set taken off or added at the end: how a 課表 plans them, and how a
/// finished workout is corrected.
class SetLoadTable extends StatelessWidget {
  const SetLoadTable({
    super.key,
    required this.loads,
    required this.onLoads,
    this.headerAction,
  });

  final List<SetLoad> loads;

  /// The sets as they are after a change.
  final ValueChanged<List<SetLoad>> onLoads;

  /// A control at the end of the header, such as 載入.
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    void change(int set, {double? weightKg, int? reps}) => onLoads([
      for (final (i, load) in loads.indexed)
        i == set
            ? (weightKg: weightKg ?? load.weightKg, reps: reps ?? load.reps)
            : load,
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 40,
              child: Text('組', style: AppTextStyles.caption),
            ),
            const Expanded(
              child: Text(
                'kg',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Expanded(
              child: Text(
                '次',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
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
                Expanded(
                  child: InlineNumberField(
                    text: formatWeight(load.weightKg),
                    label: '第 ${i + 1} 組重量',
                    decimal: true,
                    onCommit: (text) {
                      if (double.tryParse(text) case final kg? when kg >= 0) {
                        change(i, weightKg: kg);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: InlineNumberField(
                    text: '${load.reps}',
                    label: '第 ${i + 1} 組次數',
                    decimal: false,
                    onCommit: (text) {
                      if (int.tryParse(text) case final reps? when reps > 0) {
                        change(i, reps: reps);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: SecondaryButton(
                label: '刪除組',
                icon: Icons.remove,
                isCompact: true,
                onPressed: loads.length <= 1
                    ? null
                    : () => onLoads(loads.sublist(0, loads.length - 1)),
              ),
            ),
            Expanded(
              child: SecondaryButton(
                label: '新增組',
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
