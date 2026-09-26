import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/app_info.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../body/body_view_model.dart';
import '../exercise/exercise_picker_screen.dart';
import '../goal/goal_screen.dart';
import '../goal/goal_view_model.dart';
import '../journal/body_reading_entry_screen.dart';
import '../nutrition/food_library_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../sleep/sleep_goal_rows.dart';
import '../sleep/sleep_view_model.dart';
import '../trends/trends_view_model.dart';
import 'ai_settings_screen.dart';
import 'data_sources_screen.dart';
import 'export_screen.dart';
import 'privacy_screen.dart';
import 'references_screen.dart';

/// Who the user is to the app and how it is set up: what they have done
/// so far, what the app knows about them, their goals and reminders, the
/// libraries and modules, their data, and the app itself.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  // Each setting lives with its own feature; this page only gathers them.
  late final _backend = AppStoreScope.read(context).backend;
  late final _goal = GoalViewModel(_backend);
  late final _sleep = SleepViewModel(_backend);
  late final _trends = TrendsViewModel(_backend);
  late final _body = BodyViewModel(_backend);
  late final _version = appVersion();

  @override
  void dispose() {
    for (final model in [_goal, _sleep, _trends, _body]) {
      model.dispose();
    }
    super.dispose();
  }

  Future<void> _editBirthYear() async {
    final store = AppStoreScope.read(context);
    final typed = await showTextDialog(
      context,
      title: '出生年',
      initial: '${store.birthYear ?? ''}',
      hint: '例如 1995',
    );
    if (typed == null) return;
    final text = typed.trim();
    final year = int.tryParse(text);
    final thisYear = store.now().year;
    if (text.isEmpty) {
      store.setBirthYear(null);
    } else if (year != null && year >= thisYear - 120 && year <= thisYear) {
      store.setBirthYear(year);
    } else if (mounted) {
      showToast(context, '出生年請填 4 位數西元年。', kind: ToastKind.warning);
    }
  }

  Future<void> _pickFigure() async {
    final figure = await showAppDialog<MuscleFigure>(
      context,
      AppDialog(
        title: '人體圖',
        isChoiceList: true,
        actions: [
          for (final figure in MuscleFigure.values)
            DialogAction(
              label: figure.label,
              isSelected: figure == _trends.muscleFigure,
              onTap: () => Navigator.of(context).pop(figure),
            ),
        ],
      ),
    );
    if (figure != null) _trends.setMuscleFigure(figure);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_goal, _sleep, _trends, _body]),
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final store = AppStoreScope.of(context);
    final moduleNames = store.enabledModules.map((m) => m.title).join('、');
    final height = _body.latestReadings[BodyMetric.height];
    return CollapsingPage(
      title: '我的',
      children: [
        Gutter(child: FigureGrid(figures: _figures(store))),
        PageSection(
          label: '個人資料',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: '身高',
                    trailing: _value(
                      height == null
                          ? '未設定'
                          : '${formatAmount(height.value)} cm',
                    ),
                    onTap: () => pushModalPage<void>(
                      context,
                      const BodyReadingEntryScreen(only: BodyMetric.height),
                    ),
                  ),
                  NavRow(
                    title: '出生年',
                    trailing: _value(switch (store.birthYear) {
                      final year? => '$year 年',
                      null => '未設定',
                    }),
                    onTap: _editBirthYear,
                  ),
                  NavRow(
                    title: '人體圖',
                    trailing: _value(_trends.muscleFigure.label),
                    onTap: _pickFigure,
                  ),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: '目標與提醒',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: '每週目標',
                    subtitle: _goalSummary(_goal),
                    onTap: () => pushPage(context, const GoalScreen()),
                  ),
                  ...sleepGoalRows(context, _sleep),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: '功能',
          children: [
            Gutter(
              child: GroupedCard(
                children: [
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
                    onTap: () => pushPage(
                      context,
                      const OnboardingScreen(isEditing: true),
                    ),
                  ),
                  NavRow(
                    title: 'AI',
                    subtitle: store.aiProvider?.label ?? '未啟用',
                    onTap: () => pushPage(context, const AiSettingsScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: '資料',
          children: [
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
                  if (store.hasDemo)
                    SwitchRow(
                      title: '顯示示範資料',
                      value: store.showsDemo,
                      onChanged: store.setShowsDemo,
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
        ),
        PageSection(
          label: '關於',
          children: [
            Gutter(
              child: FutureBuilder(
                future: _version,
                builder: (context, version) => GroupedCard(
                  children: [
                    if (version.data case final version?)
                      KeyValueRow(label: '版本', value: version),
                    const KeyValueRow(
                      label: '動作圖',
                      value: 'Workout Guide · CC BY-SA 4.0',
                    ),
                    NavRow(
                      title: '文獻來源',
                      onTap: () => pushPage(context, const ReferencesScreen()),
                    ),
                    NavRow(
                      title: '開源授權',
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Mishirube',
                        applicationVersion: version.data,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// What has been done so far: the workouts, the days with training or
  /// activity, the goal kept, and since when.
  List<Figure> _figures(AppStore store) {
    final overview = _goal.overview;
    final since = store.firstRecordMonth;
    return [
      (
        label: '訓練',
        value: '${store.finishedWorkoutCount}',
        unit: '次',
        color: AppColors.training,
      ),
      (
        label: '運動日',
        value: '${overview.activeDays.length}',
        unit: '天',
        color: null,
      ),
      if (_goal.isEnabled && overview.hasGoal)
        (
          label: '連續達標',
          value: '${overview.streak.current}',
          unit: '週',
          color: null,
        ),
      if (since != null)
        (
          label: '開始紀錄',
          value: '${since.year} 年 ${since.month} 月',
          unit: null,
          color: null,
        ),
    ];
  }
}

Widget _value(String text) => Text(text, style: AppTextStyles.caption);

/// What the row says without opening the page: the goal, or that there
/// is not one yet.
String _goalSummary(GoalViewModel goal) {
  if (!goal.isEnabled) return '未設定';
  final overview = goal.overview;
  if (overview.isPaused) return '已暫停';
  final week = overview.thisWeek;
  return '每週 ${week.targetDays} 個運動日 · 本週 ${week.activeDays}';
}

/// `自己的 3 種 · 品牌 2 家`: what is in the library without opening it.
String _foodLibrarySummary(AppStore store) {
  final own = store.backend.nutrition
      .searchFoods('')
      .where((food) => !food.isBuiltIn && !food.isSize)
      .length;
  return '自己的 $own 種 · 品牌 ${store.catalogues.length} 家';
}

/// `1.3 MB`, to one decimal: the store's size is a rough figure, and a
/// byte count would read as more precise than it is useful.
String _megabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
