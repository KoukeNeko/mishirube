/// Where a model runs, as the user chooses it.
///
/// The two differ in the one way that matters to a health log: whether
/// what is typed leaves the phone.
enum AiProviderKind {
  /// Apple's on-device model. Nothing is sent anywhere.
  appleOnDevice('Apple Intelligence', leavesDevice: false),

  /// Models hosted by Ollama, reached with the user's own key.
  ollamaCloud('Ollama Cloud', leavesDevice: true);

  const AiProviderKind(this.label, {required this.leavesDevice});

  final String label;

  /// Whether a request sends what the user typed to someone else.
  final bool leavesDevice;
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
  });

  final List<DraftItem> items;
  final AiProviderKind provider;

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
    this.isDrink = false,
  });

  final String name;

  /// How much, in the words the model used: `一個`, `700 ml`.
  final String amount;
  final int? kcal;
  final int? proteinGrams;
  final int? carbGrams;
  final int? fatGrams;
  final bool isDrink;

  DraftItem copyWith({int? kcal}) => DraftItem(
    name: name,
    amount: amount,
    kcal: kcal ?? this.kcal,
    proteinGrams: proteinGrams,
    carbGrams: carbGrams,
    fatGrams: fatGrams,
    isDrink: isDrink,
  );
}
