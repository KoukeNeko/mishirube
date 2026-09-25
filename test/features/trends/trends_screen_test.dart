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

  /// Longer nights over the last four weeks than the four before, so
  /// the page has a second change beside the demo's strength one.
  void sleepLonger(AppStore store) {
    final today = store.now();
    for (var day = 1; day <= 2 * 28; day++) {
      store.backend.journal.recordSleep(
        Duration(hours: day <= 28 ? 8 : 6),
        at: DateTime(today.year, today.month, today.day - day + 1, 7),
      );
    }
  }

  testWidgets('Apple Intelligence words the facts the page already shows', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final model = _OnDevice((facts) => '近 4 週訓練每週 2.3 次，趨勢體重 72.6 kg。');
    final store = await storeWith(model);
    sleepLonger(store);
    await pumpScreen(tester, const TrendsScreen(), store: store);
    await tester.pump();

    expect(model.given.single, contains('變化：近 4 週平均睡眠'));
    expect(model.given.single, contains('現況：訓練每週 2.3 次'));
    expect(find.text('近 4 週訓練每週 2.3 次，趨勢體重 72.6 kg。'), findsOneWidget);
    expect(find.textContaining('Apple Intelligence 整理'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('an answer with a figure of its own is not shown', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = await storeWith(_OnDevice((_) => '體重會在 3 週內降到 70 kg。'));
    sleepLonger(store);
    await pumpScreen(tester, const TrendsScreen(), store: store);
    await tester.pump();

    expect(find.textContaining('Apple Intelligence 整理'), findsNothing);
    expect(find.text('值得注意'), findsOneWidget, reason: 'the page stands');
    await disposeTree(tester);
  });

  testWidgets('a single change is not summarized over its own card', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final model = _OnDevice((_) => '近 4 週訓練每週 2.3 次。');
    final store = await storeWith(model);
    await pumpScreen(tester, const TrendsScreen(), store: store);
    await tester.pump();

    expect(model.given, isEmpty);
    expect(find.textContaining('Apple Intelligence 整理'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('every area logged has a long-run row, even without records', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = await storeWith(_OnDevice((_) => ''));
    await pumpScreen(tester, const TrendsScreen(), store: store);

    for (final area in ['身體', '訓練', '睡眠', '飲食', '活動']) {
      expect(find.text(area), findsWidgets, reason: area);
    }
    await disposeTree(tester);
  });
}
