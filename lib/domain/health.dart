import 'body.dart';

/// What the app reads from a health platform. Each has a record of its
/// own here already; nothing is read that would have nowhere to go.
enum HealthDataKind {
  sleep('睡眠'),
  weight('體重'),
  waist('腰圍'),

  /// Height, and what a body composition scale wrote to the platform.
  body('身體組成'),
  workouts('運動'),
  water('喝水'),

  /// Heart rate, breathing, blood oxygen, temperature and heart rate
  /// variability, read only for the time a sleep covers.
  overnight('夜間數據'),

  /// Steps, distance, energy, floors, exercise minutes, and the heart
  /// and fitness figures measured through the day (see [ActivityMetric]).
  activity('活動與心肺');

  const HealthDataKind(this.label);

  final String label;
}

/// A weighing from a health platform, with the platform's own id.
class HealthWeight {
  const HealthWeight({required this.id, required this.at, required this.kg});

  final String id;
  final DateTime at;
  final double kg;
}

/// A waist measurement from a health platform.
class HealthWaist {
  const HealthWaist({required this.id, required this.at, required this.cm});

  final String id;
  final DateTime at;
  final double cm;
}

/// A body figure from a health platform, already in the app's unit:
/// body fat in percent however the platform keeps it, basal metabolic
/// rate in kcal a day.
class HealthBodyReading {
  const HealthBodyReading({
    required this.id,
    required this.at,
    required this.metric,
    required this.value,
  });

  final String id;
  final DateTime at;
  final BodyMetric metric;
  final double value;
}

/// A workout from a health platform. [activity] is one of the app's
/// activity type ids, or `other`; [nativeType] is the platform's own
/// name for it, kept so a later mapping can reinterpret it.
class HealthWorkout {
  const HealthWorkout({
    required this.id,
    required this.start,
    required this.end,
    required this.activity,
    required this.nativeType,
    this.distanceMeters,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String activity;
  final String nativeType;
  final double? distanceMeters;
}

/// Water drunk, from a health platform.
class HealthWater {
  const HealthWater({required this.id, required this.at, required this.ml});

  final String id;
  final DateTime at;
  final int ml;
}
