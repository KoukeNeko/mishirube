import '../../domain/domain.dart';
import '../engines/sleep_nights.dart';
import '../health/health_source.dart';
import '../storage/activity_repository.dart';
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

  /// Nights whose length changed since the last read.
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
/// waist, workouts and water. Read only.
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
    this._nutrition,
    this.source,
  );

  static const _connectedKey = 'health.connected';
  static const _syncedKey = 'health.synced_at';

  /// How far back an import reads.
  static const window = Duration(days: 30);

  final AppDatabase _db;
  final JournalRepository _journal;
  final ActivityRepository _activities;
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
    if (!await source.requestAccess(source.kinds)) return null;
    return importAll();
  }

  bool get isConnected => _db.setting(_connectedKey) == 'true';

  DateTime? get lastSync => switch (_db.setting(_syncedKey)) {
    final ms? => DateTime.fromMillisecondsSinceEpoch(int.parse(ms)),
    null => null,
  };

  /// Asks for access to every kind, remembers the choice and reads the
  /// last [window]. Null when the platform is not there or the request
  /// did not go through.
  Future<HealthImport?> connect() async {
    if (!await source.isAvailable()) return null;
    if (!await source.requestAccess(source.kinds)) return null;
    _db.setSetting(_connectedKey, 'true');
    return importAll();
  }

  /// Stops reading. What was imported stays: it is the user's record now.
  void disconnect() => _db.setSetting(_connectedKey, 'false');

  Future<HealthImport> importAll() async {
    final now = _db.now();
    final from = now.subtract(window);
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
    final workouts = kinds.contains(HealthDataKind.workouts)
        ? await source.workouts(from, now)
        : const <HealthWorkout>[];
    final water = kinds.contains(HealthDataKind.water)
        ? await source.water(from, now)
        : const <HealthWater>[];

    return _db.transaction(() {
      final added = {for (final kind in kinds) kind: 0};
      final (nights, updated, skipped) = _importNights(nightsOf(samples));
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

      _db.setSetting(_syncedKey, '${now.millisecondsSinceEpoch}');
      return HealthImport(
        added: added,
        updated: updated,
        skipped: skipped,
        denied: granted == null ? null : source.kinds.difference(granted),
      );
    });
  }

  /// Adds, updates or skips each night; returns how many of each.
  (int, int, int) _importNights(List<NightOfSleep> nights) {
    var added = 0, updated = 0, skipped = 0;
    for (final night in nights) {
      final id = '${source.idPrefix}-sleep-${localDayOf(night.morning)}';
      // Whole minutes, as the log keeps them.
      final asleep = Duration(minutes: night.asleep.inMinutes);
      switch (_journal.sleepRow(id)) {
        case (isDeleted: true, sleptAt: _, duration: _):
          continue;
        case (isDeleted: false, :final sleptAt, :final duration):
          if (sleptAt == night.wokeAt && duration == asleep) continue;
          _journal.resyncSleep(
            id,
            sleptAt: night.wokeAt,
            duration: asleep,
            source: source.changeSource,
          );
          updated++;
        case null:
          // A night logged by hand is dated when it was logged, which is
          // usually soon after waking.
          final from = night.wokeAt.subtract(const Duration(hours: 12));
          final to = night.wokeAt.add(const Duration(hours: 12));
          if (_journal.hasSleepOtherThan(source.changeSource, from, to)) {
            skipped++;
            continue;
          }
          _journal.addSleep(
            SleepEntry(id: id, sleptAt: night.wokeAt, duration: asleep),
            source: source.changeSource,
          );
          added++;
      }
    }
    return (added, updated, skipped);
  }
}
