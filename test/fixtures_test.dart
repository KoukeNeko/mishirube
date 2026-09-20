import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/food_portion.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/harness.dart';

/// Fixtures for the shapes a record can take.
///
/// These are not about any one screen. They pin that a set of each
/// tracking type and each set type survives being written and read back,
/// so a storage change that quietly drops RIR or a distance shows up
/// here rather than in somebody's history a month later.
void main() {
  final clock = FakeClock();

  Backend open() => Backend.inMemory(clock: clock.now);

  ExerciseDefinition exercise(String id, TrackingType tracking) =>
      ExerciseDefinition(
        id: id,
        name: id,
        equipment: Equipment.barbell,
        primaryMuscles: const [MuscleGroup.quads],
        pattern: MovementPattern.squat,
        trackingType: tracking,
        source: ExerciseSource.custom,
      );

  group('workout set fixtures', () {
    test('every tracking type and set type survives a round trip', () {
      final backend = open();
      addTearDown(backend.close);

      // One exercise per tracking type, each with one set of every type.
      final sessions = [
        for (final tracking in TrackingType.values)
          ExerciseSession(
            exercise: exercise(tracking.name, tracking),
            sets: [
              for (final (index, type) in SetType.values.indexed)
                WorkoutSet(
                  weightKg: 60 + index.toDouble(),
                  reps: 8 - index,
                  previousWeightKg: 55,
                  previousReps: 8,
                  rir: index,
                  rpe: 7 + index * 0.5,
                  type: type,
                  durationSeconds: tracking == TrackingType.duration
                      ? 60 + index
                      : null,
                  distanceMeters: tracking == TrackingType.distance
                      ? 1000 + index.toDouble()
                      : null,
                  isDone: true,
                ),
            ],
          ),
      ];
      for (final session in sessions) {
        backend.storage.exercises.save(session.exercise);
      }
      final workout = WorkoutSession(
        id: 'fixture',
        routineName: '各種組型',
        startedAt: clock.now(),
        exercises: sessions,
      );
      backend.storage.workouts.save(workout, action: 'create');

      final read = backend.storage.workouts.byId(
        'fixture',
        (id) => backend.storage.exercises.byId(id)!,
      )!;
      expect(read.exercises, hasLength(TrackingType.values.length));
      for (final (index, session) in read.exercises.indexed) {
        final tracking = TrackingType.values[index];
        expect(session.exercise.trackingType, tracking);
        expect(session.sets.map((set) => set.type), SetType.values);
        for (final (setIndex, set) in session.sets.indexed) {
          expect(set.rir, setIndex, reason: 'RIR is part of the record');
          expect(set.rpe, 7 + setIndex * 0.5);
          expect(set.isDone, isTrue);
          expect(
            set.durationSeconds,
            tracking == TrackingType.duration ? 60 + setIndex : null,
            reason: 'a timed set keeps its seconds and nothing else gains any',
          );
          expect(
            set.distanceMeters,
            tracking == TrackingType.distance ? 1000 + setIndex : null,
          );
        }
      }
    });

    test('a set with no RIR or RPE keeps none', () {
      final backend = open();
      addTearDown(backend.close);
      final definition = exercise('plain', TrackingType.weightReps);
      backend.storage.exercises.save(definition);
      backend.storage.workouts.save(
        WorkoutSession(
          id: 'plain-workout',
          routineName: '沒填',
          startedAt: clock.now(),
          exercises: [
            ExerciseSession(
              exercise: definition,
              sets: [
                WorkoutSet(
                  weightKg: 60,
                  reps: 5,
                  previousWeightKg: 60,
                  previousReps: 5,
                ),
              ],
            ),
          ],
        ),
        action: 'create',
      );

      final set = backend.storage.workouts
          .byId('plain-workout', (id) => backend.storage.exercises.byId(id)!)!
          .exercises
          .single
          .sets
          .single;
      expect(set.rir, isNull);
      expect(set.rpe, isNull);
      expect(
        set.type,
        SetType.working,
        reason: 'a set nobody labelled is a working set, not an unknown one',
      );
    });
  });

  group('meal fixtures', () {
    test('a dish keeps its components, and exploding it keeps the meal', () {
      final backend = open();
      addTearDown(backend.close);
      const meal = MealEvent(
        id: 'fixture-meal',
        name: '午餐',
        timeLabel: '12:30',
        qualityTag: '自訂食物',
        kcal: 700,
        proteinGrams: 30,
        carbGrams: 80,
        fatGrams: 25,
        dishes: [
          DishEntry(
            name: '牛肉麵',
            quantityLabel: '一碗',
            subtitle: '湯喝一半',
            components: [
              FoodComponent(name: '麵', amountLabel: '150 g', source: '估計'),
              FoodComponent(name: '牛肉', amountLabel: '80 g', source: '估計'),
            ],
          ),
        ],
      );
      backend.storage.meals.insert(meal, eatenAt: clock.now());

      final read = backend.nutrition.mealsOn(clock.now()).single;
      expect(read.dishes.single.components, hasLength(2));
      expect(read.dishes.single.isComposite, isTrue);

      final exploded = backend.nutrition.explodeDish(
        [read],
        mealId: 'fixture-meal',
        dishIndex: 0,
      )!;
      expect(
        exploded.$1.dishes,
        hasLength(2),
        reason: 'the components become entries of their own',
      );
      expect(
        backend.nutrition.mealsOn(clock.now()).single.kcal,
        700,
        reason: 'how a meal is written down is not what was eaten',
      );
    });

    test('a meal remembers what kind of figures it copied', () {
      final backend = open();
      addTearDown(backend.close);
      const drink = FoodItem(
        id: 'fixture-drink',
        name: '拿鐵',
        brand: 'CITY CAFE',
        kind: ConsumptionKind.beverage,
        valueType: NutrientValueType.max,
        servingAmount: 360,
        servingUnit: ServingUnit.millilitre,
        kcal: 180,
        nutrients: {Nutrient.caffeine: 180},
      );
      backend.storage.foods.save(drink, source: ChangeSource.catalogue);
      final logged = backend.nutrition.logPortion(
        const FoodPortion(drink, 1),
        mealType: MealType.breakfast,
      );

      final read = backend.nutrition.mealsOn(clock.now()).single;
      expect(read.id, logged.id);
      expect(read.valueType, NutrientValueType.max);
      expect(read.mealType, MealType.breakfast);
      expect(read.kind, ConsumptionKind.beverage);
      expect(read.millilitres, 360);
      expect(read.nutrients[Nutrient.caffeine], 180);
    });
  });
}
