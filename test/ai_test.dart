import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/ai/food_label_json.dart';
import 'package:mishirube/backend/ai/food_photo.dart';
import 'package:mishirube/backend/ai/label_reader.dart';
import 'package:mishirube/backend/ai/meal_draft_json.dart';
import 'package:mishirube/backend/ai/meal_drafter.dart';
import 'package:mishirube/backend/ai/cloud_drafter.dart';
import 'package:mishirube/backend/ai/copilot_drafter.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/backend/ai/workout_draft_json.dart';
import 'package:mishirube/backend/application/ai_service.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/label_text.dart';
import 'package:mishirube/backend/engines/workout_text.dart';
import 'package:mishirube/backend/engines/nutrition_summary.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/me/ai_draft_parts.dart';
import 'package:mishirube/features/me/ai_settings_screen.dart';
import 'package:mishirube/features/nutrition/describe_meal_screen.dart';
import 'package:mishirube/features/nutrition/food_edit_screen.dart';
import 'package:mishirube/features/training/describe_workout_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import 'support/harness.dart';

/// A drafter that answers from a list, and says what it was asked.
class _FakeDrafter implements MealDrafter {
  _FakeDrafter(this.kind, this.items);

  @override
  final AiProviderKind kind;
  final List<DraftItem> items;
  final asked = <String>[];

  @override
  Future<String> modelName() async => 'fake-1';

  /// What it says about itself: Apple's model can be off.
  AiAvailability status = AiAvailability.available;

  @override
  Future<AiAvailability> availability() async => status;

  @override
  Future<MealDraft> draftMeal(String description) async {
    asked.add(description);
    return MealDraft(items: items, provider: kind, model: 'fake-1');
  }

  /// The label text it was given; answers with a model's JSON for it.
  final labels = <String>[];
  String labelAnswer =
      '{"name":"燕麥奶","serving_amount":200,"serving_unit":"ml",'
      '"kcal":120,"protein_g":2.4,"fat_g":5,"saturated_fat_g":0.5,'
      '"carb_g":16,"sugar_g":7,"sodium_mg":95}';

  @override
  Future<FoodLabelDraft> draftFoodLabel(String labelText) async {
    labels.add(labelText);
    return parseFoodLabel(labelAnswer, provider: kind, model: 'fake-1');
  }

  /// Whether it can look at a photo, and the photos and notes it was
  /// given; answers with a model's JSON for them.
  bool canReadPhotos = true;
  final photos = <FoodPhoto>[];
  final notes = <String>[];
  String photoAnswer =
      '{"items":[{"name":"滷肉飯","amount":"約 300 g","kcal":620,'
      '"protein_g":18,"carb_g":82,"fat_g":24,"is_drink":false}],'
      '"notes":["滷汁的油量看不出來"]}';

  @override
  Future<bool> readsPhotos() async => canReadPhotos;

  @override
  Future<MealDraft> draftMealPhoto(FoodPhoto photo, {String note = ''}) async {
    photos.add(photo);
    notes.add(note);
    return parseMealPhoto(photoAnswer, provider: kind, model: 'fake-1');
  }

  /// The workouts it was given; answers with a model's JSON for them, or
  /// fails as [workoutFailure] says.
  final workouts = <String>[];
  String workoutAnswer = '{"exercises":[]}';
  AiFailure? workoutFailure;

  @override
  Future<List<WorkoutLine>> draftWorkout(String text) async {
    workouts.add(text);
    if (workoutFailure case final failure?) throw AiException(failure);
    return parseWorkoutDraft(workoutAnswer);
  }
}

/// Text recognition as a list of lines.
class _FakeReader implements LabelReader {
  _FakeReader(this.lines);

  final List<TextLine> lines;
  final read = <String>[];

  @override
  Future<List<TextLine>> readText(String imagePath) async {
    read.add(imagePath);
    return lines;
  }
}

TextLine _line(String text, double left, double top) =>
    TextLine(text: text, left: left, top: top, width: 0.2, height: 0.04);

const _eggPancake = DraftItem(name: '蛋餅', amount: '一份', kcal: 250);
const _milkTea = DraftItem(name: '冰奶茶', amount: '大杯', kcal: 300, isDrink: true);

void main() {
  group('Apple Intelligence without asking', () {
    AiService serviceWith(_FakeDrafter apple, [_FakeDrafter? cloud]) =>
        AiService(
          Backend.inMemory().db,
          secrets: MemorySecretStore(),
          drafters: {apple.kind: apple, ?cloud?.kind: ?cloud},
        );

    test('is used when it is on and nothing else was chosen', () async {
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, [_eggPancake]);
      final ai = serviceWith(apple);
      expect(ai.provider, isNull, reason: 'not looked at yet');

      await ai.refreshOnDevice();
      expect(ai.provider, AiProviderKind.appleOnDevice);
      final draft = await ai.draftMeal('蛋餅');
      expect(draft.items.single.name, '蛋餅', reason: 'no consent to ask');
    });

    test('is not used while Apple Intelligence is off', () async {
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, [_eggPancake])
        ..status = AiAvailability.notEnabled;
      final ai = serviceWith(apple);
      await ai.refreshOnDevice();
      expect(ai.provider, isNull);
    });

    test('a provider the user chose comes first', () async {
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, [_eggPancake]);
      final cloud = _FakeDrafter(AiProviderKind.ollamaCloud, [_milkTea]);
      final ai = serviceWith(apple, cloud)
        ..setProvider(AiProviderKind.ollamaCloud);
      await ai.refreshOnDevice();
      expect(ai.provider, AiProviderKind.ollamaCloud);
    });
  });

  group('reading a model answer', () {
    MealDraft parse(String answer) => parseMealDraft(
      answer,
      provider: AiProviderKind.ollamaCloud,
      model: 'm',
    );

    test('finds the JSON inside whatever the model wrapped it in', () {
      final draft = parse('''
好的，以下是結果：
```json
{"items":[{"name":"蛋餅","amount":"","kcal":250.4,"protein_g":9,
"carb_g":null,"fat_g":12,"is_drink":false}]}
```''');
      final item = draft.items.single;
      expect(item.name, '蛋餅');
      expect(item.amount, '一份', reason: 'no amount is one serving');
      expect(item.kcal, 250);
      expect(item.carbGrams, isNull, reason: 'unknown stays unknown');
    });

    test('keeps every row a printed label gave', () {
      final item = parse(
        '{"items":[{"name":"巧克力乳清蛋白飲","amount":"250 ml","kcal":186,'
        '"protein_g":21,"carb_g":21,"fat_g":2,"fibre_g":null,'
        '"nutrients":{"saturated_fat_g":1.5,"trans_fat_g":0,"sugar_g":14.4,'
        '"sodium_mg":79,"calcium_mg":667,"valine_mg":1047,'
        '"isoleucine_mg":867,"leucine_mg":1571,"sparkle_g":3},'
        '"is_drink":true}]}',
      ).items.single;
      expect(item.nutrients, {
        Nutrient.saturatedFat: 1.5,
        Nutrient.transFat: 0,
        Nutrient.sugar: 14.4,
        Nutrient.sodium: 79,
        Nutrient.calcium: 667,
        Nutrient.valine: 1047,
        Nutrient.isoleucine: 867,
        Nutrient.leucine: 1571,
      }, reason: 'a key the app does not know is left out');
      expect(item.fibreGrams, isNull);
    });

    test('the prompts ask for nutrients under the keys the parser reads', () {
      for (final prompt in [mealDraftInstructions, mealPhotoInstructions]) {
        expect(prompt, contains('sugar_g'));
        expect(prompt, contains('leucine_mg'));
      }
      expect(foodLabelInstructions, contains('calcium_mg'));
      expect(foodLabelInstructions, contains('polyols_g'));
    });

    test('a drink with alcohol carries its grams', () {
      expect(mealDraftInstructions, contains('alcohol_g'));
      final beer = parse(
        '{"items":[{"name":"啤酒","amount":"330 ml","kcal":142,'
        '"protein_g":1,"carb_g":12,"fat_g":0,'
        '"nutrients":{"alcohol_g":13},"is_drink":true}]}',
      ).items.single;
      expect(beer.nutrients[Nutrient.alcohol], 13);
    });

    test('drops a figure no meal could have instead of trusting it', () {
      final item = parse(
        '{"items":[{"name":"雞排","kcal":23000,"protein_g":-4}]}',
      ).items.single;
      expect(item.kcal, isNull);
      expect(item.proteinGrams, isNull);
    });

    test('an answer with nothing to draft is unreadable', () {
      for (final answer in ['我不確定', '{"items":[]}', '{"items":[{"kcal":1}]}']) {
        expect(
          () => parse(answer),
          throwsA(
            isA<AiException>().having(
              (e) => e.failure,
              'failure',
              AiFailure.unreadable,
            ),
          ),
          reason: answer,
        );
      }
    });
  });

  group('reading a label', () {
    test('pieces on the same line become one row, left to right', () {
      final text = labelTextFrom([
        _line('400 大卡', 0.7, 0.301),
        _line('熱量', 0.1, 0.3),
        _line('120 大卡', 0.4, 0.305),
        _line('營養標示', 0.3, 0.1),
        _line('蛋白質', 0.1, 0.36),
        _line('3.2 公克', 0.4, 0.358),
      ]);
      expect(text, '營養標示\n熱量  120 大卡  400 大卡\n蛋白質  3.2 公克');
    });

    test('a figure that cannot be what the label says is left blank', () {
      final draft = parseFoodLabel(
        '{"serving_amount":30,"serving_unit":"公克","kcal":150,'
        '"fat_g":5,"saturated_fat_g":8,"carb_g":20,"sugar_g":25,'
        '"sodium_mg":18000,"protein_g":3}',
        provider: AiProviderKind.appleOnDevice,
        model: 'm',
      );
      expect(draft.servingAmount, 30);
      expect(draft.servingUnit, ServingUnit.gram);
      expect(draft.kcal, 150);
      expect(
        draft.nutrients.keys,
        isEmpty,
        reason:
            'saturated fat above total fat, sugar above carbohydrate and '
            '18 g of sodium in 30 g are misreadings, not the label',
      );
    });

    test('a figure sent as text off the label is still read', () {
      final draft = parseFoodLabel(
        '{"serving_amount":"30","serving_unit":"g","kcal":"150 大卡",'
        '"protein_g":"3.2公克","fat_g":8,"sodium_mg":"1,200毫克",'
        '"sugar_g":"不明"}',
        provider: AiProviderKind.ollamaCloud,
        model: 'm',
      );
      expect(draft.servingAmount, 30);
      expect(draft.kcal, 150);
      expect(draft.proteinGrams, 3.2, reason: 'the label\'s decimals stay');
      expect(draft.nutrients[Nutrient.sodium], 1200);
      expect(draft.nutrients[Nutrient.sugar], isNull, reason: 'not a figure');
    });

    test('swapped columns and energy that does not add up are flagged', () {
      FoodLabelDraft parse(String json) => parseFoodLabel(
        json,
        provider: AiProviderKind.appleOnDevice,
        model: 'm',
      );
      // 30 g of something with 400 kcal per 100 g is 120 a serving.
      final right = parse(
        '{"serving_amount":30,"serving_unit":"g","kcal":120,'
        '"kcal_per_100":400,"protein_g":3,"carb_g":18,"fat_g":4}',
      );
      expect(right.warnings, isEmpty);

      final swapped = parse(
        '{"serving_amount":30,"serving_unit":"g","kcal":400,'
        '"kcal_per_100":120}',
      );
      expect(swapped.kcal, 400, reason: 'still filled in, for the user');
      expect(swapped.warnings.single, contains('另一欄'));

      final offEnergy = parse(
        '{"kcal":500,"protein_g":3,"carb_g":18,"fat_g":4}',
      );
      expect(offEnergy.warnings.single, contains('蛋白質、碳水化合物、脂肪'));
    });

    test('the photo is read on the phone and only its text is sent', () async {
      final backend = Backend.inMemory();
      addTearDown(backend.close);
      final cloud = _FakeDrafter(AiProviderKind.ollamaCloud, const []);
      final reader = _FakeReader([
        _line('每一份量 200 毫升', 0.1, 0.1),
        _line('熱量', 0.1, 0.2),
        _line('120 大卡', 0.5, 0.2),
      ]);
      final ai = AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {AiProviderKind.ollamaCloud: cloud},
        labelReader: reader,
      )..setProvider(AiProviderKind.ollamaCloud);

      await expectLater(
        ai.scanFoodLabel('/photo.jpg'),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.needsConsent,
          ),
        ),
      );
      expect(reader.read, isEmpty, reason: 'not even read before consent');

      ai.setCloudConsent(true);
      final draft = await ai.scanFoodLabel('/photo.jpg');
      expect(cloud.labels, ['每一份量 200 毫升\n熱量  120 大卡']);
      expect(draft.kcal, 120);
    });

    test('a photo with no text asks for another', () async {
      final backend = Backend.inMemory();
      addTearDown(backend.close);
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, const []);
      final ai = AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {AiProviderKind.appleOnDevice: apple},
        labelReader: _FakeReader(const []),
      )..setProvider(AiProviderKind.appleOnDevice);

      await expectLater(
        ai.scanFoodLabel('/blank.jpg'),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.noText,
          ),
        ),
      );
      expect(apple.labels, isEmpty);
    });
  });

  testWidgets('the model is chosen from what the provider offers', (
    tester,
  ) async {
    final backend = Backend.inMemory(clock: FakeClock().now);
    final client = MockClient(
      (_) async => http.Response(
        '{"data":[{"id":"gemma4:31b"},{"id":"qwen3:8b"}]}',
        200,
      ),
    );
    final secrets = MemorySecretStore();
    final ai = AiService(
      backend.db,
      secrets: secrets,
      drafters: {
        AiProviderKind.ollamaCloud: OllamaDrafter(
          client: client,
          readKey: () async => 'k-123',
          readModel: () => 'gemma4:31b',
        ),
      },
    )..setProvider(AiProviderKind.ollamaCloud);
    final store = AppStore(
      clock: FakeClock().now,
      isOnboarded: true,
      backend: backend,
      ai: ai,
    );
    await pumpScreen(tester, const AiSettingsScreen(), store: store);

    await tester.tap(find.text('模型'));
    await tester.pumpAndSettle();
    expect(find.text('qwen3:8b'), findsOneWidget, reason: 'listed to pick');
    await tester.tap(find.text('qwen3:8b'));
    await tester.pumpAndSettle();

    expect(store.aiModel, 'qwen3:8b');
    expect(find.text('qwen3:8b'), findsOneWidget, reason: 'now the model');
    await disposeTree(tester);
  });

  testWidgets('a label photo from the library fills the form to check', (
    tester,
  ) async {
    final backend = Backend.inMemory(clock: FakeClock().now);
    final apple = _FakeDrafter(AiProviderKind.appleOnDevice, const []);
    final store = AppStore(
      clock: FakeClock().now,
      isOnboarded: true,
      backend: backend,
      ai: AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {AiProviderKind.appleOnDevice: apple},
        labelReader: _FakeReader([_line('熱量 120 大卡', 0.1, 0.1)]),
      )..setProvider(AiProviderKind.appleOnDevice),
    );
    final cameras = <String>[];
    await pumpScreen(
      tester,
      FoodEditScreen(
        takePhoto: (title) async {
          cameras.add(title);
          return '/label.jpg';
        },
      ),
      store: store,
    );
    final foods = store.backend.nutrition.searchFoods('').length;

    await tester.tap(find.bySemanticsLabel('掃描食物或營養標示'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppDialog), matching: find.text('營養標示')),
    );
    await tester.pumpAndSettle();

    expect(cameras, ['營養標示'], reason: 'the camera opens for a label');
    expect(find.textContaining('請對照包裝核對'), findsOneWidget);
    expect(find.text('燕麥奶'), findsOneWidget, reason: 'the name, filled');
    await tester.dragUntilVisible(
      find.text('120'),
      find.byType(CustomScrollView).first,
      const Offset(0, -200),
    );
    expect(find.text('120'), findsOneWidget, reason: 'the calories, filled');
    await tester.dragUntilVisible(
      find.text('2.4'),
      find.byType(CustomScrollView).first,
      const Offset(0, -200),
    );
    expect(
      find.text('2.4'),
      findsOneWidget,
      reason: "the protein as the label printed it, not rounded to 2",
    );
    expect(
      store.backend.nutrition.searchFoods('').length,
      foods,
      reason: 'nothing is saved until the user saves it',
    );
    await disposeTree(tester);
  });

  group('a food photo', () {
    // The smallest JPEG the service accepts: what the picker would hand
    // it, without a real file behind it.
    final jpeg = Uint8List.fromList(const [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x02, //
      0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9,
    ]);

    AppStore storeWith(_FakeDrafter drafter) {
      final backend = Backend.inMemory(clock: FakeClock().now);
      return AppStore(
        clock: FakeClock().now,
        isOnboarded: true,
        backend: backend,
        ai: AiService(
          backend.db,
          secrets: MemorySecretStore(),
          drafters: {drafter.kind: drafter},
          readPhoto: (_) async => jpeg,
        )..setProvider(drafter.kind),
      );
    }

    Future<void> scanFood(WidgetTester tester, {String note = ''}) async {
      await tester.tap(find.bySemanticsLabel('掃描食物或營養標示'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AppDialog), matching: find.text('食物')),
      );
      await tester.pumpAndSettle();
      if (note.isNotEmpty) {
        await tester.enterText(find.byType(TextField).last, note);
      }
      await tester.tap(find.text('估算'));
      await tester.pumpAndSettle();
    }

    FoodEditScreen screen({bool logsOnce = false}) =>
        FoodEditScreen(logsOnce: logsOnce, takePhoto: (_) async => '/meal.jpg');

    testWidgets('fills a quick record, which logs the estimate', (
      tester,
    ) async {
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, const []);
      final store = storeWith(apple);
      await pumpScreen(tester, screen(logsOnce: true), store: store);
      final before = store.todayKcal;

      await scanFood(tester, note: '飯半碗');

      expect(apple.notes, ['飯半碗'], reason: 'the note goes with the photo');
      expect(find.text('滷肉飯'), findsOneWidget, reason: 'the name, filled');
      expect(find.textContaining('從照片的估算'), findsOneWidget);
      expect(
        find.textContaining('滷汁的油量看不出來'),
        findsOneWidget,
        reason: 'what the photo cannot show is said',
      );
      await tester.tap(find.text('記錄'));
      await tester.pumpAndSettle();
      expect(store.todayKcal, before + 620);
      await disposeTree(tester);
    });

    testWidgets('saved as a food, its figures are marked as an estimate', (
      tester,
    ) async {
      final store = storeWith(
        _FakeDrafter(AiProviderKind.appleOnDevice, const []),
      );
      await pumpScreen(tester, screen(), store: store);

      await scanFood(tester);
      await tester.tap(find.text('只建立'));
      await tester.pumpAndSettle();

      final saved = store.backend.nutrition.searchFoods('滷肉飯').single;
      expect(saved.kcal, 620);
      expect(saved.servingAmount, 300);
      expect(saved.servingUnit, ServingUnit.gram);
      expect(saved.valueType, NutrientValueType.estimate);
      await disposeTree(tester);
    });

    testWidgets('a plate can be logged item by item', (tester) async {
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, const [])
        ..photoAnswer =
            '{"items":[{"name":"白飯","amount":"約 180 g","kcal":250},'
            '{"name":"滷雞腿","amount":"約 120 g","kcal":300}],'
            '"notes":["滷汁的油量看不出來"]}';
      final store = storeWith(apple);
      await pumpScreen(tester, screen(logsOnce: true), store: store);
      final before = store.todayMeals.length;

      await scanFood(tester);
      expect(find.text('照片裡有 2 項'), findsOneWidget);
      await tester.tap(find.text('逐項記錄'));
      await tester.pumpAndSettle();
      expect(find.byType(DescribeMealScreen), findsOneWidget);
      await tester.tap(find.text('記錄 2 項'));
      await tester.pumpAndSettle();

      expect(store.todayMeals, hasLength(before + 2));
      expect(
        store.backend.nutrition.searchFoods('白飯'),
        isEmpty,
        reason: 'a plate is a meal, not a food',
      );
      await disposeTree(tester);
    });

    testWidgets('a cloud provider asks before the first photo', (tester) async {
      final cloud = _FakeDrafter(AiProviderKind.ollamaCloud, const []);
      final store = storeWith(cloud)..setCloudConsent(true);
      await pumpScreen(tester, screen(logsOnce: true), store: store);

      await scanFood(tester);
      expect(find.text('送出食物照片到 Ollama Cloud？'), findsOneWidget);
      expect(cloud.photos, isEmpty, reason: 'nothing leaves before a yes');
      await tester.tap(find.text('同意並送出'));
      await tester.pumpAndSettle();

      expect(cloud.photos, hasLength(1));
      expect(store.hasPhotoConsent, isTrue);
      await disposeTree(tester);
    });
  });

  group('Ollama Cloud', () {
    OllamaDrafter drafter(http.Client client, {String? key = 'k-123'}) =>
        OllamaDrafter(
          client: client,
          readKey: () async => key,
          readModel: () => 'gemma4:31b',
        );

    test(
      'asks for one answer with the key, the model and the sentence',
      () async {
        late http.Request sent;
        final client = MockClient((request) async {
          sent = request;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'message': {
                  'role': 'assistant',
                  'content': '{"items":[{"name":"蛋餅","kcal":250}]}',
                },
              }),
            ),
            200,
          );
        });

        final draft = await drafter(client).draftMeal('早餐 蛋餅');

        expect(sent.url, OllamaDrafter.endpoint);
        expect(sent.headers['Authorization'], 'Bearer k-123');
        final body = jsonDecode(sent.body) as Map<String, dynamic>;
        expect(body['model'], 'gemma4:31b');
        expect(body['stream'], false, reason: 'one answer, not a stream');
        expect((body['messages'] as List).last['content'], '早餐 蛋餅');
        expect(draft.items.single.name, '蛋餅');
        expect(draft.model, 'gemma4:31b');
      },
    );

    test('its errors become the app\'s own', () async {
      for (final (status, failure) in [
        (401, AiFailure.authentication),
        (429, AiFailure.rateLimited),
        (500, AiFailure.providerError),
      ]) {
        final client = MockClient((_) async => http.Response('no', status));
        await expectLater(
          drafter(client).draftMeal('x'),
          throwsA(
            isA<AiException>().having((e) => e.failure, 'failure', failure),
          ),
          reason: '$status',
        );
      }
    });

    test('lists the models the key can reach, in order', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          '{"object":"list","data":[{"id":"qwen3:8b"},{"id":"gemma4:31b"},'
          '{"id":""}]}',
          200,
        );
      });

      final models = await drafter(client).models();

      expect(sent.url, OllamaDrafter.modelsEndpoint);
      expect(sent.headers['Authorization'], 'Bearer k-123');
      expect(models, ['gemma4:31b', 'qwen3:8b'], reason: 'sorted, no blanks');
    });

    test('an invalid key while listing models says so', () async {
      final client = MockClient((_) async => http.Response('no', 401));
      await expectLater(
        drafter(client).models(),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.authentication,
          ),
        ),
      );
    });

    test('without a key it is not available and sends nothing', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 200);
      });
      final noKey = drafter(client, key: null);
      expect(await noKey.availability(), AiAvailability.needsKey);
      await expectLater(noKey.draftMeal('x'), throwsA(isA<AiException>()));
      expect(calls, 0);
    });
  });

  group('Google AI Studio', () {
    test('asks Gemini in its own shape, key in a header', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"items":[{"name":"蛋餅","kcal":250}]}'},
                    ],
                  },
                },
              ],
            }),
          ),
          200,
        );
      });
      final gemini = GoogleAiStudioDrafter(
        client: client,
        readKey: () async => 'g-key',
        readModel: () => 'gemini-3.8-flash',
      );

      final draft = await gemini.draftMeal('早餐 蛋餅');

      expect(
        sent.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-3.8-flash:generateContent',
      );
      expect(sent.headers['x-goog-api-key'], 'g-key');
      expect(
        sent.url.query,
        isEmpty,
        reason: 'a key in the URL ends up in logs',
      );
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['systemInstruction'], isNotNull);
      expect(draft.items.single.name, '蛋餅');
    });

    test('lists only the models that can answer', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.8-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/text-embedding-004',
                'supportedGenerationMethods': ['embedContent'],
              },
            ],
          }),
          200,
        ),
      );
      final models = await GoogleAiStudioDrafter(
        client: client,
        readKey: () async => 'g-key',
        readModel: () => 'gemini-3.8-flash',
      ).models();

      expect(models, ['gemini-3.8-flash'], reason: 'no embedding models');
    });
  });

  group('Anthropic', () {
    test('asks the Messages API with its version header', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'content': [
                {'type': 'text', 'text': '{"items":[{"name":"蛋餅"}]}'},
              ],
            }),
          ),
          200,
        );
      });
      final anthropic = AnthropicDrafter(
        client: client,
        readKey: () async => 'a-key',
        readModel: () => 'claude-opus-4-5',
      );

      final draft = await anthropic.draftMeal('早餐 蛋餅');

      expect(sent.url, AnthropicDrafter.endpoint);
      expect(sent.headers['x-api-key'], 'a-key');
      expect(sent.headers['anthropic-version'], AnthropicDrafter.version);
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-4-5');
      expect(body['system'], isNotEmpty);
      expect(draft.items.single.name, '蛋餅');
    });
  });

  group('Microsoft 365 Copilot', () {
    CopilotDrafter copilot(
      http.Client client, {
      String? refresh = 'r-token',
      void Function(String)? onSave,
    }) => CopilotDrafter(
      client: client,
      readKey: () async => refresh,
      readModel: () => '',
      readClientId: () => 'client-1',
      readTenant: () => '',
      saveRefreshToken: (token) async => onSave?.call(token),
    );

    test('signs in with a device code and keeps the refresh token', () async {
      final saved = <String>[];
      final asked = <Uri>[];
      var polls = 0;
      final client = MockClient((request) async {
        asked.add(request.url);
        if (request.url.path.endsWith('/devicecode')) {
          return http.Response(
            jsonEncode({
              'device_code': 'd-code',
              'user_code': 'ABCD-EFGH',
              'verification_uri': 'https://microsoft.com/devicelogin',
              'interval': 1,
              'expires_in': 900,
            }),
            200,
          );
        }
        // Microsoft answers "not yet" until the user finishes.
        polls++;
        return http.Response(
          polls == 1
              ? jsonEncode({'error': 'authorization_pending'})
              : jsonEncode({
                  'access_token': 'a-token',
                  'refresh_token': 'r-new',
                  'expires_in': 3600,
                }),
          polls == 1 ? 400 : 200,
        );
      });
      final drafter = copilot(client, onSave: saved.add);

      final prompt = await drafter.startSignIn();
      expect(prompt.userCode, 'ABCD-EFGH');
      expect(prompt.verificationUri, 'https://microsoft.com/devicelogin');
      expect(
        asked.first.toString(),
        'https://login.microsoftonline.com/organizations/oauth2/v2.0/devicecode',
      );

      // No real waiting in a test; the polling is what is under test.
      await drafter.finishSignIn(prompt, wait: (_) async {});

      expect(polls, 2, reason: 'it waited for the user, then took the token');
      expect(saved, ['r-new']);
      expect(await drafter.availability(), AiAvailability.available);
    });

    test('opens a conversation, asks, and reads the last message', () async {
      final asked = <Uri>[];
      final client = MockClient((request) async {
        asked.add(request.url);
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({'access_token': 'a-token', 'expires_in': 3600}),
            200,
          );
        }
        if (request.url.path.endsWith('/conversations')) {
          return http.Response(jsonEncode({'id': 'c-1'}), 201);
        }
        expect(request.headers['Authorization'], 'Bearer a-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(
          (body['message'] as Map)['text'],
          contains('早餐 蛋餅'),
          reason: 'Copilot takes no system message, so it leads the text',
        );
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'id': 'c-1',
              'messages': [
                {'text': '早餐 蛋餅'},
                {'text': '{"items":[{"name":"蛋餅","kcal":250}]}'},
              ],
            }),
          ),
          200,
        );
      });

      final draft = await copilot(client).draftMeal('早餐 蛋餅');

      expect(draft.items.single.name, '蛋餅');
      expect(draft.model, 'Microsoft 365 Copilot');
      expect(
        asked.map((url) => url.path),
        containsAllInOrder([
          '/organizations/oauth2/v2.0/token',
          '/beta/copilot/conversations',
          '/beta/copilot/conversations/c-1/chat',
        ]),
      );
    });

    test('without a sign-in it asks for one and sends nothing', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 200);
      });
      final drafter = copilot(client, refresh: null);

      expect(await drafter.availability(), AiAvailability.needsKey);
      await expectLater(drafter.draftMeal('蛋餅'), throwsA(isA<AiException>()));
      expect(calls, 0);
    });
  });

  group('Azure AI Foundry', () {
    test('posts to the resource with the API version', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '{"items":[{"name":"蛋餅"}]}'},
                },
              ],
            }),
          ),
          200,
        );
      });
      final foundry = AzureAiFoundryDrafter(
        client: client,
        readKey: () async => 'az-key',
        readModel: () => 'my-deployment',
        readEndpoint: () => 'https://mine.services.ai.azure.com/models/',
      );

      final draft = await foundry.draftMeal('早餐 蛋餅');

      expect(
        sent.url.toString(),
        'https://mine.services.ai.azure.com/models/chat/completions'
        '?api-version=${AzureAiFoundryDrafter.apiVersion}',
      );
      expect(sent.headers['Authorization'], 'Bearer az-key');
      expect(jsonDecode(sent.body), containsPair('model', 'my-deployment'));
      expect(draft.items.single.name, '蛋餅');
      expect(
        await foundry.models(),
        isEmpty,
        reason: 'Foundry has no listing; the deployment name is typed',
      );
    });
  });

  group('an OpenAI-compatible endpoint', () {
    OpenAiCompatibleDrafter drafterAt(String endpoint, http.Client client) =>
        OpenAiCompatibleDrafter(
          client: client,
          readKey: () async => 'k',
          readModel: () => 'some-model',
          readEndpoint: () => endpoint,
        );

    test('posts to the address the user gave', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '{"items":[{"name":"蛋餅"}]}'},
                },
              ],
            }),
          ),
          200,
        );
      });

      // A trailing slash is the user's, not a second path segment.
      await drafterAt('https://example.invalid/v1/', client).draftMeal('蛋餅');

      expect(
        sent.url.toString(),
        'https://example.invalid/v1/chat/completions',
      );
      expect(sent.headers['Authorization'], 'Bearer k');
    });

    test('without an address it is not ready and sends nothing', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 200);
      });
      final drafter = drafterAt('  ', client);

      expect(await drafter.availability(), AiAvailability.needsKey);
      await expectLater(drafter.draftMeal('蛋餅'), throwsA(isA<AiException>()));
      expect(calls, 0);
    });
  });

  group('the AI layer', () {
    test('sends nothing until a provider is chosen', () async {
      final backend = Backend.inMemory();
      addTearDown(backend.close);
      final cloud = _FakeDrafter(AiProviderKind.ollamaCloud, [_eggPancake]);
      final ai = AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {AiProviderKind.ollamaCloud: cloud},
      );

      await expectLater(ai.draftMeal('蛋餅'), throwsA(isA<AiException>()));
      expect(cloud.asked, isEmpty);
    });

    test('asks before the first sentence leaves the phone', () async {
      final backend = Backend.inMemory();
      addTearDown(backend.close);
      final cloud = _FakeDrafter(AiProviderKind.ollamaCloud, [_eggPancake]);
      final ai = AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {AiProviderKind.ollamaCloud: cloud},
      )..setProvider(AiProviderKind.ollamaCloud);

      await expectLater(
        ai.draftMeal('蛋餅'),
        throwsA(
          isA<AiException>().having(
            (e) => e.failure,
            'failure',
            AiFailure.needsConsent,
          ),
        ),
      );
      expect(cloud.asked, isEmpty);

      ai.setCloudConsent(true);
      expect((await ai.draftMeal('蛋餅')).items, [_eggPancake]);
      expect(cloud.asked, ['蛋餅']);
    });

    test('the on-device model needs no consent', () async {
      final backend = Backend.inMemory();
      addTearDown(backend.close);
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, [_eggPancake]);
      final ai = AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {AiProviderKind.appleOnDevice: apple},
      )..setProvider(AiProviderKind.appleOnDevice);

      expect((await ai.draftMeal('蛋餅')).items, hasLength(1));
    });

    test('the key lives in the secret store, never the database', () async {
      final backend = Backend.inMemory();
      addTearDown(backend.close);
      final secrets = MemorySecretStore();
      final ai = AiService(backend.db, secrets: secrets, drafters: const {});

      await ai.setKey(AiProviderKind.ollamaCloud, '  k-123  ');
      expect(
        await secrets.read(AiService.keyName(AiProviderKind.ollamaCloud)),
        'k-123',
      );
      expect(
        backend.db.select('SELECT value FROM settings').map((r) => r['value']),
        isNot(contains('k-123')),
      );
      await ai.setKey(AiProviderKind.ollamaCloud, '');
      expect(
        await ai.hasKey(AiProviderKind.ollamaCloud),
        isFalse,
        reason: 'empty forgets it',
      );
    });

    test(
      'a confirmed draft is logged as an estimate, with where it came from',
      () {
        final store = AppStore(clock: FakeClock().now, isOnboarded: true);
        final before = store.todayMeals.length;
        const draft = MealDraft(
          items: [_eggPancake, _milkTea],
          provider: AiProviderKind.ollamaCloud,
          model: 'gemma4:31b',
        );

        final logged = store.backend.nutrition.logDraft(draft, [
          _milkTea,
        ], mealType: MealType.breakfast);

        expect(
          store.todayMeals,
          hasLength(before + 1),
          reason: 'only what was kept',
        );
        final tea = logged.single;
        expect(tea.name, '冰奶茶（大杯）');
        expect(tea.isEstimated, isTrue);
        expect(tea.valueType, NutrientValueType.estimate);
        expect(tea.qualityTag, aiDraftQualityTag);
        expect(tea.kind, ConsumptionKind.beverage);
        expect(tea.mealType, MealType.breakfast);
        final audit = store.backend.db.select(
          'SELECT source, payload FROM audit_events WHERE entity_id = ?',
          [tea.id],
        ).single;
        expect(audit['source'], 'aiDraft');
        expect(jsonDecode(audit['payload']! as String), {
          'provider': 'ollamaCloud',
          'model': 'gemma4:31b',
        });
      },
    );

    test('a draft of several items can be one meal of those items', () {
      final store = AppStore(clock: FakeClock().now, isOnboarded: true);
      final before = store.todayMeals.length;
      const rice = DraftItem(
        name: '白飯',
        amount: '一碗',
        kcal: 280,
        proteinGrams: 5,
        carbGrams: 62,
        fatGrams: 1,
      );
      const soup = DraftItem(
        name: '味噌湯',
        amount: '一碗',
        kcal: 40,
        proteinGrams: 3,
        carbGrams: 4,
      );
      const draft = MealDraft(
        items: [rice, soup],
        provider: AiProviderKind.ollamaCloud,
        model: 'gemma4:31b',
      );

      final items = store.backend.nutrition.logDraft(draft, [
        rice,
        soup,
      ], asOneMeal: true);

      expect(store.todayMeals, hasLength(before + 2));
      expect(items.map((item) => item.name), ['白飯（一碗）', '味噌湯（一碗）']);
      expect(
        items.map((item) => item.groupId).toSet(),
        hasLength(1),
        reason: 'one meal, each item its own record',
      );
      expect(items.first.groupId, isNotNull);
      expect(mealKcalOf(items), 320);
      expect(items.every((item) => item.isEstimated), isTrue);
    });
  });

  testWidgets('a sentence becomes a draft, and only the kept part is logged', (
    tester,
  ) async {
    final backend = Backend.inMemory(clock: FakeClock().now);
    final cloud = _FakeDrafter(AiProviderKind.ollamaCloud, [
      _eggPancake,
      _milkTea,
    ]);
    final store = AppStore(
      clock: FakeClock().now,
      isOnboarded: true,
      backend: backend,
      ai: AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {AiProviderKind.ollamaCloud: cloud},
      )..setProvider(AiProviderKind.ollamaCloud),
    );
    final before = store.todayMeals.length;
    await pumpScreen(tester, const DescribeMealScreen(), store: store);

    await tester.enterText(find.byType(TextField), '早餐 蛋餅加大杯冰奶茶');
    await tester.pump();
    await tester.tap(find.text('產生草稿'));
    await tester.pumpAndSettle();
    expect(find.text('送到 Ollama Cloud？'), findsOneWidget);
    await tester.tap(find.text('同意並送出'));
    await tester.pumpAndSettle();

    expect(cloud.asked, ['早餐 蛋餅加大杯冰奶茶']);
    expect(store.todayMeals, hasLength(before), reason: 'a draft logs nothing');
    expect(find.text('蛋餅'), findsOneWidget);
    expect(
      find.widgetWithText(DraftAttribution, 'Ollama Cloud / fake-1'),
      findsOneWidget,
    );
    expect(
      find.text('蛋白質 — · 碳水化合物 — · 脂肪 —'),
      findsNWidgets(2),
      reason: 'figures the model did not give read as dashes, not 0',
    );

    // Every figure is corrected in one place, not just the energy.
    await tester.tap(find.text('蛋餅'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(NumberFieldRow, '蛋白質'),
        matching: find.byType(TextField),
      ),
      '9',
    );
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(find.text('蛋白質 9 g · 碳水化合物 — · 脂肪 —'), findsOneWidget);

    await tester.drag(find.text('冰奶茶'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('記錄 1 項'));
    await tester.pumpAndSettle();

    expect(store.todayMeals, hasLength(before + 1));
    expect(store.todayMeals.last.name, '蛋餅（一份）');
    expect(store.todayMeals.last.proteinGrams, 9);
    await disposeTree(tester);
  });

  test('a draft names its provider, and the model when there is a choice', () {
    expect(
      aiLabel(AiProviderKind.ollamaCloud, 'gemma4:31b'),
      'Ollama Cloud / gemma4:31b',
    );
    expect(
      aiLabel(AiProviderKind.appleOnDevice, 'on-device'),
      'Apple Intelligence',
    );
    expect(
      aiLabel(AiProviderKind.microsoftCopilot, 'Microsoft 365 Copilot'),
      'Microsoft 365 Copilot',
    );
    expect(aiLabel(AiProviderKind.anthropic, ''), 'Anthropic');
  });

  group('a workout the rules cannot read', () {
    test(
      'a model\'s answer reads into lines, figures out of range left out',
      () {
        final lines = parseWorkoutDraft(
          '```json\n{"exercises":['
          '{"name":"深蹲","name_en":"Back Squat","line":"深蹲五組五下",'
          '"sets":5,"reps":5,"weight_kg":100},'
          '{"name":"棒式","name_en":"Plank","sets":2,"reps":null,'
          '"weight_kg":0},'
          '{"name":"臥推","sets":300,"reps":8,"weight_kg":9000},'
          '{"name":"  "}]}\n```',
        );

        expect([for (final line in lines) line.name], ['深蹲', '棒式', '臥推']);
        expect(lines[0].otherName, 'Back Squat');
        expect(lines[0].text, '深蹲五組五下');
        expect(
          (lines[0].sets, lines[0].reps, lines[0].weightKg),
          (5, 5, 100.0),
        );
        expect(lines[1].text, '棒式', reason: 'no line given: its name');
        expect((lines[1].reps, lines[1].weightKg), (null, null));
        expect((lines[2].sets, lines[2].weightKg), (null, null));
        expect(
          () => parseWorkoutDraft('這是一份很棒的課表！'),
          throwsA(
            isA<AiException>().having(
              (error) => error.failure,
              'failure',
              AiFailure.unreadable,
            ),
          ),
        );
      },
    );

    Future<(AppStore, _FakeDrafter)> open(WidgetTester tester) async {
      usePhoneViewport(tester);
      final backend = Backend.inMemory(clock: FakeClock().now);
      final apple = _FakeDrafter(AiProviderKind.appleOnDevice, const []);
      final store = AppStore(
        clock: FakeClock().now,
        isOnboarded: true,
        backend: backend,
        ai: AiService(
          backend.db,
          secrets: MemorySecretStore(),
          drafters: {apple.kind: apple},
        )..setProvider(AiProviderKind.appleOnDevice),
      );
      await pumpScreen(tester, const DescribeWorkoutScreen(), store: store);
      return (store, apple);
    }

    Future<void> read(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.text('產生草稿'));
      await tester.pumpAndSettle();
    }

    testWidgets('goes to the chosen AI', (tester) async {
      final (_, apple) = await open(tester);
      apple.workoutAnswer =
          '{"exercises":[{"name":"深蹲","name_en":"Back Squat",'
          '"line":"先深蹲五組五下一百公斤","sets":5,"reps":5,"weight_kg":100}]}';

      await read(tester, '先深蹲五組五下一百公斤，再看狀況');

      expect(apple.workouts, ['先深蹲五組五下一百公斤，再看狀況']);
      expect(find.text('槓鈴深蹲'), findsOneWidget);
      expect(find.text('5 組 × 5 下 · 100 kg'), findsOneWidget);
      expect(
        find.widgetWithText(DraftAttribution, 'Apple Intelligence'),
        findsOneWidget,
      );
      await disposeTree(tester);
    });

    testWidgets('what the rules read whole is not sent', (tester) async {
      final (_, apple) = await open(tester);

      await read(tester, '槓鈴深蹲 4×8 60kg');

      expect(apple.workouts, isEmpty);
      expect(find.text('4 組 × 8 下 · 60 kg'), findsOneWidget);
      expect(find.byType(DraftAttribution), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('when the AI fails, the rules\' reading stays', (tester) async {
      final (_, apple) = await open(tester);
      apple.workoutFailure = AiFailure.rateLimited;

      await read(tester, '槓鈴深蹲 4×8 60kg\n不存在的動作名稱 3x5');

      expect(apple.workouts, hasLength(1));
      expect(find.text('4 組 × 8 下 · 60 kg'), findsOneWidget);
      expect(find.text('找不到這個動作'), findsOneWidget);
      expect(
        find.text(aiFailureMessage(AiFailure.rateLimited)),
        findsOneWidget,
      );
      await disposeTree(tester);
    });
  });
}
