import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'food_edit_screen.dart';
import 'portion_sheet.dart';

/// The user's own foods: search them, log one, or save a new one.
///
/// This is the private layer of the food catalogue. There is no shared
/// database behind it yet, so the screen says so rather than implying a
/// search that came up empty was a search of everything.
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    await pushPage<FoodItem>(
      context,
      FoodEditScreen(initialName: _query.text.trim()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(FoodItem food) async {
    await pushPage<FoodItem>(context, FoodEditScreen(editing: food));
    if (mounted) setState(() {});
  }

  Future<void> _log(FoodItem food) async {
    final portion = await showPortionSheet(context, food);
    if (portion == null || !mounted) return;
    AppStoreScope.read(context).logPortion(portion);
    showToast(
      context,
      '已記錄「${food.displayName}」${portion.label}',
      kind: ToastKind.success,
    );
    Navigator.of(context).pop();
  }

  void _delete(FoodItem food) {
    final store = AppStoreScope.read(context);
    store.deleteFood(food.id);
    setState(() {});
    ToastScope.read(context).showUndo(
      '已刪除「${food.displayName}」',
      onUndo: () {
        store.undeleteFood(food.id);
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final query = _query.text.trim();
    final foods = store.searchFoods(query);
    return DetailPage(
      appBar: const PageAppBar(title: '食物', subtitle: '你自己存的食物'),
      footer: SecondaryButton(label: '新增食物', onPressed: _create),
      children: [
        Gutter(
          child: SearchField(controller: _query, hint: '搜尋你存過的食物⋯⋯'),
        ),
        if (foods.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: query.isEmpty ? '還沒有存過食物' : '沒有符合的食物',
              message: query.isEmpty
                  ? '把常吃的東西存起來，下次直接點一下就記好了。'
                  : '這裡只找你自己存過的食物，還沒有共用的食物資料庫。',
              action: PrimaryButton(label: '新增食物', onPressed: _create),
            ),
          )
        else
          for (final food in foods)
            Gutter(
              child: _FoodRow(
                food: food,
                onTap: () => _log(food),
                onEdit: () => _edit(food),
                onDelete: () => _delete(food),
              ),
            ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.food,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final FoodItem food;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: NavRow(
              title: food.displayName,
              subtitle:
                  '${food.servingLabel} · ${food.kcal} kcal · '
                  'P${food.proteinGrams} C${food.carbGrams} F${food.fatGrams}',
              onTap: onTap,
            ),
          ),
          SquareIconButton(icon: Icons.edit_outlined, onPressed: onEdit),
          const SizedBox(width: AppSpacing.xs),
          SquareIconButton(icon: Icons.delete_outline, onPressed: onDelete),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
