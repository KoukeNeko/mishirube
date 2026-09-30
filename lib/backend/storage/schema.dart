import 'package:sqlite3/sqlite3.dart';

/// Columns every syncable entity carries: revision counts semantic changes,
/// `deleted_at` is the tombstone, and imported rows keep their batch so an
/// import can be undone as a whole.
const _entityColumns = '''
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  revision INTEGER NOT NULL DEFAULT 1,
  source TEXT NOT NULL DEFAULT 'local',
  import_batch_id TEXT REFERENCES import_batches(id)
''';

/// Which day a record belonged to for the person who lived it, as
/// yyyymmdd, plus the UTC offset in force when they recorded it. An
/// instant alone cannot answer "which day was that": the same moment is
/// Monday night in Taipei and Monday morning in Los Angeles.
const _livedColumns = '''
  local_day INTEGER,
  utc_offset_minutes INTEGER''';

/// Schema steps; step `i` upgrades `user_version` i to i + 1. Never edit a
/// released step – append a new one.
///
/// Step 0 is the baseline the steps restarted from. A store from before
/// it is a different file, never opened or upgraded.
final List<String> _migrations = [
  '''
  CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );

  CREATE TABLE import_batches (
    id TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    file_name TEXT,
    content_sha256 TEXT NOT NULL,
    imported_at INTEGER NOT NULL,
    undone_at INTEGER,
    summary TEXT
  );
  CREATE UNIQUE INDEX import_batches_live_content
    ON import_batches(content_sha256) WHERE undone_at IS NULL;

  CREATE TABLE audit_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    occurred_at INTEGER NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,
    source TEXT NOT NULL,
    import_batch_id TEXT,
    payload TEXT
  );
  CREATE INDEX audit_events_entity ON audit_events(entity_type, entity_id);

  CREATE TABLE exercises (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    aliases TEXT NOT NULL,
    -- Names the user gave it, kept apart from the catalog's own aliases
    -- so a catalog update never overwrites them.
    personal_aliases TEXT NOT NULL DEFAULT '[]',
    equipment TEXT NOT NULL,
    primary_muscles TEXT NOT NULL,
    secondary_muscles TEXT NOT NULL,
    pattern TEXT NOT NULL,
    tracking_type TEXT NOT NULL,
    ownership TEXT NOT NULL,
    cues TEXT NOT NULL,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    -- Hidden exercises stay in history and in old workouts; they are
    -- only kept out of pickers and suggestions.
    is_hidden INTEGER NOT NULL DEFAULT 0,
    is_in_home_gym INTEGER NOT NULL DEFAULT 1,
    -- How its two sides work, the movement it is a version of, and its
    -- demonstration frames (asset paths, as JSON).
    laterality TEXT NOT NULL DEFAULT 'bilateral',
    family TEXT NOT NULL DEFAULT '',
    frames TEXT NOT NULL DEFAULT '[]',
    $_entityColumns
  );

  CREATE TABLE external_exercise_names (
    source TEXT NOT NULL,
    name TEXT NOT NULL,
    exercise_id TEXT NOT NULL REFERENCES exercises(id),
    import_batch_id TEXT REFERENCES import_batches(id),
    PRIMARY KEY (source, name)
  );

  CREATE TABLE routines (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    program_name TEXT NOT NULL,
    estimated_minutes INTEGER NOT NULL,
    $_entityColumns
  );

  CREATE TABLE routine_exercises (
    routine_id TEXT NOT NULL REFERENCES routines(id),
    position INTEGER NOT NULL,
    exercise_id TEXT NOT NULL REFERENCES exercises(id),
    sets INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    rir INTEGER,
    target_weight_kg REAL NOT NULL,
    progression_label TEXT NOT NULL,
    is_unilateral INTEGER NOT NULL DEFAULT 0,
    -- Done in turn with the one after it (a superset); null for no.
    joins_next INTEGER,
    -- The sets one by one, as [[kg, reps], ...], when they differ from
    -- set to set; null when every set is alike.
    set_loads TEXT,
    PRIMARY KEY (routine_id, position)
  );

  CREATE TABLE workouts (
    id TEXT PRIMARY KEY,
    routine_id TEXT REFERENCES routines(id),
    name TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    finished_at INTEGER,
    paused_at INTEGER,
    paused_total_ms INTEGER NOT NULL DEFAULT 0,
    current_exercise INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    fingerprint TEXT,
    -- How a finished workout felt (tooLight, right, tooHard); null until
    -- the lifter rates it.
    workload TEXT,
    $_livedColumns,
    $_entityColumns
  );
  CREATE UNIQUE INDEX workouts_single_active
    ON workouts(status) WHERE status = 'in_progress' AND deleted_at IS NULL;
  CREATE INDEX workouts_started ON workouts(started_at);
  CREATE INDEX workouts_fingerprint ON workouts(fingerprint);

  CREATE TABLE workout_exercises (
    workout_id TEXT NOT NULL REFERENCES workouts(id),
    position INTEGER NOT NULL,
    exercise_id TEXT NOT NULL REFERENCES exercises(id),
    exercise_name TEXT NOT NULL,
    is_pr_candidate INTEGER NOT NULL DEFAULT 0,
    joins_next INTEGER,
    PRIMARY KEY (workout_id, position)
  );
  CREATE INDEX workout_exercises_exercise ON workout_exercises(exercise_id);

  CREATE TABLE workout_sets (
    workout_id TEXT NOT NULL REFERENCES workouts(id),
    exercise_position INTEGER NOT NULL,
    position INTEGER NOT NULL,
    set_type TEXT NOT NULL,
    weight_kg REAL NOT NULL,
    reps INTEGER NOT NULL,
    rir INTEGER,
    rpe REAL,
    duration_s INTEGER,
    distance_m REAL,
    previous_weight_kg REAL,
    previous_reps INTEGER,
    is_done INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (workout_id, exercise_position, position)
  );

  -- Programs: routines trained in turn or on set weekdays. Where a
  -- program stands is derived from the workouts that trained its days
  -- and the days the user chose to skip, never stored.
  CREATE TABLE programs (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    schedule TEXT NOT NULL,
    started_at INTEGER,
    ended_at INTEGER,
    $_entityColumns
  );
  CREATE TABLE program_days (
    program_id TEXT NOT NULL REFERENCES programs(id),
    position INTEGER NOT NULL,
    routine_id TEXT NOT NULL REFERENCES routines(id),
    weekday INTEGER,
    PRIMARY KEY (program_id, position)
  );
  -- A workout started as a program's day.
  CREATE TABLE program_workouts (
    workout_id TEXT PRIMARY KEY REFERENCES workouts(id),
    program_id TEXT NOT NULL REFERENCES programs(id),
    day_position INTEGER NOT NULL,
    $_entityColumns
  );
  -- A program's day the user chose to skip.
  CREATE TABLE program_skips (
    id TEXT PRIMARY KEY,
    program_id TEXT NOT NULL REFERENCES programs(id),
    day_position INTEGER NOT NULL,
    skipped_at INTEGER NOT NULL,
    $_entityColumns
  );

  -- Foods the user saved to log again, and the brand data shipped with
  -- the app (source 'catalogue'), which is replaced wholesale on every
  -- launch. The five figures are optional: a food whose label was never
  -- read has no calorie figure, which is not 0.
  CREATE TABLE foods (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    brand TEXT NOT NULL DEFAULT '',
    -- The brand's own line (CITY CAFE, CITY TEA), so one chain's menu can
    -- be read in the sections it is sold in.
    series TEXT NOT NULL DEFAULT '',
    -- What the maker says about it beside its name: 一部店舗限定.
    note TEXT NOT NULL DEFAULT '',
    -- Where it is sold (ISO 3166-1, TW): one chain prints different
    -- figures for the same drink in each country.
    country TEXT NOT NULL DEFAULT '',
    serving_label TEXT NOT NULL,
    serving_amount REAL NOT NULL DEFAULT 1,
    serving_unit TEXT NOT NULL DEFAULT 'serving',
    kcal INTEGER,
    protein_g INTEGER,
    carb_g INTEGER,
    fat_g INTEGER,
    fibre_g INTEGER,
    -- Cup sizes. A size is a food that belongs to another food, because
    -- sizes are not proportional: a Starbucks americano is 98 mg of
    -- caffeine in a 240 ml short and 195 mg in a 350 ml tall.
    parent_id TEXT REFERENCES foods(id),
    size_name TEXT NOT NULL DEFAULT '',
    -- Eaten or drunk, which is not how it is measured: soup is poured
    -- and is not a drink, powder is weighed and becomes one.
    consumption_kind TEXT NOT NULL DEFAULT 'unknown',
    -- What kind of number a figure is: Taiwan has chains publish a
    -- maximum caffeine figure per cup, which is not the amount in it.
    value_type TEXT NOT NULL DEFAULT 'declared',
    source_url TEXT NOT NULL DEFAULT '',
    checked_at INTEGER,
    -- Other words it answers to in search, such as a brand's English
    -- name. The catalogue writes them; nothing shows them.
    search_terms TEXT NOT NULL DEFAULT '',
    -- Its volume is the cup it comes in rather than the drink, as chains
    -- publish it. Such a volume is never counted as fluid drunk.
    is_cup_capacity INTEGER NOT NULL DEFAULT 0,
    -- How its caffeine was typed: per 100 g/ml, as bottled drinks print
    -- it, or the total in one serving. Stored per serving either way.
    caffeine_basis TEXT NOT NULL DEFAULT 'serving',
    -- The allergens its maker declares, as Allergen names separated by
    -- commas: empty for none declared, null for nobody having said.
    allergens TEXT,
    barcode TEXT,
    $_entityColumns
  );
  CREATE INDEX foods_name ON foods(name);
  CREATE INDEX foods_parent ON foods(parent_id);

  -- Nutrients beyond the five every record carries. A row exists only
  -- when the amount is actually known: a missing row is nobody having
  -- written it down, which is not the same as zero.
  CREATE TABLE food_nutrients (
    food_id TEXT NOT NULL REFERENCES foods(id),
    nutrient TEXT NOT NULL,
    amount REAL NOT NULL,
    PRIMARY KEY (food_id, nutrient)
  );

  -- Starred foods, one row per food or cup size. Kept apart from foods
  -- because the catalogue's rows are replaced wholesale on every launch,
  -- and a star stored on them would go with them.
  CREATE TABLE food_favorites (
    food_id TEXT PRIMARY KEY,
    $_entityColumns
  );

  -- What was eaten. A meal copies its figures when logged: correcting the
  -- food later is not a claim about what was eaten.
  CREATE TABLE meals (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    -- How much was eaten, in words, when that is not a food's servings:
    -- an AI draft's `180 g`. Empty when not said.
    amount TEXT NOT NULL DEFAULT '',
    -- Who made it, copied from the food when logged and editable on the
    -- record; empty when nobody said.
    brand TEXT NOT NULL DEFAULT '',
    eaten_at INTEGER NOT NULL,
    kcal INTEGER,
    protein_g INTEGER,
    carb_g INTEGER,
    fat_g INTEGER,
    fibre_g INTEGER,
    -- What was drunk, when logged by volume. It is the drink, not the
    -- water in it: no hydration factor is applied anywhere.
    millilitres INTEGER,
    consumption_kind TEXT NOT NULL DEFAULT 'unknown',
    -- Which sitting it was, when the user said. The five values are the
    -- ones Health Connect defines.
    meal_type TEXT,
    value_type TEXT NOT NULL DEFAULT 'declared',
    quality_tag TEXT NOT NULL,
    is_estimated INTEGER NOT NULL DEFAULT 0,
    -- Starred to log again without going looking.
    is_favorite INTEGER NOT NULL DEFAULT 0,
    -- Which saved food it was logged from, and how many servings, so the
    -- next time can start from the usual portion. The figures stay
    -- copied; these do not bring the food's current numbers back.
    food_id TEXT,
    servings REAL,
    -- A meal of several things is a group of them, each keeping its own
    -- record and figures; null for a meal on its own.
    group_id TEXT,
    -- Whose rules the label its figures came from follows, copied from
    -- the food: the EU's salt is sodium x 2.5, Japan's x 2.54. Empty
    -- when no label stood behind them.
    label_country TEXT NOT NULL DEFAULT '',
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX meals_eaten ON meals(eaten_at);

  -- What a meal of several items is called, when it is called something
  -- other than its items: an AI draft's name for it, or one typed. Keyed
  -- by the group, so taking the meal apart and putting it back keeps it.
  CREATE TABLE meal_groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    $_entityColumns
  );

  CREATE TABLE meal_dishes (
    meal_id TEXT NOT NULL REFERENCES meals(id),
    position INTEGER NOT NULL,
    name TEXT NOT NULL,
    quantity_label TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    PRIMARY KEY (meal_id, position)
  );

  CREATE TABLE dish_components (
    meal_id TEXT NOT NULL REFERENCES meals(id),
    dish_position INTEGER NOT NULL,
    position INTEGER NOT NULL,
    name TEXT NOT NULL,
    amount_label TEXT NOT NULL,
    source_label TEXT NOT NULL,
    PRIMARY KEY (meal_id, dish_position, position)
  );

  -- Copied from the food when logged, like the calories.
  CREATE TABLE meal_nutrients (
    meal_id TEXT NOT NULL REFERENCES meals(id),
    nutrient TEXT NOT NULL,
    amount REAL NOT NULL,
    PRIMARY KEY (meal_id, nutrient)
  );

  CREATE TABLE body_weights (
    id TEXT PRIMARY KEY,
    measured_at INTEGER NOT NULL,
    weight_kg REAL NOT NULL,
    note TEXT NOT NULL,
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX body_weights_measured ON body_weights(measured_at);

  -- Tape measurements, one row per site per measurement.
  CREATE TABLE body_measurements (
    id TEXT PRIMARY KEY,
    measured_at INTEGER NOT NULL,
    site TEXT NOT NULL,
    centimetres REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX body_measurements_at ON body_measurements(measured_at);

  -- Body figures other than weight and girth (height, body fat, muscle
  -- and the rest a body composition scale reports), one row per figure
  -- per reading.
  CREATE TABLE body_readings (
    id TEXT PRIMARY KEY,
    measured_at INTEGER NOT NULL,
    metric TEXT NOT NULL,
    value REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX body_readings_at ON body_readings(metric, measured_at);

  CREATE TABLE wellness_entries (
    id TEXT PRIMARY KEY,
    recorded_at INTEGER NOT NULL,
    kind TEXT NOT NULL,
    score INTEGER NOT NULL,
    note TEXT NOT NULL,
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX wellness_entries_recorded ON wellness_entries(recorded_at);

  -- Sleep is its own record: a length, and how it felt when the user
  -- says. One read from a health platform also has when it began,
  -- whether it was the day's night or a nap beside it, whether its
  -- length is time asleep or only time in bed, which source it is shown
  -- from, and the source the user picked over the default.
  CREATE TABLE sleep_entries (
    id TEXT PRIMARY KEY,
    slept_at INTEGER NOT NULL,
    duration_minutes INTEGER NOT NULL,
    score INTEGER,
    note TEXT NOT NULL,
    started_at INTEGER,
    kind TEXT NOT NULL DEFAULT 'night',
    measure TEXT NOT NULL DEFAULT 'asleep',
    source_name TEXT NOT NULL DEFAULT '',
    chosen_source TEXT,
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX sleep_entries_slept ON sleep_entries(slept_at);

  -- Every source's stretches of a sleep by stage, with the platform's own
  -- name for the stage, so another source can be shown without reading
  -- the platform again. recorded_by is the app or device that measured
  -- it, apart from source, which says how the row reached this database.
  CREATE TABLE sleep_segments (
    id TEXT PRIMARY KEY,
    sleep_id TEXT NOT NULL REFERENCES sleep_entries(id),
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    stage TEXT NOT NULL,
    native_stage TEXT NOT NULL,
    recorded_by TEXT NOT NULL,
    recorded_by_name TEXT NOT NULL,
    is_manual INTEGER NOT NULL,
    $_entityColumns
  );
  CREATE INDEX sleep_segments_sleep ON sleep_segments(sleep_id)
    WHERE deleted_at IS NULL;

  -- What the platform measured over a sleep, one row per measure, in the
  -- statistic the platform reports it in.
  CREATE TABLE sleep_readings (
    id TEXT PRIMARY KEY,
    sleep_id TEXT NOT NULL REFERENCES sleep_entries(id),
    measure TEXT NOT NULL,
    minimum REAL NOT NULL,
    maximum REAL NOT NULL,
    average REAL NOT NULL,
    sample_count INTEGER NOT NULL,
    is_elevated INTEGER,
    $_entityColumns
  );
  CREATE INDEX sleep_readings_sleep ON sleep_readings(sleep_id)
    WHERE deleted_at IS NULL;

  -- General exercise: one stretch of time doing something, as opposed to
  -- the sets of a strength workout. A running one has a start, and its
  -- end and length are only filled in when it stops. One at a time.
  CREATE TABLE activities (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    native_type TEXT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    elapsed_ms INTEGER NOT NULL,
    distance_m REAL,
    elevation_gain_m REAL,
    effort INTEGER,
    note TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'finished',
    paused_at INTEGER,
    paused_ms INTEGER NOT NULL DEFAULT 0,
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX activities_started ON activities(started_at);
  CREATE UNIQUE INDEX activities_single_active
    ON activities(status) WHERE status = 'in_progress' AND deleted_at IS NULL;

  -- What a health platform counted (hourly, already de-duplicated
  -- across devices) or measured (a day's average) about everyday
  -- movement and fitness. Read again on each sync: a bucket's value is
  -- replaced when the platform's has changed.
  CREATE TABLE activity_samples (
    id TEXT PRIMARY KEY,
    metric TEXT NOT NULL,
    started_at INTEGER NOT NULL,
    ended_at INTEGER NOT NULL,
    value REAL NOT NULL,
    $_entityColumns
  );
  CREATE INDEX activity_samples_metric
    ON activity_samples(metric, started_at) WHERE deleted_at IS NULL;

  -- How many days a week the user is aiming for, as a timeline: changing
  -- the goal appends a row, so a past week keeps the goal it was judged
  -- by. Whether anything is met is derived from the records, never stored.
  CREATE TABLE weekly_goals (
    id TEXT PRIMARY KEY,
    effective_from INTEGER NOT NULL,
    target_days INTEGER NOT NULL,
    $_entityColumns
  );
  CREATE INDEX weekly_goals_from ON weekly_goals(effective_from);

  -- Stretches where the goal does not apply: ill, injured, travelling.
  -- An open pause has no end yet.
  CREATE TABLE goal_pauses (
    id TEXT PRIMARY KEY,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    note TEXT NOT NULL DEFAULT '',
    $_entityColumns
  );

  -- Free-text notes. One about a day stands on its own in the log; one
  -- about a record belongs to that record, which is what parent_type and
  -- parent_id are for. Only day notes are written so far.
  CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    noted_at INTEGER NOT NULL,
    parent_type TEXT,
    parent_id TEXT,
    $_livedColumns,
    $_entityColumns
  );
  CREATE INDEX notes_day ON notes(local_day) WHERE deleted_at IS NULL;
  ''',
  // One body composition measurement: its weight and each figure share a
  // session id, so it opens, is corrected and goes as one. Records from
  // before are left without one rather than grouped by a guess.
  '''
  ALTER TABLE body_weights ADD COLUMN session_id TEXT;
  ALTER TABLE body_readings ADD COLUMN session_id TEXT;
  CREATE INDEX body_weights_session ON body_weights(session_id)
    WHERE session_id IS NOT NULL;
  CREATE INDEX body_readings_session ON body_readings(session_id)
    WHERE session_id IS NOT NULL;
  ''',
  // What a planned exercise asks of each set besides weight and reps: the
  // time of a plank, the distance of a run. Per-set plans keep theirs in
  // set_loads.
  '''
  ALTER TABLE routine_exercises ADD COLUMN target_seconds INTEGER;
  ALTER TABLE routine_exercises ADD COLUMN target_meters REAL;
  ''',
];

int get latestSchemaVersion => _migrations.length;

/// The steps themselves, for the test that pins them.
///
/// A released step must never change: a database that already ran it
/// will not run it again, so an edit only ever takes effect on fresh
/// installs and quietly gives the two different schemas.
List<String> get schemaSteps => List.unmodifiable(_migrations);

/// Brings [db] up to [latestSchemaVersion], all steps in one transaction.
void migrate(Database db) {
  final from = db.userVersion;
  if (from > latestSchemaVersion) {
    throw StateError(
      'Database schema $from is newer than this app ($latestSchemaVersion).',
    );
  }
  if (from == latestSchemaVersion) return;
  db.execute('BEGIN IMMEDIATE');
  try {
    for (var step = from; step < latestSchemaVersion; step++) {
      db.execute(_migrations[step]);
    }
    db.userVersion = latestSchemaVersion;
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
