import 'nutrition.dart';

/// Where a model runs, as the user chooses it.
///
/// The two differ in the one way that matters to a health log: whether
/// what is typed leaves the phone.
enum AiProviderKind {
  /// Apple's on-device model. Nothing is sent anywhere.
  appleOnDevice('Apple Intelligence', leavesDevice: false),

  /// Models hosted by Ollama, reached with the user's own key.
  ollamaCloud('Ollama Cloud', leavesDevice: true),

  /// Google's Gemini API, the key from AI Studio.
  googleAiStudio('Google AI Studio', leavesDevice: true),

  /// Anthropic's Claude API.
  anthropic('Anthropic', leavesDevice: true),

  /// Microsoft's Azure AI Foundry, a model deployed in the user's own
  /// Azure resource.
  azureAiFoundry('Azure AI Foundry', leavesDevice: true),

  /// Microsoft 365 Copilot, through its Chat API: a sign-in with a work
  /// or school account rather than a key.
  microsoftCopilot('Microsoft 365 Copilot', leavesDevice: true),

  /// Anything else speaking OpenAI's chat API at an address the user
  /// gives: a gateway, a server of their own.
  openAiCompatible('OpenAI 相容端點', leavesDevice: true);

  const AiProviderKind(this.label, {required this.leavesDevice});

  final String label;

  /// Whether a request sends what the user typed to someone else.
  final bool leavesDevice;

  /// Whether it needs a key from the user.
  bool get needsKey => leavesDevice && !needsSignIn;

  /// Whether the user signs in instead of pasting a key.
  bool get needsSignIn => this == AiProviderKind.microsoftCopilot;

  /// Whether the user picks the model.
  bool get hasModelChoice =>
      leavesDevice && this != AiProviderKind.microsoftCopilot;

  /// Whether the user also has to say where to send it.
  bool get needsEndpoint =>
      this == AiProviderKind.openAiCompatible ||
      this == AiProviderKind.azureAiFoundry;
}

/// Whether a provider can answer right now, and if not, what the user
/// can do about it.
enum AiAvailability {
  available,

  /// Ollama without a key.
  needsKey,

  /// The phone cannot run Apple's model.
  deviceNotEligible,

  /// Apple Intelligence is off in Settings.
  notEnabled,

  /// Apple's model is still downloading.
  modelNotReady,

  /// Anything else: an older system, another platform.
  unavailable,
}

/// Why a request produced no draft. Each provider's own errors are
/// translated into these, so a screen never has to guess at a status
/// code from one company or another.
enum AiFailure {
  unavailable,
  needsConsent,
  authentication,
  rateLimited,
  network,
  providerError,

  /// The model answered, but not with anything a draft can be made of.
  unreadable,

  /// No text could be read off the photo.
  noText,

  /// A food photo would go to a cloud provider the user has not agreed
  /// to send photos to: agreeing to text does not cover a photo.
  needsPhotoConsent,

  /// The chosen provider, or its model, cannot look at a photo.
  photoUnsupported,

  /// The model saw no food or drink in the photo.
  noFood,

  /// The photo is in a format the providers do not read.
  photoFormat,
}

class AiException implements Exception {
  const AiException(this.failure, [this.detail]);

  final AiFailure failure;

  /// What the provider said, for diagnosis; never shown as the message.
  final String? detail;

  @override
  String toString() => 'AiException($failure, $detail)';
}

/// How a meal logged from a confirmed AI draft is tagged.
const aiDraftQualityTag = 'AI 估計';

/// A meal as a model read it from a sentence. Nothing here is a record:
/// it becomes one only after the user has seen it and confirmed it, and
/// every number in it is the model's guess.
class MealDraft {
  const MealDraft({
    required this.items,
    required this.provider,
    required this.model,
    this.warnings = const [],
  });

  final List<DraftItem> items;
  final AiProviderKind provider;

  /// What a photo cannot show and the figures depend on — oil, sauce, a
  /// drink's sugar — or what does not add up, in the words the review
  /// shows.
  final List<String> warnings;

  /// The model's own name, kept with what it produced.
  final String model;
}

class DraftItem {
  const DraftItem({
    required this.name,
    this.amount = '',
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.nutrients = const {},
    this.isDrink = false,
  });

  final String name;

  /// How much, in the words the model used: `一個`, `700 ml`.
  final String amount;
  final int? kcal;
  final int? proteinGrams;
  final int? carbGrams;
  final int? fatGrams;
  final int? fibreGrams;

  /// Everything else a printed label gave: sugar, sodium, calcium, the
  /// amino acids. Absent is unknown, as on a food.
  final Nutrients nutrients;
  final bool isDrink;
}

/// One line of text read off a photo, with where it sat, as a fraction
/// of the photo's width and height from the top left. Where it sat is
/// what keeps a label's rows together: 「熱量」 and its numbers are three
/// separate pieces of text on the same line.
class TextLine {
  const TextLine({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  double get centreY => top + height / 2;
}

/// A packaged food as a model read it off its nutrition label: the
/// figures for one serving, which the user checks in the food form
/// before anything is saved. Any of them may be missing.
class FoodLabelDraft {
  const FoodLabelDraft({
    required this.provider,
    required this.model,
    this.name,
    this.brand,
    this.servingAmount,
    this.servingUnit,
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.nutrients = const {},
    this.warnings = const [],
  });

  final AiProviderKind provider;
  final String model;
  final String? name;
  final String? brand;

  /// The label's 每一份量, in grams or millilitres.
  final double? servingAmount;
  final ServingUnit? servingUnit;

  /// Per serving, as the label prints them, decimals included: the form
  /// shows what the label said.
  final double? kcal;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;
  final double? fibreGrams;

  /// Saturated and trans fat, sugar, sodium and caffeine, per serving.
  final Nutrients nutrients;

  /// What did not add up, in the words the form shows: the figures are
  /// still filled in, and these say where to look.
  final List<String> warnings;

  bool get isEmpty =>
      kcal == null &&
      proteinGrams == null &&
      carbGrams == null &&
      fatGrams == null &&
      nutrients.isEmpty;
}
