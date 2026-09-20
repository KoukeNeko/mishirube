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
    isFavorite: isFavorite ?? this.isFavorite,
    isEstimated: isEstimated ?? this.isEstimated,
  );
}
