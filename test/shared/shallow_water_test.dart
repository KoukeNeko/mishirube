import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/shared/widgets/widgets.dart';

void main() {
  const down = 3528.0; // 9.8 m/s² at the tile's scale.

  ShallowWater glass() =>
      ShallowWater(width: 160, height: 110, level: 0.5, seed: 1);

  test('still water stays flat and still', () {
    final water = glass();
    water.step(1, down: down, right: 0);

    expect(water.speed, 0);
    expect(water.depth.every((d) => (d - 55).abs() < 1e-9), isTrue);
  });

  test('water is moved about, never made or lost', () {
    final water = glass();
    final before = water.volume;
    // Shaken side to side, hard, for two seconds.
    for (var i = 0; i < 120; i++) {
      water.step(1 / 60, down: down, right: i.isEven ? 3000 : -3000);
    }

    expect(water.volume, closeTo(before, before * 1e-9));
    expect(water.depth.every((d) => d >= 0), isTrue);
  });

  test('tilted, it comes to rest level with the ground', () {
    final water = glass();
    const lean = 0.3;
    for (var i = 0; i < 600; i++) {
      water.step(1 / 60, down: down, right: down * lean);
    }

    final slope =
        (water.depth.last - water.depth.first) /
        ((water.columns - 1) * water.columnWidth);
    expect(slope, closeTo(lean, 0.02), reason: 'deeper on the low side');
    expect(water.speed, lessThan(0.5), reason: 'and still');
  });

  test('tilted past the height, the high side runs dry, not negative', () {
    final water = ShallowWater(width: 160, height: 110, level: 0.1);
    final before = water.volume;
    for (var i = 0; i < 600; i++) {
      water.step(1 / 60, down: down, right: down * 0.6);
    }

    expect(water.depth.first, closeTo(0, 1e-6), reason: 'dry');
    expect(water.depth.every((d) => d >= 0), isTrue);
    expect(water.volume, closeTo(before, before * 1e-9));
  });

  test('a glass poured in adds exactly its water, then settles', () {
    final water = glass();
    water.pourTo(0.8);
    expect(water.isPouring, isTrue);
    for (var i = 0; i < 300; i++) {
      water.step(1 / 60, down: down, right: 0);
    }

    expect(water.isPouring, isFalse);
    expect(water.volume, closeTo(0.8 * 110 * 160, 1e-6));
    final spread = water.depth.reduce(math.max) - water.depth.reduce(math.min);
    expect(spread, lessThan(0.5), reason: 'the ripples have died away');
  });

  test('narrow and deep, a frame at a time, it still settles', () {
    // A Today tile beside two others: columns under 3 px, water 150 deep,
    // advanced by a whole 30 fps frame at once.
    final water = ShallowWater(width: 110, height: 180, level: 0.66);
    water.pourTo(0.83);
    for (var i = 0; i < 300; i++) {
      water.step(1 / 30, down: down, right: 0);
    }

    expect(water.speed, lessThan(0.5), reason: 'not blown up');
    expect(water.volume, closeTo(0.83 * 110 * 180, 1e-6));
  });

  test('a hard shake throws drops, and every one falls back in', () {
    final water = glass();
    final before = water.volume;
    var thrown = 0;
    for (var i = 0; i < 30; i++) {
      water.step(1 / 60, down: down, right: i < 15 ? 6000 : -6000);
      thrown = math.max(thrown, water.drops.length);
    }
    expect(thrown, greaterThan(0), reason: 'a splash');
    expect(water.volume, closeTo(before, before * 1e-9), reason: 'in the air');

    for (var i = 0; i < 600; i++) {
      water.step(1 / 60, down: down, right: 0);
    }
    expect(water.drops, isEmpty, reason: 'all landed');
    expect(water.isStill(), isTrue);
    expect(water.volume, closeTo(before, before * 1e-9));
  });
}
