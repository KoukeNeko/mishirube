import '../../domain/domain.dart';

/// Bumped whenever a rule below changes.
const figureReaderVersion = 1;

/// What each body figure is printed as on a scale's screen, its app or a
/// body composition sheet, most specific first: a line is read as the
/// first name it contains, so 「骨骼肌量」 is tried before 「肌肉量」 could
/// match inside something longer.
const bodyMetricNames = {
  BodyMetric.height: ['身高', 'height'],
  BodyMetric.bodyFat: ['體脂肪率', '體脂率', '脂肪率', 'pbf', 'body fat'],
  BodyMetric.skeletalMuscle: ['骨骼肌量', '骨骼肌重', '骨骼肌', 'smm', 'skeletal muscle'],
  BodyMetric.leanMass: [
    '除脂體重',
    '去脂體重',
    '瘦體重',
    'ffm',
    'fat free mass',
    'lean body mass',
  ],
  BodyMetric.muscleMass: ['肌肉量', '肌肉重', 'muscle mass'],
  BodyMetric.visceralFat: ['內臟脂肪等級', '內臟脂肪', 'visceral fat'],
  BodyMetric.bodyWater: ['體水分率', '身體水分率', '水分率', '體水分', 'body water'],
  BodyMetric.boneMass: ['骨礦物質', '骨鹽量', '骨量', 'bone mass'],
  BodyMetric.basalMetabolicRate: ['基礎代謝率', '基礎代謝', 'bmr'],
};

/// What each tape site is written as.
const girthNames = {
  MeasurementSite.waist: ['腰圍', 'waist'],
  MeasurementSite.hips: ['臀圍', 'hip'],
  MeasurementSite.chest: ['胸圍', 'chest'],
  MeasurementSite.arm: ['上臂', '手臂', 'arm'],
  MeasurementSite.thigh: ['大腿', 'thigh'],
  MeasurementSite.calf: ['小腿', 'calf'],
  MeasurementSite.neck: ['頸圍', 'neck'],
};

/// A figure as it was read, with the unit printed beside it when there
/// was one.
final _number = RegExp(r'(\d+(?:[.,]\d+)?)\s*(%|kg|cm|kcal|公斤|公分|大卡)?');

/// Figures read off [text], one line of a photo per line: each line that
/// names one of [names] gives the first number after the name on that
/// line, or failing that the first number on the next line, where a
/// screen puts a value under its label. [rejects] refuses a value with
/// a unit that does not belong to the figure, such as a fat mass in kg
/// read where a percentage was meant. The first reading of each figure
/// wins; the rest of the page is usually a history of older ones.
Map<K, double> readFigures<K>(
  String text,
  Map<K, List<String>> names, {
  bool Function(K key, String? unit)? rejects,
}) {
  final lines = text.split('\n');
  final found = <K, double>{};
  for (final (index, line) in lines.indexed) {
    final lower = line.toLowerCase();
    for (final MapEntry(key: key, value: aliases) in names.entries) {
      if (found.containsKey(key)) continue;
      final at = [
        for (final alias in aliases)
          if (lower.indexOf(alias) case final position when position >= 0)
            (position, alias),
      ].firstOrNull;
      if (at == null) continue;
      final (position, alias) = at;
      final rest = line.substring(position + alias.length);
      final match =
          _number.firstMatch(rest) ??
          (index + 1 < lines.length
              ? _number.firstMatch(lines[index + 1])
              : null);
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (value == null || (rejects?.call(key, match.group(2)) ?? false)) {
        continue;
      }
      found[key] = value;
      break;
    }
  }
  return found;
}

/// A body composition reading off a photo: percentages only where a
/// percentage belongs, masses only where a mass does.
Map<BodyMetric, double> readBodyFigures(String text) => readFigures(
  text,
  bodyMetricNames,
  rejects: (metric, unit) => switch (metric.unit) {
    '%' => unit != null && unit != '%',
    'kg' => unit == '%',
    _ => false,
  },
);

/// Tape measurements off a photo, in centimetres.
Map<MeasurementSite, double> readGirths(String text) => readFigures(
  text,
  girthNames,
  rejects: (_, unit) => unit == '%' || unit == 'kg' || unit == '公斤',
);
