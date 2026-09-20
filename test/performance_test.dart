import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/seed/demo_content.dart';
import 'package:mishirube/backend/seed/seed.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';

import 'support/harness.dart';

/// Years of training for one person: the size the app must stay quick at.
const _workouts = 500;
const _setsPerWorkout = 20;

/// Generous for a laptop or a CI box, tight enough to catch a query that
/// starts scanning everything. The reads run on the UI isolate, so a
/// regression here shows up as dropped frames on a phone.
const _readBudget = Duration(seconds: 2);

void main() {
  test('reads stay quick with ${_workouts * _setsPerWorkout} sets', () {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    addTearDown(backend.close);
    seedDemoData(backend, clock.now());
    final exercises = DemoExercises.catalog.take(4).toList();

    final written = _time(() {
      backend.db.transaction(() {
        for (var i = 0; i < _workouts; i++) {
          final startedAt = clock.now().subtract(Duration(hours: 12 * i + 12));
          backend.storage.workouts.save(
            WorkoutSession(
              id: 'bench-$i',
              routineName: '壓力測試',
              startedAt: startedAt,
              exercises: [
                for (final exercise in exercises)
                  ExerciseSession(
                    exercise: exercise,
                    sets: [
                      for (
                        var set = 0;
                        set < _setsPerWorkout ~/ exercises.length;
                        set++
                      )
                        WorkoutSet(
                          weightKg: 60 + set.toDouble(),
                          reps: 5,
                          previousWeightKg: 60,
                          previousReps: 5,
                          isDone: true,
                        ),
                    ],
                  ),
              ],
            )..finishedAt = startedAt.add(const Duration(minutes: 50)),
            action: 'create',
            source: ChangeSource.seed,
          );
        }
      });
    });

    final catalog = _time(backend.catalog.all);
    final month = _time(
      () =>
          backend.timeline.month(DateTime(clock.now().year, clock.now().month)),
    );
    final trends = _time(backend.insights.trends);
    final history = _time(() => backend.catalog.history('back-squat'));

    printOnFailure(
      'write $written, catalog $catalog, month $month, trends $trends, '
      'history $history',
    );
    expect(catalog, lessThan(_readBudget), reason: 'catalog with usage');
    expect(month, lessThan(_readBudget), reason: 'a month of the log');
    expect(trends, lessThan(_readBudget), reason: 'the trends overview');
    expect(history, lessThan(_readBudget), reason: 'one exercise history');
  });
}

Duration _time(void Function() action) {
  final stopwatch = Stopwatch()..start();
  action();
  return stopwatch.elapsed;
}
