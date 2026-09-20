import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// The range a night is logged in, in 15-minute steps.
const _minMinutes = 180;
const _maxMinutes = 720;
const _stepMinutes = 15;

/// Starting point when nothing was logged before.
const _defaultMinutes = 450;

/// Logging one night: how long, and how it felt if the user says.
class SleepEntryScreen extends StatefulWidget {
  const SleepEntryScreen({super.key});

  @override
  State<SleepEntryScreen> createState() => _SleepEntryScreenState();
}

class _SleepEntryScreenState extends State<SleepEntryScreen> {
  late int _minutes = _lastNight?.duration.inMinutes ?? _defaultMinutes;
  int? _score;

  SleepEntry? get _lastNight =>
      AppStoreScope.read(context).recentSleep.lastOrNull;

  void _save() {
    final store = AppStoreScope.read(context);
    store.recordSleep(Duration(minutes: _minutes), score: _score);
    Navigator.of(context).pop();
    showToast(context, '已記錄睡眠 ${_label(_minutes)}', kind: ToastKind.success);
  }

  static String _label(int minutes) =>
      formatHoursMinutes(Duration(minutes: minutes));

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '睡眠', subtitle: '手動補記'),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        Gutter(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('睡了多久', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                Text(_label(_minutes), style: AppTextStyles.hugeNumber),
                Slider(
                  value: _minutes.toDouble(),
                  min: _minMinutes.toDouble(),
                  max: _maxMinutes.toDouble(),
                  divisions: (_maxMinutes - _minMinutes) ~/ _stepMinutes,
                  label: _label(_minutes),
                  activeColor: AppColors.wellness,
                  onChanged: (value) =>
                      setState(() => _minutes = value.round()),
                ),
              ],
            ),
          ),
        ),
        Gutter(child: const SectionLabel('品質（可略過）')),
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
        Gutter(
          child: const Text(
            '沒有評分也可以，趨勢只會用到有紀錄的夜晚。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
