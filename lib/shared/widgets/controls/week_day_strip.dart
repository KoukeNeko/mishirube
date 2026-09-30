import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';
import '../../motion.dart';
import '../../window_layout.dart';
import '../page/collapsing_header.dart';
import '../../../l10n/l10n.dart';

/// Size of the circle round each day's number.
const _dayCircle = 32.0;
const _markDot = 4.0;

/// Where a day's circle starts, under its weekday.
double _circleTop(BuildContext context) =>
    measureTextHeight(
      context,
      // l10n-ignore: measures a line of text, never shown.
      '日',
      AppTextStyles.caption,
      maxWidth: double.infinity,
    ) +
    AppSpacing.xxs;

/// How long the picked day's circle takes to move, and a week to turn.
const _moveDuration = Duration(milliseconds: 250);

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
      _circleTop(context) + _dayCircle + AppSpacing.xxs + _markDot;

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

  /// The day cell last under the strip's centre, counted in days from
  /// the first week; null between scrolls.
  int? _detent;

  /// Whether this scroll crossed a day; one that did not has nothing to
  /// settle.
  bool _hasTicked = false;

  /// Ticks as the Digital Crown does: once for each day that crosses the
  /// strip, however fast, never a burst to catch up on days skipped in
  /// one frame; then a firmer one when it settles on a week. A week the
  /// strip turns to by itself ticks as a swiped one does, so the hand
  /// feels every move of the row, not only its own.
  bool _tickDetents(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final page = switch (notification.metrics) {
      final PageMetrics metrics => metrics.page,
      _ => null,
    };
    if (page == null) return false;
    // A day's cell is crossed at its middle, so a swipe back is as
    // exact as one forward.
    final detent = (page * 7).round();
    switch (notification) {
      case ScrollStartNotification():
        _detent = detent;
        _hasTicked = false;
      case ScrollUpdateNotification() when _detent != null:
        if (detent != _detent) {
          _detent = detent;
          _hasTicked = true;
          AppHaptics.selection(context);
        }
      case ScrollEndNotification():
        if (_hasTicked) AppHaptics.settle(context);
        _detent = null;
      default:
    }
    return false;
  }

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
      final duration = chromeDuration(context, _moveDuration);
      if (duration == Duration.zero) {
        pages.jumpToPage(page);
      } else {
        pages.animateToPage(page, duration: duration, curve: Curves.easeOut);
      }
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
        // A first frame laid out with the screen off has no width.
        if (width <= 0) return const SizedBox.shrink();
        final column = (width - gutter.horizontal).clamp(1.0, width);
        return NotificationListener<ScrollNotification>(
          onNotification: _tickDetents,
          child: PageView.builder(
            controller: _controllerFor(column / width),
            itemCount: _weeks + 1,
            itemBuilder: (context, page) {
              final start = _startOf(widget.latest);
              final weekStart = DateTime(
                start.year,
                start.month,
                start.day - (_weeks - 1 - page) * 7,
              );
              final days = [
                for (var i = 0; i < 7; i++)
                  DateTime(weekStart.year, weekStart.month, weekStart.day + i),
              ];
              final picked = days.indexOf(widget.selected);
              final duration = chromeDuration(context, _moveDuration);
              return LayoutBuilder(
                builder: (context, week) => Stack(
                  children: [
                    // One circle for the week, sliding to the day picked
                    // rather than one day's going out as another's comes on.
                    if (picked >= 0)
                      AnimatedPositioned(
                        duration: duration,
                        curve: Curves.easeOut,
                        top: _circleTop(context),
                        left:
                            (picked + 0.5) * week.maxWidth / 7 - _dayCircle / 2,
                        width: _dayCircle,
                        height: _dayCircle,
                        child: AnimatedContainer(
                          duration: duration,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.color,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        for (final day in days)
                          Expanded(
                            child: _Day(day: day, strip: widget),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
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
      label: isMarked
          ? context.l10n.dayStripHasRecords(
              date: context.dates.dayWithWeekday(day),
            )
          : context.dates.dayWithWeekday(day),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canPick ? () => strip.onSelected(day) : null,
        child: Column(
          children: [
            Text(context.dates.weekday(day), style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xxs),
            // The circle behind is the week's, sliding under the day.
            Container(
              width: _dayCircle,
              height: _dayCircle,
              alignment: Alignment.center,
              child: AnimatedDefaultTextStyle(
                duration: chromeDuration(context, _moveDuration),
                // As the log's month calendar writes its days.
                style: AppTextStyles.body.copyWith(
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.background
                      : canPick
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
                // Shrinks rather than overflows at large text sizes.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${day.day}'),
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
