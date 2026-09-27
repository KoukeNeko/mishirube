import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
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

  /// The day the calendar lists; it may lie outside [_month] once the
  /// calendar has been scrolled on.
  late DateTime _selected;

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

  bool get _isEarliestMonth => !_month.isAfter(_log.earliestMonth);

  void _setMonth(DateTime month) {
    setState(() {
      _month = month;
      // Today in the current month; otherwise the month's first day.
      _selected = _isCurrentMonth ? _dayOf(_today) : month;
    });
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
    final destination = timelineDestination(entry, isSleep: _log.isSleep);
    if (destination != null) pushPage(context, destination);
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _log, builder: (context, _) => _page());

  Widget _page() {
    final isTimeline = _view == _LogView.timeline;
    return CollapsingPage(
      // The tab names the page. The calendar reads as Apple Calendar's
      // month view: its month pinned as a title, and the year to reach
      // other months from.
      title: null,
      compactBar: isTimeline
          ? CompactBarBehavior.none
          : CompactBarBehavior.pinned,
      leading: isTimeline
          ? null
          : Builder(
              builder: (buttonContext) => HeaderAction(
                icon: Icons.chevron_left,
                label: context.dates.compactYear(_month.year),
                semanticLabel: context.l10n.pickMonthCurrent(
                  month: context.dates.compactYearMonth(_month),
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
          ? Gutter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.dates.compactMonth(_month),
                  maxLines: 1,
                  style: largeTitleStyle,
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  // The switch takes the toolbar's row once it has
                  // scrolled away, centred in it as the toolbar's buttons.
                  height: ToolbarMetrics.of(context).controlRowHeight,
                  child: Gutter(
                    child: Row(
                      children: [
                        _MonthStep(
                          icon: Icons.chevron_left,
                          semanticLabel: context.l10n.previousMonth,
                          onTap: _isEarliestMonth
                              ? null
                              : () => _setMonth(
                                  DateTime(_month.year, _month.month - 1),
                                ),
                        ),
                        Expanded(
                          // Shrinks rather than overflows at large text sizes.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Builder(
                              builder: (buttonContext) => HeaderAction(
                                icon: Icons.calendar_month_outlined,
                                label: context.dates.yearMonth(_month),
                                semanticLabel: context.l10n.pickMonthCurrent(
                                  month: context.dates.yearMonth(_month),
                                ),
                                onTap: () => _pickMonth(buttonContext),
                              ),
                            ),
                          ),
                        ),
                        _MonthStep(
                          icon: Icons.chevron_right,
                          semanticLabel: context.l10n.nextMonth,
                          onTap: _isCurrentMonth
                              ? null
                              : () => _setMonth(
                                  DateTime(_month.year, _month.month + 1),
                                ),
                        ),
                      ],
                    ),
                  ),
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
      // The chips' row, then the switch's, as tall as the toolbar's row.
      pinnedHeight: isTimeline
          ? measurePinnedControlHeight(context) +
                AppSpacing.xs +
                ToolbarMetrics.of(context).controlRowHeight
          : measurePinnedControlHeight(context) -
                pillHeight(context) +
                measureTextHeight(
                  context,
                  context.dates.compactMonth(DateTime(2024, 12)),
                  largeTitleStyle,
                  maxWidth: double.infinity,
                ),
      children: _view == _LogView.timeline
          ? _timeline(_log.month(_month))
          : _calendar(),
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
          Gutter(child: _DayHeader(day: day)),
          for (final entry in entries)
            Gutter(
              child: _TimelineRow(entry: entry, onTap: () => _openEntry(entry)),
            ),
        ],
    ];
  }

  List<Widget> _calendar() {
    final entries = _log.day(_selected);
    return [
      Gutter(
        child: MonthCalendar(
          month: _month,
          earliest: _log.earliestMonth,
          selected: _selected,
          today: _today,
          firstWeekday: AppStoreScope.of(context).firstWeekday,
          categoriesOf: _log.categoriesIn,
          onSelect: (day) => setState(() => _selected = day),
          // Scrolled by hand: the month shown follows, the day listed
          // stays until another is tapped.
          onMonth: (month) => setState(() => _month = month),
        ),
      ),
      Gutter(child: const _CalendarLegend()),
      Gutter(
        child: SectionLabel(context.dates.compactDayWithWeekday(_selected)),
      ),
      if (entries.isEmpty)
        Gutter(child: InfoBanner(message: context.l10n.noEntriesThisDay))
      else
        for (final entry in entries)
          Gutter(
            child: _TimelineRow(entry: entry, onTap: () => _openEntry(entry)),
          ),
    ];
  }
}

/// A step to the month before or after; dimmed where there is none.
class _MonthStep extends StatelessWidget {
  const _MonthStep({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: HeaderAction(
        icon: icon,
        semanticLabel: semanticLabel,
        onTap: onTap,
      ),
    );
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
