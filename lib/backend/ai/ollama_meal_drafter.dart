import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/domain.dart';
import 'food_label_json.dart';
import 'meal_draft_json.dart';
import 'meal_drafter.dart';

/// Ollama's hosted models, called directly with the user's own key.
///
/// Ollama Cloud does not support structured outputs, so the shape is
/// asked for in the instructions and checked on the way back
/// ([parseMealDraft]) rather than enforced by the server.
class OllamaMealDrafter implements MealDrafter {
  OllamaMealDrafter({
    required this.client,
    required this.readKey,
    required this.readModel,
  });

  static final endpoint = Uri.parse('https://ollama.com/api/chat');
  static const _timeout = Duration(seconds: 60);

  final http.Client client;
  final Future<String?> Function() readKey;
  final String Function() readModel;

  @override
  AiProviderKind get kind => AiProviderKind.ollamaCloud;

  @override
  Future<String> modelName() async => readModel();

  @override
  Future<AiAvailability> availability() async =>
      (await readKey())?.isNotEmpty == true
      ? AiAvailability.available
      : AiAvailability.needsKey;

  @override
  Future<MealDraft> draftMeal(String description) async => parseMealDraft(
    await _chat(mealDraftInstructions, description),
    provider: kind,
    model: readModel(),
  );

  @override
  Future<FoodLabelDraft> draftFoodLabel(String labelText) async =>
      parseFoodLabel(
        await _chat(foodLabelInstructions, labelText),
        provider: kind,
        model: readModel(),
      );

  /// One question, one whole answer: the model's reply text.
  Future<String> _chat(String instructions, String message) async {
    final key = await readKey();
    if (key == null || key.isEmpty) {
      throw const AiException(AiFailure.unavailable);
    }
    final http.Response response;
    try {
      response = await client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': readModel(),
              'stream': false,
              'messages': [
                {'role': 'system', 'content': instructions},
                {'role': 'user', 'content': message},
              ],
            }),
          )
          .timeout(_timeout);
    } on SocketException catch (error) {
      throw AiException(AiFailure.network, error.message);
    } on TimeoutException {
      throw const AiException(AiFailure.network, 'timed out');
    } on http.ClientException catch (error) {
      throw AiException(AiFailure.network, error.message);
    }
    switch (response.statusCode) {
      case 200:
        break;
      case 401 || 403:
        throw AiException(AiFailure.authentication, response.body);
      case 429:
        throw AiException(AiFailure.rateLimited, response.body);
      default:
        throw AiException(AiFailure.providerError, response.body);
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw AiException(AiFailure.unreadable, response.body);
    }
    return switch (body) {
      {'message': {'content': final String content}} => content,
      _ => throw AiException(AiFailure.unreadable, response.body),
    };
  }
}
