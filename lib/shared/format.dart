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
String formatAmount(double value) {
  final isWholeNumber = value == value.roundToDouble();
  return isWholeNumber ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

/// A weight in kilograms, written the way [formatAmount] writes numbers.
String formatWeight(double kilograms) => formatAmount(kilograms);

/// A length of sleep or rest as `h:mm`, where seconds would be noise.
String formatHoursMinutes(Duration duration) {
  final minutes = duration.inMinutes % _minutesPerHour;
  return '${duration.inHours}:${minutes.toString().padLeft(2, '0')}';
}

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// The weekday of [day] as one character, Monday first.
String weekdayLabel(DateTime day) => _weekdays[day.weekday - 1];

/// `2026/9/21`.
String formatDate(DateTime day) => '${day.year}/${day.month}/${day.day}';

String formatTimeOfDay(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Adds thousands separators: 1180 → `1,180`.
/// A calorie figure, or a dash when nobody wrote one down. The dash is
/// not a zero: it says the record has no number, not that the food had
/// none in it.
String formatKcalOrDash(int? kcal) => kcal == null ? '—' : formatKcal(kcal);

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
