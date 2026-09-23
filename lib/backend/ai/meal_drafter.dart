import '../../domain/domain.dart';
import 'food_photo.dart';

/// Turns a sentence into a [MealDraft], or a label's text into a
/// [FoodLabelDraft]. That is all it can do: it is given no repository
/// and no database, so whatever a model answers, the only thing it can
/// produce is a draft for the user to confirm.
abstract interface class MealDrafter {
  AiProviderKind get kind;

  /// The model a draft would come from, as the provider names it.
  Future<String> modelName();

  Future<AiAvailability> availability();

  /// Throws [AiException] when no draft can be made.
  Future<MealDraft> draftMeal(String description);

  /// [labelText] is a nutrition label already read off a photo on the
  /// phone, one table row per line. Throws [AiException].
  Future<FoodLabelDraft> draftFoodLabel(String labelText);

  /// Whether this provider, with the model chosen, can look at a photo.
  Future<bool> readsPhotos();

  /// What a food photo shows, item by item, with [note] the user added
  /// (「飯半碗」「微糖少冰」) taking precedence over what the photo seems
  /// to show. Throws [AiException].
  Future<MealDraft> draftMealPhoto(FoodPhoto photo, {String note = ''});
}

/// A provider that can say which models it offers, so the settings page
/// can list them instead of asking the user to type a name exactly.
abstract interface class ModelCatalogue {
  /// Throws [AiException]; empty when the provider answered with none.
  Future<List<String>> models();
}
