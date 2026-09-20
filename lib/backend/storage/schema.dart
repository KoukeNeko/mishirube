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
];

int get latestSchemaVersion => _migrations.length;

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
