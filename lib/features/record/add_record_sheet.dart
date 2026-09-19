import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import '../nutrition/meal_entry_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../training/routine_detail_screen.dart';

Future<void> showAddRecordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => const AddRecordSheet(),
  );
}

/// One kind of record the user can add from the quick-log entry points.
class RecordOption {
  const RecordOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.destination,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget Function()? destination;
}

final recordOptions = [
  RecordOption(
    icon: Icons.fitness_center,
    color: AppColors.training,
    title: '訓練',
    subtitle: '從訓練模板開始，或空白紀錄',
    destination: () => const RoutineDetailScreen(),
  ),
  RecordOption(
    icon: Icons.restaurant,
    color: AppColors.nutrition,
    title: '一餐',
    subtitle: '拍照、說出來或搜尋',
    destination: () => const MealEntryScreen(),
  ),
  const RecordOption(
    icon: Icons.straighten,
    color: AppColors.body,
    title: '體重與量測',
    subtitle: '體重、腰圍、體組成',
  ),
  const RecordOption(
    icon: Icons.bedtime_outlined,
    color: AppColors.wellness,
    title: '睡眠',
    subtitle: '手動補記或由 Apple Health 帶入',
  ),
  const RecordOption(
    icon: Icons.sentiment_satisfied_outlined,
    color: AppColors.textSecondary,
    title: '心情、精力、症狀',
    subtitle: '簡短的一天狀態日誌',
  ),
  const RecordOption(
    icon: Icons.description_outlined,
    color: AppColors.textSecondary,
    title: '筆記',
    subtitle: '和任何一天或一筆紀錄關聯',
  ),
];

/// Closes the current popup (sheet or menu) and opens [option]'s screen.
void openRecordOption(BuildContext context, RecordOption option) {
  final destination = option.destination;
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  navigator.pop();
  if (destination == null) {
    messenger.showSnackBar(
      SnackBar(content: Text('「${option.title}」的輸入畫面尚未設計')),
    );
    return;
  }
  navigator.push(MaterialPageRoute<void>(builder: (_) => destination()));
}

class AddRecordSheet extends StatelessWidget {
  const AddRecordSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _DragHandle(),
          Row(
            children: [
              const Text('要記錄什麼？', style: AppTextStyles.pageTitle),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '取消',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final option in recordOptions) ...[
            _RecordOptionTile(
              option: option,
              onTap: () => openRecordOption(context, option),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              const Text('這裡只列出你已啟用的模組。', style: AppTextStyles.caption),
              LinkText(
                label: '管理模組',
                onTap: () {
                  final navigator = Navigator.of(context)..pop();
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(isEditing: true),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _RecordOptionTile extends StatelessWidget {
  const _RecordOptionTile({required this.option, required this.onTap});

  final RecordOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      tone: CardTone.raised,
      child: NavRow(
        title: option.title,
        subtitle: option.subtitle,
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: option.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Icon(option.icon, color: option.color),
        ),
      ),
    );
  }
}
