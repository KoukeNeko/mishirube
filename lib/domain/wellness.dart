enum WellnessKind {
  energy('精力'),
  mood('心情'),
  symptom('症狀'),
  // Kept for a rating given without a length; a night's own quality lives
  // on [SleepEntry].
  sleep('睡眠品質');

  const WellnessKind(this.label);

  final String label;
}

/// A night's sleep: how long, and how it felt when the user says so.
class SleepEntry {
  const SleepEntry({
    required this.id,
    required this.sleptAt,
    required this.duration,
    this.score,
    this.note = '',
  });

  final String id;

  /// The morning the night is logged against.
  final DateTime sleptAt;
  final Duration duration;

  /// 1–5, or null when the user did not rate it.
  final int? score;
  final String note;
}

/// A self-rated 1–5 check-in with an optional note.
class WellnessEntry {
  const WellnessEntry({
    required this.id,
    required this.recordedAt,
    required this.kind,
    required this.score,
    this.note = '',
  });

  final String id;
  final DateTime recordedAt;
  final WellnessKind kind;
  final int score;
  final String note;
}
