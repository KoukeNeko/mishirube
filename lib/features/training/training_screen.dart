import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'active_workout_screen.dart';
import 'program_screen.dart';
import 'program_view_model.dart';
import 'routine_detail_screen.dart';

/// Everything to train from: the running program, a workout from
/// nothing, the user's own workouts and their programs.
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      create: ProgramViewModel.new,
      builder: (context, model) => _TrainingPage(model: model),
    );
  }
}

class _TrainingPage extends StatelessWidget {
  const _TrainingPage({required this.model});

  final ProgramViewModel model;

  void _open(BuildContext context, Routine routine) {
    AppStoreScope.read(context).selectRoutine(routine);
    pushPage(context, const RoutineDetailScreen());
  }

  Future<void> _createRoutine(BuildContext context) async {
    final name = await showTextDialog(
      context,
      title: '新增訓練',
      hint: '例如：上肢 B',
      confirmLabel: '建立',
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    AppStoreScope.read(context).createRoutine(name.trim());
    pushPage(context, const RoutineDetailScreen());
  }

  Future<void> _startFree(BuildContext context) async {
    final store = AppStoreScope.read(context);
    if (store.activeWorkout == null) {
      final exercises = await pushModalPage<List<ExerciseDefinition>>(
        context,
        const ExercisePickerScreen(targetName: '自由訓練'),
      );
      if (exercises == null || exercises.isEmpty || !context.mounted) return;
      if (!store.startFreeWorkout(exercises)) {
        showToast(context, '運動進行中，先結束運動才能開始訓練', kind: ToastKind.warning);
        return;
      }
    }
    pushPage(context, const ActiveWorkoutScreen());
  }

  Future<void> _createProgram(BuildContext context) async {
    // A template, or null for one built from nothing.
    final choice = await showAppDialog<(ProgramTemplate?,)>(
      context,
      AppDialog(
        title: '建立課表',
        isChoiceList: true,
        actions: [
          for (final template in model.templates)
            DialogAction(
              label: template.name,
              detail: template.workouts
                  .map((workout) => workout.name)
                  .join('／'),
              onTap: () => Navigator.of(context).pop((template,)),
            ),
          DialogAction(
            label: '自己建立',
            onTap: () => Navigator.of(context).pop((null,)),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    final Program program;
    if (choice.$1 case final template?) {
      program = model.createFrom(template);
    } else {
      final name = await showTextDialog(
        context,
        title: '課表名稱',
        hint: '例如：上下肢分化',
        confirmLabel: '建立',
      );
      if (name == null || name.trim().isEmpty || !context.mounted) return;
      program = model.create(name.trim());
    }
    pushPage(context, ProgramScreen(programId: program.id));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final routines = {
      for (final routine in store.routines) routine.id: routine,
    };
    final progress = model.progress;
    final programs = model.programs;
    final mine = store.myRoutines;
    return DetailPage(
      appBar: const PageAppBar(title: '訓練'),
      children: [
        if (progress != null) ...[
          Gutter(child: const SectionLabel('目前課表')),
          Gutter(
            child: NavCard(
              tone: CardTone.training,
              title: progress.program.name,
              subtitle:
                  '下一次：${routines[progress.next.routineId]?.name ?? '已刪除的訓練'}',
              detail: roundLabel(progress),
              onTap: () => pushPage(
                context,
                ProgramScreen(programId: progress.program.id),
              ),
            ),
          ),
        ],
        Gutter(
          child: SecondaryButton(
            label: store.activeWorkout == null ? '自由訓練' : '回到訓練',
            icon: Icons.add,
            onPressed: () => _startFree(context),
          ),
        ),
        Gutter(child: const SectionLabel('我的訓練')),
        if (mine.isNotEmpty)
          Gutter(
            child: GroupedCard(
              children: [
                for (final routine in mine)
                  NavRow(
                    title: routine.name,
                    subtitle: routineSummary(routine),
                    detail: routine.lastCompletedLabel,
                    onTap: () => _open(context, routine),
                  ),
              ],
            ),
          ),
        Gutter(
          child: DashedActionCard(
            label: '新增訓練',
            onTap: () => _createRoutine(context),
          ),
        ),
        Gutter(child: const SectionLabel('課表')),
        if (programs.isNotEmpty)
          Gutter(
            child: GroupedCard(
              children: [
                for (final program in programs)
                  NavRow(
                    title: program.name,
                    titleTrailing: program.isRunning
                        ? const TagChip(label: '使用中', tone: TagTone.training)
                        : null,
                    subtitle: program.days.isEmpty
                        ? '沒有訓練'
                        : [
                            for (final day in program.days)
                              routines[day.routineId]?.name ?? '已刪除的訓練',
                          ].join('／'),
                    onTap: () =>
                        pushPage(context, ProgramScreen(programId: program.id)),
                  ),
              ],
            ),
          ),
        Gutter(
          child: DashedActionCard(
            label: '建立課表',
            onTap: () => _createProgram(context),
          ),
        ),
      ],
    );
  }
}

/// `5 個動作 · 16 組`.
String routineSummary(Routine routine) =>
    '${routine.exercises.length} 個動作 · ${routine.totalSets} 組';

/// `本輪 2 / 3 · 已完成 20 次`: where a rotation is, and how much of the
/// program was trained.
String roundLabel(ProgramProgress progress) => [
  if (progress.program.schedule == ProgramSchedule.rotation)
    '本輪 ${progress.nextDay + 1} / ${progress.program.days.length}',
  '已完成 ${progress.completed} 次',
].join(' · ');
