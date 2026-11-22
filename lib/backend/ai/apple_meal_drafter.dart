import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/domain.dart';
import '../engines/workout_text.dart';
import 'conversation.dart';
import 'food_label_json.dart';
import 'food_photo.dart';
import 'meal_draft_json.dart';
import 'meal_drafter.dart';
import 'meal_name.dart';
import 'workout_draft_json.dart';

/// Apple Intelligence's on-device model, reached through a small channel
/// to Swift
/// (`AppleIntelligence` in `ios/Runner/AppDelegate.swift`). There is no Flutter plugin
/// from Apple, and the job is small enough not to hang it on a 0.x one.
class AppleMealDrafter implements MealDrafter, AiConverser {
  const AppleMealDrafter();

  static const _channel = MethodChannel('mishirube/apple_intelligence');

  /// iOS and iPadOS, and macOS: the same bridge answers on each.
  static bool get _isApple => Platform.isIOS || Platform.isMacOS;

  @override
  AiProviderKind get kind => AiProviderKind.appleOnDevice;

  @override
  Future<String> modelName() async => 'Apple Intelligence';

  @override
  Future<AiAvailability> availability() async {
    if (!_isApple) return AiAvailability.unavailable;
    try {
      final status = await _channel.invokeMethod<String>('availability');
      return switch (status) {
        'available' => AiAvailability.available,
        'deviceNotEligible' => AiAvailability.deviceNotEligible,
        'appleIntelligenceNotEnabled' => AiAvailability.notEnabled,
        'modelNotReady' => AiAvailability.modelNotReady,
        _ => AiAvailability.unavailable,
      };
    } on MissingPluginException {
      return AiAvailability.unavailable;
    }
  }

  // The on-device model answers in one piece through the channel, so
  // the thinking sink is never fed; a draft reads the same without it.

  @override
  Future<MealDraft> draftMeal(
    String description, {
    ThinkingSink? onThinking,
  }) async => parseMealDraft(
    await _ask('draftMeal', mealDraftInstructions, description),
    provider: kind,
    model: await modelName(),
  );

  @override
  Future<FoodLabelDraft> draftFoodLabel(
    String labelText, {
    ThinkingSink? onThinking,
  }) async => parseFoodLabel(
    await _ask('draftFoodLabel', appleFoodLabelInstructions, labelText),
    provider: kind,
    model: await modelName(),
  );

  @override
  Future<List<WorkoutLine>> draftWorkout(
    String text, {
    ThinkingSink? onThinking,
  }) async => parseWorkoutDraft(
    await _ask('draftWorkout', workoutDraftInstructions, text),
  );

  @override
  Future<String> nameMeal(List<String> itemNames, {required String language}) =>
      _ask('nameMeal', mealNameInstructions(language), itemNames.join('、'));

  /// From iOS 27, where a model has vision.
  @override
  Future<bool> readsPhotos() async {
    if (!_isApple) return false;
    try {
      return await _channel.invokeMethod<bool>('readsPhotos') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The photo is read from its file by the Swift side, which gives the
  /// model its pixels alone.
  @override
  Future<PhotoDraft> draftPhoto(
    FoodPhoto photo, {
    String note = '',
    ThinkingSink? onThinking,
  }) async => parsePhoto(
    await _ask(
      'draftPhoto',
      applePhotoInstructions,
      note.trim().isEmpty ? '這張照片。' : '補充：${note.trim()}',
      path: photo.path,
    ),
    provider: kind,
    model: await modelName(),
  );

  /// How many earlier turns go with a message: the model's context is
  /// 4,096 tokens, and the tools' descriptions take their share of it.
  static const historyTurns = 6;

  /// The model calls the tools back through the channel while it works
  /// on the reply. The session has no memory of earlier turns, so the
  /// last few go in front of the message as text.
  @override
  Future<String> converse({
    required String instructions,
    required List<AiTurn> history,
    required String message,
    required List<AiTool> tools,
    required ToolRunner runTool,
    ThinkingSink? onThinking,
  }) async {
    final earlier = history.length > historyTurns
        ? history.sublist(history.length - historyTurns)
        : history;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'runTool') throw MissingPluginException();
      final arguments = call.arguments as Map<Object?, Object?>;
      final decoded = jsonDecode(arguments['arguments']! as String);
      return jsonEncode(
        runTool(
          arguments['name']! as String,
          decoded is Map<String, dynamic> ? decoded : const {},
        ),
      );
    });
    try {
      return await _ask(
        'converse',
        instructions,
        [
          for (final turn in earlier) '${turn.speaker.name}: ${turn.text}',
          if (earlier.isNotEmpty) '',
          message,
        ].join('\n'),
        tools: [
          for (final tool in tools)
            {
              'name': tool.name,
              'description': tool.description,
              'parameters': jsonEncode(tool.parameters),
            },
        ],
      );
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  /// Runs one of the Swift side's guided generations; its JSON answer.
  Future<String> _ask(
    String method,
    String instructions,
    String text, {
    String? path,
    List<Map<String, Object?>>? tools,
  }) async {
    try {
      return await _channel.invokeMethod<String>(method, {
            'instructions': instructions,
            'text': text,
            'path': ?path,
            'tools': ?tools,
          }) ??
          '';
    } on PlatformException catch (error) {
      throw AiException(switch (error.code) {
        'unavailable' => AiFailure.unavailable,
        'unsupported' => AiFailure.photoUnsupported,
        'rateLimited' => AiFailure.rateLimited,
        _ => AiFailure.providerError,
      }, error.message);
    } on MissingPluginException {
      throw const AiException(AiFailure.unavailable);
    }
  }
}
