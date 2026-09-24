import '../../domain/domain.dart';
import '../engines/sleep_nights.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';

/// One sleep as the sleep page shows it.
class SleepRecord {
  const SleepRecord({
    required this.entry,
    required this.origin,
    required this.stages,
    required this.sources,
    required this.shownSource,
    required this.readings,
  });

  final SleepEntry entry;

  /// How the record reached the log: typed in here, or read from a
  /// health platform.
  final ChangeSource origin;

  /// The shown source's stretches, in time order, "in bed" left out when
  /// it recorded anything more specific. Empty for a length typed in.
  final List<SleepSample> stages;

  /// Every source that recorded this sleep.
  final List<SleepSummary> sources;

  /// The source [entry]'s figures come from; null for a length typed in.
  final SleepSummary? shownSource;

  final List<OvernightReading> readings;

  /// Whether the source staged the sleep, so there is a chart to draw.
  bool get hasStages => stages.any((stage) => stage.stage.isDetailed);

  bool get isTypedIn => origin == ChangeSource.local;
}

/// The sleep page's reads, and the one choice it makes: which source a
/// sleep is shown from.
class SleepService {
  SleepService(this._db, this._journal);

  final AppDatabase _db;
  final JournalRepository _journal;

  /// The sleeps logged against [day]: its night first, then its naps.
  List<SleepRecord> day(DateTime day) {
    final entries = _journal.sleepOn(day)
      ..sort((a, b) {
        if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
        return a.sleptAt.compareTo(b.sleptAt);
      });
    return [for (final entry in entries) _recordOf(entry)];
  }

  /// The latest night, when it ended today or yesterday; older than that
  /// it is not last night.
  SleepRecord? lastNight() {
    final start = today.subtract(const Duration(days: 1));
    final night = nights(start, _db.nowInclusive).lastOrNull;
    return night == null ? null : _recordOf(night);
  }

  /// Nights (not naps) that ended in `[start, end)`, oldest first.
  List<SleepEntry> nights(DateTime start, DateTime end) => [
    for (final entry in _journal.sleepBetween(start, end))
      if (entry.kind == SleepKind.night) entry,
  ];

  /// Shows [id] from [source], which must have recorded it. The choice is
  /// kept, so reading the platform again keeps showing that source.
  void chooseSource(String id, String source) {
    final row = _journal.sleepRow(id);
    if (row == null || row.isDeleted) return;
    final samples = _journal.sleepSegments(id);
    if (!samples.any((sample) => sample.source == source)) return;
    final summary = summarize(samples, source: source)!;
    final entry = row.entry;
    _journal.resyncSleep(
      SleepEntry(
        id: id,
        sleptAt: summary.end,
        duration: Duration(minutes: summary.length.inMinutes),
        score: entry.score,
        note: entry.note,
        startedAt: summary.start,
        kind: entry.kind,
        measure: summary.measure,
        sourceName: summary.sourceName,
      ),
      source: ChangeSource.local,
      chosenSource: source,
    );
  }

  SleepRecord _recordOf(SleepEntry entry) {
    final samples = _journal.sleepSegments(entry.id);
    final origin = _journal.sourceOf(entry.id) ?? ChangeSource.local;
    final shown = samples.isEmpty
        ? null
        : summarize(samples, source: _journal.chosenSleepSource(entry.id));
    return SleepRecord(
      entry: entry,
      origin: origin,
      stages: shown == null ? const [] : stagesOf(samples, shown.source),
      sources: sourcesOf(samples),
      shownSource: shown,
      readings: _journal.sleepReadings(entry.id),
    );
  }

  /// Today, for a page that opens on the latest night.
  DateTime get today {
    final now = _db.now();
    return DateTime(now.year, now.month, now.day);
  }
}
