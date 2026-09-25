import 'dart:convert';

import '../../domain/domain.dart';
import '../engines/workout_text.dart';

/// What every provider is asked about a workout written as text, when
/// the rules in `workout_text.dart` could not read all of it. Apple's
/// side also constrains the answer to this shape.
const workoutDraftInstructions = '''
你把使用者貼上的訓練內容整理成動作清單。
只回傳 JSON，不要任何說明文字，格式：
{"exercises":[{"name":"動作名稱","name_en":"English name","line":"原文","sets":整數,"reps":整數,"weight_kg":數字}]}
規則：
- 只列出要做的動作，照原文順序；說明、休息、注意事項不要列。
- name 用台灣健身房常用的繁體中文說法，name_en 用常見的英文名稱。
- line 是原文裡寫這個動作的那一行。
- 次數或重量是範圍（10–12 下、2.5–4 kg）就填較小的數字。
- 計時的動作（例如棒式 60 秒）reps 填 null。
- 原文沒寫的組數、次數、重量填 null，不要猜。''';

/// Figures past these are a misreading, not a plan.
const _maxSets = 20;
const _maxReps = 100;
const _maxKg = 500;

/// Reads a model's answer into workout lines, or throws
/// [AiFailure.unreadable]. Tolerant of what models wrap JSON in, strict
/// about figures: one out of range is dropped, and the plan's usual
/// figure takes its place.
List<WorkoutLine> parseWorkoutDraft(String answer) {
  final start = answer.indexOf('{');
  final end = answer.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw AiException(AiFailure.unreadable, answer);
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(answer.substring(start, end + 1));
  } on FormatException {
    throw AiException(AiFailure.unreadable, answer);
  }
  if (decoded case {'exercises': final List<dynamic> exercises}) {
    return [
      for (final entry in exercises)
        if (entry case {'name': final String name} when name.trim().isNotEmpty)
          WorkoutLine(
            name: name.trim(),
            otherName: switch (entry['name_en']) {
              final String english when english.trim().isNotEmpty =>
                english.trim(),
              _ => null,
            },
            text: switch (entry['line']) {
              final String line when line.trim().isNotEmpty => line.trim(),
              _ => name.trim(),
            },
            sets: _whole(entry['sets'], _maxSets),
            reps: _whole(entry['reps'], _maxReps),
            weightKg: switch (entry['weight_kg']) {
              final num kg when kg > 0 && kg <= _maxKg => kg.toDouble(),
              _ => null,
            },
          ),
    ];
  }
  throw AiException(AiFailure.unreadable, answer);
}

int? _whole(Object? value, int max) => switch (value) {
  final num number when number >= 1 && number <= max => number.round(),
  _ => null,
};
