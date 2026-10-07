import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/trend_findings.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/body/body_screen.dart';
import 'package:mishirube/features/trends/insight_destination.dart';
import 'package:mishirube/features/trends/insight_detail_screen.dart';
import 'package:mishirube/features/trends/trend_detail_screen.dart';

void main() {
  Insight insight(InsightKind kind, {String? exerciseId}) => Insight(
    kind: kind,
    statement: '',
    evidence: const [],
    exerciseId: exerciseId,
  );

  test('each kind of insight opens the page about it', () {
    expect(
      insightDestination(
        insight(InsightKind.exerciseVolume, exerciseId: 'back-squat'),
      ),
      isA<InsightDetailScreen>().having(
        (page) => page.exerciseId,
        'exerciseId',
        'back-squat',
      ),
      reason: 'the volume of that exercise, not the most trained one',
    );
    expect(
      insightDestination(insight(InsightKind.bodyWeight)),
      isA<BodyScreen>(),
    );
    expect(
      insightDestination(insight(InsightKind.weeklyTraining)),
      isA<TrendDetailScreen>().having(
        (page) => page.domain,
        'domain',
        TrendDomain.training,
      ),
    );
    expect(
      insightDestination(insight(InsightKind.sleepAndTraining)),
      isNull,
      reason: 'nothing to open yet',
    );
  });
}
