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

/// What the energy target is for: a daily offset from maintenance, and
/// the protein a day aimed at this usually takes, which the user can
/// override. More protein while losing fat keeps more lean mass
/// (Helms 2014, Longland 2016); 1.6 g per kg is where gains level off
/// otherwise (Morton 2018), a little above it while gaining.
enum WeightGoal {
  lose('減脂', -500, 2.2),
  maintain('維持', 0, 1.6),
  gain('增肌', 300, 1.8);

  const WeightGoal(this.label, this.kcalOffset, this.proteinPerKg);

  final String label;
  final int kcalOffset;

  /// Protein a day per kg of body weight.
  final double proteinPerKg;
}

/// What the user chose for their targets. The energy target is either
/// typed in ([customKcal]) or worked out from the body; protein follows
/// the goal and fat a default share unless the user set them.
class NutritionTargetSettings {
  const NutritionTargetSettings({
    this.customKcal,
    this.activity = ActivityLevel.moderate,
    this.goal = WeightGoal.maintain,
    this.proteinPerKg,
    this.fatPercent,
  });

  /// Fat as a share of energy, inside the 20–35 % the DRIs give adults
  /// and the 15–30 % Helms 2014 gives lifters; no goal calls for another.
  static const defaultFatPercent = 25;

  /// The energy target typed in; null to work it out from the body.
  final int? customKcal;
  final ActivityLevel activity;
  final WeightGoal goal;

  /// Protein per kg the user set; null to follow [goal].
  final double? proteinPerKg;

  /// Fat as a share of energy the user set; null for [defaultFatPercent].
  final int? fatPercent;

  bool get isCustom => customKcal != null;

  double get proteinPerKgInUse => proteinPerKg ?? goal.proteinPerKg;
  int get fatPercentInUse => fatPercent ?? defaultFatPercent;

  NutritionTargetSettings copyWith({
    int? Function()? customKcal,
    ActivityLevel? activity,
    WeightGoal? goal,
    double? Function()? proteinPerKg,
    int? Function()? fatPercent,
  }) => NutritionTargetSettings(
    customKcal: customKcal == null ? this.customKcal : customKcal(),
    activity: activity ?? this.activity,
    goal: goal ?? this.goal,
    proteinPerKg: proteinPerKg == null ? this.proteinPerKg : proteinPerKg(),
    fatPercent: fatPercent == null ? this.fatPercent : fatPercent(),
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
