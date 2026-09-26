import 'dart:math' as math;

import '../../domain/domain.dart';

/// Bumped whenever a rule below changes.
const nutritionTargetsVersion = 1;

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

/// A day's targets from what the user chose and what is known of them.
///
/// A typed-in energy target is taken as it is. Otherwise it is resting
/// energy times [NutritionTargetSettings.activity], moved by the goal;
/// null, with what is [NutritionTargets.missing], until the body is
/// known well enough. Protein goes by weight, fat by share of energy,
/// and carbohydrate takes what is left.
NutritionTargets nutritionTargets(
  NutritionTargetSettings settings, {
  double? weightKg,
  double? heightCm,
  int? age,
  Sex? sex,
}) {
  final missing = settings.isCustom
      ? const <TargetInput>[]
      : [
          if (weightKg == null) TargetInput.weight,
          if (heightCm == null) TargetInput.height,
          if (age == null) TargetInput.birthYear,
          if (sex == null) TargetInput.sex,
        ];
  final resting = missing.isEmpty && !settings.isCustom
      ? restingEnergyKcal(
          weightKg: weightKg!,
          heightCm: heightCm!,
          age: age!,
          sex: sex!,
        )
      : null;
  final kcal =
      settings.customKcal ??
      switch (resting) {
        final resting? =>
          (resting * settings.activity.factor).round() +
              settings.goal.kcalOffset,
        null => null,
      };
  final protein = weightKg == null
      ? null
      : (weightKg * settings.proteinPerKg).round();
  final fat = kcal == null
      ? null
      : (kcal * settings.fatPercent / 100 / 9).round();
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
    missing: missing,
  );
}
