import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/trends/trends_view_model.dart';

import '../../support/harness.dart';

void main() {
  late Backend backend;
  late TrendsViewModel trends;

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now);
    trends = TrendsViewModel(backend);
  });

  tearDown(() {
    trends.dispose();
    backend.close();
  });

  test('the muscle figure is stored and rebuilds the card', () {
    var notified = 0;
    trends.addListener(() => notified++);

    trends.setMuscleFigure(MuscleFigure.female);

    expect(trends.muscleFigure, MuscleFigure.female);
    expect(notified, 1);
  });

  test('a night recorded elsewhere reaches the average', () {
    const week = Duration(days: 7);
    expect(trends.overview(week).averageSleep, isNull);
    backend.journal.recordSleep(const Duration(hours: 7));
    expect(trends.overview(week).averageSleep, const Duration(hours: 7));
  });
}
