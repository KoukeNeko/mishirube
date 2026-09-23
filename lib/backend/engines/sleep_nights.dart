import '../../domain/domain.dart';

/// Bumped whenever the rules below change.
const sleepNightsVersion = 2;

/// Stretches of one source this far apart or closer belong to one sleep:
/// waking in the night leaves a gap, not a second sleep.
const _sameSleepGap = Duration(hours: 1);

/// What one source says about a sleep.
class SleepSummary {
  const SleepSummary({
    required this.source,
    required this.sourceName,
    required this.measure,
    required this.start,
    required this.end,
    required this.length,
    required this.hasStages,
    required this.isManual,
  });

  final String source;
  final String sourceName;

  /// Time asleep when the source says when it was asleep, time in bed
  /// when that is all it knows.
  final SleepMeasure measure;

  /// From the first stretch measured to the last.
  final DateTime start;
  final DateTime end;
  final Duration length;

  /// Whether the source staged the sleep (core, deep, REM).
  final bool hasStages;
  final bool isManual;
}

/// One sleep as the log keeps it: the day it belongs to, whether it is
/// that day's main sleep or a nap, the figures from the source it is
/// shown from, and every source's stretches.
class NightOfSleep {
  const NightOfSleep({
    required this.morning,
    required this.kind,
    required this.summary,
    required this.samples,
  });

  /// Midnight of the day the sleep is logged against.
  final DateTime morning;
  final SleepKind kind;
  final SleepSummary summary;

  /// Every source's stretches for this sleep, so another can be chosen
  /// later without reading the platform again.
  final List<SleepSample> samples;

  DateTime get wokeAt => summary.end;
  Duration get asleep => summary.length;
}

/// Turns a platform's sleep samples into sleeps.
///
/// Each source's stretches are grouped into sleeps on their own, then
/// sleeps from different sources that overlap are taken to be the same
/// one. A sleep's figures come from one source, never stitched together
/// from several: two algorithms do not agree stretch by stretch, and a
/// watch and a phone both saying 23:00 to 07:00 is eight hours, not
/// sixteen. See [summarize] for which source that is.
///
/// A sleep belongs to the day whose 18:00-to-18:00 window it starts in,
/// named after the morning inside it, so going to bed after midnight
/// stays with that day. A day's longest sleep is its night; any other is
/// a nap, kept apart rather than added to the night.
List<NightOfSleep> nightsOf(Iterable<SleepSample> samples) {
  final byDay = <DateTime, List<(SleepSummary, List<SleepSample>)>>{};
  for (final cluster in _clusters(samples)) {
    final summary = summarize(cluster);
    if (summary == null) continue;
    final shifted = summary.start.add(const Duration(hours: 6));
    final morning = DateTime(shifted.year, shifted.month, shifted.day);
    (byDay[morning] ??= []).add((summary, cluster));
  }
  final nights = <NightOfSleep>[];
  for (final MapEntry(key: morning, value: sleeps) in byDay.entries) {
    final longest = sleeps.reduce((a, b) => b.$1.length > a.$1.length ? b : a);
    for (final (summary, cluster) in sleeps) {
      nights.add(
        NightOfSleep(
          morning: morning,
          kind: identical(summary, longest.$1)
              ? SleepKind.night
              : SleepKind.nap,
          summary: summary,
          samples: cluster,
        ),
      );
    }
  }
  return nights..sort((a, b) => a.summary.start.compareTo(b.summary.start));
}

/// What [source] says about a sleep recorded in [samples], or, with no
/// source given or when it recorded nothing here, the best source: one
/// that staged the sleep, then one that knew when it was asleep, then
/// the one that measured longest. Null when no source measured anything.
SleepSummary? summarize(Iterable<SleepSample> samples, {String? source}) {
  final bySource = <String, List<SleepSample>>{};
  for (final sample in samples) {
    if (sample.end.isAfter(sample.start)) {
      (bySource[sample.source] ??= []).add(sample);
    }
  }
  final summaries = [
    for (final MapEntry(key: key, value: own) in bySource.entries)
      ?_summaryOf(key, own),
  ];
  if (summaries.isEmpty) return null;
  if (source != null) {
    for (final summary in summaries) {
      if (summary.source == source) return summary;
    }
  }
  int rank(SleepSummary summary) => summary.hasStages
      ? 2
      : summary.measure == SleepMeasure.asleep
      ? 1
      : 0;
  return summaries.reduce((a, b) {
    if (rank(a) != rank(b)) return rank(b) > rank(a) ? b : a;
    return b.length > a.length ? b : a;
  });
}

/// The stretches [source] recorded in [samples], in time order, with
/// "in bed" left out when it recorded anything more specific.
List<SleepSample> stagesOf(Iterable<SleepSample> samples, String source) {
  final own = [
    for (final sample in samples)
      if (sample.source == source && sample.end.isAfter(sample.start)) sample,
  ]..sort((a, b) => a.start.compareTo(b.start));
  final specific = [
    for (final sample in own)
      if (sample.stage != SleepStage.inBed) sample,
  ];
  return specific.isEmpty ? own : specific;
}

SleepSummary? _summaryOf(String source, List<SleepSample> own) {
  final asleep = _union([
    for (final sample in own)
      if (sample.stage.isAsleep) sample,
  ]);
  final measure = asleep.isEmpty ? SleepMeasure.inBed : SleepMeasure.asleep;
  final spans = asleep.isEmpty
      ? _union([
          for (final sample in own)
            if (sample.stage == SleepStage.inBed) sample,
        ])
      : asleep;
  if (spans.isEmpty) return null;
  final named = own.firstWhere(
    (sample) => sample.sourceName.isNotEmpty,
    orElse: () => own.first,
  );
  return SleepSummary(
    source: source,
    sourceName: named.sourceName,
    measure: measure,
    start: spans.first.$1,
    end: spans.last.$2,
    length: spans.fold(
      Duration.zero,
      (sum, span) => sum + span.$2.difference(span.$1),
    ),
    hasStages: own.any((sample) => sample.stage.isDetailed),
    isManual: own.every((sample) => sample.isManual),
  );
}

/// Overlapping stretches merged, oldest first.
List<(DateTime, DateTime)> _union(List<SleepSample> samples) {
  final sorted = [...samples]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <(DateTime, DateTime)>[];
  for (final sample in sorted) {
    if (merged.isNotEmpty && !sample.start.isAfter(merged.last.$2)) {
      final (start, end) = merged.removeLast();
      merged.add((start, sample.end.isAfter(end) ? sample.end : end));
    } else {
      merged.add((sample.start, sample.end));
    }
  }
  return merged;
}

/// The samples grouped into sleeps: each source's stretches joined across
/// short gaps, then the groups of different sources that overlap joined.
List<List<SleepSample>> _clusters(Iterable<SleepSample> samples) {
  final bySource = <String, List<SleepSample>>{};
  for (final sample in samples) {
    if (sample.end.isAfter(sample.start)) {
      (bySource[sample.source] ??= []).add(sample);
    }
  }
  final episodes = <(DateTime, DateTime, List<SleepSample>)>[];
  for (final own in bySource.values) {
    own.sort((a, b) => a.start.compareTo(b.start));
    for (final sample in own) {
      if (episodes.isNotEmpty &&
          episodes.last.$3.first.source == sample.source &&
          !sample.start.isAfter(episodes.last.$2.add(_sameSleepGap))) {
        final (start, end, members) = episodes.removeLast();
        episodes.add((
          start,
          sample.end.isAfter(end) ? sample.end : end,
          members..add(sample),
        ));
      } else {
        episodes.add((sample.start, sample.end, [sample]));
      }
    }
  }
  episodes.sort((a, b) => a.$1.compareTo(b.$1));
  final clusters = <(DateTime, List<SleepSample>)>[];
  for (final (start, end, members) in episodes) {
    if (clusters.isNotEmpty && start.isBefore(clusters.last.$1)) {
      final (clusterEnd, clusterMembers) = clusters.removeLast();
      clusters.add((
        end.isAfter(clusterEnd) ? end : clusterEnd,
        clusterMembers..addAll(members),
      ));
    } else {
      clusters.add((end, [...members]));
    }
  }
  return [for (final (_, members) in clusters) members];
}

/// Time in each stage across [stages], in stage order, leaving out the
/// stages with none.
Map<SleepStage, Duration> stageTotals(Iterable<SleepSample> stages) {
  final totals = <SleepStage, Duration>{};
  for (final sample in stages) {
    totals.update(
      sample.stage,
      (total) => total + sample.length,
      ifAbsent: () => sample.length,
    );
  }
  return {
    for (final stage in SleepStage.values)
      if (totals[stage] case final total? when total > Duration.zero)
        stage: total,
  };
}

/// Every source that recorded [samples], each as it would be shown.
List<SleepSummary> sourcesOf(Iterable<SleepSample> samples) => [
  for (final source in {for (final sample in samples) sample.source})
    ?summarize([
      for (final sample in samples)
        if (sample.source == source) sample,
    ]),
]..sort((a, b) => a.start.compareTo(b.start));
