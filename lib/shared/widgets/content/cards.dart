import 'package:flutter/material.dart';

import '../../../app/theme.dart';

enum CardTone {
  neutral(AppColors.surface, Colors.transparent),
  raised(AppColors.surfaceRaised, Colors.transparent),
  training(AppColors.trainingSurface, AppColors.trainingOutline),
  nutrition(AppColors.nutritionSurface, AppColors.nutritionOutline),
  warning(AppColors.warningSurface, AppColors.warningOutline);

  const CardTone(this.background, this.border);

  final Color background;
  final Color border;
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tone = CardTone.neutral,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.card,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final CardTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: borderColor ?? tone.border,
        width: borderColor == null ? 1 : 2,
      ),
    );
    return Material(
      color: tone.background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A card whose children are separated by hairline dividers (settings style).
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Dashed outline used for "add" affordances such as「加入動作」.
class DashedActionCard extends StatelessWidget {
  const DashedActionCard({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.training,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: AppColors.outline),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.small),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: color, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  static const _dashLength = 5.0;
  static const _gapLength = 4.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.small),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dashLength),
          paint,
        );
        distance += _dashLength + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
