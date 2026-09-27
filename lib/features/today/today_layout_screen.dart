import 'package:flutter/material.dart';

import '../../app/view_model.dart';
import '../../shared/widgets/widgets.dart';
import 'today_view_model.dart';
import '../../l10n/l10n.dart';

/// Which parts of Today are shown. Hiding one only takes it off Today;
/// what it shows stays everywhere else, and the modules in settings are
/// what turn a kind of record off.
class TodayLayoutScreen extends StatelessWidget {
  const TodayLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TodayViewModel.new,
    builder: (context, today) {
      final hidden = today.hidden;
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.customiseToday),
        children: [
          Gutter(
            child: GroupedCard(
              children: [
                for (final section in TodaySection.values)
                  SwitchRow(
                    title: section.labelIn(context.l10n),
                    value: !hidden.contains(section),
                    onChanged: (isShown) => today.setShown(section, isShown),
                  ),
              ],
            ),
          ),
          if (hidden.isNotEmpty)
            Gutter(
              child: Center(
                child: LinkText(
                  label: context.l10n.showAll,
                  onTap: today.showAll,
                ),
              ),
            ),
        ],
      );
    },
  );
}
