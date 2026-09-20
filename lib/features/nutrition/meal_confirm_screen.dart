import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/seed/demo_content.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import 'component_list.dart';
import 'daily_nutrition_screen.dart';

const _baseEstimateKcal = 620;
const _estimateRangeKcal = 80;

enum _MayoAmount {
  little('少量', -40),
  normal('一般', 0),
  more('多一點', 45);

  const _MayoAmount(this.label, this.kcalDelta);

  final String label;
  final int kcalDelta;
}

enum _ChickenAmount {
  small('85 g', -25),
  regular('100 g', 0),
  unsure('不確定', 0);

  const _ChickenAmount(this.label, this.kcalDelta);

  final String label;
  final int kcalDelta;
}

/// AI inference result that is only saved after the user confirms it.
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

  void _confirm() {
    AppStoreScope.read(context).confirmLunch();
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
        Gutter(child: const _InferredDishCard(dish: DemoNutrition.sandwich)),
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
          ComponentList(
            components: DemoNutrition.sandwichComponents,
            showSource: true,
          ),
        ],
      ),
    );
  }
}
