import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'brand_menu_screen.dart';
import 'food_edit_screen.dart';

/// Every food the app knows, for looking after rather than logging: the
/// user's own, to add and correct, and the chains that ship with the
/// app, to browse. The exercise library's counterpart under 我的.
class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({super.key});

  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen> {
  final _query = TextEditingController();

  /// A brand's menu opened from here browses; nothing goes on a plate.
  static final _noPlate = Listenable.merge(const []);

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

  Future<void> _openBrand(String brand) => pushPage<void>(
    context,
    BrandMenuScreen(
      brand: brand,
      rowFor: (food, _) => _catalogueRow(food),
      footer: () => null,
      plateChanges: _noPlate,
    ),
  );

  Widget _ownRow(FoodItem food) => AppCard(
    padding: EdgeInsets.zero,
    child: NavRow(
      title: food.displayName,
      subtitle:
          '一份 ${food.servingDescription} · '
          '${formatKcalOrDash(food.kcal)} kcal',
      onTap: () => _edit(food),
    ),
  );

  /// A shipped drink is read-only, so its row says what it has.
  Widget _catalogueRow(FoodItem food) {
    final sizes = AppStoreScope.read(context).sizesOf(food.id).length;
    return AppCard(
      padding: EdgeInsets.zero,
      child: NavRow(
        title: food.name,
        subtitle: sizes > 0
            ? '$sizes 種杯型'
            : '一份 ${food.servingDescription} · '
                  '${formatKcalOrDash(food.kcal)} kcal',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final query = _query.text.trim();
    final found = store.searchFoods(query).where((food) => !food.isSize);
    final own = found.where((food) => !food.isBuiltIn).toList();
    final brands = query.isEmpty
        ? [for (final catalogue in store.catalogues) catalogue.brand]
        : {
            ...store.brandsNamedBy(query),
            for (final food in found)
              if (food.isBuiltIn) food.brand,
          }.toList();
    return PageScaffold(
      appBar: const PageAppBar(title: '食物庫', subtitle: '自己的食物與內建品牌'),
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
              query.isEmpty ? '還沒有自己存的食物。' : '沒有符合的食物。',
              style: AppTextStyles.caption,
            ),
          ),
        for (final food in own) Gutter(child: _ownRow(food)),
        if (brands.isNotEmpty) ...[
          Gutter(child: const SectionLabel('內建品牌')),
          for (final brand in brands)
            Gutter(
              child: AppCard(
                padding: EdgeInsets.zero,
                child: NavRow(
                  title: brand,
                  subtitle: '${store.menuOf(brand).length} 款 · 官方資料，唯讀',
                  onTap: () => _openBrand(brand),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
