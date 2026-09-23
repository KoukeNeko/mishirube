import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
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
}
