import '../../domain/domain.dart';
import '../engines/substitution_engine.dart' as engine;
import '../storage/database.dart';
import '../storage/exercise_repository.dart';

/// The exercise catalog as the pickers use it: search, favourites, custom
/// exercises, personal history and fair swaps.
class CatalogService {
  CatalogService(this._db, this._exercises);

  final AppDatabase _db;
  final ExerciseRepository _exercises;

  List<ExerciseDefinition> all() => _exercises.all();

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

  void setFavorite(String id, {required bool isFavorite}) =>
      _exercises.setFavorite(id, isFavorite: isFavorite);

  /// Hides an exercise from the pickers without touching its history.
  void setHidden(String id, {required bool isHidden}) =>
      _exercises.setHidden(id, isHidden: isHidden);

  List<SubstitutionOption> substitutesFor(ExerciseDefinition exercise) =>
      engine.substitutesFor(exercise, all());

  /// A fresh id for a custom exercise.
  String newExerciseId() => 'custom-${_db.newId()}';
}
