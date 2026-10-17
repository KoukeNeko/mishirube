import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/app/app_store.dart';
import 'package:mishirube/features/nutrition/nutrition_target_screen.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

import '../../support/harness.dart';

void main() {
  testWidgets('what the choices add up to is on top, as one figure', (
    tester,
  ) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    store.backend.nutrition.setTargetSettings(
      store.backend.nutrition.targetSettings.copyWith(customKcal: () => 2150),
    );
    await pumpScreen(tester, const NutritionTargetScreen(), store: store);

    final hero = tester.widget<SegmentHero>(find.byType(SegmentHero));
    expect(hero.value, '2,150');
    expect(hero.unit, 'kcal');
    expect(
      tester.getTopLeft(find.byType(SegmentHero)).dy,
      lessThan(tester.getTopLeft(find.text('自己設定')).dy),
      reason: 'above the choices that make it',
    );
    await disposeTree(tester);
  });

  testWidgets('one way to the target is picked, and says so', (tester) async {
    usePhoneViewport(tester);
    final store = AppStore(clock: FakeClock().now, isOnboarded: true);
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester, const NutritionTargetScreen(), store: store);

    expect(
      find.semantics.byFlag(SemanticsFlag.isSelected),
      findsWidgets,
      reason: 'a way to the target, and a level of activity',
    );
    await tester.tap(find.text('依身體資料估算'));
    await tester.pumpAndSettle();
    expect(store.backend.nutrition.targetSettings.isCustom, isFalse);
    semantics.dispose();
    await disposeTree(tester);
  });
}
