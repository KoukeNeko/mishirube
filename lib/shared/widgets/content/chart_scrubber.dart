import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';

/// Makes a chart readable point by point: touching it, sliding along it
/// or a pointer over it picks the item under the finger, and the line
/// above the chart reads that item out. A tap anywhere else puts the
/// reading away and the line goes back to [idle].
///
/// The chart itself is drawn by [builder], told which item is picked so
/// it can mark it; which item a position falls on is [indexAt]'s to say,
/// since a bar chart and a line chart place their items differently.
class ChartScrubber extends StatefulWidget {
  const ChartScrubber({
    super.key,
    required this.count,
    required this.indexAt,
    required this.readoutOf,
    required this.idle,
    required this.builder,
  });

  /// How many items the chart has.
  final int count;

  /// The item at [position] in a chart of [size].
  final int Function(Offset position, Size size) indexAt;

  /// What the line says about item [index].
  final String Function(int index) readoutOf;

  /// What the line says with nothing picked.
  final String idle;

  final Widget Function(BuildContext context, int? selected) builder;

  /// For items in equal slots across the width, such as bars.
  static int Function(Offset, Size) slots(int count) =>
      (position, size) =>
          (position.dx / size.width * count).floor().clamp(0, count - 1);

  /// For items on points spread from edge to edge, such as a line.
  static int Function(Offset, Size) points(int count) =>
      (position, size) => count < 2
      ? 0
      : (position.dx / size.width * (count - 1)).round().clamp(0, count - 1);

  /// For items in equal rows down the height.
  static int Function(Offset, Size) rows(int count, double rowExtent) =>
      (position, size) => (position.dy / rowExtent).floor().clamp(0, count - 1);

  @override
  State<ChartScrubber> createState() => _ChartScrubberState();
}

const _readoutHeight = 22.0;

class _ChartScrubberState extends State<ChartScrubber> {
  int? _selected;

  void _pick(Offset position, Size size, {bool isTouch = true}) {
    if (widget.count == 0 || size.isEmpty) return;
    final index = widget.indexAt(position, size);
    if (index == _selected) return;
    // A tick each time the finger crosses onto another item.
    if (isTouch) AppHaptics.selection(context);
    setState(() => _selected = index);
  }

  void _clear() {
    if (_selected != null) setState(() => _selected = null);
  }

  @override
  void didUpdateWidget(ChartScrubber old) {
    super.didUpdateWidget(old);
    if (_selected case final selected? when selected >= widget.count) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return TapRegion(
      onTapOutside: (_) => _clear(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One line, the same height whichever it says, so reading the
          // chart does not move it.
          SizedBox(
            height: _readoutHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selected == null ? widget.idle : widget.readoutOf(selected),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (selected == null
                            ? AppTextStyles.caption
                            : AppTextStyles.itemTitle)
                        .copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              Size sizeOf() =>
                  (context.findRenderObject() as RenderBox?)?.size ??
                  constraints.biggest;
              return MouseRegion(
                onHover: (event) =>
                    _pick(event.localPosition, sizeOf(), isTouch: false),
                onExit: (_) => _clear(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _pick(details.localPosition, sizeOf()),
                  onHorizontalDragStart: (details) =>
                      _pick(details.localPosition, sizeOf()),
                  onHorizontalDragUpdate: (details) =>
                      _pick(details.localPosition, sizeOf()),
                  child: widget.builder(context, selected),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
