import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../format.dart';
import '../../window_layout.dart';
import '../page/collapsing_header.dart';

/// Size of the circle round each day's number.
const _dayCircle = 32.0;
const _markDot = 4.0;

/// One week of days to pick from, swiped sideways to earlier weeks, as a
/// calendar app's week header. A mark under a day says it has records.
/// Days after [latest] cannot be picked.
class WeekDayStrip extends StatefulWidget {
  const WeekDayStrip({
    super.key,
    required this.selected,
    required this.latest,
    required this.onSelected,
    this.firstWeekday = DateTime.monday,
    this.markedDays = const {},
    this.color = AppColors.training,
  });

  /// Midnight of the day picked.
  final DateTime selected;

  /// Midnight of the last day that can be picked, usually today.
  final DateTime latest;
  final ValueChanged<DateTime> onSelected;

  /// The weekday a week starts on, as the system calendar has it.
  final int firstWeekday;

  /// Midnights of the days that have records.
  final Set<DateTime> markedDays;
  final Color color;

  /// How tall the strip is at the current text size.
  static double heightOf(BuildContext context) =>
      measureTextHeight(
        context,
        '日',
        AppTextStyles.caption,
        maxWidth: double.infinity,
      ) +
      AppSpacing.xxs +
      _dayCircle +
      AppSpacing.xxs +
      _markDot;

  /// How tall the page's pinned slot is with the strip in it.
  static double pinnedHeightOf(BuildContext context) =>
      measurePinnedHeight(heightOf(context));

  @override
  State<WeekDayStrip> createState() => _WeekDayStripState();
}

/// How many weeks back the strip can be swiped: ten years.
const _weeks = 520;

class _WeekDayStripState extends State<WeekDayStrip> {
  /// Made once the width is known: a week is exactly the page column
  /// wide, so the weeks either side show in the margins and the row
  /// reads as one that goes on past the screen.
  PageController? _pages;

  DateTime _startOf(DateTime day) {
    final back = (day.weekday - widget.firstWeekday + 7) % 7;
    return DateTime(day.year, day.month, day.day - back);
  }

  /// The page showing [day]'s week; [latest]'s is the one before last,
  /// the last being the week after it, shown but not pickable.
  int _pageOf(DateTime day) {
    final weeksBack =
        _startOf(widget.latest).difference(_startOf(day)).inDays ~/ 7;
    return (_weeks - 1 - weeksBack).clamp(0, _weeks);
  }

  PageController _controllerFor(double fraction) {
    final current = _pages;
    if (current != null && current.viewportFraction == fraction) {
      return current;
    }
    final page = current != null && current.hasClients
        ? current.page!.round()
        : _pageOf(widget.selected);
    // Still attached this frame (a rotation changed the width), so let
    // it go once the new one has taken over.
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    return _pages = PageController(
      initialPage: page,
      viewportFraction: fraction,
    );
  }

  @override
  void didUpdateWidget(WeekDayStrip old) {
    super.didUpdateWidget(old);
    final page = _pageOf(widget.selected);
    final pages = _pages;
    if (pages != null && pages.hasClients && pages.page?.round() != page) {
      pages.jumpToPage(page);
    }
  }

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: WeekDayStrip.heightOf(context),
    child: LayoutBuilder(
      builder: (context, space) {
        final gutter = PageColumn.gutterOf(context);
        final width = space.maxWidth;
        final column = (width - gutter.horizontal).clamp(1.0, width);
        return PageView.builder(
          controller: _controllerFor(column / width),
          itemCount: _weeks + 1,
          itemBuilder: (context, page) {
            final start = _startOf(widget.latest);
            final weekStart = DateTime(
              start.year,
              start.month,
              start.day - (_weeks - 1 - page) * 7,
            );
            return Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Day(
                      day: DateTime(
                        weekStart.year,
                        weekStart.month,
                        weekStart.day + i,
                      ),
                      strip: widget,
                    ),
                  ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _Day extends StatelessWidget {
  const _Day({required this.day, required this.strip});

  final DateTime day;
  final WeekDayStrip strip;

  @override
  Widget build(BuildContext context) {
    final isSelected = day == strip.selected;
    final isMarked = strip.markedDays.contains(day);
    final canPick = !day.isAfter(strip.latest);
    return Semantics(
      button: canPick,
      selected: isSelected,
      label:
          '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）'
          '${isMarked ? '，有紀錄' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canPick ? () => strip.onSelected(day) : null,
        child: Column(
          children: [
            Text(weekdayLabel(day), style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xxs),
            Container(
              width: _dayCircle,
              height: _dayCircle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? strip.color : Colors.transparent,
              ),
              child: Text(
                '${day.day}',
                style: AppTextStyles.body.copyWith(
                  fontSize: 15,
                  color: isSelected
                      ? AppColors.background
                      : canPick
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Container(
              width: _markDot,
              height: _markDot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMarked ? strip.color : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
