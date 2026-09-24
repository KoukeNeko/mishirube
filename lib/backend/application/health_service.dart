import '../../domain/domain.dart';
import '../engines/sleep_nights.dart';
import '../health/health_source.dart';
import '../storage/activity_repository.dart';
import '../storage/activity_sample_repository.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';
import 'nutrition_service.dart';

/// What one import did.
class HealthImport {
  const HealthImport({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.denied,
  });

  /// New records per kind.
  final Map<HealthDataKind, int> added;

  /// Sleeps whose figures changed since the last read.
  final int updated;

  /// Nights the user already logged by hand: theirs is kept.
  final int skipped;

  /// Kinds the user did not allow, which were not read; null when the
  /// platform does not say.
  final Set<HealthDataKind>? denied;

  bool get foundNothing =>
      added.values.every((count) => count == 0) && updated == 0 && skipped == 0;
}

/// Records read from a health platform into the log: sleep, weight,
/// waist, body composition, workouts, water, and everyday activity.
/// Read only.
///
/// Every record gets an id from the platform's own — a night from its
/// morning — so reading the same weeks again finds what came in before
/// instead of adding it twice. A record the user deleted stays deleted,
/// and a night they logged themselves is left alone.
class HealthService {
  HealthService(
    this._db,
    this._journal,
    this._activities,
    this._samples,
    this._nutrition,
    this.source,
  );

  static const _connectedKey = 'health.connected';

  /// The kinds access was last asked for, so a kind added in an update
  /// is asked for once instead of silently reading nothing.
  static const _askedKey = 'health.asked_kinds';
  static const _syncedKey = 'health.synced_at';

  /// How far back an import reads: far enough to catch a record changed
  /// on the platform since the last read.
  static const window = Duration(days: 30);

  /// How far back the first import reads: the longest trend the app
  /// draws, so it has something to draw from the first day.
  static const history = Duration(days: 182);

  final AppDatabase _db;
  final JournalRepository _journal;
  final ActivityRepository _activities;
  final ActivitySampleRepository _samples;
  final NutritionService _nutrition;
  final HealthSource source;

  Future<bool> isAvailable() => source.isAvailable();

  /// What the user allowed; null when the platform will not say.
  Future<Set<HealthDataKind>?> grantedKinds() async {
    final granted = await source.grantedKinds();
    return granted?.intersection(source.kinds);
  }

  /// Asks again for the kinds not yet allowed, then reads what now is.
  Future<HealthImport?> askAgain() async {
    if (!await _ask()) return null;
    return importAll();
  }

  Future<bool> _ask() async {
    if (!await source.requestAccess(source.kinds)) return false;
    _db.setSetting(
      _askedKey,
      [for (final kind in source.kinds) kind.name].join(','),
    );
    return true;
  }

  /// Whether a kind this platform holds was never asked for.
  bool get _hasUnaskedKinds {
    final asked = (_db.setting(_askedKey) ?? '').split(',').toSet();
    return source.kinds.any((kind) => !asked.contains(kind.name));
  }

  bool get isConnected => _db.setting(_connectedKey) == 'true';

  DateTime? get lastSync => switch (_db.setting(_syncedKey)) {
    final ms? => DateTime.fromMillisecondsSinceEpoch(int.parse(ms)),
    null => null,
  };

  /// Asks for access to every kind, remembers the choice and reads the
  /// last [history]. Null when the platform is not there or the request
  /// did not go through.
  Future<HealthImport?> connect() async {
    if (!await source.isAvailable()) return null;
    if (!await _ask()) return null;
    _db.setSetting(_connectedKey, 'true');
    return importAll();
  }

  /// Stops reading. What was imported stays: it is the user's record now.
  void disconnect() => _db.setSetting(_connectedKey, 'false');

  Future<HealthImport> importAll() async {
    if (isConnected && _hasUnaskedKinds) await _ask();
    final now = _db.now();
    final from = now.subtract(lastSync == null ? history : window);
    // Only what was allowed: Health Connect refuses a read it was not
    // allowed, and asking for it anyway would fail the whole import.
    final granted = await grantedKinds();
    final kinds = granted ?? source.kinds;
    // Read everything first: a platform call can fail, and a failure
    // should leave the log as it was, not half imported.
    final samples = kinds.contains(HealthDataKind.sleep)
        ? await source.sleepSamples(from, now)
        : const <SleepSample>[];
    final weights = kinds.contains(HealthDataKind.weight)
        ? await source.weights(from, now)
        : const <HealthWeight>[];
    final waists = kinds.contains(HealthDataKind.waist)
        ? await source.waists(from, now)
        : const <HealthWaist>[];
    final body = kinds.contains(HealthDataKind.body)
        ? await source.bodyReadings(from, now)
        : const <HealthBodyReading>[];
    final workouts = kinds.contains(HealthDataKind.workouts)
        ? await source.workouts(from, now)
        : const <HealthWorkout>[];
    final water = kinds.contains(HealthDataKind.water)
        ? await source.water(from, now)
        : const <HealthWater>[];
    final activity = kinds.contains(HealthDataKind.activity)
        ? await source.activitySamples(from, now)
        : const <ActivitySample>[];
    final sleeps = [for (final night in nightsOf(samples)) _planOf(night)];
    // Only over the time each sleep covers: a whole month of heart rate
    // is not what the sleep page shows.
    final readings = kinds.contains(HealthDataKind.overnight)
        ? await source.overnight([
            for (final sleep in sleeps)
              (sleep.entry.startedAt!, sleep.entry.sleptAt),
          ])
        : null;

    return _db.transaction(() {
      final added = {for (final kind in kinds) kind: 0};
      final (nights, updated, skipped) = _importSleeps(sleeps, readings);
      if (kinds.contains(HealthDataKind.sleep)) {
        added[HealthDataKind.sleep] = nights;
      }

      for (final weight in weights) {
        final id = '${source.idPrefix}-weight-${weight.id}';
        if (_db.hasRow('body_weights', id)) continue;
        _journal.addWeight(
          BodyWeight(id: id, measuredAt: weight.at, weightKg: weight.kg),
          source: source.changeSource,
        );
        added.update(HealthDataKind.weight, (n) => n + 1);
      }
      for (final waist in waists) {
        final id = '${source.idPrefix}-waist-${waist.id}';
        if (_db.hasRow('body_measurements', id)) continue;
        _journal.addMeasurement(
          BodyMeasurement(
            id: id,
            measuredAt: waist.at,
            site: MeasurementSite.waist,
            centimetres: waist.cm,
          ),
          source: source.changeSource,
        );
        added.update(HealthDataKind.waist, (n) => n + 1);
      }
      for (final reading in body) {
        final id = '${source.idPrefix}-body-${reading.id}';
        if (_db.hasRow('body_readings', id)) continue;
        _journal.addBodyReading(
          BodyReading(
            id: id,
            measuredAt: reading.at,
            metric: reading.metric,
            value: reading.value,
          ),
          source: source.changeSource,
        );
        added.update(HealthDataKind.body, (n) => n + 1);
      }
      for (final workout in workouts) {
        final id = '${source.idPrefix}-workout-${workout.id}';
        if (_db.hasRow('activities', id) ||
            !workout.end.isAfter(workout.start)) {
          continue;
        }
        _activities.add(
          ActivitySession(
            id: id,
            type: ActivityTypes.byId(workout.activity),
            startedAt: workout.start,
            duration: workout.end.difference(workout.start),
            distanceMeters: workout.distanceMeters,
            nativeType: workout.nativeType,
          ),
          source: source.changeSource,
        );
        added.update(HealthDataKind.workouts, (n) => n + 1);
      }
      for (final glass in water) {
        final id = '${source.idPrefix}-water-${glass.id}';
        if (_db.hasRow('meals', id) || glass.ml <= 0) continue;
        _nutrition.logWater(
          glass.ml,
          at: glass.at,
          id: id,
          source: source.changeSource,
        );
        added.update(HealthDataKind.water, (n) => n + 1);
      }

      if (kinds.contains(HealthDataKind.activity)) {
        added[HealthDataKind.activity] = _samples.sync(
          activity,
          idPrefix: source.idPrefix,
          source: source.changeSource,
        );
      }

      _db.setSetting(_syncedKey, '${now.millisecondsSinceEpoch}');
      return HealthImport(
        added: added,
        updated: updated,
        skipped: skipped,
        denied: granted == null ? null : source.kinds.difference(granted),
      );
    });
  }

  /// The record a sleep becomes, from the source the user picked for it
  /// when that source still recorded it.
  ({String id, SleepEntry entry, List<SleepSample> samples}) _planOf(
    NightOfSleep night,
  ) {
    final day = localDayOf(night.morning);
    final start = night.summary.start;
    final id = switch (night.kind) {
      SleepKind.night => '${source.idPrefix}-sleep-$day',
      // Named by when it began: a day can have more than one.
      SleepKind.nap =>
        '${source.idPrefix}-nap-$day-'
            '${start.hour.toString().padLeft(2, '0')}'
            '${start.minute.toString().padLeft(2, '0')}',
    };
    final chosen = _journal.chosenSleepSource(id);
    final summary =
        (chosen == null ? null : summarize(night.samples, source: chosen)) ??
        night.summary;
    return (
      id: id,
      entry: SleepEntry(
        id: id,
        sleptAt: summary.end,
        // Whole minutes, as the log keeps them.
        duration: Duration(minutes: summary.length.inMinutes),
        startedAt: summary.start,
        kind: night.kind,
        measure: summary.measure,
        sourceName: summary.sourceName,
      ),
      samples: night.samples,
    );
  }

  /// Adds, updates or skips each sleep, with its stretches and what was
  /// measured over it; returns how many were added, updated and skipped.
  (int, int, int) _importSleeps(
    List<({String id, SleepEntry entry, List<SleepSample> samples})> sleeps,
    List<List<OvernightReading>>? readings,
  ) {
    var added = 0, updated = 0, skipped = 0;
    for (final (index, (:id, :entry, :samples)) in sleeps.indexed) {
      switch (_journal.sleepRow(id)) {
        case (isDeleted: true, entry: _, chosenSource: _):
          continue;
        case (isDeleted: false, entry: final stored, chosenSource: _):
          if (!_sameFigures(stored, entry)) {
            _journal.resyncSleep(entry, source: source.changeSource);
            updated++;
          }
        case null:
          if (entry.kind == SleepKind.night) {
            // A night logged by hand is dated when it was logged, which
            // is usually soon after waking.
            final from = entry.sleptAt.subtract(const Duration(hours: 12));
            final to = entry.sleptAt.add(const Duration(hours: 12));
            if (_journal.hasSleepOtherThan(source.changeSource, from, to)) {
              skipped++;
              continue;
            }
          }
          _journal.addSleep(entry, source: source.changeSource);
          added++;
      }
      _journal.replaceSleepSegments(id, samples, source: source.changeSource);
      if (readings != null) {
        _journal.replaceSleepReadings(
          id,
          readings[index],
          source: source.changeSource,
        );
      }
    }
    return (added, updated, skipped);
  }

  static bool _sameFigures(SleepEntry a, SleepEntry b) =>
      a.sleptAt == b.sleptAt &&
      a.duration == b.duration &&
      a.startedAt == b.startedAt &&
      a.kind == b.kind &&
      a.measure == b.measure &&
      a.sourceName == b.sourceName;
}
