/// Which day a record belonged to, and to whom.
///
/// A record's instant says when it happened; it does not say which day
/// that was. The same moment is Monday night in Taipei and Monday
/// morning in Los Angeles, so a day can only be decided by the clock
/// the person was living under when they recorded it. That is kept with
/// the record, not re-derived from the phone's current zone.
library;

/// The calendar day [at] falls on, as `yyyymmdd`.
///
/// An integer rather than a date because it is an identity, not a
/// moment: two records share a day when this number matches, whatever
/// zone either of them was recorded in.
int localDayOf(DateTime at) => at.year * 10000 + at.month * 100 + at.day;

/// The first moment of [localDay] in the reader's own zone, for
/// labelling and for arithmetic between days.
DateTime dayOfLocalDay(int localDay) =>
    DateTime(localDay ~/ 10000, localDay ~/ 100 % 100, localDay % 100);

/// [at] as the wall clock showed it to somebody at [utcOffsetMinutes].
///
/// The result's fields are the time they read off their phone; its
/// instant is not, so it is for showing and grouping, never for storing
/// back. A null offset means the record predates this being kept, and
/// the reader's own zone is the best guess available.
DateTime asLived(DateTime at, int? utcOffsetMinutes) {
  if (utcOffsetMinutes == null) return at;
  final shifted = at.toUtc().add(Duration(minutes: utcOffsetMinutes));
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
  );
}
