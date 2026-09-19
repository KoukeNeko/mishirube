import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../shared/widgets/widgets.dart';
import '../onboarding/onboarding_screen.dart';
import 'ai_permissions_screen.dart';
import 'import_screen.dart';
import 'sync_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final moduleNames = store.enabledModules.map((m) => m.title).join('、');
    void notDesigned(String name) => showToast(context, '「$name」尚未設計');

    return CollapsingPage(
      title: '我的',
      children: [
        const InfoBanner(
          tone: CardTone.training,
          icon: Icons.shield_outlined,
          message: '所有紀錄都先存在這台裝置。沒有帳號也能使用，雲端同步是可選的。',
        ),
        const SectionLabel('產品怎麼為我工作'),
        GroupedCard(
          children: [
            NavRow(
              title: '目標',
              subtitle: '減重 · 每週訓練 3 次',
              onTap: () => notDesigned('目標'),
            ),
            NavRow(
              title: '模組',
              subtitle: '$moduleNames 已啟用',
              onTap: () =>
                  pushPage(context, const OnboardingScreen(isEditing: true)),
            ),
          ],
        ),
        const SectionLabel('資料'),
        GroupedCard(
          children: [
            const KeyValueRow(label: '本機資料', value: '72.4 MB'),
            NavRow(
              title: '資料來源',
              subtitle: 'Apple Health、TFDA、USDA',
              onTap: () => notDesigned('資料來源'),
            ),
            NavRow(
              title: '匯入與匯出',
              subtitle: '完整封存 JSON · CSV 檢視',
              onTap: () => pushPage(context, const ImportScreen()),
            ),
            NavRow(
              title: '備份與同步',
              subtitle: '本機備份 09:12 · 雲端未啟用',
              onTap: () => pushPage(context, const SyncScreen()),
            ),
          ],
        ),
        const SectionLabel('AI'),
        GroupedCard(
          children: [
            NavRow(
              title: '提供者與模型',
              subtitle: '自備金鑰 · OpenAI-compatible',
              onTap: () => pushPage(context, const AiPermissionsScreen()),
            ),
            NavRow(
              title: '權限',
              subtitle: '可讀 3 個模組 · 可寫 僅草稿',
              onTap: () => pushPage(context, const AiPermissionsScreen()),
            ),
          ],
        ),
        const SectionLabel('這台裝置'),
        GroupedCard(
          children: [
            NavRow(
              title: '單位與外觀',
              subtitle: '公斤、公分 · 跟隨系統',
              onTap: () => notDesigned('單位與外觀'),
            ),
            NavRow(
              title: '通知',
              subtitle: '依目標提醒',
              onTap: () => notDesigned('通知'),
            ),
          ],
        ),
      ],
    );
  }
}
