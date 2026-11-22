import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../engines/nutrition_summary.dart';
import '../engines/training_metrics.dart';
import '../engines/workout_review.dart';
import '../storage/timeline_query.dart';
import 'activity_service.dart';
import 'catalog_service.dart';
import 'goal_service.dart';
import 'insights_service.dart';
import 'journal_service.dart';
import 'nutrition_service.dart';
import 'sleep_service.dart';
import 'training_service.dart';

/// The longest period one call may read, so a single answer never
/// carries a year of records into a model's context.
const maxToolDays = 92;

/// The longest period the timeline may read: it lists every record.
const maxTimelineDays = 14;

/// The records a model may read while answering a question about them.
///
/// Every tool only reads, over a period the app checks, and returns the
/// figures already worked out, so a number in an answer comes from here
/// rather than from the model's own arithmetic (research 100, section 6).
/// Arguments come from a model and are checked like any other input;
/// a bad one is answered with an `error` the model can correct, never
/// thrown.
class RecordTools {
  RecordTools(
    this._catalog,
    this._training,
    this._nutrition,
    this._sleep,
    this._journal,
    this._activity,
    this._goal,
    this._insights,
    this._timeline,
    this._l10n,
  );

  final CatalogService _catalog;
  final TrainingService _training;
  final NutritionService _nutrition;
  final SleepService _sleep;
  final JournalService _journal;
  final ActivityService _activity;
  final GoalService _goal;
  final InsightsService _insights;
  final TimelineQuery _timeline;

  /// The units figures are given in, the same ones the screens show.
  final AppLocalizations _l10n;

  static const _period = {
    'from': {'type': 'string', 'description': 'First day, YYYY-MM-DD.'},
    'to': {
      'type': 'string',
      'description': 'Last day, YYYY-MM-DD, at most $maxToolDays days on.',
    },
  };

  static Map<String, Object?> strictObject(Map<String, Object?> properties) => {
    'type': 'object',
    'properties': properties,
    'required': properties.keys.toList(),
    'additionalProperties': false,
  };

  static final _comparePrevious = {
    'compare_previous': {
      'type': 'boolean',
      'description':
          'Also return the same number of days just before, and the '
          'change from them.',
    },
  };

  static final List<AiTool> tools = [
    AiTool(
      name: 'find_exercise',
      description:
          'Exercises in the library matching a name, best first, with the '
          'id the other exercise tools take.',
      parameters: strictObject({
        'query': {'type': 'string'},
      }),
    ),
    AiTool(
      name: 'exercise_history',
      description:
          'Each finished session of one exercise in a period: counted sets, '
          'best set and volume, and the current estimated one-rep max.',
      parameters: strictObject({
        'exercise_id': {'type': 'string'},
        ..._period,
      }),
    ),
    AiTool(
      name: 'workouts',
      description:
          'Finished workouts in a period, each with its sets and volume, '
          'and the totals.',
      parameters: strictObject({..._period, ..._comparePrevious}),
    ),
    AiTool(
      name: 'nutrition_days',
      description:
          'Energy and macronutrients eaten each day of a period, whether the '
          "day's log is complete, the user's own targets, and the average "
          'over complete days.',
      parameters: strictObject({..._period, ..._comparePrevious}),
    ),
    AiTool(
      name: 'meals',
      description: 'The meals logged each day of a period.',
      parameters: strictObject(_period),
    ),
    AiTool(
      name: 'sleep_days',
      description:
          'Time asleep for each morning in a period, naps included, and the '
          "user's sleep goal.",
      parameters: strictObject(_period),
    ),
    AiTool(
      name: 'body_records',
      description:
          'Weights, tape measurements and body composition readings taken '
          'in a period.',
      parameters: strictObject(_period),
    ),
    AiTool(
      name: 'activities',
      description:
          'Activities recorded and the day\'s movement figures (steps, '
          'distance, energy, exercise time) for each day of a period.',
      parameters: strictObject(_period),
    ),
    AiTool(
      name: 'vitals',
      description:
          'Overnight readings for each night of a period (heart rate, '
          'breathing, oxygen, temperature, HRV), and the daily heart and '
          'vital figures health platforms recorded.',
      parameters: strictObject(_period),
    ),
    AiTool(
      name: 'wellness',
      description:
          'Check-ins (mood, energy, symptoms, each out of 5), baths, water '
          'and caffeine for each day of a period.',
      parameters: strictObject(_period),
    ),
    AiTool(
      name: 'search_notes',
      description: 'Notes written in a period that contain the query.',
      parameters: strictObject({
        'query': {'type': 'string'},
        ..._period,
      }),
    ),
    AiTool(
      name: 'timeline',
      description:
          'Every record of each day of a period, in time order, as the log '
          'lists it; at most $maxTimelineDays days.',
      parameters: strictObject(_period),
    ),
    AiTool(
      name: 'weekly_goal',
      description:
          "The user's weekly active-day goal, recent weeks against it, and "
          'the streak.',
      parameters: strictObject({}),
    ),
    AiTool(
      name: 'insights',
      description:
          'The observations the app has already worked out from the last 28 '
          'days, each with what it rests on.',
      parameters: strictObject({}),
    ),
  ];

  /// What [name] answers for [arguments], as JSON.
  Map<String, Object?> call(String name, Map<String, Object?> arguments) {
    try {
      return switch (name) {
        'find_exercise' => _findExercise(_string(arguments, 'query')),
        'exercise_history' => _exerciseHistory(
          _string(arguments, 'exercise_id'),
          _days(arguments),
        ),
        'workouts' => _compared(arguments, _workouts),
        'nutrition_days' => _compared(arguments, _nutritionDays),
        'meals' => _meals(_days(arguments)),
        'sleep_days' => _sleepDays(_days(arguments)),
        'body_records' => _bodyRecords(_days(arguments)),
        'activities' => _activities(_days(arguments)),
        'vitals' => _vitals(_days(arguments)),
        'wellness' => _wellness(_days(arguments)),
        'search_notes' => _searchNotes(
          _string(arguments, 'query'),
          _days(arguments),
        ),
        'timeline' => _timelineOf(_days(arguments, most: maxTimelineDays)),
        'weekly_goal' => _weeklyGoal(),
        'insights' => _insightsNow(),
        _ => throw ToolArgumentError('no tool named $name'),
      };
    } on ToolArgumentError catch (error) {
      return {'error': error.message};
    }
  }

  Map<String, Object?> _findExercise(String query) => {
    'exercises': [
      for (final exercise in _catalog.search(query: query).take(5))
        {
          'id': exercise.id,
          'name': exercise.name,
          'equipment': exercise.equipment.name,
          'primary_muscles': [
            for (final muscle in exercise.primaryMuscles) muscle.name,
          ],
        },
    ],
  };

  Map<String, Object?> _exerciseHistory(String id, List<DateTime> days) {
    final exercise = _catalog.byId(id);
    if (exercise == null) {
      throw ToolArgumentError('no exercise $id; find it with find_exercise');
    }
    final sessions = [
      for (final record in _training.sessionsOf(exercise))
        if (_isWithin(record.date, days)) record,
    ];
    return {
      'exercise': exercise.name,
      'session_count': sessions.length,
      'estimated_one_rep_max_kg': _round(
        _catalog.history(id).estimatedOneRepMaxKg,
      ),
      'sessions': [
        for (final record in sessions)
          {
            'date': _date(record.date),
            'counted_sets': countedSets(record.sets).length,
            'volume_kg': _round(
              exercise.trackingType == TrackingType.weightReps
                  ? volumeKg(record.sets)
                  : null,
            ),
            'best_set': _set(bestSet(exercise.trackingType, record.sets)),
          },
      ],
    };
  }

  Map<String, Object?> _workouts(List<DateTime> days) {
    final workouts = [for (final day in days) ..._training.finishedOn(day)];
    int setsOf(WorkoutSession workout) => workout.exercises.fold<int>(
      0,
      (sum, session) => sum + countedSets(session.sets).length,
    );
    double volumeOf(WorkoutSession workout) => workout.exercises.fold<double>(
      0,
      (sum, session) => sum + sessionVolumeKg(session),
    );
    return {
      'workout_count': workouts.length,
      'counted_sets': workouts.fold<int>(0, (sum, w) => sum + setsOf(w)),
      'volume_kg': _round(
        workouts.fold<double>(0, (sum, w) => sum + volumeOf(w)),
      ),
      'workouts': [
        for (final workout in workouts)
          {
            'date': _date(workout.startedAt),
            'name': workout.routineName,
            'counted_sets': setsOf(workout),
            'volume_kg': _round(volumeOf(workout)),
            'exercises': [
              for (final session in workout.exercises) session.exercise.name,
            ],
          },
      ],
    };
  }

  /// How many earlier sessions of an exercise, and earlier workouts, a
  /// workout's facts carry; fewer when [workoutFacts] is `compact`.
  static const workoutFactsSessions = 12;
  static const workoutFactsWorkouts = 30;

  /// One finished workout as [review] worked it out (every set done, the
  /// records it set, its total against the same template's last time)
  /// and the training before it: each exercise's earlier sessions and the
  /// workouts finished before, for a model asked about that workout.
  /// [compact] keeps a quarter of the latest ones, for a small context.
  Map<String, Object?> workoutFacts(
    WorkoutSession workout,
    WorkoutReview review, {
    bool compact = false,
  }) => {
    'date': _date(workout.startedAt),
    'name': workout.routineName,
    'minutes': workout.finishedAt?.difference(workout.startedAt).inMinutes,
    'workload': workout.workload?.name,
    'counted_sets': review.sets,
    'volume_kg': _round(review.volumeKg),
    'previous_volume_kg': _round(review.previousVolumeKg),
    'exercises': [
      for (final item in review.exercises)
        {
          'exercise_id': item.exercise.id,
          'name': item.exercise.name,
          'sets': [
            for (final set in item.done) {'type': set.type.name, ...?_set(set)},
          ],
          'volume_kg': _round(item.volumeKg),
          'personal_record': ?_set(item.record),
          'history': _historyBefore(
            item.exercise,
            workout,
            sessions: workoutFactsSessions ~/ (compact ? 4 : 1),
          ),
        },
    ],
    'earlier_workouts': [
      for (final earlier in _training.recentFinished(
        limit: workoutFactsWorkouts ~/ (compact ? 4 : 1),
      ))
        if (earlier.id != workout.id &&
            earlier.startedAt.isBefore(workout.startedAt))
          {
            'date': _date(earlier.startedAt),
            'name': earlier.routineName,
            'counted_sets': earlier.exercises.fold<int>(
              0,
              (sum, session) => sum + countedSets(session.sets).length,
            ),
          },
    ],
  };

  /// [exercise]'s sessions before [workout]: how many and since when, the
  /// best set of them all, and the latest few.
  Map<String, Object?> _historyBefore(
    ExerciseDefinition exercise,
    WorkoutSession workout, {
    required int sessions,
  }) {
    final type = exercise.trackingType;
    final earlier = [
      for (final record in _training.sessionsOf(exercise))
        if (record.workoutId != workout.id &&
            record.date.isBefore(workout.startedAt))
          record,
    ];
    return {
      'session_count': earlier.length,
      if (earlier.isNotEmpty) 'first_date': _date(earlier.last.date),
      'best_set_before': ?_set(
        bestSet(type, [for (final record in earlier) ...record.sets]),
      ),
      'estimated_one_rep_max_kg': _round(
        _catalog.history(exercise.id).estimatedOneRepMaxKg,
      ),
      'latest_sessions': [
        for (final record in earlier.take(sessions))
          {
            'date': _date(record.date),
            'counted_sets': countedSets(record.sets).length,
            'volume_kg': _round(
              type == TrackingType.weightReps ? volumeKg(record.sets) : null,
            ),
            'best_set': _set(bestSet(type, record.sets)),
          },
      ],
    };
  }

  Map<String, Object?> _nutritionDays(List<DateTime> days) {
    final summaries = [
      for (final day in days) (day, _nutrition.summaryOf(day)),
    ];
    final complete = [
      for (final (_, summary) in summaries)
        if (summary.isComplete) summary,
    ];
    double? average(double Function(DaySummary) figure) => complete.isEmpty
        ? null
        : complete.fold<double>(0, (sum, day) => sum + figure(day)) /
              complete.length;
    final targets = _nutrition.targetsOn(days.last);
    return {
      'complete_days': complete.length,
      'average_kcal': _round(average((day) => day.kcal)),
      'average_protein_g': _round(average((day) => day.proteinGrams)),
      'average_carb_g': _round(average((day) => day.carbGrams)),
      'average_fat_g': _round(average((day) => day.fatGrams)),
      'targets': {
        'kcal': _round(targets.kcal),
        'protein_g': _round(targets.proteinGrams),
        'carb_g': _round(targets.carbGrams),
        'fat_g': _round(targets.fatGrams),
      },
      'days': [
        for (final (day, summary) in summaries)
          if (summary.hasRecords)
            {
              'date': _date(day),
              'is_complete': summary.isComplete,
              'meals': summary.mealCount,
              'meals_without_figures': summary.mealsWithoutFigures,
              'kcal': _round(summary.kcal),
              'protein_g': _round(summary.proteinGrams),
              'carb_g': _round(summary.carbGrams),
              'fat_g': _round(summary.fatGrams),
            },
      ],
    };
  }

  Map<String, Object?> _meals(List<DateTime> days) => {
    'days': [
      for (final day in days)
        if (_nutrition.mealsOn(day).where((meal) => !meal.isWater).toList()
            case final meals when meals.isNotEmpty)
          {
            'date': _date(day),
            'meals': [
              for (final meal in meals)
                {
                  'name': meal.name,
                  'time': meal.timeLabel,
                  'meal_type': meal.mealType?.name,
                  'kcal': _round(meal.kcal),
                  'protein_g': _round(meal.proteinGrams),
                  'is_estimated': meal.isEstimated,
                },
            ],
          },
    ],
  };

  Map<String, Object?> _sleepDays(List<DateTime> days) {
    final sleepDays = _sleep.sleepDays(days.last, days.length);
    return {
      'goal_minutes': _sleep.goal?.inMinutes,
      'days': [
        for (final day in sleepDays)
          {'date': _date(day.day), 'asleep_minutes': day.slept?.inMinutes},
      ],
    };
  }

  Map<String, Object?> _bodyRecords(List<DateTime> days) {
    final start = days.first;
    final end = days.last.add(const Duration(days: 1));
    return {
      'weights': [
        for (final weight in _journal.weightsBetween(start, end))
          {'date': _date(weight.measuredAt), 'kg': _round(weight.weightKg)},
      ],
      'measurements': [
        for (final measurement in _journal.measurementsBetween(start, end))
          {
            'date': _date(measurement.measuredAt),
            'site': measurement.site.name,
            'cm': _round(measurement.centimetres),
          },
      ],
      'body_composition': [
        for (final metric in BodyMetric.values)
          for (final reading in _journal.bodyReadingsBetween(
            metric,
            start,
            end,
          ))
            {
              'date': _date(reading.measuredAt),
              'metric': metric.name,
              'value': _round(reading.value),
              'unit': metric.unitIn(_l10n),
              'is_estimated': metric.isEstimated,
            },
      ],
    };
  }

  Map<String, Object?> _activities(List<DateTime> days) => {
    'days': [
      for (final day in days)
        if ((
              _activity.on(day),
              _dailyFigures(day, {ActivityMetricGroup.movement}),
            )
            case (final sessions, final figures)
            when sessions.isNotEmpty || figures.isNotEmpty)
          {
            'date': _date(day),
            'figures': figures,
            'activities': [
              for (final session in sessions)
                {
                  'type': session.type.id,
                  'minutes': session.duration.inMinutes,
                  'distance_km': _round(switch (session.distanceMeters) {
                    final metres? => metres / 1000,
                    null => null,
                  }),
                },
            ],
          },
    ],
  };

  Map<String, Object?> _vitals(List<DateTime> days) => {
    'days': [
      for (final day in days)
        if ((
              [
                for (final record in _sleep.day(day))
                  if (record.entry.kind == SleepKind.night) ...record.readings,
              ],
              _dailyFigures(day, {
                ActivityMetricGroup.heart,
                ActivityMetricGroup.vitals,
              }),
            )
            case (final overnight, final figures)
            when overnight.isNotEmpty || figures.isNotEmpty)
          {
            'date': _date(day),
            'overnight': [
              for (final reading in overnight)
                {
                  'measure': reading.measure.name,
                  if (reading.isElevated case final isElevated?)
                    'is_elevated': isElevated
                  else ...{
                    'minimum': _round(reading.minimum),
                    'maximum': _round(reading.maximum),
                    'average': _round(reading.average),
                    'unit': reading.measure.unitIn(_l10n),
                  },
                  'readings': reading.count,
                },
            ],
            'figures': figures,
          },
    ],
  };

  /// [day]'s figures of the metrics in [groups], in the units the
  /// screens show them in.
  List<Map<String, Object?>> _dailyFigures(
    DateTime day,
    Set<ActivityMetricGroup> groups,
  ) => [
    for (final MapEntry(key: metric, :value)
        in _activity.dayTotals(day).entries)
      if (groups.contains(metric.group))
        {
          'metric': metric.name,
          'value': _round(value * metric.displayScale),
          'unit': metric.unitIn(_l10n),
        },
  ];

  Map<String, Object?> _wellness(List<DateTime> days) {
    final checkIns = _journal.wellnessBetween(
      days.first,
      days.last.add(const Duration(days: 1)),
    );
    final answer = <Map<String, Object?>>[];
    for (final day in days) {
      final entries = [
        for (final entry in checkIns)
          if (_isSameDay(entry.recordedAt, day)) entry,
      ];
      final baths = _journal.bathsOn(day);
      final meals = _nutrition.mealsOn(day);
      final waterMl = meals
          .where((meal) => meal.isWater)
          .fold<int>(0, (sum, meal) => sum + (meal.millilitres ?? 0));
      final caffeineMg = meals.fold<double>(
        0,
        (sum, meal) => sum + (meal.nutrients[Nutrient.caffeine] ?? 0),
      );
      if (entries.isEmpty && baths.isEmpty && waterMl == 0 && caffeineMg == 0) {
        continue;
      }
      answer.add({
        'date': _date(day),
        'check_ins': [
          for (final entry in entries)
            {'kind': entry.kind.name, 'score': entry.score, 'out_of': 5},
        ],
        'baths': [
          for (final bath in baths)
            {
              'kind': bath.kind?.name,
              'water': bath.water?.name,
              'minutes': bath.duration?.inMinutes,
            },
        ],
        'water_ml': waterMl,
        'caffeine_mg': _round(caffeineMg),
      });
    }
    return {'days': answer};
  }

  Map<String, Object?> _searchNotes(String query, List<DateTime> days) {
    final needle = query.toLowerCase();
    final notes = <Map<String, Object?>>[];
    for (final day in days) {
      for (final entry in _timeline.day(day)) {
        final id = entry.recordId;
        if (id == null || _journal.entry(id) is! Note) continue;
        if (!entry.detail.toLowerCase().contains(needle)) continue;
        notes.add({
          'date': _date(day),
          'time': entry.timeLabel,
          'text': entry.detail,
        });
      }
    }
    return {'notes': notes};
  }

  Map<String, Object?> _timelineOf(List<DateTime> days) => {
    'days': [
      for (final day in days)
        if (_timeline.day(day) case final entries when entries.isNotEmpty)
          {
            'date': _date(day),
            'records': [
              for (final entry in entries)
                {
                  'time': entry.timeLabel,
                  'category': entry.category.name,
                  'title': entry.title,
                  'detail': entry.detail,
                },
            ],
          },
    ],
  };

  Map<String, Object?> _weeklyGoal() {
    final overview = _goal.overview();
    if (!overview.hasGoal) return {'has_goal': false};
    return {
      'has_goal': true,
      'is_paused': overview.isPaused,
      'current_streak_weeks': overview.streak.current,
      'best_streak_weeks': overview.streak.best,
      'weeks': [
        for (final week in overview.weeks.reversed.take(8))
          {
            'week_of': _date(week.start),
            'active_days': week.activeDays,
            'target_days': week.targetDays,
            'is_paused': week.isPaused,
            'is_current': week.isCurrent,
          },
      ],
    };
  }

  Map<String, Object?> _insightsNow() => {
    'insights': [
      for (final insight in _insights.today())
        {
          'kind': insight.kind.name,
          'statement': insight.statement,
          'evidence': insight.evidence,
        },
    ],
  };

  /// [read] over the period, and with `compare_previous` the same over
  /// as many days just before, with what each figure changed by.
  Map<String, Object?> _compared(
    Map<String, Object?> arguments,
    Map<String, Object?> Function(List<DateTime>) read,
  ) {
    final days = _days(arguments);
    final current = read(days);
    if (arguments['compare_previous'] != true) return current;
    final before = [
      for (var i = days.length; i > 0; i--)
        days.first.subtract(Duration(days: i)),
    ];
    final previous = read(before);
    return {
      ...current,
      'previous': {
        'from': _date(before.first),
        'to': _date(before.last),
        for (final MapEntry(:key, :value) in previous.entries)
          if (value is num) key: value,
      },
      'change': {
        for (final MapEntry(:key, :value) in current.entries)
          if ((value, previous[key]) case (final num now, final num then))
            key: _round((now - then).toDouble()),
      },
    };
  }

  static String _string(Map<String, Object?> arguments, String key) =>
      switch (arguments[key]) {
        final String text when text.trim().isNotEmpty => text.trim(),
        _ => throw ToolArgumentError('$key must be a non-empty string'),
      };

  /// The days from `from` to `to`, both included.
  static List<DateTime> _days(
    Map<String, Object?> arguments, {
    int most = maxToolDays,
  }) {
    final from = _day(arguments, 'from');
    final to = _day(arguments, 'to');
    final count =
        DateTime.utc(
          to.year,
          to.month,
          to.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
        1;
    if (count < 1) throw ToolArgumentError('to is before from');
    if (count > most) {
      throw ToolArgumentError('at most $most days at a time');
    }
    return [
      for (var i = 0; i < count; i++)
        DateTime(from.year, from.month, from.day + i),
    ];
  }

  static DateTime _day(Map<String, Object?> arguments, String key) {
    final text = arguments[key];
    final match = text is String
        ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text)
        : null;
    if (match == null) throw ToolArgumentError('$key must be YYYY-MM-DD');
    final [year, month, day] = [
      for (var group = 1; group <= 3; group++) int.parse(match[group]!),
    ];
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) {
      throw ToolArgumentError('$key is not a date');
    }
    return date;
  }

  static bool _isWithin(DateTime at, List<DateTime> days) =>
      !at.isBefore(days.first) &&
      at.isBefore(days.last.add(const Duration(days: 1)));

  static bool _isSameDay(DateTime at, DateTime day) =>
      at.year == day.year && at.month == day.month && at.day == day.day;

  static String _date(DateTime at) =>
      '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  static double? _round(double? value) =>
      value == null ? null : (value * 10).roundToDouble() / 10;

  static Map<String, Object?>? _set(WorkoutSet? set) => set == null
      ? null
      : {
          'weight_kg': _round(set.weightKg),
          'reps': set.reps,
          'seconds': set.durationSeconds,
          'distance_m': _round(set.distanceMeters),
        };
}

/// A tool call whose arguments cannot be answered, said so the model can
/// correct them.
class ToolArgumentError implements Exception {
  ToolArgumentError(this.message);

  final String message;
}
