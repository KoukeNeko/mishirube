import '../../domain/domain.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';

/// Body measurements and wellness check-ins.
class JournalService {
  JournalService(this._db, this._journal);

  final AppDatabase _db;
  final JournalRepository _journal;

  BodyWeight recordWeight(double kilograms, {String note = '', DateTime? at}) {
    final weight = BodyWeight(
      id: _db.newId(),
      measuredAt: at ?? _db.now(),
      weightKg: kilograms,
      note: note,
    );
    _journal.addWeight(weight);
    return weight;
  }

  /// Records one tape measurement. Each site is its own record, so a
  /// session where only the waist was measured says exactly that.
  BodyMeasurement recordMeasurement(
    MeasurementSite site,
    double centimetres, {
    String note = '',
    DateTime? at,
  }) {
    final measurement = BodyMeasurement(
      id: _db.newId(),
      measuredAt: at ?? _db.now(),
      site: site,
      centimetres: centimetres,
      note: note,
    );
    _journal.addMeasurement(measurement);
    return measurement;
  }

  /// The last measurement of each site.
  Map<MeasurementSite, BodyMeasurement> latestMeasurements() =>
      _journal.latestMeasurements();

  WellnessEntry recordWellness(
    WellnessKind kind,
    int score, {
    String note = '',
    DateTime? at,
  }) {
    final entry = WellnessEntry(
      id: _db.newId(),
      recordedAt: at ?? _db.now(),
      kind: kind,
      score: score,
      note: note,
    );
    _journal.addWellness(entry);
    return entry;
  }

  SleepEntry recordSleep(
    Duration slept, {
    int? score,
    String note = '',
    DateTime? at,
  }) {
    final entry = SleepEntry(
      id: _db.newId(),
      sleptAt: at ?? _db.now(),
      duration: slept,
      score: score,
      note: note,
    );
    _journal.addSleep(entry);
    return entry;
  }

  Note recordNote(String text, {DateTime? at}) {
    final note = Note(id: _db.newId(), notedAt: at ?? _db.now(), text: text);
    _journal.addNote(note);
    return note;
  }

  void updateNote(Note note) => _journal.updateNote(note);

  /// A live journal record by id, or null when there is none.
  Object? entry(String id) => _journal.byId(id);

  ChangeSource? sourceOf(String id) => _journal.sourceOf(id);

  void updateWeight(BodyWeight weight) => _journal.updateWeight(weight);

  void updateMeasurement(BodyMeasurement measurement) =>
      _journal.updateMeasurement(measurement);

  void updateSleep(SleepEntry entry) => _journal.updateSleep(entry);

  void updateWellness(WellnessEntry entry) => _journal.updateWellness(entry);

  void delete(String id) => _journal.delete(id);

  void restore(String id) => _journal.restore(id);

  /// Weights measured in the [window] ending now, oldest first.
  List<BodyWeight> recentWeights(Duration window) =>
      _journal.weightsBetween(_db.now().subtract(window), _db.nowInclusive);

  List<WellnessEntry> recentWellness(Duration window) =>
      _journal.wellnessBetween(_db.now().subtract(window), _db.nowInclusive);

  List<SleepEntry> recentSleep(Duration window) =>
      _journal.sleepBetween(_db.now().subtract(window), _db.nowInclusive);
}
