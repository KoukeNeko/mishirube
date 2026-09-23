enum WellnessKind {
  energy('精力'),
  mood('心情'),
  symptom('症狀'),
  // Kept for a rating given without a length; a night's own quality lives
  // on [SleepEntry].
  sleep('睡眠品質');

  const WellnessKind(this.label);

  final String label;
}

/// Which sleep of a day a record is: the main one, or a nap beside it.
enum SleepKind {
  night('睡眠'),
  nap('小睡');

  const SleepKind(this.label);

  final String label;
}

/// What a record's length measures. Time in bed is not time asleep: an
/// iPhone without a watch only knows when the phone was put down.
enum SleepMeasure {
  asleep('睡著時間'),
  inBed('在床時間');

  const SleepMeasure(this.label);

  final String label;
}

/// A sleep: how long, and how it felt when the user says so.
///
/// A record read from a health platform also says when it started, what
/// its length measures and which source it was taken from; its stretches
/// by stage and the night's other readings are kept beside it.
class SleepEntry {
  const SleepEntry({
    required this.id,
    required this.sleptAt,
    required this.duration,
    this.score,
    this.note = '',
    this.startedAt,
    this.kind = SleepKind.night,
    this.measure = SleepMeasure.asleep,
    this.sourceName = '',
  });

  final String id;

  /// When the sleep ended: the morning a night is logged against.
  final DateTime sleptAt;
  final Duration duration;

  /// 1–5, or null when the user did not rate it.
  final int? score;
  final String note;

  /// When the sleep began; null for a length typed in by hand.
  final DateTime? startedAt;
  final SleepKind kind;
  final SleepMeasure measure;

  /// The device or app the figures were taken from, such as
  /// `Apple Watch`; empty for a record typed in by hand.
  final String sourceName;
}

/// What a stretch of a health platform's sleep record was, in terms both
/// platforms share. Apple's Core and Health Connect's Light are the same
/// row here but not the same algorithm, so the platform's own name is
/// kept with each stretch.
enum SleepStage {
  inBed('在床'),
  awake('清醒'),

  /// Asleep, with no stage given.
  asleep('睡著'),
  core('淺層／核心'),
  deep('深層'),
  rem('REM');

  const SleepStage(this.label);

  final String label;

  bool get isAsleep =>
      this == asleep || this == core || this == deep || this == rem;

  /// A stage a staging algorithm chose, rather than "asleep" or "in bed".
  bool get isDetailed => this == core || this == deep || this == rem;
}

/// One stretch from a platform's sleep record, as it came: Apple Health
/// stores a night as many of these, from every device that watched it.
class SleepSample {
  const SleepSample({
    required this.start,
    required this.end,
    required this.stage,
    this.source = '',
    this.sourceName = '',
    this.native = '',
    this.isManual = false,
  });

  final DateTime start;
  final DateTime end;
  final SleepStage stage;

  /// A stable key for who recorded it: the app's bundle id or package.
  final String source;

  /// What to call that source: the device when there is one, else the app.
  final String sourceName;

  /// The platform's own name for the stage, such as
  /// `HKCategoryValueSleepAnalysis.asleepCore`.
  final String native;

  /// Typed in by hand in the platform, rather than measured.
  final bool isManual;

  Duration get length => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is SleepSample &&
      other.start == start &&
      other.end == end &&
      other.stage == stage &&
      other.source == source &&
      other.sourceName == sourceName &&
      other.native == native &&
      other.isManual == isManual;

  @override
  int get hashCode =>
      Object.hash(start, end, stage, source, sourceName, native, isManual);
}

/// A reading a platform takes overnight, reported the way that platform
/// measures it. Heart rate variability is SDNN from Apple Health and
/// RMSSD from Health Connect: different statistics, never one series.
enum OvernightMeasure {
  heartRate('心率', '次/分'),
  respiratoryRate('呼吸速率', '次/分'),
  oxygenSaturation('血氧', '%'),

  /// Apple Health's nightly wrist temperature, in degrees.
  wristTemperature('手腕溫度', '°C'),

  /// Health Connect's skin temperature, as its change from the baseline
  /// the platform keeps.
  skinTemperatureChange('皮膚溫度變化', '°C'),
  hrvSdnn('心率變異度（SDNN）', 'ms'),
  hrvRmssd('心率變異度（RMSSD）', 'ms'),

  /// Apple Watch's breathing disturbances, with Apple's own reading of
  /// whether they are elevated.
  breathingDisturbances('呼吸干擾', '');

  const OvernightMeasure(this.label, this.unit);

  final String label;
  final String unit;
}

/// One measure over one sleep: the range of the samples that fell in it.
class OvernightReading {
  const OvernightReading({
    required this.measure,
    required this.minimum,
    required this.maximum,
    required this.average,
    required this.count,
    this.isElevated,
  });

  final OvernightMeasure measure;
  final double minimum;
  final double maximum;
  final double average;
  final int count;

  /// The platform's classification, for breathing disturbances only.
  final bool? isElevated;

  @override
  bool operator ==(Object other) =>
      other is OvernightReading &&
      other.measure == measure &&
      other.minimum == minimum &&
      other.maximum == maximum &&
      other.average == average &&
      other.count == count &&
      other.isElevated == isElevated;

  @override
  int get hashCode =>
      Object.hash(measure, minimum, maximum, average, count, isElevated);
}

/// A self-rated 1–5 check-in with an optional note.
class WellnessEntry {
  const WellnessEntry({
    required this.id,
    required this.recordedAt,
    required this.kind,
    required this.score,
    this.note = '',
  });

  final String id;
  final DateTime recordedAt;
  final WellnessKind kind;
  final int score;
  final String note;
}
