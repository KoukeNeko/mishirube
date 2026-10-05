import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/widgets.dart';
import '../trends/muscle_map.dart';
import 'exercise_demo.dart';
import 'exercise_detail_screen.dart';

/// Opens YouTube on a search for [name]: in the YouTube app where it is
/// installed, in the browser otherwise.
Future<void> searchExerciseOnYoutube(BuildContext context, String name) async {
  final opened = await launchUrl(
    Uri.https('www.youtube.com', '/results', {'search_query': name}),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    showToast(context, context.l10n.cannotOpenLink, kind: ToastKind.warning);
  }
}

/// What an exercise is, over the workout: which muscles and equipment, how
/// it is done, the cues; and the way to see it done on YouTube or to open
/// its page.
Future<void> showExerciseInfoSheet(
  BuildContext context,
  ExerciseDefinition exercise,
) async {
  final opensPage = await showAppSheet<bool>(
    context,
    (_) => ExerciseInfoCard(exercise: exercise),
  );
  if (opensPage != true || !context.mounted) return;
  await pushPage<void>(context, ExerciseDetailScreen(exercise: exercise));
}

/// The tallest the demonstration gets in the card: between sets what is
/// wanted is the muscles and the cues, not a picture as wide as the
/// screen.
const _demoMaxSize = 280.0;

class ExerciseInfoCard extends StatelessWidget {
  const ExerciseInfoCard({super.key, required this.exercise});

  final ExerciseDefinition exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final history = AppStoreScope.of(context).exerciseHistory(exercise);
    return AppSheetScaffold(
      title: exercise.name,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          PrimaryButton(
            label: l10n.searchOnYoutube,
            icon: Icons.play_circle_outline,
            onPressed: () => searchExerciseOnYoutube(context, exercise.name),
          ),
          SecondaryButton(
            label: l10n.exerciseDetails,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
      children: [
        if (exercise.frames.isNotEmpty) ...[
          Gutter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: _demoMaxSize,
                  maxHeight: _demoMaxSize,
                ),
                child: AppCard(
                  child: ExerciseDemo(
                    name: exercise.name,
                    frames: exercise.frames,
                  ),
                ),
              ),
            ),
          ),
          Gutter(child: ExerciseDemoCredit(exercise: exercise)),
        ],
        Gutter(child: ExerciseSpecCard(exercise: exercise)),
        Gutter(
          child: AppCard(
            child: MuscleRoleMap(
              primary: exercise.primaryMuscles,
              secondary: exercise.secondaryMuscles,
            ),
          ),
        ),
        if (exercise.cues.isNotEmpty) ...[
          Gutter(child: SectionLabel(l10n.cuesSection)),
          Gutter(child: ExerciseCueList(cues: exercise.cues)),
        ],
        if (history.last != null) ...[
          Gutter(child: SectionLabel(l10n.recordTitle)),
          Gutter(
            child: ExerciseHistoryCard(exercise: exercise, history: history),
          ),
        ],
      ],
    );
  }
}
