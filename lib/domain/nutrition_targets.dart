/// How much a day's food is aimed at: energy, the macronutrients, and
/// the few limits a label lets a day be checked against.
library;

/// How active a day usually is, as the multiplier on resting energy
/// (the physical activity levels used with Mifflin-St Jeor).
enum ActivityLevel {
  sedentary('久坐', '幾乎不運動', 1.2),
  light('輕度', '每週運動 1–3 天', 1.375),
  moderate('中度', '每週運動 3–5 天', 1.55),
  active('高度', '每週運動 6–7 天', 1.725),
  veryActive('非常高', '體力勞動或一天兩練', 1.9);

  const ActivityLevel(this.label, this.detail, this.factor);

  final String label;
  final String detail;
  final double factor;
}

/// What the energy target is for, as a daily offset from maintenance.
enum WeightGoal {
  lose('減脂', -500),
  maintain('維持', 0),
  gain('增肌', 300);

  const WeightGoal(this.label, this.kcalOffset);

  final String label;
  final int kcalOffset;
}

/// What the user chose for their targets. The energy target is either
/// typed in ([customKcal]) or worked out from the body; the split into
/// macronutrients is the same either way.
class NutritionTargetSettings {
  const NutritionTargetSettings({
    this.customKcal,
    this.activity = ActivityLevel.moderate,
    this.goal = WeightGoal.maintain,
    this.proteinPerKg = defaultProteinPerKg,
    this.fatPercent = defaultFatPercent,
  });

  /// Protein for someone who trains: the middle of the 1.4–2.0 g per kg
  /// a day the ISSN position stand gives.
  static const defaultProteinPerKg = 1.6;

  /// Fat as a share of energy, inside the 20–35 % the DRIs give adults.
  static const defaultFatPercent = 25;

  /// The energy target typed in; null to work it out from the body.
  final int? customKcal;
  final ActivityLevel activity;
  final WeightGoal goal;
  final double proteinPerKg;
  final int fatPercent;

  bool get isCustom => customKcal != null;

  NutritionTargetSettings copyWith({
    int? Function()? customKcal,
    ActivityLevel? activity,
    WeightGoal? goal,
    double? proteinPerKg,
    int? fatPercent,
  }) => NutritionTargetSettings(
    customKcal: customKcal == null ? this.customKcal : customKcal(),
    activity: activity ?? this.activity,
    goal: goal ?? this.goal,
    proteinPerKg: proteinPerKg ?? this.proteinPerKg,
    fatPercent: fatPercent ?? this.fatPercent,
  );
}

/// What working out the energy target still needs.
enum TargetInput {
  weight('體重'),
  height('身高'),
  birthYear('出生年'),
  sex('性別');

  const TargetInput(this.label);

  final String label;
}

/// A day's targets. Null where there is nothing to aim at yet: without a
/// weight there is no protein target, without an energy target no split.
class NutritionTargets {
  const NutritionTargets({
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.restingKcal,
    this.missing = const [],
  });

  final int? kcal;
  final int? proteinGrams;
  final int? carbGrams;
  final int? fatGrams;
  final int? fibreGrams;

  /// Resting energy from the equation, when the target was worked out.
  final int? restingKcal;

  /// What working out the energy target lacks; empty when it did not
  /// need to (a typed-in target) or had everything.
  final List<TargetInput> missing;

  /// Sodium a day, at most: the 2,400 mg Taiwan's Health Promotion
  /// Administration sets for adults.
  static const sodiumLimitMg = 2400;
}
