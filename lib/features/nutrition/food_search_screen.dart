import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'brand_menu_screen.dart';
import 'food_edit_screen.dart';
import 'food_row.dart';
import 'meal_type_picker.dart';
import 'plate_screen.dart';
import 'portion_screen.dart';
import 'quick_add_sheet.dart';
import 'recent_meal_row.dart';

/// Which part of the list is showing. A scope narrows what is listed; it
/// is not a separate search, and typing searches within it.
enum _Scope {
  all('全部'),
  recent('最近'),
  starred('收藏'),
  own('自己的'),
  brands('品牌');

  const _Scope(this.label);

  final String label;
}

/// Where a meal or a drink gets logged: pick what was eaten onto a
/// plate, then log the plate.
///
/// Search is the whole screen rather than one tab among several: someone
/// opening this already knows what they had. A row of scopes narrows the
/// list without starting a second search; with nothing typed, 「全部」
/// shows a few recent and starred foods, the chains, then the user's own.
/// Once something is typed there is one ranked list, so a food never
/// appears twice. Chains are found by searching like anything else, and
/// naming one on its own offers its whole menu first.
///
/// Which meal this is sits in the title, since it is where everything on
/// the plate is going, not a filter on the list. Everything chosen goes
/// on one plate, logged together and undone together.
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
  /// How many recent or starred foods 「全部」 shows before the rest.
  static const _preview = 4;

  final _query = TextEditingController();

  /// What has been picked so far, in the order it was picked.
  final _plate = <FoodPortion>[];

  /// Which meal the plate is, for everything on it. Optional.
  MealType? _mealType;

  _Scope _scope = _Scope.all;

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

  Future<void> _pickMealType() async {
    final picked = await showMealTypeDialog(context, selected: _mealType);
    if (picked != null && mounted) setState(() => _mealType = picked.$1);
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

  bool _isOnPlate(FoodItem food) => _plate.any(
    (portion) => portion.food.id == food.id || portion.food.parentId == food.id,
  );

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

  void _remove(FoodItem food) => setState(
    () => _plate.removeWhere(
      (p) => p.food.id == food.id || p.food.parentId == food.id,
    ),
  );

  /// ＋ on a row: onto the plate at [last] — the portion last eaten, which
  /// for a drink with cups is also the cup — or at one serving. A drink
  /// never had from before has to have its cup chosen first.
  Future<void> _quickAddFood(FoodItem food, RecentFood? last) async {
    if (_isOnPlate(food)) {
      _remove(food);
      return;
    }
    if (last != null) {
      _add(last.portion);
      return;
    }
    if (AppStoreScope.read(context).sizesOf(food.id).isNotEmpty) {
      await _choose(food);
      return;
    }
    _add(FoodPortion(food, 1));
  }

  /// Tapping a row: choose the size and portion, then onto the plate.
  Future<void> _choose(FoodItem food, {RecentFood? last}) async {
    final sizes = AppStoreScope.read(context).sizesOf(food.id);
    // A size carries its own figures, so the one chosen is what gets
    // logged — not the food scaled up to it.
    final chosen = sizes.isEmpty ? food : await _pickSize(food, sizes);
    if (chosen == null || !mounted) return;
    final portion = await showPortionScreen(
      context,
      chosen,
      servings: last?.food.id == chosen.id ? last!.servings : 1,
    );
    if (!mounted) return;
    if (portion == null) {
      // The food may have been edited, starred or deleted meanwhile.
      setState(() {});
      return;
    }
    _add(portion);
  }

  /// Logs the plate and closes this page with every page it opened over
  /// itself — the plate review, a brand's menu.
  void _logPlate() {
    final store = AppStoreScope.read(context);
    final toast = ToastScope.read(context);
    final navigator = Navigator.of(context);
    final ownRoute = ModalRoute.of(context);
    final count = _plate.length;
    final logged = store.logPortions(List.of(_plate), mealType: _mealType);
    navigator
      ..popUntil((route) => route == ownRoute)
      ..pop();
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

  Widget? _plateBar() => _plate.isEmpty
      ? null
      : PlateBar(
          plate: _plate,
          mealType: _mealType,
          onReview: _reviewPlate,
          onLog: _logPlate,
        );

  Future<void> _openBrand(String brand) => pushPage<void>(
    context,
    BrandMenuScreen(
      brand: brand,
      // Every drink on a menu needs its cup chosen, so ＋ would only
      // repeat what tapping the row does.
      rowFor: (food, refresh) =>
          _row(food, onChanged: refresh, showsAdd: false),
      footer: _plateBar,
    ),
  );

  /// The row for [food], with what ＋ would add worked out from when it
  /// was last eaten. [onChanged] also rebuilds a page opened over this
  /// one, which a change to the plate would otherwise not reach.
  Widget _row(FoodItem food, {VoidCallback? onChanged, bool showsAdd = true}) {
    final store = AppStoreScope.read(context);
    final last = store.recentFoods
        .where((r) => r.food.id == food.id || r.food.parentId == food.id)
        .firstOrNull;
    return FoodRow(
      food: food,
      adds: last != null
          ? addsLastPortion(last.portion)
          : addsFirstPortion(food, sizeCount: store.sizesOf(food.id).length),
      isOnPlate: _isOnPlate(food),
      showsAdd: showsAdd,
      onTap: () async {
        await _choose(food, last: last);
        onChanged?.call();
      },
      onAdd: () async {
        await _quickAddFood(food, last);
        onChanged?.call();
      },
    );
  }

  /// Which cup: one row each, with its volume and the figure the chain
  /// actually published, in the app's own dialog rather than a system
  /// sheet.
  Future<FoodItem?> _pickSize(FoodItem food, List<FoodItem> sizes) =>
      showAppDialog<FoodItem>(
        context,
        AppDialog(
          title: food.name,
          message: food.brand.isEmpty ? null : food.brand,
          isChoiceList: true,
          actions: [
            for (final (index, size) in sizes.indexed)
              DialogAction(
                icon: _cupIcons[index.clamp(0, _cupIcons.length - 1)],
                label: size.sizeName,
                detail: _sizeDetail(size),
                onTap: () => Navigator.of(context).pop(size),
              ),
          ],
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
    return PageScaffold(
      appBar: PageAppBar(
        title: _mealType?.label ?? '飲食',
        subtitle: '吃的和喝的',
        actions: [
          HeaderAction(
            icon: Icons.expand_more,
            label: _mealType?.label ?? '餐次',
            semanticLabel: '這是哪一餐，目前${_mealType?.label ?? '不指定'}',
            onTap: _pickMealType,
          ),
        ],
      ),
      // Searching is the main job here, so the field stays pinned under
      // the bar the way the log's view switch does.
      pinned: Gutter(
        child: SearchField(controller: _query, hint: '搜尋，或打品牌名稱'),
      ),
      pinnedHeight: measurePinnedSearchHeight(),
      footer: switch (_plateBar()) {
        final bar? => BottomActionBar(child: bar),
        null => null,
      },
      children: [
        if (_mealType == null)
          if (store.suggestedMealType() case final offer?)
            Gutter(
              child: MealTypeOffer(
                offer: offer,
                onTake: () => setState(() => _mealType = offer),
              ),
            ),
        // Full-bleed: the chips scroll to the screen edge, so the row
        // pads its own content instead of taking a Gutter.
        SizedBox(
          height: pillHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
            ),
            itemCount: _Scope.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (_, index) {
              final scope = _Scope.values[index];
              return SelectChip(
                label: scope.label,
                isSelected: scope == _scope,
                onTap: () => setState(() => _scope = scope),
              );
            },
          ),
        ),
        ...query.isEmpty ? _browse(store) : _results(store, query),
      ],
    );
  }

  /// What shows before anything is typed, for the chosen scope.
  List<Widget> _browse(AppStore store) {
    final recent = store.recentFoods;
    final starred = store.favoriteFoods;
    final own = store.searchFoods('').where((food) => !food.isBuiltIn);
    return switch (_scope) {
      _Scope.all => [
        // The ways in that exist today. Photo, barcode and describing a
        // meal join this row when they are real, not before.
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
        ..._section('最近', [for (final r in recent.take(_preview)) r.food]),
        ..._section('收藏', starred.take(_preview).toList()),
        ..._brands(store),
        ..._section('自己的', own.toList()),
        if (recent.isEmpty && starred.isEmpty && own.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: '還沒有存過東西',
              message: '把常吃常喝的存起來，下次直接點一下就記好了。',
              action: PrimaryButton(label: '新增食物或飲品', onPressed: _create),
            ),
          ),
      ],
      _Scope.recent => [
        ..._section('吃過的食物', [for (final r in recent) r.food]),
        if (store.recentMeals case final meals when meals.isNotEmpty) ...[
          Gutter(child: const SectionLabel('最近的餐')),
          for (final meal in meals) Gutter(child: _mealRow(meal)),
        ],
        if (recent.isEmpty && store.recentMeals.isEmpty)
          Gutter(child: const InfoBanner(message: '還沒有最近吃過的東西。')),
      ],
      _Scope.starred => [
        ..._section('收藏的食物', starred),
        if (store.favoriteMeals case final meals when meals.isNotEmpty) ...[
          Gutter(child: const SectionLabel('收藏的餐')),
          for (final meal in meals) Gutter(child: _mealRow(meal)),
        ],
        if (starred.isEmpty && store.favoriteMeals.isEmpty)
          Gutter(child: const InfoBanner(message: '在食物的份量頁按右上的星號，它就會出現在這裡。')),
      ],
      _Scope.own => [
        ..._section('自己的', own.toList()),
        if (own.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: '還沒有自己存的食物',
              message: '存起來的食物只在這台裝置。',
              action: PrimaryButton(label: '新增食物或飲品', onPressed: _create),
            ),
          ),
      ],
      _Scope.brands => [
        ..._brands(store),
        if (store.catalogues.isEmpty)
          Gutter(child: const InfoBanner(message: '還沒有內建的連鎖品牌。')),
      ],
    };
  }

  /// One ranked list for what was typed, inside the chosen scope. A
  /// query naming a chain on its own offers the whole menu first.
  List<Widget> _results(AppStore store, String query) {
    final ids = switch (_scope) {
      _Scope.recent => {for (final r in store.recentFoods) r.food.id},
      _Scope.starred => {for (final f in store.favoriteFoods) f.id},
      _ => null,
    };
    final foods = [
      for (final food in store.searchFoods(query))
        if (switch (_scope) {
          _Scope.own => !food.isBuiltIn,
          _Scope.brands => food.isBuiltIn,
          _ => ids == null || ids.contains(food.id),
        })
          food,
    ];
    final brands = _scope == _Scope.all || _scope == _Scope.brands
        ? store.brandsNamedBy(query)
        : const <String>[];
    return [
      for (final brand in brands)
        Gutter(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: NavRow(
              title: '$brand · 查看完整菜單',
              subtitle: '${store.menuOf(brand).length} 款 · 官方資料',
              onTap: () => _openBrand(brand),
            ),
          ),
        ),
      for (final food in foods) Gutter(child: _row(food)),
      if (foods.isEmpty && brands.isEmpty)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.search_off,
            title: '沒有符合的項目',
            message: '這裡只找你自己存過的和內建的品牌，還沒有共用的食物資料庫。',
            action: PrimaryButton(label: '新增食物或飲品', onPressed: _create),
          ),
        )
      else
        Gutter(
          child: Row(
            children: [
              const Text('找不到？', style: AppTextStyles.caption),
              LinkText(label: '新增食物或飲品', onTap: _create),
            ],
          ),
        ),
    ];
  }

  List<Widget> _section(String label, List<FoodItem> foods) => [
    if (foods.isNotEmpty) ...[
      Gutter(child: SectionLabel(label)),
      for (final food in foods) Gutter(child: _row(food)),
    ],
  ];

  /// The chains whose menus ship with the app: one row each, however long
  /// the menu, so a chain never takes over the list.
  List<Widget> _brands(AppStore store) => [
    if (store.catalogues case final catalogues when catalogues.isNotEmpty) ...[
      Gutter(child: const SectionLabel('連鎖品牌')),
      for (final catalogue in catalogues)
        Gutter(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: NavRow(
              title: catalogue.brand,
              subtitle: [
                '${catalogue.products} 款',
                '官方資料',
                if (catalogue.checkedAt case final at?) '查證 ${formatDate(at)}',
              ].join(' · '),
              onTap: () => _openBrand(catalogue.brand),
            ),
          ),
        ),
    ],
  ];

  Widget _mealRow(RecentMeal meal) => RecentMealRow(
    meal: meal,
    when: mealWhenLabel(context, meal.eatenAt),
    onAdd: () => _logAgain(meal),
    onToggleFavorite: () => _toggleFavorite(meal),
  );
}

/// A cup per size, smallest first; sizes past the last share it.
const _cupIcons = [
  Icons.coffee_outlined,
  Icons.local_cafe_outlined,
  Icons.local_drink_outlined,
];

/// `354 ml · 咖啡因 150 mg`: the volume, then whichever figure the size
/// has — energy when it was published, caffeine when that is all there is.
String _sizeDetail(FoodItem size) {
  final caffeine = size.nutrients[Nutrient.caffeine];
  return [
    size.servingDescription,
    if (size.kcal != null)
      '${size.valueType.write(formatKcal(size.kcal!))} kcal'
    else if (caffeine != null)
      '咖啡因 ${size.valueType.write(formatAmount(caffeine))} mg',
  ].join(' · ');
}
