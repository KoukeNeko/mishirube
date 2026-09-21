import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import '../goal/goal_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'ai_settings_screen.dart';
import 'data_sources_screen.dart';
import 'export_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final moduleNames = store.enabledModules.map((m) => m.title).join('、');
    return CollapsingPage(
      title: '我的',
      children: [
        Gutter(
          child: const InfoBanner(
            tone: CardTone.training,
            icon: Icons.shield_outlined,
            message: '所有紀錄都先存在這台裝置。沒有帳號也能使用，雲端同步是可選的。',
          ),
        ),
        Gutter(child: const SectionLabel('產品怎麼為我工作')),
        Gutter(
          child: GroupedCard(
            children: [
              NavRow(
                title: '每週目標',
                subtitle: _goalSummary(store),
                onTap: () => pushPage(context, const GoalScreen()),
              ),
              NavRow(
                title: '動作庫',
                subtitle: '瀏覽、搜尋與建立自訂動作',
                onTap: () => pushModalPage<void>(
                  context,
                  const ExercisePickerScreen(purpose: PickerPurpose.browse),
                ),
              ),
              NavRow(
                title: '模組',
                subtitle: '$moduleNames 已啟用',
                onTap: () =>
                    pushPage(context, const OnboardingScreen(isEditing: true)),
              ),
              NavRow(
                title: 'AI',
                subtitle: store.aiProvider?.label ?? '未啟用',
                onTap: () => pushPage(context, const AiSettingsScreen()),
              ),
            ],
          ),
        ),
        Gutter(child: const SectionLabel('資料')),
        if (store.recoveredDatabasePath case final moved?)
          Gutter(
            child: InfoBanner(
              tone: CardTone.warning,
              message:
                  '上次的資料檔無法讀取，已移到 $moved，並從空白重新開始。'
                  '舊檔案沒有被刪除。',
            ),
          ),
        Gutter(
          child: GroupedCard(
            children: [
              KeyValueRow(
                label: '本機資料',
                value: _megabytes(store.databaseBytes),
              ),
              NavRow(
                title: '資料來源',
                subtitle: '手動輸入、匯入與內建目錄',
                onTap: () => pushPage(context, const DataSourcesScreen()),
              ),
              NavRow(
                title: '匯出',
                subtitle: '完整封存 JSON · CSV 檢視',
                onTap: () => pushPage(context, const ExportScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the row says without opening the page: the goal, or that there
/// is not one yet.
String _goalSummary(AppStore store) {
  if (!store.isGoalEnabled) return '還沒設定';
  final overview = store.goalOverview;
  if (overview.isPaused) return '已暫停';
  final week = overview.thisWeek;
  return '每週 ${week.targetDays} 個運動日 · 本週 ${week.activeDays}';
}

/// `1.3 MB`, to one decimal: the store's size is a rough figure, and a
/// byte count would read as more precise than it is useful.
String _megabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
