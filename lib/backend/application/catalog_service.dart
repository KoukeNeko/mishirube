import '../../domain/domain.dart';
import '../engines/exercise_search.dart' as finder;
import '../engines/substitution_engine.dart' as engine;
import '../storage/database.dart';
import '../storage/exercise_repository.dart';

/// Refusing a change that would make old records mean something else.
class TrackingChangeRefused implements Exception {
  const TrackingChangeRefused(this.sessionCount);

  /// How many finished sessions the exercise already has.
  final int sessionCount;

  @override
  String toString() =>
      'TrackingChangeRefused: $sessionCount sessions already recorded';
}

/// The exercise catalog as the pickers use it: search, favourites, custom
/// exercises, personal history and fair swaps.
class CatalogService {
  CatalogService(this._db, this._exercises);

  final AppDatabase _db;
  final ExerciseRepository _exercises;

  List<ExerciseDefinition> all() => _exercises.all();

  /// Catalog entries matching [query] and [filter], best first. With no
  /// query it is the whole catalog in familiarity order.
  List<ExerciseDefinition> search({
    String query = '',
    ExerciseFilter filter = const ExerciseFilter(),
    bool includeHidden = false,
  }) => [
    for (final result in finder.searchExercises(
      all(),
      query: query,
      filter: filter,
      includeHidden: includeHidden,
    ))
      result.exercise,
  ];

  /// Exercises that may already be what [name] describes, so the user can
  /// reuse one instead of starting a second history for it.
  List<ExerciseDefinition> duplicateCandidatesFor(String name) =>
      finder.duplicateCandidates(name, all());

  ExerciseDefinition? byId(String id) => _exercises.byId(id);

  ExerciseHistory history(String exerciseId) => _exercises.history(exerciseId);

  /// Working sets per finished session, oldest first.
  List<(DateTime, int)> sessionSetCounts(String exerciseId) =>
      _exercises.sessionSetCounts(exerciseId);

  /// Stores a user-made exercise. An id that already exists is returned as
  /// it is, so a repeated tap does not create the same exercise twice.
  ExerciseDefinition create(ExerciseDefinition exercise) {
    final existing = _exercises.byId(exercise.id);
    if (existing != null) return existing;
    _exercises.save(exercise);
    return _exercises.byId(exercise.id)!;
  }

  /// Saves an edited exercise.
  ///
  /// The tracking type is part of how its history reads, so once sessions
  /// exist it cannot change: the old sets would silently start meaning
  /// something else. Everything else is free to change, and the id stays,
  /// so the history follows the exercise.
  ExerciseDefinition update(ExerciseDefinition exercise) {
    final existing = _exercises.byId(exercise.id);
    if (existing == null) return create(exercise);
    if (existing.trackingType != exercise.trackingType) {
      final sessions = _exercises.history(exercise.id).sessionCount;
      if (sessions > 0) throw TrackingChangeRefused(sessions);
    }
    _exercises.save(exercise);
    return _exercises.byId(exercise.id)!;
  }

  void setFavorite(String id, {required bool isFavorite}) =>
      _exercises.setFavorite(id, isFavorite: isFavorite);

  /// Replaces the names this user gave an exercise; the catalog's own
  /// names stay as they are.
  void setPersonalAliases(String id, List<String> aliases) =>
      _exercises.setPersonalAliases(id, aliases);

  /// Hides an exercise from the pickers without touching its history.
  void setHidden(String id, {required bool isHidden}) =>
      _exercises.setHidden(id, isHidden: isHidden);

  List<SubstitutionOption> substitutesFor(ExerciseDefinition exercise) =>
      engine.substitutesFor(exercise, all());

  /// A fresh id for a custom exercise.
  String newExerciseId() => 'custom-${_db.newId()}';
}
