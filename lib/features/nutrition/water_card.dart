import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';

/// The amounts offered for one tap, named after what holds them.
const _presets = [('一杯', 250), ('大杯', 350), ('一瓶', 500)];

/// Plain water, logged in one tap.
///
/// The card states facts and nothing else: how much water today, how many
/// times, the last one. There is no target, percentage or filling glass —
/// the app has no validated daily amount, and a glass that fills up is
/// read as distance to one. Other drinks with a volume are counted on a
/// quieter line of their own rather than folded into a number labelled
/// 「水」.
///
/// How much the next tap adds is chosen on the card itself, since it is
/// part of logging, not a setting.
class WaterCard extends StatelessWidget {
  const WaterCard({super.key, required this.onOpenDay});

  /// Opens the day's food and drink, where every drink is listed and can
  /// be corrected.
  final VoidCallback onOpenDay;

  void _logGlass(BuildContext context, AppStore store) {
    final logged = store.logWater();
    ToastScope.read(context).showUndo(
      '已記錄 ${logged.millilitres} mL 水',
      onUndo: () => store.deleteMeals([logged]),
    );
  }

  Future<void> _pickAmount(BuildContext context, AppStore store) async {
    final current = store.glassMillilitres;
    final isPreset = _presets.any((preset) => preset.$2 == current);
    await showAppDialog<void>(
      context,
      AppDialog(
        title: '一次記多少',
        isChoiceList: true,
        actions: [
          for (final (name, millilitres) in _presets)
            DialogAction(
              icon: Icons.water_drop_outlined,
              label: millilitres == current ? '$name ✓' : name,
              detail: '$millilitres mL',
              tone: millilitres == current
                  ? DialogTone.primary
                  : DialogTone.normal,
              onTap: () {
                store.setGlassMillilitres(millilitres);
                Navigator.of(context).pop();
              },
            ),
          DialogAction(
            icon: Icons.edit_outlined,
            label: isPreset ? '自訂' : '自訂 ✓',
            detail: isPreset ? null : '$current mL',
            tone: isPreset ? DialogTone.normal : DialogTone.primary,
            onTap: () async {
              Navigator.of(context).pop();
              final typed = await showTextDialog(
                context,
                title: '一次記多少毫升',
                initial: '$current',
                confirmLabel: '好',
              );
              final millilitres = int.tryParse(typed?.trim() ?? '');
              if (millilitres != null && millilitres > 0) {
                store.setGlassMillilitres(millilitres);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final water = store.todayWater;
    final fluid = store.todayFluid;
    final glass = store.glassMillilitres;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: AppColors.nutrition,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(child: Text('水', style: AppTextStyles.itemTitle)),
              ChipButton(
                label: '$glass mL ▾',
                semanticLabel: '一次記多少，目前 $glass 毫升',
                onTap: () => _pickAmount(context, store),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          StatBlock(
            value: '${water.millilitres}',
            unit: 'mL',
            label: '今天',
            valueStyle: AppTextStyles.hugeNumber,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(switch (water.lastTimeLabel) {
            final last? => '${water.times} 次 · 最近 $last',
            null => '今天還沒有記錄',
          }, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          NutritionButton(
            label: '＋ $glass mL',
            onPressed: () => _logGlass(context, store),
          ),
          // Only when other drinks added something, and never under the
          // name 「水」.
          if (fluid.millilitres > water.millilitres) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.outline),
            LinkText(
              label: '飲品總量 ${fluid.millilitres} mL（含咖啡、茶等）',
              color: AppColors.textSecondary,
              onTap: onOpenDay,
            ),
          ],
        ],
      ),
    );
  }
}
