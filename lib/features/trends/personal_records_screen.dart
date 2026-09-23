import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/view_model.dart';
import '../../backend/engines/workout_review.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_detail_screen.dart';
import 'trends_view_model.dart';

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
        appBar: PageAppBar(title: '個人紀錄'),
        children: [
          if (records.isEmpty)
            Gutter(
              child: const EmptyStateCard(
                icon: Icons.emoji_events_outlined,
                title: '沒有紀錄',
              ),
            )
          else ...[
            for (final bests in records)
              Gutter(child: _RecordRow(bests: bests)),
            Gutter(child: const TagWrap(labels: ['Epley 估計，非實測'])),
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
    final heaviest = bests.heaviest;
    final estimate = bests.bestEstimate;
    return NavCard(
      title: bests.exercise.name,
      subtitle:
          '最重 ${formatWeight(heaviest.weightKg)} kg × ${heaviest.reps} · '
          '${heaviest.date.month} 月 ${heaviest.date.day} 日',
      detail: estimate == null
          ? null
          : '估計最大重量 ${estimate.oneRepMaxKg!.round()} kg · '
                '${estimate.date.month} 月 ${estimate.date.day} 日',
      onTap: () =>
          pushPage(context, ExerciseDetailScreen(exercise: bests.exercise)),
    );
  }
}
