import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../training/workout_summary_screen.dart';
import 'month_calendar.dart';

enum _LogView { timeline, calendar }

enum _LogFilter {
  all('全部', null),
  training('訓練', RecordCategory.training),
  nutrition('飲食', RecordCategory.nutrition),
  body('身體', RecordCategory.body),
  wellness('睡眠與狀態', RecordCategory.wellness);

  const _LogFilter(this.label, this.category);

  final String label;
  final RecordCategory? category;

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

  /// First day of the month being browsed.
  DateTime _month = DateTime(mockToday.year, mockToday.month);
  int _selectedDay = mockToday.day;

  bool get _isCurrentMonth =>
      _month.year == mockToday.year && _month.month == mockToday.month;

  void _setMonth(DateTime month) {
    setState(() {
      _month = month;
      // Today in the current month; otherwise the month's first day.
      _selectedDay = _isCurrentMonth ? mockToday.day : 1;
    });
  }

  /// Opens the month wheels under [buttonContext]'s button.
  void _pickMonth(BuildContext buttonContext) {
    final box = buttonContext.findRenderObject()! as RenderBox;
    showMonthPopover(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      selected: _month,
      earliest: mockEarliestMonth,
      latest: DateTime(mockToday.year, mockToday.month),
      onChanged: _setMonth,
    );
  }

  void _openEntry(TimelineEntry entry) {
    final destination = switch (entry.category) {
      RecordCategory.training => const WorkoutSummaryScreen(),
      RecordCategory.nutrition => const DailyNutritionScreen(),
      _ => null,
    };
    if (destination == null) {
      showToast(context, '「${entry.title}」的詳細畫面尚未設計');
      return;
    }
    pushPage(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    return CollapsingPage(
      title: '紀錄',
      subtitle: '${_month.year} 年 ${_month.month} 月',
      compactBar: CompactBarBehavior.none,
      actions: [
        Builder(
          builder: (buttonContext) => HeaderAction(
            icon: Icons.calendar_month_outlined,
            label: '${_month.month}月',
            semanticLabel: '切換月份，目前 ${_month.year} 年 ${_month.month} 月',
            onTap: () => _pickMonth(buttonContext),
          ),
        ),
        HeaderAction(
          icon: Icons.search,
          semanticLabel: '搜尋紀錄',
          onTap: () => showToast(context, '紀錄搜尋尚未設計'),
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
      children: _view == _LogView.timeline ? _timeline() : _calendar(),
    );
  }

  List<Widget> _timeline() {
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
              isSelected: filter == _filter,
              onTap: () => setState(() => _filter = filter),
            );
          },
        ),
      ),
      if (_month == MockTimeline.recordMonth)
        for (final day in MockTimeline.days) ...[
          Gutter(child: _DayHeader(day: day)),
          for (final entry in day.entries.where(_filter.accepts))
            Gutter(
              child: _TimelineRow(entry: entry, onTap: () => _openEntry(entry)),
            ),
        ]
      else
        Gutter(
          child: EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: '${_month.month} 月沒有紀錄',
            message: '換一個月份看看，或從「+」新增一筆紀錄。',
          ),
        ),
    ];
  }

  List<Widget> _calendar() {
    final dotsByDay = MockTimeline.dotsIn(_month);
    final dots = dotsByDay[_selectedDay] ?? const [];
    return [
      Gutter(
        child: MonthCalendar(
          month: _month,
          selectedDay: _selectedDay,
          today: mockToday,
          dotsByDay: dotsByDay,
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
      if (dots.isEmpty)
        Gutter(child: const InfoBanner(message: '這天沒有紀錄。'))
      else
        for (final category in dots)
          Gutter(child: _DaySummaryRow(category: category)),
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
        for (final category in const [
          RecordCategory.training,
          RecordCategory.nutrition,
          RecordCategory.body,
        ])
          CategoryLabel(label: category.label, color: category.color),
      ],
    );
  }
}

class _DaySummaryRow extends StatelessWidget {
  const _DaySummaryRow({required this.category});

  final RecordCategory category;

  String get _summary => switch (category) {
    RecordCategory.training => '下肢 A · 16 組',
    RecordCategory.nutrition => '3 餐 · ~1,960 kcal',
    RecordCategory.body => '72.4 kg',
    RecordCategory.wellness => '精力 3 / 5',
  };

  @override
  Widget build(BuildContext context) {
    return AccentRow(
      color: category.color,
      title: category.label,
      trailing: _summary,
    );
  }
}
