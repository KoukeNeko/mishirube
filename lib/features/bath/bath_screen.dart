import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/bath_entry_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../journal/journal_view_model.dart';
import '../../l10n/l10n.dart';

/// One day's showers and baths, under the week strip 飲食, 睡眠 and 水
/// have: any day is a tap away. Each bath opens to be corrected, or is
/// taken back with a swipe; a new one is added to the day shown.
class BathScreen extends StatefulWidget {
  const BathScreen({super.key, this.day});

  /// The day to open on; today when null.
  final DateTime? day;

  @override
  State<BathScreen> createState() => _BathScreenState();
}

class _BathScreenState extends State<BathScreen> {
  late final _journal = JournalViewModel(AppStoreScope.read(context).backend);

  /// The day shown: the one opened, then whichever the strip picks.
  late DateTime _day = DateUtils.dateOnly(
    widget.day ?? AppStoreScope.read(context).now(),
  );

  @override
  void dispose() {
    _journal.dispose();
    super.dispose();
  }

  void _remove(BathEntry bath) {
    _journal.delete(bath.id);
    ToastScope.read(context).showUndo(
      context.l10n.deletedItem(item: context.l10n.recordBath),
      onUndo: () => _journal.restore(bath.id),
    );
  }

  /// A bath's water, kind and length, the ones the user gave.
  String? _detailOf(BathEntry bath) {
    final l10n = context.l10n;
    final parts = [
      ?bath.water?.labelIn(l10n),
      ?bath.kind?.labelIn(l10n),
      if (bath.duration case final duration?) formatDuration(l10n, duration),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _journal,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final l10n = context.l10n;
    final day = _day;
    final today = DateUtils.dateOnly(_journal.now());
    final baths = _journal.bathsOn(day);
    final running = day == today ? AppStoreScope.of(context).activeBath : null;
    return PageScaffold(
      appBar: PageAppBar(
        title: l10n.recordBath,
        subtitle: context.dates.dayWithWeekday(day),
      ),
      pinned: WeekDayStrip(
        selected: day,
        latest: today,
        firstWeekday: AppStoreScope.of(context).firstWeekday,
        color: AppColors.wellness,
        markedDays: _journal.daysWithBaths([
          for (var back = -35; back <= 35; back++)
            DateTime(day.year, day.month, day.day + back),
        ]),
        onSelected: (picked) => setState(() => _day = picked),
      ),
      pinnedHeight: WeekDayStrip.pinnedHeightOf(context),
      children: [
        if (running != null)
          Gutter(
            child: NavCard(
              title: l10n.recordBath,
              subtitle: l10n.sessionInProgress,
              leading: const Icon(
                Icons.bathtub_outlined,
                color: AppColors.wellness,
              ),
              tone: CardTone.training,
              onTap: () => pushPage(context, const BathEntryScreen.running()),
            ),
          ),
        if (baths.isEmpty && running == null)
          Gutter(
            child: EmptyStateCard(
              icon: Icons.bathtub_outlined,
              title: l10n.noEntriesShort,
              action: PrimaryButton(
                label: l10n.logByHand,
                onPressed: () => pushPage(context, BathEntryScreen(day: day)),
              ),
            ),
          ),
        for (final bath in baths.reversed)
          Gutter(
            child: SwipeAction(
              key: ValueKey(bath.id),
              label: l10n.removeAction,
              semanticLabel:
                  '${l10n.removeAction} ${l10n.recordBath} '
                  '${formatTimeOfDay(bath.bathedAt)}',
              onAction: () => _remove(bath),
              child: NavCard(
                title: formatTimeOfDay(bath.bathedAt),
                subtitle: _detailOf(bath),
                leading: const Icon(
                  Icons.bathtub_outlined,
                  color: AppColors.wellness,
                ),
                onTap: () => pushPage(
                  context,
                  JournalDetailScreen(id: bath.id, at: bath.bathedAt),
                ),
              ),
            ),
          ),
        if (baths.isNotEmpty)
          Gutter(
            child: DashedActionCard(
              label: day == today
                  ? l10n.dockAddEntry
                  : l10n.addEntryToDay(date: context.dates.monthDay(day)),
              color: AppColors.wellness,
              onTap: () => pushPage(context, BathEntryScreen(day: day)),
            ),
          ),
      ],
    );
  }
}
