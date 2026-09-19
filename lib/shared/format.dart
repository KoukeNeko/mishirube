const _secondsPerMinute = 60;
const _minutesPerHour = 60;

/// Formats a duration as `m:ss`, or `h:mm:ss` once it passes an hour.
String formatClock(Duration duration) {
  final safeDuration = duration.isNegative ? Duration.zero : duration;
  final hours = safeDuration.inHours;
  final minutes = safeDuration.inMinutes % _minutesPerHour;
  final seconds = safeDuration.inSeconds % _secondsPerMinute;
  final paddedSeconds = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$paddedSeconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
}

/// Drops the trailing `.0` so 100.0 reads as `100` but 77.5 stays `77.5`.
String formatWeight(double kilograms) {
  final isWholeNumber = kilograms == kilograms.roundToDouble();
  return isWholeNumber
      ? kilograms.toStringAsFixed(0)
      : kilograms.toStringAsFixed(1);
}

String formatTimeOfDay(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Adds thousands separators: 1180 → `1,180`.
String formatKcal(int kcal) {
  final digits = kcal.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
