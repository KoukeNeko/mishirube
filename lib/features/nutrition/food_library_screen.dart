import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'brand_menu_screen.dart';
import 'food_edit_screen.dart';
import 'nutrition_view_model.dart';
import 'portion_screen.dart';
import '../../l10n/l10n.dart';

/// Every food the app knows, for looking after rather than logging: the
/// user's own, to add and correct, and the chains that ship with the
/// app, to browse. The exercise library's counterpart under 我的.
class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({super.key});

  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen> {
  late final NutritionViewModel _nutrition;
  final _query = TextEditingController();

  /// What the list shows: everything, the user's own foods, or one
  /// country's chains — [_all], [_own] or a country code.
  String _scope = _all;
  static const _all = '';
  static const _own = 'own';

  /// A brand's menu opened from here browses; nothing goes on a plate.
  static final _noPlate = Listenable.merge(const []);

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _nutrition.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    await pushPage<FoodEdit>(
      context,
      FoodEditScreen(initialName: _query.text.trim()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(FoodItem food) async {
    await pushPage<FoodEdit>(context, FoodEditScreen(editing: food));
    if (mounted) setState(() {});
  }

  Future<void> _openBrand(String brand) => pushPage<void>(
    context,
    BrandMenuScreen(
      brand: brand,
      rowFor: (food, _) => _catalogueRow(food),
      footer: () => null,
      plateChanges: _noPlate,
    ),
  );

  Widget _ownRow(FoodItem food) => NavCard(
    title: food.displayName,
    subtitle: context.l10n.servingAndKcal(
      serving: food.servingDescription(context.l10n),
      kcal: formatKcalOrDash(food.kcal?.round()),
    ),
    onTap: () => _edit(food),
  );

  /// A shipped drink is read-only: it opens on its figures, after the cup
  /// when it comes in sizes, with nothing to add it to.
  Future<void> _openCatalogueFood(FoodItem food) async {
    final sizes = _nutrition.sizesOf(food.id);
    final chosen = sizes.isEmpty
        ? food
        : await pickCupSize(context, food, sizes);
    if (chosen == null || !mounted) return;
    await pushPage<void>(context, PortionScreen(food: chosen, canAdd: false));
  }

  Widget _catalogueRow(FoodItem food) {
    final sizes = _nutrition.sizesOf(food.id).length;
    return NavCard(
      title: food.name,
      subtitle: sizes > 0
          ? context.l10n.foodCupSizes(count: sizes)
          : context.l10n.servingAndKcal(
              serving: food.servingDescription(context.l10n),
              kcal: formatKcalOrDash(food.kcal?.round()),
            ),
      onTap: () => _openCatalogueFood(food),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final store = AppStoreScope.of(context);
    final query = _query.text.trim();
    final found = _nutrition.searchFoods(query).where((food) => !food.isSize);
    final own = found.where((food) => !food.isBuiltIn).toList();
    final countryOf = {
      for (final catalogue in store.catalogues)
        catalogue.brand: catalogue.country,
    };
    final labels = {
      for (final catalogue in store.catalogues)
        catalogue.brand: catalogue.labelIn(context.l10n),
    };
    final brands = query.isEmpty
        ? [for (final catalogue in store.catalogues) catalogue.brand]
        : {
            ..._nutrition.brandsNamedBy(query),
            for (final food in found)
              if (food.isBuiltIn) food.brand,
          }.toList();
    // The same chain sells different things in each country, so its
    // brands are looked for by country first.
    final countries = {
      for (final catalogue in store.catalogues) catalogue.country,
    };
    return PageScaffold(
      appBar: PageAppBar(title: context.l10n.foodLibrary),
      pinned: Column(
        children: [
          Gutter(
            child: SearchField(
              controller: _query,
              hint: context.l10n.searchFoodHint,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilterChipBar<String>(
            options: [_all, _own, ...countries],
            selected: _scope,
            labelOf: (scope) => switch (scope) {
              _all => context.l10n.foodScopeAll,
              _own => context.l10n.foodScopeOwn,
              final country => countryName(context.l10n, country),
            },
            onSelected: (scope) => setState(() => _scope = scope),
          ),
        ],
      ),
      pinnedHeight:
          measurePinnedSearchHeight() + AppSpacing.xs + pillHeight(context),
      footer: BottomActionBar(
        child: PrimaryButton(label: context.l10n.newFood, onPressed: _create),
      ),
      children: [
        if (_scope == _all || _scope == _own) ...[
          Gutter(child: SectionLabel(context.l10n.foodScopeOwn)),
          if (own.isEmpty)
            Gutter(
              child: Text(
                query.isEmpty
                    ? context.l10n.noOwnFoodsSentence
                    : context.l10n.noMatchingFoods,
                style: AppTextStyles.caption,
              ),
            ),
          for (final food in own) Gutter(child: _ownRow(food)),
        ],
        for (final country in countries)
          if (_scope == _all || _scope == country)
            if (brands.where((brand) => countryOf[brand] == country).toList()
                case final inCountry when inCountry.isNotEmpty) ...[
              Gutter(child: SectionLabel(countryName(context.l10n, country))),
              for (final brand in inCountry)
                Gutter(
                  child: NavCard(
                    title: labels[brand] ?? brand,
                    subtitle:
                        '${context.l10n.productsCount(count: _nutrition.menuOf(brand).length)}'
                        ' · ${context.l10n.officialReadOnly}',
                    onTap: () => _openBrand(brand),
                  ),
                ),
            ],
      ],
    );
  }
}
