import '../../domain/domain.dart';
import '../engines/program_progress.dart';
import '../storage/database.dart';
import '../storage/exercise_repository.dart';
import '../storage/program_repository.dart';
import 'training_service.dart';

/// Programs: making them, running one at a time, and training or
/// skipping their workouts. Where one stands is derived on each read.
class ProgramService {
  ProgramService(this._db, this._programs, this._exercises, this._training);

  final AppDatabase _db;
  final ProgramRepository _programs;
  final ExerciseRepository _exercises;
  final TrainingService _training;

  List<Program> all() => _programs.all();

  Program? byId(String id) => _programs.byId(id);

  /// Where the running program stands today; null when none runs or it
  /// has nothing in it.
  ProgramProgress? progress() => switch (_programs.running()) {
    final program? when program.days.isNotEmpty => progressOf(program),
    _ => null,
  };

  /// Where [program] stands, counting only what came since it was last
  /// started: starting it again begins from its first workout.
  ProgramProgress progressOf(Program program) {
    final startedAt = program.startedAt;
    return programProgress(program, [
      for (final record in _programs.records(program.id))
        if (startedAt == null || !record.at.isBefore(startedAt)) record,
    ], _db.now());
  }

  /// The routines programs hold, which the user's own list leaves out.
  Set<String> routineIdsInPrograms() => _programs.routineIdsInPrograms();

  /// A new, empty program, not yet started.
  Program create(String name) {
    final program = Program(
      id: _db.newId(),
      name: name,
      schedule: ProgramSchedule.rotation,
      days: const [],
    );
    _programs.save(program);
    return program;
  }

  /// A new program from [template], each of its workouts a routine of
  /// the program's own.
  Program createFrom(ProgramTemplate template) => _db.transaction(() {
    final program = Program(
      id: _db.newId(),
      name: template.name,
      schedule: ProgramSchedule.rotation,
      days: [
        for (final workout in template.workouts)
          ProgramDay(
            routineId: _training
                .createRoutine(
                  workout.name,
                  exercises: [
                    for (final (id, sets, reps) in workout.exercises)
                      if (_exercises.byId(id) case final exercise?)
                        _training
                            .planFor(exercise)
                            .copyWith(sets: sets, reps: reps),
                  ],
                )
                .id,
          ),
      ],
    );
    _programs.save(program);
    return program;
  });

  void save(Program program) => _programs.save(program);

  /// Adds a new, empty routine named [name] to the end of [program].
  Routine addNew(Program program, String name) => _db.transaction(() {
    final routine = _training.createRoutine(name);
    _append(program, routine);
    return routine;
  });

  /// Adds a copy of [routine] to the end of [program]; the user's own
  /// stays as it is.
  Routine addCopy(Program program, Routine routine) => _db.transaction(() {
    final copy = _training.copyRoutine(routine);
    _append(program, copy);
    return copy;
  });

  void _append(Program program, Routine routine) => _programs.save(
    program.copyWith(
      days: [
        ...program.days,
        ProgramDay(
          routineId: routine.id,
          weekday: program.schedule == ProgramSchedule.weekdays
              ? _freeWeekday(program)
              : null,
        ),
      ],
    ),
  );

  /// Switches how [program]'s workouts come round. Going to weekdays
  /// gives each workout without one a weekday of its own.
  void setSchedule(Program program, ProgramSchedule schedule) {
    var days = program.days;
    if (schedule == ProgramSchedule.weekdays) {
      days = [];
      for (final day in program.days) {
        final weekday =
            day.weekday ?? _freeWeekday(program.copyWith(days: days));
        days.add(day.onWeekday(weekday));
      }
    }
    _programs.save(program.copyWith(schedule: schedule, days: days));
  }

  /// The first weekday, spread across the week, no workout is on yet.
  static int _freeWeekday(Program program) {
    const spread = [
      DateTime.monday,
      DateTime.wednesday,
      DateTime.friday,
      DateTime.tuesday,
      DateTime.thursday,
      DateTime.saturday,
      DateTime.sunday,
    ];
    final taken = {for (final day in program.days) day.weekday};
    return spread.firstWhere(
      (weekday) => !taken.contains(weekday),
      orElse: () => DateTime.monday,
    );
  }

  void setWeekday(Program program, int position, int weekday) {
    final days = [...program.days];
    days[position] = days[position].onWeekday(weekday);
    _programs.save(program.copyWith(days: days));
  }

  void move(Program program, int from, int to) {
    final days = [...program.days];
    days.insert(to, days.removeAt(from));
    _programs.save(program.copyWith(days: days));
  }

  /// Takes a workout out of [program]; its routine becomes the user's
  /// own, and what was trained from it stays.
  void remove(Program program, int position) => _programs.save(
    program.copyWith(days: [...program.days]..removeAt(position)),
  );

  /// Starts [program] from its first workout, ending the one running
  /// before: one program at a time.
  void start(Program program) {
    _db.transaction(() {
      final now = _db.now();
      if (_programs.running() case final running?) {
        _programs.save(running.copyWith(endedAt: () => now));
      }
      _programs.save(
        program.copyWith(startedAt: () => now, endedAt: () => null),
      );
    });
  }

  void end(Program program) =>
      _programs.save(program.copyWith(endedAt: () => _db.now()));

  void delete(String id) => _programs.delete(id);

  /// Skips the running program's next workout.
  void skipNext() {
    final progress = this.progress();
    if (progress == null) return;
    _programs.skip(progress.program.id, progress.nextDay);
  }

  /// Starts [routine]. When it is one of the running program's, the
  /// workout counts as that one once finished, whether or not it was
  /// the one next: the rotation goes on from what was trained.
  WorkoutSession startWorkout(
    Routine routine, {
    Set<MuscleGroup> sore = const {},
  }) => _db.transaction(() {
    final workout = _training.start(routine, sore: sore);
    if (_programs.running() case final program?) {
      if (program.positionOf(routine.id) case final position?) {
        _programs.linkWorkout(workout.id, program.id, position);
      }
    }
    return workout;
  });
}
