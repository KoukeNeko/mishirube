import '../../app/view_model.dart';
import '../../backend/engines/caffeine.dart';
import '../../domain/domain.dart';

/// Caffeine: what is likely still in the body around now, and what was
/// drunk or eaten with it over the last day.
class CaffeineViewModel extends ViewModel {
  CaffeineViewModel(super.backend);

  /// Records within the last day that carry caffeine, newest first.
  List<(DateTime, MealEvent)> get recentIntakes {
    final at = now();
    return [
      for (final (eatenAt, meal)
          in backend.nutrition
              .between(at.subtract(const Duration(days: 1)), at)
              .reversed)
        if (meal.nutrients[Nutrient.caffeine] != null) (eatenAt, meal),
    ];
  }

  /// The caffeine likely still in the body around now ([caffeineAround]).
  ({List<(DateTime, double)> curve, int nowIndex})? get curve {
    final at = now();
    return caffeineAround(
      caffeineIntakes(
        backend.nutrition.between(
          at.subtract(caffeineCurveBack + const Duration(days: 1)),
          at,
        ),
      ),
      at: at,
    );
  }

  /// Whether caffeine over the bedtime reference is shown on the lock
  /// screen and in the Dynamic Island.
  bool get isLiveActivityOn => backend.nutrition.isCaffeineActivityOn;

  void setLiveActivity(bool isOn) =>
      backend.nutrition.setCaffeineActivity(isOn);
}
