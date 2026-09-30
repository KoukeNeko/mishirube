import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/view_model.dart';
import '../../backend/engines/workout_review.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_detail_screen.dart';
import 'trends_view_model.dart';
import '../../l10n/l10n.dart';

/// Every exercise's heaviest set and best estimated max, the most
/// recently set first.
class PersonalRecordsScreen extends StatelessWidget {
  const PersonalRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TrendsViewModel.new,
    builder: (context, trends) {
      final records = trends.personalRecords();
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.personalRecords),
        children: [
          if (records.isEmpty)
            Gutter(
              child: EmptyStateCard(
                icon: Icons.emoji_events_outlined,
                title: context.l10n.noEntriesShort,
              ),
            )
          else ...[
            for (final bests in records)
              Gutter(child: _RecordRow(bests: bests)),
            Gutter(child: TagWrap(labels: [context.l10n.epleyEstimate])),
          ],
        ],
      );
    },
  );
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.bests});

  final ExerciseBests bests;

  @override
  Widget build(BuildContext context) {
    final best = bests.best;
    final estimate = bests.bestEstimate;
    final l10n = context.l10n;
    final type = bests.exercise.trackingType;
    final set = best.figuresIn(l10n, type);
    final date = context.dates.monthDay(best.date);
    return NavCard(
      title: bests.exercise.name,
      // What a record is depends on how the exercise is recorded.
      subtitle: switch (type) {
        TrackingType.weightReps ||
        TrackingType.weightDuration => l10n.heaviestSet(set: set, date: date),
        TrackingType.reps => l10n.mostRepsSet(set: set, date: date),
        TrackingType.duration => l10n.longestSet(set: set, date: date),
        TrackingType.distance => l10n.furthestSet(set: set, date: date),
      },
      detail: estimate == null
          ? null
          : context.l10n.estimatedMaxOn(
              weight: estimate.oneRepMaxKg!.round(),
              date: context.dates.monthDay(estimate.date),
            ),
      onTap: () =>
          pushPage(context, ExerciseDetailScreen(exercise: bests.exercise)),
    );
  }
}
