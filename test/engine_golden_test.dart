import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/engines/exercise_search.dart';
import 'package:mishirube/backend/engines/insight_engine.dart';
import 'package:mishirube/backend/engines/substitution_engine.dart';
import 'package:mishirube/backend/engines/training_metrics.dart';
import 'package:mishirube/backend/engines/trend_engine.dart';
import 'package:mishirube/backend/seed/seed.dart';

import 'support/harness.dart';

/// The engines decide what the app tells the user about their training, so
/// a rule change must be deliberate. This runs every engine over the demo
/// records and compares the whole report with a checked-in golden file.
///
/// When a rule really changes: bump the version constant in that engine,
/// run `flutter test -r expanded test/engine_golden_test.dart`, read the
/// printed report, and copy it into `test/golden/engines.txt` in the same
/// commit as the rule change.
const _goldenPath = 'test/golden/engines.txt';

void main() {
  test('the engines produce the same report for the same records', () {
    final clock = FakeClock();
    final backend = Backend.inMemory(clock: clock.now);
    addTearDown(backend.close);
    seedDemoData(backend, clock.now());

    final report = _report(backend);
    final golden = File(_goldenPath);
    if (!golden.existsSync()) {
      golden
        ..createSync(recursive: true)
        ..writeAsStringSync(report);
      fail('Wrote a new golden file: check $_goldenPath into git.');
    }

    expect(
      report,
      golden.readAsStringSync(),
      reason:
          'The engines changed what they say. If that was intended, copy '
          'the report above into $_goldenPath with the rule change.',
    );
  });
}

String _report(Backend backend) {
  final buffer = StringBuffer()
    ..writeln('# engine versions')
    ..writeln('training metrics: $trainingMetricsVersion')
    ..writeln('trend: $trendEngineVersion')
    ..writeln('insight: $insightEngineVersion')
    ..writeln('substitution: $substitutionEngineVersion')
    ..writeln('exercise search: $exerciseSearchVersion');

  final overview = backend.insights.trends();
  buffer
    ..writeln()
    ..writeln('# trends over ${overview.weight.days} days')
    ..writeln(
      'weight: ${overview.weight.values.length} points, '
      'per week ${_round(overview.weight.changePerWeek)}',
    )
    ..writeln(
      'weekly workouts: '
      '${overview.weeklyWorkouts.map((bar) => bar.$2).join(', ')}',
    )
    ..writeln(
      'food days: ${overview.foodDaysComplete}/${overview.foodDaysTracked}',
    )
    ..writeln('average sleep: ${overview.averageSleep}')
    ..writeln()
    ..writeln('# insights');
  for (final insight in overview.insights) {
    buffer
      ..writeln('- ${insight.statement}')
      ..writeln('  ${insight.evidence.join(' | ')}');
  }

  final volume = backend.insights.volumeReport()!;
  buffer
    ..writeln()
    ..writeln('# volume: ${volume.exercise.name}')
    ..writeln('sessions: ${volume.sessionCount}')
    ..writeln(
      'weekly sets: ${volume.weeklySets.map((bar) => bar.$2).join(', ')}',
    )
    ..writeln('estimated max: ${_round(volume.history.estimatedOneRepMaxKg)}')
    ..writeln()
    ..writeln('# history and metrics');
  for (final id in ['back-squat', 'bench-press', 'plank']) {
    final history = backend.catalog.history(id);
    final last = history.last;
    buffer.writeln(
      '$id: ${history.sessionCount} sessions, last '
      '${last == null ? 'none' : '${_round(last.weightKg)}x${last.reps}'}, '
      'e1RM ${_round(history.estimatedOneRepMaxKg)}',
    );
  }

  buffer
    ..writeln()
    ..writeln('# substitutions');
  for (final id in ['back-squat', 'rdl']) {
    final exercise = backend.catalog.byId(id)!;
    for (final option in substitutesFor(exercise, backend.catalog.all())) {
      buffer.writeln(
        '$id → ${option.exercise.id}: ${option.reasons.join(' / ')}',
      );
    }
  }

  buffer
    ..writeln()
    ..writeln('# search');
  for (final query in ['深蹲', 'bench press', 'bnech press', 'RDL', '壺鈴']) {
    final hits = searchExercises(backend.catalog.all(), query: query);
    buffer.writeln(
      '$query → '
      '${hits.take(3).map((hit) => '${hit.exercise.id}(${hit.score})').join(', ')}',
    );
  }
  return buffer.toString();
}

String _round(double? value) =>
    value == null ? 'none' : value.toStringAsFixed(2);
