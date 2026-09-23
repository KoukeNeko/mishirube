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
    subtitle:
        '一份 ${food.servingDescription} · '
        '${formatKcalOrDash(food.kcal?.round())} kcal',
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
          ? '$sizes 種杯型'
          : '一份 ${food.servingDescription} · '
                '${formatKcalOrDash(food.kcal?.round())} kcal',
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
    final brands = query.isEmpty
        ? [for (final catalogue in store.catalogues) catalogue.brand]
        : {
            ..._nutrition.brandsNamedBy(query),
            for (final food in found)
              if (food.isBuiltIn) food.brand,
          }.toList();
    return PageScaffold(
      appBar: const PageAppBar(title: '食物庫'),
      pinned: Gutter(
        child: SearchField(controller: _query, hint: '搜尋食物或品牌'),
      ),
      pinnedHeight: measurePinnedSearchHeight(),
      footer: BottomActionBar(
        child: PrimaryButton(label: '新增食物', onPressed: _create),
      ),
      children: [
        Gutter(child: const SectionLabel('自己的')),
        if (own.isEmpty)
          Gutter(
            child: Text(
              query.isEmpty ? '沒有自己的食物。' : '沒有符合的食物。',
              style: AppTextStyles.caption,
            ),
          ),
        for (final food in own) Gutter(child: _ownRow(food)),
        if (brands.isNotEmpty) ...[
          Gutter(child: const SectionLabel('內建品牌')),
          for (final brand in brands)
            Gutter(
              child: NavCard(
                title: brand,
                subtitle: '${_nutrition.menuOf(brand).length} 款 · 官方資料，唯讀',
                onTap: () => _openBrand(brand),
              ),
            ),
        ],
      ],
    );
  }
}
