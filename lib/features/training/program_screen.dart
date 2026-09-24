import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../app/view_model.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import 'program_view_model.dart';
import 'routine_detail_screen.dart';
import 'training_screen.dart';
import 'workout_summary_screen.dart';

/// How many of the running program's workouts are listed as its record.
const _recentDays = 5;

/// One program, changed in place: how its workouts come round, what
/// they are, and, once started, what is next.
class ProgramScreen extends StatelessWidget {
  const ProgramScreen({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      create: ProgramViewModel.new,
      builder: (context, model) => switch (model.byId(programId)) {
        final program? => _ProgramPage(model: model, program: program),
        // Deleted from here, while the page leaves.
        null => const DetailPage(
          appBar: PageAppBar(title: '課表'),
          children: [],
        ),
      },
    );
  }
}

class _ProgramPage extends StatelessWidget {
  const _ProgramPage({required this.model, required this.program});

  final ProgramViewModel model;
  final Program program;

  void _edit(BuildContext context, Routine routine) {
    AppStoreScope.read(context).selectRoutine(routine);
    pushPage(context, const RoutineDetailScreen());
  }

  Future<void> _rename(BuildContext context) async {
    final name = await showTextDialog(
      context,
      title: '課表名稱',
      initial: program.name,
    );
    if (name == null || name.trim().isEmpty) return;
    model.rename(program, name.trim());
  }

  Future<void> _add(BuildContext context) async {
    final mine = AppStoreScope.read(context).myRoutines;
    final fromMine = await showAppDialog<bool>(
      context,
      AppDialog(
        title: '新增訓練',
        isChoiceList: true,
        actions: [
          DialogAction(
            label: '建立新的訓練',
            onTap: () => Navigator.of(context).pop(false),
          ),
          if (mine.isNotEmpty)
            DialogAction(
              label: '從「我的訓練」加入',
              onTap: () => Navigator.of(context).pop(true),
            ),
        ],
      ),
    );
    if (fromMine == null || !context.mounted) return;
    if (fromMine) {
      final routine = await showAppDialog<Routine>(
        context,
        AppDialog(
          title: '從「我的訓練」加入',
          isChoiceList: true,
          actions: [
            for (final routine in mine)
              DialogAction(
                label: routine.name,
                detail: routineSummary(routine),
                onTap: () => Navigator.of(context).pop(routine),
              ),
          ],
        ),
      );
      if (routine != null) model.addCopy(program, routine);
      return;
    }
    final name = await showTextDialog(
      context,
      title: '新增訓練',
      hint: '例如：推',
      confirmLabel: '建立',
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    _edit(context, model.addNew(program, name.trim()));
  }

  Future<void> _dayActions(
    BuildContext context,
    int index,
    Routine? routine,
  ) async {
    final isWeekdays = program.schedule == ProgramSchedule.weekdays;
    void close() => Navigator.of(context).pop();
    await showAppDialog<void>(
      context,
      AppDialog(
        title: routine?.name ?? '已刪除的訓練',
        actions: [
          if (routine != null)
            DialogAction(
              label: '編輯動作',
              onTap: () {
                close();
                _edit(context, routine);
              },
            ),
          if (isWeekdays)
            DialogAction(
              label: '改星期',
              onTap: () {
                close();
                _pickWeekday(context, index);
              },
            ),
          if (!isWeekdays && index > 0)
            DialogAction(
              label: '上移',
              onTap: () {
                close();
                model.move(program, index, index - 1);
              },
            ),
          if (!isWeekdays && index < program.days.length - 1)
            DialogAction(
              label: '下移',
              onTap: () {
                close();
                model.move(program, index, index + 1);
              },
            ),
          DialogAction(
            label: '從課表移除',
            tone: DialogTone.destructive,
            onTap: () {
              close();
              model.remove(program, index);
            },
          ),
          DialogAction(label: '取消', onTap: close),
        ],
      ),
    );
  }

  Future<void> _pickWeekday(BuildContext context, int index) async {
    final weekday = await showAppDialog<int>(
      context,
      AppDialog(
        title: '星期',
        isChoiceList: true,
        actions: [
          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
            DialogAction(
              label: '週${weekdayName(day)}',
              isSelected: program.days[index].weekday == day,
              onTap: () => Navigator.of(context).pop(day),
            ),
        ],
      ),
    );
    if (weekday != null) model.setWeekday(program, index, weekday);
  }

  Future<void> _end(BuildContext context) async {
    final ends = await showAppDialog<bool>(
      context,
      AppDialog(
        title: '結束「${program.name}」？',
        actions: [
          DialogAction(
            label: '結束課表',
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (ends == true) model.end(program);
  }

  Future<void> _delete(BuildContext context) async {
    final deletes = await showAppDialog<bool>(
      context,
      AppDialog(
        title: '刪除「${program.name}」？',
        message: '課表裡的訓練會移到「我的訓練」，已完成的訓練紀錄會保留。',
        actions: [
          DialogAction(
            label: '刪除這份課表',
            tone: DialogTone.destructive,
            onTap: () => Navigator.of(context).pop(true),
          ),
          DialogAction(label: '取消', onTap: () => Navigator.of(context).pop()),
        ],
      ),
    );
    if (deletes != true || !context.mounted) return;
    model.delete(program);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final routines = {
      for (final routine in AppStoreScope.of(context).routines)
        routine.id: routine,
    };
    String nameOf(String id) => routines[id]?.name ?? '已刪除的訓練';
    final progress = program.isRunning && program.days.isNotEmpty
        ? model.progressOf(program)
        : null;
    final isWeekdays = program.schedule == ProgramSchedule.weekdays;
    return DetailPage(
      appBar: PageAppBar(
        title: program.name,
        subtitle: program.isRunning ? '使用中' : null,
        actions: [
          HeaderAction(
            icon: Icons.edit_outlined,
            semanticLabel: '改課表名稱',
            onTap: () => _rename(context),
          ),
        ],
      ),
      footer: program.isRunning
          ? null
          : PrimaryButton(
              label: '啟用課表',
              icon: Icons.play_arrow_outlined,
              onPressed: program.days.isEmpty
                  ? null
                  : () => model.start(program),
            ),
      children: [
        if (progress != null)
          Gutter(
            child: AppCard(
              tone: CardTone.training,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '下一次：${nameOf(progress.next.routineId)}',
                    style: AppTextStyles.pageTitle,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(roundLabel(progress), style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: '略過這次',
                          onPressed: model.skipNext,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SecondaryButton(
                          label: '結束課表',
                          onPressed: () => _end(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Gutter(child: const SectionLabel('安排')),
        Gutter(
          child: SegmentedChoice<ProgramSchedule>(
            options: ProgramSchedule.values,
            selected: program.schedule,
            labelOf: (schedule) => schedule.label,
            onChanged: (schedule) => model.setSchedule(program, schedule),
          ),
        ),
        Gutter(child: const SectionLabel('訓練')),
        if (program.days.isNotEmpty)
          Gutter(
            child: GroupedCard(
              children: [
                for (final (index, day) in program.days.indexed)
                  NavRow(
                    title: nameOf(day.routineId),
                    titleTrailing: progress?.nextDay == index
                        ? const TagChip(label: '下一次', tone: TagTone.training)
                        : null,
                    subtitle: switch (routines[day.routineId]) {
                      final routine? => routineSummary(routine),
                      null => null,
                    },
                    trailing: switch (day.weekday) {
                      final weekday? when isWeekdays => Text(
                        '週${weekdayName(weekday)}',
                        style: AppTextStyles.caption,
                      ),
                      _ => null,
                    },
                    showChevron: false,
                    onTap: () =>
                        _dayActions(context, index, routines[day.routineId]),
                  ),
              ],
            ),
          ),
        Gutter(
          child: DashedActionCard(label: '新增訓練', onTap: () => _add(context)),
        ),
        if (progress != null && progress.records.isNotEmpty) ...[
          Gutter(child: const SectionLabel('最近紀錄')),
          Gutter(
            child: GroupedCard(
              children: [
                for (final record in progress.records.reversed.take(
                  _recentDays,
                ))
                  NavRow(
                    title:
                        '${record.at.month} 月 ${record.at.day} 日'
                        '（週${weekdayLabel(record.at)}）',
                    subtitle: record.day < program.days.length
                        ? nameOf(program.days[record.day].routineId)
                        : null,
                    trailing: record.isSkipped
                        ? const TagChip(label: '已略過')
                        : null,
                    onTap: switch (record.workoutId) {
                      final id? => () => pushPage(
                        context,
                        WorkoutSummaryScreen(workoutId: id),
                      ),
                      null => null,
                    },
                  ),
              ],
            ),
          ),
        ],
        Gutter(
          child: Center(
            child: LinkText(
              label: '刪除這份課表',
              color: AppColors.destructive,
              onTap: () => _delete(context),
            ),
          ),
        ),
      ],
    );
  }
}
