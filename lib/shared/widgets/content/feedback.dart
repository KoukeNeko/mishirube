import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'cards.dart';

/// Explanatory banner: an icon and a sentence on a tinted card.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.tone = CardTone.neutral,
    this.icon = Icons.info_outline,
  });

  final String message;
  final CardTone tone;
  final IconData icon;

  Color get _iconColor => switch (tone) {
    CardTone.warning => AppColors.warning,
    CardTone.nutrition => AppColors.nutrition,
    CardTone.training => AppColors.training,
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: tone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _iconColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered explanation shown when there is not enough data.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.small + 4),
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.pageTitle,
          ),
          if (message case final message?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 14),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Status card with a leading icon, used on the sync screen.
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = CardTone.neutral,
    this.titleColor = AppColors.textPrimary,
  });

  final IconData icon;
  final String title;
  final String message;
  final CardTone tone;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: tone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: titleColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.itemTitle.copyWith(color: titleColor),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(message, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
