import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/backend/ai/cloud_drafter.dart';
import 'package:mishirube/backend/ai/copilot_drafter.dart';
import 'package:mishirube/backend/ai/food_photo.dart';
import 'package:mishirube/backend/ai/meal_draft_json.dart';
import 'package:mishirube/backend/ai/meal_drafter.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/backend/application/ai_service.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/workout_text.dart';
import 'package:mishirube/domain/domain.dart';

/// A JPEG's segments, each as its marker and payload.
Uint8List _jpeg(List<(int, List<int>)> segments, {List<int> scan = const []}) {
  final bytes = <int>[0xFF, 0xD8];
  for (final (marker, payload) in segments) {
    final length = payload.length + 2;
    bytes.addAll([0xFF, marker, length >> 8, length & 0xFF, ...payload]);
  }
  bytes.addAll([0xFF, 0xDA, 0x00, 0x04, 0x01, 0x02, ...scan, 0xFF, 0xD9]);
  return Uint8List.fromList(bytes);
}

bool _contains(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var found = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        found = false;
        break;
      }
    }
    if (found) return true;
  }
  return false;
}

final _gps = utf8.encode('GPS 25.0330N 121.5654E');
final _photo = _jpeg(
  [
    (0xE0, utf8.encode('JFIF\u0000')),
    (0xE1, [...utf8.encode('Exif\u0000\u0000'), ..._gps]),
    (0xE2, utf8.encode('ICC_PROFILE\u0000')),
    (0xDB, const [0, 1, 2, 3]),
    (0xFE, utf8.encode('shot on a phone')),
  ],
  scan: const [0xAA, 0xBB, 0xCC],
);

/// Answers a photo with the JSON it is given, and keeps what it was sent.
class _FakeDrafter implements MealDrafter {
  _FakeDrafter(this.kind, {this.canReadPhotos = true});

  @override
  final AiProviderKind kind;
  final bool canReadPhotos;
  final photos = <FoodPhoto>[];
  final notes = <String>[];

  @override
  Future<String> modelName() async => 'fake-1';

  @override
  Future<AiAvailability> availability() async => AiAvailability.available;

  @override
  Future<MealDraft> draftMeal(String description) => throw UnimplementedError();

  @override
  Future<FoodLabelDraft> draftFoodLabel(String labelText) =>
      throw UnimplementedError();

  @override
  Future<List<WorkoutLine>> draftWorkout(String text) =>
      throw UnimplementedError();

  @override
  Future<bool> readsPhotos() async => canReadPhotos;

  @override
  Future<MealDraft> draftMealPhoto(FoodPhoto photo, {String note = ''}) async {
    photos.add(photo);
    notes.add(note);
    return parseMealPhoto(
      '{"items":[{"name":"滷肉飯","amount":"約 300 g","kcal":620}]}',
      provider: kind,
      model: 'fake-1',
    );
  }
}

void main() {
  group('the photo that is sent', () {
    test('loses where and when it was taken, and keeps the picture', () {
      final stripped = stripJpegMetadata(_photo);

      expect(_contains(stripped, _gps), isFalse, reason: 'EXIF is gone');
      expect(_contains(stripped, utf8.encode('shot on a phone')), isFalse);
      expect(_contains(stripped, utf8.encode('JFIF')), isTrue);
      expect(
        _contains(stripped, utf8.encode('ICC_PROFILE')),
        isTrue,
        reason: 'the colour profile is part of the picture',
      );
      expect(
        _contains(stripped, const [0xFF, 0xDA, 0x00, 0x04, 1, 2, 0xAA]),
        isTrue,
        reason: 'the image data is copied as it is',
      );
      expect(imageMimeType(stripped), 'image/jpeg');
    });

    test('is recognised by its first bytes', () {
      Uint8List bytes(List<int> head) =>
          Uint8List.fromList([...head, ...List.filled(12, 0)]);
      expect(imageMimeType(bytes([0x89, 0x50, 0x4E, 0x47])), 'image/png');
      expect(
        imageMimeType(
          bytes([...utf8.encode('RIFF'), 0, 0, 0, 0, ...utf8.encode('WEBP')]),
        ),
        'image/webp',
      );
      expect(
        imageMimeType(bytes([0, 0, 0, 0x18, ...utf8.encode('ftypheic')])),
        isNull,
        reason: 'HEIC is not read by every provider',
      );
    });

    test('a file that is not a JPEG passes through unchanged', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      expect(stripJpegMetadata(png), png);
    });
  });

  group('reading a photo answer', () {
    MealDraft parse(String json) =>
        parseMealPhoto(json, provider: AiProviderKind.anthropic, model: 'm');

    test('keeps each item, and what the photo cannot show', () {
      final draft = parse(
        '{"items":[{"name":"白飯","amount":"約 180 g（150–220 g）",'
        '"kcal":250,"protein_g":5,"carb_g":56,"fat_g":0},'
        '{"name":"炒高麗菜","amount":"約 80 g","kcal":null}],'
        '"notes":["炒菜油的量看不出來"]}',
      );

      expect(draft.items.map((item) => item.name), ['白飯', '炒高麗菜']);
      expect(draft.items.first.amount, '約 180 g（150–220 g）');
      expect(draft.items.last.kcal, isNull, reason: 'unknown is not zero');
      expect(draft.warnings, ['炒菜油的量看不出來']);
    });

    test('energy far from its macronutrients is flagged, not changed', () {
      final draft = parse(
        '{"items":[{"name":"雞腿","kcal":900,"protein_g":20,'
        '"carb_g":0,"fat_g":10}],"notes":[]}',
      );

      expect(draft.items.single.kcal, 900);
      expect(draft.warnings.single, contains('雞腿'));
    });

    test('a photo with no food in it says so', () {
      expect(
        () => parse('{"items":[],"notes":[]}'),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.noFood,
          ),
        ),
      );
    });
  });

  group('asking for a photo estimate', () {
    late Backend backend;
    late File file;

    setUp(() async {
      backend = Backend.inMemory();
      file = File(
        '${(await Directory.systemTemp.createTemp('photo')).path}/meal.jpg',
      )..writeAsBytesSync(_photo);
    });

    tearDown(() => backend.close());

    AiService service(MealDrafter drafter) => AiService(
      backend.db,
      secrets: MemorySecretStore(),
      drafters: {drafter.kind: drafter},
    )..setProvider(drafter.kind);

    Matcher failsWith(AiFailure failure) => throwsA(
      isA<AiException>().having((e) => e.failure, 'failure', failure),
    );

    test('agreeing to send text does not cover a photo', () async {
      final cloud = _FakeDrafter(AiProviderKind.ollamaCloud);
      final ai = service(cloud)..setCloudConsent(true);

      await expectLater(
        ai.draftMealPhoto(file.path),
        failsWith(AiFailure.needsPhotoConsent),
      );
      expect(cloud.photos, isEmpty, reason: 'nothing was sent');

      ai.setPhotoConsent(true);
      final draft = await ai.draftMealPhoto(file.path, note: '飯半碗');
      expect(draft.items.single.name, '滷肉飯');
      expect(cloud.notes, ['飯半碗']);
      expect(_contains(cloud.photos.single.bytes, _gps), isFalse);
      expect(cloud.photos.single.mimeType, 'image/jpeg');
    });

    test('a provider that cannot look at photos is not sent one', () async {
      final copilot = _FakeDrafter(
        AiProviderKind.microsoftCopilot,
        canReadPhotos: false,
      );
      final ai = service(copilot)..setPhotoConsent(true);

      await expectLater(
        ai.draftMealPhoto(file.path),
        failsWith(AiFailure.photoUnsupported),
      );
      expect(copilot.photos, isEmpty);
    });

    test('the on-device model needs no consent', () async {
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice);

      await service(apple).draftMealPhoto(file.path);
      expect(apple.photos, hasLength(1));
    });

    test('a format the providers cannot read is not sent', () async {
      file.writeAsBytesSync([0, 0, 0, 0x18, ...utf8.encode('ftypheic')]);
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice);

      await expectLater(
        service(apple).draftMealPhoto(file.path),
        failsWith(AiFailure.photoFormat),
      );
      expect(apple.photos, isEmpty);
    });
  });

  group('each provider sends the photo its own way', () {
    final photo = FoodPhoto(
      path: '/meal.jpg',
      bytes: _photo,
      mimeType: 'image/jpeg',
    );
    const answer = '{"items":[{"name":"滷肉飯","kcal":620}],"notes":[]}';
    Future<String?> key() async => 'k-123';

    Future<Map<String, dynamic>> sentBy(
      CloudDrafter Function(http.Client) make,
      Object reply,
    ) async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes(utf8.encode(jsonEncode(reply)), 200);
      });
      final draft = await make(client).draftMealPhoto(photo, note: '飯半碗');
      expect(draft.items.single.name, '滷肉飯');
      return jsonDecode(sent.body) as Map<String, dynamic>;
    }

    test('Ollama Cloud: base64 in the message', () async {
      final body = await sentBy(
        (client) => OllamaDrafter(
          client: client,
          readKey: key,
          readModel: () => 'gemma4:31b',
        ),
        {
          'message': {'content': answer},
        },
      );
      final message = (body['messages'] as List).last as Map;
      expect(message['images'], [photo.base64]);
      expect(message['content'], '補充：飯半碗');
    });

    test('Google AI Studio: inline data before the text', () async {
      final body = await sentBy(
        (client) => GoogleAiStudioDrafter(
          client: client,
          readKey: key,
          readModel: () => 'gemini-3.8-flash',
        ),
        {
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': answer},
                ],
              },
            },
          ],
        },
      );
      final parts = ((body['contents'] as List).single as Map)['parts'] as List;
      expect(parts.first, {
        'inlineData': {'mimeType': 'image/jpeg', 'data': photo.base64},
      });
      expect(parts.last, {'text': '補充：飯半碗'});
    });

    test('Anthropic: an image block before the text', () async {
      final body = await sentBy(
        (client) => AnthropicDrafter(
          client: client,
          readKey: key,
          readModel: () => 'claude',
        ),
        {
          'content': [
            {'type': 'text', 'text': answer},
          ],
        },
      );
      final content =
          ((body['messages'] as List).single as Map)['content'] as List;
      expect(content.first, {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/jpeg',
          'data': photo.base64,
        },
      });
      expect(content.last, {'type': 'text', 'text': '補充：飯半碗'});
    });

    test('an OpenAI-shaped address: a data URL', () async {
      final body = await sentBy(
        (client) => OpenAiCompatibleDrafter(
          client: client,
          readKey: key,
          readModel: () => 'gpt',
          readEndpoint: () => 'https://example.com/v1',
        ),
        {
          'choices': [
            {
              'message': {'content': answer},
            },
          ],
        },
      );
      final content =
          ((body['messages'] as List).last as Map)['content'] as List;
      expect(content.last, {
        'type': 'image_url',
        'image_url': {'url': photo.dataUrl, 'detail': 'high'},
      });
    });

    test('Microsoft 365 Copilot takes no photo, and sends nothing', () async {
      var requests = 0;
      final copilot = CopilotDrafter(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
        readKey: key,
        readModel: () => '',
        readClientId: () => 'client',
        readTenant: () => '',
        saveRefreshToken: (_) async {},
      );

      expect(await copilot.readsPhotos(), isFalse);
      await expectLater(
        copilot.draftMealPhoto(photo),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.photoUnsupported,
          ),
        ),
      );
      expect(requests, 0);
    });
  });
}
