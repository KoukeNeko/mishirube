import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/backend/storage/database.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/sleep/sleep_view_model.dart';

import '../../support/harness.dart';

void main() {
  late Backend backend;
  late SleepViewModel model;

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now);
    model = SleepViewModel(backend);
  });

  tearDown(() {
    model.dispose();
    backend.close();
  });

  test('opens on today and never steps past it', () {
    final today = model.day;
    expect(model.canGoForward, isFalse);

    model.step(1);
    expect(model.day, today, reason: 'tomorrow has no sleep yet');

    model.step(-1);
    expect(model.day, DateTime(today.year, today.month, today.day - 1));
    expect(model.canGoForward, isTrue);
  });

  test('a night recorded anywhere shows without being told', () {
    var notified = 0;
    model.addListener(() => notified++);

    // Written straight to the backend, as another screen would.
    backend.journal.recordSleep(const Duration(hours: 7));

    expect(notified, greaterThan(0));
    expect(model.night?.entry.duration, const Duration(hours: 7));
    expect(model.night!.isTypedIn, isTrue);
  });

  test('history counts nights asleep, not naps', () {
    backend.journal.recordSleep(const Duration(hours: 7));
    expect(model.nightsAsleep(7), hasLength(1));
    expect(model.nightsAsleep(7).single.kind, SleepKind.night);
  });

  test('a goal is kept, and the week is read against it', () {
    expect(model.goal, isNull);
    expect(model.weekShortfall, isNull, reason: 'no goal, no shortfall');

    final now = backend.db.now();
    for (var night = 0; night < 3; night++) {
      final woke = DateTime(now.year, now.month, now.day - night, 7);
      backend.journal.recordSleep(
        const Duration(hours: 7),
        at: woke,
        startedAt: woke.subtract(const Duration(hours: 7)),
      );
    }
    model.setGoal(const Duration(hours: 8));

    expect(model.goal, const Duration(hours: 8));
    expect(model.weekShortfall, const Duration(hours: 3));
    final plan = model.tonightPlan!;
    expect(plan.wake.hour, 7, reason: 'the usual waking');
    expect(plan.wake.difference(plan.bedtime), const Duration(hours: 8));

    model.setGoal(null);
    expect(model.goal, isNull);
  });

  test('a night that was staged says how it held together', () {
    final woke = backend.db.now();
    final start = woke.subtract(const Duration(hours: 8));
    SleepSample stretch(SleepStage stage, int from, int to) => SleepSample(
      start: start.add(Duration(minutes: from)),
      end: start.add(Duration(minutes: to)),
      stage: stage,
      source: 'watch',
    );
    backend.storage.journal
      ..addSleep(
        SleepEntry(
          id: 'night',
          sleptAt: woke,
          duration: const Duration(hours: 7),
          startedAt: start,
        ),
        source: ChangeSource.healthKit,
      )
      ..replaceSleepSegments('night', [
        stretch(SleepStage.inBed, 0, 480),
        stretch(SleepStage.core, 15, 200),
        stretch(SleepStage.awake, 200, 215),
        stretch(SleepStage.deep, 215, 470),
      ], source: ChangeSource.healthKit);

    final continuity = model.night!.continuity!;
    expect(continuity.latency, const Duration(minutes: 15));
    expect(continuity.awakenings, 1);
    expect(continuity.efficiency, closeTo(440 / 480, 0.001));
  });

  test('the usual night is the four weeks before, not the day itself', () {
    final now = backend.db.now();
    for (final (days, hours) in [(1, 6), (2, 8), (0, 9)]) {
      backend.journal.recordSleep(
        Duration(hours: hours),
        at: DateTime(now.year, now.month, now.day - days, 7),
      );
    }
    expect(model.usualNight, const Duration(hours: 7));
  });
}
