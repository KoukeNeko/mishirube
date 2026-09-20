import 'package:flutter/material.dart';

import '../app/theme.dart';

enum RecordCategory {
  training('訓練', AppColors.training, Icons.fitness_center),
  nutrition('飲食', AppColors.nutrition, Icons.restaurant),
  body('身體', AppColors.body, Icons.monitor_weight_outlined),
  wellness('狀態', AppColors.wellness, Icons.bedtime_outlined);

  const RecordCategory(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class TimelineEntry {
  const TimelineEntry({
    required this.timeLabel,
    required this.category,
    required this.title,
    required this.detail,
    this.tags = const [],
  });

  final String timeLabel;
  final RecordCategory category;
  final String title;
  final String detail;
  final List<String> tags;
}

class TimelineDay {
  const TimelineDay({required this.label, required this.entries, this.warning});

  final String label;
  final List<TimelineEntry> entries;
  final String? warning;
}

class Insight {
  const Insight({required this.statement, required this.evidence});

  final String statement;
  final List<String> evidence;
}
