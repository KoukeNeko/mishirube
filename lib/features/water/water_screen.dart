import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final day = _day;
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
        color: AppColors.nutrition,
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
