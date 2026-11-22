import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/application/record_tools.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/domain/domain.dart';

import '../support/harness.dart';

void main() {
  late FakeClock clock;
  late Backend backend;

  setUp(() {
    clock = FakeClock();
    backend = Backend.inMemory(clock: clock.now);
  });

  tearDown(() => backend.close());

  Map<String, Object?> call(String name, Map<String, Object?> arguments) =>
      backend.recordTools.call(name, arguments);

  test('every tool schema meets strict mode', () {
    for (final tool in RecordTools.tools) {
      final schema = tool.parameters;
      final properties = schema['properties']! as Map;
      expect(schema['additionalProperties'], false, reason: tool.name);
      expect(
        (schema['required']! as List).toSet(),
        properties.keys.toSet(),
        reason: tool.name,
      );
    }
  });

  test('every tool answers over records with nothing in them', () {
    const period = {
      'from': '2026-09-13',
      'to': '2026-09-19',
      'compare_previous': true,
      'query': 'squat',
      'exercise_id': 'none',
    };
    for (final tool in RecordTools.tools) {
      final arguments = {
        for (final key in (tool.parameters['properties']! as Map).keys)
          key as String: period[key],
      };
      final answer = call(tool.name, arguments);
      if (tool.name == 'exercise_history') {
        expect(answer, contains('error'));
      } else {
        expect(answer, isNot(contains('error')), reason: tool.name);
      }
    }
  });

  test('a period the app cannot answer is an error, not a throw', () {
    expect(call('workouts', {'from': '2026-09-01', 'to': 'soon'}), {
      'error': 'to must be YYYY-MM-DD',
    });
    expect(call('meals', {'from': '2026-02-30', 'to': '2026-03-01'}), {
      'error': 'from is not a date',
    });
    expect(call('meals', {'from': '2026-09-10', 'to': '2026-09-01'}), {
      'error': 'to is before from',
    });
    expect(call('meals', {'from': '2026-01-01', 'to': '2026-09-01'}), {
      'error': 'at most $maxToolDays days at a time',
    });
    expect(call('drop_tables', {}), {'error': 'no tool named drop_tables'});
  });

  test('body records are the weights logged in the period', () {
    backend.journal.recordWeight(72.44, at: DateTime(2026, 9, 18, 7));
    backend.journal.recordWeight(70, at: DateTime(2026, 9, 1, 7));

    final answer = call('body_records', {
      'from': '2026-09-15',
      'to': '2026-09-19',
    });

    expect(answer['weights'], [
      {'date': '2026-09-18', 'kg': 72.4},
    ]);
  });

  test('body composition readings come with their unit', () {
    backend.journal.recordBodyReadings({
      BodyMetric.bodyFat: 18.25,
    }, at: DateTime(2026, 9, 18, 7));

    final answer = call('body_records', {
      'from': '2026-09-18',
      'to': '2026-09-18',
    });

    expect(answer['body_composition'], [
      {
        'date': '2026-09-18',
        'metric': 'bodyFat',
        'value': 18.3,
        'unit': '%',
        'is_estimated': true,
      },
    ]);
  });

  test('wellness lists only the days something was logged', () {
    backend.journal.recordWellness(
      WellnessKind.mood,
      4,
      at: DateTime(2026, 9, 17, 21),
    );
    backend.nutrition
      ..logWater(250, at: DateTime(2026, 9, 18, 9))
      ..logWater(300, at: DateTime(2026, 9, 18, 15));

    final days =
        call('wellness', {'from': '2026-09-15', 'to': '2026-09-19'})['days']!
            as List;

    expect(days, hasLength(2));
    expect(
      days.first,
      containsPair('check_ins', [
        {'kind': 'mood', 'score': 4, 'out_of': 5},
      ]),
    );
    expect(days.last, containsPair('water_ml', 550));
  });

  test('note search finds notes, not other records', () {
    backend.journal.recordNote('膝蓋有點緊', at: DateTime(2026, 9, 18, 8));
    backend.journal.recordNote('睡得好', at: DateTime(2026, 9, 18, 9));
    backend.journal.recordWeight(72, at: DateTime(2026, 9, 18, 7));

    final notes = call('search_notes', {
      'query': '膝蓋',
      'from': '2026-09-18',
      'to': '2026-09-18',
    })['notes'];

    expect(notes, [containsPair('text', '膝蓋有點緊')]);
  });

  test('the timeline reads at most $maxTimelineDays days', () {
    expect(call('timeline', {'from': '2026-09-01', 'to': '2026-09-19'}), {
      'error': 'at most $maxTimelineDays days at a time',
    });
    backend.journal.recordWeight(72, at: DateTime(2026, 9, 18, 7));
    final days =
        call('timeline', {'from': '2026-09-13', 'to': '2026-09-19'})['days']!
            as List;
    expect(days.single, containsPair('date', '2026-09-18'));
  });

  test('workouts work out the change from the period before', () {
    final exercise = backend.catalog.create(
      const ExerciseDefinition(
        id: 'tool-bench',
        name: '工具臥推',
        equipment: Equipment.barbell,
        primaryMuscles: [MuscleGroup.chest],
        pattern: MovementPattern.horizontalPush,
      ),
    );
    expect(
      call('find_exercise', {'query': '工具臥推'})['exercises'],
      contains(containsPair('id', 'tool-bench')),
    );
    void lift(DateTime at, double weightKg) {
      clock.current = at;
      final workout = backend.training.startFree([exercise]);
      backend.training
        ..begin(workout)
        ..editSet(workout, 0, weightKg: weightKg, reps: 5, rir: 2)
        ..toggleSet(workout, 0);
      clock.advance(const Duration(minutes: 30));
      backend.training.finish(workout);
    }

    lift(DateTime(2026, 9, 10, 18), 60);
    lift(DateTime(2026, 9, 17, 18), 80);

    final answer = call('workouts', {
      'from': '2026-09-14',
      'to': '2026-09-20',
      'compare_previous': true,
    });

    expect(answer['workout_count'], 1);
    expect(answer['volume_kg'], 400);
    expect(answer['previous'], containsPair('volume_kg', 300.0));
    expect(answer['change'], containsPair('volume_kg', 100.0));

    final history = call('exercise_history', {
      'exercise_id': exercise.id,
      'from': '2026-09-01',
      'to': '2026-09-20',
    });
    expect(history['session_count'], 2);
  });
}
