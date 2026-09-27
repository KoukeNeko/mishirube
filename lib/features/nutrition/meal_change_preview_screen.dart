import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_detail_screen.dart';
import 'meal_type_picker.dart';

/// What putting meals together, or taking one apart, will leave, shown
/// before it is done: the page closes with the choice, and the caller
/// makes the change.
///
/// Merging pops with a [MergeChoice]; splitting pops with true.
class MealChangePreviewScreen extends StatefulWidget {
  /// [items] as one meal, named [name], at [mealType] and [eatenAt] to
  /// start from; no later than [latest].
  const MealChangePreviewScreen.merge({
    super.key,
    required this.items,
    required this.convention,
    required this.eatenAt,
    required this.latest,
    this.name = '',
    this.mealType,
  }) : isMerge = true;

  /// [items], each a meal of its own again.
  const MealChangePreviewScreen.split({
    super.key,
    required this.items,
    required this.convention,
  }) : isMerge = false,
       name = '',
       mealType = null,
       eatenAt = null,
       latest = null;

  final List<MealEvent> items;
  final NutritionConvention convention;
  final bool isMerge;
  final String name;
  final MealType? mealType;
  final DateTime? eatenAt;
  final DateTime? latest;

  @override
  State<MealChangePreviewScreen> createState() =>
      _MealChangePreviewScreenState();
}

/// What a merge was agreed to with: the meal's name (blank for its
/// items'), its sitting, and when it was eaten.
typedef MergeChoice = ({String name, MealType? mealType, DateTime? eatenAt});

class _MealChangePreviewScreenState extends State<MealChangePreviewScreen> {
  late final _name = TextEditingController(text: widget.name)
    ..addListener(() => setState(() {}));
  late MealType? _mealType = widget.mealType;
  late DateTime? _eatenAt = widget.eatenAt;

  Future<void> _pickTime() async {
    final picked = await pickDateTime(
      context,
      initial: _eatenAt!,
      latest: widget.latest!,
    );
    if (picked == null || !mounted) return;
    setState(() => _eatenAt = picked);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = widget.items;
    return DetailPage(
      appBar: PageAppBar(
        title: widget.isMerge ? l10n.mergeIntoMeal : l10n.splitThisMeal,
      ),
      footer: PrimaryButton(
        label: widget.isMerge ? l10n.mergeAction : l10n.splitAction,
        onPressed: () => Navigator.of(context).pop(
          widget.isMerge
              ? (name: _name.text, mealType: _mealType, eatenAt: _eatenAt)
              : true,
        ),
      ),
      children: widget.isMerge ? _merged(l10n, items) : _split(l10n, items),
    );
  }

  /// The one meal: its name to set, its sum, and what it holds.
  List<Widget> _merged(AppLocalizations l10n, List<MealEvent> items) {
    final name = _name.text.trim();
    return [
      Gutter(child: SectionLabel(l10n.nameSection)),
      Gutter(
        child: AppTextField(controller: _name, hint: mealNameOf(items)),
      ),
      Gutter(
        child: SectionLabel(l10n.optionalField(field: l10n.mealTypeOptional)),
      ),
      Gutter(
        child: MealTypePicker(
          selected: _mealType,
          onChanged: (type) => setState(() => _mealType = type),
        ),
      ),
      if (_eatenAt case final eatenAt?)
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: l10n.timeSection,
                trailing: Text(
                  '${context.dates.date(eatenAt)} ${formatTimeOfDay(eatenAt)}',
                  style: AppTextStyles.caption,
                ),
                onTap: _pickTime,
              ),
            ],
          ),
        ),
      Gutter(child: SectionLabel(l10n.afterMerge)),
      Gutter(
        child: MealSummaryCard(
          meal: mealTotal(items, name: name.isEmpty ? null : name),
          convention: widget.convention,
          details: [
            ?_mealType?.labelIn(l10n),
            l10n.itemsCountShort(count: items.length),
          ],
        ),
      ),
      Gutter(child: SectionLabel(l10n.contentsSection)),
      Gutter(child: _Items(items: items)),
    ];
  }

  /// Each item on its own, as the day will list it.
  List<Widget> _split(AppLocalizations l10n, List<MealEvent> items) => [
    Gutter(
      child: SectionLabel(
        l10n.afterSplit,
        trailing: Text(
          l10n.mealsCount(count: items.length),
          style: AppTextStyles.caption,
        ),
      ),
    ),
    Gutter(child: _Items(items: items)),
  ];
}

/// Items as rows: the name, when, and the energy.
class _Items extends StatelessWidget {
  const _Items({required this.items});

  final List<MealEvent> items;

  @override
  Widget build(BuildContext context) => GroupedCard(
    children: [
      for (final item in items)
        NavRow(
          title: item.name,
          subtitle: item.timeLabel,
          trailing: Text(
            '${formatKcalOrDash(item.kcal)} kcal',
            style: AppTextStyles.caption,
          ),
          showChevron: false,
        ),
    ],
  );
}
