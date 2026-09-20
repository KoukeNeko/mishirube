import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';

/// Every training template, so the one trained from next is a choice
/// rather than whichever one the app happens to hold.
class RoutineListScreen extends StatelessWidget {
  const RoutineListScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final name = await showTextDialog(
      context,
      title: '新增訓練',
      hint: '例如：上肢 B',
      confirmLabel: '建立',
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    AppStoreScope.read(context).createRoutine(name.trim());
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final selected = store.routine;
    return DetailPage(
      appBar: const PageAppBar(title: '所有訓練', subtitle: '選一份作為接下來的訓練'),
      children: [
        Gutter(child: const SectionLabel('訓練模板')),
        for (final routine in store.routines)
          Gutter(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: NavRow(
                title: routine.name,
                subtitle:
                    '${routine.exercises.length} 個動作 · '
                    '${routine.lastCompletedLabel}',
                leading: Icon(
                  routine.id == selected.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: routine.id == selected.id
                      ? AppColors.training
                      : AppColors.textTertiary,
                ),
                onTap: () {
                  store.selectRoutine(routine);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        Gutter(
          child: DashedActionCard(label: '新增訓練', onTap: () => _create(context)),
        ),
        Gutter(
          child: const Text(
            '刪除一份訓練不會動到已完成的訓練紀錄。',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }
}
