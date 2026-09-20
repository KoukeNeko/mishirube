import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../engines/training_metrics.dart';
import '../engines/nutrition_summary.dart';
import 'database.dart';
import 'journal_repository.dart';
import 'meal_repository.dart';
import 'workout_repository.dart';

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// Everything recorded in one month, as the log shows it.
class MonthRecords {
  const MonthRecords({required this.days, required this.summaries});

  static const empty = MonthRecords(days: [], summaries: {});

  /// Days with records, newest first.
  final List<TimelineDay> days;

  /// Per day of the month, one short summary per recorded category, in
  /// [RecordCategory] order.
  final Map<int, Map<RecordCategory, String>> summaries;

  Map<int, List<RecordCategory>> get dots => {
    for (final MapEntry(key: day, value: byCategory) in summaries.entries)
      day: byCategory.keys.toList(),
  };
}

/// Builds the unified timeline across training, food, body and wellness.
class TimelineQuery {
  TimelineQuery(this._db, this._workouts, this._meals, this._journal);

  final AppDatabase _db;
  final WorkoutRepository _workouts;
  final MealRepository _meals;
  final JournalRepository _journal;

  /// The first month holding any record, or null for an empty store.
  DateTime? earliestMonth() {
    final rows = _db.select('''
      SELECT MIN(t) AS first FROM (
        SELECT MIN(started_at) AS t FROM workouts
          WHERE status = 'completed' AND deleted_at IS NULL
        UNION ALL SELECT MIN(eaten_at) FROM meals WHERE deleted_at IS NULL
        UNION ALL SELECT MIN(measured_at) FROM body_weights
          WHERE deleted_at IS NULL
        UNION ALL SELECT MIN(recorded_at) FROM wellness_entries
          WHERE deleted_at IS NULL
      )
    ''');
    final first = rows.first['first'] as int?;
    if (first == null) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(first);
    return DateTime(date.year, date.month);
  }

  MonthRecords month(DateTime month, ExerciseResolver exercises) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final today = _db.now();
    final entriesByDay = <int, List<(DateTime, TimelineEntry)>>{};
    final summaries = <int, Map<RecordCategory, String>>{};
    void add(DateTime at, TimelineEntry entry) =>
        (entriesByDay[at.day] ??= []).add((at, entry));

    for (final workout in _completedWorkouts(start, end, exercises)) {
      final sets = workout.completedSets;
      final minutes = workout.elapsedAt(workout.finishedAt!).inMinutes;
      final record = _personalRecord(workout);
      add(
        workout.finishedAt!,
        TimelineEntry(
          timeLabel: formatTimeOfDay(workout.finishedAt!),
          category: RecordCategory.training,
          title: workout.routineName,
          detail: ['$sets 組', '$minutes 分', ?record].join(' · '),
        ),
      );
      (summaries[workout.startedAt.day] ??= {})[RecordCategory.training] =
          '${workout.routineName} · $sets 組';
    }

    final mealsByDay = <int, List<MealEvent>>{};
    for (final (eatenAt, meal) in _meals.between(start, end)) {
      final kcal = '${meal.isEstimated ? '~' : ''}${formatKcal(meal.kcal)}';
      add(
        eatenAt,
        TimelineEntry(
          timeLabel: meal.timeLabel,
          category: RecordCategory.nutrition,
          title: meal.name,
          detail: meal.dishes.map((dish) => dish.name).join('、'),
          tags: ['$kcal kcal', meal.qualityTag],
        ),
      );
      (mealsByDay[eatenAt.day] ??= []).add(meal);
    }
    for (final MapEntry(key: day, value: meals) in mealsByDay.entries) {
      final summary = summariseDay(meals);
      final approximate = summary.hasEstimates ? '~' : '';
      (summaries[day] ??= {})[RecordCategory.nutrition] =
          '${summary.mealCount} 餐 · $approximate${formatKcal(summary.kcal)} kcal';
    }

    for (final weight in _journal.weightsBetween(start, end)) {
      final label = '${formatWeight(weight.weightKg)} kg';
      add(
        weight.measuredAt,
        TimelineEntry(
          timeLabel: formatTimeOfDay(weight.measuredAt),
          category: RecordCategory.body,
          title: '體重 $label',
          detail: weight.note,
        ),
      );
      (summaries[weight.measuredAt.day] ??= {})[RecordCategory.body] = label;
    }

    for (final entry in _journal.wellnessBetween(start, end)) {
      final title = '${entry.kind.label} ${entry.score} / 5';
      add(
        entry.recordedAt,
        TimelineEntry(
          timeLabel: formatTimeOfDay(entry.recordedAt),
          category: RecordCategory.wellness,
          title: title,
          detail: entry.note.isEmpty ? '' : '備註：${entry.note}',
        ),
      );
      (summaries[entry.recordedAt.day] ??= {})[RecordCategory.wellness] = title;
    }

    final days = entriesByDay.keys.toList()..sort((a, b) => b - a);
    return MonthRecords(
      days: [
        for (final day in days)
          TimelineDay(
            label: _dayLabel(DateTime(month.year, month.month, day), today),
            warning:
                _isIncomplete(
                  DateTime(month.year, month.month, day),
                  mealsByDay[day] ?? const [],
                  today,
                )
                ? '飲食紀錄不完整'
                : null,
            entries: [
              for (final (_, entry)
                  in entriesByDay[day]!..sort((a, b) => b.$1.compareTo(a.$1)))
                entry,
            ],
          ),
      ],
      summaries: {
        for (final day in summaries.keys.toList()..sort())
          day: {
            for (final category in RecordCategory.values)
              category: ?summaries[day]![category],
          },
      },
    );
  }

  List<WorkoutSession> _completedWorkouts(
    DateTime start,
    DateTime end,
    ExerciseResolver exercises,
  ) => [
    for (final row in _db.select(
      "SELECT id FROM workouts WHERE status = 'completed' "
      'AND deleted_at IS NULL AND started_at >= ? AND started_at < ? '
      'ORDER BY started_at',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    ))
      _workouts.byId(row['id'], exercises)!,
  ];

  /// A heavier set than any earlier finished session of the same exercise.
  String? _personalRecord(WorkoutSession workout) {
    for (final session in workout.exercises) {
      final best = heaviestSet(session.sets);
      if (best == null) continue;
      final rows = _db.select(
        '''
        SELECT MAX(s.weight_kg) AS best FROM workout_sets s
        JOIN workout_exercises we ON we.workout_id = s.workout_id
          AND we.position = s.exercise_position
        JOIN workouts w ON w.id = s.workout_id
        WHERE we.exercise_id = ? AND w.status = 'completed'
          AND w.deleted_at IS NULL AND w.started_at < ? AND s.is_done = 1
          AND s.set_type != 'warmup'
        ''',
        [session.exercise.id, workout.startedAt.millisecondsSinceEpoch],
      );
      final previousBest = (rows.first['best'] as num?)?.toDouble();
      if (previousBest != null && best.weightKg > previousBest) {
        return '${session.exercise.name} ${formatWeight(best.weightKg)} kg × '
            '${best.reps} 為新紀錄';
      }
    }
    return null;
  }

  /// Whether a day's food log looks incomplete, by the nutrition engine's
  /// rule.
  static bool _isIncomplete(
    DateTime day,
    List<MealEvent> meals,
    DateTime today,
  ) => isFoodLogIncomplete(
    summariseDay(
      meals,
      isOver: day.isBefore(DateTime(today.year, today.month, today.day)),
    ),
  );

  static String _dayLabel(DateTime day, DateTime today) {
    final label = '${day.month} 月 ${day.day} 日（週${_weekdays[day.weekday - 1]}）';
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return isToday ? '今天 · $label' : label;
  }
}
