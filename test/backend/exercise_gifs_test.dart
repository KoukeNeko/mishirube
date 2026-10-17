import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/backend/application/exercise_gifs.dart';

void main() {
  late Directory cache;
  final requested = <Uri>[];

  ExerciseGifs gifsAnswering(
    Future<http.Response> Function(http.Request request) answer,
  ) => ExerciseGifs(
    mediaIds: {'bench-press': 'abc1234'},
    directory: Directory('${cache.path}/gifs'),
    client: MockClient((request) {
      requested.add(request.url);
      return answer(request);
    }),
  );

  http.Response gif() =>
      http.Response.bytes(utf8.encode('GIF89a-the-picture'), 200);

  setUp(() {
    cache = Directory.systemTemp.createTempSync('exercise-gifs-test');
    requested.clear();
    addTearDown(() => cache.deleteSync(recursive: true));
  });

  test('a picture is fetched once and then read from the device', () async {
    final gifs = gifsAnswering((_) async => gif());
    expect(gifs.cached('bench-press'), isNull);

    final file = await gifs.fetch('bench-press');
    expect(file!.readAsBytesSync(), utf8.encode('GIF89a-the-picture'));
    expect(requested.single.toString(), endsWith('/media/abc1234.gif'));
    expect(gifs.cached('bench-press'), isNotNull);

    await gifs.fetch('bench-press');
    expect(requested, hasLength(1));
  });

  test('two cards asking for one picture share the download', () async {
    final gifs = gifsAnswering((_) async => gif());
    await Future.wait([gifs.fetch('bench-press'), gifs.fetch('bench-press')]);
    expect(requested, hasLength(1));
  });

  test('what is not a picture is not kept', () async {
    final refused = gifsAnswering((_) async => http.Response('nope', 403));
    expect(await refused.fetch('bench-press'), isNull);

    final page = gifsAnswering(
      (_) async => http.Response('<html>sign in</html>', 200),
    );
    expect(await page.fetch('bench-press'), isNull);
    expect(page.cached('bench-press'), isNull);
    expect(
      File('${cache.path}/gifs/abc1234.gif.part').existsSync(),
      isFalse,
      reason: 'a download cut short is never taken for the picture',
    );
  });

  test('no network is no picture, and the next try asks again', () async {
    var isOnline = false;
    final gifs = gifsAnswering(
      (_) async =>
          isOnline ? gif() : throw http.ClientException('no connection'),
    );
    expect(await gifs.fetch('bench-press'), isNull);
    isOnline = true;
    expect(await gifs.fetch('bench-press'), isNotNull);
    expect(requested, hasLength(2));
  });

  test('an exercise with no picture asks for nothing', () async {
    final gifs = gifsAnswering((_) async => gif());
    expect(gifs.has('squat'), isFalse);
    expect(await gifs.fetch('squat'), isNull);
    expect(ExerciseGifs.none().has('bench-press'), isFalse);
    expect(requested, isEmpty);
  });
}
