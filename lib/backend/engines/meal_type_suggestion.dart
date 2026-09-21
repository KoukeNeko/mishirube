import '../../domain/domain.dart';

/// Bump when the rule below changes what it suggests.
const mealTypeSuggestionVersion = 1;

/// How far either side of the time being logged a past label still
/// counts as "around this time".
const mealTypeSuggestionWindow = Duration(minutes: 90);

/// Labels the user must have given around this time before the app
/// offers one. A single past lunch at 15:00 is not a habit.
const mealTypeSuggestionMinimum = 2;

/// Which meal the user usually calls something eaten at [at], or null
/// when they have not shown a habit yet.
///
/// Learned from their own labels, never from the clock: the same 15:00
/// is lunch for somebody who wakes at noon and a snack for somebody who
/// does not, and a night-shift worker's main meal at 03:00 is not a
/// snack. So there is no suggestion at all until the person's own
/// history has one, and the screen offers it rather than choosing it.
///
/// [history] holds past meals with the wall-clock time they were eaten
/// at, as lived.
MealType? suggestMealType(Iterable<(DateTime, MealType)> history, DateTime at) {
  final minute = at.hour * 60 + at.minute;
  final counts = <MealType, int>{};
  for (final (eatenAt, type) in history) {
    final distance = (eatenAt.hour * 60 + eatenAt.minute - minute).abs();
    // Around midnight, 23:30 and 00:30 are an hour apart, not 23.
    final wrapped = distance > 720 ? 1440 - distance : distance;
    if (wrapped <= mealTypeSuggestionWindow.inMinutes) {
      counts[type] = (counts[type] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  final ranked = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final best = ranked.first;
  if (best.value < mealTypeSuggestionMinimum) return null;
  // A tie is not a habit either: offering one of two would be a guess.
  if (ranked.length > 1 && ranked[1].value == best.value) return null;
  return best.key;
}
