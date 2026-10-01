/// What is usual for this person: the lowest to the highest of their own
/// earlier days, never a population norm, one rule for every reading
/// the app sets against a usual range (see
/// `research/85-normal-ranges-and-google-health-gaps.md`).
///
/// The lowest to the highest, not a middle half or a mean give or take a
/// deviation: the app diagnoses nothing, so a day marked apart from the
/// usual should be rare. Of n interchangeable days a new one falls
/// outside their lowest and highest with a chance of 2/(n + 1), some 7%
/// over four weeks, whatever shape the figure's spread has; a middle half
/// leaves half of all ordinary days outside.
library;

/// The days a usual range is drawn from, before the day it is for.
const usualRangeWindow = Duration(days: 28);

/// Days with a figure the window needs before it says what is usual: a
/// day then has at most a 13% chance of falling outside by chance.
const usualRangeMinimumDays = 14;

/// For a figure read week by week: the weeks before the latest stretch
/// the range is drawn from, and how many of them need a figure.
const weeklyUsualRangeWeeks = 26;
const weeklyUsualRangeMinimumWeeks = 13;
const weeklyUsualRangeWindow = Duration(
  days: weeklyUsualRangeWeeks * DateTime.daysPerWeek,
);

typedef UsualRange = ({double low, double high});

/// The lowest to the highest of [values]; null with fewer than [minimum]
/// of them.
UsualRange? usualRangeOf(
  Iterable<double> values, {
  int minimum = usualRangeMinimumDays,
}) {
  final list = values.toList();
  if (list.length < minimum) return null;
  var low = list.first;
  var high = list.first;
  for (final value in list) {
    if (value < low) low = value;
    if (value > high) high = value;
  }
  return (low: low, high: high);
}

/// The usual range for [day] from [days] in the [window] before it, the
/// day itself left out: a day read against itself would always fit.
UsualRange? usualRangeBefore(
  List<(DateTime, double)> days,
  DateTime day, {
  Duration window = usualRangeWindow,
  int minimum = usualRangeMinimumDays,
}) {
  final start = DateTime(day.year, day.month, day.day).subtract(window);
  final end = DateTime(day.year, day.month, day.day);
  return usualRangeOf([
    for (final (other, value) in days)
      if (!other.isBefore(start) && other.isBefore(end)) value,
  ], minimum: minimum);
}

/// For each of [days] (oldest first), its usual range from the days
/// before it: a range that moves with the days, so a lasting change is
/// taken in within the window rather than marked for ever.
List<UsualRange?> rollingUsualRanges(
  List<(DateTime, double)> days, {
  Duration window = usualRangeWindow,
  int minimum = usualRangeMinimumDays,
}) => [
  for (final (day, _) in days)
    usualRangeBefore(days, day, window: window, minimum: minimum),
];

/// Where a value sits against its usual range; on an edge is within.
enum UsualPosition { below, within, above }

UsualPosition? positionIn(double value, UsualRange? range) => switch (range) {
  null => null,
  (:final low, high: _) when value < low => UsualPosition.below,
  (low: _, :final high) when value > high => UsualPosition.above,
  _ => UsualPosition.within,
};
