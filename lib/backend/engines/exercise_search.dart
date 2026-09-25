import '../../domain/domain.dart';

/// Bumped whenever the matching or ranking below changes.
const exerciseSearchVersion = 1;

/// How close a typo may be and still match, as shared two-letter pieces
/// over the longer word's pieces.
const _fuzzyThreshold = 0.5;

/// Signals, strongest first. A name match outranks everything: the user
/// typed it. Familiarity (recent, often used, favourite, equipment they
/// have) only orders what already matched.
const _exactScore = 100;
const _prefixScore = 70;
const _substringScore = 45;
const _fuzzyScore = 20;
const _aliasPenalty = 5;
const _favoriteScore = 6;
const _homeGymScore = 4;
const _recentScore = 12;
const _recentDays = 30;
const _frequentScore = 6;
const _frequentSessions = 20;

/// How a name matched, so a caller can tell a real hit from a guess.
enum SearchMatch { none, fuzzy, substring, prefix, exact }

/// One catalog entry as a search result.
class ExerciseSearchResult {
  const ExerciseSearchResult({
    required this.exercise,
    required this.match,
    required this.score,
  });

  final ExerciseDefinition exercise;
  final SearchMatch match;
  final int score;
}

/// Searches and ranks [catalog].
///
/// Matching normalises width, case, spacing and punctuation, and looks at
/// the name, the aliases and the equipment word, so 「臥推」, `bench press`
/// and `Bench-Press` all find the same exercise. Ranking is deterministic:
/// the same catalog and query always give the same order, and ties fall
/// back to the name so the list never shuffles between opens.
List<ExerciseSearchResult> searchExercises(
  Iterable<ExerciseDefinition> catalog, {
  String query = '',
  ExerciseFilter filter = const ExerciseFilter(),
  bool includeHidden = false,
  bool allowFuzzy = true,
}) {
  final normalizedQuery = normalizeTerm(query);
  final results = <ExerciseSearchResult>[];
  for (final exercise in catalog) {
    if (exercise.isHidden && !includeHidden) continue;
    if (!filter.matches(exercise)) continue;
    final (match, isOnName) = normalizedQuery.isEmpty
        ? (SearchMatch.none, true)
        : _matchOf(exercise, normalizedQuery, allowFuzzy: allowFuzzy);
    if (normalizedQuery.isNotEmpty && match == SearchMatch.none) continue;
    results.add(
      ExerciseSearchResult(
        exercise: exercise,
        match: match,
        score: _scoreOf(exercise, match, isOnName: isOnName),
      ),
    );
  }
  results.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.exercise.name.compareTo(b.exercise.name);
  });
  return results;
}

/// Exercises that may already be what the user is about to create, so a
/// second 「啞鈴臥推」 does not start its own history.
List<ExerciseDefinition> duplicateCandidates(
  String name,
  Iterable<ExerciseDefinition> catalog, {
  int count = 3,
}) => [
  for (final result in searchExercises(
    catalog,
    query: name,
    includeHidden: true,
  ).take(count))
    result.exercise,
];

/// Lowercases, folds full-width characters to half-width, and drops
/// spacing and punctuation, so `Bench-Press`, `bench press` and
/// `ＢＥＮＣＨ　ＰＲＥＳＳ` all normalise alike.
String normalizeTerm(String value) {
  final buffer = StringBuffer();
  for (final char in _foldWidth(value.trim().toLowerCase()).split('')) {
    if (char == ' ' || char == '　' || char == '-' || char == '_') continue;
    buffer.write(char);
  }
  return buffer.toString();
}

/// Full-width forms sit a fixed distance above their ASCII twins.
String _foldWidth(String value) => String.fromCharCodes([
  for (final rune in value.runes)
    rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune,
]);

/// How much of a name must be shared for [closestExercise] to take it.
const _closeEnough = 0.5;

final _word = RegExp(r'[a-z0-9]+|\p{L}', unicode: true);

/// The exercise [names] most likely mean, when someone else wrote them:
/// the one sharing the most of a name's words — each Chinese character,
/// each English word — through its own name or an alias, so
/// 「單手啞鈴划船」 finds 單臂啞鈴划船 by its alias 啞鈴單手划船 and
/// 「反向腕彎舉」 finds 腕伸 by 反握手腕彎舉. [names] are the same exercise
/// named more than one way, such as in Chinese and in English. Null when
/// nothing shares half. A tie goes to the more familiar exercise.
ExerciseDefinition? closestExercise(
  Iterable<String> names,
  Iterable<ExerciseDefinition> catalog,
) {
  final wanted = [
    for (final name in names)
      if (_wordsOf(name) case final words when words.isNotEmpty) words,
  ];
  if (wanted.isEmpty) return null;
  ExerciseDefinition? closest;
  var closestShare = 0.0;
  for (final result in searchExercises(catalog)) {
    final exercise = result.exercise;
    for (final term in [
      exercise.name,
      ...exercise.personalAliases,
      ...exercise.aliases,
    ]) {
      final words = _wordsOf(term);
      for (final name in wanted) {
        final share =
            words.intersection(name).length / words.union(name).length;
        if (share >= _closeEnough && share > closestShare) {
          closest = exercise;
          closestShare = share;
        }
      }
    }
  }
  return closest;
}

Set<String> _wordsOf(String value) => {
  for (final match in _word.allMatches(_foldWidth(value.toLowerCase())))
    match[0]!,
};

/// The best match over an exercise's searchable terms, and whether it
/// came from the name rather than an alias, the equipment or a muscle.
(SearchMatch, bool) _matchOf(
  ExerciseDefinition exercise,
  String query, {
  required bool allowFuzzy,
}) {
  var best = SearchMatch.none;
  var isOnName = false;
  final terms = [
    exercise.name,
    ...exercise.personalAliases,
    ...exercise.aliases,
    exercise.equipment.label,
    ...exercise.primaryMuscles.map((muscle) => muscle.label),
  ];
  for (final (index, term) in terms.indexed) {
    final normalized = normalizeTerm(term);
    final match = switch (normalized) {
      _ when normalized == query => SearchMatch.exact,
      _ when normalized.startsWith(query) => SearchMatch.prefix,
      _ when normalized.contains(query) => SearchMatch.substring,
      _ when allowFuzzy && _isNearlyEqual(normalized, query) =>
        SearchMatch.fuzzy,
      _ => SearchMatch.none,
    };
    if (match.index > best.index) {
      best = match;
      isOnName = index == 0;
    }
    if (best == SearchMatch.exact) break;
  }
  return (best, isOnName);
}

int _scoreOf(
  ExerciseDefinition exercise,
  SearchMatch match, {
  required bool isOnName,
}) {
  final matchScore = switch (match) {
    SearchMatch.exact => _exactScore,
    SearchMatch.prefix => _prefixScore,
    SearchMatch.substring => _substringScore,
    SearchMatch.fuzzy => _fuzzyScore,
    SearchMatch.none => 0,
  };
  final days = exercise.lastUsedDaysAgo;
  // A hit on the name itself beats the same hit on an alias.
  return matchScore -
      (isOnName ? 0 : _aliasPenalty) +
      (exercise.isFavorite ? _favoriteScore : 0) +
      (exercise.isInHomeGym ? _homeGymScore : 0) +
      (days != null && days <= _recentDays
          ? (_recentScore * (_recentDays - days) / _recentDays).round()
          : 0) +
      (exercise.recordCount >= _frequentSessions ? _frequentScore : 0);
}

/// Two-letter overlap, which catches a swapped or missing letter without
/// matching unrelated words.
bool _isNearlyEqual(String a, String b) {
  if (a.length < 3 || b.length < 3) return false;
  Set<String> pieces(String value) => {
    for (var i = 0; i + 2 <= value.length; i++) value.substring(i, i + 2),
  };
  final left = pieces(a);
  final right = pieces(b);
  final shared = left.intersection(right).length;
  return shared / (left.length > right.length ? left.length : right.length) >=
      _fuzzyThreshold;
}
