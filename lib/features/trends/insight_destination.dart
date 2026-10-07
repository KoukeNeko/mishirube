import 'package:flutter/widgets.dart';

import '../../backend/engines/trend_findings.dart';
import '../../domain/domain.dart';
import '../body/body_screen.dart';
import 'insight_detail_screen.dart';
import 'trend_detail_screen.dart';

/// The page that explains [insight], or null for one with nothing behind
/// it.
///
/// Exhaustive on purpose: a new kind of insight must decide what opening
/// its card does, rather than silently opening another one's page.
Widget? insightDestination(Insight insight) => switch (insight.kind) {
  InsightKind.exerciseVolume => InsightDetailScreen(
    exerciseId: insight.exerciseId,
  ),
  InsightKind.bodyWeight => const BodyScreen(),
  InsightKind.weeklyTraining => const TrendDetailScreen(
    domain: TrendDomain.training,
  ),
  InsightKind.sleepAndTraining => null,
};
