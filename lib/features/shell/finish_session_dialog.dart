import 'package:flutter/material.dart';

import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';

enum FinishChoice { keepGoing, discard, finish }

/// Asks how a running workout or exercise ends: kept, given up, or not
/// yet. Null when the dialog is dismissed.
Future<FinishChoice?> askHowSessionEnds(
  BuildContext context,
  ActiveSession session,
) {
  final label = session.label;
  return showAppDialog<FinishChoice>(
    context,
    AppDialog(
      title: '結束這次$label？',
      message: switch (session) {
        ActiveWorkout() => '已完成的組數會存成紀錄；放棄則不會算成一次訓練。',
        ActiveActivity() => '結束會存成一筆運動紀錄；放棄則什麼都不留。',
      },
      actions: [
        DialogAction(
          label: '結束並儲存',
          tone: DialogTone.primary,
          onTap: () => Navigator.of(context).pop(FinishChoice.finish),
        ),
        DialogAction(
          label: switch (session) {
            ActiveWorkout() => '放棄這次訓練',
            ActiveActivity() => '放棄這次運動',
          },
          tone: DialogTone.destructive,
          onTap: () => Navigator.of(context).pop(FinishChoice.discard),
        ),
        // The way out goes last, where a stacked Cancel belongs.
        DialogAction(
          label: '繼續$label',
          onTap: () => Navigator.of(context).pop(FinishChoice.keepGoing),
        ),
      ],
    ),
  );
}
