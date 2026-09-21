import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/ai/meal_draft_json.dart';
import 'package:mishirube/backend/ai/meal_drafter.dart';
import 'package:mishirube/backend/ai/ollama_meal_drafter.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/backend/application/ai_service.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/nutrition/describe_meal_screen.dart';

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
}

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
