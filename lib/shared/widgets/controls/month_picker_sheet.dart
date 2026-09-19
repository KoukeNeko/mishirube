import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../page/collapsing_header.dart';
import 'chips.dart';
import 'pill.dart';

const _monthsPerRow = 3;

/// Lets the user jump the log to another month. Resolves to the first day
/// of the chosen month, or null when dismissed.
Future<DateTime?> showMonthPickerSheet(
  BuildContext context, {
  required DateTime selected,
  required DateTime earliest,
  required DateTime latest,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) =>
        _MonthPicker(selected: selected, earliest: earliest, latest: latest),
  );
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({
    required this.selected,
    required this.earliest,
    required this.latest,
  });

  final DateTime selected;
  final DateTime earliest;
  final DateTime latest;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.selected.year;

  bool _isAvailable(int month) {
    final first = DateTime(_year, month);
    return !first.isBefore(
          DateTime(widget.earliest.year, widget.earliest.month),
        ) &&
        !first.isAfter(widget.latest);
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _year > widget.earliest.year;
    final canGoForward = _year < widget.latest.year;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        AppSpacing.screenGutter + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _YearStep(
                icon: Icons.chevron_left,
                semanticLabel: '上一年',
                onTap: canGoBack ? () => setState(() => _year--) : null,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    '$_year 年',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.pageTitle,
                  ),
                ),
              ),
              _YearStep(
                icon: Icons.chevron_right,
                semanticLabel: '下一年',
                onTap: canGoForward ? () => setState(() => _year++) : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var row = 0; row < 12 ~/ _monthsPerRow; row++) ...[
            if (row > 0) const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (var column = 0; column < _monthsPerRow; column++) ...[
                  if (column > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(child: _monthCell(row * _monthsPerRow + column + 1)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _monthCell(int month) {
    final label = '$month 月';
    if (!_isAvailable(month)) {
      return Semantics(
        enabled: false,
        child: Pill(
          onTap: null,
          color: Colors.transparent,
          foregroundColor: AppColors.textTertiary,
          child: Text(label),
        ),
      );
    }
    return SelectChip(
      label: label,
      isSelected:
          _year == widget.selected.year && month == widget.selected.month,
      onTap: () => Navigator.of(context).pop(DateTime(_year, month)),
    );
  }
}

class _YearStep extends StatelessWidget {
  const _YearStep({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: HeaderAction(
        icon: icon,
        semanticLabel: semanticLabel,
        onTap: onTap,
      ),
    );
  }
}
