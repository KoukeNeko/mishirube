import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../nutrition/meal_detail_screen.dart';
import '../nutrition/nutrition_view_model.dart';
import 'water_card.dart';
import '../../l10n/l10n.dart';

/// One day's plain water: what it came to, a tap to log a glass today,
/// and each glass, to open or take back.
///
/// Water is kept as the drink record every drink writes, so the day's
/// fluid stays one total; it is apart from 飲食 on screen only.
class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key, this.day});

  /// The day to open on; today when null.
  final DateTime? day;

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

/// Plain water within an hour that earns the warning.
const _fastMillilitres = 1000;

class _WaterScreenState extends State<WaterScreen> {
  late final _nutrition = NutritionViewModel(
    AppStoreScope.read(context).backend,
  );

  /// The day shown: the one opened, then whichever the strip picks.
  late DateTime _day = DateUtils.dateOnly(
    widget.day ?? AppStoreScope.read(context).now(),
  );

  @override
  void dispose() {
    _nutrition.dispose();
    super.dispose();
  }

  /// Takes a glass of water back out of the day.
  void _remove(MealEvent glass) {
    _nutrition.deleteMeals([glass]);
    ToastScope.read(context).showUndo(
      context.l10n.removedWater(millilitres: glass.millilitres ?? 0),
      onUndo: () => _nutrition.restoreMeals([glass]),
    );
  }

  /// Chooses the daily reference: 國健署's where the day follows
  /// Taiwan's rules, one of the user's own, or none, which draws no level.
  Future<void> _pickReference() async {
    final l10n = context.l10n;
    final current = _nutrition.waterReferenceMl;
    const hpa = NutritionViewModel.taiwanWaterReferenceMl;
    final offersHpa = _nutrition.convention == NutritionConvention.taiwan;
    final isCustom = current != null && !(offersHpa && current == hpa);
    DialogTone tone(bool isSelected) =>
        isSelected ? DialogTone.primary : DialogTone.normal;
    await showAppDialog<void>(
      context,
      AppDialog(
        title: l10n.waterReference,
        message: l10n.waterReferenceNote,
        isChoiceList: true,
        actions: [
          if (offersHpa)
            DialogAction(
              label: '${formatKcal(hpa)} mL',
              detail: l10n.waterReferenceHpa,
              isSelected: current == hpa,
              tone: tone(current == hpa),
              onTap: () {
                _nutrition.setWaterReferenceMl(hpa);
                Navigator.of(context).pop();
              },
            ),
          DialogAction(
            label: l10n.customAction,
            detail: isCustom ? '${formatKcal(current)} mL' : null,
            isSelected: isCustom,
            tone: tone(isCustom),
            onTap: () async {
              Navigator.of(context).pop();
              final typed = await showTextDialog(
                context,
                title: l10n.waterReferenceMl,
                initial: current == null ? '' : '$current',
              );
              final millilitres = int.tryParse(typed?.trim() ?? '');
              if (millilitres != null && millilitres > 0) {
                _nutrition.setWaterReferenceMl(millilitres);
              }
            },
          ),
          DialogAction(
            label: l10n.waterReferenceNone,
            isSelected: current == null,
            tone: tone(current == null),
            onTap: () {
              _nutrition.setWaterReferenceMl(null);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final day = _day;
    final reference = _nutrition.waterReferenceMl;
    final lastHour = DateUtils.isSameDay(day, _nutrition.now())
        ? _nutrition.waterInLastHour
        : 0;
    return PageScaffold(
      appBar: PageAppBar(
        title: context.l10n.healthDataWater,
        subtitle: context.dates.dayWithWeekday(day),
      ),
      // The same week header as 飲食 and 睡眠.
      pinned: WeekDayStrip(
        selected: day,
        latest: DateUtils.dateOnly(_nutrition.now()),
        firstWeekday: AppStoreScope.of(context).firstWeekday,
        color: AppColors.water,
        markedDays: _nutrition.daysWithWater([
          for (var back = -35; back <= 35; back++)
            DateTime(day.year, day.month, day.day + back),
        ]),
        onSelected: (picked) => setState(() => _day = picked),
      ),
      pinnedHeight: WeekDayStrip.pinnedHeightOf(context),
      children: [
        Gutter(
          child: WaterCard(
            nutrition: _nutrition,
            day: day,
            onOpenDay: () => pushPage(context, DailyNutritionScreen(day: day)),
          ),
        ),
        // Near what the kidneys can clear in an hour (NASEM, 0.7–1.0 L).
        if (lastHour >= _fastMillilitres)
          Gutter(
            child: InfoBanner(
              tone: CardTone.warning,
              message: context.l10n.waterFastWarning(
                millilitres: formatKcal(lastHour),
              ),
            ),
          ),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: context.l10n.waterReference,
                subtitle:
                    reference == NutritionViewModel.taiwanWaterReferenceMl &&
                        _nutrition.convention == NutritionConvention.taiwan
                    ? context.l10n.waterReferenceHpa
                    : null,
                trailing: Text(
                  reference == null
                      ? context.l10n.notSet
                      : '${formatKcal(reference)} mL',
                  style: AppTextStyles.body,
                ),
                showChevron: false,
                onTap: _pickReference,
              ),
            ],
          ),
        ),
        for (final glass in _nutrition.glassesOn(day))
          Gutter(
            child: SwipeAction(
              key: ValueKey(glass.id),
              label: context.l10n.removeAction,
              semanticLabel: context.l10n.removeWaterAt(time: glass.timeLabel),
              onAction: () => _remove(glass),
              child: NavCard(
                title: '${glass.millilitres} mL',
                subtitle: glass.timeLabel,
                onTap: () => pushPage(context, MealDetailScreen(meal: glass)),
              ),
            ),
          ),
      ],
    );
  }
}
