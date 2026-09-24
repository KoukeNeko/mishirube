import '../../domain/domain.dart';

/// Where [program] stands at [now], from what was trained and skipped:
/// nothing about it is stored but the records themselves.
///
/// In rotation the next workout follows the last one done or skipped.
/// On weekdays it is today's if not yet done, else the next one to
/// come. A missed workout is never a failure; it only waits (rotation)
/// or passes (weekdays).
ProgramProgress programProgress(
  Program program,
  List<ProgramDayRecord> records,
  DateTime now,
) => ProgramProgress(
  program: program,
  nextDay: switch (program.schedule) {
    ProgramSchedule.rotation =>
      records.isEmpty || program.days.isEmpty
          ? 0
          : (records.last.day + 1) % program.days.length,
    ProgramSchedule.weekdays => _nextOnWeekdays(
      program,
      records,
      DateTime(now.year, now.month, now.day),
    ),
  },
  records: records,
);

/// Today's workout when it has not been done today, else the next
/// weekday's.
int _nextOnWeekdays(
  Program program,
  List<ProgramDayRecord> records,
  DateTime today,
) {
  bool doneToday(int day) => records.any(
    (record) =>
        record.day == day &&
        record.at.year == today.year &&
        record.at.month == today.month &&
        record.at.day == today.day,
  );
  for (var ahead = 0; ahead < DateTime.daysPerWeek; ahead++) {
    final weekday = (today.weekday - 1 + ahead) % DateTime.daysPerWeek + 1;
    for (final (index, day) in program.days.indexed) {
      if (day.weekday != weekday) continue;
      if (ahead == 0 && doneToday(index)) continue;
      return index;
    }
  }
  return 0;
}
