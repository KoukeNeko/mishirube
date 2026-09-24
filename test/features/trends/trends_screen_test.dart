import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/backend/ai/food_photo.dart';
import 'package:mishirube/backend/ai/meal_drafter.dart';
import 'package:mishirube/backend/ai/secret_store.dart';
import 'package:mishirube/backend/ai/trend_writer.dart';
import 'package:mishirube/backend/application/ai_service.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/trends/trends_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

/// Apple's on-device model, answering trend facts with [answer] and
/// keeping what it was given.
class _OnDevice implements MealDrafter, TrendWriter {
  _OnDevice(this.answer);

  final String Function(String facts) answer;
  final given = <String>[];

  @override
  AiProviderKind get kind => AiProviderKind.appleOnDevice;
  @override
  Future<String> modelName() async => 'on-device';
  @override
  Future<AiAvailability> availability() async => AiAvailability.available;
  @override
  Future<String> summarizeTrends(String facts) async {
    given.add(facts);
    return answer(facts);
  }

  @override
  Future<MealDraft> draftMeal(String description) => throw UnimplementedError();
  @override
  Future<FoodLabelDraft> draftFoodLabel(String labelText) =>
      throw UnimplementedError();
  @override
  Future<bool> readsPhotos() async => false;
  @override
  Future<MealDraft> draftMealPhoto(FoodPhoto photo, {String note = ''}) =>
      throw UnimplementedError();
}

void main() {
  Future<AppStore> storeWith(_OnDevice model) async {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    final store = AppStore(
      clock: clock.now,
      isOnboarded: true,
      backend: backend,
      ai: AiService(
        backend.db,
        secrets: MemorySecretStore(),
        drafters: {model.kind: model},
      ),
    );
    await store.refreshOnDeviceAi();
    return store;
  }

  testWidgets('Apple Intelligence words the facts the page already shows', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final model = _OnDevice((facts) => '近 4 週訓練每週 2.3 次，趨勢體重 72.6 kg。');
    final store = await storeWith(model);
    await pumpScreen(tester, const TrendsScreen(), store: store);
    await tester.pump();

    expect(model.given.single, contains('訓練：每週 2.3 次'));
    expect(find.text('近 4 週訓練每週 2.3 次，趨勢體重 72.6 kg。'), findsOneWidget);
    expect(find.text('Apple Intelligence 整理'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('an answer with a figure of its own is not shown', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = await storeWith(_OnDevice((_) => '體重會在 3 週內降到 70 kg。'));
    await pumpScreen(tester, const TrendsScreen(), store: store);
    await tester.pump();

    expect(find.text('Apple Intelligence 整理'), findsNothing);
    expect(find.byType(InsightCard), findsWidgets, reason: 'the page stands');
    await disposeTree(tester);
  });
}
