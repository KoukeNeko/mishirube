import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/widgets.dart';
import '../training/set_names.dart';
import '../training/workout_summary_screen.dart';
import 'trends_view_model.dart';

/// The records a volume report rests on: [exercise]'s sessions since
/// [from], newest first, a card to each with every set done in it. The
/// count beside a date is what the session adds to the weekly sets, so
/// warm-ups are listed but not counted; the card opens its workout.
class VolumeRecordsScreen extends StatelessWidget {
  const VolumeRecordsScreen({
    super.key,
    required this.exercise,
    required this.from,
  });

  final ExerciseDefinition exercise;
  final DateTime from;

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TrendsViewModel.new,
    builder: (context, trends) {
      final l10n = context.l10n;
      final sessions = trends.volumeSessions(exercise.id, from: from);
      return DetailPage(
        appBar: PageAppBar(
          title: exercise.name,
          subtitle: context.dates.span(from, trends.now()),
        ),
        children: [
          if (sessions.isEmpty)
            Gutter(
              child: EmptyStateCard(
                icon: Icons.fitness_center,
                title: l10n.noEntriesShort,
              ),
            )
          else
            for (final session in sessions)
              Gutter(
                child: GroupedCard(
                  children: [
                    NavRow(
                      title: context.dates.dayWithWeekday(session.date),
                      trailing: Text(
                        l10n.setsCount(count: countedSets(session.sets).length),
                        style: AppTextStyles.body,
                      ),
                      showChevron: true,
                      onTap: () => pushPage(
                        context,
                        WorkoutSummaryScreen(workoutId: session.workoutId),
                      ),
                    ),
                    for (final (i, set) in session.sets.indexed)
                      KeyValueRow(
                        label: setName(
                          l10n,
                          set,
                          workingNumber(session.sets, i),
                        ),
                        value: set.figuresIn(l10n, exercise.trackingType),
                      ),
                  ],
                ),
              ),
        ],
      );
    },
  );
}
