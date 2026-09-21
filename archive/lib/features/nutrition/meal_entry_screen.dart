import 'package:flutter/material.dart';

import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import 'meal_confirm_screen.dart';

/// The ways in that are not search.
///
/// Search and what was eaten before live one level up, because someone
/// opening the log usually already knows what they had. These are the
/// methods worth a trip: they either take a photo or need the camera,
/// and none of them is the common case.
class MealEntryScreen extends StatelessWidget {
  const MealEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPage(
      appBar: const PageAppBar(title: '其他記錄方式', subtitle: '搜尋以外的入口'),
      children: [
        Gutter(
          child: _MethodCard(
            icon: Icons.photo_camera_outlined,
            title: '拍照',
            subtitle: '辨識料理與成分，確認後才存入',
            isPrimary: true,
            onTap: () => pushPage(context, const MealConfirmScreen()),
          ),
        ),
        Gutter(
          child: _MethodCard(
            icon: Icons.mic_none,
            title: '說出來',
            subtitle: '「牛肉麵一碗，湯喝一半」',
            onTap: () => pushPage(context, const MealConfirmScreen()),
          ),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: isPrimary ? CardTone.nutrition : CardTone.neutral,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isPrimary ? AppColors.nutrition : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.small + 4),
            ),
            child: Icon(
              icon,
              color: isPrimary ? AppColors.textPrimary : AppColors.nutrition,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
