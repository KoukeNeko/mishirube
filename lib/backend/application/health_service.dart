import '../../domain/domain.dart';
import '../engines/sleep_nights.dart';
import '../health/health_source.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';
import 'health_writer.dart';
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

  /// This import and [other] together, as one.
  HealthImport and(HealthImport other) => HealthImport(
    added: {
      for (final kind in {...added.keys, ...other.added.keys})
        kind: (added[kind] ?? 0) + (other.added[kind] ?? 0),
    },
    updated: updated + other.updated,
    skipped: skipped + other.skipped,
    denied: denied,
  );

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
  HealthService(this._db, this._journal, this._nutrition, this.source);

  static const _connectedKey = 'health.connected';

  /// The kinds access was last asked for, so a kind added in an update
  /// is asked for once instead of silently reading nothing.
  static const _askedKey = 'health.asked_kinds';

  /// Bumped whenever a platform starts reading more types under a kind
  /// it already had (a workout's route, heart rate and running figures
  /// under workouts): Apple Health never says a read was refused, so
  /// without asking again those reads would quietly come back empty.
  static const _accessVersion = 3;
  static const _askedVersionKey = 'health.asked_version';
  static const _syncedKey = 'health.synced_at';

  /// How far back an import reads: far enough to catch a record changed
  /// on the platform since the last read.
  static const window = Duration(days: 30);

  /// How far back a full read reaches: Apple Health began in 2014, so
  /// this is everything a platform can hold. Health Connect itself
  /// returns less without its history permission.
  static final earliest = DateTime(2014);

  /// Kept whenever a full read has run, with [_accessVersion]: a kind or
  /// type added later is read in full once, not just its last month.
  static const _fullReadKey = 'health.full_read_version';

  /// Activity is kept hour by hour for the last year, day by day before:
  /// years of hours would fill the store for charts that never show them.
  static const hourlyActivity = Duration(days: 365);

  final AppDatabase _db;
  final JournalRepository _journal;
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
    _db.setSetting(_askedVersionKey, '$_accessVersion');
    return true;
  }

  /// Whether a kind this platform holds, or a type read under one, was
  /// never asked for.
  bool get _hasUnaskedKinds {
    final asked = (_db.setting(_askedKey) ?? '').split(',').toSet();
    final version = int.tryParse(_db.setting(_askedVersionKey) ?? '') ?? 1;
    return version < _accessVersion ||
        source.kinds.any((kind) => !asked.contains(kind.name));
  }

  bool get isConnected => _db.setting(_connectedKey) == 'true';

  /// What the platform recorded during [session], when it was read from
  /// this platform; null for one logged in the app or no longer there.
  Future<ActivityDetail?> detailOf(ActivitySession session) async {
    final prefix = '${source.idPrefix}-workout-';
    if (!session.id.startsWith(prefix)) return null;
    return source.activityDetail(session.id.substring(prefix.length));
  }

  /// Heart rate and respiratory rate through a sleep, read from the
  /// platform when the night is opened; empty when not connected.
  Future<Map<OvernightMeasure, List<(DateTime, double)>>> overnightSeries(
    DateTime from,
    DateTime to,
  ) async => isConnected ? source.overnightSeries(from, to) : const {};

  DateTime? get lastSync => switch (_db.setting(_syncedKey)) {
    final ms? => DateTime.fromMillisecondsSinceEpoch(int.parse(ms)),
    null => null,
  };

  /// Asks for access to every kind, remembers the choice and reads all
  /// the platform holds. Null when the platform is not there or the
  /// request did not go through.
  Future<HealthImport?> connect() async {
    if (!await source.isAvailable()) return null;
    if (!await _ask()) return null;
    _db.setSetting(_connectedKey, 'true');
    return importAll();
  }

  /// Stops reading. What was imported stays: it is the user's record now.
  void disconnect() => _db.setSetting(_connectedKey, 'false');

  /// Reads the last [window], or, the first time and whenever a kind or
  /// type has been added since, everything back to [earliest] a year at
  /// a time: one read of a decade of samples would not fit in memory.
  Future<HealthImport> importAll() async {
    if (isConnected && _hasUnaskedKinds) await _ask();
    final now = _db.now();
    // Only what was allowed: Health Connect refuses a read it was not
    // allowed, and asking for it anyway would fail the whole import.
    final granted = await grantedKinds();
    final kinds = granted ?? source.kinds;
    final isFullRead =
        lastSync == null || _db.setting(_fullReadKey) != '$_accessVersion';
    var total = HealthImport(
      added: {for (final kind in kinds) kind: 0},
      updated: 0,
      skipped: 0,
      denied: granted == null ? null : source.kinds.difference(granted),
    );
    for (final (from, to)
        in isFullRead ? _yearsBack(now) : [(now.subtract(window), now)]) {
      total = total.and(
        await _importRange(
          from,
          to,
          kinds,
          isHourly: now.difference(from) <= hourlyActivity,
        ),
      );
    }
    _db.setSetting(_syncedKey, '${now.millisecondsSinceEpoch}');
    if (isFullRead) _db.setSetting(_fullReadKey, '$_accessVersion');
    return total;
  }

  /// A year at a time from [now] back to [earliest], newest first. Each
  /// stretch starts at noon, so no night's sleep is cut in two.
  List<(DateTime, DateTime)> _yearsBack(DateTime now) {
    final stretches = <(DateTime, DateTime)>[];
    var to = now;
    while (to.isAfter(earliest)) {
      final from = DateTime(to.year - 1, to.month, to.day, 12);
      stretches.add((from.isBefore(earliest) ? earliest : from, to));
      to = from;
    }
    return stretches;
  }

  /// Reads [from]–[to] of [kinds] and records it, all or nothing.
  Future<HealthImport> _importRange(
    DateTime from,
    DateTime now,
    Set<HealthDataKind> kinds, {
    required bool isHourly,
  }) async {
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
        ? await source.activitySamples(from, now, isHourly: isHourly)
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

    final batch = HealthBatch(
      kinds: kinds,
      idPrefix: source.idPrefix,
      changeSource: source.changeSource,
      sleeps: sleeps,
      readings: readings,
      weights: weights,
      waists: waists,
      body: body,
      workouts: workouts,
      water: [
        for (final glass in water)
          if (glass.ml > 0)
            (
              _nutrition.waterRecord(
                glass.ml,
                at: glass.at,
                id: '${source.idPrefix}-water-${glass.id}',
              ),
              glass.at,
            ),
      ],
      activity: activity,
    );
    // A store in a file is written on an isolate of its own, so the
    // screens keep drawing through a long transaction; one in memory
    // (tests, previews) has nothing else that could reach it.
    final path = _db.path;
    if (path == null) return HealthWriter(_db).write(batch);
    final imported = await writeHealthBatchApart(path, _db.now(), batch);
    _db.notifyWrittenElsewhere();
    return imported;
  }

  /// The record a sleep becomes, from the source the user picked for it
  /// when that source still recorded it.
  PlannedSleep _planOf(NightOfSleep night) {
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
}
