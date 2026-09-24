import '../../domain/domain.dart';
import '../../shared/format.dart';
import 'database.dart';
import 'timeline_source.dart';

/// Body measurements and wellness check-ins.
class JournalRepository {
  JournalRepository(this._db);

  final AppDatabase _db;

  void addWeight(
    BodyWeight weight, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO body_weights (id, measured_at, weight_kg, note, '
        'created_at, updated_at, source, local_day, utc_offset_minutes) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          weight.id,
          weight.measuredAt.millisecondsSinceEpoch,
          weight.weightKg,
          weight.note,
          now,
          now,
          source.name,
          localDayOf(weight.measuredAt),
          weight.measuredAt.timeZoneOffset.inMinutes,
        ],
      );
      _db.audit(
        entityType: 'body_weight',
        entityId: weight.id,
        action: 'create',
        source: source,
      );
    });
  }

  void addWellness(
    WellnessEntry entry, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO wellness_entries (id, recorded_at, kind, score, note, '
        'created_at, updated_at, source, local_day, utc_offset_minutes) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          entry.id,
          entry.recordedAt.millisecondsSinceEpoch,
          entry.kind.name,
          entry.score,
          entry.note,
          now,
          now,
          source.name,
          localDayOf(entry.recordedAt),
          entry.recordedAt.timeZoneOffset.inMinutes,
        ],
      );
      _db.audit(
        entityType: 'wellness_entry',
        entityId: entry.id,
        action: 'create',
        source: source,
      );
    });
  }

  void addSleep(SleepEntry entry, {ChangeSource source = ChangeSource.local}) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO sleep_entries (id, slept_at, duration_minutes, score, '
        'note, created_at, updated_at, source, local_day, '
        'utc_offset_minutes, started_at, kind, measure, source_name) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          entry.id,
          entry.sleptAt.millisecondsSinceEpoch,
          entry.duration.inMinutes,
          entry.score,
          entry.note,
          now,
          now,
          source.name,
          localDayOf(entry.sleptAt),
          entry.sleptAt.timeZoneOffset.inMinutes,
          entry.startedAt?.millisecondsSinceEpoch,
          entry.kind.name,
          entry.measure.name,
          entry.sourceName,
        ],
      );
      _db.audit(
        entityType: 'sleep_entry',
        entityId: entry.id,
        action: 'create',
        source: source,
      );
    });
  }

  /// A night's row whatever its state: null when there is none, and
  /// `isDeleted` when the user removed it — an import must not bring a
  /// deleted night back.
  ({bool isDeleted, SleepEntry entry, String? chosenSource})? sleepRow(
    String id,
  ) {
    final rows = _db.select('SELECT * FROM sleep_entries WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final row = rows.single;
    return (
      isDeleted: row['deleted_at'] != null,
      entry: _sleepFrom(row),
      chosenSource: row['chosen_source'] as String?,
    );
  }

  /// Whether a live night from anywhere but [source] lies in
  /// `[start, end)`.
  bool hasSleepOtherThan(ChangeSource source, DateTime start, DateTime end) =>
      _db.select(
        'SELECT 1 FROM sleep_entries WHERE deleted_at IS NULL '
        'AND source != ? AND slept_at >= ? AND slept_at < ? LIMIT 1',
        [source.name, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      ).isNotEmpty;

  /// Moves an imported sleep to what its source now says, and records
  /// which source the user picked when [chosenSource] is given.
  void resyncSleep(
    SleepEntry entry, {
    required ChangeSource source,
    String? chosenSource,
  }) => _update('sleep_entries', entry.id, {
    'slept_at': entry.sleptAt.millisecondsSinceEpoch,
    'duration_minutes': entry.duration.inMinutes,
    'local_day': localDayOf(entry.sleptAt),
    'utc_offset_minutes': entry.sleptAt.timeZoneOffset.inMinutes,
    'started_at': entry.startedAt?.millisecondsSinceEpoch,
    'kind': entry.kind.name,
    'measure': entry.measure.name,
    'source_name': entry.sourceName,
    'chosen_source': ?chosenSource,
  }, source: source);

  /// Sleeps logged against the day [day] falls on, oldest first.
  List<SleepEntry> sleepOn(DateTime day) => [
    for (final row in _db.select(
      'SELECT * FROM sleep_entries WHERE deleted_at IS NULL '
      'AND local_day = ? ORDER BY slept_at',
      [localDayOf(day)],
    ))
      _sleepFrom(row),
  ];

  /// The source the user picked for [sleepId], or null for the default.
  String? chosenSleepSource(String sleepId) =>
      _db.select('SELECT chosen_source FROM sleep_entries WHERE id = ?', [
            sleepId,
          ]).firstOrNull?['chosen_source']
          as String?;

  /// Every source's stretches of [sleepId], in time order.
  List<SleepSample> sleepSegments(String sleepId) => [
    for (final row in _db.select(
      'SELECT * FROM sleep_segments WHERE sleep_id = ? AND deleted_at IS NULL '
      'ORDER BY started_at, recorded_by',
      [sleepId],
    ))
      SleepSample(
        start: DateTime.fromMillisecondsSinceEpoch(row['started_at']! as int),
        end: DateTime.fromMillisecondsSinceEpoch(row['ended_at']! as int),
        stage: SleepStage.values.byName(row['stage']! as String),
        native: row['native_stage']! as String,
        source: row['recorded_by']! as String,
        sourceName: row['recorded_by_name']! as String,
        isManual: row['is_manual'] == 1,
      ),
  ];

  /// Makes [samples] the stretches of [sleepId]. Nothing is written when
  /// they are what is already there; otherwise the old ones are
  /// tombstoned, as every record is, and the new ones added.
  void replaceSleepSegments(
    String sleepId,
    List<SleepSample> samples, {
    required ChangeSource source,
  }) {
    final sorted = [...samples]
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        return byStart != 0 ? byStart : a.source.compareTo(b.source);
      });
    final current = sleepSegments(sleepId);
    if (_sameList(current, sorted)) return;
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE sleep_segments SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE sleep_id = ? AND deleted_at IS NULL',
        [now, now, sleepId],
      );
      for (final sample in sorted) {
        _db.execute(
          'INSERT INTO sleep_segments (id, sleep_id, started_at, ended_at, '
          'stage, native_stage, recorded_by, recorded_by_name, is_manual, '
          'created_at, updated_at, source) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _db.newId(),
            sleepId,
            sample.start.millisecondsSinceEpoch,
            sample.end.millisecondsSinceEpoch,
            sample.stage.name,
            sample.native,
            sample.source,
            sample.sourceName,
            sample.isManual ? 1 : 0,
            now,
            now,
            source.name,
          ],
        );
      }
      _db.audit(
        entityType: 'sleep_segments',
        entityId: sleepId,
        action: 'replace',
        source: source,
        payload: {'count': sorted.length},
      );
    });
  }

  /// What was measured over [sleepId], in [OvernightMeasure] order.
  List<OvernightReading> sleepReadings(String sleepId) {
    final readings = [
      for (final row in _db.select(
        'SELECT * FROM sleep_readings WHERE sleep_id = ? '
        'AND deleted_at IS NULL',
        [sleepId],
      ))
        OvernightReading(
          measure: OvernightMeasure.values.byName(row['measure']! as String),
          minimum: row['minimum']! as double,
          maximum: row['maximum']! as double,
          average: row['average']! as double,
          count: row['sample_count']! as int,
          isElevated: switch (row['is_elevated']) {
            null => null,
            final value => value == 1,
          },
        ),
    ];
    return readings..sort((a, b) => a.measure.index.compareTo(b.measure.index));
  }

  /// Makes [readings] what was measured over [sleepId], writing nothing
  /// when they are what is already there.
  void replaceSleepReadings(
    String sleepId,
    List<OvernightReading> readings, {
    required ChangeSource source,
  }) {
    final sorted = [...readings]
      ..sort((a, b) => a.measure.index.compareTo(b.measure.index));
    if (_sameList(sleepReadings(sleepId), sorted)) return;
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE sleep_readings SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE sleep_id = ? AND deleted_at IS NULL',
        [now, now, sleepId],
      );
      for (final reading in sorted) {
        _db.execute(
          'INSERT INTO sleep_readings (id, sleep_id, measure, minimum, '
          'maximum, average, sample_count, is_elevated, created_at, '
          'updated_at, source) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _db.newId(),
            sleepId,
            reading.measure.name,
            reading.minimum,
            reading.maximum,
            reading.average,
            reading.count,
            switch (reading.isElevated) {
              null => null,
              final value => value ? 1 : 0,
            },
            now,
            now,
            source.name,
          ],
        );
      }
      _db.audit(
        entityType: 'sleep_readings',
        entityId: sleepId,
        action: 'replace',
        source: source,
        payload: {'count': sorted.length},
      );
    });
  }

  static bool _sameList<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Nights logged in `[start, end)`, oldest first.
  List<SleepEntry> sleepBetween(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM sleep_entries WHERE deleted_at IS NULL '
      'AND slept_at >= ? AND slept_at < ? ORDER BY slept_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      _sleepFrom(row),
  ];

  SleepEntry _sleepFrom(Map<String, Object?> row) => SleepEntry(
    id: row['id']! as String,
    sleptAt: DateTime.fromMillisecondsSinceEpoch(row['slept_at']! as int),
    duration: Duration(minutes: row['duration_minutes']! as int),
    score: row['score'] as int?,
    note: row['note']! as String,
    startedAt: switch (row['started_at']) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    },
    kind: SleepKind.values.byName(row['kind']! as String),
    measure: SleepMeasure.values.byName(row['measure']! as String),
    sourceName: row['source_name']! as String,
  );

  /// The oldest live row of [table], by its [timeColumn].
  DateTime? _earliest(String table, String timeColumn) {
    final first = _db
        .select(
          'SELECT MIN($timeColumn) AS first FROM $table '
          'WHERE deleted_at IS NULL',
        )
        .first['first'];
    return first == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(first as int);
  }

  /// Weights measured in `[start, end)`, oldest first.
  void addMeasurement(
    BodyMeasurement measurement, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO body_measurements (id, measured_at, site, centimetres, '
        'note, created_at, updated_at, source, local_day, '
        'utc_offset_minutes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          measurement.id,
          measurement.measuredAt.millisecondsSinceEpoch,
          measurement.site.name,
          measurement.centimetres,
          measurement.note,
          now,
          now,
          source.name,
          localDayOf(measurement.measuredAt),
          measurement.measuredAt.timeZoneOffset.inMinutes,
        ],
      );
      _db.audit(
        entityType: 'body_measurement',
        entityId: measurement.id,
        action: 'create',
        source: source,
      );
    });
  }

  List<BodyMeasurement> measurementsBetween(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM body_measurements WHERE deleted_at IS NULL '
      'AND measured_at >= ? AND measured_at < ? ORDER BY measured_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      _measurementFrom(row),
  ];

  /// The last measurement of each site, for prefilling and for showing
  /// what has been tracked at all.
  Map<MeasurementSite, BodyMeasurement> latestMeasurements() => {
    for (final row in _db.select(
      'SELECT * FROM body_measurements WHERE deleted_at IS NULL '
      'ORDER BY measured_at',
    ))
      MeasurementSite.values.byName(row['site'] as String): _measurementFrom(
        row,
      ),
  };

  BodyMeasurement _measurementFrom(Map<String, Object?> row) => BodyMeasurement(
    id: row['id']! as String,
    measuredAt: DateTime.fromMillisecondsSinceEpoch(row['measured_at']! as int),
    site: MeasurementSite.values.byName(row['site']! as String),
    centimetres: (row['centimetres']! as num).toDouble(),
    note: row['note']! as String,
  );

  void addBodyReading(
    BodyReading reading, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO body_readings (id, measured_at, metric, value, note, '
        'created_at, updated_at, source, local_day, utc_offset_minutes) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          reading.id,
          reading.measuredAt.millisecondsSinceEpoch,
          reading.metric.name,
          reading.value,
          reading.note,
          now,
          now,
          source.name,
          localDayOf(reading.measuredAt),
          reading.measuredAt.timeZoneOffset.inMinutes,
        ],
      );
      _db.audit(
        entityType: 'body_reading',
        entityId: reading.id,
        action: 'create',
        source: source,
      );
    });
  }

  /// Readings of [metric] taken in `[start, end)`, oldest first.
  List<BodyReading> bodyReadingsBetween(
    BodyMetric metric,
    DateTime start,
    DateTime end,
  ) => [
    for (final row in _db.select(
      'SELECT * FROM body_readings WHERE deleted_at IS NULL AND metric = ? '
      'AND measured_at >= ? AND measured_at < ? ORDER BY measured_at',
      [metric.name, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      _bodyReadingFrom(row),
  ];

  /// The last reading of each metric that has one.
  Map<BodyMetric, BodyReading> latestBodyReadings() => {
    for (final row in _db.select(
      'SELECT * FROM body_readings WHERE deleted_at IS NULL '
      'ORDER BY measured_at',
    ))
      BodyMetric.values.byName(row['metric']! as String): _bodyReadingFrom(row),
  };

  BodyReading _bodyReadingFrom(Map<String, Object?> row) => BodyReading(
    id: row['id']! as String,
    measuredAt: DateTime.fromMillisecondsSinceEpoch(row['measured_at']! as int),
    metric: BodyMetric.values.byName(row['metric']! as String),
    value: (row['value']! as num).toDouble(),
    note: row['note']! as String,
  );

  List<BodyWeight> weightsBetween(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM body_weights WHERE deleted_at IS NULL '
      'AND measured_at >= ? AND measured_at < ? ORDER BY measured_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      _weightFrom(row),
  ];

  BodyWeight _weightFrom(Map<String, Object?> row) => BodyWeight(
    id: row['id']! as String,
    measuredAt: DateTime.fromMillisecondsSinceEpoch(row['measured_at']! as int),
    weightKg: (row['weight_kg']! as num).toDouble(),
    note: row['note']! as String,
  );

  /// Check-ins recorded in `[start, end)`, oldest first.
  List<WellnessEntry> wellnessBetween(DateTime start, DateTime end) => [
    for (final row in _db.select(
      'SELECT * FROM wellness_entries WHERE deleted_at IS NULL '
      'AND recorded_at >= ? AND recorded_at < ? ORDER BY recorded_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      _wellnessFrom(row),
  ];

  WellnessEntry _wellnessFrom(Map<String, Object?> row) => WellnessEntry(
    id: row['id']! as String,
    recordedAt: DateTime.fromMillisecondsSinceEpoch(row['recorded_at']! as int),
    kind: WellnessKind.values.byName(row['kind']! as String),
    score: row['score']! as int,
    note: row['note']! as String,
  );

  /// Stores a note about the day it was written on.
  void addNote(Note note) {
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'INSERT INTO notes (id, text, noted_at, local_day, '
        'utc_offset_minutes, created_at, updated_at, source) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [
          note.id,
          note.text,
          note.notedAt.millisecondsSinceEpoch,
          localDayOf(note.notedAt),
          note.notedAt.timeZoneOffset.inMinutes,
          now,
          now,
          ChangeSource.local.name,
        ],
      );
      _db.audit(entityType: 'note', entityId: note.id, action: 'create');
    });
  }

  void updateNote(Note note) => _update('notes', note.id, {'text': note.text});

  Note _noteFrom(Map<String, Object?> row) => Note(
    id: row['id']! as String,
    notedAt: DateTime.fromMillisecondsSinceEpoch(row['noted_at']! as int),
    text: row['text']! as String,
  );

  /// The month's records of [table] by the day each was taken on, with
  /// the time it was taken as lived, for the timeline.
  List<(int, DateTime, T)> _inDays<T>(
    String table,
    String instantColumn,
    DateTime start,
    DateTime end,
    T Function(Map<String, Object?> row) read,
  ) => [
    for (final row in _db.select(
      'SELECT *, ${AppDatabase.localDaySql(instantColumn)} AS day '
      'FROM $table WHERE deleted_at IS NULL AND day BETWEEN ? AND ? '
      'ORDER BY $instantColumn',
      [localDayOf(start), localDayOf(end.subtract(const Duration(days: 1)))],
    ))
      (
        row['day']! as int,
        asLived(
          DateTime.fromMillisecondsSinceEpoch(row[instantColumn]! as int),
          row['utc_offset_minutes'] as int?,
        ),
        read(row),
      ),
  ];

  /// The four journal tables, with the name each is audited under.
  static const _tables = {
    'body_weights': 'body_weight',
    'body_measurements': 'body_measurement',
    'body_readings': 'body_reading',
    'sleep_entries': 'sleep_entry',
    'wellness_entries': 'wellness_entry',
    'notes': 'note',
  };

  /// Which journal table holds [id], deleted or not.
  String? _tableOf(String id) {
    for (final table in _tables.keys) {
      if (_db.select('SELECT 1 FROM $table WHERE id = ?', [id]).isNotEmpty) {
        return table;
      }
    }
    return null;
  }

  /// A live journal record — a [BodyWeight], [BodyMeasurement],
  /// [SleepEntry] or [WellnessEntry] — or null when there is none.
  Object? byId(String id) {
    final table = _tableOf(id);
    if (table == null) return null;
    final rows = _db.select(
      'SELECT * FROM $table WHERE id = ? AND deleted_at IS NULL',
      [id],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return switch (table) {
      'body_weights' => _weightFrom(row),
      'body_measurements' => _measurementFrom(row),
      'body_readings' => _bodyReadingFrom(row),
      'sleep_entries' => _sleepFrom(row),
      'notes' => _noteFrom(row),
      _ => _wellnessFrom(row),
    };
  }

  /// Where [id] came from.
  ChangeSource? sourceOf(String id) {
    final table = _tableOf(id);
    if (table == null) return null;
    final row = _db.select('SELECT source FROM $table WHERE id = ?', [id]);
    return ChangeSource.values.byName(row.single['source']! as String);
  }

  void updateWeight(BodyWeight weight) => _update('body_weights', weight.id, {
    'weight_kg': weight.weightKg,
    'note': weight.note,
  });

  void updateBodyReading(BodyReading reading) => _update(
    'body_readings',
    reading.id,
    {'value': reading.value, 'note': reading.note},
  );

  void updateMeasurement(BodyMeasurement measurement) => _update(
    'body_measurements',
    measurement.id,
    {'centimetres': measurement.centimetres, 'note': measurement.note},
  );

  /// Rewrites a sleep. Its times are part of what it records, so unlike
  /// a weight a corrected sleep can move to another morning.
  void updateSleep(SleepEntry entry) => _update('sleep_entries', entry.id, {
    'duration_minutes': entry.duration.inMinutes,
    'score': entry.score,
    'note': entry.note,
    'slept_at': entry.sleptAt.millisecondsSinceEpoch,
    'started_at': entry.startedAt?.millisecondsSinceEpoch,
    'kind': entry.kind.name,
    'local_day': localDayOf(entry.sleptAt),
    'utc_offset_minutes': entry.sleptAt.timeZoneOffset.inMinutes,
  });

  void updateWellness(WellnessEntry entry) => _update(
    'wellness_entries',
    entry.id,
    {'score': entry.score, 'note': entry.note},
  );

  /// Writes [values] over a record, recording what they replaced. The
  /// time it was taken is not among them: correcting a weight does not
  /// move it to another day.
  void _update(
    String table,
    String id,
    Map<String, Object?> values, {
    ChangeSource source = ChangeSource.local,
  }) {
    _db.transaction(() {
      final previous = _db.select(
        'SELECT ${values.keys.join(', ')} FROM $table WHERE id = ?',
        [id],
      ).single;
      final assignments = values.keys.map((column) => '$column = ?');
      _db.execute(
        'UPDATE $table SET ${assignments.join(', ')}, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [...values.values, _db.now().millisecondsSinceEpoch, id],
      );
      _db.audit(
        entityType: _tables[table]!,
        entityId: id,
        action: 'edit',
        source: source,
        payload: {
          'previous': {...previous},
        },
      );
    });
  }

  /// Tombstones [id]; [restore] takes it back.
  void delete(String id) => _setDeleted(id, deleted: true);

  void restore(String id) => _setDeleted(id, deleted: false);

  void _setDeleted(String id, {required bool deleted}) {
    final table = _tableOf(id)!;
    _db.transaction(() {
      final now = _db.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE $table SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1 WHERE id = ?',
        [deleted ? now : null, now, id],
      );
      _db.audit(
        entityType: _tables[table]!,
        entityId: id,
        action: deleted ? 'delete' : 'restore',
      );
    });
  }
}

/// Body weights as log rows.
class BodyWeightTimelineSource extends TimelineSource {
  BodyWeightTimelineSource(this._journal);

  final JournalRepository _journal;

  @override
  RecordCategory get category => RecordCategory.body;

  @override
  DateTime? earliest() {
    final dates = [
      ?_journal._earliest('body_weights', 'measured_at'),
      ?_journal._earliest('body_measurements', 'measured_at'),
    ]..sort();
    return dates.firstOrNull;
  }

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final (_, at, weight) in _weights(start, end))
      (
        at,
        TimelineEntry(
          timeLabel: formatTimeOfDay(at),
          at: at,
          recordId: weight.id,
          category: RecordCategory.body,
          title: '體重 ${_label(weight)}',
          detail: weight.note,
        ),
      ),
    for (final (_, at, measurement) in _measurements(start, end))
      (
        at,
        TimelineEntry(
          timeLabel: formatTimeOfDay(at),
          at: at,
          recordId: measurement.id,
          category: RecordCategory.body,
          title: '${measurement.site.label} ${_size(measurement)}',
          detail: measurement.note,
        ),
      ),
  ];

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    // A weight is the headline of a day that has both.
    for (final (day, _, measurement) in _measurements(start, end))
      day % 100: '${measurement.site.label} ${_size(measurement)}',
    for (final (day, _, weight) in _weights(start, end))
      day % 100: _label(weight),
  };

  List<(int, DateTime, BodyWeight)> _weights(DateTime start, DateTime end) =>
      _journal._inDays(
        'body_weights',
        'measured_at',
        start,
        end,
        _journal._weightFrom,
      );

  List<(int, DateTime, BodyMeasurement)> _measurements(
    DateTime start,
    DateTime end,
  ) => _journal._inDays(
    'body_measurements',
    'measured_at',
    start,
    end,
    _journal._measurementFrom,
  );

  static String _label(BodyWeight weight) =>
      '${formatWeight(weight.weightKg)} kg';

  static String _size(BodyMeasurement measurement) =>
      '${formatWeight(measurement.centimetres)} cm';
}

/// Nights of sleep as log rows.
class SleepTimelineSource extends TimelineSource {
  SleepTimelineSource(this._journal);

  final JournalRepository _journal;

  @override
  RecordCategory get category => RecordCategory.wellness;

  @override
  DateTime? earliest() => _journal._earliest('sleep_entries', 'slept_at');

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final (_, at, night) in _nights(start, end))
      (
        at,
        TimelineEntry(
          timeLabel: formatTimeOfDay(at),
          at: at,
          recordId: night.id,
          category: RecordCategory.wellness,
          title: _label(night),
          detail: [
            if (night.score != null) '品質 ${night.score} / 5',
            if (night.note.isNotEmpty) '備註：${night.note}',
          ].join(' · '),
        ),
      ),
  ];

  @override
  /// A day's line is about its night; a nap has its own row.
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    for (final (day, _, night) in _nights(start, end))
      if (night.kind == SleepKind.night) day % 100: _label(night),
  };

  List<(int, DateTime, SleepEntry)> _nights(DateTime start, DateTime end) =>
      _journal._inDays(
        'sleep_entries',
        'slept_at',
        start,
        end,
        _journal._sleepFrom,
      );

  static String _label(SleepEntry sleep) =>
      '${sleep.kind.label} ${formatHoursMinutes(sleep.duration)}';
}

/// Energy, mood and symptom check-ins as log rows.
class WellnessTimelineSource extends TimelineSource {
  WellnessTimelineSource(this._journal);

  final JournalRepository _journal;

  @override
  RecordCategory get category => RecordCategory.wellness;

  @override
  DateTime? earliest() => _journal._earliest('wellness_entries', 'recorded_at');

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final (_, at, entry) in _entries(start, end))
      (
        at,
        TimelineEntry(
          timeLabel: formatTimeOfDay(at),
          at: at,
          recordId: entry.id,
          category: RecordCategory.wellness,
          title: _label(entry),
          detail: entry.note.isEmpty ? '' : '備註：${entry.note}',
        ),
      ),
  ];

  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => {
    for (final (day, _, entry) in _entries(start, end))
      day % 100: _label(entry),
  };

  List<(int, DateTime, WellnessEntry)> _entries(DateTime start, DateTime end) =>
      _journal._inDays(
        'wellness_entries',
        'recorded_at',
        start,
        end,
        _journal._wellnessFrom,
      );

  static String _label(WellnessEntry entry) =>
      '${entry.kind.label} ${entry.score} / 5';
}

/// Notes about a day, as rows of their own under the day's state.
class NoteTimelineSource extends TimelineSource {
  NoteTimelineSource(this._journal);

  final JournalRepository _journal;

  @override
  RecordCategory get category => RecordCategory.wellness;

  @override
  DateTime? earliest() => _journal._earliest('notes', 'noted_at');

  @override
  List<(DateTime, TimelineEntry)> entriesIn(DateTime start, DateTime end) => [
    for (final (_, at, note) in _notes(start, end))
      (
        at,
        TimelineEntry(
          timeLabel: formatTimeOfDay(at),
          at: at,
          recordId: note.id,
          category: RecordCategory.wellness,
          title: '筆記',
          detail: note.text,
        ),
      ),
  ];

  /// A note is not a summary of a day; the day's line stays about sleep
  /// and check-ins.
  @override
  Map<int, String> summariesIn(DateTime start, DateTime end) => const {};

  List<(int, DateTime, Note)> _notes(DateTime start, DateTime end) =>
      _journal._inDays('notes', 'noted_at', start, end, _journal._noteFrom);
}
