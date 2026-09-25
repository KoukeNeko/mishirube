/// A night's samples in equal stretches, each its lowest and highest
/// value: the shape Apple Health draws a sleep's heart rate and
/// breathing in. Null for a stretch with no sample.
List<(double, double)?> rangeBins(
  List<(DateTime, double)> points,
  DateTime from,
  DateTime to, {
  int bins = defaultRangeBins,
}) {
  final span = to.difference(from).inMilliseconds;
  final ranges = List<(double, double)?>.filled(bins, null);
  if (span <= 0) return ranges;
  for (final (at, value) in points) {
    final offset = at.difference(from).inMilliseconds;
    if (offset < 0 || offset > span) continue;
    final bin = (offset * bins ~/ span).clamp(0, bins - 1);
    ranges[bin] = switch (ranges[bin]) {
      (final low, final high) => (
        value < low ? value : low,
        value > high ? value : high,
      ),
      null => (value, value),
    };
  }
  return ranges;
}

/// About half an hour each over a night of eight.
const defaultRangeBins = 16;
