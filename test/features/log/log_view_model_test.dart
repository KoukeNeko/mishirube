import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/features/log/log_view_model.dart';

import '../../support/harness.dart';

void main() {
  late Backend backend;
  late LogViewModel log;

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now);
    log = LogViewModel(backend);
  });

  tearDown(() {
    log.dispose();
    backend.close();
  });

  test('an empty log starts at this month', () {
    expect(log.earliestMonth, DateTime(2026, 9));
    expect(log.month(DateTime(2026, 9)).days, isEmpty);
  });

  test('a night recorded elsewhere shows in the month and opens as sleep', () {
    var notified = 0;
    log.addListener(() => notified++);

    backend.journal.recordSleep(const Duration(hours: 7));
    final month = log.month(DateTime(2026, 9));
    final id = month.days.single.entries.single.recordId!;
    expect(log.isSleep(id), isTrue);
    expect(notified, 1);

    backend.journal.recordNote('rest day');
    final noteId = log
        .month(DateTime(2026, 9))
        .days
        .expand((day) => day.entries)
        .map((entry) => entry.recordId)
        .firstWhere((entryId) => entryId != null && entryId != id)!;
    expect(log.isSleep(noteId), isFalse);
  });
}
