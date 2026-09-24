import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/engines/figure_reader.dart';
import 'package:mishirube/domain/domain.dart';

void main() {
  test('a scale app screen gives each figure it names', () {
    const screen = '''
體重  72.4  kg
BMI  23.6
體脂率  18.2  %
體脂肪量  13.2  kg
骨骼肌量  33.1  kg
肌肉量  56.8 kg
除脂體重  59.2  kg
內臟脂肪等級  7
體水分率  56.3 %
骨量  3.1 kg
基礎代謝  1650  kcal''';
    expect(readBodyFigures(screen), {
      BodyMetric.bodyFat: 18.2,
      BodyMetric.skeletalMuscle: 33.1,
      BodyMetric.muscleMass: 56.8,
      BodyMetric.leanMass: 59.2,
      BodyMetric.visceralFat: 7,
      BodyMetric.bodyWater: 56.3,
      BodyMetric.boneMass: 3.1,
      BodyMetric.basalMetabolicRate: 1650,
    });
  });

  test('a value under its label is read, and a wrong unit is not', () {
    const sheet = '''
Skeletal Muscle Mass (SMM)
33.1 kg
Body Fat
12.9 kg
PBF 18.2%''';
    expect(readBodyFigures(sheet), {
      BodyMetric.skeletalMuscle: 33.1,
      BodyMetric.bodyFat: 18.2,
    }, reason: 'fat mass in kg is not a body fat percentage');
  });

  test('tape measurements are read in centimetres', () {
    const note = '腰圍 82.5 cm\n臀圍：96\n大腿  55,5 公分\n體重 72 kg';
    expect(readGirths(note), {
      MeasurementSite.waist: 82.5,
      MeasurementSite.hips: 96,
      MeasurementSite.thigh: 55.5,
    });
  });

  test('nothing named is nothing read', () {
    expect(readBodyFigures('今天天氣很好 25 度'), isEmpty);
  });
}
