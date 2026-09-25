import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import 'active_workout_screen.dart';
import 'describe_workout_screen.dart';
import 'routine_detail_screen.dart';

/// Where a workout starts from, besides exercises picked one by one.
enum _Source {
  routines('我的課表'),
  past('載入紀錄');

  const _Source(this.label);

  final String label;
}

/// Everything to train from: exercises picked by hand, one of the user's
/// 課表 (each a set of exercises), or exercises of an earlier workout at
/// the sets they were done at.
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  _Source _source = _Source.routines;

  /// Exercises ticked in 載入紀錄, by workout and position, in the order
  /// they were ticked.
  final _picked = <(String, int)>[];

  /// Workouts opened in 載入紀錄 to show their exercises.
  final _open = <String>{};

  void _openRoutine(Routine routine) {
    AppStoreScope.read(context).selectRoutine(routine);
    pushPage(context, const RoutineDetailScreen());
  }

  /// Removed with an undo: what was trained from it stays.
  void _delete(Routine routine) {
    final store = AppStoreScope.read(context);
    final wasShown = store.selectedRoutine?.id == routine.id;
    store.deleteRoutine(routine);
    ToastScope.read(context).showUndo(
      '已刪除「${routine.name}」',
      onUndo: () => store.undeleteRoutine(routine.id, select: wasShown),
    );
  }

  /// Named after what it trains once exercises are in it.
  void _create() {
    AppStoreScope.read(context).createRoutine();
    pushPage(context, const RoutineDetailScreen());
  }

  void _refuse() =>
      showToast(context, '運動進行中，先結束運動才能開始訓練', kind: ToastKind.warning);

  Future<void> _pickByHand() async {
    final store = AppStoreScope.read(context);
    if (store.activeWorkout == null) {
      final exercises = await pushModalPage<List<ExerciseDefinition>>(
        context,
        const ExercisePickerScreen(targetName: '自由訓練'),
      );
      if (exercises == null || exercises.isEmpty || !mounted) return;
      if (!store.startFreeWorkout(exercises)) return _refuse();
    }
    if (mounted) pushPage(context, const ActiveWorkoutScreen());
  }

  void _startFromPast(List<WorkoutSession> workouts) {
    final store = AppStoreScope.read(context);
    final byId = {for (final workout in workouts) workout.id: workout};
    final exercises = [
      for (final (id, index) in _picked) byId[id]!.exercises[index],
    ];
    if (!store.startFromPast(exercises)) return _refuse();
    setState(_picked.clear);
    pushPage(context, const ActiveWorkoutScreen());
  }

  void _toggle(String id, int index, bool picked) => setState(
    () => picked ? _picked.add((id, index)) : _picked.remove((id, index)),
  );

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final workouts = _source == _Source.past
        ? store.recentWorkouts
        : const <WorkoutSession>[];
    return DetailPage(
      appBar: const PageAppBar(title: '訓練'),
      footer: _source == _Source.past
          ? PrimaryButton(
              label: _picked.isEmpty ? '選擇動作' : '開始訓練（${_picked.length} 個動作）',
              onPressed: _picked.isEmpty || store.activeWorkout != null
                  ? null
                  : () => _startFromPast(workouts),
            )
          : null,
      children: [
        Gutter(
          child: SecondaryButton(
            label: '一句話',
            icon: Icons.notes,
            onPressed: () => pushPage(context, const DescribeWorkoutScreen()),
          ),
        ),
        Gutter(
          child: SecondaryButton(
            label: store.activeWorkout == null ? '手動新增動作' : '回到訓練',
            icon: Icons.add,
            onPressed: _pickByHand,
          ),
        ),
        Gutter(
          child: SegmentedChoice<_Source>(
            options: _Source.values,
            selected: _source,
            labelOf: (source) => source.label,
            onChanged: (source) => setState(() => _source = source),
          ),
        ),
        ...switch (_source) {
          _Source.routines => _routines(store),
          _Source.past => _past(workouts),
        },
      ],
    );
  }

  List<Widget> _routines(AppStore store) => [
    for (final routine in store.routines)
      Gutter(
        child: SwipeAction(
          key: ValueKey(routine.id),
          label: '刪除',
          semanticLabel: '刪除「${routine.name}」',
          onAction: () => _delete(routine),
          child: NavCard(
            title: routine.name,
            subtitle: routineSummary(routine),
            detail: routine.lastCompletedLabel,
            onTap: () => _openRoutine(routine),
          ),
        ),
      ),
    Gutter(
      child: DashedActionCard(label: '新增課表', onTap: _create),
    ),
  ];

  List<Widget> _past(List<WorkoutSession> workouts) => [
    if (workouts.isEmpty)
      Gutter(
        child: const EmptyStateCard(
          icon: Icons.fitness_center,
          title: '沒有訓練紀錄',
        ),
      ),
    for (final workout in workouts) Gutter(child: _pastCard(workout)),
  ];

  Widget _pastCard(WorkoutSession workout) {
    final day = workout.startedAt;
    final isOpen = _open.contains(workout.id);
    final all = [for (var i = 0; i < workout.exercises.length; i++) i];
    final allPicked = all.every((i) => _picked.contains((workout.id, i)));
    return GroupedCard(
      children: [
        NavRow(
          title:
              '${day.month} 月 ${day.day} 日（週${weekdayLabel(day)}）· '
              '${workout.routineName}',
          subtitle: {
            for (final session in workout.exercises)
              for (final muscle in session.exercise.primaryMuscles)
                muscle.region.label,
          }.join(' · '),
          trailing: Icon(
            isOpen ? Icons.expand_less : Icons.expand_more,
            color: AppColors.textSecondary,
          ),
          onTap: () => setState(
            () => isOpen ? _open.remove(workout.id) : _open.add(workout.id),
          ),
        ),
        if (isOpen) ...[
          CheckRow(
            title: '選擇全部',
            isChecked: allPicked,
            onChanged: (picked) => setState(() {
              for (final i in all) {
                _picked.remove((workout.id, i));
                if (picked) _picked.add((workout.id, i));
              }
            }),
          ),
          for (final (i, session) in workout.exercises.indexed)
            CheckRow(
              title: session.exercise.name,
              subtitle: [
                for (final (n, set) in session.sets.indexed)
                  if (set.isDone)
                    '${n + 1} 組 ${formatWeight(set.weightKg)} kg ${set.reps} 次',
              ].join('\n'),
              isChecked: _picked.contains((workout.id, i)),
              onChanged: (picked) => _toggle(workout.id, i, picked),
            ),
        ],
      ],
    );
  }
}

/// `5 個動作 · 16 組`.
String routineSummary(Routine routine) =>
    '${routine.exercises.length} 個動作 · ${routine.totalSets} 組';
