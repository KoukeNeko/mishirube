import '../../domain/domain.dart';

/// Turns a sentence into a [MealDraft]. That is all it can do: it is
/// given no repository and no database, so whatever a model answers, the
/// only thing it can produce is a draft for the user to confirm.
abstract interface class MealDrafter {
  AiProviderKind get kind;

  /// The model a draft would come from, as the provider names it.
  Future<String> modelName();

  Future<AiAvailability> availability();

  /// Throws [AiException] when no draft can be made.
  Future<MealDraft> draftMeal(String description);
}
