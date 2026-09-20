import '../../domain/domain.dart';
import '../storage/database.dart';
import '../storage/journal_repository.dart';

/// Body measurements and wellness check-ins.
class JournalService {
  JournalService(this._db, this._journal);

  final AppDatabase _db;
  final JournalRepository _journal;

  BodyWeight recordWeight(double kilograms, {String note = '', DateTime? at}) {
    final weight = BodyWeight(
      id: _db.newId(),
      measuredAt: at ?? _db.now(),
      weightKg: kilograms,
      note: note,
    );
    _journal.addWeight(weight);
    return weight;
  }

  WellnessEntry recordWellness(
    WellnessKind kind,
    int score, {
    String note = '',
    DateTime? at,
  }) {
    final entry = WellnessEntry(
      id: _db.newId(),
      recordedAt: at ?? _db.now(),
      kind: kind,
      score: score,
      note: note,
    );
    _journal.addWellness(entry);
    return entry;
  }

  /// Weights measured in the [window] ending now, oldest first.
  List<BodyWeight> recentWeights(Duration window) =>
      _journal.weightsBetween(_db.now().subtract(window), _db.now());

  List<WellnessEntry> recentWellness(Duration window) =>
      _journal.wellnessBetween(_db.now().subtract(window), _db.now());
}
