import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/body_reading_entry_screen.dart';
import '../journal/weight_entry_screen.dart';
import '../me/me_screen.dart';
import 'nutrition_view_model.dart';

/// The daily targets: an energy target typed in or worked out from the
/// body, and how it splits into protein, fat and carbohydrate. Every
/// change is kept as it is made.
class NutritionTargetScreen extends StatefulWidget {
  const NutritionTargetScreen({super.key});

  @override
  State<NutritionTargetScreen> createState() => _NutritionTargetScreenState();
}

class _NutritionTargetScreenState extends State<NutritionTargetScreen> {
  late final NutritionViewModel _nutrition;

  @override
  void initState() {
    super.initState();
    _nutrition = NutritionViewModel(AppStoreScope.read(context).backend);
  }

  @override
  void dispose() {
    _nutrition.dispose();
    super.dispose();
  }

  void _update(NutritionTargetSettings settings) =>
      _nutrition.setTargetSettings(settings);

  Future<void> _typeKcal() async {
    final settings = _nutrition.targetSettings;
    final typed = await showTextDialog(
      context,
      title: '每日熱量目標',
      keyboardType: TextInputType.number,
      initial: '${settings.customKcal ?? ''}',
      hint: 'kcal',
    );
    if (typed == null) return;
    final kcal = int.tryParse(typed.trim());
    if (kcal == null || kcal < 800 || kcal > 6000) {
      if (mounted) {
        showToast(context, '請填 800–6000 kcal。', kind: ToastKind.warning);
      }
      return;
    }
    _update(settings.copyWith(customKcal: () => kcal));
  }

  Future<void> _typeNumber({
    required String title,
    required String hint,
    required num initial,
    required double min,
    required double max,
    required ValueChanged<double> onValue,
  }) async {
    final typed = await showTextDialog(
      context,
      title: title,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      initial: formatAmount(initial.toDouble()),
      hint: hint,
    );
    final value = double.tryParse(typed?.trim() ?? '');
    if (typed == null) return;
    if (value == null || value < min || value > max) {
      if (mounted) {
        showToast(
          context,
          '請填 ${formatAmount(min)}–${formatAmount(max)}。',
          kind: ToastKind.warning,
        );
      }
      return;
    }
    onValue(value);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _nutrition,
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final settings = _nutrition.targetSettings;
    final today = _nutrition.now();
    final targets = _nutrition.targetsOn(today);
    final weight = _nutrition.weightOn(today);
    final height = _nutrition.heightCm;
    return DetailPage(
      appBar: const PageAppBar(title: '每日目標'),
      children: [
        PageSection(
          label: '熱量目標',
          children: [
            Gutter(
              child: RadioRow(
                title: '依身體資料估算',
                subtitle: '體重、身高、年齡、性別與活動量',
                isSelected: !settings.isCustom,
                onTap: () => _update(settings.copyWith(customKcal: () => null)),
              ),
            ),
            Gutter(
              child: RadioRow(
                title: '自己設定',
                subtitle: settings.customKcal == null
                    ? '未設定'
                    : '${formatKcal(settings.customKcal!)} kcal',
                isSelected: settings.isCustom,
                onTap: _typeKcal,
              ),
            ),
          ],
        ),
        if (!settings.isCustom) ...[
          PageSection(
            label: '身體資料',
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    NavRow(
                      title: '體重',
                      trailing: _value(
                        weight == null
                            ? '未設定'
                            : '${formatWeight(weight.weightKg)} kg',
                      ),
                      onTap: () => pushModalPage<void>(
                        context,
                        const WeightEntryScreen(),
                      ),
                    ),
                    NavRow(
                      title: '身高',
                      trailing: _value(
                        height == null ? '未設定' : '${formatAmount(height)} cm',
                      ),
                      onTap: () => pushModalPage<void>(
                        context,
                        const BodyReadingEntryScreen(only: BodyMetric.height),
                      ),
                    ),
                    NavRow(
                      title: '出生年',
                      trailing: _value(switch (_nutrition.birthYear) {
                        final year? => '$year 年',
                        null => '未設定',
                      }),
                      onTap: () => editBirthYear(context),
                    ),
                    NavRow(
                      title: '性別',
                      trailing: _value(_nutrition.sex?.label ?? '未設定'),
                      onTap: () => pickSex(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          PageSection(
            label: '活動量',
            children: [
              for (final level in ActivityLevel.values)
                Gutter(
                  child: RadioRow(
                    title: level.label,
                    subtitle: level.detail,
                    isSelected: level == settings.activity,
                    onTap: () => _update(settings.copyWith(activity: level)),
                  ),
                ),
            ],
          ),
          PageSection(
            label: '目的',
            children: [
              Gutter(
                child: ChipWrap(
                  options: WeightGoal.values,
                  labelOf: (goal) => goal.kcalOffset == 0
                      ? goal.label
                      : '${goal.label} '
                            '${goal.kcalOffset > 0 ? '+' : '−'}'
                            '${goal.kcalOffset.abs()} kcal',
                  isSelected: (goal) => goal == settings.goal,
                  onTap: (goal) => _update(settings.copyWith(goal: goal)),
                  selectedColor: AppColors.nutrition,
                ),
              ),
            ],
          ),
        ],
        PageSection(
          label: '營養素分配',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: MacroLabel.protein,
                    subtitle: '每公斤體重 ${formatAmount(settings.proteinPerKg)} g',
                    trailing: _value(_grams(targets.proteinGrams)),
                    onTap: () => _typeNumber(
                      title: '蛋白質（每公斤體重）',
                      hint: 'g',
                      initial: settings.proteinPerKg,
                      min: 0.8,
                      max: 3,
                      onValue: (value) =>
                          _update(settings.copyWith(proteinPerKg: value)),
                    ),
                  ),
                  NavRow(
                    title: MacroLabel.fat,
                    subtitle: '熱量的 ${settings.fatPercent}%',
                    trailing: _value(_grams(targets.fatGrams)),
                    onTap: () => _typeNumber(
                      title: '脂肪（占熱量 %）',
                      hint: '%',
                      initial: settings.fatPercent,
                      min: 15,
                      max: 45,
                      onValue: (value) =>
                          _update(settings.copyWith(fatPercent: value.round())),
                    ),
                  ),
                  NavRow(
                    title: MacroLabel.carb,
                    subtitle: '其餘的熱量',
                    trailing: _value(_grams(targets.carbGrams)),
                    showChevron: false,
                  ),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: '結果',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  if (targets.restingKcal case final resting?)
                    KeyValueRow(
                      label: '基礎代謝',
                      value: '${formatKcal(resting)} kcal',
                    ),
                  KeyValueRow(
                    label: '每日熱量',
                    value: switch (targets.kcal) {
                      final kcal? => '${formatKcal(kcal)} kcal',
                      null =>
                        '缺少${targets.missing.map((i) => i.label).join('、')}',
                    },
                  ),
                  KeyValueRow(
                    label: MacroLabel.fibre,
                    value: _grams(targets.fibreGrams),
                  ),
                  KeyValueRow(
                    label: Nutrient.sodium.label,
                    value:
                        '上限 ${formatKcal(NutritionTargets.sodiumLimitMg)} mg',
                  ),
                ],
              ),
            ),
            if (targets.restingKcal != null)
              Gutter(
                child: Text(
                  'Mifflin-St Jeor 估計',
                  style: AppTextStyles.caption,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Widget _value(String text) => Text(text, style: AppTextStyles.caption);

String _grams(int? grams) => grams == null ? '—' : '$grams g';
