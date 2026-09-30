import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';
import 'month_calendar.dart';
import 'log_view_model.dart';
import 'timeline_destination.dart';
import '../../l10n/l10n.dart';

enum _LogView { timeline, calendar }

/// A chip in the log's filter row: everything, then one per category, so
/// a new kind of record appears here without editing this screen.
class _LogFilter {
  const _LogFilter(this.category);

  static const all = _LogFilter(null);
  static final values = [
    all,
    for (final category in RecordCategory.values) _LogFilter(category),
  ];

  /// Null filters nothing out.
  final RecordCategory? category;

  String labelIn(AppLocalizations l10n) =>
      category?.labelIn(l10n) ?? l10n.logFilterAll;

  IconData get icon => category?.icon ?? Icons.apps;

  Color get color => category?.color ?? AppColors.textPrimary;

  bool accepts(TimelineEntry entry) =>
      category == null || entry.category == category;
}

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late _LogView _view = _log.showsCalendar
      ? _LogView.calendar
      : _LogView.timeline;
  _LogFilter _filter = _LogFilter.all;
  String _query = '';

  /// First day of the month being browsed.
  late DateTime _month;

  /// The day the calendar lists, or the timeline has at its top; it may
  /// lie outside [_month] once the calendar has been scrolled on.
  late DateTime _selected;

  /// Each listed day's header on the timeline, to scroll to and to read
  /// which day is at the top.
  final _dayKeys = <DateTime, GlobalKey>{};

  /// The pinned strip, whose bottom edge is where the list shows from.
  final _pinnedKey = GlobalKey();

  /// Set while the timeline scrolls to a picked day, so that scroll does
  /// not pick a day of its own.
  bool _isRevealing = false;

  late final _log = LogViewModel(AppStoreScope.read(context).backend);

  DateTime get _today => _log.now();

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
    _selected = _dayOf(_today);
  }

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  bool get _isCurrentMonth =>
      _month.year == _today.year && _month.month == _today.month;

  void _setMonth(DateTime month) {
    setState(() {
      _month = month;
      // Today in the current month; otherwise the month's first day, or
      // on the timeline, which lists newest first, its last.
      _selected = _isCurrentMonth
          ? _dayOf(_today)
          : _view == _LogView.timeline
          ? DateTime(month.year, month.month + 1, 0)
          : month;
    });
    _revealSelected();
  }

  /// A day picked on the week strip: its month is listed, and the list
  /// scrolls to it.
  void _pickDay(DateTime day) {
    setState(() {
      _selected = day;
      _month = DateTime(day.year, day.month);
    });
    _revealSelected();
  }

  /// Scrolls the timeline to [_selected]'s header, or to the nearest
  /// listed day before it, once the list has been built. The list is
  /// built lazily, so a header not yet built is reached by stepping a
  /// screen at a time towards it.
  void _revealSelected() {
    if (_view != _LogView.timeline) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final listed = _listedDays();
      if (listed.isEmpty) return;
      final target =
          listed.where((day) => !day.isAfter(_selected)).firstOrNull ??
          listed.last;
      _isRevealing = true;
      try {
        for (var step = 0; step < 100 && mounted; step++) {
          final built = [
            for (final day in listed)
              if (_dayKeys[day]?.currentContext != null) day,
          ];
          if (built.isEmpty) return;
          final position = Scrollable.of(_dayKeys[built.first]!.currentContext!)
              .position;
          // The newest day is the list's top, toolbar and all.
          if (target == listed.first) {
            await _scrollTo(position, position.minScrollExtent);
            return;
          }
          if (_dayKeys[target]?.currentContext != null) {
            await _settle(position, _dayKeys[target]!);
            return;
          }
          // Newest first: an older day lies further down.
          final isBelow = target.isBefore(built.last);
          final next =
              position.pixels +
              (isBelow ? 1 : -1) * position.viewportDimension * 0.8;
          position.jumpTo(
            next.clamp(position.minScrollExtent, position.maxScrollExtent),
          );
          await WidgetsBinding.instance.endOfFrame;
        }
      } finally {
        _isRevealing = false;
      }
    });
  }

  Future<void> _scrollTo(ScrollPosition position, double offset) {
    final duration = chromeDuration(context, const Duration(milliseconds: 250));
    if (duration == Duration.zero) {
      position.jumpTo(offset);
      return Future.value();
    }
    return position.animateTo(
      offset,
      duration: duration,
      curve: Curves.easeOut,
    );
  }

  /// Brings [header] to just under the pinned strip. The toolbar scrolls
  /// away above the strip, which moves it, so the offset is measured
  /// again once and corrected.
  Future<void> _settle(ScrollPosition position, GlobalKey header) async {
    final duration = chromeDuration(context, const Duration(milliseconds: 250));
    for (var pass = 0; pass < 2 && mounted; pass++) {
      final strip = _pinnedKey.currentContext?.findRenderObject() as RenderBox?;
      final box = header.currentContext?.findRenderObject() as RenderBox?;
      if (strip == null || box == null || !box.attached) return;
      final stripBottom = strip.localToGlobal(Offset(0, strip.size.height)).dy;
      final delta = box.localToGlobal(Offset.zero).dy - stripBottom;
      if (delta.abs() < 1) return;
      final to = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (duration == Duration.zero || pass > 0) {
        position.jumpTo(to);
      } else {
        await position.animateTo(to, duration: duration, curve: Curves.easeOut);
      }
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  /// The days the timeline lists, newest first, under the filter and
  /// search.
  List<DateTime> _listedDays() => [
    for (final day in _log.month(_month).days)
      if (day.entries.where(_filter.accepts).where(_matchesQuery).isNotEmpty ||
          _query.isEmpty)
        day.date,
  ];

  /// Once the timeline stops, the week strip picks the day at its top.
  bool _followScroll(ScrollEndNotification notification) {
    // The page's own list only, not the strip's or the chips' rows.
    if (_isRevealing ||
        _view != _LogView.timeline ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    // A scroll can end mid-build, when the list under it changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isRevealing) _pickDayAtTop();
    });
    return false;
  }

  void _pickDayAtTop() {
    final strip = _pinnedKey.currentContext?.findRenderObject() as RenderBox?;
    if (strip == null) return;
    final top = strip.localToGlobal(Offset(0, strip.size.height)).dy;
    DateTime? atTop;
    for (final day in _listedDays()) {
      final box =
          _dayKeys[day]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      // The last header at or above the strip's edge owns the top of the
      // list; before any has reached it, the first one built does.
      if (box.localToGlobal(Offset.zero).dy <= top + 1) {
        atTop = day;
      } else {
        atTop ??= day;
        break;
      }
    }
    if (atTop != null && atTop != _selected) {
      setState(() => _selected = atTop!);
    }
  }

  /// Which of the strip's weeks have records the filter keeps.
  Set<DateTime> _markedDays() {
    final day = _selected;
    final marked = <DateTime>{};
    for (var back = -35; back <= 35; back += 7) {
      final month = DateTime(day.year, day.month, day.day + back);
      final first = DateTime(month.year, month.month);
      for (final MapEntry(key: date, value: categories)
          in _log.categoriesIn(first).entries) {
        if (_filter.category == null || categories.contains(_filter.category)) {
          marked.add(DateTime(first.year, first.month, date));
        }
      }
    }
    return marked;
  }

  void _search(String query) {
    setState(() {
      _query = query.trim();
      // Results are listed on the timeline.
      if (_query.isNotEmpty) _view = _LogView.timeline;
    });
  }

  void _setView(_LogView view) {
    setState(() => _view = view);
    _log.setShowsCalendar(view == _LogView.calendar);
  }

  bool _matchesQuery(TimelineEntry entry) =>
      _query.isEmpty ||
      [
        entry.title,
        entry.detail,
        ...entry.tags,
      ].any((text) => text.contains(_query));

  void _goToToday() {
    setState(() {
      _month = DateTime(_today.year, _today.month);
      _selected = _dayOf(_today);
    });
    _revealSelected();
  }

  /// Opens the month wheels under [buttonContext]'s button.
  void _pickMonth(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject()! as RenderBox;
    showMonthPopover(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      selected: _month,
      earliest: _log.earliestMonth,
      latest: DateTime(_today.year, _today.month),
      onChanged: _setMonth,
    );
  }

  void _openEntry(TimelineEntry entry) {
    final destination = timelineDestination(
      entry,
      isSleep: _log.isSleep,
      mealById: _log.backend.nutrition.mealById,
    );
    if (destination != null) pushPage(context, destination);
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _log, builder: (context, _) => _page());

  Widget _page() {
    final isTimeline = _view == _LogView.timeline;
    return NotificationListener<ScrollEndNotification>(
      onNotification: _followScroll,
      child: LayoutBuilder(
        builder: (context, constraints) => _pageBody(
          isTimeline,
          // Held while the list keeps at least as much of the page, which
          // a device on its side does not.
          calendarStays:
              WeekdayHeader.height + MonthCalendar.height <=
              constraints.maxHeight / 2,
        ),
      ),
    );
  }

  Widget _pageBody(bool isTimeline, {required bool calendarStays}) {
    return CollapsingPage(
      // The tab names the page. The calendar reads as Apple Calendar's
      // month view: its month pinned as a title, and the year to reach
      // other months from.
      title: null,
      compactBar: isTimeline
          ? CompactBarBehavior.none
          : CompactBarBehavior.pinned,
      // The calendar's grid starts right under its pinned weekdays; held,
      // the grid is not in the list, which keeps the gap under it.
      hasTopGap: isTimeline || calendarStays,
      // Held as Apple Calendar's month is, its months scrolling up behind
      // the bar and the day's list scrolling on its own below it.
      held: !isTimeline && calendarStays
          ? (headerHeight) => _monthCalendar(topInset: headerHeight)
          : null,
      heldHeight: MonthCalendar.height,
      // On the timeline the month is picked here; the week strip under
      // the toolbar picks the day.
      // The month is picked here in both views: on the calendar it is the
      // page's title too, which leaves the grid the height.
      leading: Builder(
        builder: (buttonContext) => HeaderAction(
          icon: Icons.calendar_month_outlined,
          label: context.dates.compactYearMonth(_month),
          semanticLabel: context.l10n.pickMonthCurrent(
            month: context.dates.yearMonth(_month),
          ),
          onTap: () => _pickMonth(buttonContext),
        ),
      ),
      actions: [
        SearchableHeaderActions(
          hint: context.l10n.logSearch,
          searchLabel: context.l10n.logSearch,
          onChanged: _search,
          actions: [
            HeaderAction(
              icon: Icons.today_outlined,
              label: context.l10n.tabToday,
              semanticLabel: context.l10n.backToToday,
              onTap: _goToToday,
            ),
            HeaderAction(
              icon: isTimeline
                  ? Icons.calendar_month_outlined
                  : Icons.view_agenda_outlined,
              semanticLabel: isTimeline
                  ? context.l10n.showAsCalendar
                  : context.l10n.showAsTimeline,
              onTap: () =>
                  _setView(isTimeline ? _LogView.calendar : _LogView.timeline),
            ),
          ],
        ),
      ],
      // The timeline's month and its category chips stay at the top as
      // the list scrolls, as does the calendar's month.
      pinned: !isTimeline
          // Over the calendar's columns, which are the week strip's.
          ? WeekdayHeader(firstWeekday: AppStoreScope.of(context).firstWeekday)
          : Column(
              key: _pinnedKey,
              children: [
                // The same week header as 睡眠 and 飲食.
                WeekDayStrip(
                  selected: _selected,
                  latest: _dayOf(_today),
                  firstWeekday: AppStoreScope.of(context).firstWeekday,
                  color: _filter.color,
                  markedDays: _markedDays(),
                  onSelected: _pickDay,
                ),
                const SizedBox(height: AppSpacing.xs),
                FilterChipBar<_LogFilter>(
                  options: _LogFilter.values,
                  selected: _filter,
                  labelOf: (filter) => filter.labelIn(context.l10n),
                  iconOf: (filter) => filter.icon,
                  colorOf: (filter) => filter.color,
                  onSelected: (filter) => setState(() => _filter = filter),
                ),
              ],
            ),
      // The week strip, then the chips' row.
      pinnedHeight: isTimeline
          ? measurePinnedControlHeight(context) +
                AppSpacing.xs +
                WeekDayStrip.heightOf(context)
          // The weekdays sit on the grid, with no inset round them.
          : WeekdayHeader.height,
      children: _view == _LogView.timeline
          ? _timeline(_log.month(_month))
          : _calendar(calendarStays: calendarStays),
    );
  }

  List<Widget> _timeline(MonthRecords records) {
    final days = [
      for (final day in records.days)
        if (day.entries.where(_filter.accepts).where(_matchesQuery).toList()
            case final entries when entries.isNotEmpty || _query.isEmpty)
          (day, entries),
    ];
    return [
      if (records.days.isEmpty)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: context.l10n.noEntriesInMonth(
              month: context.dates.month(_month.month),
            ),
          ),
        )
      else if (days.isEmpty)
        Gutter(
          child: InfoBanner(
            message: context.l10n.noEntriesMatching(query: _query),
          ),
        )
      else
        for (final (day, entries) in days) ...[
          Gutter(
            key: _dayKeys.putIfAbsent(day.date, GlobalKey.new),
            child: _DayHeader(day: day),
          ),
          for (final entry in entries)
            Gutter(
              child: _TimelineRow(entry: entry, onTap: () => _openEntry(entry)),
            ),
        ],
    ];
  }

  Widget _monthCalendar({double topInset = 0}) => MonthCalendar(
    topInset: topInset,
    month: _month,
    earliest: _log.earliestMonth,
    selected: _selected,
    today: _today,
    firstWeekday: AppStoreScope.of(context).firstWeekday,
    categoriesOf: _log.categoriesIn,
    onSelect: (day) => setState(() => _selected = day),
    // Scrolled by hand: the month shown follows, the day listed stays
    // until another is tapped.
    onMonth: (month) => setState(() => _month = month),
  );

  List<Widget> _calendar({required bool calendarStays}) {
    final entries = _log.day(_selected);
    return [
      // Right under the pinned weekdays, scrolling with the list.
      if (!calendarStays) _monthCalendar(),
      Gutter(child: const _CalendarLegend()),
      Gutter(
        child: SectionLabel(context.dates.compactDayWithWeekday(_selected)),
      ),
      if (entries.isEmpty)
        Gutter(child: InfoBanner(message: context.l10n.noEntriesThisDay))
      else
        // A card each, as the timeline has them, at a row's height.
        for (final entry in entries)
          Gutter(
            child: _DayEntryRow(entry: entry, onTap: () => _openEntry(entry)),
          ),
    ];
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final TimelineDay day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      // Wraps so the warning drops below the date at large text sizes.
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            day.label,
            style: AppTextStyles.itemTitle.copyWith(fontSize: 17),
          ),
          if (day.warning != null)
            TagChip(label: day.warning!, tone: TagTone.warning),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.onTap});

  final TimelineEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Text(
              entry.timeLabel,
              style: AppTextStyles.itemTitle.copyWith(
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        Expanded(
          child: AppCard(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AccentBar(color: entry.category.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _TimelineContent(entry: entry)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One record in the calendar's day list: its kind's colour down the
/// side, what it was, and its time at the end, as a calendar lists a
/// day's events.
class _DayEntryRow extends StatelessWidget {
  const _DayEntryRow({required this.entry, required this.onTap});

  final TimelineEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    // A row's height, not an ordinary card's.
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AccentBar(color: entry.category.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.itemTitle,
                ),
                if (entry.detail.isNotEmpty)
                  Text(
                    entry.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            entry.timeLabel,
            style: AppTextStyles.caption.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.entry});

  final TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.category.labelIn(context.l10n),
          style: TextStyle(
            color: entry.category.color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          entry.title,
          style: AppTextStyles.itemTitle.copyWith(fontSize: 17),
        ),
        if (entry.detail.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(entry.detail, style: AppTextStyles.caption),
        ],
        if (entry.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          TagWrap(labels: entry.tags),
        ],
      ],
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      children: [
        for (final category in RecordCategory.values)
          CategoryLabel(
            label: category.labelIn(context.l10n),
            color: category.color,
          ),
      ],
    );
  }
}
