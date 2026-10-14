import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/domain.dart';
import '../../../l10n/l10n.dart';
import '../../window_layout.dart';

const monthWeekdayHeight = 24.0;
const monthTitleHeight = 36.0;
const monthRowHeight = 52.0;
const _dayCircle = 32.0;
const _dotSize = 5.0;

/// The lines the weeks are ruled with.
const monthRule = 0.5;

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// The days of [month]'s first week that belong to the month before, for
/// weeks starting on [firstWeekday].
int monthLeading(DateTime month, int firstWeekday) =>
    (month.weekday - firstWeekday) % DateTime.daysPerWeek;

int monthWeeks(DateTime month, int firstWeekday) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  return ((monthLeading(month, firstWeekday) + days) / DateTime.daysPerWeek)
      .ceil();
}

/// How tall a [MonthBlock] of [month] is, with or without its name.
double monthBlockHeight(
  DateTime month,
  int firstWeekday, {
  bool showsTitle = true,
}) =>
    (showsTitle ? monthTitleHeight : 0) +
    monthWeeks(month, firstWeekday) * monthRowHeight;

/// `9月`, and with its year in January, as the system writes months.
String monthTitle(AppDates dates, DateTime month) => month.month == 1
    ? dates.compactYearMonth(month)
    : dates.compactMonth(month);

/// The days of the week over a month's columns, starting on
/// [firstWeekday]: pinned with the month's title, as Apple Calendar has
/// them, so they stay over the columns as the months scroll under. A
/// [trailingWidth] leaves the room a [MonthBlock] gives to what ends each
/// week.
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({
    super.key,
    required this.firstWeekday,
    this.trailingWidth = 0,
    this.sideInsets,
  });

  final int firstWeekday;
  final double trailingWidth;

  /// What the weekdays keep to on each side; the page's gutter without it.
  final EdgeInsets? sideInsets;

  /// The weekdays and the room above them, which is as far under the bar
  /// as the week strip of the timeline sits.
  static const height = monthWeekdayHeight + AppSpacing.xs;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    // The page column's, so the days stay put on switching to the
    // timeline's week strip.
    padding: (sideInsets ?? PageColumn.gutterOf(context)).copyWith(
      top: AppSpacing.xs,
    ),
    child: Row(
      children: [
        for (var i = 0; i < DateTime.daysPerWeek; i++)
          Expanded(
            // At the top, as the week strip has its weekdays.
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                context.dates.weekdayNumber(
                  (firstWeekday - 1 + i) % DateTime.daysPerWeek + 1,
                ),
                style: AppTextStyles.caption,
              ),
            ),
          ),
        SizedBox(width: trailingWidth),
      ],
    ),
  );
}

/// One month as a column of weeks ruled across, each day a number with a
/// dot for each kind of record it has: the month's name over the column
/// its first day falls in, then its weeks. Days after [today] cannot be
/// picked, and with no [onSelect] none can.
class MonthBlock extends StatelessWidget {
  const MonthBlock({
    super.key,
    required this.month,
    required this.firstWeekday,
    required this.categories,
    required this.today,
    this.selected,
    this.onSelect,
    this.showsTitle = true,
    this.trailingWidth = 0,
    this.weekTrailing,
    this.semanticLabelOf,
    this.sideInsets,
  });

  /// First day of the month.
  final DateTime month;

  /// [DateTime.monday] … [DateTime.sunday].
  final int firstWeekday;

  /// The kinds of record on each day of the month.
  final Map<int, List<RecordCategory>> categories;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;

  /// Whether the month's name stands over its first day. A page that
  /// already says the month leaves it out.
  final bool showsTitle;

  /// A column at the end of each week of this width, with what
  /// [weekTrailing] draws in it for the week starting on the given day
  /// (which may fall in the month before).
  final double trailingWidth;
  final Widget Function(BuildContext context, DateTime weekStart)? weekTrailing;

  /// What a screen reader says for a day, where more than its date is
  /// worth saying.
  final String Function(
    BuildContext context,
    DateTime date,
    List<RecordCategory> categories,
  )?
  semanticLabelOf;

  /// What the days keep to on each side; the page's gutter without it,
  /// for a block that runs the width of the page.
  final EdgeInsets? sideInsets;

  @override
  Widget build(BuildContext context) {
    final leading = monthLeading(month, firstWeekday);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final weeks = monthWeeks(month, firstWeekday);
    final lastWeekday = (leading + days - 1) % DateTime.daysPerWeek;
    final gutter = sideInsets ?? PageColumn.gutterOf(context);
    final picked = selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final column =
            (constraints.maxWidth - gutter.horizontal - trailingWidth) /
            DateTime.daysPerWeek;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showsTitle)
              SizedBox(
                height: monthTitleHeight,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: gutter.left + column * leading + AppSpacing.xs,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      monthTitle(context.dates, month),
                      maxLines: 1,
                      style: AppTextStyles.itemTitle.copyWith(fontSize: 17),
                    ),
                  ),
                ),
              ),
            for (var week = 0; week < weeks; week++)
              SizedBox(
                height: monthRowHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // A line over each week's days, as the month's rows
                    // are ruled; out to the screen's edge where a week
                    // reaches the first or last column, and across what
                    // ends it.
                    Positioned(
                      top: 0,
                      height: monthRule,
                      left: switch (week == 0 ? leading : 0) {
                        0 => 0,
                        final first => gutter.left + column * first,
                      },
                      right: switch (week == weeks - 1 && weekTrailing == null
                          ? lastWeekday
                          : 6) {
                        6 => 0,
                        final last => gutter.right + column * (6 - last),
                      },
                      child: const ColoredBox(color: AppColors.outline),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        left: gutter.left,
                        right: gutter.right,
                      ),
                      child: Row(
                        children: [
                          for (var weekday = 0; weekday < 7; weekday++)
                            Expanded(
                              child: switch (week * 7 + weekday - leading + 1) {
                                final day when day >= 1 && day <= days =>
                                  _DayCell(
                                    date: DateTime(
                                      month.year,
                                      month.month,
                                      day,
                                    ),
                                    categories: categories[day] ?? const [],
                                    isSelected:
                                        picked != null &&
                                        isSameMonth(picked, month) &&
                                        picked.day == day,
                                    today: today,
                                    onSelect: onSelect,
                                    semanticLabelOf: semanticLabelOf,
                                  ),
                                _ => const SizedBox.shrink(),
                              },
                            ),
                          if (weekTrailing case final trailing?)
                            SizedBox(
                              width: trailingWidth,
                              child: trailing(
                                context,
                                DateTime(
                                  month.year,
                                  month.month,
                                  1 - leading + week * DateTime.daysPerWeek,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.categories,
    required this.isSelected,
    required this.today,
    required this.onSelect,
    required this.semanticLabelOf,
  });

  final DateTime date;
  final List<RecordCategory> categories;
  final bool isSelected;
  final DateTime today;
  final ValueChanged<DateTime>? onSelect;
  final String Function(BuildContext, DateTime, List<RecordCategory>)?
  semanticLabelOf;

  @override
  Widget build(BuildContext context) {
    final isToday = isSameMonth(date, today) && date.day == today.day;
    final isFuture = date.isAfter(today);
    final onSelect = this.onSelect;
    final color = isSelected
        ? AppColors.onTraining
        : isToday
        ? AppColors.training
        : isFuture
        ? AppColors.textTertiary
        : AppColors.textPrimary;
    return Semantics(
      button: onSelect != null && !isFuture,
      selected: isSelected,
      label:
          semanticLabelOf?.call(context, date, categories) ??
          context.dates.compactMonthDay(date),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect == null || isFuture ? null : () => onSelect(date),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxs),
            Container(
              width: _dayCircle,
              height: _dayCircle,
              alignment: Alignment.center,
              decoration: isSelected
                  ? const BoxDecoration(
                      color: AppColors.training,
                      shape: BoxShape.circle,
                    )
                  : null,
              // Shrinks rather than overflows at large text sizes.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: color,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            SizedBox(
              height: _dotSize,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final category in categories)
                    Container(
                      width: _dotSize,
                      height: _dotSize,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
