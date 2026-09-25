import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';

const _weekdayHeight = 24.0;
const _titleHeight = 36.0;
const _rowHeight = 52.0;
const _dayCircle = 32.0;
const _dotSize = 5.0;

/// About half a phone screen of weeks at once, as Apple Calendar's month
/// view shows them above the day's list.
const _visibleWeeks = 5.5;
const _viewportHeight = _rowHeight * _visibleWeeks;

const _jumpDuration = Duration(milliseconds: 350);

/// The months from [earliest] to the current one as one column of weeks,
/// scrolled up and down as Apple Calendar's month view is: each month's
/// name over the column its first day falls in, its weeks under it, each
/// week starting on [firstWeekday] as the device is set to.
///
/// [month] is the month scrolled to; scrolling by hand reports the month
/// at the top through [onMonth] instead.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.earliest,
    required this.selected,
    required this.today,
    required this.firstWeekday,
    required this.categoriesOf,
    required this.onSelect,
    required this.onMonth,
  });

  /// First day of the month scrolled to.
  final DateTime month;

  /// First day of the earliest month there is to scroll back to.
  final DateTime earliest;

  final DateTime selected;
  final DateTime today;

  /// [DateTime.monday] … [DateTime.sunday].
  final int firstWeekday;

  /// The kinds of record on each day of a month.
  final Map<int, List<RecordCategory>> Function(DateTime month) categoriesOf;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonth;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

bool _isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// The days of [month]'s first week that belong to the month before.
int _leadingOf(DateTime month, int firstWeekday) =>
    (month.weekday - firstWeekday) % DateTime.daysPerWeek;

int _weeksIn(DateTime month, int firstWeekday) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  return ((_leadingOf(month, firstWeekday) + days) / DateTime.daysPerWeek)
      .ceil();
}

double _heightOf(DateTime month, int firstWeekday) =>
    _titleHeight + _weeksIn(month, firstWeekday) * _rowHeight;

/// `9月`, and with its year in January, as the system writes months.
String _monthTitle(DateTime month) =>
    month.month == 1 ? '${month.year}年1月' : '${month.month}月';

class _MonthCalendarState extends State<MonthCalendar> {
  late List<DateTime> _months;

  /// Where each month's block starts in the column.
  late List<double> _starts;

  /// The month at the top as last reported, or being jumped to.
  late DateTime _inView = widget.month;

  /// Set while the calendar scrolls to a month it was given, so the
  /// months passed on the way are not reported as scrolled to.
  bool _isJumping = false;

  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _layOut();
    _scroll = ScrollController(initialScrollOffset: _startOf(widget.month))
      ..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(MonthCalendar old) {
    super.didUpdateWidget(old);
    if (old.firstWeekday != widget.firstWeekday) {
      // Every month's height changes: stay on the month in view.
      _layOut();
      final month = _inView;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_startOf(month));
      });
    } else if (!_isSameMonth(old.earliest, widget.earliest) ||
        !_isSameMonth(old.today, widget.today)) {
      _layOut();
    }
    if (!_isSameMonth(widget.month, _inView)) _jumpTo(widget.month);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _layOut() {
    final last = DateTime(widget.today.year, widget.today.month);
    _months = [
      for (
        var month = DateTime(widget.earliest.year, widget.earliest.month);
        !month.isAfter(last);
        month = DateTime(month.year, month.month + 1)
      )
        month,
    ];
    _starts = [];
    var offset = 0.0;
    for (final month in _months) {
      _starts.add(offset);
      offset += _heightOf(month, widget.firstWeekday);
    }
  }

  double _startOf(DateTime month) {
    final index = _months.indexWhere((each) => _isSameMonth(each, month));
    return index < 0 ? _starts.last : _starts[index];
  }

  Future<void> _jumpTo(DateTime month) async {
    _inView = month;
    if (!_scroll.hasClients) return;
    final target = _startOf(month).clamp(0.0, _scroll.position.maxScrollExtent);
    if (prefersReducedMotion(context)) {
      _scroll.jumpTo(target);
      return;
    }
    _isJumping = true;
    await _scroll.animateTo(
      target,
      duration: _jumpDuration,
      curve: Curves.easeOutCubic,
    );
    _isJumping = false;
  }

  void _onScroll() {
    if (_isJumping) return;
    // The month whose block reaches the top of the view.
    final top = _scroll.offset + 1;
    var index = 0;
    while (index + 1 < _starts.length && _starts[index + 1] <= top) {
      index++;
    }
    final month = _months[index];
    if (_isSameMonth(month, _inView)) return;
    _inView = month;
    widget.onMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    // Room below the last month, so it too can be scrolled to the top.
    final tail =
        (_viewportHeight - _heightOf(_months.last, widget.firstWeekday)).clamp(
          0.0,
          _viewportHeight,
        );
    return Column(
      children: [
        SizedBox(
          height: _weekdayHeight,
          child: Row(
            children: [
              for (var i = 0; i < DateTime.daysPerWeek; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayName(
                        (widget.firstWeekday - 1 + i) % DateTime.daysPerWeek +
                            1,
                      ),
                      style: AppTextStyles.caption,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: _viewportHeight,
          // Inside the page, not at its edges: the page's insets are not
          // this list's padding.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            removeBottom: true,
            removeLeft: true,
            removeRight: true,
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.only(bottom: tail),
              itemCount: _months.length,
              itemExtentBuilder: (index, _) => index < _months.length
                  ? _heightOf(_months[index], widget.firstWeekday)
                  : null,
              itemBuilder: (context, index) => _MonthBlock(
                month: _months[index],
                firstWeekday: widget.firstWeekday,
                categories: widget.categoriesOf(_months[index]),
                selected: widget.selected,
                today: widget.today,
                onSelect: widget.onSelect,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One month of the column: its name over its first day's column, then
/// its weeks.
class _MonthBlock extends StatelessWidget {
  const _MonthBlock({
    required this.month,
    required this.firstWeekday,
    required this.categories,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final DateTime month;
  final int firstWeekday;
  final Map<int, List<RecordCategory>> categories;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final leading = _leadingOf(month, firstWeekday);
    final days = DateTime(month.year, month.month + 1, 0).day;
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = constraints.maxWidth / DateTime.daysPerWeek;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _titleHeight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: column * leading + AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    _monthTitle(month),
                    maxLines: 1,
                    style: AppTextStyles.itemTitle.copyWith(fontSize: 17),
                  ),
                ),
              ),
            ),
            for (var week = 0; week < _weeksIn(month, firstWeekday); week++)
              SizedBox(
                height: _rowHeight,
                child: Row(
                  children: [
                    for (var weekday = 0; weekday < 7; weekday++)
                      Expanded(
                        child: switch (week * 7 + weekday - leading + 1) {
                          final day when day >= 1 && day <= days => _DayCell(
                            date: DateTime(month.year, month.month, day),
                            categories: categories[day] ?? const [],
                            isSelected:
                                _isSameMonth(selected, month) &&
                                selected.day == day,
                            today: today,
                            onSelect: onSelect,
                          ),
                          _ => const SizedBox.shrink(),
                        },
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
  });

  final DateTime date;
  final List<RecordCategory> categories;
  final bool isSelected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameMonth(date, today) && date.day == today.day;
    final isFuture = date.isAfter(today);
    final color = isSelected
        ? AppColors.onTraining
        : isToday
        ? AppColors.training
        : isFuture
        ? AppColors.textTertiary
        : AppColors.textPrimary;
    return Semantics(
      button: !isFuture,
      selected: isSelected,
      label: '${date.month}月${date.day}日',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isFuture ? null : () => onSelect(date),
        child: DecoratedBox(
          // A line over each week, as the month's rows are ruled.
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.outline, width: 0.5),
            ),
          ),
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
      ),
    );
  }
}
