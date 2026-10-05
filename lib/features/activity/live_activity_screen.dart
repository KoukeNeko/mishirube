import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../shell/finish_session_dialog.dart';
import 'activity_detail_screen.dart';
import '../../l10n/l10n.dart';

/// Exercise being timed as it happens: the clock, and the three things
/// that can be done to it. What was done gets filled in afterwards, on
/// the record it becomes.
class LiveActivityScreen extends StatelessWidget {
  const LiveActivityScreen({super.key});

  void _finish(BuildContext context) {
    final finished = AppStoreScope.read(context).finishActivity();
    if (finished == null) return;
    replaceWithPage(context, ActivityDetailScreen(activityId: finished.id));
  }

  /// Asks first, as the dock's stop button does.
  Future<void> _discard(BuildContext context, LiveActivity live) async {
    final store = AppStoreScope.read(context);
    final discarded = context.l10n.sessionDiscarded(
      session: live.type.labelIn(context.l10n),
    );
    final choice = await askHowSessionEnds(context, ActiveActivity(live));
    if (!context.mounted) return;
    switch (choice) {
      case null || FinishChoice.keepGoing:
        return;
      case FinishChoice.finish:
        _finish(context);
      case FinishChoice.discard:
        store.discardActivity();
        Navigator.of(context).pop();
        showToast(context, discarded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = AppStoreScope.of(context).activeActivity;
    if (live == null) {
      return DetailPage(
        appBar: PageAppBar(title: context.l10n.moduleActivity),
        children: [
          Gutter(child: InfoBanner(message: context.l10n.activityEnded)),
        ],
      );
    }
    return DetailPage(
      appBar: PageAppBar(
        title: live.type.labelIn(context.l10n),
        subtitle: live.isPaused
            ? context.l10n.sessionPausedStatus
            : context.l10n.sessionInProgress,
      ),
      footer: PrimaryButton(
        label: context.l10n.commonEnd,
        onPressed: () => _finish(context),
      ),
      children: [
        Gutter(
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xxl,
              horizontal: AppSpacing.md,
            ),
            child: Column(
              children: [
                Icon(live.type.icon, color: AppColors.activity, size: 32),
                const SizedBox(height: AppSpacing.sm),
                ElapsedClock(
                  session: ActiveActivity(live),
                  builder: (_, elapsed) => Text(
                    elapsed,
                    style: AppTextStyles.bigNumber.copyWith(
                      color: live.isPaused
                          ? AppColors.warning
                          : AppColors.activity,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Gutter(
          child: SecondaryButton(
            label: live.isPaused
                ? context.l10n.commonResume
                : context.l10n.commonPause,
            icon: live.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            onPressed: AppStoreScope.read(context).togglePause,
          ),
        ),
        Gutter(
          child: Center(
            child: LinkText(
              label: context.l10n.sessionDiscardActivity,
              color: AppColors.warning,
              onTap: () => _discard(context, live),
            ),
          ),
        ),
      ],
    );
  }
}
