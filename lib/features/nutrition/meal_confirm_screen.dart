import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/seed/demo_content.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'component_list.dart';
import 'daily_nutrition_screen.dart';

const _baseEstimateKcal = 620;
const _estimateRangeKcal = 80;

/// Macros of the inferred meal, part of the same estimate as its energy.
const _estimatedProteinGrams = 36;
const _estimatedCarbGrams = 68;
const _estimatedFatGrams = 21;

enum _MayoAmount {
  little('少量', -40, '~8 g'),
  normal('一般', 0, '~12 g'),
  more('多一點', 45, '~18 g');

  const _MayoAmount(this.label, this.kcalDelta, this.amountLabel);

  final String label;
  final int kcalDelta;

  /// What the component reads as once this amount is confirmed.
  final String amountLabel;
}

enum _ChickenAmount {
  small('85 g', -25, '85 g'),
  regular('100 g', 0, '100 g'),
  // Left as the range it was inferred as: an unsure answer is not a value.
  unsure('不確定', 0, null);

  const _ChickenAmount(this.label, this.kcalDelta, this.amountLabel);

  final String label;
  final int kcalDelta;
  final String? amountLabel;
}

/// An inferred meal the user confirms before anything is stored.
///
/// There is no vision model yet, so the draft is fixed demo content; what
/// is real is the flow around it: ranges stay ranges until the user
/// answers, and the meal reaches the records only on confirmation.
class MealConfirmScreen extends StatefulWidget {
  const MealConfirmScreen({super.key});

  @override
  State<MealConfirmScreen> createState() => _MealConfirmScreenState();
}

class _MealConfirmScreenState extends State<MealConfirmScreen> {
  _MayoAmount _mayo = _MayoAmount.normal;
  _ChickenAmount? _chicken;

  int get _estimate =>
      _baseEstimateKcal + _mayo.kcalDelta + (_chicken?.kcalDelta ?? 0);

  /// The inferred components with the user's answers filled in; what they
  /// did not answer keeps the range it was guessed as.
  List<FoodComponent> get _confirmedComponents => [
    for (final component in DemoNutrition.sandwichComponents)
      switch (component.name) {
        '美乃滋' => FoodComponent(
          name: component.name,
          amountLabel: _mayo.amountLabel,
          source: component.source,
        ),
        '照燒雞腿肉' when _chicken?.amountLabel != null => FoodComponent(
          name: component.name,
          amountLabel: _chicken!.amountLabel!,
          source: component.source,
        ),
        _ => component,
      },
  ];

  /// Nothing is stored until this runs: the inference alone is a draft.
  void _confirm() {
    final store = AppStoreScope.read(context);
    final isExact = _chicken != null && _chicken != _ChickenAmount.unsure;
    store.logMeal(
      MealEvent(
        id: 'lunch',
        name: '午餐',
        timeLabel: formatTimeOfDay(store.now()),
        kcal: _estimate,
        qualityTag: isExact ? '已確認' : '份量為估計',
        isEstimated: !isExact,
        proteinGrams: _estimatedProteinGrams,
        carbGrams: _estimatedCarbGrams,
        fatGrams: _estimatedFatGrams,
        dishes: [
          DishEntry(
            name: DemoNutrition.sandwich.name,
            quantityLabel: DemoNutrition.sandwich.quantityLabel,
            subtitle: DemoNutrition.sandwich.subtitle,
            components: _confirmedComponents,
          ),
        ],
      ),
    );
    replaceWithPage(context, const DailyNutritionScreen());
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      appBar: const PageAppBar(title: '確認這一餐', subtitle: '由照片推測 · 尚未存入'),
      footer: BottomActionBar(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatBlock(
                  value: '~$_estimate',
                  label: '估計熱量',
                  valueStyle: AppTextStyles.hugeNumber,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '可能範圍 ${_estimate - _estimateRangeKcal} – '
                    '${_estimate + _estimateRangeKcal} kcal',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            NutritionButton(label: '確認並存入', onPressed: _confirm),
          ],
        ),
      ),
      children: [
        Gutter(child: const _PhotoPlaceholder()),
        Gutter(
          child: const InfoBanner(
            tone: CardTone.nutrition,
            message: '以下是推測結果，份量以區間表示。確認後才會存成你的紀錄。',
          ),
        ),
        Gutter(
          child: _InferredDishCard(
            dish: DishEntry(
              name: DemoNutrition.sandwich.name,
              quantityLabel: DemoNutrition.sandwich.quantityLabel,
              subtitle: DemoNutrition.sandwich.subtitle,
              components: _confirmedComponents,
            ),
          ),
        ),
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('幫我確認兩件事', style: AppTextStyles.itemTitle),
                const SizedBox(height: AppSpacing.sm),
                const Text('美乃滋的份量比較接近？', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                SegmentedChoice(
                  options: _MayoAmount.values,
                  selected: _mayo,
                  labelOf: (amount) => amount.label,
                  selectedColor: AppColors.nutrition,
                  onChanged: (amount) => setState(() => _mayo = amount),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('雞腿肉大約幾克？', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                SegmentedChoice<_ChickenAmount?>(
                  options: _ChickenAmount.values,
                  selected: _chicken,
                  labelOf: (amount) => amount!.label,
                  selectedColor: AppColors.nutrition,
                  onChanged: (amount) => setState(() => _chicken = amount),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.photo_camera_outlined, color: AppColors.textTertiary),
          SizedBox(height: AppSpacing.xs),
          Text('[ 午餐照片 ]', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _InferredDishCard extends StatelessWidget {
  const _InferredDishCard({required this.dish});

  final DishEntry dish;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dish.name,
                  style: AppTextStyles.pageTitle.copyWith(fontSize: 19),
                ),
              ),
              const TagChip(label: '信心 高', tone: TagTone.nutrition),
            ],
          ),
          Text(
            '一道料理 · ${dish.components.length} 項成分',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          ComponentList(components: dish.components, showSource: true),
        ],
      ),
    );
  }
}
