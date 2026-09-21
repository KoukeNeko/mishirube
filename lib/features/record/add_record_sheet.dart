import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import '../activity/record_activity_screen.dart';
import '../journal/sleep_entry_screen.dart';
import '../journal/measurement_entry_screen.dart';
import '../journal/note_entry_screen.dart';
import '../journal/weight_entry_screen.dart';
import '../journal/wellness_entry_screen.dart';
import '../nutrition/food_search_screen.dart';
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
    required this.module,
    required this.destination,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  /// The module this record belongs to; turning the module off takes the
  /// option out of the menu.
  final AppModule module;

  /// The screen that records it. Every option has one: an entry that led
  /// nowhere would be a button that only says it is not done yet.
  final Widget Function() destination;
}

/// What the user can add, most used first. The menu shows the ones whose
/// module is on.
final recordOptions = [
  RecordOption(
    icon: Icons.fitness_center,
    color: AppColors.training,
    title: '訓練',
    module: AppModule.training,
    subtitle: '從訓練模板開始，或空白紀錄',
    destination: () => const RoutineDetailScreen(),
  ),
  RecordOption(
    icon: Icons.directions_run,
    color: AppColors.activity,
    title: '運動',
    subtitle: '跑步、健走、騎車、球類、瑜伽',
    module: AppModule.activity,
    destination: () => const RecordActivityScreen(),
  ),
  RecordOption(
    icon: Icons.restaurant,
    color: AppColors.nutrition,
    title: '飲食',
    module: AppModule.nutrition,
    subtitle: '吃的和喝的，都記在這裡',
    destination: () => const FoodSearchScreen(),
  ),
  RecordOption(
    icon: Icons.monitor_weight_outlined,
    color: AppColors.body,
    title: '體重',
    module: AppModule.weight,
    subtitle: '早晨空腹，或任何固定的時間',
    destination: () => const WeightEntryScreen(),
  ),
  RecordOption(
    icon: Icons.bedtime_outlined,
    color: AppColors.wellness,
    title: '睡眠',
    module: AppModule.sleep,
    subtitle: '手動補記或由 Apple Health 帶入',
    destination: () => const SleepEntryScreen(),
  ),
  RecordOption(
    icon: Icons.sentiment_satisfied_outlined,
    color: AppColors.textSecondary,
    title: '心情、精力、症狀',
    module: AppModule.wellness,
    subtitle: '簡短的一天狀態日誌',
    destination: () => const WellnessEntryScreen(),
  ),
  RecordOption(
    icon: Icons.straighten,
    color: AppColors.body,
    title: '圍度',
    module: AppModule.weight,
    subtitle: '腰圍、臀圍、上臂等，量到的才記',
    destination: () => const MeasurementEntryScreen(),
  ),
  RecordOption(
    icon: Icons.description_outlined,
    color: AppColors.textSecondary,
    title: '筆記',
    module: AppModule.notes,
    subtitle: '關於今天的一段話，放在當天的紀錄裡',
    destination: () => const NoteEntryScreen(),
  ),
];

/// The options whose module the user has switched on.
List<RecordOption> enabledRecordOptions(BuildContext context) {
  final modules = AppStoreScope.of(context).enabledModules;
  return [
    for (final option in recordOptions)
      if (modules.contains(option.module)) option,
  ];
}

/// Closes the current popup (sheet or menu) and opens [option]'s screen.
void openRecordOption(BuildContext context, RecordOption option) {
  final navigator = Navigator.of(context);
  navigator.pop();
  navigator.push(MaterialPageRoute<void>(builder: (_) => option.destination()));
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
              LinkText(
                label: '取消',
                color: AppColors.textSecondary,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final option in enabledRecordOptions(context)) ...[
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
