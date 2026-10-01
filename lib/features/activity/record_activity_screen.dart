import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'activity_type_picker.dart';
import 'activity_view_model.dart';
import 'live_activity_screen.dart';
import '../../l10n/l10n.dart';

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
  late final ActivityViewModel _activities;
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
    _activities = ActivityViewModel(store.backend);
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
    _type = _activities.recentTypes.firstOrNull ?? ActivityTypes.running;
    _minutes = _activities.startingDuration(_type).inMinutes;
    _startedAt = store.now().subtract(Duration(minutes: _minutes));
  }

  @override
  void dispose() {
    _elevation.dispose();
    _distance.dispose();
    _note.dispose();
    _activities.dispose();
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
        _minutes = _activities.startingDuration(type).inMinutes;
      }
      if (!type.tracksDistance) _distance.clear();
      if (!type.tracksElevation) _elevation.clear();
    });
  }

  void _startNow() {
    final store = AppStoreScope.read(context);
    if (!store.startActivity(_type)) {
      showToast(
        context,
        context.l10n.workoutBlocksActivity,
        kind: ToastKind.warning,
      );
      return;
    }
    replaceWithPage(context, const LiveActivityScreen());
  }

  Future<void> _pickStart() async {
    final picked = await pickDateTime(
      context,
      initial: _startedAt,
      latest: AppStoreScope.read(context).now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _startedAt = picked);
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
      setState(
        () => _error = context.l10n.activityDurationRange(
          min: _minMinutes,
          max: _maxMinutes,
        ),
      );
      return;
    }
    final text = _distance.text.trim();
    final metres = _distanceMetres;
    if (text.isNotEmpty &&
        (metres == null || metres < 0 || metres > _maxDistanceKm * 1000)) {
      setState(
        () => _error = context.l10n.activityDistanceRange(
          max: _maxDistanceKm.round(),
        ),
      );
      return;
    }
    final climb = _elevationMetres;
    if (_elevation.text.trim().isNotEmpty &&
        (climb == null || climb < 0 || climb > _maxElevationM)) {
      setState(
        () => _error = context.l10n.activityClimbRange(
          max: _maxElevationM.round(),
        ),
      );
      return;
    }
    final edited = widget.activity;
    if (edited == null) {
      _activities.log(
        type: _type,
        startedAt: _startedAt,
        duration: Duration(minutes: _minutes),
        distanceMeters: _type.tracksDistance ? metres : null,
        elevationGainMeters: _type.tracksElevation ? climb : null,
        effort: _effort,
        note: _note.text.trim(),
      );
    } else {
      _activities.update(
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
      edited == null
          ? context.l10n.activityLogged(
              activity: _type.labelIn(context.l10n),
              minutes: _minutes,
            )
          : context.l10n.activityUpdated(activity: _type.labelIn(context.l10n)),
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
        title: widget.activity == null
            ? context.l10n.activityRecordTitle
            : context.l10n.activityEditTitle,
      ),
      footer: PrimaryButton(label: context.l10n.commonSave, onPressed: _save),
      children: [
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: context.l10n.activityTypeRow,
                subtitle: _type.labelIn(context.l10n),
                leading: Icon(_type.icon, color: AppColors.activity),
                onTap: _pickType,
              ),
              if (widget.activity == null)
                NavRow(
                  title: context.l10n.activityStartTimer,
                  subtitle: context.l10n.activityStartTimerDetail,
                  leading: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.activity,
                  ),
                  onTap: _startNow,
                ),
              NavRow(
                title: context.l10n.activityStartTime,
                subtitle:
                    '${context.dates.monthDay(_startedAt)} '
                    '${formatTimeOfDay(_startedAt)}',
                onTap: _pickStart,
              ),
            ],
          ),
        ),
        Gutter(child: SectionLabel(context.l10n.activityDurationSection)),
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChipWrap(
                  options: _durationShortcuts,
                  labelOf: (minutes) =>
                      context.l10n.durationMinutes(minutes: minutes),
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
                        onTapOutside: dismissKeyboardOnTapOutside,
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
                    Text(
                      context.l10n.minutesUnit,
                      style: AppTextStyles.caption,
                    ),
                    const Spacer(),
                    Text(
                      context.l10n.activityEndsAt(
                        time: formatTimeOfDay(_endedAt),
                      ),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_type.tracksDistance) ...[
          Gutter(
            child: SectionLabel(
              context.l10n.optionalField(field: context.l10n.activityDistance),
            ),
          ),
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
                context.l10n.activityPaceValue(pace: formatClock(pace)),
                style: AppTextStyles.caption,
              ),
            ),
        ],
        if (_type.tracksElevation) ...[
          Gutter(
            child: SectionLabel(
              context.l10n.optionalField(field: context.l10n.activityClimb),
            ),
          ),
          Gutter(
            child: _MeasureField(
              fieldKey: const ValueKey('activity-elevation'),
              controller: _elevation,
              unit: 'm',
            ),
          ),
        ],
        Gutter(
          child: SectionLabel(
            context.l10n.optionalField(field: context.l10n.effortSection),
          ),
        ),
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
          child: Text(
            context.l10n.effortScaleHint,
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(
          child: SectionLabel(
            context.l10n.optionalField(field: context.l10n.notesSection),
          ),
        ),
        Gutter(
          child: AppTextField(
            controller: _note,
            hint: context.l10n.activityNoteHint,
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
              onTapOutside: dismissKeyboardOnTapOutside,
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
