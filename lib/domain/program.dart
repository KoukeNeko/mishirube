/// How a program's workouts come round.
enum ProgramSchedule {
  /// One after another, whatever the date: a missed one waits.
  rotation('照順序輪替'),

  /// Each on its weekday.
  weekdays('固定星期');

  const ProgramSchedule(this.label);

  final String label;
}

/// One workout of a program: the routine trained, and in a weekday
/// program its weekday (1 is Monday).
class ProgramDay {
  const ProgramDay({required this.routineId, this.weekday});

  final String routineId;
  final int? weekday;

  ProgramDay onWeekday(int? weekday) =>
      ProgramDay(routineId: routineId, weekday: weekday);
}

/// Workouts trained in turn or on set weekdays. Each is a routine of the
/// program's own, copied in rather than shared, so editing one elsewhere
/// never changes a program quietly; a finished workout is never
/// rewritten by editing either.
class Program {
  const Program({
    required this.id,
    required this.name,
    required this.schedule,
    required this.days,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String name;
  final ProgramSchedule schedule;
  final List<ProgramDay> days;

  /// When it was started and, once stopped, when; a program not yet
  /// started has neither.
  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isRunning => startedAt != null && endedAt == null;

  /// The position of [routineId] in the program; null when not in it.
  int? positionOf(String routineId) {
    final index = days.indexWhere((day) => day.routineId == routineId);
    return index < 0 ? null : index;
  }

  Program copyWith({
    String? name,
    ProgramSchedule? schedule,
    List<ProgramDay>? days,
    DateTime? Function()? startedAt,
    DateTime? Function()? endedAt,
  }) => Program(
    id: id,
    name: name ?? this.name,
    schedule: schedule ?? this.schedule,
    days: days ?? this.days,
    startedAt: startedAt == null ? this.startedAt : startedAt(),
    endedAt: endedAt == null ? this.endedAt : endedAt(),
  );
}

/// A workout of a running program that has come and gone: trained, or
/// skipped by choice. One simply not trained is neither, and never
/// counts against anything.
class ProgramDayRecord {
  const ProgramDayRecord({required this.day, required this.at, this.workoutId});

  /// The workout's position in the program.
  final int day;
  final DateTime at;

  /// The finished workout; null when it was skipped.
  final String? workoutId;

  bool get isSkipped => workoutId == null;
}

/// Where a running program stands today.
class ProgramProgress {
  const ProgramProgress({
    required this.program,
    required this.nextDay,
    required this.records,
  });

  final Program program;

  /// The position of the workout to train next.
  final int nextDay;

  /// Its workouts so far, trained and skipped, oldest first.
  final List<ProgramDayRecord> records;

  ProgramDay get next => program.days[nextDay];

  /// How many of its workouts were trained.
  int get completed => records.where((record) => !record.isSkipped).length;
}

/// A ready-made program to start from: its workouts, each a list of
/// exercises by catalogue id with sets and reps.
class ProgramTemplate {
  const ProgramTemplate({required this.name, required this.workouts});

  final String name;
  final List<TemplateWorkout> workouts;
}

class TemplateWorkout {
  const TemplateWorkout(this.name, this.exercises);

  final String name;

  /// Exercise id, sets, reps.
  final List<(String, int, int)> exercises;
}
