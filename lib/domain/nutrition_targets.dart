/// How much a day's food is aimed at: energy, the macronutrients, and
/// the few limits a label lets a day be checked against.
library;

/// How active a day usually is, as the multiplier on resting energy
/// (the physical activity levels used with Mifflin-St Jeor).
enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  active(1.725),
  veryActive(1.9);

  const ActivityLevel(this.factor);
  final double factor;
}

/// What the energy target is for: how fast body weight should move, as
/// a share of it a week, and the protein a day aimed at this usually
/// takes, both of which the user can override.
///
/// A rate rather than a fixed offset, because 500 kcal a day means more
/// to someone of 60 kg than of 100 kg. Losing 0.5–1 % a week keeps most
/// lean mass (Helms 2014, Garthe 2011), toward the slow end the leaner
/// someone is; gaining faster than about 0.25 % a week adds mostly fat
/// once someone has trained a while (Helms 2023). More protein while
/// losing keeps more lean mass (Helms 2014, Longland 2016); 1.6 g per kg
/// is where gains level off otherwise (Morton 2018), a little above it
/// while gaining.
///
/// Recomposing, gaining muscle while losing fat, holds weight nearly
/// still: a deficit slows lean mass gains, which stop at about 500 kcal
/// a day (Murphy 2022), and both a small deficit and maintenance with
/// high protein recompose trained people (Vargas-Molina 2026). Protein
/// stays high, a little lower at maintenance, inside the 1.6–2.2 g per
/// kg the meta-analyses support (Morton 2018, Nunes 2022).
enum WeightGoal {
  lose([-0.25, -0.5, -0.75], -0.5),
  recomp([-0.25, 0], -0.25),
  maintain([0], 0),
  gain([0.1, 0.25], 0.25);

  const WeightGoal(this.weeklyPercents, this.defaultWeeklyPercent);

  /// The rates offered, % of body weight a week; negative is losing.
  final List<double> weeklyPercents;
  final double defaultWeeklyPercent;

  /// Protein a day per kg of body weight, at [weeklyPercent].
  double proteinPerKgAt(double weeklyPercent) => switch (this) {
    lose => 2.2,
    recomp => weeklyPercent < 0 ? 2.2 : 2.0,
    maintain => 1.6,
    gain => 1.8,
  };
}

/// What the user chose for their targets. The energy target is either
/// typed in ([customKcal]) or worked out from the body; protein follows
/// the goal and fat a default share unless the user set them.
class NutritionTargetSettings {
  const NutritionTargetSettings({
    this.customKcal,
    this.activity = ActivityLevel.moderate,
    this.goal = WeightGoal.maintain,
    this.weeklyPercent,
    this.proteinPerKg,
    this.fatPercent,
  });

  /// Fat as a share of energy, inside the 20–35 % the DRIs give adults
  /// and the 15–30 % Helms 2014 gives lifters; no goal calls for another.
  static const defaultFatPercent = 25;

  /// The energy target typed in; null to work it out from the body. A
  /// figure of the user's own, so it keeps whatever they typed.
  final double? customKcal;
  final ActivityLevel activity;
  final WeightGoal goal;

  /// The rate the user picked from [WeightGoal.weeklyPercents]; null
  /// for the goal's default.
  final double? weeklyPercent;

  /// Protein per kg the user set; null to follow [goal].
  final double? proteinPerKg;

  /// Fat as a share of energy the user set; null for [defaultFatPercent].
  final int? fatPercent;

  bool get isCustom => customKcal != null;

  /// The rate in use: the one picked, when it is one this goal offers.
  double get weeklyPercentInUse => switch (weeklyPercent) {
    final picked? when goal.weeklyPercents.contains(picked) => picked,
    _ => goal.defaultWeeklyPercent,
  };

  /// Protein per kg as the goal sets it, at the rate in use.
  double get goalProteinPerKg => goal.proteinPerKgAt(weeklyPercentInUse);

  double get proteinPerKgInUse => proteinPerKg ?? goalProteinPerKg;
  int get fatPercentInUse => fatPercent ?? defaultFatPercent;

  NutritionTargetSettings copyWith({
    double? Function()? customKcal,
    ActivityLevel? activity,
    WeightGoal? goal,
    double? Function()? weeklyPercent,
    double? Function()? proteinPerKg,
    int? Function()? fatPercent,
  }) => NutritionTargetSettings(
    customKcal: customKcal == null ? this.customKcal : customKcal(),
    activity: activity ?? this.activity,
    goal: goal ?? this.goal,
    weeklyPercent: weeklyPercent == null ? this.weeklyPercent : weeklyPercent(),
    proteinPerKg: proteinPerKg == null ? this.proteinPerKg : proteinPerKg(),
    fatPercent: fatPercent == null ? this.fatPercent : fatPercent(),
  );
}

/// Where a day's maintenance energy came from.
enum MaintenanceSource {
  /// Resting energy by equation times the activity level.
  formula,

  /// Energy eaten less what the body stored or gave up, over the recent
  /// weeks of complete food days and weighings.
  measured,
}

/// What working out the energy target still needs.
enum TargetInput { weight, height, birthYear, sex }

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
    this.maintenanceKcal,
    this.maintenanceSource,
    this.missing = const [],
  });

  /// The day's targets, kept as the sums they come out of rather than
  /// rounded: a typed-in energy target is the user's own figure, and the
  /// macronutrients it leaves room for follow it exactly.
  final double? kcal;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;
  final double? fibreGrams;

  /// Resting energy from the equation, when the target was worked out.
  final double? restingKcal;

  /// Energy to keep weight where it is, when the target was worked out:
  /// what the goal's rate moves away from.
  final double? maintenanceKcal;

  /// How [maintenanceKcal] was worked out; null without it.
  final MaintenanceSource? maintenanceSource;

  /// What working out the energy target lacks; empty when it did not
  /// need to (a typed-in target) or had everything.
  final List<TargetInput> missing;
}
