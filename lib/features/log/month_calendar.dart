import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';

/// About half a phone screen of weeks at once, as Apple Calendar's month
/// view shows them above the day's list.
const _visibleWeeks = 5.5;
const _viewportHeight = monthRowHeight * _visibleWeeks;

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
    this.topInset = 0,
  });

  /// Room above the first week at rest, which the months scroll up
  /// into: a bar the calendar runs behind.
  final double topInset;

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

  /// How tall the calendar is below [topInset], whatever the month.
  static const height = _viewportHeight + monthRule;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

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
    } else if (!isSameMonth(old.earliest, widget.earliest) ||
        !isSameMonth(old.today, widget.today)) {
      _layOut();
    }
    if (!isSameMonth(widget.month, _inView)) _jumpTo(widget.month);
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
      offset += monthBlockHeight(month, widget.firstWeekday);
    }
  }

  /// Where the calendar stops for [month]: just past its name, which the
  /// pinned title already shows, so its first week is at the top. The
  /// name shows between months while scrolling.
  double _startOf(DateTime month) {
    final index = _months.indexWhere((each) => isSameMonth(each, month));
    return (index < 0 ? _starts.last : _starts[index]) + monthTitleHeight;
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
    if (isSameMonth(month, _inView)) return;
    _inView = month;
    widget.onMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    // Room below the last month, so it too can be scrolled to the top.
    final tail =
        (_viewportHeight -
                monthBlockHeight(_months.last, widget.firstWeekday) +
                monthTitleHeight)
            .clamp(0.0, _viewportHeight);
    // The inset pads the list's start, so the offsets the months are
    // reached at stay the same with it.
    return Column(
      children: [
        SizedBox(
          height: widget.topInset + _viewportHeight,
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
              padding: EdgeInsets.only(top: widget.topInset, bottom: tail),
              itemCount: _months.length,
              itemExtentBuilder: (index, _) => index < _months.length
                  ? monthBlockHeight(_months[index], widget.firstWeekday)
                  : null,
              itemBuilder: (context, index) => MonthBlock(
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
        // Closes the last week shown, as each week is ruled above.
        const SizedBox(
          height: monthRule,
          width: double.infinity,
          child: ColoredBox(color: AppColors.outline),
        ),
      ],
    );
  }
}
