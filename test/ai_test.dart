import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/ai/food_label_json.dart';
import 'package:mishirube/backend/ai/label_reader.dart';
import 'package:mishirube/backend/ai/meal_draft_json.dart';
import 'package:mishirube/backend/ai/meal_drafter.dart';
import 'package:mishirube/backend/ai/ollama_meal_drafter.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/backend/application/ai_service.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/label_text.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/nutrition/describe_meal_screen.dart';
import 'package:mishirube/features/nutrition/food_edit_screen.dart';

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

  @override
  Future<AiAvailability> availability() async => AiAvailability.available;

  @override
  Future<MealDraft> draftMeal(String description) async {
    asked.add(description);
    return MealDraft(items: items, provider: kind, model: 'fake-1');
  }

  /// The label text it was given; answers with a model's JSON for it.
  final labels = <String>[];
  String labelAnswer =
      '{"name":"燕麥奶","serving_amount":200,"serving_unit":"ml",'
      '"kcal":120,"protein_g":2,"fat_g":5,"saturated_fat_g":0.5,'
      '"carb_g":16,"sugar_g":7,"sodium_mg":95}';

  @override
  Future<FoodLabelDraft> draftFoodLabel(String labelText) async {
    labels.add(labelText);
    return parseFoodLabel(labelAnswer, provider: kind, model: 'fake-1');
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
      expect(offEnergy.warnings.single, contains('蛋白質、碳水、脂肪'));
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
    final picked = <ImageSource>[];
    await pumpScreen(
      tester,
      FoodEditScreen(
        pickPhoto: (source) async {
          picked.add(source);
          return '/label.jpg';
        },
      ),
      store: store,
    );
    final foods = store.searchFoods('').length;

    await tester.tap(find.bySemanticsLabel('掃描營養標示'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('從相簿選取'));
    await tester.pumpAndSettle();

    expect(picked, [ImageSource.gallery]);
    expect(find.textContaining('請對照包裝逐一核對'), findsOneWidget);
    expect(find.text('燕麥奶'), findsOneWidget, reason: 'the name, filled');
    await tester.dragUntilVisible(
      find.text('120'),
      find.byType(CustomScrollView).first,
      const Offset(0, -200),
    );
    expect(find.text('120'), findsOneWidget, reason: 'the calories, filled');
    expect(
      store.searchFoods('').length,
      foods,
      reason: 'nothing is saved until the user saves it',
    );
    await disposeTree(tester);
  });

  group('Ollama Cloud', () {
    OllamaMealDrafter drafter(http.Client client, {String? key = 'k-123'}) =>
        OllamaMealDrafter(
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

        expect(sent.url, OllamaMealDrafter.endpoint);
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

      await ai.setOllamaKey('  k-123  ');
      expect(await secrets.read(AiService.ollamaKeyName), 'k-123');
      expect(
        backend.db.select('SELECT value FROM settings').map((r) => r['value']),
        isNot(contains('k-123')),
      );
      await ai.setOllamaKey('');
      expect(await ai.hasOllamaKey(), isFalse, reason: 'empty forgets it');
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

        final logged = store.logDraft(draft, [
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

    await tester.drag(find.text('冰奶茶'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('記錄 1 項'));
    await tester.pumpAndSettle();

    expect(store.todayMeals, hasLength(before + 1));
    expect(store.todayMeals.last.name, '蛋餅（一份）');
    await disposeTree(tester);
  });
}
