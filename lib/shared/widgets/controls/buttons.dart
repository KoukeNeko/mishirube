import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../haptics.dart';

/// The height of a full-size button, for controls that sit beside one.
const buttonHeight = 60.0;
const _compactButtonHeight = 48.0;

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.training,
    this.foregroundColor = AppColors.onTraining,
    this.isCompact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foregroundColor;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return _AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      background: color,
      foreground: foregroundColor,
      height: isCompact ? _compactButtonHeight : buttonHeight,
    );
  }
}

/// Orange call-to-action used by every nutrition flow.
class NutritionButton extends StatelessWidget {
  const NutritionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      color: AppColors.nutrition,
      foregroundColor: AppColors.onTraining,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isCompact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return _AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      background: AppColors.surfaceRaised,
      foreground: AppColors.textPrimary,
      height: isCompact ? _compactButtonHeight : buttonHeight,
    );
  }
}

class _AppButton extends StatelessWidget {
  const _AppButton({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FilledButton(
        onPressed: _withTap(onPressed),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: AppTextStyles.buttonLabel,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// Square icon button on a raised surface, e.g. the close button of sheets.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.color = AppColors.textPrimary,
    this.radius = AppRadius.small,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;
  final Color color;

  /// Beside a full-height button it takes that button's corners.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: _withTap(onPressed),
        // Sized to the square, not to Material's 48-point minimum with
        // its padding: in a smaller square that pushed the icon off
        // centre.
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceRaised,
          foregroundColor: color,
          padding: EdgeInsets.zero,
          minimumSize: Size.square(size),
          maximumSize: Size.square(size),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        iconSize: size / 2,
        icon: Icon(icon),
      ),
    );
  }
}

/// Inline text link such as「管理模組」or「查看這段期間的原始紀錄」.
class LinkText extends StatelessWidget {
  const LinkText({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.training,
    this.alignment = Alignment.center,
  });

  final String label;
  final VoidCallback onTap;

  /// Green for going somewhere; secondary grey for dismissive actions such
  /// as 取消 or 清除.
  final Color color;

  /// Where the text sits in its touch target; at the bottom beside a
  /// section label, so the target grows away from what the label heads.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _withTap(onTap),
      child: ConstrainedBox(
        // Text-sized, but still a full touch target.
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: alignment,
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a button callback with the shared press haptic.
VoidCallback? _withTap(VoidCallback? onPressed) => onPressed == null
    ? null
    : () {
        AppHaptics.tap();
        onPressed();
      };
