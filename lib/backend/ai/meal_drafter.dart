import '../../domain/domain.dart';
import '../engines/workout_text.dart';
import 'food_photo.dart';

/// A model's reasoning as it arrives, chunk by chunk, while a draft is
/// being made: the running text the user watches under 「產生中…」. Only
/// a reasoning model reached over a streaming connection has any; every
/// other provider leaves it unused, and so the draft reads the same
/// whether or not anyone is listening.
typedef ThinkingSink = void Function(String delta);

/// Turns a sentence into a [MealDraft], a label's text into a
/// [FoodLabelDraft], or a workout's text into its exercises. That is all
/// it can do: it is given no repository
/// and no database, so whatever a model answers, the only thing it can
/// produce is a draft for the user to confirm.
///
/// When [ThinkingSink] is given, a provider that reasons out loud feeds
/// it the model's thinking as it streams in; the draft returned is the
/// same either way.
abstract interface class MealDrafter {
  AiProviderKind get kind;

  /// The model a draft would come from, as the provider names it.
  Future<String> modelName();

  Future<AiAvailability> availability();

  /// Throws [AiException] when no draft can be made.
  Future<MealDraft> draftMeal(String description, {ThinkingSink? onThinking});

  /// [labelText] is a nutrition label already read off a photo on the
  /// phone, one table row per line. Throws [AiException].
  Future<FoodLabelDraft> draftFoodLabel(
    String labelText, {
    ThinkingSink? onThinking,
  });

  /// The exercises a workout written as [text] lists, in order, with
  /// the figures it gives. Throws [AiException].
  Future<List<WorkoutLine>> draftWorkout(
    String text, {
    ThinkingSink? onThinking,
  });

  /// A short name for one meal made of the items called [itemNames], as
  /// the model wrote it: the caller cleans it up ([cleanMealName]).
  /// [language] is that language's own name (「English」). Throws
  /// [AiException].
  Future<String> nameMeal(List<String> itemNames, {required String language});

  /// Whether this provider, with the model chosen, can look at a photo.
  Future<bool> readsPhotos();

  /// What a photo shows, as the model finds it: a nutrition label read
  /// as printed, or food item by item, with [note] the user added
  /// (「飯半碗」「微糖少冰」) taking precedence over what the photo seems
  /// to show. Throws [AiException].
  Future<PhotoDraft> draftPhoto(
    FoodPhoto photo, {
    String note = '',
    ThinkingSink? onThinking,
  });
}

/// A provider that can say which models it offers, so the settings page
/// can list them instead of asking the user to type a name exactly.
abstract interface class ModelCatalogue {
  /// Throws [AiException]; empty when the provider answered with none.
  Future<List<String>> models();
}
