import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../record/add_record_sheet.dart';
import 'chrome_metrics.dart';

const _menuDuration = Duration(milliseconds: 280);
const _quickOptionCount = 4;
const _staggerStep = 0.12;
const _itemSpacing = 10.0;
const _itemHeight = 52.0;
const _scrimOpacity = 0.6;

const quickLogMenuKey = ValueKey('quick-log-menu');

/// Staggered action list that grows out of the dock's「+」. The first few
/// record types are one tap away; the rest stay in the full sheet.
Future<void> showQuickLogMenu(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉快速記錄',
    barrierColor: Colors.black.withValues(alpha: _scrimOpacity),
    transitionDuration: chromeDuration(context, _menuDuration),
    pageBuilder: (_, animation, _) => _QuickLogMenu(animation: animation),
  );
}

class _QuickLogMenu extends StatelessWidget {
  const _QuickLogMenu({required this.animation});

  final Animation<double> animation;

  void _openMore(BuildContext context) {
    final navigator = Navigator.of(context)..pop();
    showAddRecordSheet(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    final quickOptions = recordOptions.take(_quickOptionCount).toList();
    final itemCount = quickOptions.length + 1;
    final metrics = DockMetrics.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: metrics.bottomOffset(context, isMinimized: false),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          key: quickLogMenuKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < quickOptions.length; i++)
              _Staggered(
                animation: animation,
                // Items nearest the button appear first.
                order: itemCount - 1 - i,
                child: _MenuItem(
                  icon: quickOptions[i].icon,
                  color: quickOptions[i].color,
                  label: quickOptions[i].title,
                  onTap: () => openRecordOption(context, quickOptions[i]),
                ),
              ),
            _Staggered(
              animation: animation,
              order: 0,
              child: _MenuItem(
                icon: Icons.more_horiz,
                color: AppColors.textSecondary,
                label: '更多紀錄類型',
                onTap: () => _openMore(context),
              ),
            ),
            const SizedBox(height: _itemSpacing),
            _CloseButton(animation: animation, size: metrics.height),
          ],
        ),
      ),
    );
  }
}

class _Staggered extends StatelessWidget {
  const _Staggered({
    required this.animation,
    required this.order,
    required this.child,
  });

  final Animation<double> animation;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = math.min(order * _staggerStep, 0.6);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1, curve: ChromeMetrics.morphCurve),
      reverseCurve: Interval(start, 1, curve: ChromeMetrics.fadeCurve),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: _itemSpacing),
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceRaised,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: _itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(label, style: AppTextStyles.itemTitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sits exactly where「+」was and turns into ×.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.animation, required this.size});

  final Animation<double> animation;

  /// Matches the expanded dock's「+」so × covers it exactly.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: FloatingActionButton(
        heroTag: null,
        tooltip: '關閉',
        elevation: 0,
        backgroundColor: AppColors.training,
        foregroundColor: AppColors.onTraining,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).pop(),
        child: RotationTransition(
          turns: Tween(begin: 0.0, end: 0.125).animate(animation),
          child: const Icon(Icons.add, size: 32),
        ),
      ),
    );
  }
}
