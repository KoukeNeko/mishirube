import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/domain.dart';
import 'food_label_json.dart';
import 'meal_draft_json.dart';
import 'meal_drafter.dart';

/// Apple's on-device model, reached through a small channel to Swift
/// (`AppleIntelligence` in `ios/Runner/AppDelegate.swift`). There is no Flutter plugin
/// from Apple, and the job is small enough not to hang it on a 0.x one.
class AppleMealDrafter implements MealDrafter {
  const AppleMealDrafter();

  static const _channel = MethodChannel('mishirube/apple_intelligence');

  @override
  AiProviderKind get kind => AiProviderKind.appleOnDevice;

  @override
  Future<String> modelName() async => 'Apple 裝置端模型';

  @override
  Future<AiAvailability> availability() async {
    if (!Platform.isIOS) return AiAvailability.unavailable;
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

  /// Runs one of the Swift side's guided generations; its JSON answer.
  Future<String> _ask(String method, String instructions, String text) async {
    try {
      return await _channel.invokeMethod<String>(method, {
            'instructions': instructions,
            'text': text,
          }) ??
          '';
    } on PlatformException catch (error) {
      throw AiException(switch (error.code) {
        'unavailable' => AiFailure.unavailable,
        'rateLimited' => AiFailure.rateLimited,
        _ => AiFailure.providerError,
      }, error.message);
    } on MissingPluginException {
      throw const AiException(AiFailure.unavailable);
    }
  }
}
