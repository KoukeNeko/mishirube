import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../../shared/app_info.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../body/body_view_model.dart';
import '../exercise/exercise_picker_screen.dart';
import '../goal/goal_screen.dart';
import '../goal/goal_view_model.dart';
import '../journal/body_reading_entry_screen.dart';
import '../nutrition/food_library_screen.dart';
import '../nutrition/nutrition_target_screen.dart';
import '../nutrition/nutrition_view_model.dart';
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
  late final _nutrition = NutritionViewModel(_backend);
  late final _version = appVersion();

  @override
  void dispose() {
    for (final model in [_goal, _sleep, _trends, _body, _nutrition]) {
      model.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFigure() async {
    final figure = await showAppDialog<MuscleFigure>(
      context,
      AppDialog(
        title: context.l10n.muscleMapSetting,
        isChoiceList: true,
        actions: [
          for (final figure in MuscleFigure.values)
            DialogAction(
              label: figure.labelIn(context.l10n),
              isSelected: figure == _trends.muscleFigure,
              onTap: () => Navigator.of(context).pop(figure),
            ),
        ],
      ),
    );
    if (figure != null) _trends.setMuscleFigure(figure);
  }

  Future<void> _pickConvention() async {
    final convention = await showAppDialog<NutritionConvention>(
      context,
      AppDialog(
        title: context.l10n.nutritionLabel,
        message: context.l10n.conventionMessage,
        isChoiceList: true,
        actions: [
          for (final convention in NutritionConvention.values)
            DialogAction(
              label: convention.labelIn(context.l10n),
              detail: joinList(context.l10n, [
                convention.carbName(context.l10n),
                convention.nameOf(context.l10n, convention.carbPart),
                '${convention.nameOf(context.l10n, convention.saltMeasure)} '
                    '${convention.saltMeasure.unit.label}',
              ]),
              isSelected: convention == _nutrition.convention,
              onTap: () => Navigator.of(context).pop(convention),
            ),
        ],
      ),
    );
    if (convention != null) _nutrition.setConvention(convention);
  }

  /// The app's own page in the system settings, where its language is
  /// chosen: the app follows the system's choice rather than keeping one
  /// of its own.
  Future<void> _openAppSettings() async {
    final opened = await launchUrl(Uri.parse('app-settings:'));
    if (!opened && mounted) {
      showToast(
        context,
        context.l10n.meSettingsOpenFailed,
        kind: ToastKind.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_goal, _sleep, _trends, _body, _nutrition]),
    builder: (context, _) => _page(context),
  );

  Widget _page(BuildContext context) {
    final store = AppStoreScope.of(context);
    final moduleNames = joinList(
      context.l10n,
      store.enabledModules.map((m) => m.title(context.l10n)),
    );
    final height = _body.latestReadings[BodyMetric.height];
    return CollapsingPage(
      title: context.l10n.tabMe,
      children: [
        Gutter(child: FigureGrid(figures: _figures(store))),
        PageSection(
          label: context.l10n.profileSection,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: context.l10n.bodyMetricHeight,
                    trailing: _value(
                      height == null
                          ? context.l10n.notSet
                          : '${formatAmount(height.value)} cm',
                    ),
                    onTap: () => pushModalPage<void>(
                      context,
                      const BodyReadingEntryScreen(only: BodyMetric.height),
                    ),
                  ),
                  NavRow(
                    title: context.l10n.targetInputBirthYear,
                    trailing: _value(switch (store.birthYear) {
                      final year? => context.l10n.yearValue(year: year),
                      null => context.l10n.notSet,
                    }),
                    onTap: () => editBirthYear(context),
                  ),
                  NavRow(
                    title: context.l10n.targetInputSex,
                    trailing: _value(
                      store.backend.journal.sex?.labelIn(context.l10n) ??
                          context.l10n.notSet,
                    ),
                    onTap: () => pickSex(context),
                  ),
                  NavRow(
                    title: context.l10n.muscleMapSetting,
                    trailing: _value(
                      _trends.muscleFigure.labelIn(context.l10n),
                    ),
                    onTap: _pickFigure,
                  ),
                  NavRow(
                    title: context.l10n.nutritionLabel,
                    trailing: _value(
                      _nutrition.convention.labelIn(context.l10n),
                    ),
                    onTap: _pickConvention,
                  ),
                  NavRow(
                    title: context.l10n.meLanguageRow,
                    trailing: _value(context.l10n.appLanguage),
                    onTap: _openAppSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: context.l10n.goalsAndReminders,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: context.l10n.weeklyGoal,
                    subtitle: _goalSummary(context.l10n, _goal),
                    onTap: () => pushPage(context, const GoalScreen()),
                  ),
                  NavRow(
                    title: context.l10n.dailyTargets,
                    subtitle: _nutritionTargetSummary(context.l10n, _nutrition),
                    onTap: () =>
                        pushPage(context, const NutritionTargetScreen()),
                  ),
                  ...sleepGoalRows(context, _sleep),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: context.l10n.featuresSection,
          children: [
            Gutter(
              child: GroupedCard(
                children: [
                  NavRow(
                    title: context.l10n.exerciseLibrary,
                    subtitle: context.l10n.exerciseLibraryDetail,
                    onTap: () => pushPage(
                      context,
                      const ExercisePickerScreen(purpose: PickerPurpose.browse),
                    ),
                  ),
                  NavRow(
                    title: context.l10n.foodLibrary,
                    subtitle: _foodLibrarySummary(context.l10n, store),
                    onTap: () => pushPage(context, const FoodLibraryScreen()),
                  ),
                  NavRow(
                    title: context.l10n.modulesTitle,
                    subtitle: context.l10n.modulesEnabled(modules: moduleNames),
                    onTap: () => pushPage(
                      context,
                      const OnboardingScreen(isEditing: true),
                    ),
                  ),
                  NavRow(
                    title: 'AI',
                    subtitle:
                        store.aiProvider?.labelIn(context.l10n) ??
                        context.l10n.notEnabled,
                    onTap: () => pushPage(context, const AiSettingsScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: context.l10n.dataSection,
          children: [
            if (store.recoveredDatabasePath case final moved?)
              Gutter(
                child: InfoBanner(
                  tone: CardTone.warning,
                  message: context.l10n.databaseRecovered(path: moved),
                ),
              ),
            Gutter(
              child: GroupedCard(
                children: [
                  KeyValueRow(
                    label: context.l10n.localData,
                    value: _megabytes(store.databaseBytes),
                  ),
                  NavRow(
                    title: context.l10n.dataSourcesLink,
                    subtitle: context.l10n.dataSourcesDetail,
                    onTap: () => pushPage(context, const DataSourcesScreen()),
                  ),
                  if (store.hasDemo)
                    SwitchRow(
                      title: context.l10n.showDemoData,
                      value: store.showsDemo,
                      onChanged: store.setShowsDemo,
                    ),
                  NavRow(
                    title: context.l10n.exportTitle,
                    subtitle: context.l10n.exportDetail,
                    onTap: () => pushPage(context, const ExportScreen()),
                  ),
                  NavRow(
                    title: context.l10n.privacyLink,
                    subtitle: context.l10n.privacyDetail,
                    onTap: () => pushPage(context, const PrivacyScreen()),
                  ),
                ],
              ),
            ),
          ],
        ),
        PageSection(
          label: context.l10n.aboutSection,
          children: [
            Gutter(
              child: FutureBuilder(
                future: _version,
                builder: (context, version) => GroupedCard(
                  children: [
                    if (version.data case final version?)
                      KeyValueRow(
                        label: context.l10n.versionLabel,
                        value: version,
                      ),
                    KeyValueRow(
                      label: context.l10n.exerciseImages,
                      value: 'Workout Guide · CC BY-SA 4.0',
                    ),
                    NavRow(
                      title: context.l10n.referencesTitle,
                      onTap: () => pushPage(context, const ReferencesScreen()),
                    ),
                    NavRow(
                      title: context.l10n.openSourceLicenses,
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
        label: context.l10n.workoutsFigure,
        value: '${store.finishedWorkoutCount}',
        unit: context.l10n.sessionsUnit,
        color: AppColors.training,
      ),
      (
        label: context.l10n.activeDaysFigure,
        value: '${overview.activeDays.length}',
        unit: context.l10n.daysUnit,
        color: null,
      ),
      if (_goal.isEnabled && overview.hasGoal)
        (
          label: context.l10n.streakSection,
          value: '${overview.streak.current}',
          unit: context.l10n.weeksUnit,
          color: null,
        ),
      if (since != null)
        (
          label: context.l10n.startedLogging,
          value: context.dates.yearMonth(since),
          unit: null,
          color: null,
        ),
    ];
  }
}

Widget _value(String text) => Text(text, style: AppTextStyles.caption);

/// What the row says without opening the page: the goal, or that there
/// is not one yet.
String _goalSummary(AppLocalizations l10n, GoalViewModel goal) {
  if (!goal.isEnabled) return l10n.notSet;
  final overview = goal.overview;
  if (overview.isPaused) return l10n.sessionPausedStatus;
  final week = overview.thisWeek;
  return l10n.goalSummaryText(target: week.targetDays, active: week.activeDays);
}

/// `2,100 kcal · 蛋白質 96 g`: today's targets, or 未設定 while the body
/// they are worked out from is not known.
String _nutritionTargetSummary(
  AppLocalizations l10n,
  NutritionViewModel nutrition,
) {
  final targets = nutrition.targetsOn(nutrition.now());
  final kcal = targets.kcal;
  if (kcal == null) return l10n.notSet;
  return [
    '${formatKcal(kcal)} kcal',
    if (targets.proteinGrams case final protein?)
      l10n.proteinGrams(grams: protein),
  ].join(' · ');
}

/// `自己的 3 種 · 品牌 2 家`: what is in the library without opening it.
String _foodLibrarySummary(AppLocalizations l10n, AppStore store) {
  final own = store.backend.nutrition
      .searchFoods('')
      .where((food) => !food.isBuiltIn && !food.isSize)
      .length;
  return l10n.foodLibrarySummary(own: own, brands: store.catalogues.length);
}

/// `1.3 MB`, to one decimal: the store's size is a rough figure, and a
/// byte count would read as more precise than it is useful.
String _megabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Asks for the year the user was born; empty clears it.
Future<void> editBirthYear(BuildContext context) async {
  final store = AppStoreScope.read(context);
  final typed = await showTextDialog(
    context,
    title: context.l10n.targetInputBirthYear,
    keyboardType: TextInputType.number,
    initial: '${store.birthYear ?? ''}',
    hint: context.l10n.birthYearHint,
  );
  if (typed == null) return;
  final text = typed.trim();
  final year = int.tryParse(text);
  final thisYear = store.now().year;
  if (text.isEmpty) {
    store.setBirthYear(null);
  } else if (year != null && year >= thisYear - 120 && year <= thisYear) {
    store.setBirthYear(year);
  } else if (context.mounted) {
    showToast(context, context.l10n.birthYearError, kind: ToastKind.warning);
  }
}

/// Asks for sex, which only the energy equations use.
Future<void> pickSex(BuildContext context) async {
  final journal = AppStoreScope.read(context).backend.journal;
  final sex = await showAppDialog<Sex>(
    context,
    AppDialog(
      title: context.l10n.targetInputSex,
      message: context.l10n.sexUseMessage,
      isChoiceList: true,
      actions: [
        for (final sex in Sex.values)
          DialogAction(
            label: sex.labelIn(context.l10n),
            isSelected: sex == journal.sex,
            onTap: () => Navigator.of(context).pop(sex),
          ),
      ],
    ),
  );
  if (sex != null) journal.setSex(sex);
}
