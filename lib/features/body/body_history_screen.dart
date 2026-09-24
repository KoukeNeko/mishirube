import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'body_range.dart';
import 'body_view_model.dart';

/// One body figure over time: its readings as a line that reads out
/// when touched, and every reading, newest first.
class BodyHistoryScreen extends StatefulWidget {
  const BodyHistoryScreen({
    super.key,
    required this.title,
    required this.unit,
    required this.load,
    required this.addPage,
    this.tags = const [],
  });

  final String title;
  final String unit;

  /// The readings over a window, oldest first.
  final List<(DateTime, double)> Function(BodyViewModel model, Duration window)
  load;

  /// Where a new reading of the figure is logged.
  final Widget Function() addPage;

  /// Short qualifiers, such as that a scale estimated the figure.
  final List<String> tags;

  @override
  State<BodyHistoryScreen> createState() => _BodyHistoryScreenState();
}

class _BodyHistoryScreenState extends State<BodyHistoryScreen> {
  BodyRange _range = BodyRange.quarter;

  String _value(double value) => '${formatAmount(value)} ${widget.unit}';

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: BodyViewModel.new,
    builder: (context, model) {
      final points = widget.load(model, _range.window);
      return DetailPage(
        appBar: PageAppBar(
          title: widget.title,
          actions: [
            HeaderAction(
              icon: Icons.add,
              semanticLabel: '記錄${widget.title}',
              onTap: () => pushModalPage<void>(context, widget.addPage()),
            ),
          ],
        ),
        children: [
          Gutter(
            child: SegmentedChoice<BodyRange>(
              options: BodyRange.values,
              selected: _range,
              labelOf: (range) => range.label,
              selectedColor: AppColors.body,
              onChanged: (range) => setState(() => _range = range),
            ),
          ),
          if (points.isEmpty)
            Gutter(
              child: const EmptyStateCard(
                icon: Icons.show_chart,
                title: '沒有紀錄',
              ),
            )
          else ...[
            Gutter(
              child: AppCard(
                child: Semantics(
                  label: '${widget.title}走勢，${points.length} 筆',
                  child: ChartScrubber(
                    count: points.length,
                    indexAt: ChartScrubber.points(points.length),
                    idle:
                        '${_range.label} · ${points.length} 筆'
                        '${points.length > 1 ? ' · ${_change(points)}' : ''}',
                    readoutOf: (index) =>
                        '${bodyDate(points[index].$1)} · '
                        '${_value(points[index].$2)}',
                    builder: (context, selected) => Sparkline(
                      values: [for (final (_, value) in points) value],
                      color: AppColors.body,
                      height: 96,
                      selected: selected,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.tags.isNotEmpty)
              Gutter(child: TagWrap(labels: widget.tags)),
            Gutter(child: const SectionLabel('紀錄')),
            Gutter(
              child: GroupedCard(
                children: [
                  for (final (at, value) in points.reversed)
                    KeyValueRow(
                      label: '${bodyDate(at)} ${formatTimeOfDay(at)}',
                      value: _value(value),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  String _change(List<(DateTime, double)> points) {
    final change = points.last.$2 - points.first.$2;
    return '${change < 0 ? '−' : '+'}${formatAmount(change.abs())} ${widget.unit}';
  }
}
