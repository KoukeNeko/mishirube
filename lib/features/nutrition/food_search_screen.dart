import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'food_edit_screen.dart';
import 'meal_entry_screen.dart';
import 'portion_screen.dart';
import 'quick_add_sheet.dart';
import 'recent_meal_row.dart';

/// Where a meal or a drink gets logged: search, or pick something eaten
/// before.
///
/// Search is the whole screen rather than one option among several.
/// Someone opening this already knows what they had; what they ate
/// recently is shown as the answer to a search they have not typed yet,
/// not as a separate feature. The other ways in — photo, voice, barcode
/// — sit one level down.
///
/// This is also the private layer of the food catalogue. There is no
/// shared database behind it yet, so the screen says so rather than
/// implying a search that came up empty was a search of everything.
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
    // A food comes back when the user asked to log it straight away.
    final created = await pushPage<FoodItem>(
      context,
      FoodEditScreen(initialName: _query.text.trim()),
    );
    if (!mounted) return;
    setState(() {});
    if (created != null) await _log(created);
  }

  Future<void> _edit(FoodItem food) async {
    await pushPage<FoodItem>(context, FoodEditScreen(editing: food));
    if (mounted) setState(() {});
  }

  Future<void> _log(FoodItem food) async {
    final sizes = AppStoreScope.read(context).sizesOf(food.id);
    // A size carries its own figures, so the one chosen is what gets
    // logged — not the food scaled up to it.
    final chosen = sizes.isEmpty ? food : await _pickSize(food, sizes);
    if (chosen == null || !mounted) return;
    final logged = await showPortionScreen(context, chosen);
    if (logged == null || !mounted) return;
    AppStoreScope.read(
      context,
    ).logPortion(logged.portion, mealType: logged.mealType);
    showToast(
      context,
      '已記錄「${chosen.displayName}」${logged.portion.label}',
      kind: ToastKind.success,
    );
    Navigator.of(context).pop();
  }

  Future<FoodItem?> _pickSize(FoodItem food, List<FoodItem> sizes) =>
      showModalBottomSheet<FoodItem>(
        context: context,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card),
          ),
        ),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.screenGutter),
                child: Text(food.displayName, style: AppTextStyles.pageTitle),
              ),
              for (final size in sizes)
                NavRow(
                  title: size.sizeName,
                  subtitle:
                      '${size.servingDescription} · '
                      '${size.valueType.write(formatKcalOrDash(size.kcal))}'
                      ' kcal',
                  onTap: () => Navigator.of(sheetContext).pop(size),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      );

  Future<void> _quickAdd() async {
    final logged = await showQuickAddSheet(context);
    if (logged != true || !mounted) return;
    showToast(context, '已記錄', kind: ToastKind.success);
    Navigator.of(context).pop();
  }

  void _logAgain(RecentMeal recent) {
    AppStoreScope.read(context).copyMeal(recent.meal);
    showToast(context, '已記錄「${recent.label}」', kind: ToastKind.success);
    Navigator.of(context).pop();
  }

  void _toggleFavorite(RecentMeal recent) {
    final isFavorite = !recent.meal.isFavorite;
    AppStoreScope.read(
      context,
    ).setMealFavorite(recent.meal, isFavorite: isFavorite);
    showToast(context, isFavorite ? '已加入常用' : '已從常用移除');
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
      appBar: const PageAppBar(title: '飲食', subtitle: '吃的和喝的'),
      footer: ButtonPair(
        secondary: SecondaryButton(label: '快速記錄', onPressed: _quickAdd),
        primaryFlex: 2,
        primary: SecondaryButton(
          label: '新增食物或飲品',
          onPressed: _create,
        ),
      ),
      children: [
        Gutter(
          child: SearchField(controller: _query, hint: '搜尋吃過或存過的⋯⋯'),
        ),
        // Before anything is typed, what was eaten before is the most
        // likely answer, so it goes first.
        if (query.isEmpty) ...[
          if (store.favoriteMeals case final favorites
              when favorites.isNotEmpty) ...[
            Gutter(child: const SectionLabel('常用')),
            for (final favorite in favorites)
              Gutter(
                child: RecentMealRow(
                  meal: favorite,
                  when: mealWhenLabel(context, favorite.eatenAt),
                  onAdd: () => _logAgain(favorite),
                  onToggleFavorite: () => _toggleFavorite(favorite),
                ),
              ),
          ],
          if (store.recentMeals case final recents when recents.isNotEmpty) ...[
            Gutter(child: const SectionLabel('最近')),
            for (final recent in recents)
              Gutter(
                child: RecentMealRow(
                  meal: recent,
                  when: mealWhenLabel(context, recent.eatenAt),
                  onAdd: () => _logAgain(recent),
                  onToggleFavorite: () => _toggleFavorite(recent),
                ),
              ),
          ],
        ],
        if (foods.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: query.isEmpty ? '還沒有存過東西' : '沒有符合的項目',
              message: query.isEmpty
                  ? '把常吃常喝的存起來，下次直接點一下就記好了。'
                  : '這裡只找你自己存過的，還沒有共用的食物資料庫。',
              action: PrimaryButton(label: '新增食物或飲品', onPressed: _create),
            ),
          )
        else
          // Drinks and food are listed apart: someone looking for a
          // coffee is not scrolling past the rice to find it.
          for (final kind in ConsumptionKind.values)
            if (foods.where((food) => food.kind == kind) case final group
                when group.isNotEmpty) ...[
              Gutter(
                child: SectionLabel(
                  kind == ConsumptionKind.unknown ? '你存過的' : kind.label,
                ),
              ),
              for (final food in group)
                Gutter(
                  child: _FoodRow(
                    food: food,
                    sizeCount: store.sizesOf(food.id).length,
                    onTap: () => _log(food),
                    onEdit: () => _edit(food),
                    onDelete: () => _delete(food),
                  ),
                ),
            ],
        if (query.isEmpty)
          Gutter(
            child: NavCard(
              title: '其他記錄方式',
              subtitle: '拍照、說出來、掃條碼、餐點模板',
              onTap: () => pushPage(context, const MealEntryScreen()),
            ),
          ),
      ],
    );
  }
}

/// A figure, or a dash where the food has none.
String _orDash(int? amount) => amount == null ? '—' : '$amount';

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.food,
    required this.sizeCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final FoodItem food;

  /// How many cup sizes it has; with any, tapping asks which one.
  final int sizeCount;

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
              subtitle: sizeCount > 0
                  ? '$sizeCount 種杯型'
                  : '${food.servingDescription} · '
                        '${food.valueType.write(formatKcalOrDash(food.kcal))}'
                        ' kcal · '
                        'P${_orDash(food.proteinGrams)} '
                        'C${_orDash(food.carbGrams)} F${_orDash(food.fatGrams)}',
              onTap: onTap,
            ),
          ),
          // Food that ships with the app has no edit or delete: the next
          // release replaces it, so a change here would not survive.
          if (!food.isBuiltIn) ...[
            SquareIconButton(icon: Icons.edit_outlined, onPressed: onEdit),
            const SizedBox(width: AppSpacing.xs),
            SquareIconButton(icon: Icons.delete_outline, onPressed: onDelete),
          ],
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
