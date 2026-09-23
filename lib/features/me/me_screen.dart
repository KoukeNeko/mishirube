import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import '../goal/goal_screen.dart';
import '../nutrition/food_library_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'ai_settings_screen.dart';
import 'data_sources_screen.dart';
import 'export_screen.dart';
import 'privacy_screen.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final moduleNames = store.enabledModules.map((m) => m.title).join('、');
    return CollapsingPage(
      title: '我的',
      children: [
        Gutter(child: const SectionLabel('功能')),
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
                onTap: () => pushPage(
                  context,
                  const ExercisePickerScreen(purpose: PickerPurpose.browse),
                ),
              ),
              NavRow(
                title: '食物庫',
                subtitle: _foodLibrarySummary(store),
                onTap: () => pushPage(context, const FoodLibraryScreen()),
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
              NavRow(
                title: '隱私說明',
                subtitle: '資料存在哪裡、會送出什麼',
                onTap: () => pushPage(context, const PrivacyScreen()),
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
  if (!store.isGoalEnabled) return '未設定';
  final overview = store.goalOverview;
  if (overview.isPaused) return '已暫停';
  final week = overview.thisWeek;
  return '每週 ${week.targetDays} 個運動日 · 本週 ${week.activeDays}';
}

/// `自己的 3 種 · 品牌 2 家`: what is in the library without opening it.
String _foodLibrarySummary(AppStore store) {
  final own = store
      .searchFoods('')
      .where((food) => !food.isBuiltIn && !food.isSize)
      .length;
  return '自己的 $own 種 · 品牌 ${store.catalogues.length} 家';
}

/// `1.3 MB`, to one decimal: the store's size is a rough figure, and a
/// byte count would read as more precise than it is useful.
String _megabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
