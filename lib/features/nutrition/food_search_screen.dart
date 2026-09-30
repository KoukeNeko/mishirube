import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/food_portion.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'brand_menu_screen.dart';
import 'daily_nutrition_screen.dart';
import 'meal_detail_screen.dart';
import 'describe_meal_screen.dart';
import 'food_edit_screen.dart';
import 'food_row.dart';
import 'meal_type_picker.dart';
import 'nutrition_view_model.dart';
import 'plate_screen.dart';
import 'portion_screen.dart';
import 'recent_meal_row.dart';
import '../../l10n/l10n.dart';

/// Which part of the list is showing. A scope narrows what is listed; it
/// is not a separate search, and typing searches within it.
enum _Scope {
  all(Icons.apps),
  recent(Icons.history),
  starred(Icons.star_outline),
  own(Icons.person_outline),
  brands(Icons.storefront_outlined);

  const _Scope(this.icon);

  final IconData icon;

  String labelIn(AppLocalizations l10n) => switch (this) {
    all => l10n.foodScopeAll,
    recent => l10n.foodScopeRecent,
    starred => l10n.foodScopeStarred,
    own => l10n.foodScopeOwn,
    brands => l10n.foodScopeBrands,
  };
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
  const FoodSearchScreen({super.key, this.day});

  /// The day what is picked here goes to; today when null.
  final DateTime? day;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  late final NutritionViewModel _nutrition;

  /// When what is picked here was eaten: now on today, and on another
  /// day at this time of day, which the meal's editor can change. Null
  /// for now, read when it is logged.
  DateTime? get _at {
    final day = widget.day;
    if (day == null) return null;
    final now = _nutrition.now();
    if (day.year == now.year && day.month == now.month && day.day == now.day) {
      return null;
    }
    return DateTime(day.year, day.month, day.day, now.hour, now.minute);
  }

  /// How many recent or starred foods 「全部」 shows before the rest.
  static const _preview = 4;

  /// How many recent meals 「全部」 offers to log again.
  static const _mealPreview = 3;

  /// How many more of what was eaten 「最近」 lists each time the end of
  /// the list comes into sight.
  static const _recentPage = 30;

  final _query = TextEditingController();

  /// What has been picked so far, in the order it was picked.
  final _plate = <FoodPortion>[];

  /// Which model read each food's figures, by food id: what is logged
  /// from here then says so on the record.
  final _drafted = <String, (AiProviderKind, String)>{};

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

  _Scope _scope = _Scope.all;

  /// How much of what was eaten 「最近」 lists so far: foods first, then,
  /// once every food is listed, meals, as far back as the log goes.
  int _recentShown = _recentPage;

  /// What 「最近」 lists within [_recentShown], and whether there is more.
  ({List<RecentFood> foods, List<RecentMeal> meals, bool hasMore}) _recentUpTo(
    int shown,
  ) {
    final foods = _nutrition.recentFoodsUpTo(shown + 1);
    if (foods.length > shown) {
      return (foods: foods.take(shown).toList(), meals: [], hasMore: true);
    }
    final room = shown - foods.length;
    final meals = _nutrition.recentMealsUpTo(room + 1);
    return (
      foods: foods,
      meals: meals.take(room).toList(),
      hasMore: meals.length > room,
    );
  }

  /// Lists the next page of 「最近」 once its end is near.
  bool _onScroll(ScrollNotification notification) {
    if (_scope == _Scope.recent &&
        _query.text.trim().isEmpty &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 600 &&
        _recentUpTo(_recentShown).hasMore) {
      setState(() => _recentShown += _recentPage);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final store = AppStoreScope.read(context);
    _nutrition = NutritionViewModel(store.backend);
    _mealType = _nutrition.suggestedMealType();
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
    // A food comes back when the user asked to log it straight away,
    // along with the model that read its figures when one did.
    final created = await pushPage<FoodEdit>(
      context,
      FoodEditScreen(initialName: _query.text.trim()),
    );
    if (!mounted) return;
    setState(() {});
    if (created == null) return;
    if (created.draftedBy case final draftedBy?) {
      _drafted[created.food.id] = draftedBy;
    }
    await _choose(created.food);
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
    final logged = _nutrition.logPortions(
      List.of(_plate),
      mealType: _mealType,
      at: _at,
      draftedByOf: (portion) => _drafted[portion.food.id],
    );
    navigator
      ..popUntil((route) => route == ownRoute)
      ..pop();
    toast.showUndo(
      count == 1
          ? context.l10n.loggedNamed(name: logged.single.name)
          : context.l10n.loggedItemsCount(count: count),
      onUndo: () => _nutrition.deleteMeals(logged),
      onTap: () => _openLogged(AppStoreScope.read(context), logged),
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
          ? addsLastPortion(context.l10n, last.portion)
          : addsFirstPortion(context.l10n, food, sizeCount: sizeCount),
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

  /// A meal drafted by the AI from a photo, words or both, and confirmed
  /// on its own page; once it is logged, this page closes too and offers
  /// the undo, as a plate does.
  Future<void> _describe() async {
    final toast = ToastScope.read(context);
    final logged = await pushPage<List<MealEvent>>(
      context,
      DescribeMealScreen(mealType: _mealType, at: _at),
    );
    if (logged == null || logged.isEmpty || !mounted) return;
    Navigator.of(context).pop();
    toast.showUndo(
      logged.length == 1
          ? context.l10n.loggedNamed(name: logged.single.name)
          : context.l10n.loggedItemsCount(count: logged.length),
      onUndo: () => _nutrition.deleteMeals(logged),
      onTap: () => _openLogged(AppStoreScope.read(context), logged),
    );
  }

  Future<void> _quickAdd() async {
    final logged = await pushPage<MealEvent>(
      context,
      FoodEditScreen(initialName: _query.text.trim(), logsOnce: true, at: _at),
    );
    if (logged == null || !mounted) return;
    showToast(
      context,
      context.l10n.loggedToast,
      kind: ToastKind.success,
      onTap: () =>
          AppStoreScope.read(context)
              .openFromChrome(MealDetailScreen(meal: logged)),
    );
  }

  /// Where a toast after logging goes: the meal itself when one was
  /// logged, the day when several were.
  void _openLogged(AppStore store, List<MealEvent> logged) =>
      store.openFromChrome(
        logged.length == 1
            ? MealDetailScreen(meal: logged.single)
            : DailyNutritionScreen(day: _at),
      );

  void _logAgain(RecentMeal recent) {
    final logged = _nutrition.copyMeal(recent.meal, at: _at);
    ToastScope.read(context).showUndo(
      context.l10n.loggedNamed(name: recent.label),
      onUndo: () => _nutrition.deleteMeals([logged]),
      onTap: () =>
          AppStoreScope.read(context)
              .openFromChrome(MealDetailScreen(meal: logged)),
    );
  }

  void _toggleFavorite(RecentMeal recent) {
    final isFavorite = !recent.meal.isFavorite;
    _nutrition.setMealFavorite(recent.meal, isFavorite: isFavorite);
    showToast(
      context,
      isFavorite ? context.l10n.favoriteAdded : context.l10n.favoriteRemoved,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: _page(context),
    ),
  );

  Widget _page(BuildContext context) {
    final store = AppStoreScope.of(context);
    final query = _query.text.trim();
    return PageScaffold(
      appBar: PageAppBar(
        title: _mealType?.labelIn(context.l10n) ?? context.l10n.moduleNutrition,
        actions: [
          HeaderAction(
            icon: Icons.expand_more,
            label:
                _mealType?.labelIn(context.l10n) ??
                context.l10n.mealTypeOptional,
            semanticLabel: context.l10n.mealTypeHeaderLabel(
              meal:
                  _mealType?.labelIn(context.l10n) ?? context.l10n.unspecified,
            ),
            onTap: _pickMealType,
          ),
        ],
      ),
      // Searching is the main job here, so the field stays pinned under
      // the bar the way the log's view switch does.
      pinned: Gutter(
        child: SearchField(
          controller: _query,
          hint: context.l10n.searchFoodHint,
        ),
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
          labelOf: (scope) => scope.labelIn(context.l10n),
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
        // The quickest ways in lead: a photo, words or both for the AI to
        // draft, numbers typed once, or a whole meal eaten before.
        Gutter(
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              _WayIn(
                icon: Icons.auto_awesome_outlined,
                label: context.l10n.aiDraftAction,
                onTap: _describe,
              ),
              _WayIn(
                icon: Icons.edit_note_outlined,
                label: context.l10n.qualityQuickLog,
                onTap: _quickAdd,
              ),
            ],
          ),
        ),
        // A whole meal eaten before is the fastest record there is.
        if (_nutrition.recentMeals.take(_mealPreview).toList() case final meals
            when meals.isNotEmpty) ...[
          Gutter(child: SectionLabel(context.l10n.recentMealsSection)),
          for (final meal in meals) Gutter(child: _mealRow(meal)),
        ],
        ..._section(
          context.l10n.foodScopeRecent,
          [for (final r in recent.take(_preview)) r.food],
          // The rest is under 「最近」, which goes as far back as the log.
          more: recent.length > _preview
              ? () => setState(() => _scope = _Scope.recent)
              : null,
        ),
        ..._section(
          context.l10n.foodScopeStarred,
          starred.take(_preview).toList(),
        ),
        // Chains are found by typing their name or under 「品牌」, not
        // listed here: they are browsed rarely, and 「全部」 is for what the
        // user eats.
        ..._section(context.l10n.foodScopeOwn, own.toList()),
        if (recent.isEmpty && starred.isEmpty && own.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: context.l10n.noFoods,
              action: PrimaryButton(
                label: context.l10n.newFood,
                onPressed: _create,
              ),
            ),
          ),
      ],
      _Scope.recent => switch (_recentUpTo(_recentShown)) {
        (:final foods, :final meals, hasMore: _) => [
          ..._section(context.l10n.eatenFoods, [for (final r in foods) r.food]),
          if (meals.isNotEmpty) ...[
            Gutter(child: SectionLabel(context.l10n.recentMealsSection)),
            for (final meal in meals) Gutter(child: _mealRow(meal)),
          ],
          if (foods.isEmpty && meals.isEmpty)
            Gutter(child: InfoBanner(message: context.l10n.noRecentFoods)),
        ],
      },
      _Scope.starred => [
        ..._section(context.l10n.starredFoods, starred),
        if (_nutrition.favoriteMeals case final meals
            when meals.isNotEmpty) ...[
          Gutter(child: SectionLabel(context.l10n.starredMeals)),
          for (final meal in meals) Gutter(child: _mealRow(meal)),
        ],
        if (starred.isEmpty && _nutrition.favoriteMeals.isEmpty)
          Gutter(child: InfoBanner(message: context.l10n.noFavorites)),
      ],
      _Scope.own => [
        ..._section(context.l10n.foodScopeOwn, own.toList()),
        if (own.isEmpty)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.restaurant_outlined,
              title: context.l10n.noOwnFoods,
              action: PrimaryButton(
                label: context.l10n.newFood,
                onPressed: _create,
              ),
            ),
          ),
      ],
      _Scope.brands => [
        ..._brands(store),
        if (store.catalogues.isEmpty)
          Gutter(child: InfoBanner(message: context.l10n.noBuiltInBrands)),
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
      for (final food in _nutrition.searchFoods(
        query,
        includePackaged: _scope == _Scope.all,
      ))
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
    final labels = {
      for (final catalogue in AppStoreScope.of(context).catalogues)
        catalogue.brand: catalogue.labelIn(context.l10n),
    };
    return [
      for (final brand in brands)
        Gutter(
          child: NavCard(
            title: context.l10n.viewFullMenu(brand: labels[brand] ?? brand),
            subtitle:
                '${context.l10n.productsCount(count: _nutrition.menuOf(brand).length)}'
                ' · ${context.l10n.officialData}',
            onTap: () => _openBrand(brand),
          ),
        ),
      for (final food in foods) Gutter(child: _row(food)),
      if (foods.isEmpty && brands.isEmpty)
        Gutter(
          child: EmptyStateCard(
            icon: Icons.search_off,
            title: context.l10n.noMatchingItems,
            action: PrimaryButton(
              label: context.l10n.newFood,
              onPressed: _create,
            ),
          ),
        )
      else
        Gutter(
          child: Row(
            children: [
              Text(context.l10n.notFoundQuestion, style: AppTextStyles.caption),
              LinkText(label: context.l10n.newFood, onTap: _create),
            ],
          ),
        ),
    ];
  }

  /// A labelled list of [foods]; [more] opens the rest of them.
  List<Widget> _section(
    String label,
    List<FoodItem> foods, {
    VoidCallback? more,
  }) => [
    if (foods.isNotEmpty) ...[
      Gutter(
        child: SectionLabel(
          label,
          trailing: more == null
              ? null
              : LinkText(
                  label: context.l10n.moreAction,
                  color: AppColors.nutrition,
                  alignment: Alignment.bottomRight,
                  onTap: more,
                ),
        ),
      ),
      for (final food in foods) Gutter(child: _row(food)),
    ],
  ];

  /// The chains whose menus ship with the app: one row each, however long
  /// the menu, so a chain never takes over the list.
  List<Widget> _brands(AppStore store) => [
    // By country: the same chain sells different things in each.
    for (final country in {
      for (final catalogue in store.catalogues) catalogue.country,
    }) ...[
      Gutter(child: SectionLabel(countryName(context.l10n, country))),
      for (final catalogue in store.catalogues.where(
        (catalogue) => catalogue.country == country,
      ))
        Gutter(
          child: NavCard(
            title: catalogue.labelIn(context.l10n),
            subtitle: [
              '${context.l10n.productsCount(count: catalogue.products)} · '
                  '${context.l10n.officialData}',
              if (catalogue.checkedAt case final at?)
                context.l10n.updatedOn(date: context.dates.date(at)),
            ].join('\n'),
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
