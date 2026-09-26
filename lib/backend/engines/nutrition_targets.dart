import 'dart:math' as math;

import '../../domain/domain.dart';

/// Bumped whenever a rule below changes.
const nutritionTargetsVersion = 4;

/// Fibre per 1,000 kcal eaten: the Adequate Intake the Dietary Reference
/// Intakes set, 14 g per 1,000 kcal.
const fibreGramsPer1000Kcal = 14;

/// Resting energy by Mifflin-St Jeor (1990), the equation the Academy of
/// Nutrition and Dietetics found closest to measured resting energy in
/// healthy adults.
int restingEnergyKcal({
  required double weightKg,
  required double heightCm,
  required int age,
  required Sex sex,
}) =>
    (10 * weightKg +
            6.25 * heightCm -
            5 * age +
            switch (sex) {
              Sex.male => 5,
              Sex.female => -161,
            })
        .round();

/// Energy per kg of body weight gained or lost, to turn a weekly rate
/// into a daily difference: the familiar 7,700 kcal, a rough figure to
/// start from. What a kg really holds moves with body composition and
/// with time (Hall 2008), which only the user's own intake and weight
/// can show.
const kcalPerKgBodyWeight = 7700;

/// The daily energy difference that moves [weightKg] by [weeklyPercent]
/// of it a week; negative is a deficit.
int dailyKcalForRate(double weightKg, double weeklyPercent) =>
    (weightKg * weeklyPercent / 100 * kcalPerKgBodyWeight / 7).round();

/// A day's targets from what the user chose and what is known of them.
///
/// A typed-in energy target is taken as it is. Otherwise it is
/// maintenance moved by the goal's weekly rate: [measuredMaintenanceKcal]
/// when the user's own intake and weight have shown it, which the
/// equations cannot match for one person, else resting energy times
/// [NutritionTargetSettings.activity];
/// null, with what is [NutritionTargets.missing], until the body is
/// known well enough. Protein goes by weight, fat by share of energy,
/// both as the goal sets them unless the user did, and carbohydrate
/// takes what is left.
NutritionTargets nutritionTargets(
  NutritionTargetSettings settings, {
  double? weightKg,
  double? heightCm,
  int? age,
  Sex? sex,
  int? measuredMaintenanceKcal,
}) {
  // Maintenance the records have shown needs only the weight, for the
  // rate; the equation needs the whole body.
  final missing = settings.isCustom
      ? const <TargetInput>[]
      : [
          if (weightKg == null) TargetInput.weight,
          if (measuredMaintenanceKcal == null) ...[
            if (heightCm == null) TargetInput.height,
            if (age == null) TargetInput.birthYear,
            if (sex == null) TargetInput.sex,
          ],
        ];
  final resting =
      !settings.isCustom &&
          weightKg != null &&
          heightCm != null &&
          age != null &&
          sex != null
      ? restingEnergyKcal(
          weightKg: weightKg,
          heightCm: heightCm,
          age: age,
          sex: sex,
        )
      : null;
  // Maintenance below resting energy is food missing from the records,
  // not a body running on less: the equation stands in for it.
  final measured = switch (measuredMaintenanceKcal) {
    final measured? when resting == null || measured >= resting => measured,
    _ => null,
  };
  final maintenance =
      measured ??
      switch (resting) {
        final resting? => (resting * settings.activity.factor).round(),
        null => null,
      };
  final kcal =
      settings.customKcal ??
      switch ((maintenance, weightKg)) {
        (final maintenance?, final weightKg?) =>
          maintenance + dailyKcalForRate(weightKg, settings.weeklyPercentInUse),
        _ => null,
      };
  final protein = weightKg == null
      ? null
      : (weightKg * settings.proteinPerKgInUse).round();
  final fat = kcal == null
      ? null
      : (kcal * settings.fatPercentInUse / 100 / 9).round();
  final carb = kcal == null || protein == null || fat == null
      ? null
      : math.max(0, ((kcal - protein * 4 - fat * 9) / 4).round());
  return NutritionTargets(
    kcal: kcal,
    proteinGrams: protein,
    carbGrams: carb,
    fatGrams: fat,
    fibreGrams: kcal == null
        ? null
        : (kcal / 1000 * fibreGramsPer1000Kcal).round(),
    restingKcal: resting,
    maintenanceKcal: settings.isCustom ? null : maintenance,
    maintenanceSource: settings.isCustom || maintenance == null
        ? null
        : measured != null
        ? MaintenanceSource.measured
        : MaintenanceSource.formula,
    missing: missing,
  );
}
