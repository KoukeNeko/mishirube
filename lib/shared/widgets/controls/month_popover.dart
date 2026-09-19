import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../motion.dart';
import '../chrome/chrome_surface.dart';

const _popoverWidth = 260.0;
const _anchorGap = 8.0;
const _itemExtent = 40.0;
const _visibleRows = 5;
const _popoverDuration = Duration(milliseconds: 220);

/// Year and month wheels in a glass popover that hangs from [anchor] (the
/// button that opened it), like a UIKit date picker in a popover. Every
/// settled change is reported through [onChanged]; tapping outside closes
/// it.
Future<void> showMonthPopover(
  BuildContext context, {
  required Rect anchor,
  required DateTime selected,
  required DateTime earliest,
  required DateTime latest,
  required ValueChanged<DateTime> onChanged,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉月份選擇',
    barrierColor: Colors.transparent,
    transitionDuration: chromeDuration(context, _popoverDuration),
    pageBuilder: (context, _, _) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      return Stack(
        children: [
          Positioned(
            top: anchor.bottom + _anchorGap,
            right: screenWidth - anchor.right,
            width: _popoverWidth,
            child: _MonthWheels(
              selected: selected,
              earliest: earliest,
              latest: latest,
              onChanged: onChanged,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final size = MediaQuery.sizeOf(context);
      // Grows out from under the button; Reduce Motion only fades.
      return FadeTransition(
        opacity: curved,
        child: prefersReducedMotion(context)
            ? child
            : ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.0).animate(curved),
                alignment: Alignment(
                  anchor.right / size.width * 2 - 1,
                  (anchor.bottom + _anchorGap) / size.height * 2 - 1,
                ),
                child: child,
              ),
      );
    },
  );
}

class _MonthWheels extends StatefulWidget {
  const _MonthWheels({
    required this.selected,
    required this.earliest,
    required this.latest,
    required this.onChanged,
  });

  final DateTime selected;
  final DateTime earliest;
  final DateTime latest;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_MonthWheels> createState() => _MonthWheelsState();
}

class _MonthWheelsState extends State<_MonthWheels> {
  late int _year = widget.selected.year;
  late int _month = widget.selected.month;
  late DateTime _reported = DateTime(_year, _month);
  late final _years = [
    for (var y = widget.earliest.year; y <= widget.latest.year; y++) y,
  ];
  late final _yearController = FixedExtentScrollController(
    initialItem: _years.indexOf(_year),
  );
  late final _monthController = FixedExtentScrollController(
    initialItem: _month - 1,
  );

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  bool _isAvailable(int year, int month) {
    final first = DateTime(year, month);
    return !first.isBefore(
          DateTime(widget.earliest.year, widget.earliest.month),
        ) &&
        !first.isAfter(widget.latest);
  }

  /// Like a date picker with a maximum date: months out of range can be
  /// scrolled past but the wheel settles back on the nearest valid one.
  void _settle() {
    var month = _month;
    while (!_isAvailable(_year, month)) {
      month += DateTime(_year, month).isAfter(widget.latest) ? -1 : 1;
    }
    if (month != _month) {
      _monthController.animateToItem(
        month - 1,
        duration: chromeDuration(context, _popoverDuration),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final value = DateTime(_year, _month);
    if (value != _reported) {
      _reported = value;
      widget.onChanged(value);
    }
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    // The wheel is still switching to idle here; starting the snap-back now
    // would be overridden by that switch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _settle();
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyles.itemTitle.copyWith(fontSize: 20);
    return ChromeSurface(
      radius: AppRadius.card,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Brightness.dark,
          textTheme: CupertinoTextThemeData(pickerTextStyle: textStyle),
        ),
        child: SizedBox(
          height: _itemExtent * _visibleRows,
          child: NotificationListener<ScrollEndNotification>(
            onNotification: _onScrollEnd,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: '年份',
                    child: CupertinoPicker(
                      scrollController: _yearController,
                      itemExtent: _itemExtent,
                      onSelectedItemChanged: (index) =>
                          setState(() => _year = _years[index]),
                      children: [
                        for (final year in _years)
                          Center(child: Text('$year 年')),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    label: '月份',
                    child: CupertinoPicker(
                      scrollController: _monthController,
                      itemExtent: _itemExtent,
                      onSelectedItemChanged: (index) =>
                          setState(() => _month = index + 1),
                      children: [
                        for (var month = 1; month <= 12; month++)
                          Center(
                            child: Text(
                              '$month 月',
                              style: _isAvailable(_year, month)
                                  ? null
                                  : textStyle.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
