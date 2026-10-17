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
    final l10n = context.l10n;
    final convention = _nutrition.convention;
    Segment row({
      required String title,
      String? caption,
      required String value,
      VoidCallback? onTap,
    }) => Segment(
      onTap: onTap,
      child: SegmentRow(
        title: title,
        caption: caption,
        value: value,
        showsChevron: onTap != null,
      ),
    );
    Segment figure(String label, String value) => Segment(
      child: SegmentStat(
        label: label,
        color: AppColors.nutrition,
        placeholder: '—',
        value: value,
        valueSize: 20,
      ),
    );
    final kcal = targets.kcal;
    final figures = [
      if (targets.restingKcal case final resting?)
        figure(l10n.restingMetabolism, '${formatKcal(resting)} kcal'),
      if (targets.maintenanceKcal case final maintenance?
          when settings.goal != WeightGoal.maintain)
        figure(l10n.maintenanceKcal, '${formatKcal(maintenance)} kcal'),
      figure(convention.fibreName(l10n), _grams(targets.fibreGrams)),
      figure(
        convention.nameOf(l10n, convention.saltMeasure),
        l10n.limitValue(
          value: convention.saltMeasure.unit == NutrientUnit.milligram
              ? '${formatKcal(_nutrition.saltLimit.round())} mg'
              : '${formatAmount(_nutrition.saltLimit)} g',
        ),
      ),
    ];
    return DetailPage(
      appBar: PageAppBar(title: l10n.dailyTargets),
      children: [
        // What the choices below add up to, at the top where each change
        // shows.
        Gutter(
          child: CategoryGroup(
            label: l10n.resultSection,
            color: AppColors.nutrition,
            children: [
              SegmentedGroup(
                rows: [
                  [
                    Segment(
                      surface: AppColors.surfaceRaised,
                      child: kcal == null
                          ? SegmentStat(
                              label: l10n.dailyKcal,
                              color: AppColors.nutrition,
                              placeholder: l10n.missingInputs(
                                inputs: joinList(
                                  l10n,
                                  targets.missing.map((i) => i.labelIn(l10n)),
                                ),
                              ),
                            )
                          : SegmentHero(
                              label: l10n.dailyKcal,
                              color: AppColors.nutrition,
                              value: formatKcal(kcal),
                              unit: 'kcal',
                            ),
                    ),
                  ],
                  for (var i = 0; i < figures.length; i += 2)
                    figures.sublist(
                      i,
                      i + 2 > figures.length ? figures.length : i + 2,
                    ),
                ],
              ),
              if (targets.maintenanceSource case final source?)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: TagWrap(
                    labels: [
                      switch (source) {
                        MaintenanceSource.measured =>
                          l10n.fromRecentFoodAndWeight(days: energyWindowDays),
                        MaintenanceSource.formula => l10n.mifflinEstimate,
                      },
                    ],
                  ),
                ),
            ],
          ),
        ),
        Gutter(
          child: CategoryGroup(
            label: l10n.kcalTarget,
            color: AppColors.nutrition,
            children: [
              SegmentedGroup(
                rows: [
                  [
                    choiceSegment(
                      title: l10n.estimateFromBody,
                      caption: l10n.estimateFromBodyDetail,
                      isSelected: !settings.isCustom,
                      onTap: () =>
                          _update(settings.copyWith(customKcal: () => null)),
                      color: AppColors.nutrition,
                      tint: AppColors.nutritionSurface,
                    ),
                  ],
                  [
                    choiceSegment(
                      title: l10n.setMyself,
                      caption: settings.customKcal == null
                          ? l10n.notSet
                          : '${formatKcal(settings.customKcal!)} kcal',
                      isSelected: settings.isCustom,
                      onTap: _typeKcal,
                      color: AppColors.nutrition,
                      tint: AppColors.nutritionSurface,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (!settings.isCustom) ...[
          Gutter(
            child: CategoryGroup(
              label: l10n.bodyData,
              color: AppColors.body,
              children: [
                SegmentedGroup(
                  rows: [
                    [
                      row(
                        title: l10n.moduleWeight,
                        value: weight == null
                            ? l10n.notSet
                            : '${formatWeight(weight.weightKg)} kg',
                        onTap: () => pushModalPage<void>(
                          context,
                          const WeightEntryScreen(),
                        ),
                      ),
                    ],
                    [
                      row(
                        title: l10n.bodyMetricHeight,
                        value: height == null
                            ? l10n.notSet
                            : '${formatAmount(height)} cm',
                        onTap: () => pushModalPage<void>(
                          context,
                          const BodyReadingEntryScreen(only: BodyMetric.height),
                        ),
                      ),
                    ],
                    [
                      row(
                        title: l10n.targetInputBirthYear,
                        value: switch (_nutrition.birthYear) {
                          final year? => l10n.yearValue(year: year),
                          null => l10n.notSet,
                        },
                        onTap: () => editBirthYear(context),
                      ),
                    ],
                    [
                      row(
                        title: l10n.targetInputSex,
                        value: _nutrition.sex?.labelIn(l10n) ?? l10n.notSet,
                        onTap: () => pickSex(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Gutter(
            child: CategoryGroup(
              label: l10n.activityLevelSection,
              color: AppColors.activity,
              children: [
                SegmentedGroup(
                  rows: [
                    for (final level in ActivityLevel.values)
                      [
                        choiceSegment(
                          title: level.labelIn(l10n),
                          caption: level.detailIn(l10n),
                          isSelected: level == settings.activity,
                          onTap: () =>
                              _update(settings.copyWith(activity: level)),
                          color: AppColors.nutrition,
                          tint: AppColors.nutritionSurface,
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
          Gutter(
            child: CategoryGroup(
              label: l10n.purposeSection,
              color: AppColors.nutrition,
              children: [
                SegmentedGroup(
                  rows: [
                    choiceButtons<WeightGoal>(
                      options: WeightGoal.values,
                      labelOf: (goal) => goal.labelIn(l10n),
                      isSelected: (goal) => goal == settings.goal,
                      // A rate picked for one goal means nothing for another.
                      onTap: (goal) => _update(
                        settings.copyWith(
                          goal: goal,
                          weeklyPercent: () => null,
                        ),
                      ),
                      color: AppColors.nutrition,
                      onColor: AppColors.textPrimary,
                    ),
                    if (settings.goal.weeklyPercents.length > 1)
                      [
                        row(
                          title: l10n.weeklyChange,
                          value: _rateLabel(
                            settings.weeklyPercentInUse,
                            weight?.weightKg,
                          ),
                          onTap: () => _pickRate(settings, weight?.weightKg),
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
        ],
        Gutter(
          child: CategoryGroup(
            label: l10n.macroSplit,
            color: AppColors.macroProtein,
            children: [
              SegmentedGroup(
                rows: [
                  [
                    row(
                      title: convention.proteinName(l10n),
                      caption: [
                        if (settings.proteinPerKg == null) l10n.byGoal,
                        l10n.perKgBodyWeight(
                          grams: formatAmount(settings.proteinPerKgInUse),
                        ),
                      ].join(' · '),
                      value: _grams(targets.proteinGrams),
                      onTap: () => _typeNumber(
                        title: l10n.proteinPerKgTitle,
                        initial: settings.proteinPerKg,
                        fallback: l10n.byGoalGrams(
                          grams: formatAmount(settings.goalProteinPerKg),
                        ),
                        min: 0.8,
                        max: 3,
                        onValue: (value) => _update(
                          settings.copyWith(proteinPerKg: () => value),
                        ),
                      ),
                    ),
                  ],
                  [
                    row(
                      title: convention.fatName(l10n),
                      caption: l10n.percentOfKcal(
                        percent: settings.fatPercentInUse,
                      ),
                      value: _grams(targets.fatGrams),
                      onTap: () => _typeNumber(
                        title: l10n.fatPercentTitle,
                        initial: settings.fatPercent,
                        fallback: l10n.defaultPercent(
                          percent: NutritionTargetSettings.defaultFatPercent,
                        ),
                        min: 15,
                        max: 45,
                        onValue: (value) => _update(
                          settings.copyWith(fatPercent: () => value?.round()),
                        ),
                      ),
                    ),
                  ],
                  [
                    row(
                      title: convention.carbName(l10n),
                      caption: l10n.restOfKcal,
                      value: _grams(targets.carbGrams),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
