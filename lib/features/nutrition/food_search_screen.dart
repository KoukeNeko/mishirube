import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'food_edit_screen.dart';
import 'meal_type_picker.dart';
import 'plate_screen.dart';
import 'portion_screen.dart';
import 'quick_add_sheet.dart';
import 'recent_meal_row.dart';

/// Where a meal or a drink gets logged: pick what was eaten onto a
/// plate, then log the plate.
///
/// Search is the whole screen rather than one tab among several: someone
/// opening this already knows what they had, and what they ate recently
/// is shown as the answer to a search they have not typed yet. Recent
/// lists foods, each once at the portion last eaten, so ＋ is usually
/// the whole job; tapping the row opens the portion first. Everything
/// chosen goes on one plate, logged together under one meal label and
/// undone together.
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

  /// What has been picked so far, in the order it was picked.
  final _plate = <FoodPortion>[];

  /// Which meal the plate is, for everything on it. Optional.
  MealType? _mealType;

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
    if (created != null) await _choose(created);
  }

  bool _isOnPlate(FoodItem food) =>
      _plate.any((portion) => portion.food.id == food.id);

  /// Puts [portion] on the plate. The same food twice is one line with
  /// more of it: two taps on the egg are two eggs, not two records of
  /// one egg each that only look alike.
  void _add(FoodPortion portion) {
    setState(() {
      final index = _plate.indexWhere((p) => p.food.id == portion.food.id);
      if (index < 0) {
        _plate.add(portion);
      } else {
        _plate[index] = FoodPortion(
          portion.food,
          _plate[index].servings + portion.servings,
        );
      }
    });
  }

  void _remove(FoodItem food) =>
      setState(() => _plate.removeWhere((p) => p.food.id == food.id));

  /// ＋ on a row: straight onto the plate at the usual portion, unless
  /// the food has cup sizes, which have to be chosen first.
  Future<void> _quickAddFood(FoodItem food, double servings) async {
    if (_isOnPlate(food)) {
      _remove(food);
      return;
    }
    if (AppStoreScope.read(context).sizesOf(food.id).isNotEmpty) {
      await _choose(food, servings: servings);
      return;
    }
    _add(FoodPortion(food, servings));
  }

  /// Tapping a row: choose the size and portion, then onto the plate.
  Future<void> _choose(FoodItem food, {double servings = 1}) async {
    final sizes = AppStoreScope.read(context).sizesOf(food.id);
    // A size carries its own figures, so the one chosen is what gets
    // logged — not the food scaled up to it.
    final chosen = sizes.isEmpty ? food : await _pickSize(food, sizes);
    if (chosen == null || !mounted) return;
    final portion = await showPortionScreen(
      context,
      chosen,
      servings: servings,
    );
    if (!mounted) return;
    if (portion == null) {
      // The food may have been edited or deleted from the portion page.
      setState(() {});
      return;
    }
    _add(portion);
  }

  void _logPlate() {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    final count = _plate.length;
    final logged = store.logPortions(List.of(_plate), mealType: _mealType);
    Navigator.of(context).pop();
    toast.showUndo(
      count == 1 ? '已記錄「${logged.single.name}」' : '已記錄 $count 項',
      onUndo: () => store.deleteMeals(logged),
    );
  }

  Future<void> _reviewPlate() => pushPage<void>(
    context,
    PlateScreen(
      plate: _plate,
      onChanged: () => setState(() {}),
      onLog: _logPlate,
    ),
  );

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

  void _logWater() {
    final store = AppStoreScope.read(context);
    final logged = store.logWater();
    showToast(
      context,
      '已記錄 ${logged.millilitres} mL 水',
      kind: ToastKind.success,
    );
  }

  Future<void> _setGlass() async {
    final store = AppStoreScope.read(context);
    final typed = await showTextDialog(
      context,
      title: '一杯是多少毫升',
      initial: '${store.glassMillilitres}',
      confirmLabel: '好',
    );
    final millilitres = int.tryParse(typed?.trim() ?? '');
    if (millilitres == null || millilitres <= 0 || !mounted) return;
    store.setGlassMillilitres(millilitres);
  }

  Future<void> _quickAdd() async {
    final logged = await showQuickAddSheet(context);
    if (logged != true || !mounted) return;
    showToast(context, '已記錄', kind: ToastKind.success);
  }

  void _logAgain(RecentMeal recent) {
    AppStoreScope.read(context).copyMeal(recent.meal);
    showToast(context, '已記錄「${recent.label}」', kind: ToastKind.success);
  }

  void _toggleFavorite(RecentMeal recent) {
    final isFavorite = !recent.meal.isFavorite;
    AppStoreScope.read(context)
        .setMealFavorite(recent.meal, isFavorite: isFavorite);
    showToast(context, isFavorite ? '已加入常用' : '已從常用移除');
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final query = _query.text.trim();
    final recentFoods = store.recentFoods;
    final lastServings = {
      for (final recent in recentFoods) recent.food.id: recent.servings,
    };
    final foods = store.searchFoods(query);
    return DetailPage(
      appBar: const PageAppBar(title: '飲食', subtitle: '吃的和喝的'),
      footer: _plate.isEmpty
          ? null
          : _PlateBar(plate: _plate, onReview: _reviewPlate, onLog: _logPlate),
      children: [
        Gutter(
          child: MealTypePicker(
            selected: _mealType,
            suggested: store.suggestedMealType(),
            onChanged: (type) => setState(() => _mealType = type),
          ),
        ),
        Gutter(
          child: SearchField(controller: _query, hint: '搜尋吃過或存過的⋯⋯'),
        ),
        // The ways in that exist today. Photo, barcode and describing a
        // meal join this row when they are real, not before.
        if (query.isEmpty)
          Gutter(
            child: Row(
              children: [
                // Water is the most repeated record there is, so it gets
                // one tap and skips the plate.
                Expanded(
                  child: SecondaryButton(
                    label: '水 ${store.glassMillilitres} mL',
                    onPressed: _logWater,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SquareIconButton(
                  icon: Icons.tune,
                  tooltip: '改一杯的量',
                  onPressed: _setGlass,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: SecondaryButton(label: '快速記錄', onPressed: _quickAdd),
                ),
              ],
            ),
          ),
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
          if (recentFoods.isNotEmpty) ...[
            Gutter(child: const SectionLabel('最近')),
            for (final recent in recentFoods)
              Gutter(
                child: _FoodRow(
                  food: recent.food,
                  subtitle: [
                    '上次 ${recent.portion.label}',
                    ?recent.mealType?.label,
                  ].join(' · '),
                  isOnPlate: _isOnPlate(recent.food),
                  onTap: () => _choose(recent.food, servings: recent.servings),
                  onAdd: () => _quickAddFood(recent.food, recent.servings),
                ),
              ),
          ],
          if (store.recentMeals case final meals when meals.isNotEmpty) ...[
            Gutter(child: const SectionLabel('最近的餐')),
            for (final recent in meals)
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
        else ...[
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
                    subtitle: _describe(food, store.sizesOf(food.id).length),
                    isOnPlate: _isOnPlate(food),
                    onTap: () =>
                        _choose(food, servings: lastServings[food.id] ?? 1),
                    onAdd: () =>
                        _quickAddFood(food, lastServings[food.id] ?? 1),
                  ),
                ),
            ],
          Gutter(
            child: Row(
              children: [
                const Text('找不到？', style: AppTextStyles.caption),
                LinkText(label: '新增食物或飲品', onTap: _create),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// What a food is, when it is not a recent one: its serving and figures,
/// or how many cup sizes it comes in.
String _describe(FoodItem food, int sizeCount) => sizeCount > 0
    ? '$sizeCount 種杯型'
    : '${food.servingDescription} · '
          '${food.valueType.write(formatKcalOrDash(food.kcal))} kcal · '
          'P${_orDash(food.proteinGrams)} '
          'C${_orDash(food.carbGrams)} F${_orDash(food.fatGrams)}';

/// The plate so far, and the one action that matters: log it.
class _PlateBar extends StatelessWidget {
  const _PlateBar({
    required this.plate,
    required this.onReview,
    required this.onLog,
  });

  final List<FoodPortion> plate;
  final VoidCallback onReview;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return ButtonPair(
      secondary: SecondaryButton(
        label: '${plate.length} 項 · ${plateKcalLabel(plate)} kcal',
        onPressed: onReview,
      ),
      primaryFlex: 2,
      primary: PrimaryButton(label: '記錄 ${plate.length} 項', onPressed: onLog),
    );
  }
}

/// A figure, or a dash where the food has none.
String _orDash(int? amount) => amount == null ? '—' : '$amount';

/// One food: tap to choose the portion, ＋ to put it on the plate at the
/// usual one. On the plate, the ＋ becomes a check that takes it off.
class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.food,
    required this.subtitle,
    required this.isOnPlate,
    required this.onTap,
    required this.onAdd,
  });

  final FoodItem food;
  final String subtitle;
  final bool isOnPlate;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: NavRow(
              title: food.displayName,
              subtitle: subtitle,
              onTap: onTap,
            ),
          ),
          Semantics(
            selected: isOnPlate,
            child: SquareIconButton(
              icon: isOnPlate ? Icons.check : Icons.add,
              tooltip: isOnPlate
                  ? '從這一餐拿掉「${food.displayName}」'
                  : '加入「${food.displayName}」',
              onPressed: onAdd,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
