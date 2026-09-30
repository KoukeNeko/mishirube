/// The gist of an area's latest stretch in words a reader takes in at a
/// glance (see `research/78-plain-summaries.md`): where it sits against
/// the person's own usual range, and by how much against the stretch
/// before, as an absolute amount. The words come from the same usual
/// range the chart draws, never from a threshold of their own, and with
/// too few records the gist says so rather than comparing.
library;

import 'trend_detail.dart';

/// Where the latest stretch sits against the usual range.
enum GistPosition { usual, above, below }

class TrendGist {
  const TrendGist({
    required this.position,
    required this.difference,
    required this.covered,
    required this.span,
    required this.isEnough,
  });

  /// Null when there are too few weeks for a usual range to judge by.
  final GistPosition? position;

  /// The latest stretch less the one before, in the area's own units a
  /// day (or a week, for a count); null without both.
  final double? difference;

  /// Days of the latest stretch with a record, out of [span].
  final int covered;
  final int span;

  /// Whether the latest stretch has records enough to compare at all.
  final bool isEnough;
}

/// [detail]'s gist, reading its latest [recentWeeks]. Below
/// [minimumDays] days with a record in them it does not compare.
TrendGist trendGist(
  TrendDetail detail, {
  required int recentWeeks,
  required int minimumDays,
}) {
  final covered = detail.daysWithRecords.reversed
      .take(recentWeeks)
      .fold(0, (sum, days) => sum + days);
  final span = recentWeeks * DateTime.daysPerWeek;
  final recent = detail.recent;
  final isEnough = recent != null && covered >= minimumDays;
  if (!isEnough) {
    return TrendGist(
      position: null,
      difference: null,
      covered: covered,
      span: span,
      isEnough: false,
    );
  }
  final baseline = detail.baseline;
  return TrendGist(
    position: switch (detail.normal) {
      (final low, _) when recent.value < low => GistPosition.below,
      (_, final high) when recent.value > high => GistPosition.above,
      (_, _) => GistPosition.usual,
      null => null,
    },
    difference: baseline == null ? null : recent.value - baseline.value,
    covered: covered,
    span: span,
    isEnough: true,
  );
}

/// A body weight trend's gist over its latest [recentWeeks]: steady
/// below [steadyKgPerWeek] a week either way, else how far it moved.
({GistPosition position, double change})? weightGist(
  TrendDetail detail, {
  required int recentWeeks,
  required double steadyKgPerWeek,
}) {
  final values = detail.values;
  final from = values.length - recentWeeks;
  if (from < 0) return null;
  final first = values.indexWhere((value) => value != null, from);
  final last = values.lastIndexWhere((value) => value != null);
  if (first < 0 || last <= first) return null;
  final change = values[last]! - values[first]!;
  final perWeek = change / (last - first);
  return (
    position: perWeek.abs() < steadyKgPerWeek
        ? GistPosition.usual
        : (change > 0 ? GistPosition.above : GistPosition.below),
    change: change,
  );
}
