import '../l10n/app_localizations.dart';

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

/// A distance in metres as kilometres, to two decimals with the trailing
/// zeros dropped: `2.4`, `5`, `0.35`.
String formatKilometers(double meters) {
  final text = (meters / 1000).toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// A length of time in words: `7 小時 45 分`, `45 分`, `8 小時`, so it
/// never reads as a time of day the way `7:45` does.
String formatDuration(AppLocalizations l10n, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % _minutesPerHour;
  if (hours == 0) return l10n.durationMinutes(minutes: minutes);
  if (minutes == 0) return l10n.hoursValue(hours: '$hours');
  return l10n.hoursMinutes(hours: hours, minutes: minutes);
}

/// [value] with its [unit] as the app writes them: `72.4 kg`, the value
/// alone without a unit, and `96%`, the percent sign against its number.
String withUnit(String value, String unit) => switch (unit) {
  '' => value,
  '%' => '$value%',
  _ => '$value $unit',
};

/// A length as `h:mm`, where there is no room for words.
String formatHoursMinutes(Duration duration) {
  final minutes = duration.inMinutes % _minutesPerHour;
  return '${duration.inHours}:${minutes.toString().padLeft(2, '0')}';
}

/// `07:10`: [minutes] after midnight as a time of day, past midnight
/// wrapping round to the next day's.
String formatMinutesOfDay(int minutes) {
  final clock = minutes % Duration.minutesPerDay;
  return '${(clock ~/ _minutesPerHour).toString().padLeft(2, '0')}:'
      '${(clock % _minutesPerHour).toString().padLeft(2, '0')}';
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
