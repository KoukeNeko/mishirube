import '../../data/models.dart';

/// Independent, combinable filter dimensions for the exercise catalog.
/// An empty set means "no constraint" for that dimension.
class ExerciseFilter {
  const ExerciseFilter({
    this.muscles = const {},
    this.equipment = const {},
    this.patterns = const {},
    this.trackingTypes = const {},
    this.sources = const {},
  });

  static const defaultForLowerBody = ExerciseFilter(
    muscles: {MuscleGroup.quads, MuscleGroup.glutes},
    equipment: {Equipment.barbell},
  );

  final Set<MuscleGroup> muscles;
  final Set<Equipment> equipment;
  final Set<MovementPattern> patterns;
  final Set<TrackingType> trackingTypes;
  final Set<ExerciseSource> sources;

  int get activeCount =>
      muscles.length +
      equipment.length +
      patterns.length +
      trackingTypes.length +
      sources.length;

  bool get isEmpty => activeCount == 0;

  String get summary => [
    if (muscles.isNotEmpty) muscles.map((m) => m.label).join('、'),
    if (equipment.isNotEmpty) equipment.map((e) => e.label).join('、'),
    if (patterns.isNotEmpty) patterns.map((p) => p.label).join('、'),
    if (trackingTypes.isNotEmpty) trackingTypes.map((t) => t.label).join('、'),
    if (sources.isNotEmpty) sources.map((s) => s.label).join('、'),
  ].join(' · ');

  bool matches(ExerciseDefinition exercise) =>
      _allows(muscles, exercise.primaryMuscles) &&
      _allowsOne(equipment, exercise.equipment) &&
      _allowsOne(patterns, exercise.pattern) &&
      _allowsOne(trackingTypes, exercise.trackingType) &&
      _allowsOne(sources, exercise.source);

  bool _allows<T>(Set<T> accepted, List<T> values) =>
      accepted.isEmpty || values.any(accepted.contains);

  bool _allowsOne<T>(Set<T> accepted, T value) =>
      accepted.isEmpty || accepted.contains(value);

  ExerciseFilter copyWith({
    Set<MuscleGroup>? muscles,
    Set<Equipment>? equipment,
    Set<MovementPattern>? patterns,
    Set<TrackingType>? trackingTypes,
    Set<ExerciseSource>? sources,
  }) => ExerciseFilter(
    muscles: muscles ?? this.muscles,
    equipment: equipment ?? this.equipment,
    patterns: patterns ?? this.patterns,
    trackingTypes: trackingTypes ?? this.trackingTypes,
    sources: sources ?? this.sources,
  );
}

/// Returns a copy of [values] with [value] added or removed.
Set<T> toggled<T>(Set<T> values, T value) =>
    values.contains(value) ? ({...values}..remove(value)) : {...values, value};
