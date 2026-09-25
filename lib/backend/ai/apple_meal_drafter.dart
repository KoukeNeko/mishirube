import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/domain.dart';
import '../engines/workout_text.dart';
import 'food_label_json.dart';
import 'food_photo.dart';
import 'meal_draft_json.dart';
import 'meal_drafter.dart';
import 'workout_draft_json.dart';

/// Apple's on-device model, reached through a small channel to Swift
/// (`AppleIntelligence` in `ios/Runner/AppDelegate.swift`). There is no Flutter plugin
/// from Apple, and the job is small enough not to hang it on a 0.x one.
class AppleMealDrafter implements MealDrafter {
  const AppleMealDrafter();

  static const _channel = MethodChannel('mishirube/apple_intelligence');

  /// iOS and iPadOS, and macOS: the same bridge answers on each.
  static bool get _isApple => Platform.isIOS || Platform.isMacOS;

  @override
  AiProviderKind get kind => AiProviderKind.appleOnDevice;

  @override
  Future<String> modelName() async => 'Apple 裝置端模型';

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

  @override
  Future<MealDraft> draftMeal(String description) async => parseMealDraft(
    await _ask('draftMeal', mealDraftInstructions, description),
    provider: kind,
    model: await modelName(),
  );

  @override
  Future<FoodLabelDraft> draftFoodLabel(String labelText) async =>
      parseFoodLabel(
        await _ask('draftFoodLabel', foodLabelInstructions, labelText),
        provider: kind,
        model: await modelName(),
      );

  @override
  Future<List<WorkoutLine>> draftWorkout(String text) async =>
      parseWorkoutDraft(
        await _ask('draftWorkout', workoutDraftInstructions, text),
      );

  /// On the device from iOS 27, where the model has vision.
  @override
  Future<bool> readsPhotos() async {
    if (!_isApple) return false;
    try {
      return await _channel.invokeMethod<bool>('readsPhotos') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The photo is read on the device, from its file; nothing is sent.
  @override
  Future<MealDraft> draftMealPhoto(FoodPhoto photo, {String note = ''}) async =>
      parseMealPhoto(
        await _ask(
          'draftMealPhoto',
          mealPhotoInstructions,
          note.trim().isEmpty ? '這張照片裡的食物。' : '補充：${note.trim()}',
          path: photo.path,
        ),
        provider: kind,
        model: await modelName(),
      );

  /// Runs one of the Swift side's guided generations; its JSON answer.
  Future<String> _ask(
    String method,
    String instructions,
    String text, {
    String? path,
  }) async {
    try {
      return await _channel.invokeMethod<String>(method, {
            'instructions': instructions,
            'text': text,
            'path': ?path,
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
