import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/program_generator.dart';
import 'package:mishirube/backend/engines/program_slots.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/backend/seed/exercise_catalogue.dart';
import 'package:mishirube/domain/domain.dart';

/// The generator is checked against the library the app ships, not a toy
/// one: what matters is that real requests find real exercises.
void main() {
  final library = parseExerciseCatalogue(
    jsonDecode(File(exerciseCatalogueFile).readAsStringSync())
        as Map<String, dynamic>,
  );

  final gym = Equipment.values.toSet();
  const home = {Equipment.dumbbell, Equipment.bodyweight, Equipment.band};
  const bare = {Equipment.bodyweight};

  ProgramRequest request({
    ProgramGoal goal = ProgramGoal.muscle,
    ProgramLevel level = ProgramLevel.intermediate,
    int days = 4,
    int minutes = 60,
    Set<Equipment>? equipment,
    int variant = 0,
  }) => ProgramRequest(
    goal: goal,
    level: level,
    days: days,
    minutes: minutes,
    equipment: equipment ?? gym,
    variant: variant,
  );

  GeneratedProgram build(
    ProgramRequest request, {
    Iterable<ExerciseDefinition>? from,
    Map<String, ExerciseHistory> history = const {},
  }) => generateProgram(
    request,
    library: from ?? library,
    historyOf: (exercise) => history[exercise.id] ?? ExerciseHistory.empty,
    progressionLabel: 'hold',
  );

  /// An exercise done once, at [weightKg] for [reps].
  ExerciseHistory done(double weightKg, int reps) => ExerciseHistory(
    recent: [
      ExerciseHistoryEntry(
        date: DateTime(2026, 10, 1),
        weightKg: weightKg,
        reps: reps,
        oneRepMaxKg: estimateOneRepMax(weightKg, reps),
      ),
    ],
    sessionCount: 1,
    estimatedOneRepMaxKg: estimateOneRepMax(weightKg, reps),
  );

  /// [id] as an exercise the lifter has been doing: [sessions] of it, the
  /// last [daysAgo] days back.
  List<ExerciseDefinition> withUse(String id, int sessions, int daysAgo) => [
    for (final exercise in library)
      if (exercise.id == id)
        ExerciseDefinition(
          id: exercise.id,
          name: exercise.name,
          equipment: exercise.equipment,
          primaryMuscles: exercise.primaryMuscles,
          secondaryMuscles: exercise.secondaryMuscles,
          pattern: exercise.pattern,
          trackingType: exercise.trackingType,
          laterality: exercise.laterality,
          family: exercise.family,
          recordCount: sessions,
          lastUsedDaysAgo: daysAgo,
        )
      else
        exercise,
  ];

  Map<String, PlannedExercise> lifts(GeneratedProgram program) => {
    for (final workout in program.workouts)
      for (final planned in workout.exercises) planned.exercise.id: planned,
  };

  group('the week', () {
    test('has a kind of workout for each day, every muscle about twice', () {
      expect(splitFor(2), [WorkoutKind.fullBody, WorkoutKind.fullBody]);
      expect(splitFor(3), everyElement(WorkoutKind.fullBody));
      expect(splitFor(3), hasLength(3));
      expect(splitFor(4), [
        WorkoutKind.upper,
        WorkoutKind.lower,
        WorkoutKind.upper,
        WorkoutKind.lower,
      ]);
      expect(splitFor(5), [
        WorkoutKind.upper,
        WorkoutKind.lower,
        WorkoutKind.push,
        WorkoutKind.pull,
        WorkoutKind.legs,
      ]);
      expect(splitFor(6), [
        for (var i = 0; i < 2; i++) ...const [
          WorkoutKind.push,
          WorkoutKind.pull,
          WorkoutKind.legs,
        ],
      ]);
    });

    test('is never shorter than two days or longer than six', () {
      expect(splitFor(0), splitFor(programMinDays));
      expect(splitFor(9), splitFor(programMaxDays));
    });

    test('makes as many workouts as there are days', () {
      for (var days = programMinDays; days <= programMaxDays; days++) {
        expect(build(request(days: days)).workouts, hasLength(days));
      }
    });
  });

  group('the exercises', () {
    PlannedExercise squat(Iterable<ExerciseDefinition> from) =>
        build(request(days: 3), from: from).workouts.first.exercises.first;

    test('puts what the lifter has been doing before the pool', () {
      expect(squat(library).exercise.id, 'back-squat');
      expect(squat(withUse('box-squat', 5, 10)).exercise.id, 'box-squat');
    });

    test('leaves out what was done once or not for a quarter', () {
      expect(squat(withUse('box-squat', 1, 10)).exercise.id, 'back-squat');
      expect(squat(withUse('box-squat', 5, 200)).exercise.id, 'back-squat');
    });

    test('are not repeated within a workout', () {
      for (final days in [3, 4, 6]) {
        for (final workout in build(request(days: days)).workouts) {
          final ids = [for (final item in workout.exercises) item.exercise.id];
          expect(ids.toSet(), hasLength(ids.length), reason: '$days days');
        }
      }
    });

    test('differ from one workout of a kind to the next, where they can', () {
      String lead(GeneratedWorkout workout) =>
          workout.exercises.first.exercise.id;
      final program = build(request(days: 4));
      final upper = program.workouts.where((w) => w.kind == WorkoutKind.upper);
      final lower = program.workouts.where((w) => w.kind == WorkoutKind.lower);

      expect(lead(upper.first), isNot(lead(upper.last)));
      expect(lead(lower.first), isNot(lead(lower.last)));
    });

    test(
      'are taken again when a pool has nothing else the equipment allows',
      () {
        final program = build(
          request(days: 3, equipment: {Equipment.dumbbell}),
        );
        for (final workout in program.workouts) {
          expect(workout.exercises, isNotEmpty);
        }
      },
    );

    test('every pool lists exercises the library has, that can be planned', () {
      final byId = {for (final exercise in library) exercise.id: exercise};
      for (final kind in WorkoutKind.values) {
        for (var index = 0; index < 3; index++) {
          for (final slot in kind.slots(index)) {
            for (final id in [...slot.pool, ...?slot.beginnerPool]) {
              final exercise = byId[id];
              expect(exercise, isNotNull, reason: '$id in a $kind slot');
              expect(
                switch (exercise!.trackingType) {
                  TrackingType.weightReps || TrackingType.reps => true,
                  TrackingType.duration => slot.role == SlotRole.core,
                  _ => false,
                },
                isTrue,
                reason: '$id cannot be planned as ${exercise.trackingType}',
              );
            }
          }
        }
      }
    });

    test('a newcomer starts on what is easier to learn', () {
      String squat(ProgramLevel level) =>
          build(request(level: level, days: 3))
              .workouts
              .first
              .exercises
              .first
              .exercise
              .id;

      expect(squat(ProgramLevel.beginner), 'goblet-squat');
      expect(squat(ProgramLevel.intermediate), 'back-squat');
    });

    test('are the lifter\'s favourites first, and never a hidden one', () {
      final liked = library.map(
        (exercise) => exercise.id == 'incline-dumbbell-press'
            ? ExerciseDefinition(
                id: exercise.id,
                name: exercise.name,
                equipment: exercise.equipment,
                primaryMuscles: exercise.primaryMuscles,
                pattern: exercise.pattern,
                isFavorite: true,
              )
            : exercise,
      );
      expect(
        build(
          request(days: 4),
          from: liked,
        ).workouts.first.exercises.map((planned) => planned.exercise.id),
        contains('incline-dumbbell-press'),
      );

      final hidden = library.map(
        (exercise) => exercise.id == 'bench-press'
            ? ExerciseDefinition(
                id: exercise.id,
                name: exercise.name,
                equipment: exercise.equipment,
                primaryMuscles: exercise.primaryMuscles,
                pattern: exercise.pattern,
                isHidden: true,
              )
            : exercise,
      );
      final ids = [
        for (final workout in build(request(days: 6), from: hidden).workouts)
          for (final planned in workout.exercises) planned.exercise.id,
      ];
      expect(ids, isNot(contains('bench-press')));
    });

    test('are never any the equipment does not allow', () {
      for (final equipment in [home, bare, gym]) {
        for (final days in [2, 4, 6]) {
          for (final workout in build(
            request(days: days, equipment: equipment),
          ).workouts) {
            for (final planned in workout.exercises) {
              expect(
                equipment,
                contains(planned.exercise.equipment),
                reason: planned.exercise.id,
              );
            }
          }
        }
      }
    });

    test('still make a workout with dumbbells, bands and no machines', () {
      for (final days in [3, 4, 6]) {
        for (final workout in build(
          request(days: days, equipment: home),
        ).workouts) {
          expect(workout.exercises.length, greaterThanOrEqualTo(4));
        }
      }
    });

    test('still make a workout with no equipment at all', () {
      for (final workout in build(request(days: 3, equipment: bare)).workouts) {
        expect(workout.exercises.length, greaterThanOrEqualTo(3));
      }
    });

    test('are another set of choices for another variant', () {
      List<String> ids(int variant) => [
        for (final workout in build(request(variant: variant)).workouts)
          for (final planned in workout.exercises) planned.exercise.id,
      ];

      expect(ids(1), isNot(ids(0)));
      expect(ids(0), ids(3), reason: 'three choices, then round again');
    });
  });

  group('the plan', () {
    test('is the same for the same request', () {
      List<String> lines(ProgramRequest request) => [
        for (final workout in build(request).workouts)
          for (final planned in workout.exercises)
            '${planned.exercise.id} ${planned.sets}x${planned.reps} '
                '@${planned.rir}',
      ];

      expect(lines(request()), lines(request()));
    });

    test('puts the lifts first and the small work after', () {
      for (final workout in build(request(days: 4)).workouts) {
        final firstIsolation = workout.exercises.indexWhere(
          (planned) => planned.exercise.pattern == MovementPattern.isolation,
        );
        final lastCompound = workout.exercises.lastIndexWhere(
          (planned) =>
              planned.exercise.pattern != MovementPattern.isolation &&
              planned.exercise.pattern != MovementPattern.core,
        );
        expect(lastCompound, lessThan(firstIsolation));
      }
    });

    test('gives a strength goal fewer reps than a muscle goal', () {
      PlannedExercise lift(ProgramGoal goal) =>
          build(request(goal: goal, days: 3)).workouts.first.exercises.first;

      expect(
        lift(ProgramGoal.strength).reps,
        lessThan(lift(ProgramGoal.muscle).reps),
      );
    });

    test('keeps a set in reserve, more of it for a newcomer', () {
      PlannedExercise lift(ProgramLevel level) =>
          build(request(level: level, days: 3)).workouts.first.exercises.first;

      expect(lift(ProgramLevel.intermediate).rir, 2);
      expect(lift(ProgramLevel.beginner).rir, 3);
    });

    test('plans a lift at the weight its reps allow, from the best max', () {
      // The heaviest set was three reps at 100 kg, a max of 110 kg. Eight
      // reps with two in reserve is ten to failure: 110 / (1 + 10 / 30).
      final program = build(
        request(days: 3),
        history: {'back-squat': done(100, 3)},
      );
      final planned = lifts(program);

      expect(planned['back-squat']!.reps, 8);
      expect(planned['back-squat']!.targetWeightKg, 82.5);
      expect(planned['bench-press']!.targetWeightKg, 0);
      for (final item in planned.values.where(
        (item) => !item.exercise.trackingType.usesWeight,
      )) {
        expect(item.targetWeightKg, 0);
      }
    });

    test('past ten reps to failure, goes by the last set only if as long', () {
      PlannedExercise curl(ExerciseHistory history) => lifts(
        build(request(days: 3), history: {'lying-leg-curl': history}),
      )['lying-leg-curl']!;

      // Twelve reps with one in reserve is thirteen to failure, past what
      // the max can tell.
      expect(curl(done(40, 12)).reps, 12);
      expect(curl(done(40, 12)).targetWeightKg, 40);
      expect(curl(done(40, 5)).targetWeightKg, 0);
    });

    test('holds a trunk exercise for a time, not a count', () {
      final program = build(request(days: 3, equipment: bare));
      final held = [
        for (final workout in program.workouts)
          for (final planned in workout.exercises)
            if (planned.exercise.trackingType.usesTime) planned,
      ];

      expect(held, isNotEmpty);
      for (final planned in held) {
        expect(planned.reps, 0);
        expect(planned.targetSeconds, isNotNull);
      }
    });

    test('says what it will do next as it was told', () {
      for (final workout in build(request()).workouts) {
        for (final planned in workout.exercises) {
          expect(planned.progressionLabel, 'hold');
        }
      }
    });
  });

  group('the time', () {
    test('a workout fits the minutes it was given', () {
      for (final minutes in [30, 45, 60, 75, 90]) {
        for (final level in ProgramLevel.values) {
          for (final days in [2, 4, 6]) {
            for (final workout in build(
              request(minutes: minutes, level: level, days: days),
            ).workouts) {
              final budget = Duration(minutes: minutes) - programWarmup;
              final isAsShortAsItGets =
                  workout.exercises.length == programMinExercises &&
                  workout.exercises.every((planned) => planned.sets <= 2);
              expect(
                workout.length <= budget || isAsShortAsItGets,
                isTrue,
                reason:
                    '$minutes min $level $days days '
                    '${workout.kind}: ${workout.length}',
              );
              expect(
                workout.length,
                plannedDuration(workout.exercises),
                reason: 'the length is the plan\'s own',
              );
            }
          }
        }
      }
    });

    test('a short workout holds fewer exercises than a long one', () {
      int exercises(int minutes) => build(
        request(minutes: minutes, days: 4, level: ProgramLevel.advanced),
      ).workouts.first.exercises.length;

      expect(exercises(30), lessThan(exercises(90)));
    });

    test('a newcomer\'s workout is smaller than an advanced lifter\'s', () {
      int sets(ProgramLevel level) =>
          build(request(level: level, minutes: 90, days: 4))
              .workouts
              .first
              .totalSets;

      expect(
        sets(ProgramLevel.beginner),
        lessThan(sets(ProgramLevel.advanced)),
      );
    });
  });

  group('the week as a whole', () {
    test('trains every large muscle in a gym program of any length', () {
      for (final days in [2, 3, 4, 5, 6]) {
        final sets = {
          for (final (muscle, count) in build(request(days: days)).weeklySets)
            muscle: count,
        };
        for (final muscle in [
          MuscleGroup.chest,
          MuscleGroup.lats,
          MuscleGroup.quads,
          MuscleGroup.hamstrings,
        ]) {
          expect(sets[muscle] ?? 0, greaterThan(0), reason: '$muscle $days');
        }
      }
    });

    test('gives every large muscle a workable number of sets a week', () {
      // Fewer than about five sets a week hardly trains a muscle, and past
      // twenty or so more sets stop paying for the time they take.
      for (final goal in ProgramGoal.values) {
        for (final level in ProgramLevel.values) {
          for (final days in [2, 3, 4, 5, 6]) {
            final sets = {
              for (final (muscle, count) in build(
                request(goal: goal, level: level, days: days),
              ).weeklySets)
                muscle: count,
            };
            for (final muscle in [
              MuscleGroup.chest,
              MuscleGroup.lats,
              MuscleGroup.quads,
              MuscleGroup.hamstrings,
            ]) {
              expect(
                sets[muscle] ?? 0,
                inInclusiveRange(days == 2 ? 3 : 5, 24),
                reason: '$muscle, $goal $level $days days',
              );
            }
          }
        }
      }
    });

    test('counts a muscle\'s sets the way the rest of the app does', () {
      final program = build(request(days: 4));
      final byHand = <MuscleGroup, int>{};
      for (final workout in program.workouts) {
        for (final planned in workout.exercises) {
          for (final muscle in planned.exercise.primaryMuscles) {
            byHand[muscle] = (byHand[muscle] ?? 0) + planned.sets;
          }
        }
      }

      expect({for (final (m, n) in program.weeklySets) m: n}, byHand);
    });

    test('counts workouts of a kind', () {
      final program = build(request(days: 6));

      expect(program.countOf(WorkoutKind.push), 2);
      expect(program.countOf(WorkoutKind.upper), 0);
    });
  });
  group('the lifter\'s habits', () {
    final now = DateTime(2026, 10, 13, 12);
    final base = ProgramRequest.initial();

    WorkoutSession workout(int daysAgo, int minutes, String exerciseId) =>
        WorkoutSession(
            id: '$daysAgo',
            routineName: 'x',
            startedAt: now.subtract(Duration(days: daysAgo)),
            exercises: [
              ExerciseSession(
                exercise: library.firstWhere((item) => item.id == exerciseId),
                sets: [],
              ),
            ],
          )
          ..finishedAt = now
              .subtract(Duration(days: daysAgo))
              .add(Duration(minutes: minutes));

    /// Three workouts a week for four weeks.
    List<WorkoutSession> month(String exerciseId, {int minutes = 50}) => [
      for (var i = 0; i < 12; i++) workout(2 + 2 * i, minutes, exerciseId),
    ];

    test('keeps the base when there are too few workouts to go by', () {
      final few = month('bench-press').take(3);

      expect(suggestProgramRequest(few, now, base: base).days, base.days);
      expect(suggestProgramRequest(few, now, base: base).minutes, base.minutes);
    });

    test('takes the days a week and the length from the workouts', () {
      final suggested = suggestProgramRequest(
        month('bench-press'),
        now,
        base: base,
      );

      expect(suggested.days, 3);
      expect(suggested.minutes, 45);
    });

    test('does not count a workout that ran for hours, or an old one', () {
      final suggested = suggestProgramRequest(
        [
          ...month('bench-press'),
          workout(1, 400, 'bench-press'),
          workout(70, 50, 'bench-press'),
        ],
        now,
        base: base,
      );

      expect(suggested.days, 3);
      expect(suggested.minutes, 45);
    });

    test('keeps the place when the workouts hold no exercises', () {
      final empty = [
        for (var i = 0; i < 12; i++)
          WorkoutSession(
            id: '$i',
            routineName: 'x',
            startedAt: now.subtract(Duration(days: 2 + 2 * i)),
            exercises: [],
          )..finishedAt = now.subtract(Duration(days: 2 + 2 * i)),
      ];

      expect(
        suggestProgramRequest(empty, now, base: base).equipment,
        base.equipment,
      );
    });

    test('is the smallest place that has what was used', () {
      Set<Equipment> place(String exerciseId) =>
          suggestProgramRequest(month(exerciseId), now, base: base).equipment;

      expect(place('bench-press'), ProgramPlace.gym.equipment);
      expect(place('seated-dumbbell-press'), ProgramPlace.dumbbells.equipment);
      expect(place('push-up'), ProgramPlace.bodyweight.equipment);
    });
  });

  group('the snapshot', () {
    // What the generator says for a handful of requests, pinned like the
    // engines are (`engine_golden_test.dart`): a rule change bumps
    // [programGeneratorVersion] and copies the printed report into the
    // golden file in the same commit.
    const goldenPath = 'test/golden/programs.txt';

    String describe(String label, ProgramRequest request) {
      final program = build(request);
      final buffer = StringBuffer('\n# $label\n');
      for (final workout in program.workouts) {
        buffer.writeln(
          '${workout.kind.name} ${workout.index}: '
          '${workout.totalSets} sets, ${workout.length.inMinutes} min',
        );
        for (final planned in workout.exercises) {
          buffer.writeln(
            '  ${planned.exercise.id} ${planned.sets} x '
            '${planned.reps == 0 ? "${planned.targetSeconds}s" : planned.reps}'
            ' rir ${planned.rir}',
          );
        }
      }
      buffer.writeln(
        'weekly: ${[for (final (muscle, count) in program.weeklySets) '${muscle.name} $count'].join(', ')}',
      );
      return buffer.toString();
    }

    test('does not change unless a rule does', () {
      final report =
          StringBuffer(
              '# generator version\nprogram generator: $programGeneratorVersion\n',
            )
            ..write(
              describe(
                'muscle, intermediate, 3 days, 60 min, gym',
                request(days: 3),
              ),
            )
            ..write(
              describe('muscle, intermediate, 4 days, 60 min, gym', request()),
            )
            ..write(
              describe(
                'strength, beginner, 3 days, 45 min, gym',
                request(
                  goal: ProgramGoal.strength,
                  level: ProgramLevel.beginner,
                  days: 3,
                  minutes: 45,
                ),
              ),
            )
            ..write(
              describe(
                'general, beginner, 2 days, 30 min, dumbbells',
                request(
                  goal: ProgramGoal.general,
                  level: ProgramLevel.beginner,
                  days: 2,
                  minutes: 30,
                  equipment: home,
                ),
              ),
            )
            ..write(
              describe(
                'muscle, advanced, 6 days, 90 min, gym',
                request(level: ProgramLevel.advanced, days: 6, minutes: 90),
              ),
            )
            ..write(
              describe(
                'muscle, intermediate, 5 days, 60 min, bodyweight',
                request(days: 5, equipment: bare),
              ),
            );
      final golden = File(goldenPath);
      if (!golden.existsSync()) {
        golden
          ..createSync(recursive: true)
          ..writeAsStringSync(report.toString());
        fail('Wrote a new golden file: check $goldenPath into git.');
      }

      expect(
        report.toString(),
        golden.readAsStringSync(),
        reason:
            'The generator changed what it builds. If that was intended, '
            'bump programGeneratorVersion and copy the report into '
            '$goldenPath with the rule change.',
      );
    });
  });
}
