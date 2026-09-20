enum WellnessKind {
  energy('精力'),
  mood('心情'),
  sleep('睡眠');

  const WellnessKind(this.label);

  final String label;
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
