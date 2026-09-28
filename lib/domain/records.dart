import 'package:flutter/material.dart';

import '../app/theme.dart';

enum RecordCategory {
  training(AppColors.training, Icons.fitness_center),
  activity(AppColors.activity, Icons.directions_run),
  nutrition(AppColors.nutrition, Icons.restaurant),
  body(AppColors.body, Icons.monitor_weight_outlined),
  wellness(AppColors.wellness, Icons.bedtime_outlined);

  const RecordCategory(this.color, this.icon);
  final Color color;
  final IconData icon;
}

class TimelineEntry {
  const TimelineEntry({
    required this.timeLabel,
    required this.at,
    required this.category,
    required this.title,
    required this.detail,
    this.recordId,
    this.tags = const [],
  });

  final String timeLabel;

  /// When it happened, so a row can open that day.
  final DateTime at;
  final RecordCategory category;
  final String title;
  final String detail;

  /// The record behind the row, where opening one makes sense.
  final String? recordId;
  final List<String> tags;
}

class TimelineDay {
  const TimelineDay({
    required this.date,
    required this.label,
    required this.entries,
    this.warning,
  });

  /// Midnight of the day.
  final DateTime date;
  final String label;
  final List<TimelineEntry> entries;
  final String? warning;
}

class Insight {
  const Insight({required this.statement, required this.evidence});

  final String statement;
  final List<String> evidence;
}

/// A month of the log: the days that have records, and one short
/// summary per category for the calendar.
class MonthRecords {
  const MonthRecords({required this.days, required this.summaries});

  static const empty = MonthRecords(days: [], summaries: {});

  /// Days with records, newest first.
  final List<TimelineDay> days;

  /// Per day of the month, one short summary per recorded category, in
  /// [RecordCategory] order.
  final Map<int, Map<RecordCategory, String>> summaries;
}
