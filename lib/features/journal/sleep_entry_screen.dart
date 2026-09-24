import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'journal_view_model.dart';

/// When a night is assumed to begin and end before anything was logged.
const _defaultBedtime = TimeOfDay(hour: 23, minute: 0);
const _defaultWake = TimeOfDay(hour: 7, minute: 0);

/// A nap assumed before anything else is said: the last half hour.
const _defaultNap = Duration(minutes: 30);

/// Logging one sleep: the night or a nap, when it began and ended, and
/// how it felt if the user says.
///
/// A sleep read from a health platform keeps the platform's times, which
/// the next read would bring back anyway; only its rating and note are
/// the user's to change here.
class SleepEntryScreen extends StatefulWidget {
  const SleepEntryScreen({super.key, this.editing});

  /// A sleep to correct instead of logging a new one.
  final SleepEntry? editing;

  @override
  State<SleepEntryScreen> createState() => _SleepEntryScreenState();
}

class _SleepEntryScreenState extends State<SleepEntryScreen> {
  late final JournalViewModel _journal;
  late SleepKind _kind;
  late DateTime _start;
  late DateTime _end;
  late int? _score = widget.editing?.score;
  late final _note = TextEditingController(text: widget.editing?.note ?? '');

  /// Whether the times are the user's: a new sleep, or one typed in here.
  late bool _ownsTimes;

  @override
  void initState() {
    super.initState();
    final store = AppStoreScope.read(context);
    _journal = JournalViewModel(store.backend);
    final editing = widget.editing;
    _ownsTimes = editing == null || _journal.isTypedIn(editing.id);
    _kind = editing?.kind ?? SleepKind.night;
    if (editing != null) {
      _end = editing.sleptAt;
      _start = editing.startedAt ?? editing.sleptAt.subtract(editing.duration);
    } else {
      _setDefaults(store.now());
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _journal.dispose();
    super.dispose();
  }

  /// Last night from the default bedtime to the default waking, or, for a
  /// nap, the half hour before now.
  void _setDefaults(DateTime now) {
    if (_kind == SleepKind.nap) {
      _end = now;
      _start = now.subtract(_defaultNap);
      return;
    }
    final today = DateTime(now.year, now.month, now.day);
    var wake = today.add(
      Duration(hours: _defaultWake.hour, minutes: _defaultWake.minute),
    );
    if (wake.isAfter(now)) wake = now;
    final bed = today
        .subtract(const Duration(days: 1))
        .add(
          Duration(
            hours: _defaultBedtime.hour,
            minutes: _defaultBedtime.minute,
          ),
        );
    _start = bed;
    _end = wake;
  }

  Duration get _length => _end.difference(_start);

  bool get _isValid =>
      _length > Duration.zero &&
      _length <= const Duration(hours: 24) &&
      !_end.isAfter(AppStoreScope.read(context).now());

  Future<void> _pick({required bool isStart}) async {
    final store = AppStoreScope.read(context);
    final current = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(store.now().year - 1),
      lastDate: store.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => isStart ? _start = picked : _end = picked);
  }

  void _save() {
    final editing = widget.editing;
    if (editing == null) {
      _journal.recordSleep(
        _length,
        score: _score,
        note: _note.text.trim(),
        at: _end,
        startedAt: _start,
        kind: _kind,
      );
    } else {
      _journal.updateSleep(
        SleepEntry(
          id: editing.id,
          sleptAt: _ownsTimes ? _end : editing.sleptAt,
          duration: _ownsTimes ? _length : editing.duration,
          score: _score,
          note: _note.text.trim(),
          startedAt: _ownsTimes ? _start : editing.startedAt,
          kind: _ownsTimes ? _kind : editing.kind,
          measure: editing.measure,
          sourceName: editing.sourceName,
        ),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      '${editing == null ? '已記錄' : '已更新'}${_kind.label} '
      '${formatHoursMinutes(_length)}',
      kind: ToastKind.success,
    );
  }

  static String _when(DateTime time) =>
      '${time.month} 月 ${time.day} 日 ${formatTimeOfDay(time)}';

  @override
  Widget build(BuildContext context) {
    final length = _length;
    return DetailPage(
      appBar: PageAppBar(title: '睡眠'),
      footer: PrimaryButton(
        label: '儲存',
        onPressed: _isValid || !_ownsTimes ? _save : null,
      ),
      children: [
        if (_ownsTimes) ...[
          if (widget.editing == null)
            Gutter(
              child: SegmentedChoice<SleepKind>(
                options: SleepKind.values,
                selected: _kind,
                labelOf: (kind) => kind.label,
                selectedColor: AppColors.wellness,
                onChanged: (kind) => setState(() {
                  _kind = kind;
                  _setDefaults(AppStoreScope.read(context).now());
                }),
              ),
            ),
          Gutter(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    length > Duration.zero ? formatHoursMinutes(length) : '—',
                    style: AppTextStyles.hugeNumber.copyWith(
                      color: AppColors.wellness,
                    ),
                  ),
                  if (!_isValid)
                    Text(
                      length <= Duration.zero
                          ? '起床時間要在入睡之後'
                          : length > const Duration(hours: 24)
                          ? '一次睡眠不超過 24 小時'
                          : '起床時間不能晚於現在',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.destructive,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Gutter(
            child: GroupedCard(
              children: [
                NavRow(
                  title: '入睡',
                  subtitle: _when(_start),
                  onTap: () => _pick(isStart: true),
                ),
                NavRow(
                  title: '起床',
                  subtitle: _when(_end),
                  onTap: () => _pick(isStart: false),
                ),
              ],
            ),
          ),
        ],
        Gutter(child: const SectionLabel('品質（選填）')),
        Gutter(
          child: ChipWrap(
            options: const [1, 2, 3, 4, 5],
            labelOf: (score) => '$score',
            isSelected: (score) => _score == score,
            selectedColor: AppColors.wellness,
            // Tapping the chosen score again clears it: no rating is a
            // valid answer.
            onTap: (score) =>
                setState(() => _score = _score == score ? null : score),
          ),
        ),
        Gutter(child: const SectionLabel('備註（選填）')),
        Gutter(
          child: AppTextField(
            controller: _note,
            hint: '例如：睡前喝了咖啡、半夜醒來',
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}
