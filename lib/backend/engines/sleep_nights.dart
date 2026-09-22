import '../../domain/domain.dart';

/// Bumped whenever the rules below change.
const sleepNightsVersion = 1;

/// A night as the log keeps it: the morning it belongs to, when the
/// sleeper last woke, and how long they were actually asleep.
class NightOfSleep {
  const NightOfSleep({
    required this.morning,
    required this.wokeAt,
    required this.asleep,
  });

  /// Midnight of the day the night is logged against.
  final DateTime morning;
  final DateTime wokeAt;
  final Duration asleep;
}

/// Turns a platform's sleep samples into nights.
///
/// Only time asleep counts — time in bed and awake does not. Two devices
/// recording the same night overlap, so asleep time is the union of the
/// stretches, never their sum: a watch and a phone both saying 23:00 to
/// 07:00 is eight hours, not sixteen.
///
/// A stretch belongs to the night whose 18:00-to-18:00 window it starts
/// in, named after the morning inside it, so going to bed after midnight
/// or napping in the afternoon stays with that day.
List<NightOfSleep> nightsOf(Iterable<SleepSample> samples) {
  final asleep = [
    for (final sample in samples)
      if (sample.stage == SleepStage.asleep && sample.end.isAfter(sample.start))
        sample,
  ]..sort((a, b) => a.start.compareTo(b.start));

  // Overlapping stretches merged into one, oldest first.
  final merged = <(DateTime, DateTime)>[];
  for (final sample in asleep) {
    if (merged.isNotEmpty && !sample.start.isAfter(merged.last.$2)) {
      final (start, end) = merged.removeLast();
      merged.add((start, sample.end.isAfter(end) ? sample.end : end));
    } else {
      merged.add((sample.start, sample.end));
    }
  }

  final nights = <DateTime, (DateTime, Duration)>{};
  for (final (start, end) in merged) {
    final shifted = start.add(const Duration(hours: 6));
    final morning = DateTime(shifted.year, shifted.month, shifted.day);
    final (wokeAt, total) = nights[morning] ?? (end, Duration.zero);
    nights[morning] = (
      end.isAfter(wokeAt) ? end : wokeAt,
      total + end.difference(start),
    );
  }
  return [
    for (final MapEntry(key: morning, value: (wokeAt, total)) in nights.entries)
      NightOfSleep(morning: morning, wokeAt: wokeAt, asleep: total),
  ]..sort((a, b) => a.morning.compareTo(b.morning));
}
