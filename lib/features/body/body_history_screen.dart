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
    required this.editPage,
    this.tags = const [],
  });

  final String title;
  final String unit;

  /// The readings over a window, oldest first.
  final List<BodyPoint> Function(BodyViewModel model, Duration window) load;

  /// Where a new reading of the figure is logged.
  final Widget Function() addPage;

  /// Where the record behind a reading is corrected.
  final Widget Function(Object record) editPage;

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
                        '${bodyDate(points[index].at)} · '
                        '${_value(points[index].value)}',
                    builder: (context, selected) => Sparkline(
                      values: [for (final point in points) point.value],
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
                  for (final point in points.reversed)
                    NavRow(
                      title: _value(point.value),
                      subtitle:
                          '${bodyDate(point.at)} ${formatTimeOfDay(point.at)}',
                      showChevron: false,
                      onTap: () => _manage(model, point),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  /// Corrects or removes one reading; a removal can be undone.
  Future<void> _manage(BodyViewModel model, BodyPoint point) async {
    final choice = await showAppDialog<bool>(
      context,
      AppDialog(
        title: '${bodyDate(point.at)} ${_value(point.value)}',
        isChoiceList: true,
        actions: [
          DialogAction(
            label: '編輯',
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(
            label: '刪除這筆紀錄',
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(false),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice) {
      if (model.record(point.id) case final record?) {
        pushModalPage<void>(context, widget.editPage(record));
      }
      return;
    }
    model.delete(point.id);
    ToastScope.read(context)
        .showUndo('已刪除${widget.title}', onUndo: () => model.restore(point.id));
  }

  String _change(List<BodyPoint> points) {
    final change = points.last.value - points.first.value;
    return '${change < 0 ? '−' : '+'}${formatAmount(change.abs())} ${widget.unit}';
  }
}
