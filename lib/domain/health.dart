import 'body.dart';
import 'nutrition.dart';

/// What the app reads from a health platform. Each has a record of its
/// own here already; nothing is read that would have nowhere to go.
enum HealthDataKind {
  sleep,
  weight,
  waist,

  /// Height, and what a body composition scale wrote to the platform.
  body,
  workouts,
  water,

  /// What was eaten and drunk, as another app logged it: each entry with
  /// its energy and nutrients, caffeine logged on its own among them.
  nutrition,

  /// How the user said they felt (Apple Health's State of Mind); Health
  /// Connect keeps no such record.
  mood,

  /// Heart rate, breathing, blood oxygen, temperature and heart rate
  /// variability, read only for the time a sleep covers.
  overnight,

  /// Steps, distance, energy, floors, exercise minutes, and the heart
  /// and fitness figures measured through the day (see [ActivityMetric]).
  activity,
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

/// Something eaten or drunk, from a health platform: one entry as the app
/// that wrote it logged it.
class HealthFood {
  const HealthFood({
    required this.id,
    required this.at,
    required this.sourceName,
    this.name,
    this.mealType,
    this.kcal,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.fibreGrams,
    this.nutrients = const {},
  });

  final String id;
  final DateTime at;

  /// The app that logged it, such as `MyFitnessPal`.
  final String sourceName;

  /// The food's name, when the app gave one.
  final String? name;
  final MealType? mealType;
  final double? kcal;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;
  final double? fibreGrams;

  /// Everything else it recorded, in each nutrient's own unit.
  final Nutrients nutrients;
}

/// A mood the user logged in a health platform: how pleasant it felt,
/// from −1 (very unpleasant) to 1 (very pleasant).
class HealthMood {
  const HealthMood({required this.id, required this.at, required this.valence});

  final String id;
  final DateTime at;
  final double valence;
}
