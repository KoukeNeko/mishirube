import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../shared/widgets/widgets.dart';
import 'create_exercise_screen.dart';
import 'exercise_detail_screen.dart';
import 'exercise_filter.dart';
import 'exercise_filter_screen.dart';

const _maxSuggestions = 3;
const _fuzzyTermLength = 2;

/// Search field (56) plus the pinned row's vertical padding.
const _searchRowHeight = 72.0;

enum _PickerTab {
  recent('最近使用'),
  favorites('收藏'),
  homeGym('本健身房'),
  all('所有動作');

  const _PickerTab(this.label);

  final String label;

  bool includes(ExerciseDefinition exercise) => switch (this) {
    _PickerTab.recent => exercise.lastUsedDaysAgo != null,
    _PickerTab.favorites => exercise.isFavorite,
    _PickerTab.homeGym => exercise.isInHomeGym,
    _PickerTab.all => true,
  };
}

/// Multi-select exercise picker; pops with the chosen exercises in order.
class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({
    super.key,
    required this.targetName,
    this.isTemplate = false,
  });

  final String targetName;
  final bool isTemplate;

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _searchController = TextEditingController();
  final List<ExerciseDefinition> _selected = [];
  final List<ExerciseDefinition> _customExercises = [];
  _PickerTab _tab = _PickerTab.recent;
  ExerciseFilter _filter = ExerciseFilter.defaultForLowerBody;

  String get _query => _searchController.text.trim();

  List<ExerciseDefinition> get _catalog => [
    ...MockExercises.catalog,
    ..._customExercises,
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExerciseDefinition> _visibleExercises() {
    // A search looks through everything, not only the current tab.
    final tab = _query.isEmpty ? _tab : _PickerTab.all;
    final results = _catalog
        .where(
          (exercise) =>
              tab.includes(exercise) &&
              _filter.matches(exercise) &&
              exercise.matchesQuery(_query),
        )
        .toList();
    if (tab == _PickerTab.recent) {
      results.sort((a, b) => a.lastUsedDaysAgo!.compareTo(b.lastUsedDaysAgo!));
    }
    return results;
  }

  List<ExerciseDefinition> _suggestionsIgnoringFilters() {
    final direct = _catalog.where((e) => e.matchesQuery(_query)).toList();
    final fuzzyTerms = [
      for (var i = 0; i + _fuzzyTermLength <= _query.length; i++)
        _query.substring(i, i + _fuzzyTermLength),
    ];
    final fuzzy = _catalog.where(
      (e) => !direct.contains(e) && fuzzyTerms.any(e.matchesQuery),
    );
    return [...direct, ...fuzzy].take(_maxSuggestions).toList();
  }

  void _toggle(ExerciseDefinition exercise) => setState(() {
    if (!_selected.remove(exercise)) _selected.add(exercise);
  });

  Future<void> _openFilter() async {
    final filter = await pushModalPage<ExerciseFilter>(
      context,
      ExerciseFilterScreen(initial: _filter),
    );
    if (filter != null) setState(() => _filter = filter);
  }

  Future<void> _openDetail(ExerciseDefinition exercise) async {
    final shouldAdd = await pushPage<bool>(
      context,
      ExerciseDetailScreen(exercise: exercise, canAdd: true),
    );
    if (shouldAdd == true && !_selected.contains(exercise)) _toggle(exercise);
  }

  Future<void> _createExercise({String initialName = ''}) async {
    final created = await pushModalPage<ExerciseDefinition>(
      context,
      CreateExerciseScreen(initialName: initialName),
    );
    if (created == null) return;
    setState(() {
      if (!_catalog.contains(created)) _customExercises.add(created);
      if (!_selected.contains(created)) _selected.add(created);
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _visibleExercises();
    final action = widget.isTemplate ? '加入訓練模板' : '加入進行中的';
    return PageScaffold(
      appBar: PageAppBar(
        title: '新增動作',
        subtitle: '$action「${widget.targetName}」',
        leading: AppBarLeading.none,
        onClose: () => Navigator.of(context).pop(),
      ),
      // Searching is the main job here, so the search row stays pinned.
      pinned: Gutter(
        child: _SearchRow(
          controller: _searchController,
          filterCount: _filter.activeCount,
          onFilter: _openFilter,
        ),
      ),
      pinnedHeight: _searchRowHeight,
      footer: _selected.isNotEmpty
          ? _SelectionTray(
              selected: _selected,
              onRemove: _toggle,
              onConfirm: () => Navigator.of(context).pop(_selected),
            )
          : null,
      children: [
        // Full-bleed like the Log chips: the tab row pads its own content.
        if (_query.isEmpty) _TabRow(selected: _tab, onSelect: _selectTab),
        if (!_filter.isEmpty)
          Gutter(
            child: _FilterSummary(
              summary: _filter.summary,
              onClear: () => setState(() => _filter = const ExerciseFilter()),
            ),
          ),
        if (exercises.isEmpty)
          Gutter(
            child: _NoResults(
              query: _query,
              filter: _filter,
              suggestions: _suggestionsIgnoringFilters(),
              onClearEquipment: () =>
                  setState(() => _filter = _filter.copyWith(equipment: {})),
              onOpenSuggestion: _openDetail,
              onCreate: () => _createExercise(initialName: _query),
            ),
          )
        else ...[
          for (final exercise in exercises)
            Gutter(
              child: _ExerciseTile(
                exercise: exercise,
                order: _selected.indexOf(exercise) + 1,
                onTap: () => _toggle(exercise),
                onInfo: () => _openDetail(exercise),
              ),
            ),
          Gutter(
            child: DashedActionCard(
              label: '找不到？建立自訂動作',
              onTap: _createExercise,
            ),
          ),
        ],
      ],
    );
  }

  void _selectTab(_PickerTab tab) => setState(() => _tab = tab);
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.filterCount,
    required this.onFilter,
  });

  final TextEditingController controller;
  final int filterCount;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(child: SearchField(controller: controller)),
          const SizedBox(width: AppSpacing.sm),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            backgroundColor: AppColors.training,
            textColor: AppColors.onTraining,
            child: SquareIconButton(
              icon: Icons.filter_list,
              tooltip: '篩選',
              size: 56,
              onPressed: onFilter,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.selected, required this.onSelect});

  final _PickerTab selected;
  final ValueChanged<_PickerTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: pillHeight(context) + AppSpacing.sm * 2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenGutter,
          vertical: AppSpacing.sm,
        ),
        itemCount: _PickerTab.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, index) {
          final tab = _PickerTab.values[index];
          return SelectChip(
            label: tab.label,
            isSelected: tab == selected,
            onTap: () => onSelect(tab),
          );
        },
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.summary, required this.onClear});

  final String summary;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          const Text('篩選  ', style: AppTextStyles.caption),
          Expanded(
            child: Text(
              summary,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          LinkText(label: '清除', color: AppColors.textSecondary, onTap: onClear),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({
    required this.exercise,
    required this.order,
    required this.onTap,
    required this.onInfo,
  });

  /// 1-based position in the selection, or 0 when not selected.
  final int order;
  final ExerciseDefinition exercise;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final isSelected = order > 0;
    final lastUsed = exercise.lastPerformance == null
        ? '尚未做過'
        : '${exercise.lastPerformance} · ${exercise.lastUsedDaysAgo} 天前';
    return Semantics(
      selected: isSelected,
      child: AppCard(
        tone: isSelected ? CardTone.training : CardTone.neutral,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _OrderBadge(order: order),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          exercise.name,
                          style: AppTextStyles.itemTitle,
                        ),
                      ),
                      if (exercise.isFavorite) ...const [
                        SizedBox(width: AppSpacing.xxs),
                        Icon(
                          Icons.star_border,
                          size: 16,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${exercise.equipment.label} · ${exercise.muscleSummary}',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    lastUsed,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            SquareIconButton(
              icon: Icons.info_outline,
              tooltip: '${exercise.name}說明',
              size: 40,
              onPressed: onInfo,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order});

  static const _size = 30.0;

  final int order;

  @override
  Widget build(BuildContext context) {
    final isSelected = order > 0;
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.training : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.small - 4),
        border: Border.all(
          color: isSelected ? AppColors.training : AppColors.textTertiary,
          width: 2,
        ),
      ),
      child: isSelected
          ? Text(
              '$order',
              style: const TextStyle(
                color: AppColors.onTraining,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class _SelectionTray extends StatelessWidget {
  const _SelectionTray({
    required this.selected,
    required this.onRemove,
    required this.onConfirm,
  });

  final List<ExerciseDefinition> selected;
  final ValueChanged<ExerciseDefinition> onRemove;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return BottomActionBar(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('加入順序 · 點一下可移除', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < selected.length; i++)
                ChipButton(
                  label: '${i + 1}  ${selected[i].name}',
                  tone: TagTone.training,
                  semanticLabel: '移除第 ${i + 1} 個：${selected[i].name}',
                  onTap: () => onRemove(selected[i]),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: '加入 ${selected.length} 個動作',
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.query,
    required this.filter,
    required this.suggestions,
    required this.onClearEquipment,
    required this.onOpenSuggestion,
    required this.onCreate,
  });

  final String query;
  final ExerciseFilter filter;
  final List<ExerciseDefinition> suggestions;
  final VoidCallback onClearEquipment;
  final ValueChanged<ExerciseDefinition> onOpenSuggestion;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final hasEquipmentFilter = filter.equipment.isNotEmpty;
    final equipmentLabel = filter.equipment.map((e) => e.label).join('、');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        EmptyStateCard(
          icon: Icons.search,
          title: '沒有符合的動作',
          message: hasEquipmentFilter
              ? '目前套用了「器材：$equipmentLabel」，你要找的動作可能是另一種器材。'
              : '換個說法、英文名稱或別名再試一次。',
          action: hasEquipmentFilter
              ? PrimaryButton(
                  label: '移除器材篩選再找一次',
                  isCompact: true,
                  onPressed: onClearEquipment,
                )
              : null,
        ),
        if (suggestions.isNotEmpty) const SectionLabel('你可能是在找'),
        for (final exercise in suggestions)
          AccentRow(
            color: AppColors.training,
            title: exercise.name,
            subtitle: '${exercise.equipment.label} · ${exercise.muscleSummary}',
            showChevron: true,
            onTap: () => onOpenSuggestion(exercise),
          ),
        DashedActionCard(
          label: query.isEmpty ? '建立自訂動作' : '建立「$query」',
          onTap: onCreate,
        ),
        const Center(
          child: Text('搜尋支援中文、英文與別名。離線也能找。', style: AppTextStyles.caption),
        ),
      ],
    );
  }
}
