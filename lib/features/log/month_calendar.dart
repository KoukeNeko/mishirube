import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';

const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
const _daysInSeptember = 30;

/// Weekday offset of 2026-09-01 (a Tuesday) in a Monday-first grid.
const _firstDayOffset = 1;
const _cellSpacing = 6.0;
const _dotSize = 5.0;

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.selectedDay,
    required this.today,
    required this.dotsByDay,
    required this.onSelect,
  });

  final int selectedDay;
  final int today;
  final Map<int, List<RecordCategory>> dotsByDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(child: Text(label, style: AppTextStyles.caption)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.count(
          crossAxisCount: _weekdayLabels.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: _cellSpacing,
          crossAxisSpacing: _cellSpacing,
          children: [
            for (var i = 0; i < _firstDayOffset; i++) const SizedBox.shrink(),
            for (var day = 1; day <= _daysInSeptember; day++)
              _DayCell(
                day: day,
                isSelected: day == selectedDay,
                isFuture: day > today,
                dots: dotsByDay[day] ?? const [],
                onTap: day > today ? null : () => onSelect(day),
              ),
          ],
        ),
      ],
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
        child: Column(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final category in dots)
                  Container(
                    width: _dotSize,
                    height: _dotSize,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.onTraining : category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
