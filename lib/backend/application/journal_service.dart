import '../../domain/domain.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';

/// Body measurements and wellness check-ins.
class JournalService {
  JournalService(this._db, this._journal);

  static const _birthYearKey = 'profile.birth_year';
  static const _sexKey = 'profile.sex';

  /// Sex as the energy equations take it; null until the user says.
  Sex? get sex => Sex.values.asNameMap()[_db.setting(_sexKey)];

  void setSex(Sex? sex) => _db.setSetting(_sexKey, sex?.name ?? '');

  /// The last weighing on or before [day].
  BodyWeight? weightOn(DateTime day) =>
      _journal.latestWeightBefore(DateTime(day.year, day.month, day.day + 1));

  /// The latest height recorded.
  double? get heightCm =>
      _journal.latestBodyReadings()[BodyMetric.height]?.value;

  /// The year the user was born, as they gave it; null until then.
  int? get birthYear => int.tryParse(_db.setting(_birthYearKey) ?? '');

  void setBirthYear(int? year) =>
      _db.setSetting(_birthYearKey, year == null ? '' : '$year');

  /// Roughly how old the user is on [day], from [birthYear]: what goes by
  /// age, such as heart rate zones, needs no closer than the year.
  int? ageOn(DateTime day) => switch (birthYear) {
    final year? => day.year - year,
    null => null,
  };

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
  /// Readings taken together, as a scale gives them: one row per figure,
  /// all at [at].
  List<BodyReading> recordBodyReadings(
    Map<BodyMetric, double> values, {
    DateTime? at,
  }) {
    final measuredAt = at ?? _db.now();
    final readings = [
      for (final MapEntry(key: metric, value: value) in values.entries)
        BodyReading(
          id: _db.newId(),
          measuredAt: measuredAt,
          metric: metric,
          value: value,
        ),
    ];
    _db.transaction(() {
      for (final reading in readings) {
        _journal.addBodyReading(reading);
      }
    });
    return readings;
  }

  Map<BodyMetric, BodyReading> latestBodyReadings() =>
      _journal.latestBodyReadings();

  List<BodyReading> bodyReadingsBetween(
    BodyMetric metric,
    DateTime start,
    DateTime end,
  ) => _journal.bodyReadingsBetween(metric, start, end);

  void updateBodyReading(BodyReading reading) =>
      _journal.updateBodyReading(reading);

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

  /// A sleep typed in: how long, and, when the user gives them, when it
  /// began and ended ([at]) and whether it was the night or a nap.
  SleepEntry recordSleep(
    Duration slept, {
    int? score,
    String note = '',
    DateTime? at,
    DateTime? startedAt,
    SleepKind kind = SleepKind.night,
  }) {
    final entry = SleepEntry(
      id: _db.newId(),
      sleptAt: at ?? _db.now(),
      duration: slept,
      score: score,
      note: note,
      startedAt: startedAt,
      kind: kind,
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

  /// Whether a record was typed in here rather than read from a health
  /// platform, so its times are the user's to change.
  bool isTypedIn(String id) =>
      (_journal.sourceOf(id) ?? ChangeSource.local) == ChangeSource.local;

  void updateWeight(BodyWeight weight) => _journal.updateWeight(weight);

  void updateMeasurement(BodyMeasurement measurement) =>
      _journal.updateMeasurement(measurement);

  void updateSleep(SleepEntry entry) => _journal.updateSleep(entry);

  void updateWellness(WellnessEntry entry) => _journal.updateWellness(entry);

  void delete(String id) => _journal.delete(id);

  void restore(String id) => _journal.restore(id);

  /// Weights measured in the [window] ending now, oldest first.
  /// Weights measured in `[start, end)`, oldest first.
  List<BodyWeight> weightsBetween(DateTime start, DateTime end) =>
      _journal.weightsBetween(start, end);

  /// Tape measurements taken in `[start, end)`, oldest first.
  List<BodyMeasurement> measurementsBetween(DateTime start, DateTime end) =>
      _journal.measurementsBetween(start, end);

  List<BodyWeight> recentWeights(Duration window) =>
      _journal.weightsBetween(_db.now().subtract(window), _db.nowInclusive);

  List<WellnessEntry> recentWellness(Duration window) =>
      _journal.wellnessBetween(_db.now().subtract(window), _db.nowInclusive);

  List<SleepEntry> recentSleep(Duration window) =>
      _journal.sleepBetween(_db.now().subtract(window), _db.nowInclusive);
}
