import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'body_range.dart';
import 'body_view_model.dart';
import '../../l10n/l10n.dart';

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

  String _value(double value) => withUnit(formatAmount(value), widget.unit);

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
              semanticLabel: context.l10n.logItem(item: widget.title),
              onTap: () => pushModalPage<void>(context, widget.addPage()),
            ),
          ],
        ),
        children: [
          Gutter(
            child: SegmentedChoice<BodyRange>(
              options: BodyRange.values,
              selected: _range,
              labelOf: (range) => range.labelIn(context.l10n),
              selectedColor: AppColors.body,
              onChanged: (range) => setState(() => _range = range),
            ),
          ),
          if (points.isEmpty)
            Gutter(
              child: EmptyStateCard(
                icon: Icons.show_chart,
                title: context.l10n.noEntriesShort,
              ),
            )
          else ...[
            Gutter(
              child: AppCard(
                child: Semantics(
                  label: context.l10n.trendReadingsLabel(
                    item: widget.title,
                    count: points.length,
                  ),
                  child: ChartScrubber(
                    count: points.length,
                    indexAt: ChartScrubber.points(points.length),
                    idle:
                        '${_range.labelIn(context.l10n)} · '
                        '${context.l10n.readingsCount(count: points.length)}'
                        '${points.length > 1 ? ' · ${_change(points)}' : ''}',
                    readoutOf: (index) =>
                        '${context.dates.monthDay(points[index].at)} · '
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
            Gutter(child: SectionLabel(context.l10n.recordTitle)),
            Gutter(
              child: GroupedCard(
                children: [
                  for (final point in points.reversed)
                    NavRow(
                      title: _value(point.value),
                      subtitle:
                          '${context.dates.monthDay(point.at)} ${formatTimeOfDay(point.at)}',
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
        title: '${context.dates.monthDay(point.at)} ${_value(point.value)}',
        isChoiceList: true,
        actions: [
          DialogAction(
            label: context.l10n.commonEdit,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(
            label: context.l10n.recordDelete,
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(false),
          ),
          DialogAction(
            label: context.l10n.commonCancel,
            onTap: () => Navigator.of(context).pop(),
          ),
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
    ToastScope.read(context).showUndo(
      context.l10n.deletedItem(item: widget.title),
      onUndo: () => model.restore(point.id),
    );
  }

  String _change(List<BodyPoint> points) {
    final change = points.last.value - points.first.value;
    return withUnit(
      '${change < 0 ? '−' : '+'}${formatAmount(change.abs())}',
      widget.unit,
    );
  }
}
