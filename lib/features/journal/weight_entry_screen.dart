import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';

/// Plausible bounds for a body weight in kilograms; outside them it is a
/// typo rather than a measurement.
const _minKg = 20.0;
const _maxKg = 400.0;

/// Logging a body weight, prefilled with the last one so the usual case
/// is a small correction rather than typing from scratch.
class WeightEntryScreen extends StatefulWidget {
  const WeightEntryScreen({super.key});

  @override
  State<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends State<WeightEntryScreen> {
  late final TextEditingController _weight;
  late final String? _lastLabel;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = AppStoreScope.read(context);
    final previous = store.recentWeights.lastOrNull;
    _weight = TextEditingController(
      text: previous == null ? '' : formatWeight(previous.weightKg),
    );
    _lastLabel = previous == null
        ? null
        : '上次 ${formatWeight(previous.weightKg)} kg · '
              '${previous.measuredAt.month}/${previous.measuredAt.day}';
  }

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  void _save() {
    final kilograms = double.tryParse(_weight.text.trim());
    if (kilograms == null || kilograms < _minKg || kilograms > _maxKg) {
      setState(() => _error = '請輸入 $_minKg – $_maxKg 之間的公斤數。');
      return;
    }
    AppStoreScope.read(context).recordWeight(kilograms, note: _note);
    Navigator.of(context).pop();
    showToast(
      context,
      '已記錄 ${formatWeight(kilograms)} kg',
      kind: ToastKind.success,
    );
  }

  /// What the reading is, so a later trend can tell morning weights from
  /// weights taken at any hour.
  String get _note => '手動輸入';

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '體重', subtitle: '手動輸入'),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        Gutter(
          child: AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    onTapOutside: dismissKeyboardOnTapOutside,
                    controller: _weight,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onSubmitted: (_) => _save(),
                    style: AppTextStyles.hugeNumber,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: '0.0',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('kg', style: AppTextStyles.itemTitle),
                ),
              ],
            ),
          ),
        ),
        if (_error case final error?)
          Gutter(
            child: InfoBanner(tone: CardTone.warning, message: error),
          ),
        if (_lastLabel case final label?)
          Gutter(child: Text(label, style: AppTextStyles.caption)),
        Gutter(
          child: const Text(
            '體重每天會有波動，趨勢看的是一段時間的方向，不是單日數字。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
