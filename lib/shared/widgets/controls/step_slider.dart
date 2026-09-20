import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';

/// Thickness of the track and the size of the grip that rides it.
const _trackHeight = 10.0;
const _gripWidth = 14.0;
const _gripHeight = 34.0;

/// The row is this tall so the whole strip is comfortably draggable, not
/// just the track.
const _rowHeight = 48.0;

/// A slider in fixed steps, drawn the way the rest of the app is: a thick
/// track, a capsule grip and the two ends written out, instead of the
/// stock slider's dotted rail.
///
/// Every step change ticks, so a value can be set without watching the
/// number, and the whole strip is draggable and tappable.
class StepSlider extends StatefulWidget {
  const StepSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    required this.labelOf,
    this.color = AppColors.training,
    this.semanticLabel,
  });

  final double value;
  final double min;
  final double max;

  /// Distance between two positions the grip can hold.
  final double step;
  final ValueChanged<double> onChanged;

  /// How a value reads, for the end labels and for screen readers.
  final String Function(double value) labelOf;
  final Color color;
  final String? semanticLabel;

  @override
  State<StepSlider> createState() => _StepSliderState();
}

class _StepSliderState extends State<StepSlider> {
  bool _isDragging = false;

  double get _span => widget.max - widget.min;

  double get _progress =>
      _span == 0 ? 0 : ((widget.value - widget.min) / _span).clamp(0.0, 1.0);

  /// The value at [fraction] of the track, snapped to the step.
  double _valueAt(double fraction) {
    final raw = widget.min + fraction.clamp(0.0, 1.0) * _span;
    final steps = ((raw - widget.min) / widget.step).round();
    return (widget.min + steps * widget.step).clamp(widget.min, widget.max);
  }

  void _moveTo(double localX, double width) {
    // The grip's own width is taken off both ends, so the value tracks the
    // grip's centre rather than the finger's distance from the edge.
    final travel = width - _gripWidth;
    final value = _valueAt(
      travel <= 0 ? 0 : (localX - _gripWidth / 2) / travel,
    );
    if (value == widget.value) return;
    AppHaptics.selection(context);
    widget.onChanged(value);
  }

  void _nudge(int steps) {
    final value = (widget.value + steps * widget.step).clamp(
      widget.min,
      widget.max,
    );
    if (value != widget.value) widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.labelOf(widget.value),
      increasedValue: widget.labelOf(
        (widget.value + widget.step).clamp(widget.min, widget.max),
      ),
      decreasedValue: widget.labelOf(
        (widget.value - widget.step).clamp(widget.min, widget.max),
      ),
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      excludeSemantics: true,
      child: Column(
        // Only as tall as the track and its end labels: a slider is a
        // control, not a filler.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _moveTo(details.localPosition.dx, width),
                onHorizontalDragStart: (details) {
                  setState(() => _isDragging = true);
                  _moveTo(details.localPosition.dx, width);
                },
                onHorizontalDragUpdate: (details) =>
                    _moveTo(details.localPosition.dx, width),
                onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                onHorizontalDragCancel: () =>
                    setState(() => _isDragging = false),
                child: SizedBox(
                  height: _rowHeight,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      _Track(progress: _progress, color: widget.color),
                      Positioned(
                        left: (width - _gripWidth) * _progress,
                        child: _Grip(isDragging: _isDragging),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.labelOf(widget.min), style: AppTextStyles.caption),
              Text(widget.labelOf(widget.max), style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _trackHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        // The rest of the track stays visible past the grip: the filled
        // part is laid over a full-width rail, not cut out of it.
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.surfaceRaised),
            if (progress > 0)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: ColoredBox(color: color),
              ),
          ],
        ),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip({required this.isDragging});

  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isDragging ? 1.12 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Container(
        width: _gripWidth,
        height: _gripHeight,
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          // Lifts the grip off the track it sits on, like the floating
          // chrome elsewhere.
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
