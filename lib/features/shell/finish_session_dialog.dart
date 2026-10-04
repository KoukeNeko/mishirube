import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

enum FinishChoice { keepGoing, discard, finish }

/// Asks how a running workout or exercise ends: kept, given up, or not
/// yet. Null when the dialog is dismissed.
Future<FinishChoice?> askHowSessionEnds(
  BuildContext context,
  ActiveSession session,
) {
  final l10n = context.l10n;
  final name = session.name(l10n);
  return showAppDialog<FinishChoice>(
    context,
    AppDialog(
      title: l10n.sessionEndTitle(session: name),
      message: switch (session) {
        ActiveWorkout() => l10n.sessionEndWorkoutMessage,
        ActiveActivity() => l10n.sessionEndActivityMessage,
        ActiveBath() => l10n.sessionEndBathMessage,
      },
      actions: [
        DialogAction(
          label: l10n.sessionFinishAndSave,
          tone: DialogTone.primary,
          onTap: () => Navigator.of(context).pop(FinishChoice.finish),
        ),
        DialogAction(
          label: switch (session) {
            ActiveWorkout() => l10n.sessionDiscardWorkout,
            ActiveActivity() => l10n.sessionDiscardActivity,
            ActiveBath() => l10n.sessionDiscardBath,
          },
          tone: DialogTone.destructive,
          onTap: () => Navigator.of(context).pop(FinishChoice.discard),
        ),
        // The way out goes last, where a stacked Cancel belongs.
        DialogAction(
          label: l10n.sessionKeepGoing(session: name),
          onTap: () => Navigator.of(context).pop(FinishChoice.keepGoing),
        ),
      ],
    ),
  );
}
