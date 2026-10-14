import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../motion.dart';
import 'stats.dart';

/// The room a segment's content keeps on every side.
const segmentPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.md,
  vertical: AppSpacing.sm,
);

/// A figure with its unit beside it at a size a unit can be read at; a
/// value that carries its own words (`7 小時 45 分`) sets them as units too.
class MetricValue extends StatelessWidget {
  const MetricValue({
    super.key,
    required this.value,
    this.unit,
    this.size = 28,
  });

  final String value;
  final String? unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.bigNumber.copyWith(fontSize: size);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: unit == null
          ? ValueWithUnit(value: value, unit: null, style: style)
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: style),
                  TextSpan(
                    text: ' $unit',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A figure of a segmented group, a part of a row: a mark and the name,
/// the value under them, and a line of what it is measured against.
/// Without a value the mark goes quiet and the value says [placeholder].
class SegmentStat extends StatelessWidget {
  const SegmentStat({
    super.key,
    required this.label,
    required this.color,
    required this.placeholder,
    this.mark,
    this.value,
    this.unit,
    this.caption,
    this.progress,
    this.valueSize = 28,
  });

  final String label;

  /// The area's colour, which the mark and the bar are drawn in.
  final Color color;

  /// The mark in front of the name, given the colour to draw it in; the
  /// name stands alone without one.
  final Widget Function(Color tint)? mark;
  final String placeholder;
  final String? value;
  final String? unit;
  final String? caption;

  /// 0–1: a thin bar under the value for a figure with a target; none
  /// without one, and none without a value.
  final double? progress;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: segmentPadding,
        child: Column(
          // From the top, so the names of two segments side by side line up
          // whatever each has under it.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              spacing: AppSpacing.xs,
              children: [
                if (mark case final mark?)
                  mark(value == null ? AppColors.textTertiary : color),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (value == null)
              Text(
                placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 14),
              )
            else
              MetricValue(value: value, unit: unit, size: valueSize),
            if (caption case final caption? when value != null)
              Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            if (progress case final progress? when value != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ThickProgress(
                progress: progress,
                color: color,
                height: 4,
                gap: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A part of a segmented group the width of a row: [title] with a line
/// under it, then [trailing] (a small chart) and the [value] at the end.
/// [leading] stands before the title.
class SegmentRow extends StatelessWidget {
  const SegmentRow({
    super.key,
    required this.title,
    this.caption,
    this.value,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? caption;
  final String? value;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: segmentPadding,
        child: Center(
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              ?leading,
              // The end sits across from the title; with no room for both,
              // at a large text size, it goes under it instead.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body,
                        ),
                        if (caption case final caption?)
                          Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                      ],
                    ),
                    if (trailing != null || value != null)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: AppSpacing.sm,
                          children: [
                            ?trailing,
                            if (value case final value?)
                              Text(value, style: AppTextStyles.itemTitle),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one figure of a group that matters most: its name small, the value
/// large, and as a bar how far it is towards its target.
class SegmentHero extends StatelessWidget {
  const SegmentHero({
    super.key,
    required this.label,
    required this.color,
    required this.value,
    this.unit,
    this.progress,
    this.chart,
  });

  final String label;
  final Color color;
  final String value;
  final String? unit;

  /// 0–1; null for a figure with no target, which has no bar.
  final double? progress;

  /// Under the value: how the figure came about.
  final Widget? chart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: segmentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          MetricValue(value: value, unit: unit, size: 44),
          if (chart case final chart?) ...[
            const SizedBox(height: AppSpacing.sm),
            chart,
          ],
          if (progress case final progress?) ...[
            const SizedBox(height: AppSpacing.sm),
            ThickProgress(progress: progress, color: color),
          ],
        ],
      ),
    );
  }
}

/// A bar of [height], filled in [color] as far as [progress], a [gap]
/// apart from its track, which has a dot at its end where the bar would
/// have reached: Material 3 Expressive's determinate linear indicator.
/// It runs to its new length rather than jumping, and not at all with
/// reduced motion; the track is only the bar's room, never a value.
class ThickProgress extends StatelessWidget {
  const ThickProgress({
    super.key,
    required this.progress,
    required this.color,
    this.height = 8,
    this.gap = 4,
    this.track = AppColors.outline,
  });

  final double progress;
  final Color color;
  final double height;
  final double gap;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0)),
      duration: chromeDuration(context, const Duration(milliseconds: 330)),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _ThickProgressPainter(
          progress: shown,
          color: color,
          track: track,
          gap: gap,
        ),
      ),
    );
  }
}

class _ThickProgressPainter extends CustomPainter {
  const _ThickProgressPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.gap,
  });

  final double progress;
  final Color color;
  final Color track;
  final double gap;

  /// The dot at the end of the track.
  static const _stopRadius = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height;
    final radius = Radius.circular(height / 2);
    final at = size.width * progress;
    RRect part(double from, double to) =>
        RRect.fromLTRBR(from, 0, to, height, radius);
    final activeEnd = progress >= 1 ? size.width : at - gap / 2;
    final trackStart = at + gap / 2;
    if (trackStart < size.width) {
      canvas.drawRRect(part(trackStart, size.width), Paint()..color = track);
      canvas.drawCircle(
        Offset(size.width - height / 2, height / 2),
        _stopRadius,
        Paint()..color = color,
      );
    }
    if (activeEnd > 0) {
      canvas.drawRRect(
        part(0, activeEnd.clamp(height, size.width)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ThickProgressPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.gap != gap;
}
