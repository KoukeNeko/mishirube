import '../storage/database.dart';
import 'csv.dart';

/// Human-readable CSV views of the store, one file per domain. Unlike the
/// JSON archive they are lossy and cannot be restored from.
Map<String, String> exportCsvViews(AppDatabase db) => {
  'workouts.csv': encodeCsv([
    const [
      'date',
      'workout',
      'exercise',
      'set',
      'set_type',
      'weight_kg',
      'reps',
      'rir',
      'rpe',
      'seconds',
      'distance_m',
    ],
    for (final row in db.select('''
      SELECT w.started_at, w.name AS workout, we.exercise_name, s.position,
             s.set_type, s.weight_kg, s.reps, s.rir, s.rpe, s.duration_s,
             s.distance_m
      FROM workouts w
      JOIN workout_exercises we ON we.workout_id = w.id
      JOIN workout_sets s
        ON s.workout_id = w.id AND s.exercise_position = we.position
      WHERE w.status = 'completed' AND w.deleted_at IS NULL AND s.is_done = 1
      ORDER BY w.started_at, we.position, s.position
    '''))
      [
        _localTime(row['started_at']),
        row['workout'],
        row['exercise_name'],
        (row['position'] as int) + 1,
        row['set_type'],
        row['weight_kg'],
        row['reps'],
        row['rir'],
        row['rpe'],
        row['duration_s'],
        row['distance_m'],
      ],
  ]),
  'meals.csv': encodeCsv([
    const [
      'date',
      'meal',
      'dishes',
      'kcal',
      'protein_g',
      'carb_g',
      'fat_g',
      'estimated',
      'quality',
    ],
    for (final row in db.select('''
      SELECT m.eaten_at, m.name, m.kcal, m.protein_g, m.carb_g, m.fat_g,
             m.is_estimated, m.quality_tag,
             (SELECT group_concat(d.name, ' / ') FROM
               (SELECT name FROM meal_dishes
                WHERE meal_id = m.id ORDER BY position) d) AS dishes
      FROM meals m WHERE m.deleted_at IS NULL ORDER BY m.eaten_at
    '''))
      [
        _localTime(row['eaten_at']),
        row['name'],
        row['dishes'],
        row['kcal'],
        row['protein_g'],
        row['carb_g'],
        row['fat_g'],
        row['is_estimated'] == 1,
        row['quality_tag'],
      ],
  ]),
  'body_weights.csv': encodeCsv([
    const ['date', 'weight_kg', 'note'],
    for (final row in db.select(
      'SELECT * FROM body_weights WHERE deleted_at IS NULL '
      'ORDER BY measured_at',
    ))
      [_localTime(row['measured_at']), row['weight_kg'], row['note']],
  ]),
};

/// `yyyy-MM-dd HH:mm` in local time, the way spreadsheets read dates.
String _localTime(Object? millis) {
  final time = DateTime.fromMillisecondsSinceEpoch(millis! as int);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
