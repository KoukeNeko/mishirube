class BodyWeight {
  const BodyWeight({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    this.note = '',
  });

  final String id;
  final DateTime measuredAt;
  final double weightKg;
  final String note;
}
