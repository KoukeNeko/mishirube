import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../backend/application/goal_service.dart';
import '../../backend/engines/streak_engine.dart';
import '../../shared/widgets/widgets.dart';
import 'goal_view_model.dart';
import '../../l10n/l10n.dart';

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
  late final _goal = GoalViewModel(AppStoreScope.read(context).backend);

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  late int _days = widget.overview.hasGoal
      ? widget.overview.thisWeek.targetDays
      : widget.overview.suggestedDays;

  /// Changing a goal starts next week, so it never rewrites how this
  /// week was going. A first goal starts now: there is nothing yet for
  /// it to rewrite.
  late bool _applyThisWeek = !widget.overview.hasGoal;

  void _save() {
    _goal.setGoal(_days, applyThisWeek: _applyThisWeek);
    Navigator.of(context).pop();
    showToast(
      context,
      _applyThisWeek
          ? context.l10n.goalFromThisWeek(count: _days)
          : context.l10n.goalFromNextWeek(count: _days),
      kind: ToastKind.success,
    );
  }

  /// Asks how long to pause for; backing out of the dialog leaves the
  /// goal running.
  Future<void> _pause() async {
    final choice = await showAppDialog<(Duration?,)>(
      context,
      AppDialog(
        title: context.l10n.pauseWeeklyGoal,
        message: context.l10n.pauseWeeklyGoalMessage,
        actions: [
          DialogAction(
            label: context.l10n.pauseThisWeek,
            tone: DialogTone.primary,
            onTap: () => Navigator.of(context).pop((const Duration(days: 7),)),
          ),
          DialogAction(
            label: context.l10n.pauseUntilResumed,
            onTap: () => Navigator.of(context).pop((null,)),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final (duration,) = choice;
    _goal.pause(until: duration == null ? null : _goal.now().add(duration));
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _goal, builder: (context, _) => _page());

  Widget _page() {
    final overview = _goal.overview;
    return DetailPage(
      appBar: PageAppBar(
        title: overview.hasGoal
            ? context.l10n.weeklyGoal
            : context.l10n.setWeeklyGoal,
        subtitle: context.l10n.activeDaysPerWeekQuestion,
      ),
      footer: PrimaryButton(label: context.l10n.commonSave, onPressed: _save),
      children: [
        Gutter(
          child: ChipWrap(
            options: [
              for (var days = minWeeklyGoal; days <= maxWeeklyGoal; days++)
                days,
            ],
            labelOf: (days) => context.l10n.daysCount(count: days),
            isSelected: (days) => days == _days,
            onTap: (days) => setState(() => _days = days),
          ),
        ),
        if (overview.weeks.any((week) => week.activeDays > 0))
          Gutter(
            child: Text(
              context.l10n.suggestedDays(count: overview.suggestedDays),
              style: AppTextStyles.caption,
            ),
          ),
        if (overview.hasGoal) ...[
          Gutter(child: SectionLabel(context.l10n.goalStartSection)),
          Gutter(
            child: GroupedCard(
              children: [
                RadioRow(
                  title: context.l10n.fromNextWeek,
                  subtitle: context.l10n.fromNextWeekDetail,
                  isSelected: !_applyThisWeek,
                  onTap: () => setState(() => _applyThisWeek = false),
                ),
                RadioRow(
                  title: context.l10n.applyThisWeek,
                  subtitle: context.l10n.applyThisWeekDetail,
                  isSelected: _applyThisWeek,
                  onTap: () => setState(() => _applyThisWeek = true),
                ),
              ],
            ),
          ),
        ],
        if (overview.hasGoal) ...[
          Gutter(child: SectionLabel(context.l10n.pauseOrTurnOff)),
          Gutter(
            child: GroupedCard(
              children: [
                if (_goal.isEnabled)
                  SwitchRow(
                    title: context.l10n.pauseWeeklyGoal,
                    value: overview.isPaused,
                    onChanged: (pause) => pause ? _pause() : _goal.resume(),
                  ),
                SwitchRow(
                  title: context.l10n.weeklyGoal,
                  subtitle: context.l10n.weeklyGoalOffDetail,
                  value: _goal.isEnabled,
                  onChanged: _goal.setEnabled,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
