import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'activity_type_picker.dart';
import 'live_activity_screen.dart';

/// Round numbers cover most of what people log after the fact.
const _durationShortcuts = [15, 30, 45, 60];

const _minMinutes = 1;
const _maxMinutes = 600;
const _maxDistanceKm = 1000.0;
const _maxElevationM = 10000.0;

/// Logging exercise that has already happened, which is how most of it
/// gets recorded. The end is now, the start follows from the duration, so
/// nobody has to do the arithmetic. Passing [activity] corrects that
/// session instead of adding another one.
class RecordActivityScreen extends StatefulWidget {
  const RecordActivityScreen({super.key, this.activity});

  final ActivitySession? activity;

  @override
  State<RecordActivityScreen> createState() => _RecordActivityScreenState();
}

class _RecordActivityScreenState extends State<RecordActivityScreen> {
  late ActivityType _type;
  late DateTime _startedAt;
  late int _minutes;
  final _distance = TextEditingController();
  final _elevation = TextEditingController();
  final _note = TextEditingController();
  int? _effort;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = AppStoreScope.read(context);
    if (widget.activity case final activity?) {
      _type = activity.type;
      _minutes = activity.duration.inMinutes;
      _startedAt = activity.startedAt;
      _effort = activity.effort;
      _note.text = activity.note;
      if (activity.distanceMeters case final metres?) {
        _distance.text = formatWeight(metres / 1000);
      }
      if (activity.elevationGainMeters case final metres?) {
        _elevation.text = metres.round().toString();
      }
      return;
    }
    _type = store.recentActivityTypes.firstOrNull ?? ActivityTypes.running;
    _minutes = store.startingActivityDuration(_type).inMinutes;
    _startedAt = store.now().subtract(Duration(minutes: _minutes));
  }

  @override
  void dispose() {
    _elevation.dispose();
    _distance.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime get _endedAt => _startedAt.add(Duration(minutes: _minutes));

  /// Changing the length keeps the end where it is: "I just finished a
  /// 45-minute run" is the usual case.
  void _setMinutes(int minutes) => setState(() {
    final end = _endedAt;
    _minutes = minutes;
    _startedAt = end.subtract(Duration(minutes: minutes));
  });

  Future<void> _pickType() async {
    final type = await pushModalPage<ActivityType>(
      context,
      ActivityTypePicker(selected: _type),
    );
    if (type == null || !mounted) return;
    setState(() {
      _type = type;
      // Correcting a session keeps its length; a new one takes the
      // length that type usually runs to.
      if (widget.activity == null) {
        _minutes = AppStoreScope.read(context)
            .startingActivityDuration(type)
            .inMinutes;
      }
      if (!type.tracksDistance) _distance.clear();
      if (!type.tracksElevation) _elevation.clear();
    });
  }

  void _startNow() {
    final store = AppStoreScope.read(context);
    if (!store.startActivity(_type)) {
      showToast(context, '訓練進行中，先結束訓練才能開始運動', kind: ToastKind.warning);
      return;
    }
    replaceWithPage(context, const LiveActivityScreen());
  }

  Future<void> _pickStart() async {
    final store = AppStoreScope.read(context);
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(store.now().year - 1),
      lastDate: store.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  double? get _elevationMetres {
    final text = _elevation.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  double? get _distanceMetres {
    final text = _distance.text.trim();
    if (text.isEmpty) return null;
    final kilometres = double.tryParse(text);
    return kilometres == null ? null : kilometres * 1000;
  }

  void _save() {
    if (_minutes < _minMinutes || _minutes > _maxMinutes) {
      setState(() => _error = '時長請介於 $_minMinutes – $_maxMinutes 分鐘。');
      return;
    }
    final text = _distance.text.trim();
    final metres = _distanceMetres;
    if (text.isNotEmpty &&
        (metres == null || metres < 0 || metres > _maxDistanceKm * 1000)) {
      setState(() => _error = '距離請輸入 0 – ${_maxDistanceKm.round()} 公里之間。');
      return;
    }
    final climb = _elevationMetres;
    if (_elevation.text.trim().isNotEmpty &&
        (climb == null || climb < 0 || climb > _maxElevationM)) {
      setState(() => _error = '爬升請輸入 0 – ${_maxElevationM.round()} 公尺之間。');
      return;
    }
    final store = AppStoreScope.read(context);
    final edited = widget.activity;
    if (edited == null) {
      store.logActivity(
        type: _type,
        startedAt: _startedAt,
        duration: Duration(minutes: _minutes),
        distanceMeters: _type.tracksDistance ? metres : null,
        elevationGainMeters: _type.tracksElevation ? climb : null,
        effort: _effort,
        note: _note.text.trim(),
      );
    } else {
      store.updateActivity(
        ActivitySession(
          id: edited.id,
          type: _type,
          startedAt: _startedAt,
          duration: Duration(minutes: _minutes),
          distanceMeters: _type.tracksDistance ? metres : null,
          elevationGainMeters: _type.tracksElevation ? climb : null,
          effort: _effort,
          note: _note.text.trim(),
          nativeType: edited.nativeType,
        ),
      );
    }
    Navigator.of(context).pop();
    showToast(
      context,
      edited == null ? '已記錄${_type.label} $_minutes 分' : '已更新${_type.label}',
      kind: ToastKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pace = ActivitySession(
      id: '',
      type: _type,
      startedAt: _startedAt,
      duration: Duration(minutes: _minutes),
      distanceMeters: _distanceMetres,
    ).pace;
    return DetailPage(
      appBar: PageAppBar(
        title: widget.activity == null ? '記錄運動' : '編輯運動',
        subtitle: widget.activity == null ? '事後補記' : '修正已經記下的內容',
      ),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: '運動類型',
                subtitle: _type.label,
                leading: Icon(_type.icon, color: AppColors.activity),
                onTap: _pickType,
              ),
              if (widget.activity == null)
                NavRow(
                  title: '現在開始計時',
                  subtitle: '邊做邊計時，距離與強度結束後再補',
                  leading: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.activity,
                  ),
                  onTap: _startNow,
                ),
              NavRow(
                title: '開始時間',
                subtitle:
                    '${_startedAt.month} 月 ${_startedAt.day} 日 '
                    '${formatTimeOfDay(_startedAt)}',
                onTap: _pickStart,
              ),
            ],
          ),
        ),
        Gutter(child: const SectionLabel('時長')),
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChipWrap(
                  options: _durationShortcuts,
                  labelOf: (minutes) => '$minutes 分',
                  isSelected: (minutes) => _minutes == minutes,
                  selectedColor: AppColors.activity,
                  onTap: _setMinutes,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: TextField(
                        key: const ValueKey('activity-minutes'),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        controller: TextEditingController(text: '$_minutes')
                          ..selection = TextSelection.collapsed(
                            offset: '$_minutes'.length,
                          ),
                        style: AppTextStyles.bigNumber,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (value) =>
                            _setMinutes(int.tryParse(value) ?? _minutes),
                      ),
                    ),
                    const Text('分鐘', style: AppTextStyles.caption),
                    const Spacer(),
                    Text(
                      '結束 ${formatTimeOfDay(_endedAt)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_type.tracksDistance) ...[
          Gutter(child: const SectionLabel('距離（選填）')),
          Gutter(
            child: _MeasureField(
              fieldKey: const ValueKey('activity-distance'),
              controller: _distance,
              unit: 'km',
              allowsDecimals: true,
              onChanged: () => setState(() {}),
            ),
          ),
          if (pace != null)
            Gutter(
              child: Text(
                '配速 ${formatHoursMinutes(pace)} /km（由時長與距離計算）',
                style: AppTextStyles.caption,
              ),
            ),
        ],
        if (_type.tracksElevation) ...[
          Gutter(child: const SectionLabel('爬升（選填）')),
          Gutter(
            child: _MeasureField(
              fieldKey: const ValueKey('activity-elevation'),
              controller: _elevation,
              unit: 'm',
            ),
          ),
        ],
        Gutter(child: const SectionLabel('強度（選填）')),
        Gutter(
          child: ChipWrap(
            options: const [2, 4, 6, 8, 10],
            labelOf: (effort) => '$effort',
            isSelected: (effort) => _effort == effort,
            selectedColor: AppColors.activity,
            onTap: (effort) =>
                setState(() => _effort = _effort == effort ? null : effort),
          ),
        ),
        Gutter(
          child: const Text(
            '1 很輕鬆、10 拼盡全力。這是你的主觀感受，沒有標準答案。',
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(child: const SectionLabel('備註（選填）')),
        Gutter(
          child: AppTextField(controller: _note, hint: '例如：河濱，風很大'),
        ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
      ],
    );
  }
}

/// A number and its unit on a card: the optional measurements a type
/// says it supports, which read the same whichever one it is.
class _MeasureField extends StatelessWidget {
  const _MeasureField({
    required this.fieldKey,
    required this.controller,
    required this.unit,
    this.allowsDecimals = false,
    this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String unit;
  final bool allowsDecimals;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(
                decimal: allowsDecimals,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  allowsDecimals ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                ),
              ],
              onChanged: (_) => onChanged?.call(),
              style: AppTextStyles.bigNumber,
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: allowsDecimals ? '0.0' : '0',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
              ),
            ),
          ),
          Text(unit, style: AppTextStyles.itemTitle),
        ],
      ),
    );
  }
}
