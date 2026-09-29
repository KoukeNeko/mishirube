import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/trend_insights.dart' show energyWindowDays;
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../journal/body_reading_entry_screen.dart';
import '../journal/weight_entry_screen.dart';
import '../me/me_screen.dart';
import 'nutrition_view_model.dart';
import '../../l10n/l10n.dart';

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
      title: context.l10n.dailyKcalGoal,
      keyboardType: TextInputType.number,
      initial: '${settings.customKcal ?? ''}',
      hint: 'kcal',
    );
    if (typed == null) return;
    final kcal = double.tryParse(typed.trim());
    if (kcal == null || kcal < 800 || kcal > 6000) {
      if (mounted) {
        showToast(
          context,
          context.l10n.kcalRangeError,
          kind: ToastKind.warning,
        );
      }
      return;
    }
    _update(settings.copyWith(customKcal: () => kcal));
  }

  /// Asks for a number within [min]–[max]. [fallback] names what is used
  /// when [initial] is null; leaving the field empty goes back to it,
  /// which [onValue] hears as null.
  Future<void> _typeNumber({
    required String title,
    required num? initial,
    required String fallback,
    required double min,
    required double max,
    required ValueChanged<double?> onValue,
  }) async {
    final typed = await showTextDialog(
      context,
      title: title,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      initial: initial == null ? '' : formatAmount(initial.toDouble()),
      hint: fallback,
    );
    if (typed == null) return;
    if (typed.trim().isEmpty) return onValue(null);
    final value = double.tryParse(typed.trim());
    if (value == null || value < min || value > max) {
      if (mounted) {
        showToast(
          context,
          context.l10n.numberRangeError(
            min: formatAmount(min),
            max: formatAmount(max),
          ),
          kind: ToastKind.warning,
        );
      }
      return;
    }
    onValue(value);
  }

  /// Picks how fast the goal moves body weight, from the rates it offers.
  Future<void> _pickRate(
    NutritionTargetSettings settings,
    double? weightKg,
  ) async {
    final rate = await showAppDialog<double>(
      context,
      AppDialog(
        title: context.l10n.weeklyChange,
        isChoiceList: true,
        actions: [
          for (final rate in settings.goal.weeklyPercents)
            DialogAction(
              label: _rateLabel(rate, weightKg),
              isSelected: rate == settings.weeklyPercentInUse,
              onTap: () => Navigator.of(context).pop(rate),
            ),
        ],
      ),
    );
    if (rate != null) _update(settings.copyWith(weeklyPercent: () => rate));
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
      appBar: PageAppBar(title: context.l10n.dailyTargets),
      children: [
        PageSection(
          label: context.l10n.kcalTarget,
          children: [
            Gutter(
              child: RadioRow(
                title: context.l10n.estimateFromBody,
                subtitle: context.l10n.estimateFromBodyDetail,
                isSelected: !settings.isCustom,
                onTap: () => _update(settings.copyWith(customKcal: () => null)),
              ),
            ),
            Gutter(
              child: RadioRow(
                title: context.l10n.setMyself,
                subtitle: settings.customKcal == null
                    ? context.l10n.notSet
                    : '${formatKcal(settings.customKcal!)} kcal',
                isSelected: settings.isCustom,
                onTap: _typeKcal,
              ),
            ),
          ],
        ),
        if (!settings.isCustom) ...[
          PageSection(
            label: context.l10n.bodyData,
            children: [
              Gutter(
                child: GroupedCard(
                  children: [
                    NavRow(
                      title: context.l10n.moduleWeight,
                      trailing: _value(
                        weight == null
                            ? context.l10n.notSet
                            : '${formatWeight(weight.weightKg)} kg',
                      ),
                      onTap: () => pushModalPage<void>(
                        context,
                        const WeightEntryScreen(),
                      ),
                    ),
                    NavRow(
                      title: context.l10n.bodyMetricHeight,
                      trailing: _value(
                        height == null
                            ? context.l10n.notSet
                            : '${formatAmount(height)} cm',
                      ),
                      onTap: () => pushModalPage<void>(
                        context,
                        const BodyReadingEntryScreen(only: BodyMetric.height),
                      ),
                    ),
                    NavRow(
                      title: context.l10n.targetInputBirthYear,
                      trailing: _value(switch (_nutrition.birthYear) {
                        final year? => context.l10n.yearValue(year: year),
                        null => context.l10n.notSet,
                      }),
                      onTap: () => editBirthYear(context),
                    ),
                    NavRow(
                      title: context.l10n.targetInputSex,
                      trailing: _value(
                        _nutrition.sex?.labelIn(context.l10n) ??
                            context.l10n.notSet,
                      ),
                      onTap: () => pickSex(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          PageSection(
            label: context.l10n.activityLevelSection,
            children: [
              for (final level in ActivityLevel.values)
                Gutter(
                  child: RadioRow(
                    title: level.labelIn(context.l10n),
                    subtitle: level.detailIn(context.l10n),
                    isSelected: level == settings.activity,
                    onTap: () => _update(settings.copyWith(activity: level)),
                  ),
                ),
            ],
          ),
          PageSection(
            label: context.l10n.purposeSection,
            children: [
              Gutter(
                child: ChipWrap(
                  options: WeightGoal.values,
                  labelOf: (goal) => goal.labelIn(context.l10n),
                  isSelected: (goal) => goal == settings.goal,
                  // A rate picked for one goal means nothing for another.
                  onTap: (goal) => _update(
                    settings.copyWith(goal: goal, weeklyPercent: () => null),
                  ),
                  selectedColor: AppColors.nutrition,
                ),
              ),
              if (settings.goal.weeklyPercents.length > 1)
                Gutter(
                  child: GroupedCard(
                    children: [
                      NavRow(
                        title: context.l10n.weeklyChange,
                        trailing: _value(
                          _rateLabel(
                            settings.weeklyPercentInUse,
                            weight?.weightKg,
                          ),
                        ),
                        onTap: () => _pickRate(settings, weight?.weightKg),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        PageSection(
          label: context.l10n.macroSplit,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: _nutrition.convention.proteinName(context.l10n),
                    subtitle: [
                      if (settings.proteinPerKg == null) context.l10n.byGoal,
                      context.l10n.perKgBodyWeight(
                        grams: formatAmount(settings.proteinPerKgInUse),
                      ),
                    ].join(' · '),
                    trailing: _value(_grams(targets.proteinGrams)),
                    onTap: () => _typeNumber(
                      title: context.l10n.proteinPerKgTitle,
                      initial: settings.proteinPerKg,
                      fallback: context.l10n.byGoalGrams(
                        grams: formatAmount(settings.goalProteinPerKg),
                      ),
                      min: 0.8,
                      max: 3,
                      onValue: (value) =>
                          _update(settings.copyWith(proteinPerKg: () => value)),
                    ),
                  ),
                  NavRow(
                    title: _nutrition.convention.fatName(context.l10n),
                    subtitle: context.l10n.percentOfKcal(
                      percent: settings.fatPercentInUse,
                    ),
                    trailing: _value(_grams(targets.fatGrams)),
                    onTap: () => _typeNumber(
                      title: context.l10n.fatPercentTitle,
                      initial: settings.fatPercent,
                      fallback: context.l10n.defaultPercent(
                        percent: NutritionTargetSettings.defaultFatPercent,
                      ),
                      min: 15,
                      max: 45,
                      onValue: (value) => _update(
                        settings.copyWith(fatPercent: () => value?.round()),
                      ),
                    ),
                  ),
                  NavRow(
                    title: _nutrition.convention.carbName(context.l10n),
                    subtitle: context.l10n.restOfKcal,
                    trailing: _value(_grams(targets.carbGrams)),
                    showChevron: false,
                  ),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: context.l10n.resultSection,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  if (targets.restingKcal case final resting?)
                    KeyValueRow(
                      label: context.l10n.restingMetabolism,
                      value: '${formatKcal(resting)} kcal',
                    ),
                  if (targets.maintenanceKcal case final maintenance?
                      when settings.goal != WeightGoal.maintain)
                    KeyValueRow(
                      label: context.l10n.maintenanceKcal,
                      value: '${formatKcal(maintenance)} kcal',
                    ),
                  KeyValueRow(
                    label: context.l10n.dailyKcal,
                    value: switch (targets.kcal) {
                      final kcal? => '${formatKcal(kcal)} kcal',
                      null => context.l10n.missingInputs(
                        inputs: joinList(
                          context.l10n,
                          targets.missing.map((i) => i.labelIn(context.l10n)),
                        ),
                      ),
                    },
                  ),
                  KeyValueRow(
                    label: _nutrition.convention.fibreName(context.l10n),
                    value: _grams(targets.fibreGrams),
                  ),
                  KeyValueRow(
                    label: _nutrition.convention.nameOf(
                      context.l10n,
                      _nutrition.convention.saltMeasure,
                    ),
                    value:
                        _nutrition.convention.saltMeasure.unit ==
                            NutrientUnit.milligram
                        ? context.l10n.limitValue(
                            value:
                                '${formatKcal(_nutrition.saltLimit.round())} mg',
                          )
                        : context.l10n.limitValue(
                            value: '${formatAmount(_nutrition.saltLimit)} g',
                          ),
                  ),
                ],
              ),
            ),
            if (targets.maintenanceSource case final source?)
              Gutter(
                child: TagWrap(
                  labels: [
                    switch (source) {
                      MaintenanceSource.measured =>
                        context.l10n.fromRecentFoodAndWeight(
                          days: energyWindowDays,
                        ),
                      MaintenanceSource.formula => context.l10n.mifflinEstimate,
                    },
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Widget _value(String text) => Text(text, style: AppTextStyles.caption);

String _grams(num? grams) =>
    grams == null ? '—' : '${formatAmount(grams.toDouble())} g';

/// `−0.5% · −0.35 kg`: a weekly rate, and what it is for this body
/// when its weight is known.
String _rateLabel(double weeklyPercent, double? weightKg) {
  String signed(num value, String text) => '${value < 0 ? '−' : '+'}$text';
  // Maintenance: nothing to sign, and no weight to move.
  if (weeklyPercent == 0) return '0%';
  // Two places, trailing zeros dropped: the rates are 0.1, 0.25 and
  // 0.75, which one decimal would round away.
  final digits = weeklyPercent
      .abs()
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');
  final percent = signed(weeklyPercent, '$digits%');
  if (weightKg == null) return percent;
  final kg = weightKg * weeklyPercent / 100;
  return '$percent · ${signed(kg, kg.abs().toStringAsFixed(2))} kg';
}
