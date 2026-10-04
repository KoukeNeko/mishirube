import '../../app/change_source_label.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';

/// Weights, tape measurements, nights typed in, check-ins, baths and notes:
/// reading one, and recording, correcting and removing them.
class JournalViewModel extends ViewModel {
  JournalViewModel(super.backend);

  static const _recent = Duration(days: 28);

  /// A journal record — a weight, a measurement, a night, a check-in or a
  /// note — or null once it is deleted.
  Object? entry(String id) => backend.journal.entry(id);

  /// Where a record came from, in the words the screen shows.
  String sourceLabel(AppLocalizations l10n, String id) =>
      changeSourceLabel(l10n, backend.journal.sourceOf(id));

  /// Weights of the last few weeks, oldest first.
  List<BodyWeight> get recentWeights => backend.journal.recentWeights(_recent);

  /// Nights of the last few weeks, oldest first.
  List<SleepEntry> get recentSleep => backend.journal.recentSleep(_recent);

  /// The last measurement of each site.
  Map<MeasurementSite, BodyMeasurement> get latestMeasurements =>
      backend.journal.latestMeasurements();

  void recordWeight(double kilograms, {String note = ''}) =>
      backend.journal.recordWeight(kilograms, note: note);

  /// The last reading of each body figure other than weight and girth.
  Map<BodyMetric, BodyReading> get latestBodyReadings =>
      backend.journal.latestBodyReadings();

  BodySession recordBodySession({
    double? weightKg,
    Map<BodyMetric, double> readings = const {},
  }) =>
      backend.journal.recordBodySession(weightKg: weightKg, readings: readings);

  BodySession? bodySession(String sessionId) =>
      backend.journal.bodySession(sessionId);

  void updateBodySession(
    BodySession session, {
    double? weightKg,
    Map<BodyMetric, double> readings = const {},
  }) => backend.journal.updateBodySession(
    session,
    weightKg: weightKg,
    readings: readings,
  );

  List<String> deleteBodySession(BodySession session) =>
      backend.journal.deleteBodySession(session);

  void restoreRecords(List<String> ids) => backend.journal.restoreRecords(ids);

  /// The last weighing, to show beside the weight field.
  BodyWeight? get latestWeight => backend.journal.weightOn(now());

  void recordBodyReadings(Map<BodyMetric, double> values) =>
      backend.journal.recordBodyReadings(values);

  void updateBodyReading(BodyReading reading) =>
      backend.journal.updateBodyReading(reading);

  void recordMeasurement(MeasurementSite site, double centimetres) =>
      backend.journal.recordMeasurement(site, centimetres);

  void recordSleep(
    Duration slept, {
    int? score,
    String note = '',
    DateTime? at,
    DateTime? startedAt,
    SleepKind kind = SleepKind.night,
  }) => backend.journal.recordSleep(
    slept,
    score: score,
    note: note,
    at: at,
    startedAt: startedAt,
    kind: kind,
  );

  void recordWellness(WellnessKind kind, int score, {String note = ''}) =>
      backend.journal.recordWellness(kind, score, note: note);

  void recordBath({
    required DateTime at,
    BathWater? water,
    BathKind? kind,
    Duration? duration,
  }) => backend.journal.recordBath(
    at: at,
    water: water,
    kind: kind,
    duration: duration,
  );

  void recordNote(String text) => backend.journal.recordNote(text);

  void updateWeight(BodyWeight weight) => backend.journal.updateWeight(weight);

  void updateMeasurement(BodyMeasurement measurement) =>
      backend.journal.updateMeasurement(measurement);

  void updateSleep(SleepEntry entry) => backend.journal.updateSleep(entry);

  /// Makes a sleep a night or a nap; returns what [restoreSleepKinds]
  /// needs to take it back, the day's other night included.
  List<(String, SleepKind?)> setSleepKind(String id, SleepKind kind) =>
      backend.journal.setSleepKind(id, kind);

  void restoreSleepKinds(List<(String, SleepKind?)> previous) =>
      backend.journal.restoreSleepKinds(previous);

  /// Whether a record was typed in here, not read from a health platform.
  bool isTypedIn(String id) => backend.journal.isTypedIn(id);

  void updateWellness(WellnessEntry entry) =>
      backend.journal.updateWellness(entry);

  void updateBath(BathEntry entry) => backend.journal.updateBath(entry);

  void updateNote(Note note) => backend.journal.updateNote(note);

  /// Tombstones a record; [restore] takes it back.
  void delete(String id) => backend.journal.delete(id);

  void restore(String id) => backend.journal.restore(id);
}
