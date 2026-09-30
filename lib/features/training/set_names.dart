import '../../domain/domain.dart';
import '../../l10n/l10n.dart';

/// A working set's number among the working sets, since warm-ups come
/// first; null for any other kind of set.
int? workingNumber(List<WorkoutSet> sets, int index) {
  if (sets[index].type != SetType.working) return null;
  return sets
      .take(index + 1)
      .where((item) => item.type == SetType.working)
      .length;
}

/// `第 2 組`, or the kind of set it is: `熱身組`.
String setName(AppLocalizations l10n, WorkoutSet set, int? number) =>
    number == null ? set.type.labelIn(l10n) : l10n.setOrdinal(number: number);
