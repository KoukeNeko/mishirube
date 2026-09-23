/// What the app reads from a health platform. Each has a record of its
/// own here already; nothing is read that would have nowhere to go.
enum HealthDataKind {
  sleep('睡眠'),
  weight('體重'),
  waist('腰圍'),
  workouts('運動'),
  water('喝水'),

  /// Heart rate, breathing, blood oxygen, temperature and heart rate
  /// variability, read only for the time a sleep covers.
  overnight('夜間數據');

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
