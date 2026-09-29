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

String formatTimeOfDay(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// A calorie figure, or a dash when nobody wrote one down. The dash is
/// not a zero: it says the record has no number, not that the food had
/// none in it.
String formatKcalOrDash(num? kcal) => kcal == null ? '—' : formatKcal(kcal);

/// Adds thousands separators: 1180 → `1,180`. A figure a label or a
/// model gave with a decimal keeps it — 55.5 kcal is what the label
/// says — and a whole one is written as it is.
String formatKcal(num kcal) {
  final isWholeNumber = kcal == kcal.roundToDouble();
  final written = isWholeNumber
      ? kcal.round().toString()
      : kcal.toStringAsFixed(1);
  final sign = written.startsWith('-') ? '-' : '';
  final body = sign.isEmpty ? written : written.substring(1);
  final point = body.indexOf('.');
  final digits = point < 0 ? body : body.substring(0, point);
  final decimals = point < 0 ? '' : body.substring(point);
  final buffer = StringBuffer(sign);
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer$decimals';
}
