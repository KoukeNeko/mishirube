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
    required this.kcal,
    required this.qualityTag,
    required this.dishes,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    this.fibreGrams = 0,
    this.isEstimated = false,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String timeLabel;

  /// Some amount in the meal is a guess, so its totals read as `~`.
  final bool isEstimated;
  final int kcal;
  final String qualityTag;
  final List<DishEntry> dishes;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  /// Fibre, which is part of the carbohydrate already counted above and
  /// is tracked separately because it is what people actually watch.
  final int fibreGrams;

  /// Starred to log again without going looking for it.
  final bool isFavorite;

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
  );
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
    required this.servingLabel,
    required this.kcal,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    this.brand = '',
    this.fibreGrams = 0,
  });

  final String id;

  final String name;

  /// The maker, when the food has one; empty for anything homemade.
  final String brand;

  /// What one serving is, in the user's own words: `一碗 (250 g)`.
  /// It is a label, not a quantity: the app does no unit conversion, so
  /// it must not pretend to know how many grams that is.
  final String servingLabel;

  /// Per serving, as the user entered them.
  final int kcal;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  /// Fibre, part of the carbohydrate above; see [MealEvent.fibreGrams].
  final int fibreGrams;

  /// `統一 雞胸肉` when it has a maker, otherwise just the name.
  String get displayName => brand.isEmpty ? name : '$brand $name';

  FoodItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? servingLabel,
    int? kcal,
    int? proteinGrams,
    int? carbGrams,
    int? fatGrams,
    int? fibreGrams,
  }) => FoodItem(
    id: id ?? this.id,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    servingLabel: servingLabel ?? this.servingLabel,
    kcal: kcal ?? this.kcal,
    proteinGrams: proteinGrams ?? this.proteinGrams,
    carbGrams: carbGrams ?? this.carbGrams,
    fatGrams: fatGrams ?? this.fatGrams,
    fibreGrams: fibreGrams ?? this.fibreGrams,
  );
}
