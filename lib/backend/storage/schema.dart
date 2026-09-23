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

/// Schema steps; step `i` upgrades `user_version` i to i + 1. Never edit a
/// released step – append a new one.
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
    equipment TEXT NOT NULL,
    primary_muscles TEXT NOT NULL,
    secondary_muscles TEXT NOT NULL,
    pattern TEXT NOT NULL,
    tracking_type TEXT NOT NULL,
    ownership TEXT NOT NULL,
    cues TEXT NOT NULL,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    is_in_home_gym INTEGER NOT NULL DEFAULT 1,
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

  CREATE TABLE meals (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    eaten_at INTEGER NOT NULL,
    kcal INTEGER NOT NULL,
    protein_g INTEGER NOT NULL,
    carb_g INTEGER NOT NULL,
    fat_g INTEGER NOT NULL,
    quality_tag TEXT NOT NULL,
    is_estimated INTEGER NOT NULL DEFAULT 0,
    $_entityColumns
  );
  CREATE INDEX meals_eaten ON meals(eaten_at);

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

  CREATE TABLE body_weights (
    id TEXT PRIMARY KEY,
    measured_at INTEGER NOT NULL,
    weight_kg REAL NOT NULL,
    note TEXT NOT NULL,
    $_entityColumns
  );
  CREATE INDEX body_weights_measured ON body_weights(measured_at);

  CREATE TABLE wellness_entries (
    id TEXT PRIMARY KEY,
    recorded_at INTEGER NOT NULL,
    kind TEXT NOT NULL,
    score INTEGER NOT NULL,
    note TEXT NOT NULL,
    $_entityColumns
  );
  CREATE INDEX wellness_entries_recorded ON wellness_entries(recorded_at);
  ''',
  '''
  -- Hidden exercises stay in history and in old workouts; they are only
  -- kept out of pickers and suggestions.
  ALTER TABLE exercises ADD COLUMN is_hidden INTEGER NOT NULL DEFAULT 0;
  ''',
  '''
  -- Sleep is its own record: a length, and how it felt when the user says.
  CREATE TABLE sleep_entries (
    id TEXT PRIMARY KEY,
    slept_at INTEGER NOT NULL,
    duration_minutes INTEGER NOT NULL,
    score INTEGER,
    note TEXT NOT NULL,
    $_entityColumns
  );
  CREATE INDEX sleep_entries_slept ON sleep_entries(slept_at);
  ''',
  '''
  -- General exercise: one stretch of time doing something, as opposed to
  -- the sets of a strength workout.
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
    $_entityColumns
  );
  CREATE INDEX activities_started ON activities(started_at);
  ''',
  '''
  -- Names the user gave an exercise, kept apart from the catalog's own
  -- aliases so a catalog update never overwrites them.
  ALTER TABLE exercises
    ADD COLUMN personal_aliases TEXT NOT NULL DEFAULT '[]';
  ''',
  '''
  -- A session can now be running: it has a start, and its end and length
  -- are only filled in when it stops. One at a time, like a workout.
  ALTER TABLE activities ADD COLUMN status TEXT NOT NULL DEFAULT 'finished';
  ALTER TABLE activities ADD COLUMN paused_at INTEGER;
  ALTER TABLE activities ADD COLUMN paused_ms INTEGER NOT NULL DEFAULT 0;
  CREATE UNIQUE INDEX activities_single_active
    ON activities(status) WHERE status = 'in_progress' AND deleted_at IS NULL;
  ''',
  '''
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
  ''',
  '''
  -- Meals the user starred, to log again without going looking.
  ALTER TABLE meals ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;
  ''',
  '''
  -- Fibre, counted apart from the carbohydrate it is part of. Rows from
  -- before this step have no figure, which is not the same as none.
  ALTER TABLE meals ADD COLUMN fibre_g INTEGER NOT NULL DEFAULT 0;
  ''',
  '''
  -- Tape measurements, one row per site per measurement.
  CREATE TABLE body_measurements (
    id TEXT PRIMARY KEY,
    measured_at INTEGER NOT NULL,
    site TEXT NOT NULL,
    centimetres REAL NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    $_entityColumns
  );
  CREATE INDEX body_measurements_at ON body_measurements(measured_at);
  ''',
  '''
  -- Foods the user saved to log again. The private layer of the food
  -- catalogue: on this device only, every value entered by hand.
  CREATE TABLE foods (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    brand TEXT NOT NULL DEFAULT '',
    serving_label TEXT NOT NULL,
    kcal INTEGER NOT NULL,
    protein_g INTEGER NOT NULL,
    carb_g INTEGER NOT NULL,
    fat_g INTEGER NOT NULL,
    fibre_g INTEGER NOT NULL DEFAULT 0,
    $_entityColumns
  );
  CREATE INDEX foods_name ON foods(name);
  ''',
  '''
  -- A serving becomes a measurable amount, so a different portion can be
  -- worked out instead of retyped. Foods saved before this step keep
  -- whole servings, which is what they were entered as.
  ALTER TABLE foods ADD COLUMN serving_amount REAL NOT NULL DEFAULT 1;
  ALTER TABLE foods ADD COLUMN serving_unit TEXT NOT NULL DEFAULT 'serving';
  ''',
  '''
  -- Nutrients beyond the five every record carries. A row exists only
  -- when the amount is actually known: a missing row is nobody having
  -- written it down, which is not the same as zero.
  CREATE TABLE food_nutrients (
    food_id TEXT NOT NULL REFERENCES foods(id),
    nutrient TEXT NOT NULL,
    amount REAL NOT NULL,
    PRIMARY KEY (food_id, nutrient)
  );

  -- A meal copies what was known when it was logged, the way it already
  -- copies the calories: correcting the food later is not a claim about
  -- what was eaten.
  CREATE TABLE meal_nutrients (
    meal_id TEXT NOT NULL REFERENCES meals(id),
    nutrient TEXT NOT NULL,
    amount REAL NOT NULL,
    PRIMARY KEY (meal_id, nutrient)
  );
  ''',
  '''
  -- The five figures every record carries become optional. A food whose
  -- label was never read has no calorie figure, and storing that as 0
  -- was the app inventing a number nobody wrote down. SQLite cannot drop
  -- NOT NULL in place, so both tables are rebuilt.
  CREATE TABLE foods_new (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    brand TEXT NOT NULL DEFAULT '',
    serving_label TEXT NOT NULL,
    serving_amount REAL NOT NULL DEFAULT 1,
    serving_unit TEXT NOT NULL DEFAULT 'serving',
    kcal INTEGER,
    protein_g INTEGER,
    carb_g INTEGER,
    fat_g INTEGER,
    fibre_g INTEGER,
    $_entityColumns
  );
  INSERT INTO foods_new SELECT id, name, brand, serving_label,
    serving_amount, serving_unit, kcal, protein_g, carb_g, fat_g, fibre_g,
    created_at, updated_at, deleted_at, revision, source, import_batch_id
    FROM foods;
  DROP TABLE foods;
  ALTER TABLE foods_new RENAME TO foods;
  CREATE INDEX foods_name ON foods(name);

  CREATE TABLE meals_new (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    eaten_at INTEGER NOT NULL,
    kcal INTEGER,
    protein_g INTEGER,
    carb_g INTEGER,
    fat_g INTEGER,
    fibre_g INTEGER,
    quality_tag TEXT NOT NULL,
    is_estimated INTEGER NOT NULL DEFAULT 0,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    $_entityColumns
  );
  INSERT INTO meals_new SELECT id, name, eaten_at, kcal, protein_g, carb_g,
    fat_g, fibre_g, quality_tag, is_estimated, is_favorite,
    created_at, updated_at, deleted_at, revision, source, import_batch_id
    FROM meals;
  DROP TABLE meals;
  ALTER TABLE meals_new RENAME TO meals;
  CREATE INDEX meals_eaten ON meals(eaten_at);
  ''',
  '''
  -- What was drunk, when a meal was logged by volume. It is the drink,
  -- not the water in it: no hydration factor is applied anywhere.
  ALTER TABLE meals ADD COLUMN millilitres INTEGER;
  ''',
  '''
  -- Named portions: `一匙`, `一碗`. What one is worth belongs to the food,
  -- because no app can say what a spoonful of any given thing weighs.
  CREATE TABLE food_portions (
    food_id TEXT NOT NULL REFERENCES foods(id),
    position INTEGER NOT NULL,
    name TEXT NOT NULL,
    amount REAL NOT NULL,
    unit TEXT NOT NULL,
    PRIMARY KEY (food_id, position)
  );
  ''',
  '''
  -- Named portions are gone: one serving size per food is enough, and a
  -- second way to say how much was more to keep than it was worth.
  DROP TABLE food_portions;
  ''',
  '''
  -- Cup sizes. A size is a food that belongs to another food, because
  -- sizes are not proportional: a Starbucks americano is 98 mg of
  -- caffeine in a 240 ml short and 195 mg in a 350 ml tall, so the
  -- bigger cup is not the smaller one scaled up. Each size carries its
  -- own figures and reuses everything a food already has.
  ALTER TABLE foods ADD COLUMN parent_id TEXT REFERENCES foods(id);
  ALTER TABLE foods ADD COLUMN size_name TEXT NOT NULL DEFAULT '';
  CREATE INDEX foods_parent ON foods(parent_id);
  ''',
  '''
  -- Eaten or drunk, which is not the same question as how it is
  -- measured: soup is poured and is not a drink, powder is weighed and
  -- becomes one. Rows written before this step are backfilled from the
  -- unit, which is what the app had been assuming anyway; from here on
  -- the food says so itself.
  ALTER TABLE foods ADD COLUMN consumption_kind TEXT NOT NULL
    DEFAULT 'unknown';
  UPDATE foods SET consumption_kind = 'beverage'
    WHERE serving_unit IN ('millilitre', 'litre');
  UPDATE foods SET consumption_kind = 'food'
    WHERE serving_unit NOT IN ('millilitre', 'litre', 'serving');

  ALTER TABLE meals ADD COLUMN consumption_kind TEXT NOT NULL
    DEFAULT 'unknown';
  UPDATE meals SET consumption_kind = 'beverage' WHERE millilitres IS NOT NULL;

  -- Which sitting it was, when the user said. Optional on purpose: the
  -- time is the fact and the meal is what they call it, and the five
  -- values are the ones Health Connect defines.
  ALTER TABLE meals ADD COLUMN meal_type TEXT;
  ''',
  '''
  -- What kind of number a figure is, and where it came from. Taiwan
  -- requires chains to publish a maximum caffeine figure per cup, which
  -- is not the amount in the cup; printing that as a bare number would
  -- be inventing a precision nobody has. Everything already stored was
  -- typed off a packet, so it stays 'declared'.
  ALTER TABLE foods ADD COLUMN value_type TEXT NOT NULL DEFAULT 'declared';
  ALTER TABLE foods ADD COLUMN source_url TEXT NOT NULL DEFAULT '';
  ALTER TABLE foods ADD COLUMN checked_at INTEGER;
  ALTER TABLE meals ADD COLUMN value_type TEXT NOT NULL DEFAULT 'declared';
  ''',
  '''
  -- Which day a record belonged to for the person who lived it, as
  -- yyyymmdd, plus the UTC offset in force when they recorded it. An
  -- instant alone cannot answer "which day was that": the same moment
  -- is Monday night in Taipei and Monday morning in Los Angeles, so
  -- grouping by the device's current zone silently moves breakfast to
  -- yesterday the moment somebody flies.
  --
  -- Existing rows are backfilled through the device's own zone, which
  -- is the day they have been shown on until now.
  ALTER TABLE meals ADD COLUMN local_day INTEGER;
  ALTER TABLE meals ADD COLUMN utc_offset_minutes INTEGER;
  UPDATE meals SET
    local_day = CAST(
      strftime('%Y%m%d', eaten_at / 1000, 'unixepoch', 'localtime') AS INTEGER
    ),
    utc_offset_minutes = CAST(round((
      julianday(eaten_at / 1000, 'unixepoch', 'localtime')
      - julianday(eaten_at / 1000, 'unixepoch')
    ) * 1440) AS INTEGER);

  ALTER TABLE workouts ADD COLUMN local_day INTEGER;
  ALTER TABLE workouts ADD COLUMN utc_offset_minutes INTEGER;
  UPDATE workouts SET
    local_day = CAST(
      strftime('%Y%m%d', started_at / 1000, 'unixepoch', 'localtime') AS INTEGER
    ),
    utc_offset_minutes = CAST(round((
      julianday(started_at / 1000, 'unixepoch', 'localtime')
      - julianday(started_at / 1000, 'unixepoch')
    ) * 1440) AS INTEGER);

  ALTER TABLE activities ADD COLUMN local_day INTEGER;
  ALTER TABLE activities ADD COLUMN utc_offset_minutes INTEGER;
  UPDATE activities SET
    local_day = CAST(
      strftime('%Y%m%d', started_at / 1000, 'unixepoch', 'localtime') AS INTEGER
    ),
    utc_offset_minutes = CAST(round((
      julianday(started_at / 1000, 'unixepoch', 'localtime')
      - julianday(started_at / 1000, 'unixepoch')
    ) * 1440) AS INTEGER);

  ALTER TABLE body_weights ADD COLUMN local_day INTEGER;
  ALTER TABLE body_weights ADD COLUMN utc_offset_minutes INTEGER;
  UPDATE body_weights SET
    local_day = CAST(
      strftime('%Y%m%d', measured_at / 1000, 'unixepoch', 'localtime') AS INTEGER
    ),
    utc_offset_minutes = CAST(round((
      julianday(measured_at / 1000, 'unixepoch', 'localtime')
      - julianday(measured_at / 1000, 'unixepoch')
    ) * 1440) AS INTEGER);

  ALTER TABLE body_measurements ADD COLUMN local_day INTEGER;
  ALTER TABLE body_measurements ADD COLUMN utc_offset_minutes INTEGER;
  UPDATE body_measurements SET
    local_day = CAST(
      strftime('%Y%m%d', measured_at / 1000, 'unixepoch', 'localtime') AS INTEGER
    ),
    utc_offset_minutes = CAST(round((
      julianday(measured_at / 1000, 'unixepoch', 'localtime')
      - julianday(measured_at / 1000, 'unixepoch')
    ) * 1440) AS INTEGER);

  ALTER TABLE wellness_entries ADD COLUMN local_day INTEGER;
  ALTER TABLE wellness_entries ADD COLUMN utc_offset_minutes INTEGER;
  UPDATE wellness_entries SET
    local_day = CAST(
      strftime('%Y%m%d', recorded_at / 1000, 'unixepoch', 'localtime') AS INTEGER
    ),
    utc_offset_minutes = CAST(round((
      julianday(recorded_at / 1000, 'unixepoch', 'localtime')
      - julianday(recorded_at / 1000, 'unixepoch')
    ) * 1440) AS INTEGER);

  ALTER TABLE sleep_entries ADD COLUMN local_day INTEGER;
  ALTER TABLE sleep_entries ADD COLUMN utc_offset_minutes INTEGER;
  UPDATE sleep_entries SET
    local_day = CAST(
      strftime('%Y%m%d', slept_at / 1000, 'unixepoch', 'localtime') AS INTEGER
    ),
    utc_offset_minutes = CAST(round((
      julianday(slept_at / 1000, 'unixepoch', 'localtime')
      - julianday(slept_at / 1000, 'unixepoch')
    ) * 1440) AS INTEGER);
  ''',
  '''
  -- Free-text notes. One about a day stands on its own in the log
  -- ("dinner out", "slept badly, starving all day"); one about a record
  -- belongs to that record and is shown with it, which is what
  -- parent_type and parent_id are for. Only day notes are written so
  -- far; the columns are here so the other kind needs no migration.
  CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    noted_at INTEGER NOT NULL,
    local_day INTEGER,
    utc_offset_minutes INTEGER,
    parent_type TEXT,
    parent_id TEXT,
    $_entityColumns
  );
  CREATE INDEX notes_day ON notes(local_day) WHERE deleted_at IS NULL;
  ''',
  '''
  -- Which saved food a meal was logged from, and how many servings of
  -- it, so the next time can start from the usual portion. The figures
  -- stay copied on the meal; these do not bring the food's current
  -- numbers back. Meals logged before this, quick records and water
  -- have neither.
  ALTER TABLE meals ADD COLUMN food_id TEXT;
  ALTER TABLE meals ADD COLUMN servings REAL;
  ''',
  '''
  -- Other words a food answers to in search, such as a brand's English
  -- name. The catalogue writes them; nothing shows them.
  ALTER TABLE foods ADD COLUMN search_terms TEXT NOT NULL DEFAULT '';

  -- Starred foods, one row per food or cup size. Kept apart from foods
  -- because the catalogue's rows are replaced wholesale on every app
  -- update, and a star stored on them would go with them.
  CREATE TABLE food_favorites (
    food_id TEXT PRIMARY KEY,
    $_entityColumns
  );
  ''',
  '''
  -- The food's volume is the cup it comes in rather than the drink, as
  -- chains publish it. Such a volume is never counted as fluid drunk.
  ALTER TABLE foods ADD COLUMN is_cup_capacity INTEGER NOT NULL DEFAULT 0;
  ''',
  '''
  -- The brand's own line a food belongs to (CITY CAFE, CITY TEA), so one
  -- chain's menu can be read in the sections it is sold in.
  ALTER TABLE foods ADD COLUMN series TEXT NOT NULL DEFAULT '';
  ''',
  '''
  -- How a food's caffeine was typed: per 100 g/ml, as bottled drinks
  -- print it, or the total in one serving. Stored per serving either way.
  ALTER TABLE foods ADD COLUMN caffeine_basis TEXT NOT NULL DEFAULT 'serving';
  ''',
  '''
  -- A sleep read from a health platform: when it began, whether it was
  -- the day's night or a nap beside it, whether its length is time
  -- asleep or only time in bed, which source it is shown from, and the
  -- source the user picked over the default. A length typed in by hand
  -- has none of these.
  ALTER TABLE sleep_entries ADD COLUMN started_at INTEGER;
  ALTER TABLE sleep_entries ADD COLUMN kind TEXT NOT NULL DEFAULT 'night';
  ALTER TABLE sleep_entries ADD COLUMN measure TEXT NOT NULL DEFAULT 'asleep';
  ALTER TABLE sleep_entries ADD COLUMN source_name TEXT NOT NULL DEFAULT '';
  ALTER TABLE sleep_entries ADD COLUMN chosen_source TEXT;

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
  ''',
  '''
  -- The country a shipped food is sold in (ISO 3166-1, TW): one chain
  -- prints different figures for the same drink in each country.
  ALTER TABLE foods ADD COLUMN country TEXT NOT NULL DEFAULT '';
  ''',
  '''
  -- An exercise done in turn with the one after it (a superset). Null
  -- for no, so an archive written before this restores as it was.
  ALTER TABLE routine_exercises ADD COLUMN joins_next INTEGER;
  ALTER TABLE workout_exercises ADD COLUMN joins_next INTEGER;
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
