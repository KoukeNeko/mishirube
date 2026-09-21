import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/domain.dart';
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
  Future<MealDraft> draftMeal(String description) async {
    final String? answer;
    try {
      answer = await _channel.invokeMethod<String>('draftMeal', {
        'instructions': mealDraftInstructions,
        'text': description,
      });
    } on PlatformException catch (error) {
      throw AiException(switch (error.code) {
        'unavailable' => AiFailure.unavailable,
        'rateLimited' => AiFailure.rateLimited,
        _ => AiFailure.providerError,
      }, error.message);
    } on MissingPluginException {
      throw const AiException(AiFailure.unavailable);
    }
    return parseMealDraft(
      answer ?? '',
      provider: kind,
      model: await modelName(),
    );
  }
}
