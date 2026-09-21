import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/activity_detail_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../training/workout_summary_screen.dart';
import 'month_calendar.dart';

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
  _LogView _view = _LogView.timeline;
  _LogFilter _filter = _LogFilter.all;
  String _query = '';

  /// First day of the month being browsed.
  late DateTime _month;
  late int _selectedDay;

  DateTime get _today => AppStoreScope.read(context).now();

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
    _selectedDay = _today.day;
  }

  bool get _isCurrentMonth =>
      _month.year == _today.year && _month.month == _today.month;

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
      earliest: AppStoreScope.read(context).earliestRecordMonth,
      latest: DateTime(_today.year, _today.month),
      onChanged: _setMonth,
    );
  }

  void _openEntry(TimelineEntry entry) {
    // Exhaustive on purpose: a new kind of record must decide what
    // opening its row does, rather than silently doing nothing.
    final id = entry.recordId;
    final destination = switch (entry.category) {
      RecordCategory.training => WorkoutSummaryScreen(workoutId: id),
      RecordCategory.nutrition => DailyNutritionScreen(day: entry.at),
      RecordCategory.activity when id != null => ActivityDetailScreen(
        activityId: id,
      ),
      RecordCategory.body || RecordCategory.wellness when id != null =>
        JournalDetailScreen(id: id, at: entry.at),
      // Every source gives its rows an id; a row without one has nothing
      // behind it to open.
      _ => null,
    };
    if (destination != null) pushPage(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    final records = AppStoreScope.of(context).monthRecords(_month);
    return CollapsingPage(
      title: '紀錄',
      subtitle: '${_month.year} 年 ${_month.month} 月',
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
            Builder(
              builder: (buttonContext) => HeaderAction(
                icon: Icons.calendar_month_outlined,
                label: '${_month.month}月',
                semanticLabel: '切換月份，目前 ${_month.year} 年 ${_month.month} 月',
                onTap: () => _pickMonth(buttonContext),
              ),
            ),
          ],
        ),
      ],
      // Switching views changes the whole page, so it stays pinned; the
      // category chips only narrow the list and scroll away with it.
      pinned: Gutter(
        child: SegmentedChoice(
          options: _LogView.values,
          selected: _view,
          labelOf: (view) => view == _LogView.timeline ? '時間軸' : '月曆',
          onChanged: (view) => setState(() => _view = view),
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
      // Full-bleed: the chips scroll to the screen edge, so the row pads
      // its own content instead of taking a Gutter.
      SizedBox(
        height: pillHeight(context),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          itemCount: _LogFilter.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
          itemBuilder: (_, index) {
            final filter = _LogFilter.values[index];
            return SelectChip(
              label: filter.label,
              icon: filter.icon,
              iconColor: filter.color,
              // Rim in the category's colour; a fill would drown the icon.
              showsSelectionAsOutline: true,
              selectedColor: filter.color,
              isSelected: filter == _filter,
              onTap: () => setState(() => _filter = filter),
            );
          },
        ),
      ),
      if (records.days.isEmpty)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: '${_month.month} 月沒有紀錄',
            message: '換一個月份看看，或從「+」新增一筆紀錄。',
          ),
        )
      else if (days.isEmpty)
        Gutter(child: InfoBanner(message: '找不到符合「$_query」的紀錄。'))
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

  List<Widget> _calendar(MonthRecords records) {
    final summaries = records.summaries[_selectedDay] ?? const {};
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
            onTap: () => setState(() => _view = _LogView.timeline),
          ),
        ),
      ),
      if (summaries.isEmpty)
        Gutter(child: const InfoBanner(message: '這天沒有紀錄。'))
      else
        for (final MapEntry(key: category, value: summary) in summaries.entries)
          Gutter(
            child: AccentRow(
              color: category.color,
              title: category.label,
              trailing: summary,
            ),
          ),
      Gutter(
        child: const Text('尚未發生的日期不顯示 0 或 --。', style: AppTextStyles.caption),
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
            padding: const EdgeInsets.all(AppSpacing.md),
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
