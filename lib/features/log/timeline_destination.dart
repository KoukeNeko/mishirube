import 'package:flutter/widgets.dart';

import '../../domain/domain.dart';
import '../activity/activity_detail_screen.dart';
import '../journal/journal_detail_screen.dart';
import '../nutrition/daily_nutrition_screen.dart';
import '../nutrition/meal_detail_screen.dart';
import '../nutrition/meal_group_screen.dart';
import '../sleep/sleep_screen.dart';
import '../training/workout_summary_screen.dart';

/// The page a log row opens, or null for a row with nothing behind it.
/// [isSleep] says whether a wellness record is a sleep, which opens on
/// its day's sleep page. [mealById] reads the item a food row names and
/// [mealGroup] the items of the meal that item was put together into.
///
/// Exhaustive on purpose: a new kind of record must decide what opening
/// its row does, rather than silently doing nothing.
Widget? timelineDestination(
  TimelineEntry entry, {
  required bool Function(String id) isSleep,
  required MealEvent? Function(String id) mealById,
  required List<MealEvent> Function(String groupId) mealGroup,
}) {
  final id = entry.recordId;
  // A food row names one meal, so it opens that meal rather than the day
  // it was eaten on; a row whose record is gone opens the day. It names
  // the meal by its first item: a meal put together from several opens as
  // the whole of it, as it does on the day's food page.
  if (entry.category == RecordCategory.nutrition && id != null) {
    if (mealById(id) case final meal?) {
      if (meal.groupId case final groupId?) {
        final items = mealGroup(groupId);
        if (items.length > 1) return MealGroupScreen(items: items);
      }
      return MealDetailScreen(meal: meal);
    }
  }
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
