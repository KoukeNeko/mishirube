import 'package:flutter/material.dart';

import '../../../app/theme.dart';

const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

/// Gap between cells, which is also the gap between weeks.
const monthGridSpacing = 4.0;

/// A month laid out Monday first: the weekday header and the rows of
/// cells. What a day looks like is the caller's business, so the same
/// grid carries record dots on one screen and training days on another.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.dayBuilder,
    this.weekTrailingBuilder,
    this.trailingWidth = 56,
  });

  /// Any day in the month shown; only the year and month are read.
  final DateTime month;

  final Widget Function(BuildContext context, int day) dayBuilder;

  /// An optional column at the end of each row, given the row's first
  /// day (which may fall in the previous month for the first week).
  final Widget Function(BuildContext context, DateTime weekStart)?
  weekTrailingBuilder;

  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks =
        DateTime(month.year, month.month).weekday - DateTime.monday;
    final cells = <int?>[
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++) day,
    ];
    final weeks = (cells.length / DateTime.daysPerWeek).ceil();
    final hasTrailing = weekTrailingBuilder != null;
    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(child: Text(label, style: AppTextStyles.caption)),
              ),
            if (hasTrailing) SizedBox(width: trailingWidth),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Plain rows, not a GridView: a nested scroll view would pick up
        // the page's edge-to-edge insets as padding.
        for (var week = 0; week < weeks; week++) ...[
          if (week > 0) const SizedBox(height: monthGridSpacing),
          Row(
            children: [
              for (var i = week * 7; i < week * 7 + 7; i++) ...[
                if (i > week * 7) const SizedBox(width: monthGridSpacing),
                Expanded(
                  child: switch (i < cells.length ? cells[i] : null) {
                    final day? => dayBuilder(context, day),
                    null => const SizedBox.shrink(),
                  },
                ),
              ],
              if (hasTrailing)
                SizedBox(
                  width: trailingWidth,
                  child: weekTrailingBuilder!(
                    context,
                    DateTime(
                      month.year,
                      month.month,
                      1 - leadingBlanks + week * DateTime.daysPerWeek,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
