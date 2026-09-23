import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/haptics.dart';

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

int _rowOf(SleepStage stage) =>
    _rows.indexOf(stage == SleepStage.asleep ? SleepStage.core : stage);

/// Height of one stage's row: tall enough that a few minutes of a stage
/// still reads as a block, as in Apple Health and Pillow.
const _rowHeight = 52.0;

/// The top of a row, where its stage name sits above the blocks.
const _labelBand = 16.0;

/// Space under a row's blocks, before the next row.
const _blockInset = 8.0;
const _blockRadius = 6.0;

/// The hour labels under the chart.
const _axisHeight = 24.0;

/// Hour labels need this much room each, or every other one is dropped.
const _minLabelSpacing = 44.0;

/// A night's stages across the time it covers: a hypnogram, one row per
/// stage, each stretch a block where it happened and a line where the
/// night moved from one stage to the next. The stage names sit in their
/// rows.
///
/// Touching and sliding along it, or a pointer over it, reads out the
/// stretch at that moment: its stage, when it began and ended, and how
/// long it lasted.
class SleepStageChart extends StatefulWidget {
  const SleepStageChart({super.key, required this.stages});

  /// Stretches of one source, in time order.
  final List<SleepSample> stages;

  @override
  State<SleepStageChart> createState() => _SleepStageChartState();
}

class _SleepStageChartState extends State<SleepStageChart> {
  /// The moment being read, or null when nothing is.
  DateTime? _at;

  DateTime get _start => widget.stages.first.start;

  DateTime get _end => widget.stages
      .map((stage) => stage.end)
      .reduce((a, b) => a.isAfter(b) ? a : b);

  SleepSample? _stretchAt(DateTime at) {
    for (final stage in widget.stages.reversed) {
      if (!at.isBefore(stage.start) && at.isBefore(stage.end)) return stage;
    }
    return null;
  }

  void _readAt(double x, double width, {bool isTouch = true}) {
    final span = _end.difference(_start);
    final at = _start.add(span * (x / width).clamp(0.0, 1.0));
    final before = _at == null ? null : _stretchAt(_at!);
    final now = _stretchAt(at);
    // A tick each time the finger crosses into another stretch.
    if (isTouch && now != before) AppHaptics.selection(context);
    setState(() => _at = at);
  }

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final end = _end;
    final at = _at;
    final reading = at == null ? null : _stretchAt(at);
    return Semantics(
      label: '睡眠階段圖，${formatTimeOfDay(start)} 到 ${formatTimeOfDay(end)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 22,
            child: at == null ? null : _Readout(at: at, stretch: reading),
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return MouseRegion(
                onHover: (event) =>
                    _readAt(event.localPosition.dx, width, isTouch: false),
                onExit: (_) => setState(() => _at = null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _readAt(details.localPosition.dx, width),
                  onHorizontalDragStart: (details) =>
                      _readAt(details.localPosition.dx, width),
                  onHorizontalDragUpdate: (details) =>
                      _readAt(details.localPosition.dx, width),
                  child: CustomPaint(
                    size: Size(width, _rows.length * _rowHeight + _axisHeight),
                    painter: _HypnogramPainter(
                      stages: widget.stages,
                      start: start,
                      end: end,
                      at: at,
                      reading: reading,
                      labelStyle: AppTextStyles.caption,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// What the chart says about the moment under the finger.
class _Readout extends StatelessWidget {
  const _Readout({required this.at, required this.stretch});

  final DateTime at;
  final SleepSample? stretch;

  @override
  Widget build(BuildContext context) {
    final stretch = this.stretch;
    if (stretch == null) {
      return Text(formatTimeOfDay(at), style: AppTextStyles.caption);
    }
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: sleepStageColor(stretch.stage),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            '${stretch.stage.label} · '
            '${formatTimeOfDay(stretch.start)}–${formatTimeOfDay(stretch.end)}'
            ' · ${formatHoursMinutes(stretch.end.difference(stretch.start))}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.itemTitle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _HypnogramPainter extends CustomPainter {
  _HypnogramPainter({
    required this.stages,
    required this.start,
    required this.end,
    required this.at,
    required this.reading,
    required this.labelStyle,
  });

  final List<SleepSample> stages;
  final DateTime start;
  final DateTime end;
  final DateTime? at;
  final SleepSample? reading;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final span = end.difference(start).inSeconds;
    if (span <= 0) return;
    final chartHeight = _rows.length * _rowHeight;
    double x(DateTime time) =>
        size.width * time.difference(start).inSeconds / span;
    double rowTop(int row) => row * _rowHeight;
    double blockTop(int row) => rowTop(row) + _labelBand;
    const blockHeight = _rowHeight - _labelBand - _blockInset;
    double rowCentre(int row) => blockTop(row) + blockHeight / 2;

    // Row dividers.
    final divider = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    for (var row = 0; row <= _rows.length; row++) {
      final y = rowTop(row);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), divider);
    }

    _paintHours(canvas, size, chartHeight, x);

    // Stage names, in their rows.
    for (final (row, stage) in _rows.indexed) {
      _text(stage.label, labelStyle)
        ..paint(canvas, Offset(AppSpacing.xxs, rowTop(row) + 2))
        ..dispose();
    }

    // Where the night moved from one stage to the next.
    final sorted = [...stages]..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final next = sorted[i];
      final from = _rowOf(previous.stage);
      final to = _rowOf(next.stage);
      if (from < 0 || to < 0 || from == to) continue;
      if (next.start.difference(previous.end).inMinutes.abs() > 1) continue;
      final lineX = x(next.start);
      final top = rowCentre(from < to ? from : to);
      final bottom = rowCentre(from < to ? to : from);
      final (topColor, bottomColor) = from < to
          ? (sleepStageColor(previous.stage), sleepStageColor(next.stage))
          : (sleepStageColor(next.stage), sleepStageColor(previous.stage));
      canvas.drawLine(
        Offset(lineX, top),
        Offset(lineX, bottom),
        Paint()
          ..strokeWidth = 1.5
          ..shader = ui.Gradient.linear(
            Offset(lineX, top),
            Offset(lineX, bottom),
            [
              topColor.withValues(alpha: 0.6),
              bottomColor.withValues(alpha: 0.6),
            ],
          ),
      );
    }

    // The stretches themselves.
    for (final stage in sorted) {
      final row = _rowOf(stage.stage);
      if (row < 0) continue;
      final left = x(stage.start);
      // Too short to see at this width is still drawn, two pixels wide.
      final width = (x(stage.end) - left).clamp(2.0, size.width);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, blockTop(row), width, blockHeight),
        const Radius.circular(_blockRadius),
      );
      final isRead = identical(stage, reading);
      final color = sleepStageColor(stage.stage);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = reading == null || isRead
              ? color
              : color.withValues(alpha: 0.45),
      );
      if (isRead) {
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.textPrimary,
        );
      }
    }

    // The moment being read.
    final at = this.at;
    if (at != null) {
      final cursorX = x(at);
      canvas.drawLine(
        Offset(cursorX, 0),
        Offset(cursorX, chartHeight),
        Paint()
          ..color = AppColors.textPrimary
          ..strokeWidth = 1,
      );
    }
  }

  /// A dashed line at each hour, labelled under the chart; every other
  /// label goes when the hours are too close to fit them all.
  void _paintHours(
    Canvas canvas,
    Size size,
    double chartHeight,
    double Function(DateTime) x,
  ) {
    final hours = <DateTime>[];
    var hour = DateTime(start.year, start.month, start.day, start.hour + 1);
    while (!hour.isAfter(end)) {
      hours.add(hour);
      hour = hour.add(const Duration(hours: 1));
    }
    if (hours.isEmpty) return;
    final hourWidth = size.width * 3600 / end.difference(start).inSeconds;
    final step = hourWidth >= _minLabelSpacing
        ? 1
        : (_minLabelSpacing / hourWidth).ceil();
    final grid = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1;
    for (final (index, time) in hours.indexed) {
      final lineX = x(time);
      for (var y = 0.0; y < chartHeight; y += 6) {
        canvas.drawLine(Offset(lineX, y), Offset(lineX, y + 3), grid);
      }
      if (index % step != 0) continue;
      final label = _text('${time.hour}:00', labelStyle);
      final left = (lineX - label.width / 2).clamp(
        0.0,
        size.width - label.width,
      );
      label
        ..paint(canvas, Offset(left, chartHeight + 6))
        ..dispose();
    }
  }

  static TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_HypnogramPainter old) =>
      old.stages != stages ||
      old.start != start ||
      old.end != end ||
      old.at != at ||
      old.labelStyle != labelStyle;
}
