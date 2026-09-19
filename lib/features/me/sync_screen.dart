import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../shared/widgets/widgets.dart';

enum _ConflictChoice {
  keepThisDevice('保留這台'),
  keepWatch('保留手錶'),
  keepBoth('兩筆都留');

  const _ConflictChoice(this.label);

  final String label;
}

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  void _resolve(BuildContext context, _ConflictChoice choice) {
    AppStoreScope.read(context).resolveSyncConflict();
    showToast(context, '已選擇「${choice.label}」', kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    final hasConflict = AppStoreScope.of(context).hasSyncConflict;
    return DetailPage(
      appBar: const PageAppBar(title: '同步', subtitle: '上次成功 今天 09:12'),
      children: [
        const StatusCard(
          icon: Icons.cloud_off_outlined,
          title: '目前離線',
          message: '12 筆紀錄已排隊，全部都已存在這台裝置。恢復連線後會自動送出。',
        ),
        const StatusCard(
          icon: Icons.sync,
          tone: CardTone.training,
          titleColor: AppColors.training,
          title: '正在同步 8 / 12',
          message: '重複送出不會產生重複紀錄。',
        ),
        if (hasConflict) ...[
          const StatusCard(
            icon: Icons.error_outline,
            tone: CardTone.warning,
            titleColor: AppColors.warning,
            title: '1 筆需要你決定',
            message: '同一筆訓練在兩台裝置上被改過。',
          ),
          const SectionLabel('9 月 16 日 · 下肢 A'),
          const GroupedCard(
            children: [
              _ConflictVersion(
                device: '這台裝置',
                time: '21:04',
                value: '槓鈴深蹲 第 4 組 · 95 kg × 5',
              ),
              _ConflictVersion(
                device: 'Apple Watch',
                time: '21:05',
                value: '槓鈴深蹲 第 4 組 · 95 kg × 6',
              ),
            ],
          ),
          Row(
            children: [
              for (final choice in _ConflictChoice.values) ...[
                if (choice != _ConflictChoice.values.first)
                  const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: choice == _ConflictChoice.keepBoth
                      ? PrimaryButton(
                          label: choice.label,
                          isCompact: true,
                          onPressed: () => _resolve(context, choice),
                        )
                      : SecondaryButton(
                          label: choice.label,
                          isCompact: true,
                          onPressed: () => _resolve(context, choice),
                        ),
                ),
              ],
            ],
          ),
        ] else
          const StatusCard(
            icon: Icons.check_circle_outline,
            title: '沒有需要處理的衝突',
            message: '所有裝置的紀錄都一致。',
          ),
        const Text('雲端同步是可選的。關掉它，App 一樣完整可用。', style: AppTextStyles.caption),
      ],
    );
  }
}

class _ConflictVersion extends StatelessWidget {
  const _ConflictVersion({
    required this.device,
    required this.time,
    required this.value,
  });

  final String device;
  final String time;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(device, style: AppTextStyles.itemTitle),
              const Spacer(),
              Text(time, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.bigNumber.copyWith(
              fontSize: 19,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
