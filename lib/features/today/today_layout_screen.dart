import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../shared/widgets/widgets.dart';
import 'today_view_model.dart';
import '../../l10n/l10n.dart';

/// Which parts of Today are shown, and in what order. Hiding one only
/// takes it off Today; what it shows stays everywhere else, and the
/// modules in settings are what turn a kind of record off.
class TodayLayoutScreen extends StatelessWidget {
  const TodayLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TodayViewModel.new,
    builder: (context, today) {
      final hidden = today.hidden;
      final order = today.order;
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.customiseToday),
        children: [
          Gutter(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: order.length,
                onReorderItem: today.move,
                itemBuilder: (context, index) {
                  final section = order[index];
                  return Row(
                    key: ValueKey(section),
                    children: [
                      Expanded(
                        child: SwitchRow(
                          title: section.labelIn(context.l10n),
                          value: !hidden.contains(section),
                          onChanged: (isShown) =>
                              today.setShown(section, isShown),
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Semantics(
                          label: context.l10n.reorderSection(
                            section: section.labelIn(context.l10n),
                          ),
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.drag_handle,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Gutter(
            child: GroupedCard(
              children: [
                CheckRow(
                  title: context.l10n.todayOnlyWithData,
                  isChecked: today.showsOnlyWithData,
                  onChanged: today.setShowsOnlyWithData,
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
