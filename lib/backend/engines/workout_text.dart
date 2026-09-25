/// A workout written as text — typed, or pasted from a chat with a
/// language model — read line by line into exercises and their sets:
/// `1. 槓鈴深蹲 4×8 60kg`, `- 臥推：3 組 10 下 40 公斤`, `Pull-up 3x8`,
/// or an exercise with its sets on the lines under it, as workout apps
/// share a log: `1組: 12kg 10次`. Deterministic: a list someone else
/// wrote is already structured, and reading it needs no model.
library;

import '../../domain/domain.dart';

/// One exercise as written: its name, and whatever of its sets, reps
/// and weight the line gave.
class WorkoutLine {
  const WorkoutLine({
    required this.name,
    required this.text,
    this.otherName,
    this.sets,
    this.reps,
    this.weightKg,
    this.loads = const [],
  });

  /// The exercise's name, the figures and list marks taken off.
  final String name;

  /// Another name for the same exercise, tried alongside [name]: the
  /// English name a model gives beside the Chinese one.
  final String? otherName;

  /// The line as written, for showing what an unmatched name came from.
  final String text;
  final int? sets;
  final int? reps;
  final double? weightKg;

  /// Each set as the lines under the name gave it, when they did.
  final List<SetLoad> loads;

  /// This exercise with [load] as its next set.
  WorkoutLine withSet(SetLoad load) {
    final all = [...loads, load];
    return WorkoutLine(
      name: name,
      text: text,
      otherName: otherName,
      sets: all.length,
      reps: load.reps,
      weightKg: load.weightKg,
      loads: all,
    );
  }
}

/// A range, `10–12`, is read at its low end: what the plan asks at least.
const _upTo = r'(?:\s*[-–—~～至到]\s*\d+(?:\.\d+)?)?';
const _times = r'\s*[x×X＊*]\s*';

/// `1.`, `-`, `（1）`, and a row number before its name, `1 啞鈴划船`.
final _listMark = RegExp(
  r'^\s*(?:[-*•・‧]|\d+\s*[.、)）]|[（(]\d+[)）]|\d+\s+(?![\dx×X＊*組]))\s*',
);
final _weight = RegExp(
  r'(\d+(?:\.\d+)?)' + _upTo + r'\s*(?:kg|公斤)',
  caseSensitive: false,
);

/// `2 × 60 秒`: sets held for a time, which has no reps to plan.
final _setsTimesHold = RegExp(
  r'(\d+)' + _times + r'\d+' + _upTo + r'\s*(?:秒|分鐘|sec\b|min\b|s\b)',
  caseSensitive: false,
);
final _setsTimesReps = RegExp(r'(\d+)' + _times + r'(\d+)' + _upTo);
final _sets = RegExp(r'(\d+)' + _upTo + r'\s*組');
final _reps = RegExp(
  r'(\d+)' + _upTo + r'\s*(?:下|次|reps?\b)',
  caseSensitive: false,
);
final _hold = RegExp(
  r'\d+' + _upTo + r'\s*(?:秒|分鐘|sec\b|min\b)',
  caseSensitive: false,
);

/// `／側`, `每邊`: the count is per side, which the plan already means.
final _perSide = RegExp(r'[／/]\s*[側邊手腿腳]|每[側邊手腿腳]');

/// Columns of a table: tabs or runs of spaces as copied from a chat, or
/// Markdown pipes.
final _column = RegExp(r'[\t|｜]|\s{2,}');
final _leftover = RegExp(r'[：:,，、;；/（）()@＠]+|(?<!\S)[-–—~～]+(?!\S)');
final _sentenceEnd = RegExp(r'[。！？!?]');
final _letter = RegExp(r'\p{L}', unicode: true);

/// A set on a line of its own, under its exercise: `1組: 12kg 10次`,
/// `第 2 組：60 公斤 x 8`, `Set 3: 15 reps`.
final _setLine = RegExp(
  r'^\s*(?:第\s*\d+\s*組|\d+\s*組|set\s*\d+)\s*[:：]',
  caseSensitive: false,
);
final _bareReps = RegExp(r'[x×X＊*]\s*(\d+)');

/// Each line of [text] that names something, in order, with the sets
/// on the lines under it. Headings, sentences around the list, and lines
/// with no name once their figures are read are skipped.
List<WorkoutLine> parseWorkoutText(String text) {
  final lines = <WorkoutLine>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    if (_setLine.hasMatch(raw)) {
      // A set with no exercise above it belongs to nothing.
      final load = _loadOf(raw);
      if (load != null && lines.isNotEmpty) {
        lines.last = lines.last.withSet(load);
      }
      continue;
    }
    if (_lineOf(raw) case final line?) lines.add(line);
  }
  return lines;
}

/// The weight and reps a set line gives; null without reps, such as a
/// set held for a time. No weight is bodyweight.
SetLoad? _loadOf(String raw) {
  final line = raw.replaceFirst(_setLine, '');
  final weight = _weight.firstMatch(line);
  final rest = weight == null
      ? line
      : line.replaceRange(weight.start, weight.end, ' ');
  final reps = (_reps.firstMatch(rest) ?? _bareReps.firstMatch(rest))?[1];
  if (reps == null) return null;
  return (
    weightKg: weight == null ? 0 : double.parse(weight[1]!),
    reps: int.parse(reps),
  );
}

WorkoutLine? _lineOf(String raw) {
  var line = raw.replaceFirst(_listMark, '').trim();
  // Empty, a heading over the list, `今天的課表：`, or a sentence.
  if (line.isEmpty ||
      line.endsWith(':') ||
      line.endsWith('：') ||
      _sentenceEnd.hasMatch(line)) {
    return null;
  }
  int? sets;
  int? reps;
  double? weightKg;
  void take(RegExp pattern, void Function(Match) read) {
    final match = pattern.firstMatch(line);
    if (match == null) return;
    read(match);
    line = line.replaceRange(match.start, match.end, ' ');
  }

  take(_weight, (match) => weightKg = double.parse(match[1]!));
  if (_setsTimesHold.hasMatch(line)) {
    take(_setsTimesHold, (match) => sets = int.parse(match[1]!));
  } else if (_setsTimesReps.hasMatch(line)) {
    take(_setsTimesReps, (match) {
      sets = int.parse(match[1]!);
      reps = int.parse(match[2]!);
    });
  } else {
    take(_sets, (match) => sets = int.parse(match[1]!));
    take(_reps, (match) => reps = int.parse(match[1]!));
  }
  line = line.replaceAll(_hold, ' ').replaceAll(_perSide, ' ');
  // In a table the name is the first column with words in it: the row
  // number before it has none, and a note after it is not the name.
  final name = line
      .split(_column)
      .map(
        (column) => column
            .replaceAll(_leftover, ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      )
      .firstWhere(_letter.hasMatch, orElse: () => '');
  if (name.isEmpty) return null;
  return WorkoutLine(
    name: name,
    text: raw.trim(),
    sets: sets,
    reps: reps,
    weightKg: weightKg,
  );
}
