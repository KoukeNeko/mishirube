import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';

/// The rows of the chart, top to bottom, and each stage's colour. A
/// stretch asleep with no stage given is drawn on the core row.
const _rows = [
  SleepStage.awake,
  SleepStage.rem,
  SleepStage.core,
  SleepStage.deep,
];

Color sleepStageColor(SleepStage stage) => switch (stage) {
  SleepStage.awake => AppColors.nutrition,
  SleepStage.rem => AppColors.activity,
  SleepStage.core || SleepStage.asleep => AppColors.body,
  SleepStage.deep => AppColors.wellness,
  SleepStage.inBed => AppColors.textTertiary,
};

/// A night's stages across the time it covers: one row per stage, each
/// stretch a bar where it happened. The stage names on the left are the
/// legend.
class SleepStageChart extends StatelessWidget {
  const SleepStageChart({super.key, required this.stages});

  /// Stretches of one source, in time order.
  final List<SleepSample> stages;

  static const _rowHeight = 18.0;
  static const _labelWidth = 72.0;

  @override
  Widget build(BuildContext context) {
    final start = stages.first.start;
    final end = stages
        .map((stage) => stage.end)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final middle = start.add(end.difference(start) ~/ 2);
    return Semantics(
      label: '睡眠階段圖，${formatTimeOfDay(start)} 到 ${formatTimeOfDay(end)}',
      excludeSemantics: true,
      child: Column(
        children: [
          for (final row in _rows)
            SizedBox(
              height: _rowHeight + AppSpacing.xs,
              child: Row(
                children: [
                  SizedBox(
                    width: _labelWidth,
                    child: Text(row.label, style: AppTextStyles.caption),
                  ),
                  Expanded(
                    child: CustomPaint(
                      size: const Size.fromHeight(_rowHeight),
                      painter: _RowPainter(
                        stretches: [
                          for (final stage in stages)
                            if (stage.stage == row ||
                                (row == SleepStage.core &&
                                    stage.stage == SleepStage.asleep))
                              stage,
                        ],
                        start: start,
                        end: end,
                        color: sleepStageColor(row),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              const SizedBox(width: _labelWidth),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final time in [start, middle, end])
                      Text(formatTimeOfDay(time), style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RowPainter extends CustomPainter {
  _RowPainter({
    required this.stretches,
    required this.start,
    required this.end,
    required this.color,
  });

  final List<SleepSample> stretches;
  final DateTime start;
  final DateTime end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final span = end.difference(start).inSeconds;
    if (span <= 0) return;
    final paint = Paint()..color = color;
    double x(DateTime time) =>
        size.width * time.difference(start).inSeconds / span;
    for (final stretch in stretches) {
      final left = x(stretch.start);
      // Too short to see at this width is still drawn, one pixel wide.
      final width = (x(stretch.end) - left).clamp(1.0, size.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, width, size.height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RowPainter old) =>
      old.stretches != stretches || old.start != start || old.end != end;
}
