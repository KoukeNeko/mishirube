import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../app/theme.dart';
import '../../motion.dart';

/// How round a segment's corners are: the group's outer ones, the ones
/// between neighbours, and the gap that keeps them apart.
const segmentOuterRadius = AppRadius.card;
const segmentInnerRadius = 4.0;
const segmentGap = 2.0;

/// The corners of the segment at [row], [column] of a group of [rows] rows
/// with [columns] segments in its row: round where it meets the edge of the
/// group, tight where it meets another segment. A lone segment is a card.
BorderRadius segmentRadius({
  required int row,
  required int rows,
  required int column,
  required int columns,
}) {
  Radius corner({required bool isOuter}) =>
      Radius.circular(isOuter ? segmentOuterRadius : segmentInnerRadius);
  final isTop = row == 0;
  final isBottom = row == rows - 1;
  final isLeft = column == 0;
  final isRight = column == columns - 1;
  return BorderRadius.only(
    topLeft: corner(isOuter: isTop && isLeft),
    topRight: corner(isOuter: isTop && isRight),
    bottomLeft: corner(isOuter: isBottom && isLeft),
    bottomRight: corner(isOuter: isBottom && isRight),
  );
}

/// One part of a [SegmentedGroup]: its content, which pads itself, and
/// what it looks like and does as a whole.
class Segment {
  const Segment({
    required this.child,
    this.onTap,
    this.surface = AppColors.surface,
    this.background,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// The surface it sits on: one step up for the part that matters most.
  final Color surface;

  /// Drawn on the surface, under [child] and inside the corners.
  final Widget? background;

  /// What a screen reader says in place of [child]'s own text.
  final String? semanticLabel;
}

/// A group of figures as one block cut into parts: rows of one or more
/// segments, [segmentGap] apart, the group's corners round and the ones
/// between its parts tight. A segment that does something gives under
/// the finger: the tight corners open to the round ones, on a spring.
class SegmentedGroup extends StatelessWidget {
  const SegmentedGroup({super.key, required this.rows});

  final List<List<Segment>> rows;

  @override
  Widget build(BuildContext context) {
    Widget cell(int row, int column, int columns) => _SegmentCell(
      segment: rows[row][column],
      radius: segmentRadius(
        row: row,
        rows: rows.length,
        column: column,
        columns: columns,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: segmentGap,
      children: [
        for (final (row, segments) in rows.indexed)
          // Side by side they are as tall as the tallest; alone, nothing
          // needs measuring, and what a segment holds may not be able to
          // be (a layout builder).
          if (segments.length == 1)
            cell(row, 0, 1)
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: segmentGap,
                children: [
                  for (var column = 0; column < segments.length; column++)
                    Expanded(child: cell(row, column, segments.length)),
                ],
              ),
            ),
      ],
    );
  }
}

class _SegmentCell extends StatefulWidget {
  const _SegmentCell({required this.segment, required this.radius});

  final Segment segment;
  final BorderRadius radius;

  @override
  State<_SegmentCell> createState() => _SegmentCellState();
}

class _SegmentCellState extends State<_SegmentCell>
    with SingleTickerProviderStateMixin {
  /// 0 at rest, 1 when held: how far the tight corners have opened.
  late final _held = AnimationController.unbounded(vsync: this);

  void _setHeld(bool isHeld) {
    if (!mounted) return;
    final target = isHeld ? 1.0 : 0.0;
    if (prefersReducedMotion(context)) {
      _held.value = target;
      return;
    }
    _held.animateWith(
      SpringSimulation(
        M3eSprings.spatialFast,
        _held.value,
        target,
        _held.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _held.dispose();
    super.dispose();
  }

  /// The corner at rest as [radius], opened by [held] if it was tight; the
  /// spring may overshoot, which a radius cannot.
  Radius _opened(Radius radius, double held) => radius.x == segmentInnerRadius
      ? Radius.circular(
          (segmentInnerRadius +
                  (segmentOuterRadius - segmentInnerRadius) * held)
              .clamp(0, double.infinity),
        )
      : radius;

  @override
  Widget build(BuildContext context) {
    final segment = widget.segment;
    final rest = widget.radius;
    Widget content = Stack(
      children: [
        if (segment.background case final background?)
          Positioned.fill(child: background),
        segment.child,
      ],
    );
    final cell = AnimatedBuilder(
      animation: _held,
      child: content,
      builder: (context, child) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: _opened(rest.topLeft, _held.value),
            topRight: _opened(rest.topRight, _held.value),
            bottomLeft: _opened(rest.bottomLeft, _held.value),
            bottomRight: _opened(rest.bottomRight, _held.value),
          ),
        );
        return Material(
          color: segment.surface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: segment.onTap,
            // The ink's own highlight, which a scroll that wins the touch
            // cancels: a page dragged by its segments does not flex them.
            onHighlightChanged: _setHeld,
            child: child,
          ),
        );
      },
    );
    // One node that carries the label and the tap, not a nameless button
    // with the label beside it.
    if (segment.semanticLabel case final label?) {
      return Semantics(
        container: true,
        label: label,
        button: segment.onTap != null,
        onTap: segment.onTap,
        excludeSemantics: true,
        child: cell,
      );
    }
    return cell;
  }
}
