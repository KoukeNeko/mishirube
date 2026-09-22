import 'package:http/http.dart' as http;

import '../../domain/domain.dart';
import '../ai/apple_meal_drafter.dart';
import '../ai/label_reader.dart';
import '../ai/meal_drafter.dart';
import '../ai/ollama_meal_drafter.dart';
import '../ai/secret_store.dart';
import '../engines/label_text.dart';
import '../storage/database.dart';

/// The AI layer's front door: which provider the user chose, its key
/// and model, whether they agreed to send text to the cloud, and the
/// one thing a provider can do — draft.
///
/// It holds no repository. Writing a confirmed draft is the nutrition
/// service's job, so a model's answer cannot reach the records without
/// passing through the user.
class AiService {
  AiService(
    this._db, {
    required this.secrets,
    required this.drafters,
    this.labelReader = const NoLabelReader(),
  });

  /// The providers the app ships: Apple's on-device model and Ollama
  /// Cloud with a key from the keychain.
  factory AiService.onDevice(AppDatabase db, {http.Client? client}) {
    const secrets = KeychainSecretStore();
    late final AiService service;
    service = AiService(
      db,
      secrets: secrets,
      labelReader: const PlatformLabelReader(),
      drafters: {
        AiProviderKind.appleOnDevice: const AppleMealDrafter(),
        AiProviderKind.ollamaCloud: OllamaMealDrafter(
          client: client ?? http.Client(),
          readKey: () => secrets.read(ollamaKeyName),
          readModel: () => service.ollamaModel,
        ),
      },
    );
    return service;
  }

  /// No provider at all: what a store without a device behind it has.
  factory AiService.none(AppDatabase db) =>
      AiService(db, secrets: MemorySecretStore(), drafters: const {});

  static const ollamaKeyName = 'ollama_api_key';

  /// The model Ollama's own documentation uses for API calls.
  static const defaultOllamaModel = 'gemma4:31b';

  static const _providerKey = 'ai.provider';
  static const _modelKey = 'ai.ollama_model';
  static const _consentKey = 'ai.cloud_consent';

  final AppDatabase _db;
  final SecretStore secrets;

  /// What each provider drafts with; one missing is unavailable.
  final Map<AiProviderKind, MealDrafter> drafters;

  /// Reads a photo's text on the phone, before any model sees anything.
  final LabelReader labelReader;

  /// The chosen provider, or null until the user picks one: nothing is
  /// sent anywhere by default.
  AiProviderKind? get provider => switch (_db.setting(_providerKey)) {
    final name? => AiProviderKind.values.asNameMap()[name],
    null => null,
  };

  void setProvider(AiProviderKind kind) =>
      _db.setSetting(_providerKey, kind.name);

  String get ollamaModel => _db.setting(_modelKey) ?? defaultOllamaModel;

  void setOllamaModel(String model) => _db.setSetting(
    _modelKey,
    model.trim().isEmpty ? defaultOllamaModel : model.trim(),
  );

  /// Whether the user agreed to send what they type to a cloud provider.
  bool get hasCloudConsent => _db.setting(_consentKey) == 'true';

  void setCloudConsent(bool agreed) => _db.setSetting(_consentKey, '$agreed');

  Future<bool> hasOllamaKey() async =>
      (await secrets.read(ollamaKeyName))?.isNotEmpty == true;

  /// Stores the key, or forgets it when [key] is empty.
  Future<void> setOllamaKey(String key) => key.trim().isEmpty
      ? secrets.delete(ollamaKeyName)
      : secrets.write(ollamaKeyName, key.trim());

  Future<AiAvailability> availability(AiProviderKind kind) async =>
      await drafters[kind]?.availability() ?? AiAvailability.unavailable;

  /// A draft of the meal [description] describes. Throws [AiException];
  /// [AiFailure.needsConsent] before the first cloud request.
  Future<MealDraft> draftMeal(String description) async =>
      _drafter().draftMeal(description);

  /// A food drafted from a nutrition label's text, read off a photo on
  /// the phone: only the text is ever sent, never the photo.
  Future<FoodLabelDraft> draftFoodLabel(String labelText) async =>
      _drafter().draftFoodLabel(labelText);

  /// A food drafted from a photo of its nutrition label. The photo is
  /// read on the phone; the chosen model only ever gets the text, put
  /// back into the label's rows. Throws [AiException]; [AiFailure.noText]
  /// when the photo has no text in it.
  Future<FoodLabelDraft> scanFoodLabel(String imagePath) async {
    // Checked first, so a photo is not read for a request that cannot go.
    final drafter = _drafter();
    final text = labelTextFrom(await labelReader.readText(imagePath));
    if (text.isEmpty) throw const AiException(AiFailure.noText);
    return drafter.draftFoodLabel(text);
  }

  /// The chosen provider's drafter, once the rules allow a request.
  MealDrafter _drafter() {
    final kind = provider;
    final drafter = kind == null ? null : drafters[kind];
    if (kind == null || drafter == null) {
      throw const AiException(AiFailure.unavailable);
    }
    if (kind.leavesDevice && !hasCloudConsent) {
      throw const AiException(AiFailure.needsConsent);
    }
    return drafter;
  }
}
