import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('mishirube/photo_library');

/// The newest photo in the library as a small JPEG about [pixels] on a
/// side, for the camera's library button (`PhotoLibrary` in
/// `ios/Runner/AppDelegate.swift`). Null where it cannot be read: before
/// the user allows it, and on Android, where the app only uses the
/// system photo picker instead of reading the library.
Future<Uint8List?> latestPhotoThumbnail(int pixels) async {
  if (kIsWeb || !Platform.isIOS) return null;
  try {
    return await _channel.invokeMethod<Uint8List>('latestThumbnail', {
      'pixels': pixels.toDouble(),
    });
  } on MissingPluginException {
    return null;
  }
}
