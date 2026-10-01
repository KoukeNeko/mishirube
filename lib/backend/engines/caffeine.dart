import 'dart:math' as math;

import '../../domain/domain.dart';

/// Bumped whenever the arithmetic below changes.
const caffeineEngineVersion = 1;

/// The half-life the estimate assumes, in hours.
///
/// A population middle value. Published adult half-lives run from about
/// 1.5 to 9.5 hours — smoking shortens it, oral contraceptives and late
/// pregnancy lengthen it a lot — so the same 100 mg eight hours ago
/// leaves anywhere between roughly 2 and 59 mg. One number cannot be
/// right for everyone, and a slider would only dress that up as
/// something the user could calibrate.
const caffeineHalfLifeHours = 5.0;

/// What this model leaves at bedtime from the timing a meta-analysis
/// found keeps total sleep time from falling: 107 mg at least 8.8 h
/// before bed, or 217.5 mg at least 13.2 h before (Gardiner et al.,
/// 2023, Sleep Med Rev 69:101764, PMID 36870101). At
/// [caffeineHalfLifeHours] those leave 31.6 and 34.9 mg.
///
/// Worked out here, not measured: the study set no residual threshold,
/// and clearance and sensitivity vary from person to person. It is drawn
/// as a dashed reference, never as a safe line.
const caffeineBedtimeReferenceMg = 35.0;

/// One recorded caffeine intake.
class CaffeineIntake {
  const CaffeineIntake({required this.at, required this.milligrams});

  final DateTime at;
  final double milligrams;
}

/// How much caffeine is likely still in the body, in milligrams.
///
/// Each intake decays on its own and the estimates are added together.
/// A single exponential is the shape population pharmacokinetics finds
/// once absorption is done; what it cannot know is the half-life for
/// this particular person, which is why nothing here is a measurement.
///
/// **This is an estimate, never a reading.** It must not become a
/// budget for another cup, and no residual figure is a validated line
/// below which sleep is unaffected: trials find 400 mg twelve hours
/// before bed still changes sleep while 100 mg four hours before does
/// not. [caffeineBedtimeReferenceMg] is a reference, not such a line.
double estimatedCaffeineRemaining(
  Iterable<CaffeineIntake> intakes, {
  required DateTime now,
  double halfLifeHours = caffeineHalfLifeHours,
}) {
  var remaining = 0.0;
  for (final intake in intakes) {
    final hours = now.difference(intake.at).inMinutes / 60;
    // Caffeine taken later than `now` has not been drunk yet.
    if (hours < 0) continue;
    remaining += intake.milligrams * math.pow(0.5, hours / halfLifeHours);
  }
  return remaining;
}

/// When [estimatedCaffeineRemaining] falls under
/// [caffeineBedtimeReferenceMg] after [now]; null while it is under it.
///
/// Every intake halves at the same rate, so once the last one is drunk
/// their sum is a single exponential and the crossing has a closed form,
/// worked out here to the minute rather than read off a curve.
DateTime? caffeineFallsBelowReference(
  Iterable<CaffeineIntake> intakes, {
  required DateTime now,
  double halfLifeHours = caffeineHalfLifeHours,
}) {
  final remaining = estimatedCaffeineRemaining(
    intakes,
    now: now,
    halfLifeHours: halfLifeHours,
  );
  if (remaining < caffeineBedtimeReferenceMg) return null;
  final hours =
      halfLifeHours *
      math.log(remaining / caffeineBedtimeReferenceMg) /
      math.ln2;
  return now.add(Duration(minutes: (hours * 60).ceil()));
}

/// The caffeine [meals] recorded, as intakes to estimate from.
List<CaffeineIntake> caffeineIntakes(Iterable<(DateTime, MealEvent)> meals) => [
  for (final (at, meal) in meals)
    if (meal.nutrients[Nutrient.caffeine] case final milligrams?)
      CaffeineIntake(at: at, milligrams: milligrams),
];

/// [estimatedCaffeineRemaining] every [step] from [from] to [to], both
/// included: the curve the estimate draws, past and still to come.
List<(DateTime, double)> caffeineCurve(
  Iterable<CaffeineIntake> intakes, {
  required DateTime from,
  required DateTime to,
  Duration step = const Duration(minutes: 10),
  double halfLifeHours = caffeineHalfLifeHours,
}) => [
  for (var at = from; !at.isAfter(to); at = at.add(step))
    (
      at,
      estimatedCaffeineRemaining(
        intakes,
        now: at,
        halfLifeHours: halfLifeHours,
      ),
    ),
];

/// How far back and ahead of now the caffeine curve is drawn.
const caffeineCurveBack = Duration(hours: 8);
const caffeineCurveAhead = Duration(hours: 16);

/// [caffeineCurve] from [caffeineCurveBack] before [at] to
/// [caffeineCurveAhead] after it, and where [at] falls on it; null when
/// none of it comes to a milligram.
({List<(DateTime, double)> curve, int nowIndex})? caffeineAround(
  Iterable<CaffeineIntake> intakes, {
  required DateTime at,
  Duration step = const Duration(minutes: 10),
}) {
  final from = at.subtract(caffeineCurveBack);
  final curve = caffeineCurve(
    intakes,
    from: from,
    to: at.add(caffeineCurveAhead),
    step: step,
  );
  if (!curve.any((point) => point.$2 >= 1)) return null;
  return (
    curve: curve,
    nowIndex: at.difference(from).inMinutes ~/ step.inMinutes,
  );
}
