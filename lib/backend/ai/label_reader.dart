import 'package:flutter/services.dart';

import '../../domain/domain.dart';

/// Reads the text in a photo, on the phone: Apple's Vision on iOS
/// (`LabelReader` in `ios/Runner/AppDelegate.swift`), ML Kit on Android
/// (`LabelReaderBridge.kt`). The photo never leaves the device; only the
/// text it yields may go on to a model.
abstract interface class LabelReader {
  Future<List<TextLine>> readText(String imagePath);
}

class PlatformLabelReader implements LabelReader {
  const PlatformLabelReader();

  static const _channel = MethodChannel('mishirube/ocr');

  @override
  Future<List<TextLine>> readText(String imagePath) async {
    final List<Map<Object?, Object?>>? rows;
    try {
      rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'recognizeText',
        {'path': imagePath},
      );
    } on PlatformException catch (error) {
      throw AiException(AiFailure.providerError, error.message);
    } on MissingPluginException {
      throw const AiException(AiFailure.unavailable);
    }
    return [
      for (final row in rows ?? const <Map<Object?, Object?>>[])
        TextLine(
          text: row['text']! as String,
          left: (row['left']! as num).toDouble(),
          top: (row['top']! as num).toDouble(),
          width: (row['width']! as num).toDouble(),
          height: (row['height']! as num).toDouble(),
        ),
    ];
  }
}

/// No text recognition: tests and previews.
class NoLabelReader implements LabelReader {
  const NoLabelReader();

  @override
  Future<List<TextLine>> readText(String imagePath) async => const [];
}
