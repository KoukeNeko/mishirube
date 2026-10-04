import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_detail_screen.dart';
import 'journal_view_model.dart';
import '../../l10n/l10n.dart';

/// Longest a bath is taken to last when the user gives a length.
const _longestBathMinutes = 600;

/// Logging one shower or bath: when it ended, and, if the user says, how
/// warm the water was, which kind it was and how long it took.
///
/// Only the end is ever filled in for the user. The rest starts empty,
/// stays empty unless chosen, and is not carried over from the last bath:
/// a value the user never gave would read as theirs.
///
/// A bath can also be run live: 開始 begins it now, and this page then
/// shows its clock ([BathEntryScreen.running]) until 結束 records it.
class BathEntryScreen extends StatefulWidget {
  const BathEntryScreen({super.key, this.editing}) : isRunning = false;

  /// The bath that is running, with its clock; water and kind chosen
  /// here are kept with it.
  const BathEntryScreen.running({super.key}) : editing = null, isRunning = true;

  /// A bath to correct instead of logging a new one.
  final BathEntry? editing;

  final bool isRunning;

  @override
  State<BathEntryScreen> createState() => _BathEntryScreenState();
}

class _BathEntryScreenState extends State<BathEntryScreen> {
  late final JournalViewModel _journal;
  late DateTime _end;
  late BathWater? _water = widget.isRunning
      ? AppStoreScope.read(context).activeBath?.water
      : widget.editing?.water;
  late BathKind? _kind = widget.isRunning
      ? AppStoreScope.read(context).activeBath?.kind
      : widget.editing?.kind;
  late final _minutes = TextEditingController(
    text: switch (widget.editing?.duration) {
      final duration? => '${duration.inMinutes}',
      null => '',
    },
  );
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = AppStoreScope.read(context);
    _journal = JournalViewModel(store.backend);
    _end = widget.editing?.bathedAt ?? store.now();
  }

  @override
  void dispose() {
    _minutes.dispose();
    _journal.dispose();
    super.dispose();
  }

  Future<void> _pickEnd() async {
    final picked = await pickDateTime(
      context,
      initial: _end,
      latest: AppStoreScope.read(context).now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _end = picked);
  }

  void _choose({required BathWater? water, required BathKind? kind}) {
    setState(() {
      _water = water;
      _kind = kind;
    });
    if (widget.isRunning) {
      AppStoreScope.read(context).chooseBath(water: water, kind: kind);
    }
  }

  void _start() {
    final store = AppStoreScope.read(context);
    if (!store.startBath(water: _water, kind: _kind)) {
      showToast(
        context,
        context.l10n.sessionBlocksStart(
          session: store.activeSession!.name(context.l10n),
        ),
        kind: ToastKind.warning,
      );
      return;
    }
    replaceWithPage(context, const BathEntryScreen.running());
  }

  void _finish() {
    final entry = AppStoreScope.read(context).finishBath();
    if (entry == null) return;
    replaceWithPage(
      context,
      JournalDetailScreen(id: entry.id, at: entry.bathedAt),
    );
  }

  void _discard() {
    final store = AppStoreScope.read(context);
    final discarded = context.l10n.sessionDiscarded(
      session: context.l10n.recordBath,
    );
    store.discardBath();
    Navigator.of(context).pop();
    showToast(context, discarded);
  }

  void _save() {
    final text = _minutes.text.trim();
    final minutes = text.isEmpty ? null : int.tryParse(text);
    if (text.isNotEmpty &&
        (minutes == null || minutes < 1 || minutes > _longestBathMinutes)) {
      setState(
        () => _error = context.l10n.valueRangeError(
          field: context.l10n.durationLabel,
          min: '1',
          max: '$_longestBathMinutes',
          unit: context.l10n.unitMinutes,
        ),
      );
      return;
    }
    final duration = minutes == null ? null : Duration(minutes: minutes);
    final editing = widget.editing;
    if (editing == null) {
      _journal.recordBath(
        at: _end,
        water: _water,
        kind: _kind,
        duration: duration,
      );
    } else {
      _journal.updateBath(
        BathEntry(
          id: editing.id,
          bathedAt: _end,
          water: _water,
          kind: _kind,
          duration: duration,
        ),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      (editing == null ? context.l10n.loggedValue : context.l10n.updatedValue)(
        item: context.l10n.recordBath,
        value: formatTimeOfDay(_end),
      ),
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final running = AppStoreScope.of(context).activeBath;
    if (widget.isRunning && running == null) {
      return DetailPage(
        appBar: PageAppBar(title: l10n.recordBath),
        children: [Gutter(child: InfoBanner(message: l10n.bathEnded))],
      );
    }
    return DetailPage(
      appBar: PageAppBar(
        title: l10n.recordBath,
        subtitle: widget.isRunning ? l10n.sessionInProgress : null,
      ),
      footer: PrimaryButton(
        label: widget.isRunning ? l10n.commonEnd : l10n.commonSave,
        onPressed: widget.isRunning ? _finish : _save,
      ),
      children: [
        if (running != null)
          Gutter(
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxl,
                horizontal: AppSpacing.md,
              ),
              child: Center(
                child: ElapsedClock(
                  session: ActiveBath(running),
                  builder: (_, elapsed) => Text(
                    elapsed,
                    style: AppTextStyles.bigNumber.copyWith(
                      color: AppColors.wellness,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Gutter(
            child: GroupedCard(
              children: [
                NavRow(
                  title: l10n.commonEnd,
                  subtitle:
                      '${context.dates.monthDay(_end)} ${formatTimeOfDay(_end)}',
                  onTap: _pickEnd,
                ),
                if (widget.editing == null)
                  NavRow(
                    title: l10n.commonStart,
                    leading: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.wellness,
                    ),
                    onTap: _start,
                  ),
              ],
            ),
          ),
        Gutter(child: SectionLabel(l10n.bathWaterSection)),
        Gutter(
          child: ChipWrap<BathWater>(
            options: BathWater.values,
            labelOf: (water) => water.labelIn(l10n),
            isSelected: (water) => _water == water,
            selectedColor: AppColors.wellness,
            // Tapping the chosen one again clears it: no answer is valid.
            onTap: (water) =>
                _choose(water: _water == water ? null : water, kind: _kind),
          ),
        ),
        Gutter(child: SectionLabel(l10n.bathKindSection)),
        Gutter(
          child: ChipWrap<BathKind>(
            options: BathKind.values,
            labelOf: (kind) => kind.labelIn(l10n),
            isSelected: (kind) => _kind == kind,
            selectedColor: AppColors.wellness,
            onTap: (kind) =>
                _choose(water: _water, kind: _kind == kind ? null : kind),
          ),
        ),
        if (running == null)
          Gutter(
            child: NumberFieldRow(
              fieldKey: const ValueKey('bath-minutes'),
              label: l10n.durationLabel,
              unit: l10n.unitMinutes,
              controller: _minutes,
            ),
          ),
        if (running != null)
          Gutter(
            child: Center(
              child: LinkText(
                label: l10n.sessionDiscardBath,
                color: AppColors.warning,
                onTap: _discard,
              ),
            ),
          ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
      ],
    );
  }
}
