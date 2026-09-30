import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/training_metrics.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'set_names.dart';

/// Shows the earlier sessions of [exercise] one at a time, newest first,
/// and resolves to the working sets of the one shown when it is loaded;
/// null when dismissed.
Future<List<SetLoad>?> showExerciseHistorySheet(
  BuildContext context, {
  required ExerciseDefinition exercise,
  required List<ExerciseSessionRecord> sessions,
  required DateTime now,
}) => showAppSheet<List<SetLoad>>(
  context,
  (_) =>
      _ExerciseHistorySheet(exercise: exercise, sessions: sessions, now: now),
);

class _ExerciseHistorySheet extends StatefulWidget {
  const _ExerciseHistorySheet({
    required this.exercise,
    required this.sessions,
    required this.now,
  });

  final ExerciseDefinition exercise;

  /// Newest first.
  final List<ExerciseSessionRecord> sessions;
  final DateTime now;

  @override
  State<_ExerciseHistorySheet> createState() => _ExerciseHistorySheetState();
}

class _ExerciseHistorySheetState extends State<_ExerciseHistorySheet> {
  int _index = 0;

  /// `2026 年 9 月 27 日 · 3 天前`.
  String _dayLabel(BuildContext context, DateTime date) {
    final now = widget.now;
    // Calendar days, which a change of clocks does not shorten.
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
    return [
      context.dates.fullDate(date),
      if (days == 0)
        context.l10n.tabToday
      else
        context.l10n.daysAgo(count: days),
    ].join(' · ');
  }

  /// What a session came to, by how the exercise is recorded: its volume,
  /// its reps, its time or its distance.
  String _totalLabel(AppLocalizations l10n) =>
      switch (widget.exercise.trackingType) {
        TrackingType.weightReps => l10n.volumeTitle,
        TrackingType.reps => l10n.totalReps,
        TrackingType.duration || TrackingType.weightDuration => l10n.totalTime,
        TrackingType.distance => l10n.totalDistance,
      };

  String _total(AppLocalizations l10n, ExerciseSessionRecord session) {
    final counted = countedSets(session.sets);
    return switch (widget.exercise.trackingType) {
      TrackingType.weightReps =>
        '${formatKcal(volumeKg(session.sets).round())} kg',
      TrackingType.reps => '${counted.fold(0, (sum, set) => sum + set.reps)}',
      TrackingType.duration || TrackingType.weightDuration => formatClock(
        Duration(
          seconds: counted.fold(
            0,
            (sum, set) => sum + (set.durationSeconds ?? 0),
          ),
        ),
      ),
      TrackingType.distance =>
        '${formatKilometers(counted.fold(0.0, (sum, set) => sum + (set.distanceMeters ?? 0)))} km',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessions = widget.sessions;
    final shown = sessions.isEmpty ? null : sessions[_index];
    // Warm-ups and the like are not loaded onto the working sets.
    final loads = [
      for (final set in shown?.sets ?? const <WorkoutSet>[])
        if (set.type == SetType.working)
          SetLoad(
            weightKg: set.weightKg,
            reps: set.reps,
            seconds: set.durationSeconds,
            meters: set.distanceMeters,
          ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Gutter(
                  child: Text(
                    l10n.exerciseRecordsTitle(name: widget.exercise.name),
                    style: AppTextStyles.pageTitle,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (shown == null)
                  Gutter(
                    child: Text(
                      l10n.noEntriesShort,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  )
                else ...[
                  Gutter(
                    child: Row(
                      children: [
                        SquareIconButton(
                          icon: Icons.chevron_left,
                          tooltip: l10n.earlierRecord,
                          onPressed: _index < sessions.length - 1
                              ? () => setState(() => _index++)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            _dayLabel(context, shown.date),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.itemTitle,
                          ),
                        ),
                        SquareIconButton(
                          icon: Icons.chevron_right,
                          tooltip: l10n.laterRecord,
                          onPressed: _index > 0
                              ? () => setState(() => _index--)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Gutter(
                    child: GroupedCard(
                      children: [
                        KeyValueRow(
                          label: _totalLabel(l10n),
                          value: _total(l10n, shown),
                        ),
                        for (final (i, set) in shown.sets.indexed)
                          KeyValueRow(
                            label: setName(
                              l10n,
                              set,
                              workingNumber(shown.sets, i),
                            ),
                            value: set.figuresIn(
                              l10n,
                              widget.exercise.trackingType,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Gutter(
          child: Padding(
            padding: EdgeInsets.only(
              top: AppSpacing.md,
              bottom:
                  AppSpacing.screenGutter +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: PrimaryButton(
              label: l10n.loadPrevious,
              onPressed: loads.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(loads),
            ),
          ),
        ),
      ],
    );
  }
}
