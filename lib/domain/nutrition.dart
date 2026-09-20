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

  MealEvent copyWith({
    String? id,
    String? timeLabel,
    List<DishEntry>? dishes,
  }) => MealEvent(
    id: id ?? this.id,
    name: name,
    timeLabel: timeLabel ?? this.timeLabel,
    kcal: kcal,
    qualityTag: qualityTag,
    dishes: dishes ?? this.dishes,
    proteinGrams: proteinGrams,
    carbGrams: carbGrams,
    fatGrams: fatGrams,
    isEstimated: isEstimated,
  );
}
