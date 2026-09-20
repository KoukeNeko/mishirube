import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

const _cellMinHeight = 44.0;
const _dotSize = 5.0;

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.dotsByDay,
    required this.onSelect,
  });

  /// First day of the month shown.
  final DateTime month;
  final int selectedDay;
  final DateTime today;
  final Map<int, List<RecordCategory>> dotsByDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    bool isFuture(int day) =>
        DateTime(month.year, month.month, day).isAfter(today);
    return MonthGrid(
      month: month,
      dayBuilder: (context, day) => _DayCell(
        day: day,
        isSelected: day == selectedDay,
        isFuture: isFuture(day),
        dots: dotsByDay[day] ?? const [],
        onTap: isFuture(day) ? null : () => onSelect(day),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isFuture,
    required this.dots,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isFuture;
  final List<RecordCategory> dots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? AppColors.onTraining
        : isFuture
        ? AppColors.textTertiary
        : AppColors.textPrimary;
    return Material(
      color: isSelected
          ? AppColors.training
          : isFuture
          ? Colors.transparent
          : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.small),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _cellMinHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              // Always as tall as a dot, so dates line up across cells.
              SizedBox(
                height: _dotSize,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final category in dots)
                      Container(
                        width: _dotSize,
                        height: _dotSize,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.onTraining
                              : category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
