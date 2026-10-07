import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/view_model.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_proposal_screen.dart';
import 'trends_view_model.dart';
import 'volume_records_screen.dart';
import '../../l10n/l10n.dart';

/// Explains one insight: conclusion, evidence, data quality and next step.
class InsightDetailScreen extends StatelessWidget {
  const InsightDetailScreen({super.key, this.exerciseId});

  /// Which exercise's volume to explain; the most trained one by default.
  final String? exerciseId;

  @override
  Widget build(BuildContext context) => ViewModelBuilder(
    create: TrendsViewModel.new,
    builder: (context, trends) => _page(context, trends),
  );

  Widget _page(BuildContext context, TrendsViewModel trends) {
    final store = AppStoreScope.of(context);
    final report = trends.volumeReport(exerciseId: exerciseId);
    if (report == null) {
      return DetailPage(
        appBar: PageAppBar(
          title: context.l10n.volumeTitle,
          subtitle: context.l10n.todaySectionInsights,
        ),
        children: [
          Gutter(child: InfoBanner(message: context.l10n.notEnoughWorkouts)),
        ],
      );
    }
    final weeks = report.weeklySets.length;
    final estimate = report.history.estimatedOneRepMaxKg;
    final first = report.weeklySets.first.$2;
    final last = report.weeklySets.last.$2;
    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.volumeOf(exercise: report.exercise.name),
        subtitle: context.l10n.insightWeeks(weeks: weeks),
      ),
      children: [
        Gutter(
          child: _Section(
            label: context.l10n.todaySectionInsights,
            child: Text(
              report.insight?.statement ??
                  context.l10n.volumeSteady(
                    sets: last,
                    estimate: estimate == null
                        ? context.l10n.notYetEstimable
                        : '${estimate.round()} kg',
                  ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: context.l10n.basisSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.weeklySetsFrom(count: report.sessionCount),
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.md),
                MiniBarChart(bars: report.weeklySets),
              ],
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: context.l10n.dataQualitySection,
            child: TagWrap(
              labels: [
                context.l10n.workoutsAllLogged(count: report.sessionCount),
                context.l10n.weightRepsManual,
                if (estimate != null) context.l10n.epleyEstimate,
              ],
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: context.l10n.timeRangeSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_date(report.from)} → ${_date(store.now())}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  context.l10n.fullWeeks(count: weeks),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
        Gutter(
          child: _Section(
            label: context.l10n.actionsSection,
            showDivider: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  last < first
                      ? context.l10n.volumeDropped(sets: first)
                      : context.l10n.volumeStable,
                  style: AppTextStyles.body,
                ),
                if (store.selectedRoutine case final routine?) ...[
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: context.l10n.adjustRoutineSets(
                      routine: routine.name,
                    ),
                    isCompact: true,
                    onPressed: () =>
                        pushPage(context, const AiProposalScreen()),
                  ),
                ],
              ],
            ),
          ),
        ),
        Gutter(
          child: Text(
            context.l10n.notMedicalAdvice,
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(
          child: LinkText(
            label: context.l10n.viewRawEntries,
            onTap: () => pushPage(
              context,
              VolumeRecordsScreen(exercise: report.exercise, from: report.from),
            ),
          ),
        ),
      ],
    );
  }

  static String _date(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.child,
    this.showDivider = true,
  });

  final String label;
  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.overline),
        const SizedBox(height: AppSpacing.sm),
        child,
        if (showDivider) const Divider(height: AppSpacing.xxl),
      ],
    );
  }
}
