import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/nutrition/nutrition_view_model.dart';

import '../../support/harness.dart';

void main() {
  late Backend backend;
  late NutritionViewModel nutrition;

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now);
    nutrition = NutritionViewModel(backend);
  });

  tearDown(() {
    nutrition.dispose();
    backend.close();
  });

  test('a glass logs the size the user picked, and can be taken back', () {
    var notified = 0;
    nutrition.addListener(() => notified++);
    final before = nutrition.todayWater.millilitres;
    expect(
      nutrition.glassMillilitres,
      NutritionViewModel.defaultGlassMillilitres,
    );

    nutrition.setGlassMillilitres(500);
    final logged = nutrition.logWater();
    expect(logged.millilitres, 500);
    expect(nutrition.todayWater.millilitres, before + 500);

    nutrition.deleteMeals([logged]);
    expect(nutrition.todayWater.millilitres, before);
    expect(notified, 3, reason: 'one per write, the glass size included');
  });
}
