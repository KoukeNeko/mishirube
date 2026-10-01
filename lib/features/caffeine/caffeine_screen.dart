import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/caffeine_activity.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/meal_detail_screen.dart';
import 'caffeine_card.dart';
import 'caffeine_view_model.dart';
import '../../l10n/l10n.dart';

/// Caffeine on its own: the estimate now and as it falls away, each
/// record of the last day it came from, to open and correct, and whether
/// it is also shown on the lock screen.
class CaffeineScreen extends StatefulWidget {
  const CaffeineScreen({super.key});

  @override
  State<CaffeineScreen> createState() => _CaffeineScreenState();
}

class _CaffeineScreenState extends State<CaffeineScreen> {
  late final _model = CaffeineViewModel(AppStoreScope.read(context).backend);

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _model, builder: (context, _) => _page());

  Widget _page() {
    final curve = _model.curve;
    final intakes = _model.recentIntakes;
    return PageScaffold(
      appBar: PageAppBar(title: context.l10n.nutrientCaffeine),
      children: [
        if (curve case (:final curve, :final nowIndex))
          Gutter(
            child: CaffeineCard(
              curve: curve,
              nowIndex: nowIndex,
              chartHeight: 180,
            ),
          )
        else
          Gutter(
            child: EmptyStateCard(
              icon: Icons.coffee_outlined,
              title: context.l10n.noEntriesShort,
            ),
          ),
        if (intakes.isNotEmpty) ...[
          Gutter(child: SectionLabel(context.l10n.last24Hours)),
          for (final (eatenAt, meal) in intakes)
            Gutter(
              child: NavCard(
                title: meal.name,
                subtitle: formatTimeOfDay(eatenAt),
                trailing: Text(
                  '${formatAmount(meal.nutrients[Nutrient.caffeine]!)} mg',
                  style: AppTextStyles.itemTitle,
                ),
                onTap: () => pushPage(context, MealDetailScreen(meal: meal)),
              ),
            ),
        ],
        if (CaffeineActivity.isSupported)
          Gutter(
            child: GroupedCard(
              children: [
                SwitchRow(
                  title: context.l10n.liveActivities,
                  value: _model.isLiveActivityOn,
                  onChanged: _model.setLiveActivity,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
