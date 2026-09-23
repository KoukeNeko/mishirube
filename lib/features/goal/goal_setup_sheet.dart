import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/application/goal_service.dart';
import '../../backend/engines/streak_engine.dart';
import '../../shared/widgets/widgets.dart';

/// Setting the weekly goal, pausing it, or turning it off. Nothing here
/// is decided for the user: the app suggests from what they have
/// actually been doing and leaves the number to them.
class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({super.key, required this.overview});

  final GoalOverview overview;

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  late int _days = widget.overview.hasGoal
      ? widget.overview.thisWeek.targetDays
      : widget.overview.suggestedDays;

  /// Changing a goal starts next week, so it never rewrites how this
  /// week was going. A first goal starts now: there is nothing yet for
  /// it to rewrite.
  late bool _applyThisWeek = !widget.overview.hasGoal;

  void _save() {
    AppStoreScope.read(context)
        .setWeeklyGoal(_days, applyThisWeek: _applyThisWeek);
    Navigator.of(context).pop();
    showToast(
      context,
      _applyThisWeek ? '本週起每週 $_days 天' : '下週起每週 $_days 天',
      kind: ToastKind.success,
    );
  }

  Future<void> _pause() async {
    final store = AppStoreScope.read(context);
    final choice = await showAppDialog<Duration?>(
      context,
      AppDialog(
        title: '暫停每週目標',
        message: '暫停期間的週不會累積，也不會中斷連續達標。',
        actions: [
          DialogAction(
            label: '暫停本週',
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop(const Duration(days: 7)),
          ),
          DialogAction(
            label: '直到手動恢復',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
    if (!mounted) return;
    store.pauseGoal(until: choice == null ? null : store.now().add(choice));
    Navigator.of(context).pop();
    showToast(context, '已暫停每週目標');
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final overview = store.goalOverview;
    return DetailPage(
      appBar: PageAppBar(
        title: overview.hasGoal ? '每週目標' : '設定每週目標',
        subtitle: '一週想要有幾個運動日',
      ),
      footer: PrimaryButton(label: '儲存', onPressed: _save),
      children: [
        Gutter(
          child: ChipWrap(
            options: [
              for (var days = minWeeklyGoal; days <= maxWeeklyGoal; days++)
                days,
            ],
            labelOf: (days) => '$days 天',
            isSelected: (days) => days == _days,
            onTap: (days) => setState(() => _days = days),
          ),
        ),
        if (overview.weeks.any((week) => week.activeDays > 0))
          Gutter(
            child: Text(
              '過去四週平均：每週 ${overview.suggestedDays} 天',
              style: AppTextStyles.caption,
            ),
          ),
        if (overview.hasGoal) ...[
          Gutter(child: const SectionLabel('從什麼時候開始')),
          Gutter(
            child: GroupedCard(
              children: [
                RadioRow(
                  title: '下週起',
                  subtitle: '本週仍用原本的目標計算',
                  isSelected: !_applyThisWeek,
                  onTap: () => setState(() => _applyThisWeek = false),
                ),
                RadioRow(
                  title: '本週就套用',
                  subtitle: '重新計算本週',
                  isSelected: _applyThisWeek,
                  onTap: () => setState(() => _applyThisWeek = true),
                ),
              ],
            ),
          ),
        ],
        Gutter(child: const SectionLabel('暫停或關閉')),
        Gutter(
          child: GroupedCard(
            children: [
              if (overview.isPaused)
                NavRow(
                  title: '恢復每週目標',
                  subtitle: '已暫停',
                  onTap: () {
                    store.resumeGoal();
                    Navigator.of(context).pop();
                    showToast(context, '已恢復每週目標');
                  },
                )
              else
                NavRow(title: '暫停每週目標', onTap: _pause),
              NavRow(
                title: '關閉每週目標',
                subtitle: '不再顯示目標與連續達標，紀錄不受影響',
                onTap: () {
                  store.setGoalEnabled(false);
                  Navigator.of(context).pop();
                  showToast(context, '已關閉每週目標');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
