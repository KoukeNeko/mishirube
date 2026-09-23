import 'package:flutter_test/flutter_test.dart';
import 'package:mishirube/backend/backend.dart';
import 'package:mishirube/domain/domain.dart';
import 'package:mishirube/features/journal/journal_view_model.dart';

import '../../support/harness.dart';

void main() {
  late Backend backend;
  late JournalViewModel journal;

  setUp(() {
    backend = Backend.inMemory(clock: FakeClock().now);
    journal = JournalViewModel(backend);
  });

  tearDown(() {
    journal.dispose();
    backend.close();
  });

  test('a weight typed in reads back as typed in, and can be taken back', () {
    var notified = 0;
    journal.addListener(() => notified++);

    journal.recordWeight(72.4);
    final weight = journal.recentWeights.single;
    expect(weight.weightKg, 72.4);
    expect(journal.sourceLabel(weight.id), '手動輸入');
    expect(notified, 1);

    journal.delete(weight.id);
    expect(journal.entry(weight.id), isNull);
    expect(journal.recentWeights, isEmpty);

    journal.restore(weight.id);
    expect(journal.entry(weight.id), isA<BodyWeight>());
    expect(notified, 3, reason: 'one per write');
  });
}
