import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'month_calendar.dart';
import 'log_view_model.dart';
import 'timeline_destination.dart';

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

  String get label => category?.label ?? '全部';

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
  late int _selectedDay;

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
    _selectedDay = _today.day;
  }

  bool get _isCurrentMonth =>
      _month.year == _today.year && _month.month == _today.month;

  bool get _isEarliestMonth => !_month.isAfter(_log.earliestMonth);

  void _setMonth(DateTime month) {
    setState(() {
      _month = month;
      // Today in the current month; otherwise the month's first day.
      _selectedDay = _isCurrentMonth ? _today.day : 1;
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

  /// Keys on the timeline's day headers, by day of the month, so the
  /// calendar can open the timeline on its day.
  final _dayKeys = <int, GlobalKey>{};
  final _timelineStart = GlobalKey();

  /// Switches to the timeline and scrolls to [day]. The list is built as
  /// it scrolls, so a day far down is reached a screen at a time.
  void _openOnTimeline(int day) {
    _setView(_LogView.timeline);
    var screens = 0;
    // Taken once: the top of the list is gone once it has scrolled.
    ScrollPosition? position;
    void reveal(Duration _) {
      if (!mounted) return;
      final header = _dayKeys[day]?.currentContext;
      if (header != null) {
        // Below the pinned header and view control, not under them; once
        // more a frame later, when the rows around it have been laid out
        // and the list knows its real length.
        Scrollable.ensureVisible(header, alignment: 0.3);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_dayKeys[day]?.currentContext case final settled?) {
            Scrollable.ensureVisible(settled, alignment: 0.3);
          }
        });
        return;
      }
      position ??= switch (_timelineStart.currentContext) {
        final start? => Scrollable.of(start).position,
        null => null,
      };
      final scroll = position;
      // Stops at the end of the list or after enough screens: the day may
      // have no records under the current filter.
      if (scroll == null ||
          scroll.pixels >= scroll.maxScrollExtent ||
          screens++ > 50) {
        return;
      }
      scroll.jumpTo(
        (scroll.pixels + scroll.viewportDimension * 0.8).clamp(
          0,
          scroll.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback(reveal);
    }

    WidgetsBinding.instance.addPostFrameCallback(reveal);
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
      _selectedDay = _today.day;
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
    final records = _log.month(_month);
    final isTimeline = _view == _LogView.timeline;
    return CollapsingPage(
      title: '紀錄',
      compactBar: CompactBarBehavior.none,
      actions: [
        SearchableHeaderActions(
          hint: '搜尋紀錄',
          searchLabel: '搜尋紀錄',
          onChanged: _search,
          actions: [
            HeaderAction(
              icon: Icons.today_outlined,
              label: '今天',
              semanticLabel: '回到今天',
              onTap: _goToToday,
            ),
            HeaderAction(
              icon: isTimeline
                  ? Icons.calendar_month_outlined
                  : Icons.view_agenda_outlined,
              semanticLabel: isTimeline ? '以月曆顯示' : '以時間軸顯示',
              onTap: () =>
                  _setView(isTimeline ? _LogView.calendar : _LogView.timeline),
            ),
          ],
        ),
      ],
      // The month is what both views show, so it stays pinned; the
      // category chips only narrow the list and scroll away with it.
      pinned: Gutter(
        child: Row(
          children: [
            _MonthStep(
              icon: Icons.chevron_left,
              semanticLabel: '上個月',
              onTap: _isEarliestMonth
                  ? null
                  : () => _setMonth(DateTime(_month.year, _month.month - 1)),
            ),
            Expanded(
              // Shrinks rather than overflows at large text sizes.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Builder(
                  builder: (buttonContext) => HeaderAction(
                    icon: Icons.calendar_month_outlined,
                    label: '${_month.year} 年 ${_month.month} 月',
                    semanticLabel: '選擇月份，目前 ${_month.year} 年 ${_month.month} 月',
                    onTap: () => _pickMonth(buttonContext),
                  ),
                ),
              ),
            ),
            _MonthStep(
              icon: Icons.chevron_right,
              semanticLabel: '下個月',
              onTap: _isCurrentMonth
                  ? null
                  : () => _setMonth(DateTime(_month.year, _month.month + 1)),
            ),
          ],
        ),
      ),
      children: _view == _LogView.timeline
          ? _timeline(records)
          : _calendar(records),
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
      FilterChipBar<_LogFilter>(
        key: _timelineStart,
        options: _LogFilter.values,
        selected: _filter,
        labelOf: (filter) => filter.label,
        iconOf: (filter) => filter.icon,
        colorOf: (filter) => filter.color,
        onSelected: (filter) => setState(() => _filter = filter),
      ),
      if (records.days.isEmpty)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: '${_month.month} 月沒有紀錄',
          ),
        )
      else if (days.isEmpty)
        Gutter(child: InfoBanner(message: '找不到符合「$_query」的紀錄。'))
      else
        for (final (day, entries) in days) ...[
          Gutter(
            key: entries.isEmpty
                ? null
                : _dayKeys.putIfAbsent(entries.first.at.day, GlobalKey.new),
            child: _DayHeader(day: day),
          ),
          for (final entry in entries)
            Gutter(
              child: _TimelineRow(entry: entry, onTap: () => _openEntry(entry)),
            ),
        ],
    ];
  }

  List<Widget> _calendar(MonthRecords records) {
    final entries = [
      for (final day in records.days)
        for (final entry in day.entries)
          if (entry.at.day == _selectedDay) entry,
    ];
    return [
      Gutter(
        child: MonthCalendar(
          month: _month,
          selectedDay: _selectedDay,
          today: _today,
          dotsByDay: records.dots,
          onSelect: (day) => setState(() => _selectedDay = day),
        ),
      ),
      Gutter(child: const _CalendarLegend()),
      Gutter(
        child: SectionLabel(
          '${_month.month} 月 $_selectedDay 日',
          trailing: LinkText(
            label: '在時間軸開啟',
            onTap: () => _openOnTimeline(_selectedDay),
          ),
        ),
      ),
      if (entries.isEmpty)
        Gutter(child: const InfoBanner(message: '這天沒有紀錄。'))
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
          entry.category.label,
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
        const SizedBox(height: AppSpacing.xxs),
        Text(entry.detail, style: AppTextStyles.caption),
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
          CategoryLabel(label: category.label, color: category.color),
      ],
    );
  }
}
