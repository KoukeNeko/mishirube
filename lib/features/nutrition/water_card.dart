import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../shared/widgets/widgets.dart';
import 'nutrition_view_model.dart';
import '../../l10n/l10n.dart';

/// The amounts offered for one tap, named after what holds them.
List<(String, int)> _presets(AppLocalizations l10n) => [
  (l10n.waterGlass, 250),
  (l10n.waterLargeGlass, 350),
  (l10n.waterBottle, 500),
];

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

  void _logGlass(BuildContext context, NutritionViewModel nutrition) {
    final logged = nutrition.logWater();
    ToastScope.read(context).showUndo(
      context.l10n.waterLogged(millilitres: logged.millilitres ?? 0),
      onUndo: () => nutrition.deleteMeals([logged]),
    );
  }

  Future<void> _pickAmount(
    BuildContext context,
    NutritionViewModel nutrition,
  ) async {
    final current = nutrition.glassMillilitres;
    final isPreset = _presets(context.l10n)
        .any((preset) => preset.$2 == current);
    await showAppDialog<void>(
      context,
      AppDialog(
        title: context.l10n.waterPerTap,
        isChoiceList: true,
        actions: [
          for (final (name, millilitres) in _presets(context.l10n))
            DialogAction(
              icon: Icons.water_drop_outlined,
              label: name,
              isSelected: millilitres == current,
              detail: '$millilitres mL',
              tone: millilitres == current
                  ? DialogTone.primary
                  : DialogTone.normal,
              onTap: () {
                nutrition.setGlassMillilitres(millilitres);
                Navigator.of(context).pop();
              },
            ),
          DialogAction(
            icon: Icons.edit_outlined,
            label: context.l10n.customAction,
            isSelected: !isPreset,
            detail: isPreset ? null : '$current mL',
            tone: isPreset ? DialogTone.normal : DialogTone.primary,
            onTap: () async {
              Navigator.of(context).pop();
              final typed = await showTextDialog(
                context,
                title: context.l10n.waterPerTapMl,
                initial: '$current',
              );
              final millilitres = int.tryParse(typed?.trim() ?? '');
              if (millilitres != null && millilitres > 0) {
                nutrition.setGlassMillilitres(millilitres);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ViewModelBuilder(create: NutritionViewModel.new, builder: _card);

  Widget _card(BuildContext context, NutritionViewModel nutrition) {
    final water = nutrition.todayWater;
    final fluid = nutrition.todayFluid;
    final glass = nutrition.glassMillilitres;
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
              Expanded(
                child: Text(
                  context.l10n.waterSection,
                  style: AppTextStyles.itemTitle,
                ),
              ),
              ChipButton(
                label: '$glass mL ▾',
                semanticLabel: context.l10n.waterPerTapLabel(
                  millilitres: glass,
                ),
                onTap: () => _pickAmount(context, nutrition),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          StatBlock(
            value: '${water.millilitres}',
            unit: 'mL',
            label: context.l10n.tabToday,
            valueStyle: AppTextStyles.hugeNumber,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(switch (water.lastTimeLabel) {
            final last? => context.l10n.waterTimesLast(
              count: water.times,
              time: last,
            ),
            null => context.l10n.noEntriesShort,
          }, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          NutritionButton(
            label: '＋ $glass mL',
            onPressed: () => _logGlass(context, nutrition),
          ),
          // Only when other drinks added something, and never under the
          // name 「水」.
          if (fluid.millilitres > water.millilitres) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.outline),
            LinkText(
              label: context.l10n.allDrinksTotal(
                millilitres: fluid.millilitres,
              ),
              color: AppColors.textSecondary,
              onTap: onOpenDay,
            ),
          ],
        ],
      ),
    );
  }
}
