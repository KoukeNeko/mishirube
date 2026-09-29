import '../app/app_store.dart';
import '../backend/engines/body_metrics.dart';
import '../backend/engines/trend_findings.dart';
import '../domain/domain.dart';
import '../shared/format.dart';
import 'app_localizations.dart';

/// [items] as one list, joined the way the app's language joins them:
/// `胸、背`, `Chest, Back`.
String joinList(AppLocalizations l10n, Iterable<String> items) =>
    items.join(switch (l10n.localeName.split('_').first) {
      'zh' || 'ja' => '、',
      _ => ', ',
    });

/// A meal's stored quality mark in the app's language. A mark the app
/// did not write (an import's) is shown as it was stored.
String qualityTagLabel(AppLocalizations l10n, String tag) => switch (tag) {
  confirmedQualityTag => l10n.qualityConfirmed,
  estimatedPortionQualityTag => l10n.qualityPortionEstimated,
  customFoodQualityTag => l10n.qualityCustomFood,
  quickLogQualityTag => l10n.qualityQuickLog,
  waterQualityTag => l10n.healthDataWater,
  aiDraftQualityTag => l10n.qualityAiEstimate,
  _ => tag,
};

/// A country as the app names it, from its ISO 3166-1 code; the code
/// itself for one it has no name for.
String countryName(AppLocalizations l10n, String code) => switch (code) {
  'TW' => l10n.countryTW,
  'JP' => l10n.countryJP,
  'US' => l10n.countryUS,
  'EU' => l10n.countryEU,
  'AU' => l10n.countryAU,
  'NZ' => l10n.countryNZ,
  'KR' => l10n.countryKR,
  'CN' => l10n.countryCN,
  'CA' => l10n.countryCA,
  _ => code,
};

/// `7-ELEVEN（台灣）`: a chain with the country its figures are for, since
/// the same chain sells different drinks in each. [country] is empty for
/// a brand the user wrote.
String labelOfBrand(AppLocalizations l10n, String brand, String country) =>
    country.isEmpty
    ? brand
    : l10n.brandInCountry(brand: brand, country: countryName(l10n, country));

extension FoodItemBrandText on FoodItem {
  /// The brand with the country its figures are for when the app ships
  /// them; the brand alone for a food the user made.
  String brandLabelIn(AppLocalizations l10n) =>
      labelOfBrand(l10n, brand, country);
}

extension CatalogueRecordText on CatalogueRecord {
  String labelIn(AppLocalizations l10n) => labelOfBrand(l10n, brand, country);
}

/// The app's own names for things, in its language. The things themselves
/// keep no words: they are what records and settings store.
extension AppModuleText on AppModule {
  String title(AppLocalizations l10n) => switch (this) {
    AppModule.nutrition => l10n.moduleNutrition,
    AppModule.water => l10n.healthDataWater,
    AppModule.weight => l10n.moduleWeight,
    AppModule.training => l10n.moduleTraining,
    AppModule.activity => l10n.moduleActivity,
    AppModule.sleep => l10n.moduleSleep,
    AppModule.wellness => l10n.moduleWellness,
    AppModule.notes => l10n.moduleNotes,
  };

  String description(AppLocalizations l10n) => switch (this) {
    AppModule.nutrition => l10n.moduleNutritionDescription,
    AppModule.water => l10n.moduleWaterDescription,
    AppModule.weight => l10n.moduleWeightDescription,
    AppModule.training => l10n.moduleTrainingDescription,
    AppModule.activity => l10n.moduleActivityDescription,
    AppModule.sleep => l10n.moduleSleepDescription,
    AppModule.wellness => l10n.moduleWellnessDescription,
    AppModule.notes => l10n.moduleNotesDescription,
  };
}

extension ActiveSessionText on ActiveSession {
  /// What the chrome calls the session while it runs, inside a sentence.
  String name(AppLocalizations l10n) => switch (this) {
    ActiveWorkout() => l10n.sessionWorkout,
    ActiveActivity(:final activity) => activity.type.labelIn(l10n),
  };
}

extension TrackingTypeText on TrackingType {
  String labelIn(AppLocalizations l10n) => switch (this) {
    TrackingType.weightReps => l10n.trackingTypeWeightReps,
    TrackingType.reps => l10n.trackingTypeReps,
    TrackingType.duration => l10n.trackingTypeDuration,
    TrackingType.distance => l10n.trackingTypeDistance,
  };
}

extension ExerciseSourceText on ExerciseSource {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ExerciseSource.builtIn => l10n.exerciseSourceBuiltIn,
    ExerciseSource.custom => l10n.exerciseSourceCustom,
    ExerciseSource.imported => l10n.exerciseSourceImported,
  };
}

extension BodyRegionText on BodyRegion {
  String labelIn(AppLocalizations l10n) => switch (this) {
    BodyRegion.chest => l10n.bodyRegionChest,
    BodyRegion.shoulders => l10n.bodyRegionShoulders,
    BodyRegion.back => l10n.bodyRegionBack,
    BodyRegion.arms => l10n.bodyRegionArms,
    BodyRegion.core => l10n.bodyRegionCore,
    BodyRegion.legs => l10n.bodyRegionLegs,
  };
}

extension MuscleGroupText on MuscleGroup {
  String labelIn(AppLocalizations l10n) => switch (this) {
    MuscleGroup.chest => l10n.muscleChest,
    MuscleGroup.frontDelts => l10n.muscleFrontDelts,
    MuscleGroup.sideDelts => l10n.muscleSideDelts,
    MuscleGroup.rearDelts => l10n.muscleRearDelts,
    MuscleGroup.biceps => l10n.muscleBiceps,
    MuscleGroup.triceps => l10n.muscleTriceps,
    MuscleGroup.forearms => l10n.muscleForearms,
    MuscleGroup.traps => l10n.muscleTraps,
    MuscleGroup.lats => l10n.muscleLats,
    MuscleGroup.upperBack => l10n.muscleUpperBack,
    MuscleGroup.spinalErectors => l10n.muscleSpinalErectors,
    MuscleGroup.abs => l10n.muscleAbs,
    MuscleGroup.obliques => l10n.muscleObliques,
    MuscleGroup.glutes => l10n.muscleGlutes,
    MuscleGroup.quads => l10n.muscleQuads,
    MuscleGroup.hamstrings => l10n.muscleHamstrings,
    MuscleGroup.adductors => l10n.muscleAdductors,
    MuscleGroup.abductors => l10n.muscleAbductors,
    MuscleGroup.calves => l10n.muscleCalves,
    MuscleGroup.back => l10n.muscleBack,
    MuscleGroup.shoulders => l10n.muscleShoulders,
    MuscleGroup.arms => l10n.muscleArms,
    MuscleGroup.core => l10n.muscleCore,
  };
}

extension EquipmentText on Equipment {
  String labelIn(AppLocalizations l10n) => switch (this) {
    Equipment.barbell => l10n.equipmentBarbell,
    Equipment.dumbbell => l10n.equipmentDumbbell,
    Equipment.cable => l10n.equipmentCable,
    Equipment.machine => l10n.equipmentMachine,
    Equipment.smithMachine => l10n.equipmentSmithMachine,
    Equipment.kettlebell => l10n.equipmentKettlebell,
    Equipment.ezBar => l10n.equipmentEzBar,
    Equipment.trapBar => l10n.equipmentTrapBar,
    Equipment.landmine => l10n.equipmentLandmine,
    Equipment.plate => l10n.equipmentPlate,
    Equipment.band => l10n.equipmentBand,
    Equipment.bodyweight => l10n.equipmentBodyweight,
    Equipment.cardio => l10n.equipmentCardio,
    Equipment.other => l10n.equipmentOther,
  };
}

extension MovementPatternText on MovementPattern {
  String labelIn(AppLocalizations l10n) => switch (this) {
    MovementPattern.squat => l10n.movementPatternSquat,
    MovementPattern.hinge => l10n.movementPatternHinge,
    MovementPattern.lunge => l10n.movementPatternLunge,
    MovementPattern.horizontalPush => l10n.movementPatternHorizontalPush,
    MovementPattern.horizontalPull => l10n.movementPatternHorizontalPull,
    MovementPattern.verticalPush => l10n.movementPatternVerticalPush,
    MovementPattern.verticalPull => l10n.movementPatternVerticalPull,
    MovementPattern.isolation => l10n.movementPatternIsolation,
    MovementPattern.core => l10n.movementPatternCore,
    MovementPattern.carry => l10n.movementPatternCarry,
    MovementPattern.conditioning => l10n.movementPatternConditioning,
    MovementPattern.unilateral => l10n.movementPatternUnilateral,
  };
}

extension LateralityText on Laterality {
  String labelIn(AppLocalizations l10n) => switch (this) {
    Laterality.bilateral => l10n.lateralityBilateral,
    Laterality.unilateral => l10n.lateralityUnilateral,
    Laterality.alternating => l10n.lateralityAlternating,
  };
}

extension SetTypeText on SetType {
  /// The kind without the word for a set, for a phrase that supplies it
  /// (「加入一組熱身」).
  String kind(AppLocalizations l10n) => switch (this) {
    SetType.working => l10n.setKindWorking,
    SetType.warmup => l10n.setKindWarmup,
    SetType.drop => l10n.setKindDrop,
    SetType.failure => l10n.setKindFailure,
  };

  String labelIn(AppLocalizations l10n) => switch (this) {
    SetType.working => l10n.setTypeWorking,
    SetType.warmup => l10n.setTypeWarmup,
    SetType.drop => l10n.setTypeDrop,
    SetType.failure => l10n.setTypeFailure,
  };
}

extension WorkloadText on Workload {
  String labelIn(AppLocalizations l10n) => switch (this) {
    Workload.tooLight => l10n.workloadTooLight,
    Workload.right => l10n.workloadRight,
    Workload.tooHard => l10n.workloadTooHard,
  };
}

extension SubstitutionReasonText on SubstitutionReason {
  String text(AppLocalizations l10n) => switch (this) {
    SamePattern(:final pattern) => l10n.substitutionSamePattern(
      pattern: pattern.labelIn(l10n),
    ),
    SameMuscles(:final muscles) => l10n.substitutionSameMuscles(
      muscles: joinList(l10n, muscles.map((muscle) => muscle.labelIn(l10n))),
    ),
    EquipmentAvailable(:final equipment) => l10n.substitutionEquipmentAvailable(
      equipment: equipment.labelIn(l10n),
    ),
    TrackingChanges(:final trackingType) => l10n.substitutionTrackingChanges(
      tracking: trackingType.labelIn(l10n),
    ),
    EquipmentChanges(:final equipment) => l10n.substitutionEquipmentChanges(
      equipment: equipment.labelIn(l10n),
    ),
    OneSideAtATime() => l10n.substitutionOneSide,
  };
}

extension ExerciseDefinitionText on ExerciseDefinition {
  /// Its primary muscles as one list: `胸、三頭肌`.
  String muscleSummary(AppLocalizations l10n) =>
      joinList(l10n, primaryMuscles.map((muscle) => muscle.labelIn(l10n)));
}

extension ExerciseFilterText on ExerciseFilter {
  /// What the filter keeps, one list for each kind of choice.
  String summary(AppLocalizations l10n) => [
    if (muscles.isNotEmpty) joinList(l10n, muscles.map((m) => m.labelIn(l10n))),
    if (equipment.isNotEmpty)
      joinList(l10n, equipment.map((e) => e.labelIn(l10n))),
    if (patterns.isNotEmpty)
      joinList(l10n, patterns.map((p) => p.labelIn(l10n))),
    if (trackingTypes.isNotEmpty)
      joinList(l10n, trackingTypes.map((t) => t.labelIn(l10n))),
    if (sources.isNotEmpty) joinList(l10n, sources.map((s) => s.labelIn(l10n))),
  ].join(' · ');
}

extension NutrientValueTypeText on NutrientValueType {
  String labelIn(AppLocalizations l10n) => switch (this) {
    NutrientValueType.declared => l10n.valueTypeDeclared,
    NutrientValueType.max => l10n.valueTypeMax,
    NutrientValueType.estimate => l10n.valueTypeEstimate,
  };
}

extension MealTypeText on MealType {
  String labelIn(AppLocalizations l10n) => switch (this) {
    MealType.breakfast => l10n.mealTypeBreakfast,
    MealType.lunch => l10n.mealTypeLunch,
    MealType.dinner => l10n.mealTypeDinner,
    MealType.snack => l10n.mealTypeSnack,
  };
}

extension ConsumptionKindText on ConsumptionKind {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ConsumptionKind.food => l10n.consumptionKindFood,
    ConsumptionKind.beverage => l10n.consumptionKindBeverage,
    ConsumptionKind.unknown => l10n.consumptionKindUnknown,
  };
}

extension ServingUnitText on ServingUnit {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ServingUnit.gram => l10n.servingUnitGram,
    ServingUnit.kilogram => l10n.servingUnitKilogram,
    ServingUnit.ounce => l10n.servingUnitOunce,
    ServingUnit.pound => l10n.servingUnitPound,
    ServingUnit.tael => l10n.servingUnitTael,
    ServingUnit.catty => l10n.servingUnitCatty,
    ServingUnit.millilitre => l10n.servingUnitMillilitre,
    ServingUnit.litre => l10n.servingUnitLitre,
    ServingUnit.serving => l10n.servingUnitServing,
  };
}

extension AllergenText on Allergen {
  String labelIn(AppLocalizations l10n) => switch (this) {
    Allergen.crustacean => l10n.allergenCrustacean,
    Allergen.mango => l10n.allergenMango,
    Allergen.peanut => l10n.allergenPeanut,
    Allergen.milk => l10n.allergenMilk,
    Allergen.egg => l10n.allergenEgg,
    Allergen.treeNut => l10n.allergenTreeNut,
    Allergen.sesame => l10n.allergenSesame,
    Allergen.gluten => l10n.allergenGluten,
    Allergen.soy => l10n.allergenSoy,
    Allergen.fish => l10n.allergenFish,
    Allergen.sulphite => l10n.allergenSulphite,
  };
}

extension NutrientText on Nutrient {
  String labelIn(AppLocalizations l10n) => switch (this) {
    Nutrient.saturatedFat => l10n.nutrientSaturatedFat,
    Nutrient.transFat => l10n.nutrientTransFat,
    Nutrient.sugar => l10n.nutrientSugar,
    Nutrient.sodium => l10n.nutrientSodium,
    Nutrient.netCarb => l10n.nutrientNetCarb,
    Nutrient.saltEquivalent => l10n.nutrientSaltEquivalent,
    Nutrient.polyols => l10n.nutrientPolyols,
    Nutrient.alcohol => l10n.nutrientAlcohol,
    Nutrient.cholesterol => l10n.nutrientCholesterol,
    Nutrient.caffeine => l10n.nutrientCaffeine,
    Nutrient.essentialAminoAcids => l10n.nutrientEssentialAminoAcids,
    Nutrient.bcaa => l10n.nutrientBcaa,
    Nutrient.leucine => l10n.nutrientLeucine,
    Nutrient.isoleucine => l10n.nutrientIsoleucine,
    Nutrient.valine => l10n.nutrientValine,
    Nutrient.glutamine => l10n.nutrientGlutamine,
    Nutrient.calcium => l10n.nutrientCalcium,
    Nutrient.phosphorus => l10n.nutrientPhosphorus,
    Nutrient.magnesium => l10n.nutrientMagnesium,
    Nutrient.iron => l10n.nutrientIron,
    Nutrient.zinc => l10n.nutrientZinc,
    Nutrient.potassium => l10n.nutrientPotassium,
    Nutrient.iodine => l10n.nutrientIodine,
    Nutrient.selenium => l10n.nutrientSelenium,
    Nutrient.vitaminA => l10n.nutrientVitaminA,
    Nutrient.vitaminD => l10n.nutrientVitaminD,
    Nutrient.vitaminE => l10n.nutrientVitaminE,
    Nutrient.vitaminK => l10n.nutrientVitaminK,
    Nutrient.vitaminC => l10n.nutrientVitaminC,
    Nutrient.vitaminB1 => l10n.nutrientVitaminB1,
    Nutrient.vitaminB2 => l10n.nutrientVitaminB2,
    Nutrient.niacin => l10n.nutrientNiacin,
    Nutrient.vitaminB6 => l10n.nutrientVitaminB6,
    Nutrient.vitaminB12 => l10n.nutrientVitaminB12,
    Nutrient.folate => l10n.nutrientFolate,
    Nutrient.pantothenicAcid => l10n.nutrientPantothenicAcid,
    Nutrient.biotin => l10n.nutrientBiotin,
  };
}

extension NutritionConventionText on NutritionConvention {
  String labelIn(AppLocalizations l10n) => switch (this) {
    NutritionConvention.taiwan => l10n.conventionTaiwan,
    NutritionConvention.japan => l10n.conventionJapan,
    NutritionConvention.unitedStates => l10n.conventionUnitedStates,
    NutritionConvention.europeanUnion => l10n.conventionEuropeanUnion,
    NutritionConvention.australiaNewZealand =>
      l10n.conventionAustraliaNewZealand,
    NutritionConvention.korea => l10n.conventionKorea,
    NutritionConvention.china => l10n.conventionChina,
    NutritionConvention.canada => l10n.conventionCanada,
  };

  /// What the five figures every label has are called, in the words of
  /// the labels this convention reads.
  String energyName(AppLocalizations l10n) => _words(l10n).energy;
  String proteinName(AppLocalizations l10n) => _words(l10n).protein;
  String carbName(AppLocalizations l10n) => _words(l10n).carb;
  String fatName(AppLocalizations l10n) => _words(l10n).fat;
  String fibreName(AppLocalizations l10n) => _words(l10n).fibre;

  /// What [nutrient] is called on the labels this convention reads; the
  /// app's own word for one they have no word for here.
  String nameOf(AppLocalizations l10n, Nutrient nutrient) =>
      _words(l10n).nutrients[nutrient] ?? nutrient.labelIn(l10n);

  // l10n-ignore-start: each country's label words, shown as its labels
  // print them whatever the app's language.

  /// Taiwan's labels are read in the app's own words, which are the ones
  /// they print in Chinese; the others keep their labels' own.
  _LabelWords _words(AppLocalizations l10n) => switch (this) {
    NutritionConvention.taiwan => _LabelWords(
      energy: l10n.macroEnergy,
      protein: l10n.macroProtein,
      carb: l10n.macroCarb,
      fat: l10n.macroFat,
      fibre: l10n.macroFibre,
      nutrients: const {},
    ),
    NutritionConvention.japan => const _LabelWords(
      energy: JapaneseMacroLabel.energy,
      protein: JapaneseMacroLabel.protein,
      carb: JapaneseMacroLabel.carb,
      fat: JapaneseMacroLabel.fat,
      fibre: JapaneseMacroLabel.fibre,
      nutrients: _japaneseWords,
    ),
    NutritionConvention.unitedStates => const _LabelWords(
      energy: 'Calories',
      protein: 'Protein',
      carb: 'Total Carbohydrate',
      fat: 'Total Fat',
      fibre: 'Dietary Fiber',
      nutrients: {
        ..._englishWords,
        Nutrient.sugar: 'Total Sugars',
        Nutrient.saturatedFat: 'Saturated Fat',
        Nutrient.transFat: 'Trans Fat',
        Nutrient.polyols: 'Sugar Alcohol',
      },
    ),
    NutritionConvention.europeanUnion => const _LabelWords(
      energy: 'Energy',
      protein: 'Protein',
      carb: 'Carbohydrate',
      fat: 'Fat',
      fibre: 'Fibre',
      nutrients: {
        ..._englishWords,
        Nutrient.sugar: 'Sugars',
        Nutrient.saturatedFat: 'Saturates',
        Nutrient.polyols: 'Polyols',
        Nutrient.netCarb: 'Carbohydrate',
      },
    ),
    NutritionConvention.australiaNewZealand => const _LabelWords(
      energy: 'Energy',
      protein: 'Protein',
      carb: 'Carbohydrate',
      fat: 'Fat, total',
      fibre: 'Dietary fibre',
      nutrients: {
        ..._englishWords,
        Nutrient.sugar: 'Sugars',
        Nutrient.saturatedFat: 'Saturated fat',
        Nutrient.netCarb: 'Carbohydrate',
      },
    ),
    NutritionConvention.korea => const _LabelWords(
      energy: '열량',
      protein: '단백질',
      carb: '탄수화물',
      fat: '지방',
      fibre: '식이섬유',
      nutrients: {
        Nutrient.sugar: '당류',
        Nutrient.sodium: '나트륨',
        Nutrient.saturatedFat: '포화지방',
        Nutrient.transFat: '트랜스지방',
        Nutrient.cholesterol: '콜레스테롤',
        Nutrient.saltEquivalent: '식염',
        Nutrient.calcium: '칼슘',
        Nutrient.caffeine: '카페인',
      },
    ),
    NutritionConvention.china => const _LabelWords(
      energy: '能量',
      protein: '蛋白质',
      carb: '碳水化合物',
      fat: '脂肪',
      fibre: '膳食纤维',
      nutrients: {
        Nutrient.sugar: '糖',
        Nutrient.sodium: '钠',
        Nutrient.saltEquivalent: '食盐',
        Nutrient.saturatedFat: '饱和脂肪',
        Nutrient.transFat: '反式脂肪',
        Nutrient.cholesterol: '胆固醇',
        Nutrient.calcium: '钙',
        Nutrient.caffeine: '咖啡因',
      },
    ),
    NutritionConvention.canada => const _LabelWords(
      energy: 'Calories',
      protein: 'Protein',
      carb: 'Carbohydrate',
      fat: 'Fat',
      fibre: 'Fibre',
      nutrients: {
        ..._englishWords,
        Nutrient.sugar: 'Sugars',
        Nutrient.saturatedFat: 'Saturated',
        Nutrient.transFat: 'Trans',
      },
    ),
  };
}

/// A label's words for the five every label has and for the rest.
class _LabelWords {
  const _LabelWords({
    required this.energy,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.fibre,
    required this.nutrients,
  });

  final String energy;
  final String protein;
  final String carb;
  final String fat;
  final String fibre;
  final Map<Nutrient, String> nutrients;
}

const _japaneseWords = {
  Nutrient.sugar: '糖類',
  Nutrient.netCarb: '糖質',
  Nutrient.saltEquivalent: '食塩相当量',
  Nutrient.polyols: '糖アルコール',
  Nutrient.alcohol: 'アルコール',
  Nutrient.saturatedFat: '飽和脂肪酸',
  Nutrient.calcium: 'カルシウム',
  Nutrient.iron: '鉄',
  Nutrient.caffeine: 'カフェイン',
  Nutrient.vitaminB6: 'ビタミンB6',
  Nutrient.vitaminB12: 'ビタミンB12',
  Nutrient.vitaminD: 'ビタミンD',
  Nutrient.folate: '葉酸',
  Nutrient.sodium: 'ナトリウム',
  Nutrient.potassium: 'カリウム',
  Nutrient.magnesium: 'マグネシウム',
  Nutrient.phosphorus: 'リン',
  Nutrient.zinc: '亜鉛',
  Nutrient.niacin: 'ナイアシン',
  Nutrient.pantothenicAcid: 'パントテン酸',
  Nutrient.biotin: 'ビオチン',
  Nutrient.vitaminA: 'ビタミンA',
  Nutrient.vitaminB1: 'ビタミンB1',
  Nutrient.vitaminB2: 'ビタミンB2',
  Nutrient.vitaminC: 'ビタミンC',
  Nutrient.vitaminE: 'ビタミンE',
  Nutrient.vitaminK: 'ビタミンK',
  Nutrient.essentialAminoAcids: '必須アミノ酸',
  Nutrient.bcaa: 'BCAA',
  Nutrient.glutamine: 'グルタミン',
  Nutrient.leucine: 'ロイシン',
  Nutrient.isoleucine: 'イソロイシン',
  Nutrient.valine: 'バリン',
};

/// What labels in English call what they share.
const _englishWords = {
  Nutrient.sodium: 'Sodium',
  Nutrient.saltEquivalent: 'Salt',
  Nutrient.cholesterol: 'Cholesterol',
  Nutrient.alcohol: 'Alcohol',
  Nutrient.caffeine: 'Caffeine',
  Nutrient.calcium: 'Calcium',
  Nutrient.iron: 'Iron',
  Nutrient.potassium: 'Potassium',
  Nutrient.magnesium: 'Magnesium',
  Nutrient.vitaminD: 'Vitamin D',
  Nutrient.bcaa: 'BCAAs',
  Nutrient.leucine: 'Leucine',
  Nutrient.isoleucine: 'Isoleucine',
  Nutrient.valine: 'Valine',
  Nutrient.glutamine: 'Glutamine',
};

/// The five figures every label has, as a Japanese one names them.
abstract final class JapaneseMacroLabel {
  static const energy = '熱量';
  static const protein = 'たんぱく質';
  static const fat = '脂質';
  static const carb = '炭水化物';
  static const fibre = '食物繊維';
}

/// What a Japanese label (食品表示基準) calls a figure, so a food sold
/// there reads as its own label does; null for one the label has no
/// word for here.
String? japaneseLabelOf(Nutrient nutrient) => _japaneseWords[nutrient];
// l10n-ignore-end

extension FoodItemText on FoodItem {
  /// `一碗 · 250 ml`, or just the measurement when it has no name.
  String servingDescription(AppLocalizations l10n) {
    final amount =
        '${formatAmount(servingAmount)} ${servingUnit.labelIn(l10n)}';
    final measured = isCupCapacity
        ? l10n.foodCupCapacity(amount: amount)
        : amount;
    if (servingLabel.isEmpty) return measured;
    return servingUnit.isMeasured ? '$servingLabel · $measured' : servingLabel;
  }
}

extension DraftWarningText on DraftWarning {
  String text(AppLocalizations l10n) => switch (this) {
    ModelNote(:final text) => text,
    EnergyMismatch(:final item?) => l10n.draftEnergyMismatchItem(item: item),
    EnergyMismatch() => l10n.draftEnergyMismatch,
    ColumnMismatch() => l10n.draftColumnMismatch,
    CarbWithoutFibre() => l10n.draftCarbWithoutFibre,
  };
}

extension ActivityGroupText on ActivityGroup {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ActivityGroup.walkRun => l10n.activityGroupWalkRun,
    ActivityGroup.cycling => l10n.activityGroupCycling,
    ActivityGroup.water => l10n.activityGroupWater,
    ActivityGroup.ball => l10n.activityGroupBall,
    ActivityGroup.indoor => l10n.activityGroupIndoor,
    ActivityGroup.mindBody => l10n.activityGroupMindBody,
    ActivityGroup.other => l10n.activityGroupOther,
  };
}

extension ActivityMetricGroupText on ActivityMetricGroup {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ActivityMetricGroup.movement => l10n.activityMetricGroupMovement,
    ActivityMetricGroup.heart => l10n.activityMetricGroupHeart,
    ActivityMetricGroup.mobility => l10n.activityMetricGroupMobility,
    ActivityMetricGroup.running => l10n.activityMetricGroupRunning,
    ActivityMetricGroup.cycling => l10n.activityMetricGroupCycling,
    ActivityMetricGroup.swimmingWheelchair =>
      l10n.activityMetricGroupSwimmingWheelchair,
  };
}

extension ActivityMetricText on ActivityMetric {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ActivityMetric.steps => l10n.activityMetricSteps,
    ActivityMetric.distance => l10n.activityMetricDistance,
    ActivityMetric.activeEnergy => l10n.activityMetricActiveEnergy,
    ActivityMetric.basalEnergy => l10n.activityMetricBasalEnergy,
    ActivityMetric.exerciseTime => l10n.activityMetricExerciseTime,
    ActivityMetric.standTime => l10n.activityMetricStandTime,
    ActivityMetric.floors => l10n.activityMetricFloors,
    ActivityMetric.elevationGained => l10n.activityMetricElevationGained,
    ActivityMetric.timeInDaylight => l10n.activityMetricTimeInDaylight,
    ActivityMetric.heartRate => l10n.activityMetricHeartRate,
    ActivityMetric.restingHeartRate => l10n.activityMetricRestingHeartRate,
    ActivityMetric.walkingHeartRate => l10n.activityMetricWalkingHeartRate,
    ActivityMetric.hrvSdnn => l10n.activityMetricHrvSdnn,
    ActivityMetric.hrvRmssd => l10n.activityMetricHrvRmssd,
    ActivityMetric.heartRateRecovery => l10n.activityMetricHeartRateRecovery,
    ActivityMetric.vo2Max => l10n.activityMetricVo2Max,
    ActivityMetric.physicalEffort => l10n.activityMetricPhysicalEffort,
    ActivityMetric.walkingSpeed => l10n.activityMetricWalkingSpeed,
    ActivityMetric.walkingStepLength => l10n.activityMetricWalkingStepLength,
    ActivityMetric.walkingAsymmetry => l10n.activityMetricWalkingAsymmetry,
    ActivityMetric.doubleSupport => l10n.activityMetricDoubleSupport,
    ActivityMetric.walkingSteadiness => l10n.activityMetricWalkingSteadiness,
    ActivityMetric.stairAscentSpeed => l10n.activityMetricStairAscentSpeed,
    ActivityMetric.stairDescentSpeed => l10n.activityMetricStairDescentSpeed,
    ActivityMetric.sixMinuteWalk => l10n.activityMetricSixMinuteWalk,
    ActivityMetric.runningSpeed => l10n.activityMetricRunningSpeed,
    ActivityMetric.runningPower => l10n.activityMetricRunningPower,
    ActivityMetric.runningStrideLength =>
      l10n.activityMetricRunningStrideLength,
    ActivityMetric.groundContactTime => l10n.activityMetricGroundContactTime,
    ActivityMetric.verticalOscillation =>
      l10n.activityMetricVerticalOscillation,
    ActivityMetric.cyclingDistance => l10n.activityMetricCyclingDistance,
    ActivityMetric.cyclingSpeed => l10n.activityMetricCyclingSpeed,
    ActivityMetric.cyclingPower => l10n.activityMetricCyclingPower,
    ActivityMetric.cyclingCadence => l10n.activityMetricCyclingCadence,
    ActivityMetric.functionalThresholdPower =>
      l10n.activityMetricFunctionalThresholdPower,
    ActivityMetric.swimmingDistance => l10n.activityMetricSwimmingDistance,
    ActivityMetric.swimmingStrokes => l10n.activityMetricSwimmingStrokes,
    ActivityMetric.wheelchairPushes => l10n.activityMetricWheelchairPushes,
    ActivityMetric.wheelchairDistance => l10n.activityMetricWheelchairDistance,
  };
}

extension ActivityMetricUnitText on ActivityMetric {
  String unitIn(AppLocalizations l10n) => switch (this) {
    ActivityMetric.steps => l10n.activityMetricUnitSteps,
    ActivityMetric.distance => l10n.activityMetricUnitDistance,
    ActivityMetric.activeEnergy => l10n.activityMetricUnitActiveEnergy,
    ActivityMetric.basalEnergy => l10n.activityMetricUnitBasalEnergy,
    ActivityMetric.exerciseTime => l10n.activityMetricUnitExerciseTime,
    ActivityMetric.standTime => l10n.activityMetricUnitStandTime,
    ActivityMetric.floors => l10n.activityMetricUnitFloors,
    ActivityMetric.elevationGained => l10n.activityMetricUnitElevationGained,
    ActivityMetric.timeInDaylight => l10n.activityMetricUnitTimeInDaylight,
    ActivityMetric.heartRate => l10n.activityMetricUnitHeartRate,
    ActivityMetric.restingHeartRate => l10n.activityMetricUnitRestingHeartRate,
    ActivityMetric.walkingHeartRate => l10n.activityMetricUnitWalkingHeartRate,
    ActivityMetric.hrvSdnn => l10n.activityMetricUnitHrvSdnn,
    ActivityMetric.hrvRmssd => l10n.activityMetricUnitHrvRmssd,
    ActivityMetric.heartRateRecovery =>
      l10n.activityMetricUnitHeartRateRecovery,
    ActivityMetric.vo2Max => l10n.activityMetricUnitVo2Max,
    ActivityMetric.physicalEffort => l10n.activityMetricUnitPhysicalEffort,
    ActivityMetric.walkingSpeed => l10n.activityMetricUnitWalkingSpeed,
    ActivityMetric.walkingStepLength =>
      l10n.activityMetricUnitWalkingStepLength,
    ActivityMetric.walkingAsymmetry => l10n.activityMetricUnitWalkingAsymmetry,
    ActivityMetric.doubleSupport => l10n.activityMetricUnitDoubleSupport,
    ActivityMetric.walkingSteadiness =>
      l10n.activityMetricUnitWalkingSteadiness,
    ActivityMetric.stairAscentSpeed => l10n.activityMetricUnitStairAscentSpeed,
    ActivityMetric.stairDescentSpeed =>
      l10n.activityMetricUnitStairDescentSpeed,
    ActivityMetric.sixMinuteWalk => l10n.activityMetricUnitSixMinuteWalk,
    ActivityMetric.runningSpeed => l10n.activityMetricUnitRunningSpeed,
    ActivityMetric.runningPower => l10n.activityMetricUnitRunningPower,
    ActivityMetric.runningStrideLength =>
      l10n.activityMetricUnitRunningStrideLength,
    ActivityMetric.groundContactTime =>
      l10n.activityMetricUnitGroundContactTime,
    ActivityMetric.verticalOscillation =>
      l10n.activityMetricUnitVerticalOscillation,
    ActivityMetric.cyclingDistance => l10n.activityMetricUnitCyclingDistance,
    ActivityMetric.cyclingSpeed => l10n.activityMetricUnitCyclingSpeed,
    ActivityMetric.cyclingPower => l10n.activityMetricUnitCyclingPower,
    ActivityMetric.cyclingCadence => l10n.activityMetricUnitCyclingCadence,
    ActivityMetric.functionalThresholdPower =>
      l10n.activityMetricUnitFunctionalThresholdPower,
    ActivityMetric.swimmingDistance => l10n.activityMetricUnitSwimmingDistance,
    ActivityMetric.swimmingStrokes => l10n.activityMetricUnitSwimmingStrokes,
    ActivityMetric.wheelchairPushes => l10n.activityMetricUnitWheelchairPushes,
    ActivityMetric.wheelchairDistance =>
      l10n.activityMetricUnitWheelchairDistance,
  };
}

extension ActivityTypeText on ActivityType {
  String labelIn(AppLocalizations l10n) => switch (id) {
    'running' => l10n.activityTypeRunning,
    'walking' => l10n.activityTypeWalking,
    'hiking' => l10n.activityTypeHiking,
    'cycling' => l10n.activityTypeCycling,
    'swimming' => l10n.activityTypeSwimming,
    'rowing' => l10n.activityTypeRowing,
    'elliptical' => l10n.activityTypeElliptical,
    'stairs' => l10n.activityTypeStairs,
    'basketball' => l10n.activityTypeBasketball,
    'badminton' => l10n.activityTypeBadminton,
    'yoga' => l10n.activityTypeYoga,
    _ => l10n.activityTypeOther,
  };
}

extension ActivitySessionText on ActivitySession {
  /// `30 分 · 5 km`.
  String descriptionIn(AppLocalizations l10n) => [
    l10n.durationMinutes(minutes: duration.inMinutes),
    if (distanceMeters case final metres?) '${formatWeight(metres / 1000)} km',
  ].join(' · ');
}

extension ActivitySeriesText on ActivitySeries {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ActivitySeries.heartRate => l10n.activitySeriesHeartRate,
    ActivitySeries.speed => l10n.activitySeriesSpeed,
    ActivitySeries.power => l10n.activitySeriesPower,
    ActivitySeries.cadence => l10n.activitySeriesCadence,
    ActivitySeries.strideLength => l10n.activitySeriesStrideLength,
    ActivitySeries.groundContactTime => l10n.activitySeriesGroundContactTime,
    ActivitySeries.verticalOscillation =>
      l10n.activitySeriesVerticalOscillation,
    ActivitySeries.altitude => l10n.activitySeriesAltitude,
  };
}

extension ActivitySeriesUnitInText on ActivitySeries {
  String unitIn(AppLocalizations l10n) => switch (this) {
    ActivitySeries.heartRate => l10n.activitySeriesUnitHeartRate,
    ActivitySeries.speed => l10n.activitySeriesUnitSpeed,
    ActivitySeries.power => l10n.activitySeriesUnitPower,
    ActivitySeries.cadence => l10n.activitySeriesUnitCadence,
    ActivitySeries.strideLength => l10n.activitySeriesUnitStrideLength,
    ActivitySeries.groundContactTime =>
      l10n.activitySeriesUnitGroundContactTime,
    ActivitySeries.verticalOscillation =>
      l10n.activitySeriesUnitVerticalOscillation,
    ActivitySeries.altitude => l10n.activitySeriesUnitAltitude,
  };
}

extension MeasurementSiteText on MeasurementSite {
  String labelIn(AppLocalizations l10n) => switch (this) {
    MeasurementSite.waist => l10n.measurementSiteWaist,
    MeasurementSite.hips => l10n.measurementSiteHips,
    MeasurementSite.chest => l10n.measurementSiteChest,
    MeasurementSite.arm => l10n.measurementSiteArm,
    MeasurementSite.thigh => l10n.measurementSiteThigh,
    MeasurementSite.calf => l10n.measurementSiteCalf,
    MeasurementSite.neck => l10n.measurementSiteNeck,
  };
}

extension BodyMetricText on BodyMetric {
  String labelIn(AppLocalizations l10n) => switch (this) {
    BodyMetric.height => l10n.bodyMetricHeight,
    BodyMetric.bodyFat => l10n.bodyMetricBodyFat,
    BodyMetric.skeletalMuscle => l10n.bodyMetricSkeletalMuscle,
    BodyMetric.muscleMass => l10n.bodyMetricMuscleMass,
    BodyMetric.leanMass => l10n.bodyMetricLeanMass,
    BodyMetric.visceralFat => l10n.bodyMetricVisceralFat,
    BodyMetric.bodyWater => l10n.bodyMetricBodyWater,
    BodyMetric.boneMass => l10n.bodyMetricBoneMass,
    BodyMetric.basalMetabolicRate => l10n.bodyMetricBasalMetabolicRate,
  };
}

extension SexText on Sex {
  String labelIn(AppLocalizations l10n) => switch (this) {
    Sex.female => l10n.sexFemale,
    Sex.male => l10n.sexMale,
  };
}

extension SleepKindText on SleepKind {
  String labelIn(AppLocalizations l10n) => switch (this) {
    SleepKind.night => l10n.sleepKindNight,
    SleepKind.nap => l10n.sleepKindNap,
  };
}

extension SleepMeasureText on SleepMeasure {
  String labelIn(AppLocalizations l10n) => switch (this) {
    SleepMeasure.asleep => l10n.sleepMeasureAsleep,
    SleepMeasure.inBed => l10n.sleepMeasureInBed,
  };
}

extension SleepStageText on SleepStage {
  String labelIn(AppLocalizations l10n) => switch (this) {
    SleepStage.inBed => l10n.sleepStageInBed,
    SleepStage.awake => l10n.sleepStageAwake,
    SleepStage.asleep => l10n.sleepStageAsleep,
    SleepStage.core => l10n.sleepStageCore,
    SleepStage.deep => l10n.sleepStageDeep,
    SleepStage.rem => l10n.sleepStageRem,
  };
}

extension OvernightMeasureText on OvernightMeasure {
  String labelIn(AppLocalizations l10n) => switch (this) {
    OvernightMeasure.heartRate => l10n.overnightMeasureHeartRate,
    OvernightMeasure.respiratoryRate => l10n.overnightMeasureRespiratoryRate,
    OvernightMeasure.oxygenSaturation => l10n.overnightMeasureOxygenSaturation,
    OvernightMeasure.wristTemperature => l10n.overnightMeasureWristTemperature,
    OvernightMeasure.skinTemperatureChange =>
      l10n.overnightMeasureSkinTemperatureChange,
    OvernightMeasure.hrvSdnn => l10n.overnightMeasureHrvSdnn,
    OvernightMeasure.hrvRmssd => l10n.overnightMeasureHrvRmssd,
    OvernightMeasure.breathingDisturbances =>
      l10n.overnightMeasureBreathingDisturbances,
  };
}

extension ActivityLevelText on ActivityLevel {
  String labelIn(AppLocalizations l10n) => switch (this) {
    ActivityLevel.sedentary => l10n.activityLevelSedentary,
    ActivityLevel.light => l10n.activityLevelLight,
    ActivityLevel.moderate => l10n.activityLevelModerate,
    ActivityLevel.active => l10n.activityLevelActive,
    ActivityLevel.veryActive => l10n.activityLevelVeryActive,
  };
}

extension WeightGoalText on WeightGoal {
  String labelIn(AppLocalizations l10n) => switch (this) {
    WeightGoal.lose => l10n.weightGoalLose,
    WeightGoal.recomp => l10n.weightGoalRecomp,
    WeightGoal.maintain => l10n.weightGoalMaintain,
    WeightGoal.gain => l10n.weightGoalGain,
  };
}

extension TargetInputText on TargetInput {
  String labelIn(AppLocalizations l10n) => switch (this) {
    TargetInput.weight => l10n.targetInputWeight,
    TargetInput.height => l10n.targetInputHeight,
    TargetInput.birthYear => l10n.targetInputBirthYear,
    TargetInput.sex => l10n.targetInputSex,
  };
}

extension HealthDataKindText on HealthDataKind {
  String labelIn(AppLocalizations l10n) => switch (this) {
    HealthDataKind.sleep => l10n.healthDataSleep,
    HealthDataKind.weight => l10n.healthDataWeight,
    HealthDataKind.waist => l10n.healthDataWaist,
    HealthDataKind.body => l10n.healthDataBody,
    HealthDataKind.workouts => l10n.healthDataWorkouts,
    HealthDataKind.water => l10n.healthDataWater,
    HealthDataKind.nutrition => l10n.moduleNutrition,
    HealthDataKind.mood => l10n.wellnessKindMood,
    HealthDataKind.overnight => l10n.healthDataOvernight,
    HealthDataKind.activity => l10n.healthDataActivity,
  };
}

extension RecordCategoryText on RecordCategory {
  String labelIn(AppLocalizations l10n) => switch (this) {
    RecordCategory.training => l10n.recordCategoryTraining,
    RecordCategory.activity => l10n.recordCategoryActivity,
    RecordCategory.nutrition => l10n.recordCategoryNutrition,
    RecordCategory.body => l10n.recordCategoryBody,
    RecordCategory.wellness => l10n.recordCategoryWellness,
  };
}

extension AiProviderKindText on AiProviderKind {
  String labelIn(AppLocalizations l10n) => switch (this) {
    AiProviderKind.appleOnDevice => l10n.aiProviderAppleOnDevice,
    AiProviderKind.ollamaCloud => l10n.aiProviderOllamaCloud,
    AiProviderKind.googleAiStudio => l10n.aiProviderGoogleAiStudio,
    AiProviderKind.anthropic => l10n.aiProviderAnthropic,
    AiProviderKind.azureAiFoundry => l10n.aiProviderAzureAiFoundry,
    AiProviderKind.microsoftCopilot => l10n.aiProviderMicrosoftCopilot,
    AiProviderKind.openAiCompatible => l10n.aiProviderOpenAiCompatible,
  };
}

extension WellnessKindText on WellnessKind {
  String labelIn(AppLocalizations l10n) => switch (this) {
    WellnessKind.energy => l10n.wellnessKindEnergy,
    WellnessKind.mood => l10n.wellnessKindMood,
    WellnessKind.symptom => l10n.wellnessKindSymptom,
    WellnessKind.sleep => l10n.wellnessKindSleep,
  };
}

extension BodyMetricUnitInText on BodyMetric {
  String unitIn(AppLocalizations l10n) => switch (this) {
    BodyMetric.height => l10n.bodyMetricUnitHeight,
    BodyMetric.bodyFat => l10n.bodyMetricUnitBodyFat,
    BodyMetric.skeletalMuscle => l10n.bodyMetricUnitSkeletalMuscle,
    BodyMetric.muscleMass => l10n.bodyMetricUnitMuscleMass,
    BodyMetric.leanMass => l10n.bodyMetricUnitLeanMass,
    BodyMetric.visceralFat => l10n.bodyMetricUnitVisceralFat,
    BodyMetric.bodyWater => l10n.bodyMetricUnitBodyWater,
    BodyMetric.boneMass => l10n.bodyMetricUnitBoneMass,
    BodyMetric.basalMetabolicRate => l10n.bodyMetricUnitBasalMetabolicRate,
  };
}

extension OvernightMeasureUnitInText on OvernightMeasure {
  String unitIn(AppLocalizations l10n) => switch (this) {
    OvernightMeasure.heartRate => l10n.overnightMeasureUnitHeartRate,
    OvernightMeasure.respiratoryRate =>
      l10n.overnightMeasureUnitRespiratoryRate,
    OvernightMeasure.oxygenSaturation =>
      l10n.overnightMeasureUnitOxygenSaturation,
    OvernightMeasure.wristTemperature =>
      l10n.overnightMeasureUnitWristTemperature,
    OvernightMeasure.skinTemperatureChange =>
      l10n.overnightMeasureUnitSkinTemperatureChange,
    OvernightMeasure.hrvSdnn => l10n.overnightMeasureUnitHrvSdnn,
    OvernightMeasure.hrvRmssd => l10n.overnightMeasureUnitHrvRmssd,
    OvernightMeasure.breathingDisturbances =>
      l10n.overnightMeasureUnitBreathingDisturbances,
  };
}

extension ActivityLevelDetailInText on ActivityLevel {
  String detailIn(AppLocalizations l10n) => switch (this) {
    ActivityLevel.sedentary => l10n.activityLevelDetailSedentary,
    ActivityLevel.light => l10n.activityLevelDetailLight,
    ActivityLevel.moderate => l10n.activityLevelDetailModerate,
    ActivityLevel.active => l10n.activityLevelDetailActive,
    ActivityLevel.veryActive => l10n.activityLevelDetailVeryActive,
  };
}

extension BmiBandText on BmiBand {
  String labelIn(AppLocalizations l10n) => switch (this) {
    BmiBand.under => l10n.bmiBandUnder,
    BmiBand.healthy => l10n.bmiBandHealthy,
    BmiBand.over => l10n.bmiBandOver,
    BmiBand.obese => l10n.bmiBandObese,
  };
}

extension TrendDomainText on TrendDomain {
  String labelIn(AppLocalizations l10n) => switch (this) {
    TrendDomain.body => l10n.trendDomainBody,
    TrendDomain.training => l10n.trendDomainTraining,
    TrendDomain.sleep => l10n.trendDomainSleep,
    TrendDomain.nutrition => l10n.trendDomainNutrition,
    TrendDomain.activity => l10n.trendDomainActivity,
  };
}
