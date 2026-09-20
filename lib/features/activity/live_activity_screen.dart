import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import 'activity_detail_screen.dart';

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

  void _discard(BuildContext context) {
    AppStoreScope.read(context).discardActivity();
    Navigator.of(context).pop();
    showToast(context, '已放棄這次運動，沒有存成紀錄');
  }

  @override
  Widget build(BuildContext context) {
    final live = AppStoreScope.of(context).activeActivity;
    if (live == null) {
      return const DetailPage(
        appBar: PageAppBar(title: '運動'),
        children: [Gutter(child: InfoBanner(message: '這次運動已經結束。'))],
      );
    }
    return DetailPage(
      appBar: PageAppBar(
        title: live.type.label,
        subtitle: live.isPaused ? '已暫停' : '進行中',
      ),
      footer: PrimaryButton(label: '結束', onPressed: () => _finish(context)),
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
            label: live.isPaused ? '繼續' : '暫停',
            icon: live.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            onPressed: AppStoreScope.read(context).togglePause,
          ),
        ),
        Gutter(
          child: const Text(
            '暫停的時間不算進這次運動。距離與強度可以在結束後補上。',
            style: AppTextStyles.caption,
          ),
        ),
        Gutter(
          child: Center(
            child: LinkText(
              label: '放棄這次運動',
              color: AppColors.warning,
              onTap: () => _discard(context),
            ),
          ),
        ),
      ],
    );
  }
}
