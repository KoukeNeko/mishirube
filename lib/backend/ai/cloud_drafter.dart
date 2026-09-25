import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/domain.dart';
import '../engines/workout_text.dart';
import 'food_label_json.dart';
import 'food_photo.dart';
import 'meal_draft_json.dart';
import 'meal_drafter.dart';
import 'workout_draft_json.dart';

/// A model reached over the network with the user's own key.
///
/// Every provider is asked the same two things and answers in the app's
/// own JSON; what differs is the address, the header the key goes in and
/// where the reply sits in their response. That is why each has its own
/// subclass instead of one "OpenAI compatible" client: the wire formats
/// only look alike until they don't.
abstract class CloudDrafter implements MealDrafter, ModelCatalogue {
  CloudDrafter({
    required this.client,
    required this.readKey,
    required this.readModel,
  });

  static const timeout = Duration(seconds: 60);

  final http.Client client;
  final Future<String?> Function() readKey;
  final String Function() readModel;

  @override
  Future<String> modelName() async => readModel();

  @override
  Future<AiAvailability> availability() async =>
      (await readKey())?.isNotEmpty == true
      ? AiAvailability.available
      : AiAvailability.needsKey;

  @override
  Future<MealDraft> draftMeal(String description) async => parseMealDraft(
    await chat(mealDraftInstructions, description),
    provider: kind,
    // What answered, which for Copilot is not a model the user picked.
    model: await modelName(),
  );

  @override
  Future<FoodLabelDraft> draftFoodLabel(String labelText) async =>
      parseFoodLabel(
        await chat(foodLabelInstructions, labelText),
        provider: kind,
        model: await modelName(),
      );

  @override
  Future<List<WorkoutLine>> draftWorkout(String text) async =>
      parseWorkoutDraft(await chat(workoutDraftInstructions, text));

  @override
  Future<bool> readsPhotos() async => true;

  @override
  Future<MealDraft> draftMealPhoto(FoodPhoto photo, {String note = ''}) async =>
      parseMealPhoto(
        await chat(
          mealPhotoInstructions,
          note.trim().isEmpty ? '這張照片裡的食物。' : '補充：${note.trim()}',
          photo: photo,
        ),
        provider: kind,
        model: await modelName(),
      );

  /// One question, one whole answer: the model's reply text. [photo]
  /// goes with [message] when there is one.
  Future<String> chat(String instructions, String message, {FoodPhoto? photo});

  /// The key, or [AiFailure.unavailable] when there is none: a request
  /// without one is not sent at all.
  Future<String> key() async {
    final key = await readKey();
    if (key == null || key.isEmpty) {
      throw const AiException(AiFailure.unavailable);
    }
    return key;
  }

  /// Sends [request], turning the ways a network call fails into the
  /// app's own failures.
  Future<Map<String, dynamic>> send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on SocketException catch (error) {
      throw AiException(AiFailure.network, error.message);
    } on TimeoutException {
      throw const AiException(AiFailure.network, 'timed out');
    } on http.ClientException catch (error) {
      throw AiException(AiFailure.network, error.message);
    }
    switch (response.statusCode) {
      // Any success: creating a Copilot conversation answers 201.
      case >= 200 && < 300:
        break;
      case 401 || 403:
        throw AiException(AiFailure.authentication, response.body);
      case 429:
        throw AiException(AiFailure.rateLimited, response.body);
      default:
        throw AiException(AiFailure.providerError, response.body);
    }
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw AiException(AiFailure.unreadable, response.body);
      }
      return body;
    } on FormatException {
      throw AiException(AiFailure.unreadable, response.body);
    }
  }

  /// What a provider's answer must contain, or [AiFailure.unreadable].
  Never unreadable(Object? body) =>
      throw AiException(AiFailure.unreadable, '$body');
}

/// Ollama's hosted models.
///
/// Ollama Cloud does not support structured outputs, so the shape is
/// asked for in the instructions and checked on the way back rather than
/// enforced by the server.
class OllamaDrafter extends CloudDrafter {
  OllamaDrafter({
    required super.client,
    required super.readKey,
    required super.readModel,
  });

  static final endpoint = Uri.parse('https://ollama.com/api/chat');
  static final modelsEndpoint = Uri.parse('https://ollama.com/v1/models');

  @override
  AiProviderKind get kind => AiProviderKind.ollamaCloud;

  @override
  Future<String> chat(
    String instructions,
    String message, {
    FoodPhoto? photo,
  }) async {
    final body = await send(
      () async => client.post(
        endpoint,
        headers: {
          'Authorization': 'Bearer ${await key()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': readModel(),
          'stream': false,
          'messages': [
            {'role': 'system', 'content': instructions},
            {
              'role': 'user',
              'content': message,
              'images': ?(photo == null ? null : [photo.base64]),
            },
          ],
        }),
      ),
    );
    return switch (body) {
      {'message': {'content': final String content}} => content,
      _ => unreadable(body),
    };
  }

  @override
  Future<List<String>> models() async {
    final body = await send(
      () async => client.get(
        modelsEndpoint,
        headers: {'Authorization': 'Bearer ${await key()}'},
      ),
    );
    return _openAiModelNames(body, this);
  }
}

/// Google's Gemini API, with a key from AI Studio.
class GoogleAiStudioDrafter extends CloudDrafter {
  GoogleAiStudioDrafter({
    required super.client,
    required super.readKey,
    required super.readModel,
  });

  static const host = 'generativelanguage.googleapis.com';

  @override
  AiProviderKind get kind => AiProviderKind.googleAiStudio;

  @override
  Future<String> chat(
    String instructions,
    String message, {
    FoodPhoto? photo,
  }) async {
    // The key goes in a header, never in the URL: a query string ends up
    // in logs and history.
    final body = await send(
      () async => client.post(
        Uri.https(host, '/v1beta/models/${readModel()}:generateContent'),
        headers: {
          'x-goog-api-key': await key(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': instructions},
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                if (photo != null)
                  {
                    'inlineData': {
                      'mimeType': photo.mimeType,
                      'data': photo.base64,
                    },
                  },
                {'text': message},
              ],
            },
          ],
          'generationConfig': {'responseMimeType': 'application/json'},
        }),
      ),
    );
    return switch (body) {
      {
        'candidates': [
          {'content': {'parts': [{'text': final String text}, ...]}},
          ...,
        ],
      } =>
        text,
      _ => unreadable(body),
    };
  }

  @override
  Future<List<String>> models() async {
    final body = await send(
      () async => client.get(
        Uri.https(host, '/v1beta/models', {'pageSize': '200'}),
        headers: {'x-goog-api-key': await key()},
      ),
    );
    return switch (body) {
      {'models': final List<dynamic> models} => [
        for (final model in models)
          if (model
              case {
                'name': final String name,
                'supportedGenerationMethods': final List<dynamic> methods,
              }
              when methods.contains('generateContent'))
            // `models/gemini-3.8-flash` is how a request names it.
            name.startsWith('models/') ? name.substring(7) : name,
      ]..sort(),
      _ => unreadable(body),
    };
  }
}

/// Anthropic's Claude API.
class AnthropicDrafter extends CloudDrafter {
  AnthropicDrafter({
    required super.client,
    required super.readKey,
    required super.readModel,
  });

  static final endpoint = Uri.parse('https://api.anthropic.com/v1/messages');
  static final modelsEndpoint = Uri.parse(
    'https://api.anthropic.com/v1/models',
  );
  static const version = '2023-06-01';

  @override
  AiProviderKind get kind => AiProviderKind.anthropic;

  Future<Map<String, String>> _headers() async => {
    'x-api-key': await key(),
    'anthropic-version': version,
    'Content-Type': 'application/json',
  };

  @override
  Future<String> chat(
    String instructions,
    String message, {
    FoodPhoto? photo,
  }) async {
    final body = await send(
      () async => client.post(
        endpoint,
        headers: await _headers(),
        body: jsonEncode({
          'model': readModel(),
          'max_tokens': 2048,
          'system': instructions,
          'messages': [
            {
              'role': 'user',
              'content': photo == null
                  ? message
                  : [
                      {
                        'type': 'image',
                        'source': {
                          'type': 'base64',
                          'media_type': photo.mimeType,
                          'data': photo.base64,
                        },
                      },
                      {'type': 'text', 'text': message},
                    ],
            },
          ],
        }),
      ),
    );
    return switch (body) {
      {'content': [{'text': final String text}, ...]} => text,
      _ => unreadable(body),
    };
  }

  @override
  Future<List<String>> models() async {
    final body = await send(
      () async => client.get(modelsEndpoint, headers: await _headers()),
    );
    return _openAiModelNames(body, this);
  }
}

/// Azure AI Foundry: a model the user deployed in their own Azure
/// resource, which is where GitHub's own docs send people now that
/// GitHub Models is gone. The address is the resource's, the model is
/// the deployment's name, and the API version is part of every request.
class AzureAiFoundryDrafter extends CloudDrafter {
  AzureAiFoundryDrafter({
    required super.client,
    required super.readKey,
    required super.readModel,
    required this.readEndpoint,
  });

  /// The version this app's requests are written against.
  static const apiVersion = '2025-04-01';

  final String Function() readEndpoint;

  @override
  AiProviderKind get kind => AiProviderKind.azureAiFoundry;

  @override
  Future<AiAvailability> availability() async => baseOf(readEndpoint()) == null
      ? AiAvailability.needsKey
      : super.availability();

  @override
  Future<String> chat(
    String instructions,
    String message, {
    FoodPhoto? photo,
  }) async {
    final base = baseOf(readEndpoint());
    if (base == null) throw const AiException(AiFailure.unavailable);
    final body = await send(
      () async => client.post(
        base.replace(
          path: '${base.path}/chat/completions',
          queryParameters: {'api-version': apiVersion},
        ),
        headers: {
          'Authorization': 'Bearer ${await key()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': readModel(),
          'messages': [
            {'role': 'system', 'content': instructions},
            {'role': 'user', 'content': _openAiContent(message, photo)},
          ],
        }),
      ),
    );
    return _openAiReply(body, this);
  }

  /// Foundry's inference API has no listing of what is deployed, so the
  /// settings page falls back to typing the deployment's name.
  @override
  Future<List<String>> models() async => const [];
}

/// Anything that speaks OpenAI's chat API at an address the user gives:
/// a gateway, a proxy, a server of their own.
class OpenAiCompatibleDrafter extends CloudDrafter {
  OpenAiCompatibleDrafter({
    required super.client,
    required super.readKey,
    required super.readModel,
    required this.readEndpoint,
  });

  /// The base address, such as `https://example.com/v1`.
  final String Function() readEndpoint;

  @override
  AiProviderKind get kind => AiProviderKind.openAiCompatible;

  @override
  Future<AiAvailability> availability() async => baseOf(readEndpoint()) == null
      ? AiAvailability.needsKey
      : super.availability();

  Uri _at(String suffix) {
    final base = baseOf(readEndpoint());
    if (base == null) throw const AiException(AiFailure.unavailable);
    return base.replace(path: '${base.path}$suffix');
  }

  @override
  Future<String> chat(
    String instructions,
    String message, {
    FoodPhoto? photo,
  }) async {
    final body = await send(
      () async => client.post(
        _at('/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${await key()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': readModel(),
          'messages': [
            {'role': 'system', 'content': instructions},
            {'role': 'user', 'content': _openAiContent(message, photo)},
          ],
        }),
      ),
    );
    return _openAiReply(body, this);
  }

  @override
  Future<List<String>> models() async {
    final body = await send(
      () async => client.get(
        _at('/models'),
        headers: {'Authorization': 'Bearer ${await key()}'},
      ),
    );
    return _openAiModelNames(body, this);
  }
}

/// `{"data": [{"id": "…"}]}`, which Ollama, Anthropic and everything
/// OpenAI-shaped all answer a model listing with.
List<String> _openAiModelNames(
  Map<String, dynamic> body,
  CloudDrafter drafter,
) => switch (body) {
  {'data': final List<dynamic> models} => [
    for (final model in models)
      if (model case {'id': final String id} when id.isNotEmpty) id,
  ]..sort(),
  _ => drafter.unreadable(body),
};

/// The address the user gave, without a trailing slash, or null when it
/// is not an address at all.
Uri? baseOf(String address) {
  final parsed = Uri.tryParse(address.trim());
  if (parsed == null || !parsed.isAbsolute) return null;
  final path = parsed.path.endsWith('/')
      ? parsed.path.substring(0, parsed.path.length - 1)
      : parsed.path;
  return parsed.replace(path: path);
}

/// A user message as OpenAI-shaped APIs take it: plain text, or the
/// text and the photo as a data URL.
Object _openAiContent(String message, FoodPhoto? photo) => photo == null
    ? message
    : [
        {'type': 'text', 'text': message},
        {
          'type': 'image_url',
          'image_url': {'url': photo.dataUrl, 'detail': 'high'},
        },
      ];

/// `{"choices": [{"message": {"content": "…"}}]}`, the shape Azure AI
/// Foundry and every OpenAI-shaped endpoint reply with.
String _openAiReply(Map<String, dynamic> body, CloudDrafter drafter) =>
    switch (body) {
      {'choices': [{'message': {'content': final String content}}, ...]} =>
        content,
      _ => drafter.unreadable(body),
    };
