import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../backend/engines/nutrition_summary.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'brand_menu_screen.dart';
import 'camera_screen.dart';
import 'daily_nutrition_screen.dart';
import 'describe_meal_screen.dart';
import 'food_edit_screen.dart';
import 'food_row.dart';
import 'meal_type_picker.dart';
import 'nutrition_view_model.dart';
import 'plate_screen.dart';
import 'portion_screen.dart';
import 'recent_meal_row.dart';
import 'water_card.dart';

/// Which part of the list is showing. A scope narrows what is listed; it
/// is not a separate search, and typing searches within it.
enum _Scope {
  all('全部', Icons.apps),
  recent('最近', Icons.history),
  starred('收藏', Icons.star_outline),
  own('自己的', Icons.person_outline),
  brands('品牌', Icons.storefront_outlined);

  const _Scope(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Where a meal or a drink gets logged: pick what was eaten onto a
/// plate, then log the plate.
///
/// Search is the whole screen rather than one tab among several: someone
/// opening this already knows what they had. A row of scopes narrows the
/// list without starting a second search; with nothing typed, 「全部」
/// shows a few recent and starred foods, then the user's own.
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
  late final NutritionViewModel _nutrition;

  /// How many recent or starred foods 「全部」 shows before the rest.
  static const _preview = 4;

  /// How many recent meals 「全部」 offers to log again.
  static const _mealPreview = 3;

  final _query = TextEditingController();

  /// What has been picked so far, in the order it was picked.
  final _plate = <FoodPortion>[];

  /// Ticks whenever the plate changes, so a brand's menu opened over this
  /// page — which this page's rebuilds never reach — shows it too.
  final _plateChanges = ValueNotifier(0);

  void _changePlate(VoidCallback change) {
    // An undo on the plate page can come after this page logged and
    // closed; there is nothing left to show it on then.
    if (!mounted) return;
    setState(change);
    _plateChanges.value++;
  }

  void _plateChanged() => _changePlate(() {});

  /// Which meal the plate is, for everything on it: the one the hour
  /// suggests to begin with, changed from the header. Optional.
  MealType? _mealType;

  /// Whether the chosen AI can read a food photo; the camera is offered
  /// only then.
  late final Future<bool> _readsPhotos;

  _Scope _scope = _Scope.all;

  @override
  void initState() {
    super.initState();
    final store = AppStoreScope.read(context);
    _nutrition = NutritionViewModel(store.backend);
    _mealType = _nutrition.suggestedMealType();
    _readsPhotos = store.aiProvider == null
        ? Future.value(false)
        : store.readsFoodPhotos();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _plateChanges.dispose();
    _nutrition.dispose();
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
    _changePlate(() {
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

  /// Tapping a row: choose the size and portion, then onto the plate.
  Future<void> _choose(FoodItem food, {RecentFood? last}) async {
    final sizes = _nutrition.sizesOf(food.id);
    // A size carries its own figures, so the one chosen is what gets
    // logged — not the food scaled up to it.
    final chosen = sizes.isEmpty
        ? food
        : await pickCupSize(context, food, sizes);
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
    final toast = ToastScope.read(context);
    final navigator = Navigator.of(context);
    final ownRoute = ModalRoute.of(context);
    final count = _plate.length;
    final logged = _nutrition.logPortions(List.of(_plate), mealType: _mealType);
    navigator
      ..popUntil((route) => route == ownRoute)
      ..pop();
    toast.showUndo(
      count == 1 ? '已記錄「${logged.single.name}」' : '已記錄 $count 項',
      onUndo: () => _nutrition.deleteMeals(logged),
    );
  }

  Future<void> _reviewPlate() => pushPage<void>(
    context,
    PlateScreen(plate: _plate, onChanged: _plateChanged, onLog: _logPlate),
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
      rowFor: (food, refresh) => _row(food, onChanged: refresh),
      footer: _plateBar,
      plateChanges: _plateChanges,
    ),
  );

  /// The row for [food], with the portion it opens at worked out from when it
  /// was last eaten. [onChanged] also rebuilds a page opened over this
  /// one, which a change to the plate would otherwise not reach.
  Widget _row(FoodItem food, {VoidCallback? onChanged}) {
    final last = _nutrition.recentFoods
        .where((r) => r.food.id == food.id || r.food.parentId == food.id)
        .firstOrNull;
    final sizeCount = _nutrition.sizesOf(food.id).length;
    // The portion the row's last line names: the last one eaten, or a
    // serving of a food without cup sizes to choose from.
    final quick = last != null
        ? last.portion
        : sizeCount == 0
        ? FoodPortion(food, 1)
        : null;
    return FoodRow(
      food: food,
      adds: last != null
          ? addsLastPortion(last.portion)
          : addsFirstPortion(food, sizeCount: sizeCount),
      isOnPlate: _isOnPlate(food),
      onTap: () async {
        await _choose(food, last: last);
        onChanged?.call();
      },
      onQuickAdd: quick == null
          ? null
          : () {
              _add(quick);
              onChanged?.call();
            },
    );
  }

  /// A meal drafted by the AI and confirmed on its own page; once it is
  /// logged, this page closes too and offers the undo, as a plate does.
  Future<void> _describe({String? photoPath}) async {
    final toast = ToastScope.read(context);
    final logged = await pushPage<List<MealEvent>>(
      context,
      DescribeMealScreen(mealType: _mealType, photoPath: photoPath),
    );
    if (logged == null || logged.isEmpty || !mounted) return;
    Navigator.of(context).pop();
    toast.showUndo(
      logged.length == 1
          ? '已記錄「${logged.single.name}」'
          : '已記錄 ${logged.length} 項',
      onUndo: () => _nutrition.deleteMeals(logged),
    );
  }

  /// A photo of the meal, drafted item by item on the draft page.
  Future<void> _photo() async {
    final path = await takePhoto(context, '食物', maxSide: foodPhotoMaxSide);
    if (path == null || !mounted) return;
    await _describe(photoPath: path);
  }

  Future<void> _quickAdd() async {
    final logged = await pushPage<FoodItem>(
      context,
      FoodEditScreen(initialName: _query.text.trim(), logsOnce: true),
    );
    if (logged == null || !mounted) return;
    showToast(context, '已記錄', kind: ToastKind.success);
  }

  void _logAgain(RecentMeal recent) {
    final logged = _nutrition.copyMeal(recent.meal);
    ToastScope.read(context).showUndo(
      '已記錄「${recent.label}」',
      onUndo: () => _nutrition.deleteMeals([logged]),
    );
  }

  void _toggleFavorite(RecentMeal recent) {
    final isFavorite = !recent.meal.isFavorite;
    _nutrition.setMealFavorite(recent.meal, isFavorite: isFavorite);
    showToast(context, isFavorite ? '已加入收藏' : '已取消收藏');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final store = AppStoreScope.of(context);
    final query = _query.text.trim();
    return PageScaffold(
      appBar: PageAppBar(
        title: _mealType?.label ?? '飲食',
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
        child: SearchField(controller: _query, hint: '搜尋食物或品牌'),
      ),
      pinnedHeight: measurePinnedSearchHeight(),
      footer: switch (_plateBar()) {
        final bar? => BottomActionBar(child: bar),
        null => null,
      },
      children: [
        FilterChipBar<_Scope>(
          options: _Scope.values,
          selected: _scope,
          labelOf: (scope) => scope.label,
          iconOf: (scope) => scope.icon,
          onSelected: (scope) => setState(() => _scope = scope),
        ),
        ...query.isEmpty ? _browse(store) : _results(store, query),
      ],
    );
  }

  /// What shows before anything is typed, for the chosen scope.
  List<Widget> _browse(AppStore store) {
    final recent = _nutrition.recentFoods;
    final starred = _nutrition.favoriteFoods;
    final own = _nutrition.searchFoods('').where((food) => !food.isBuiltIn);
    return switch (_scope) {
      _Scope.all => [
        // The quickest ways in lead: a photo or a sentence for the AI to
        // draft, numbers typed once, or a whole meal eaten before. The
        // day and water follow; water also has its own place under ＋.
        Gutter(
          child: FutureBuilder(
            future: _readsPhotos,
            builder: (context, readsPhotos) => Row(
              spacing: AppSpacing.sm,
              children: [
                if (readsPhotos.data ?? false)
                  _WayIn(
                    icon: Icons.photo_camera_outlined,
                    label: '拍照',
                    onTap: _photo,
                  ),
                _WayIn(
                  icon: Icons.auto_awesome_outlined,
                  label: '一句話',
                  onTap: _describe,
                ),
                _WayIn(
                  icon: Icons.edit_note_outlined,
                  label: '快速記錄',
                  onTap: _quickAdd,
                ),
              ],
            ),
          ),
        ),
        // A whole meal eaten before is the fastest record there is.
        if (_nutrition.recentMeals.take(_mealPreview).toList() case final meals
            when meals.isNotEmpty) ...[
          Gutter(child: const SectionLabel('近期用餐')),
          for (final meal in meals) Gutter(child: _mealRow(meal)),
        ],
        // What is already logged today, one tap away: this page is
        // opened from ＋, not from the day, and the question before
        // logging is often whether breakfast is in yet.
        Gutter(
          child: NavCard(
            title: '今天',
            subtitle: switch (store.todaySummary) {
              DaySummary(recordCount: 0) => '沒有紀錄',
              final day => '${day.mealCount} 餐 · ${formatKcal(day.kcal)} kcal',
            },
            onTap: () => pushPage(context, const DailyNutritionScreen()),
          ),
        ),
        // Water gets a card of its own: it is the most repeated record
        // there is, logged in one tap and never through the plate.
        Gutter(
          child: WaterCard(
            onOpenDay: () => pushPage(context, const DailyNutritionScreen()),
          ),
        ),
        ..._section('最近', [for (final r in recent.take(_preview)) r.food]),
        ..._section('收藏', starred.take(_preview).toList()),
        // Chains are found by typing their name or under 「品牌」, not
        // listed here: they are browsed rarely, and 「全部」 is for what the
        // user eats.
        ..._section('自己的', own.toList()),
        if (recent.isEmpty && starred.isEmpty && own.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: '沒有食物',
              action: PrimaryButton(label: '新增食物', onPressed: _create),
            ),
          ),
      ],
      _Scope.recent => [
        ..._section('吃過的食物', [for (final r in recent) r.food]),
        if (_nutrition.recentMeals case final meals when meals.isNotEmpty) ...[
          Gutter(child: const SectionLabel('近期用餐')),
          for (final meal in meals) Gutter(child: _mealRow(meal)),
        ],
        if (recent.isEmpty && _nutrition.recentMeals.isEmpty)
          Gutter(child: const InfoBanner(message: '沒有最近吃過的食物。')),
      ],
      _Scope.starred => [
        ..._section('收藏的食物', starred),
        if (_nutrition.favoriteMeals case final meals
            when meals.isNotEmpty) ...[
          Gutter(child: const SectionLabel('收藏的餐')),
          for (final meal in meals) Gutter(child: _mealRow(meal)),
        ],
        if (starred.isEmpty && _nutrition.favoriteMeals.isEmpty)
          Gutter(child: const InfoBanner(message: '沒有收藏。')),
      ],
      _Scope.own => [
        ..._section('自己的', own.toList()),
        if (own.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: '沒有自己的食物',
              action: PrimaryButton(label: '新增食物', onPressed: _create),
            ),
          ),
      ],
      _Scope.brands => [
        ..._brands(store),
        if (store.catalogues.isEmpty)
          Gutter(child: const InfoBanner(message: '沒有內建的連鎖品牌。')),
      ],
    };
  }

  /// One ranked list for what was typed, inside the chosen scope. A
  /// query naming a chain on its own offers the whole menu first.
  List<Widget> _results(AppStore store, String query) {
    final ids = switch (_scope) {
      _Scope.recent => {for (final r in _nutrition.recentFoods) r.food.id},
      _Scope.starred => {for (final f in _nutrition.favoriteFoods) f.id},
      _ => null,
    };
    final foods = [
      for (final food in _nutrition.searchFoods(query))
        if (switch (_scope) {
          _Scope.own => !food.isBuiltIn,
          _Scope.brands => food.isBuiltIn,
          _ => ids == null || ids.contains(food.id),
        })
          food,
    ];
    final brands = _scope == _Scope.all || _scope == _Scope.brands
        ? _nutrition.brandsNamedBy(query)
        : const <String>[];
    return [
      for (final brand in brands)
        Gutter(
          child: NavCard(
            title: '$brand · 查看完整菜單',
            subtitle: '${_nutrition.menuOf(brand).length} 款 · 官方資料',
            onTap: () => _openBrand(brand),
          ),
        ),
      for (final food in foods) Gutter(child: _row(food)),
      if (foods.isEmpty && brands.isEmpty)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.search_off,
            title: '沒有符合的項目',
            action: PrimaryButton(label: '新增食物', onPressed: _create),
          ),
        )
      else
        Gutter(
          child: Row(
            children: [
              const Text('找不到？', style: AppTextStyles.caption),
              LinkText(label: '新增食物', onTap: _create),
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
          child: NavCard(
            title: catalogue.brand,
            subtitle: [
              '${catalogue.products} 款',
              '官方資料',
              if (catalogue.checkedAt case final at?) '查證 ${formatDate(at)}',
            ].join(' · '),
            onTap: () => _openBrand(catalogue.brand),
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

/// One way of logging besides picking foods: an icon over its name, a
/// third of the row each.
class _WayIn extends StatelessWidget {
  const _WayIn({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: AppColors.nutrition),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: AppTextStyles.itemTitle),
          ],
        ),
      ),
    );
  }
}
