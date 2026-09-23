import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/activity/activity_view_model.dart';

import '../../support/harness.dart';

void main() {
  late FakeClock clock;
  late Backend backend;
  late ActivityViewModel activities;

  setUp(() {
    clock = FakeClock();
    backend = Backend.inMemory(clock: clock.now);
    activities = ActivityViewModel(backend);
  });

  tearDown(() {
    activities.dispose();
    backend.close();
  });

  test('logging, correcting and removing each rebuild the screen', () {
    var notified = 0;
    activities.addListener(() => notified++);

    final logged = activities.log(
      type: ActivityTypes.running,
      startedAt: clock.now(),
      duration: const Duration(minutes: 30),
    );
    expect(activities.recentTypes.first, ActivityTypes.running);

    activities.update(
      ActivitySession(
        id: logged.id,
        type: ActivityTypes.cycling,
        startedAt: logged.startedAt,
        duration: const Duration(minutes: 45),
      ),
    );
    expect(activities.byId(logged.id)?.type, ActivityTypes.cycling);

    activities.delete(logged.id);
    expect(activities.byId(logged.id), isNull);
    activities.restore(logged.id);
    expect(activities.byId(logged.id), isNotNull);
    expect(notified, 4, reason: 'one per write');
  });
}
