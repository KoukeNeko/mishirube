import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Which ExerciseDB picture shows each exercise, by exercise id; built by
/// `tool/merge_exercise_catalogue.py`.
const exerciseGifIdsFile = 'assets/exercises/gifs.json';

const _mediaHost = 'https://static.exercisedb.dev/media';
const _timeout = Duration(seconds: 20);

/// The animated demonstrations of ExerciseDB (free hosted tier, 180 p).
/// One is downloaded the first time its exercise is shown and kept in the
/// cache folder, which the system may empty and which no backup holds, so
/// that library never rides along on the device. Only the picture's name
/// is sent. An exercise whose picture cannot be had keeps its poses.
class ExerciseGifs {
  ExerciseGifs({
    required this._mediaIds,
    required this._directory,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// No pictures at all: tests and previews, which never touch a network.
  ExerciseGifs.none()
    : _mediaIds = const {},
      _directory = Directory.systemTemp,
      _client = http.Client();

  static Future<ExerciseGifs> onDevice({http.Client? client}) async {
    final ids = jsonDecode(await rootBundle.loadString(exerciseGifIdsFile));
    final cache = await getApplicationCacheDirectory();
    return ExerciseGifs(
      mediaIds: (ids as Map<String, dynamic>).cast<String, String>(),
      directory: Directory(p.join(cache.path, 'exercise-gifs')),
      client: client,
    );
  }

  final Map<String, String> _mediaIds;
  final Directory _directory;
  final http.Client _client;

  /// Downloads under way, so two cards asking for one picture share it.
  final _downloads = <String, Future<File?>>{};

  /// Whether the exercise has a picture to be had.
  bool has(String exerciseId) => _mediaIds.containsKey(exerciseId);

  File _fileOf(String mediaId) => File(p.join(_directory.path, '$mediaId.gif'));

  /// The picture when it is already on the device.
  File? cached(String exerciseId) {
    final mediaId = _mediaIds[exerciseId];
    if (mediaId == null) return null;
    final file = _fileOf(mediaId);
    return file.existsSync() ? file : null;
  }

  /// Forgets a picture that turned out not to be one, so it is fetched
  /// again the next time.
  void discard(String exerciseId) => cached(exerciseId)?.deleteSync();

  /// The picture, downloaded first when it is not on the device; null when
  /// there is none or it could not be fetched (offline, a refusal).
  Future<File?> fetch(String exerciseId) {
    final mediaId = _mediaIds[exerciseId];
    if (mediaId == null) return Future.value();
    return _downloads.putIfAbsent(
      mediaId,
      // A block, not an arrow: `remove` returns this very future, and
      // `whenComplete` would wait on it for ever.
      () => _download(mediaId).whenComplete(() {
        _downloads.remove(mediaId);
      }),
    );
  }

  Future<File?> _download(String mediaId) async {
    final file = _fileOf(mediaId);
    if (file.existsSync()) return file;
    try {
      final response = await _client
          .get(Uri.parse('$_mediaHost/$mediaId.gif'))
          .timeout(_timeout);
      if (response.statusCode != 200 || !_isGif(response.bodyBytes)) {
        return null;
      }
      await _directory.create(recursive: true);
      // Written whole, then named, so a download cut short is never taken
      // for the picture.
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(response.bodyBytes, flush: true);
      return await partial.rename(file.path);
    } on TimeoutException {
      return null;
    } on http.ClientException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// "GIF87a" or "GIF89a": a refusal page is not a picture.
  static bool _isGif(List<int> bytes) =>
      bytes.length > 6 && String.fromCharCodes(bytes.take(4)) == 'GIF8';
}
