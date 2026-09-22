import 'package:http/http.dart' as http;

import '../../domain/domain.dart';
import '../ai/apple_meal_drafter.dart';
import '../ai/label_reader.dart';
import '../ai/meal_drafter.dart';
import '../ai/cloud_drafter.dart';
import '../ai/copilot_drafter.dart';
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
    final http.Client shared = client ?? http.Client();
    late final AiService service;
    Future<String?> keyOf(AiProviderKind kind) => secrets.read(keyName(kind));
    String modelOf(AiProviderKind kind) => service.modelFor(kind);
    service = AiService(
      db,
      secrets: secrets,
      labelReader: const PlatformLabelReader(),
      drafters: {
        AiProviderKind.appleOnDevice: const AppleMealDrafter(),
        AiProviderKind.ollamaCloud: OllamaDrafter(
          client: shared,
          readKey: () => keyOf(AiProviderKind.ollamaCloud),
          readModel: () => modelOf(AiProviderKind.ollamaCloud),
        ),
        AiProviderKind.googleAiStudio: GoogleAiStudioDrafter(
          client: shared,
          readKey: () => keyOf(AiProviderKind.googleAiStudio),
          readModel: () => modelOf(AiProviderKind.googleAiStudio),
        ),
        AiProviderKind.anthropic: AnthropicDrafter(
          client: shared,
          readKey: () => keyOf(AiProviderKind.anthropic),
          readModel: () => modelOf(AiProviderKind.anthropic),
        ),
        AiProviderKind.azureAiFoundry: AzureAiFoundryDrafter(
          client: shared,
          readKey: () => keyOf(AiProviderKind.azureAiFoundry),
          readModel: () => modelOf(AiProviderKind.azureAiFoundry),
          readEndpoint: () =>
              service.endpointFor(AiProviderKind.azureAiFoundry),
        ),
        AiProviderKind.microsoftCopilot: CopilotDrafter(
          client: shared,
          readKey: () => keyOf(AiProviderKind.microsoftCopilot),
          readModel: () => modelOf(AiProviderKind.microsoftCopilot),
          readClientId: () => service.clientId,
          readTenant: () => service.tenant,
          saveRefreshToken: (token) =>
              secrets.write(keyName(AiProviderKind.microsoftCopilot), token),
        ),
        AiProviderKind.openAiCompatible: OpenAiCompatibleDrafter(
          client: shared,
          readKey: () => keyOf(AiProviderKind.openAiCompatible),
          readModel: () => modelOf(AiProviderKind.openAiCompatible),
          readEndpoint: () =>
              service.endpointFor(AiProviderKind.openAiCompatible),
        ),
      },
    );
    return service;
  }

  /// No provider at all: what a store without a device behind it has.
  factory AiService.none(AppDatabase db) =>
      AiService(db, secrets: MemorySecretStore(), drafters: const {});

  /// What each provider's key is called in the secret store.
  static String keyName(AiProviderKind kind) => 'ai_key_${kind.name}';

  /// The model a provider starts on, from each one's own documentation.
  static const defaultModels = {
    AiProviderKind.ollamaCloud: 'gemma4:31b',
    AiProviderKind.googleAiStudio: 'gemini-3.8-flash',
    AiProviderKind.anthropic: 'claude-opus-4-5',
    AiProviderKind.azureAiFoundry: '',
    AiProviderKind.microsoftCopilot: '',
    AiProviderKind.openAiCompatible: '',
  };

  static const _providerKey = 'ai.provider';
  static const _consentKey = 'ai.cloud_consent';
  static const _endpointKey = 'ai.endpoint';

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

  /// The model [kind] is set to use.
  String modelFor(AiProviderKind kind) =>
      _db.setting('ai.model.${kind.name}') ?? defaultModels[kind] ?? '';

  void setModel(AiProviderKind kind, String model) =>
      _db.setSetting('ai.model.${kind.name}', model.trim());

  /// The app registration Microsoft 365 Copilot signs in through, and
  /// the tenant it belongs to. Both are the user's own.
  String get clientId => _db.setting('ai.client_id') ?? '';

  void setClientId(String id) => _db.setSetting('ai.client_id', id.trim());

  String get tenant => _db.setting('ai.tenant') ?? '';

  void setTenant(String tenant) => _db.setSetting('ai.tenant', tenant.trim());

  /// Starts a Copilot sign-in: the code the user types on Microsoft's
  /// page, and then [finishSignIn] waits for them to finish.
  Future<DeviceCodePrompt> startSignIn() async {
    final drafter = drafters[AiProviderKind.microsoftCopilot];
    if (drafter is! CopilotDrafter) {
      throw const AiException(AiFailure.unavailable);
    }
    return drafter.startSignIn();
  }

  Future<void> finishSignIn(DeviceCodePrompt prompt) async {
    final drafter = drafters[AiProviderKind.microsoftCopilot];
    if (drafter is! CopilotDrafter) {
      throw const AiException(AiFailure.unavailable);
    }
    return drafter.finishSignIn(prompt);
  }

  /// Where a provider that needs an address lives, as the user gave it.
  String endpointFor(AiProviderKind kind) =>
      _db.setting('$_endpointKey.${kind.name}') ?? '';

  void setEndpoint(AiProviderKind kind, String address) =>
      _db.setSetting('$_endpointKey.${kind.name}', address.trim());

  /// Whether the user agreed to send what they type to a cloud provider.
  bool get hasCloudConsent => _db.setting(_consentKey) == 'true';

  void setCloudConsent(bool agreed) => _db.setSetting(_consentKey, '$agreed');

  Future<bool> hasKey(AiProviderKind kind) async =>
      (await secrets.read(keyName(kind)))?.isNotEmpty == true;

  /// Stores the key, or forgets it when [key] is empty.
  Future<void> setKey(AiProviderKind kind, String key) => key.trim().isEmpty
      ? secrets.delete(keyName(kind))
      : secrets.write(keyName(kind), key.trim());

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

  /// The models the chosen provider offers, for the settings page to
  /// list; empty when it does not offer a choice.
  Future<List<String>> models() async => switch (drafters[provider]) {
    final ModelCatalogue catalogue => catalogue.models(),
    _ => const [],
  };

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
