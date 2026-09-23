import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_type_picker.dart';

/// Logs something once without saving it as a food.
///
/// For the things nobody plans to eat again — a colleague's birthday
/// cake, a stall on holiday. Saving every one of those would fill the
/// list with entries that are never picked twice, and a list like that
/// is slower to search, not richer.
Future<bool?> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carb = TextEditingController();
  final _fat = TextEditingController();
  MealType? _mealType;

  bool get _canLog => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final field in [_name, _kcal, _protein, _carb, _fat]) {
      field.dispose();
    }
    super.dispose();
  }

  static int? _valueOf(TextEditingController field) =>
      int.tryParse(field.text.trim());

  void _log() {
    final store = AppStoreScope.read(context);
    store.logMeal(
      MealEvent(
        id: store.newFoodId(),
        name: _name.text.trim(),
        timeLabel: '',
        qualityTag: '快速記錄',
        dishes: const [],
        kcal: _valueOf(_kcal),
        proteinGrams: _valueOf(_protein),
        carbGrams: _valueOf(_carb),
        fatGrams: _valueOf(_fat),
        mealType: _mealType,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('快速記錄', style: AppTextStyles.pageTitle),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: _name, hint: '名稱', autofocus: true),
          const SizedBox(height: AppSpacing.md),
          _Field(label: MacroLabel.energy, unit: 'kcal', field: _kcal),
          _Field(label: MacroLabel.protein, unit: 'g', field: _protein),
          _Field(label: MacroLabel.carb, unit: 'g', field: _carb),
          _Field(label: MacroLabel.fat, unit: 'g', field: _fat),
          const SizedBox(height: AppSpacing.lg),
          Text('餐次（選填）', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          MealTypePicker(
            selected: _mealType,
            suggested: AppStoreScope.of(context).suggestedMealType(),
            onChanged: (type) => setState(() => _mealType = type),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: '記錄', onPressed: _canLog ? _log : null),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.unit, required this.field});

  final String label;
  final String unit;
  final TextEditingController field;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          SizedBox(
            width: 120,
            child: AppTextField(
              controller: field,
              hint: '—',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(width: 36, child: Text(unit, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}
