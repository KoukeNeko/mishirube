import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../backend/engines/sleep_metrics.dart';
import '../../domain/domain.dart';

/// The axis runs from 18:00 to 14:00 the next day, so a night is one
/// unbroken bar whether it began before midnight or after.
const _axisStartHour = 18;
const _axisHours = 20;

const _rowGap = 3.0;
const _axisHeight = 20.0;

/// Each night as a bar from falling asleep to waking, one row a night:
/// the ragged edges are how regular bedtimes and wake times are, which a
/// single number hides.
class SleepScheduleChart extends StatelessWidget {
  const SleepScheduleChart({super.key, required this.nights});

  /// Nights that say when they began, oldest first.
  final List<SleepEntry> nights;

  @override
  Widget build(BuildContext context) {
    final timed = [
      for (final night in nights)
        if (night.startedAt != null) night,
    ];
    final rowHeight = timed.length > 14 ? 6.0 : 12.0;
    return Semantics(
      label: '入睡與起床時間，${timed.length} 晚',
      excludeSemantics: true,
      child: CustomPaint(
        size: Size(
          double.infinity,
          timed.length * (rowHeight + _rowGap) + _axisHeight,
        ),
        painter: _SchedulePainter(
          nights: timed,
          rowHeight: rowHeight,
          labelStyle: AppTextStyles.caption,
        ),
      ),
    );
  }
}

class _SchedulePainter extends CustomPainter {
  _SchedulePainter({
    required this.nights,
    required this.rowHeight,
    required this.labelStyle,
  });

  final List<SleepEntry> nights;
  final double rowHeight;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const axisMinutes = _axisHours * 60;
    double x(DateTime time) =>
        clockMinutes(time, _axisStartHour).clamp(0, axisMinutes) /
        axisMinutes *
        size.width;
    final bar = Paint()..color = AppColors.wellness;
    final grid = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    final chartHeight = size.height - _axisHeight;
    for (var hour = 0; hour <= _axisHours; hour += 4) {
      final dx = hour / _axisHours * size.width;
      canvas.drawLine(Offset(dx, 0), Offset(dx, chartHeight), grid);
      final label = TextPainter(
        text: TextSpan(
          text: ((_axisStartHour + hour) % 24).toString().padLeft(2, '0'),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final left = (dx - label.width / 2).clamp(0.0, size.width - label.width);
      label.paint(canvas, Offset(left, chartHeight + 4));
    }
    for (final (index, night) in nights.indexed) {
      final top = index * (rowHeight + _rowGap);
      final start = x(night.startedAt!);
      final end = x(night.sleptAt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(start, top, end < start ? start : end, top + rowHeight),
          Radius.circular(rowHeight / 2),
        ),
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(_SchedulePainter old) =>
      old.nights != nights || old.rowHeight != rowHeight;
}
