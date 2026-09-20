import '../shared/format.dart';

class FoodComponent {
  const FoodComponent({
    required this.name,
    required this.amountLabel,
    required this.source,
  });

  final String name;
  final String amountLabel;
  final String source;
}

class DishEntry {
  const DishEntry({
    required this.name,
    required this.quantityLabel,
    required this.subtitle,
    this.components = const [],
  });

  final String name;
  final String quantityLabel;
  final String subtitle;
  final List<FoodComponent> components;

  bool get isComposite => components.isNotEmpty;
}

class MealEvent {
  const MealEvent({
    required this.id,
    required this.name,
    required this.timeLabel,
    required this.qualityTag,
    required this.dishes,
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.isEstimated = false,
    this.isFavorite = false,
    this.nutrients = const {},
  });

  final String id;
  final String name;
  final String timeLabel;

  /// Some amount in the meal is a guess, so its totals read as `~`.
  final bool isEstimated;

  /// What was eaten, where it is known. Null is not zero: a meal logged
  /// from a food whose label was never read has no calorie figure, and
  /// the day's total has to say so rather than quietly add nothing.
  final int? kcal;
  final String qualityTag;
  final List<DishEntry> dishes;
  final int? proteinGrams;
  final int? carbGrams;
  final int? fatGrams;

  /// Fibre, which is part of the carbohydrate already counted above and
  /// is tracked separately because it is what people actually watch.
  final int? fibreGrams;

  /// Starred to log again without going looking for it.
  final bool isFavorite;

  /// Everything else known about what was eaten. Absent means unknown,
  /// so a day's total for a nutrient has to say how much of the day it
  /// could not see.
  final Nutrients nutrients;

  MealEvent copyWith({
    String? id,
    String? name,
    String? timeLabel,
    List<DishEntry>? dishes,
    bool? isFavorite,
    int? kcal,
    int? proteinGrams,
    int? carbGrams,
    int? fatGrams,
    int? fibreGrams,
    bool? isEstimated,
    String? qualityTag,
    Nutrients? nutrients,
  }) => MealEvent(
    id: id ?? this.id,
    name: name ?? this.name,
    timeLabel: timeLabel ?? this.timeLabel,
    kcal: kcal ?? this.kcal,
    qualityTag: qualityTag ?? this.qualityTag,
    dishes: dishes ?? this.dishes,
    proteinGrams: proteinGrams ?? this.proteinGrams,
    carbGrams: carbGrams ?? this.carbGrams,
    fatGrams: fatGrams ?? this.fatGrams,
    fibreGrams: fibreGrams ?? this.fibreGrams,
    isFavorite: isFavorite ?? this.isFavorite,
    isEstimated: isEstimated ?? this.isEstimated,
    nutrients: nutrients ?? this.nutrients,
  );
}

/// How much one serving of a food is.
///
/// [serving] means the size is not a measurement: one 便當 is one 便當,
/// and the app must not pretend it knows how many grams that is.
enum ServingUnit {
  gram('g'),
  millilitre('ml'),
  serving('份');

  const ServingUnit(this.label);

  final String label;

  /// Whether a portion can be entered as a raw amount in this unit.
  bool get isMeasured => this != ServingUnit.serving;
}

/// A food the user saved so they do not have to type it in again.
///
/// This is the private layer of the food catalogue: it lives on this
/// device, it is never shared, and every value in it was entered by the
/// person who will read it back. Nothing here claims to be authoritative.
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.brand = '',
    this.servingLabel = '',
    this.servingAmount = 1,
    this.servingUnit = ServingUnit.serving,
    this.nutrients = const {},
  });

  final String id;

  final String name;

  /// The maker, when the food has one; empty for anything homemade.
  final String brand;

  /// What the user calls one serving: `一碗`, `一片`, `一罐`. Optional,
  /// and separate from how much that is — what you call it and how much
  /// it weighs are two different things.
  final String servingLabel;

  /// How much one serving is, in [servingUnit]. Always positive.
  final double servingAmount;

  final ServingUnit servingUnit;

  /// `一碗 · 250 ml`, or just the measurement when it has no name.
  String get servingDescription {
    final measured = '${formatAmount(servingAmount)} ${servingUnit.label}';
    if (servingLabel.isEmpty) return measured;
    return servingUnit.isMeasured ? '$servingLabel · $measured' : servingLabel;
  }

  /// Per serving, as the user entered them. Null is a figure nobody
  /// wrote down — a food whose label was never read is not a food with
  /// no calories in it.
  final int? kcal;
  final int? proteinGrams;
  final int? carbGrams;
  final int? fatGrams;

  /// Fibre, part of the carbohydrate above; see [MealEvent.fibreGrams].
  final int? fibreGrams;

  /// Everything else known about one serving. Absent means unknown.
  final Nutrients nutrients;

  /// `統一 雞胸肉` when it has a maker, otherwise just the name.
  String get displayName => brand.isEmpty ? name : '$brand $name';

  FoodItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? servingLabel,
    double? servingAmount,
    ServingUnit? servingUnit,
    int? kcal,
    int? proteinGrams,
    int? carbGrams,
    int? fatGrams,
    int? fibreGrams,
    Nutrients? nutrients,
  }) => FoodItem(
    id: id ?? this.id,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    servingLabel: servingLabel ?? this.servingLabel,
    servingAmount: servingAmount ?? this.servingAmount,
    servingUnit: servingUnit ?? this.servingUnit,
    kcal: kcal ?? this.kcal,
    proteinGrams: proteinGrams ?? this.proteinGrams,
    carbGrams: carbGrams ?? this.carbGrams,
    fatGrams: fatGrams ?? this.fatGrams,
    fibreGrams: fibreGrams ?? this.fibreGrams,
    nutrients: nutrients ?? this.nutrients,
  );
}

/// The unit a nutrient is counted in.
enum NutrientUnit {
  gram('g'),
  milligram('mg'),
  microgram('µg');

  const NutrientUnit(this.label);

  final String label;
}

/// The nutrients this app can hold beyond the five it counts everywhere.
///
/// Energy, protein, carbohydrate, fat and fibre are not here: they are
/// fields on every food and every meal, because every record has them.
/// Everything below is held only when it is actually known, so a nutrient
/// missing from a food means nobody wrote it down — not zero.
///
/// The order is the order the label prints them in, then the DRI groups.
enum Nutrient {
  // What Taiwan's packaging law requires beyond the five above.
  saturatedFat('飽和脂肪', NutrientUnit.gram),
  transFat('反式脂肪', NutrientUnit.gram),
  sugar('糖', NutrientUnit.gram),
  sodium('鈉', NutrientUnit.milligram),

  // Commonly declared voluntarily.
  cholesterol('膽固醇', NutrientUnit.milligram),
  caffeine('咖啡因', NutrientUnit.milligram),

  // Minerals in the DRIs.
  calcium('鈣', NutrientUnit.milligram),
  phosphorus('磷', NutrientUnit.milligram),
  magnesium('鎂', NutrientUnit.milligram),
  iron('鐵', NutrientUnit.milligram),
  zinc('鋅', NutrientUnit.milligram),
  potassium('鉀', NutrientUnit.milligram),
  iodine('碘', NutrientUnit.microgram),
  selenium('硒', NutrientUnit.microgram),

  // Vitamins in the DRIs.
  vitaminA('維生素 A', NutrientUnit.microgram),
  vitaminD('維生素 D', NutrientUnit.microgram),
  vitaminE('維生素 E', NutrientUnit.milligram),
  vitaminK('維生素 K', NutrientUnit.microgram),
  vitaminC('維生素 C', NutrientUnit.milligram),
  vitaminB1('維生素 B1', NutrientUnit.milligram),
  vitaminB2('維生素 B2', NutrientUnit.milligram),
  niacin('菸鹼素', NutrientUnit.milligram),
  vitaminB6('維生素 B6', NutrientUnit.milligram),
  vitaminB12('維生素 B12', NutrientUnit.microgram),
  folate('葉酸', NutrientUnit.microgram),
  pantothenicAcid('泛酸', NutrientUnit.milligram),
  biotin('生物素', NutrientUnit.microgram);

  const Nutrient(this.label, this.unit);

  final String label;
  final NutrientUnit unit;

  /// Written as `12.4 mg`.
  String format(double amount) => '${formatAmount(amount)} ${unit.label}';
}

/// What is known about a food's nutrients, per serving.
///
/// A nutrient absent from the map is one nobody recorded. It is never
/// read as zero: a label that prints `0 g` of fat only means under half a
/// gram, and a label that prints nothing at all means nothing at all.
typedef Nutrients = Map<Nutrient, double>;
