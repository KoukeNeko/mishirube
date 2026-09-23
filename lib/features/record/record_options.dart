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
import '../training/routine_detail_screen.dart';

/// One kind of record the user can add from the quick-log entry points.
class RecordOption {
  const RecordOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.module,
    required Widget Function() this.destination,
  }) : onSelect = null,
       isBesidePrevious = false;

  /// An option that is done in one tap and opens nothing, such as logging
  /// a glass of water.
  const RecordOption.action({
    required this.icon,
    required this.color,
    required this.title,
    required this.module,
    required void Function(BuildContext context) this.onSelect,
    this.isBesidePrevious = false,
  }) : destination = null;

  final IconData icon;
  final Color color;
  final String title;

  /// The module this record belongs to; turning the module off takes the
  /// option out of the menu.
  final AppModule module;

  /// The screen that records it, or [onSelect] for an option done in one
  /// tap. Every option has exactly one of the two: an entry that led
  /// nowhere would be a button that only says it is not done yet.
  final Widget Function()? destination;
  final void Function(BuildContext context)? onSelect;

  /// Shown on the same row as the option before it, as a shortcut that
  /// belongs to it — water beside food.
  final bool isBesidePrevious;
}

/// What the user can add, most used first. The menu shows the ones whose
/// module is on.
final recordOptions = [
  RecordOption(
    icon: Icons.fitness_center,
    color: AppColors.training,
    title: '訓練',
    module: AppModule.training,
    destination: () => const RoutineDetailScreen(),
  ),
  RecordOption(
    icon: Icons.directions_run,
    color: AppColors.activity,
    title: '運動',
    module: AppModule.activity,
    destination: () => const RecordActivityScreen(),
  ),
  RecordOption(
    icon: Icons.restaurant,
    color: AppColors.nutrition,
    title: '飲食',
    module: AppModule.nutrition,
    destination: () => const FoodSearchScreen(),
  ),
  // The most repeated record there is, so it is one tap from anywhere:
  // the same drink record the food page's water button writes, with an
  // undo in case the tap was a slip.
  RecordOption.action(
    icon: Icons.water_drop_outlined,
    color: AppColors.nutrition,
    title: '水',
    module: AppModule.nutrition,
    isBesidePrevious: true,
    onSelect: (context) {
      final store = AppStoreScope.read(context);
      final logged = store.logWater();
      ToastScope.read(context).showUndo(
        '已記錄 ${logged.millilitres} mL 水',
        onUndo: () => store.deleteMeals([logged]),
      );
    },
  ),
  RecordOption(
    icon: Icons.monitor_weight_outlined,
    color: AppColors.body,
    title: '體重',
    module: AppModule.weight,
    destination: () => const WeightEntryScreen(),
  ),
  RecordOption(
    icon: Icons.bedtime_outlined,
    color: AppColors.wellness,
    title: '睡眠',
    module: AppModule.sleep,
    destination: () => const SleepEntryScreen(),
  ),
  RecordOption(
    icon: Icons.sentiment_satisfied_outlined,
    color: AppColors.textSecondary,
    title: '心情、精力、症狀',
    module: AppModule.wellness,
    destination: () => const WellnessEntryScreen(),
  ),
  RecordOption(
    icon: Icons.straighten,
    color: AppColors.body,
    title: '圍度',
    module: AppModule.weight,
    destination: () => const MeasurementEntryScreen(),
  ),
  RecordOption(
    icon: Icons.description_outlined,
    color: AppColors.textSecondary,
    title: '筆記',
    module: AppModule.notes,
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

/// Closes the quick-log menu and opens [option]'s screen with [open], or
/// does what it does.
void openRecordOption(
  BuildContext context,
  RecordOption option,
  void Function(Widget page) open,
) {
  final menu = ModalRoute.of(context);
  final navigator = Navigator.of(context)..pop();
  if (option.destination case final destination?) {
    open(destination());
    return;
  }
  // Wait for the menu to finish folding away, so what the action shows —
  // its undo toast — does not land on top of the menu on its way out.
  final Future<Object?> closed = switch (menu) {
    final TransitionRoute<Object?> route => route.completed,
    _ => Future.value(),
  };
  closed.then((_) {
    if (navigator.mounted) option.onSelect!(navigator.context);
  });
}
