import 'package:flutter/widgets.dart';

import '../../domain/domain.dart';
import '../activity/activity_detail_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../sleep/sleep_screen.dart';
import '../training/workout_summary_screen.dart';

/// The page a log row opens, or null for a row with nothing behind it.
/// [isSleep] says whether a wellness record is a sleep, which opens on
/// its day's sleep page.
///
/// Exhaustive on purpose: a new kind of record must decide what opening
/// its row does, rather than silently doing nothing.
Widget? timelineDestination(
  TimelineEntry entry, {
  required bool Function(String id) isSleep,
}) {
  final id = entry.recordId;
  return switch (entry.category) {
    RecordCategory.training => WorkoutSummaryScreen(workoutId: id),
    RecordCategory.nutrition => DailyNutritionScreen(day: entry.at),
    RecordCategory.activity when id != null => ActivityDetailScreen(
      activityId: id,
    ),
    RecordCategory.wellness when id != null && isSleep(id) => SleepScreen(
      day: entry.at,
    ),
    RecordCategory.body || RecordCategory.wellness when id != null =>
      JournalDetailScreen(id: id, at: entry.at),
    // Every source gives its rows an id; a row without one has nothing
    // behind it to open.
    _ => null,
  };
}
