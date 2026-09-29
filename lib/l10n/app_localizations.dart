import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// This language's own name, shown on 我的 > 語言.
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get appLanguage;

  /// 我的: row that opens the app's page in system Settings to pick its language.
  ///
  /// In zh, this message translates to:
  /// **'語言'**
  String get meLanguageRow;

  /// Toast when the system Settings page could not be opened.
  ///
  /// In zh, this message translates to:
  /// **'無法開啟設定'**
  String get meSettingsOpenFailed;

  /// Toast action that undoes the change just made.
  ///
  /// In zh, this message translates to:
  /// **'復原'**
  String get commonUndo;

  /// Button that opens search.
  ///
  /// In zh, this message translates to:
  /// **'搜尋'**
  String get commonSearch;

  /// Control that closes the search field.
  ///
  /// In zh, this message translates to:
  /// **'關閉搜尋'**
  String get commonCloseSearch;

  /// App bar back button.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// Closes a dialog, sheet or menu.
  ///
  /// In zh, this message translates to:
  /// **'關閉'**
  String get commonClose;

  /// Saves a form or dialog.
  ///
  /// In zh, this message translates to:
  /// **'儲存'**
  String get commonSave;

  /// Backs out of a dialog without changing anything.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// Heading of a card stating one finding from the user's records.
  ///
  /// In zh, this message translates to:
  /// **'值得注意'**
  String get insightCardTitle;

  /// Month picker: step back a year.
  ///
  /// In zh, this message translates to:
  /// **'上一年'**
  String get monthPickerPreviousYear;

  /// Month picker: step forward a year.
  ///
  /// In zh, this message translates to:
  /// **'下一年'**
  String get monthPickerNextYear;

  /// Tapping outside the month popover closes it.
  ///
  /// In zh, this message translates to:
  /// **'關閉月份選擇'**
  String get monthPickerClose;

  /// Month popover: the year wheel.
  ///
  /// In zh, this message translates to:
  /// **'年份'**
  String get monthPickerYear;

  /// Month popover: the month wheel.
  ///
  /// In zh, this message translates to:
  /// **'月份'**
  String get monthPickerMonth;

  /// Screen reader label of a day in the week strip that has records; date is already formatted.
  ///
  /// In zh, this message translates to:
  /// **'{date}，有紀錄'**
  String dayStripHasRecords({required String date});

  /// Module: food and drink records.
  ///
  /// In zh, this message translates to:
  /// **'飲食'**
  String get moduleNutrition;

  /// Onboarding: what the food module covers.
  ///
  /// In zh, this message translates to:
  /// **'一餐、料理、成分與營養'**
  String get moduleNutritionDescription;

  /// Onboarding: what the water module covers.
  ///
  /// In zh, this message translates to:
  /// **'每次喝水的量與時間'**
  String get moduleWaterDescription;

  /// Module: body weight and measurements.
  ///
  /// In zh, this message translates to:
  /// **'體重'**
  String get moduleWeight;

  /// Onboarding: what the weight module covers.
  ///
  /// In zh, this message translates to:
  /// **'體重與圍度'**
  String get moduleWeightDescription;

  /// Module: strength training.
  ///
  /// In zh, this message translates to:
  /// **'訓練'**
  String get moduleTraining;

  /// Onboarding: what the training module covers.
  ///
  /// In zh, this message translates to:
  /// **'動作、課表與訓練紀錄'**
  String get moduleTrainingDescription;

  /// Module: cardio and sports such as running and cycling.
  ///
  /// In zh, this message translates to:
  /// **'運動'**
  String get moduleActivity;

  /// Onboarding: what the activity module covers.
  ///
  /// In zh, this message translates to:
  /// **'跑步、健走、騎車、球類、瑜伽'**
  String get moduleActivityDescription;

  /// Module: sleep.
  ///
  /// In zh, this message translates to:
  /// **'睡眠'**
  String get moduleSleep;

  /// Onboarding: what the sleep module covers.
  ///
  /// In zh, this message translates to:
  /// **'睡眠時間與品質'**
  String get moduleSleepDescription;

  /// Module: daily wellbeing journal.
  ///
  /// In zh, this message translates to:
  /// **'心情、精力、症狀'**
  String get moduleWellness;

  /// Onboarding: what the wellness module covers.
  ///
  /// In zh, this message translates to:
  /// **'一天的狀態日誌'**
  String get moduleWellnessDescription;

  /// Module: free notes.
  ///
  /// In zh, this message translates to:
  /// **'筆記'**
  String get moduleNotes;

  /// Onboarding: what the notes module covers.
  ///
  /// In zh, this message translates to:
  /// **'和任何一天或一筆紀錄關聯'**
  String get moduleNotesDescription;

  /// Where a record came from: typed in by the user.
  ///
  /// In zh, this message translates to:
  /// **'手動輸入'**
  String get sourceManual;

  /// Where a record came from: the app's demo data.
  ///
  /// In zh, this message translates to:
  /// **'示範資料'**
  String get sourceDemo;

  /// Where a record came from: an import.
  ///
  /// In zh, this message translates to:
  /// **'匯入'**
  String get sourceImport;

  /// Where a record came from: an AI draft the user confirmed.
  ///
  /// In zh, this message translates to:
  /// **'AI 草稿（已確認）'**
  String get sourceAiDraft;

  /// Where a record came from: the app's built-in food catalogue.
  ///
  /// In zh, this message translates to:
  /// **'內建目錄'**
  String get sourceCatalogue;

  /// Where a record came from: not known.
  ///
  /// In zh, this message translates to:
  /// **'不明'**
  String get sourceUnknown;

  /// Where a record came from: Apple's Health app.
  ///
  /// In zh, this message translates to:
  /// **'Apple 健康'**
  String get sourceAppleHealth;

  /// Page choosing which parts of the app are switched on.
  ///
  /// In zh, this message translates to:
  /// **'模組'**
  String get modulesTitle;

  /// Subtitle: more than one module can be chosen.
  ///
  /// In zh, this message translates to:
  /// **'可複選'**
  String get modulesPickSeveral;

  /// Finishes editing and closes.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get commonDone;

  /// Moves on to the next step.
  ///
  /// In zh, this message translates to:
  /// **'繼續'**
  String get commonContinue;

  /// Record page: where the record came from.
  ///
  /// In zh, this message translates to:
  /// **'來源'**
  String get journalSourceRow;

  /// The running session when it is a strength workout, used inside sentences.
  ///
  /// In zh, this message translates to:
  /// **'訓練'**
  String get sessionWorkout;

  /// Dialog title asking how a running session ends; session is its name (workout, or the activity).
  ///
  /// In zh, this message translates to:
  /// **'結束這次{session}？'**
  String sessionEndTitle({required String session});

  /// End-session dialog message for a workout.
  ///
  /// In zh, this message translates to:
  /// **'已完成的組數會存成紀錄；放棄則不會算成一次訓練。'**
  String get sessionEndWorkoutMessage;

  /// End-session dialog message for an activity.
  ///
  /// In zh, this message translates to:
  /// **'結束會存成一筆運動紀錄；放棄則什麼都不留。'**
  String get sessionEndActivityMessage;

  /// End-session dialog: keep the session as a record.
  ///
  /// In zh, this message translates to:
  /// **'結束並儲存'**
  String get sessionFinishAndSave;

  /// End-session dialog: throw the workout away.
  ///
  /// In zh, this message translates to:
  /// **'放棄這次訓練'**
  String get sessionDiscardWorkout;

  /// End-session dialog: throw the activity away.
  ///
  /// In zh, this message translates to:
  /// **'放棄這次運動'**
  String get sessionDiscardActivity;

  /// End-session dialog: back out and carry on.
  ///
  /// In zh, this message translates to:
  /// **'繼續{session}'**
  String sessionKeepGoing({required String session});

  /// Toast after a session was thrown away.
  ///
  /// In zh, this message translates to:
  /// **'已放棄這次{session}'**
  String sessionDiscarded({required String session});

  /// Button resuming a paused session.
  ///
  /// In zh, this message translates to:
  /// **'繼續{session}'**
  String sessionResume({required String session});

  /// Button pausing a running session.
  ///
  /// In zh, this message translates to:
  /// **'暫停{session}'**
  String sessionPause({required String session});

  /// Button ending a running session.
  ///
  /// In zh, this message translates to:
  /// **'結束{session}'**
  String sessionEnd({required String session});

  /// Screen reader label of the session bar while paused.
  ///
  /// In zh, this message translates to:
  /// **'{session}已暫停，回到{session}'**
  String sessionPausedOpen({required String session});

  /// Screen reader label of the session bar while running.
  ///
  /// In zh, this message translates to:
  /// **'{session}進行中，回到{session}'**
  String sessionRunningOpen({required String session});

  /// Session bar status while paused.
  ///
  /// In zh, this message translates to:
  /// **'已暫停'**
  String get sessionPausedStatus;

  /// Session bar status while running.
  ///
  /// In zh, this message translates to:
  /// **'{session}進行中'**
  String sessionRunningStatus({required String session});

  /// The dock's centre button that opens the add menu; the same action as the add buttons on pages.
  ///
  /// In zh, this message translates to:
  /// **'新增紀錄'**
  String get dockAddEntry;

  /// A page's add button while it shows another day than today, naming the day it logs to; date is formatted.
  ///
  /// In zh, this message translates to:
  /// **'新增紀錄到 {date}'**
  String addEntryToDay({required String date});

  /// Bottom tab.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get tabToday;

  /// Bottom tab: every record, day by day.
  ///
  /// In zh, this message translates to:
  /// **'紀錄'**
  String get tabLog;

  /// Bottom tab.
  ///
  /// In zh, this message translates to:
  /// **'趨勢'**
  String get tabTrends;

  /// Bottom tab: profile and settings.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabMe;

  /// Empty right pane on a tablet before anything is opened.
  ///
  /// In zh, this message translates to:
  /// **'未選取項目'**
  String get detailNothingSelected;

  /// Empty right pane of the log on a tablet.
  ///
  /// In zh, this message translates to:
  /// **'未選取紀錄'**
  String get detailNoEntrySelected;

  /// Add menu: log a glass of water in one tap.
  ///
  /// In zh, this message translates to:
  /// **'水'**
  String get recordWater;

  /// Add menu: body measurements such as waist.
  ///
  /// In zh, this message translates to:
  /// **'圍度'**
  String get recordMeasurements;

  /// Add menu: a body composition scale reading.
  ///
  /// In zh, this message translates to:
  /// **'身體組成'**
  String get recordBodyComposition;

  /// Undo toast after the water shortcut.
  ///
  /// In zh, this message translates to:
  /// **'已記錄 {millilitres} mL 水'**
  String waterLogged({required int millilitres});

  /// Tapping outside the add menu closes it.
  ///
  /// In zh, this message translates to:
  /// **'關閉新增紀錄'**
  String get quickLogClose;

  /// Bedtime reminder notification title.
  ///
  /// In zh, this message translates to:
  /// **'準備就寢'**
  String get bedtimeReminderTitle;

  /// Bedtime reminder notification body; times are formatted.
  ///
  /// In zh, this message translates to:
  /// **'{bedtime} 就寢，{wake} 起床'**
  String bedtimeReminderBody({required String bedtime, required String wake});

  /// Rest timer notification while resting between sets.
  ///
  /// In zh, this message translates to:
  /// **'休息中'**
  String get restResting;

  /// Rest timer notification when the rest is over.
  ///
  /// In zh, this message translates to:
  /// **'休息結束'**
  String get restEnded;

  /// Rest timer notification body naming the next exercise.
  ///
  /// In zh, this message translates to:
  /// **'下一組 · {exercise}'**
  String restNextSet({required String exercise});

  /// Sets done out of the workout's total.
  ///
  /// In zh, this message translates to:
  /// **'{done} / {total} 組'**
  String setsProgress({required int done, required int total});

  /// How an exercise's sets are recorded. (TrackingType.weightReps)
  ///
  /// In zh, this message translates to:
  /// **'重量 + 次數'**
  String get trackingTypeWeightReps;

  /// How an exercise's sets are recorded. (TrackingType.reps)
  ///
  /// In zh, this message translates to:
  /// **'次數'**
  String get trackingTypeReps;

  /// How an exercise's sets are recorded. (TrackingType.duration)
  ///
  /// In zh, this message translates to:
  /// **'時間'**
  String get trackingTypeDuration;

  /// How an exercise's sets are recorded. (TrackingType.distance)
  ///
  /// In zh, this message translates to:
  /// **'距離'**
  String get trackingTypeDistance;

  /// Where an exercise in the library came from. (ExerciseSource.builtIn)
  ///
  /// In zh, this message translates to:
  /// **'內建'**
  String get exerciseSourceBuiltIn;

  /// Where an exercise in the library came from. (ExerciseSource.custom)
  ///
  /// In zh, this message translates to:
  /// **'自訂'**
  String get exerciseSourceCustom;

  /// Where an exercise in the library came from. (ExerciseSource.imported)
  ///
  /// In zh, this message translates to:
  /// **'匯入'**
  String get exerciseSourceImported;

  /// A region of the body that muscles are grouped under. (BodyRegion.chest)
  ///
  /// In zh, this message translates to:
  /// **'胸'**
  String get bodyRegionChest;

  /// A region of the body that muscles are grouped under. (BodyRegion.shoulders)
  ///
  /// In zh, this message translates to:
  /// **'肩'**
  String get bodyRegionShoulders;

  /// A region of the body that muscles are grouped under. (BodyRegion.back)
  ///
  /// In zh, this message translates to:
  /// **'背'**
  String get bodyRegionBack;

  /// A region of the body that muscles are grouped under. (BodyRegion.arms)
  ///
  /// In zh, this message translates to:
  /// **'手臂'**
  String get bodyRegionArms;

  /// A region of the body that muscles are grouped under. (BodyRegion.core)
  ///
  /// In zh, this message translates to:
  /// **'核心'**
  String get bodyRegionCore;

  /// A region of the body that muscles are grouped under. (BodyRegion.legs)
  ///
  /// In zh, this message translates to:
  /// **'腿臀'**
  String get bodyRegionLegs;

  /// A muscle an exercise trains. (MuscleGroup.chest)
  ///
  /// In zh, this message translates to:
  /// **'胸'**
  String get muscleChest;

  /// A muscle an exercise trains. (MuscleGroup.frontDelts)
  ///
  /// In zh, this message translates to:
  /// **'三角肌前束'**
  String get muscleFrontDelts;

  /// A muscle an exercise trains. (MuscleGroup.sideDelts)
  ///
  /// In zh, this message translates to:
  /// **'三角肌中束'**
  String get muscleSideDelts;

  /// A muscle an exercise trains. (MuscleGroup.rearDelts)
  ///
  /// In zh, this message translates to:
  /// **'三角肌後束'**
  String get muscleRearDelts;

  /// A muscle an exercise trains. (MuscleGroup.biceps)
  ///
  /// In zh, this message translates to:
  /// **'二頭肌'**
  String get muscleBiceps;

  /// A muscle an exercise trains. (MuscleGroup.triceps)
  ///
  /// In zh, this message translates to:
  /// **'三頭肌'**
  String get muscleTriceps;

  /// A muscle an exercise trains. (MuscleGroup.forearms)
  ///
  /// In zh, this message translates to:
  /// **'前臂'**
  String get muscleForearms;

  /// A muscle an exercise trains. (MuscleGroup.traps)
  ///
  /// In zh, this message translates to:
  /// **'斜方肌'**
  String get muscleTraps;

  /// A muscle an exercise trains. (MuscleGroup.lats)
  ///
  /// In zh, this message translates to:
  /// **'背闊肌'**
  String get muscleLats;

  /// A muscle an exercise trains. (MuscleGroup.upperBack)
  ///
  /// In zh, this message translates to:
  /// **'上背'**
  String get muscleUpperBack;

  /// A muscle an exercise trains. (MuscleGroup.spinalErectors)
  ///
  /// In zh, this message translates to:
  /// **'豎脊肌'**
  String get muscleSpinalErectors;

  /// A muscle an exercise trains. (MuscleGroup.abs)
  ///
  /// In zh, this message translates to:
  /// **'腹直肌'**
  String get muscleAbs;

  /// A muscle an exercise trains. (MuscleGroup.obliques)
  ///
  /// In zh, this message translates to:
  /// **'腹斜肌'**
  String get muscleObliques;

  /// A muscle an exercise trains. (MuscleGroup.glutes)
  ///
  /// In zh, this message translates to:
  /// **'臀'**
  String get muscleGlutes;

  /// Front thigh.
  ///
  /// In zh, this message translates to:
  /// **'股四頭'**
  String get muscleQuads;

  /// Back thigh.
  ///
  /// In zh, this message translates to:
  /// **'腿後'**
  String get muscleHamstrings;

  /// A muscle an exercise trains. (MuscleGroup.adductors)
  ///
  /// In zh, this message translates to:
  /// **'內收肌'**
  String get muscleAdductors;

  /// A muscle an exercise trains. (MuscleGroup.abductors)
  ///
  /// In zh, this message translates to:
  /// **'外展肌'**
  String get muscleAbductors;

  /// A muscle an exercise trains. (MuscleGroup.calves)
  ///
  /// In zh, this message translates to:
  /// **'小腿'**
  String get muscleCalves;

  /// A muscle an exercise trains. (MuscleGroup.back)
  ///
  /// In zh, this message translates to:
  /// **'背'**
  String get muscleBack;

  /// A muscle an exercise trains. (MuscleGroup.shoulders)
  ///
  /// In zh, this message translates to:
  /// **'肩'**
  String get muscleShoulders;

  /// A muscle an exercise trains. (MuscleGroup.arms)
  ///
  /// In zh, this message translates to:
  /// **'手臂'**
  String get muscleArms;

  /// A muscle an exercise trains. (MuscleGroup.core)
  ///
  /// In zh, this message translates to:
  /// **'核心'**
  String get muscleCore;

  /// The equipment an exercise uses. (Equipment.barbell)
  ///
  /// In zh, this message translates to:
  /// **'槓鈴'**
  String get equipmentBarbell;

  /// The equipment an exercise uses. (Equipment.dumbbell)
  ///
  /// In zh, this message translates to:
  /// **'啞鈴'**
  String get equipmentDumbbell;

  /// The equipment an exercise uses. (Equipment.cable)
  ///
  /// In zh, this message translates to:
  /// **'滑輪'**
  String get equipmentCable;

  /// The equipment an exercise uses. (Equipment.machine)
  ///
  /// In zh, this message translates to:
  /// **'機械'**
  String get equipmentMachine;

  /// The equipment an exercise uses. (Equipment.smithMachine)
  ///
  /// In zh, this message translates to:
  /// **'史密斯機'**
  String get equipmentSmithMachine;

  /// The equipment an exercise uses. (Equipment.kettlebell)
  ///
  /// In zh, this message translates to:
  /// **'壺鈴'**
  String get equipmentKettlebell;

  /// The equipment an exercise uses. (Equipment.ezBar)
  ///
  /// In zh, this message translates to:
  /// **'EZ 槓'**
  String get equipmentEzBar;

  /// The equipment an exercise uses. (Equipment.trapBar)
  ///
  /// In zh, this message translates to:
  /// **'六角槓'**
  String get equipmentTrapBar;

  /// The equipment an exercise uses. (Equipment.landmine)
  ///
  /// In zh, this message translates to:
  /// **'地雷管'**
  String get equipmentLandmine;

  /// The equipment an exercise uses. (Equipment.plate)
  ///
  /// In zh, this message translates to:
  /// **'槓片'**
  String get equipmentPlate;

  /// The equipment an exercise uses. (Equipment.band)
  ///
  /// In zh, this message translates to:
  /// **'彈力帶'**
  String get equipmentBand;

  /// The equipment an exercise uses. (Equipment.bodyweight)
  ///
  /// In zh, this message translates to:
  /// **'徒手'**
  String get equipmentBodyweight;

  /// The equipment an exercise uses. (Equipment.cardio)
  ///
  /// In zh, this message translates to:
  /// **'有氧器材'**
  String get equipmentCardio;

  /// The equipment an exercise uses. (Equipment.other)
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get equipmentOther;

  /// The movement pattern an exercise follows. (MovementPattern.squat)
  ///
  /// In zh, this message translates to:
  /// **'深蹲'**
  String get movementPatternSquat;

  /// The movement pattern an exercise follows. (MovementPattern.hinge)
  ///
  /// In zh, this message translates to:
  /// **'髖伸'**
  String get movementPatternHinge;

  /// The movement pattern an exercise follows. (MovementPattern.lunge)
  ///
  /// In zh, this message translates to:
  /// **'弓步與單腳'**
  String get movementPatternLunge;

  /// The movement pattern an exercise follows. (MovementPattern.horizontalPush)
  ///
  /// In zh, this message translates to:
  /// **'水平推'**
  String get movementPatternHorizontalPush;

  /// The movement pattern an exercise follows. (MovementPattern.horizontalPull)
  ///
  /// In zh, this message translates to:
  /// **'水平拉'**
  String get movementPatternHorizontalPull;

  /// The movement pattern an exercise follows. (MovementPattern.verticalPush)
  ///
  /// In zh, this message translates to:
  /// **'垂直推'**
  String get movementPatternVerticalPush;

  /// The movement pattern an exercise follows. (MovementPattern.verticalPull)
  ///
  /// In zh, this message translates to:
  /// **'垂直拉'**
  String get movementPatternVerticalPull;

  /// The movement pattern an exercise follows. (MovementPattern.isolation)
  ///
  /// In zh, this message translates to:
  /// **'單關節'**
  String get movementPatternIsolation;

  /// The movement pattern an exercise follows. (MovementPattern.core)
  ///
  /// In zh, this message translates to:
  /// **'核心'**
  String get movementPatternCore;

  /// The movement pattern an exercise follows. (MovementPattern.carry)
  ///
  /// In zh, this message translates to:
  /// **'搬運'**
  String get movementPatternCarry;

  /// The movement pattern an exercise follows. (MovementPattern.conditioning)
  ///
  /// In zh, this message translates to:
  /// **'體能'**
  String get movementPatternConditioning;

  /// The movement pattern an exercise follows. (MovementPattern.unilateral)
  ///
  /// In zh, this message translates to:
  /// **'單側'**
  String get movementPatternUnilateral;

  /// Whether an exercise works both sides together, one at a time, or alternating. (Laterality.bilateral)
  ///
  /// In zh, this message translates to:
  /// **'雙側'**
  String get lateralityBilateral;

  /// Whether an exercise works both sides together, one at a time, or alternating. (Laterality.unilateral)
  ///
  /// In zh, this message translates to:
  /// **'單側'**
  String get lateralityUnilateral;

  /// Whether an exercise works both sides together, one at a time, or alternating. (Laterality.alternating)
  ///
  /// In zh, this message translates to:
  /// **'左右交替'**
  String get lateralityAlternating;

  /// The kind of a set in a workout. (SetType.working)
  ///
  /// In zh, this message translates to:
  /// **'工作組'**
  String get setTypeWorking;

  /// The kind of a set in a workout. (SetType.warmup)
  ///
  /// In zh, this message translates to:
  /// **'熱身組'**
  String get setTypeWarmup;

  /// The kind of a set in a workout. (SetType.drop)
  ///
  /// In zh, this message translates to:
  /// **'遞減組'**
  String get setTypeDrop;

  /// The kind of a set in a workout. (SetType.failure)
  ///
  /// In zh, this message translates to:
  /// **'力竭組'**
  String get setTypeFailure;

  /// How heavy the last sets felt. (Workload.tooLight)
  ///
  /// In zh, this message translates to:
  /// **'太輕'**
  String get workloadTooLight;

  /// How heavy the last sets felt. (Workload.right)
  ///
  /// In zh, this message translates to:
  /// **'剛好'**
  String get workloadRight;

  /// How heavy the last sets felt. (Workload.tooHard)
  ///
  /// In zh, this message translates to:
  /// **'太吃力'**
  String get workloadTooHard;

  /// A set's kind inside a phrase that already says set (as in "add a working set"). (SetType.working)
  ///
  /// In zh, this message translates to:
  /// **'工作'**
  String get setKindWorking;

  /// A set's kind inside a phrase that already says set. (SetType.warmup)
  ///
  /// In zh, this message translates to:
  /// **'熱身'**
  String get setKindWarmup;

  /// A set's kind inside a phrase that already says set. (SetType.drop)
  ///
  /// In zh, this message translates to:
  /// **'遞減'**
  String get setKindDrop;

  /// A set's kind inside a phrase that already says set. (SetType.failure)
  ///
  /// In zh, this message translates to:
  /// **'力竭'**
  String get setKindFailure;

  /// Why a swap is offered: it follows the same movement pattern.
  ///
  /// In zh, this message translates to:
  /// **'同為{pattern}模式'**
  String substitutionSamePattern({required String pattern});

  /// Why a swap is offered: it trains the same muscles (a list).
  ///
  /// In zh, this message translates to:
  /// **'同樣練{muscles}'**
  String substitutionSameMuscles({required String muscles});

  /// Why a swap is offered: the user's gym has its equipment.
  ///
  /// In zh, this message translates to:
  /// **'{equipment}可用'**
  String substitutionEquipmentAvailable({required String equipment});

  /// Note on a swap: its sets are recorded another way.
  ///
  /// In zh, this message translates to:
  /// **'記錄方式改為{tracking}'**
  String substitutionTrackingChanges({required String tracking});

  /// Note on a swap: different equipment, so the weight does not carry over.
  ///
  /// In zh, this message translates to:
  /// **'換{equipment}，重量需重新設定'**
  String substitutionEquipmentChanges({required String equipment});

  /// Note on a swap: it works one side at a time.
  ///
  /// In zh, this message translates to:
  /// **'單側動作，次數請重新設定'**
  String get substitutionOneSide;

  /// Default name of a routine with no exercises yet.
  ///
  /// In zh, this message translates to:
  /// **'新的課表'**
  String get routineUntitled;

  /// Name given to a workout started without a routine; stored with the workout.
  ///
  /// In zh, this message translates to:
  /// **'自由訓練'**
  String get workoutFreeName;

  /// A working set named by its place among the exercise's working sets.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 組'**
  String setOrdinal({required int number});

  /// A muscle and the working sets it got.
  ///
  /// In zh, this message translates to:
  /// **'{muscle} {sets} 組'**
  String muscleSetCount({required String muscle, required int sets});

  /// What kind of figures a food or record holds. (NutrientValueType.declared)
  ///
  /// In zh, this message translates to:
  /// **'標示值'**
  String get valueTypeDeclared;

  /// What kind of figures a food or record holds. (NutrientValueType.max)
  ///
  /// In zh, this message translates to:
  /// **'最高值'**
  String get valueTypeMax;

  /// What kind of figures a food or record holds. (NutrientValueType.estimate)
  ///
  /// In zh, this message translates to:
  /// **'估計值'**
  String get valueTypeEstimate;

  /// Which meal of the day something was eaten at. (MealType.breakfast)
  ///
  /// In zh, this message translates to:
  /// **'早餐'**
  String get mealTypeBreakfast;

  /// Which meal of the day something was eaten at. (MealType.lunch)
  ///
  /// In zh, this message translates to:
  /// **'午餐'**
  String get mealTypeLunch;

  /// Which meal of the day something was eaten at. (MealType.dinner)
  ///
  /// In zh, this message translates to:
  /// **'晚餐'**
  String get mealTypeDinner;

  /// Which meal of the day something was eaten at. (MealType.snack)
  ///
  /// In zh, this message translates to:
  /// **'點心'**
  String get mealTypeSnack;

  /// Whether something was eaten or drunk. (ConsumptionKind.food)
  ///
  /// In zh, this message translates to:
  /// **'食物'**
  String get consumptionKindFood;

  /// Whether something was eaten or drunk. (ConsumptionKind.beverage)
  ///
  /// In zh, this message translates to:
  /// **'飲品'**
  String get consumptionKindBeverage;

  /// Whether something was eaten or drunk. (ConsumptionKind.unknown)
  ///
  /// In zh, this message translates to:
  /// **'未指定'**
  String get consumptionKindUnknown;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.gram)
  ///
  /// In zh, this message translates to:
  /// **'g'**
  String get servingUnitGram;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.kilogram)
  ///
  /// In zh, this message translates to:
  /// **'kg'**
  String get servingUnitKilogram;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.ounce)
  ///
  /// In zh, this message translates to:
  /// **'oz'**
  String get servingUnitOunce;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.pound)
  ///
  /// In zh, this message translates to:
  /// **'lb'**
  String get servingUnitPound;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.tael)
  ///
  /// In zh, this message translates to:
  /// **'台兩'**
  String get servingUnitTael;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.catty)
  ///
  /// In zh, this message translates to:
  /// **'台斤'**
  String get servingUnitCatty;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.millilitre)
  ///
  /// In zh, this message translates to:
  /// **'ml'**
  String get servingUnitMillilitre;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.litre)
  ///
  /// In zh, this message translates to:
  /// **'L'**
  String get servingUnitLitre;

  /// A unit a serving is measured in; symbols stay as they are. (ServingUnit.serving)
  ///
  /// In zh, this message translates to:
  /// **'份'**
  String get servingUnitServing;

  /// An allergen a maker declares. (Allergen.crustacean)
  ///
  /// In zh, this message translates to:
  /// **'甲殼類'**
  String get allergenCrustacean;

  /// An allergen a maker declares. (Allergen.mango)
  ///
  /// In zh, this message translates to:
  /// **'芒果'**
  String get allergenMango;

  /// An allergen a maker declares. (Allergen.peanut)
  ///
  /// In zh, this message translates to:
  /// **'花生'**
  String get allergenPeanut;

  /// An allergen a maker declares. (Allergen.milk)
  ///
  /// In zh, this message translates to:
  /// **'牛奶'**
  String get allergenMilk;

  /// An allergen a maker declares. (Allergen.egg)
  ///
  /// In zh, this message translates to:
  /// **'蛋'**
  String get allergenEgg;

  /// An allergen a maker declares. (Allergen.treeNut)
  ///
  /// In zh, this message translates to:
  /// **'堅果'**
  String get allergenTreeNut;

  /// An allergen a maker declares. (Allergen.sesame)
  ///
  /// In zh, this message translates to:
  /// **'芝麻'**
  String get allergenSesame;

  /// An allergen a maker declares. (Allergen.gluten)
  ///
  /// In zh, this message translates to:
  /// **'麩質'**
  String get allergenGluten;

  /// An allergen a maker declares. (Allergen.soy)
  ///
  /// In zh, this message translates to:
  /// **'大豆'**
  String get allergenSoy;

  /// An allergen a maker declares. (Allergen.fish)
  ///
  /// In zh, this message translates to:
  /// **'魚類'**
  String get allergenFish;

  /// An allergen a maker declares. (Allergen.sulphite)
  ///
  /// In zh, this message translates to:
  /// **'亞硫酸鹽'**
  String get allergenSulphite;

  /// A nutrient beyond the five every record has. (Nutrient.saturatedFat)
  ///
  /// In zh, this message translates to:
  /// **'飽和脂肪'**
  String get nutrientSaturatedFat;

  /// A nutrient beyond the five every record has. (Nutrient.transFat)
  ///
  /// In zh, this message translates to:
  /// **'反式脂肪'**
  String get nutrientTransFat;

  /// A nutrient beyond the five every record has. (Nutrient.sugar)
  ///
  /// In zh, this message translates to:
  /// **'糖'**
  String get nutrientSugar;

  /// A nutrient beyond the five every record has. (Nutrient.sodium)
  ///
  /// In zh, this message translates to:
  /// **'鈉'**
  String get nutrientSodium;

  /// A nutrient beyond the five every record has. (Nutrient.netCarb)
  ///
  /// In zh, this message translates to:
  /// **'糖質'**
  String get nutrientNetCarb;

  /// A nutrient beyond the five every record has. (Nutrient.saltEquivalent)
  ///
  /// In zh, this message translates to:
  /// **'食鹽相當量'**
  String get nutrientSaltEquivalent;

  /// A nutrient beyond the five every record has. (Nutrient.polyols)
  ///
  /// In zh, this message translates to:
  /// **'糖醇'**
  String get nutrientPolyols;

  /// A nutrient beyond the five every record has. (Nutrient.alcohol)
  ///
  /// In zh, this message translates to:
  /// **'酒精'**
  String get nutrientAlcohol;

  /// A nutrient beyond the five every record has. (Nutrient.cholesterol)
  ///
  /// In zh, this message translates to:
  /// **'膽固醇'**
  String get nutrientCholesterol;

  /// A nutrient beyond the five every record has. (Nutrient.caffeine)
  ///
  /// In zh, this message translates to:
  /// **'咖啡因'**
  String get nutrientCaffeine;

  /// A nutrient beyond the five every record has. (Nutrient.essentialAminoAcids)
  ///
  /// In zh, this message translates to:
  /// **'必需胺基酸'**
  String get nutrientEssentialAminoAcids;

  /// A nutrient beyond the five every record has. (Nutrient.bcaa)
  ///
  /// In zh, this message translates to:
  /// **'支鏈胺基酸'**
  String get nutrientBcaa;

  /// A nutrient beyond the five every record has. (Nutrient.leucine)
  ///
  /// In zh, this message translates to:
  /// **'白胺酸'**
  String get nutrientLeucine;

  /// A nutrient beyond the five every record has. (Nutrient.isoleucine)
  ///
  /// In zh, this message translates to:
  /// **'異白胺酸'**
  String get nutrientIsoleucine;

  /// A nutrient beyond the five every record has. (Nutrient.valine)
  ///
  /// In zh, this message translates to:
  /// **'纈胺酸'**
  String get nutrientValine;

  /// A nutrient beyond the five every record has. (Nutrient.glutamine)
  ///
  /// In zh, this message translates to:
  /// **'麩醯胺酸'**
  String get nutrientGlutamine;

  /// A nutrient beyond the five every record has. (Nutrient.calcium)
  ///
  /// In zh, this message translates to:
  /// **'鈣'**
  String get nutrientCalcium;

  /// A nutrient beyond the five every record has. (Nutrient.phosphorus)
  ///
  /// In zh, this message translates to:
  /// **'磷'**
  String get nutrientPhosphorus;

  /// A nutrient beyond the five every record has. (Nutrient.magnesium)
  ///
  /// In zh, this message translates to:
  /// **'鎂'**
  String get nutrientMagnesium;

  /// A nutrient beyond the five every record has. (Nutrient.iron)
  ///
  /// In zh, this message translates to:
  /// **'鐵'**
  String get nutrientIron;

  /// A nutrient beyond the five every record has. (Nutrient.zinc)
  ///
  /// In zh, this message translates to:
  /// **'鋅'**
  String get nutrientZinc;

  /// A nutrient beyond the five every record has. (Nutrient.potassium)
  ///
  /// In zh, this message translates to:
  /// **'鉀'**
  String get nutrientPotassium;

  /// A nutrient beyond the five every record has. (Nutrient.iodine)
  ///
  /// In zh, this message translates to:
  /// **'碘'**
  String get nutrientIodine;

  /// A nutrient beyond the five every record has. (Nutrient.selenium)
  ///
  /// In zh, this message translates to:
  /// **'硒'**
  String get nutrientSelenium;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminA)
  ///
  /// In zh, this message translates to:
  /// **'維生素 A'**
  String get nutrientVitaminA;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminD)
  ///
  /// In zh, this message translates to:
  /// **'維生素 D'**
  String get nutrientVitaminD;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminE)
  ///
  /// In zh, this message translates to:
  /// **'維生素 E'**
  String get nutrientVitaminE;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminK)
  ///
  /// In zh, this message translates to:
  /// **'維生素 K'**
  String get nutrientVitaminK;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminC)
  ///
  /// In zh, this message translates to:
  /// **'維生素 C'**
  String get nutrientVitaminC;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminB1)
  ///
  /// In zh, this message translates to:
  /// **'維生素 B1'**
  String get nutrientVitaminB1;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminB2)
  ///
  /// In zh, this message translates to:
  /// **'維生素 B2'**
  String get nutrientVitaminB2;

  /// A nutrient beyond the five every record has. (Nutrient.niacin)
  ///
  /// In zh, this message translates to:
  /// **'菸鹼素'**
  String get nutrientNiacin;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminB6)
  ///
  /// In zh, this message translates to:
  /// **'維生素 B6'**
  String get nutrientVitaminB6;

  /// A nutrient beyond the five every record has. (Nutrient.vitaminB12)
  ///
  /// In zh, this message translates to:
  /// **'維生素 B12'**
  String get nutrientVitaminB12;

  /// A nutrient beyond the five every record has. (Nutrient.folate)
  ///
  /// In zh, this message translates to:
  /// **'葉酸'**
  String get nutrientFolate;

  /// A nutrient beyond the five every record has. (Nutrient.pantothenicAcid)
  ///
  /// In zh, this message translates to:
  /// **'泛酸'**
  String get nutrientPantothenicAcid;

  /// A nutrient beyond the five every record has. (Nutrient.biotin)
  ///
  /// In zh, this message translates to:
  /// **'生物素'**
  String get nutrientBiotin;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.taiwan)
  ///
  /// In zh, this message translates to:
  /// **'台灣'**
  String get conventionTaiwan;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.japan)
  ///
  /// In zh, this message translates to:
  /// **'日本'**
  String get conventionJapan;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.unitedStates)
  ///
  /// In zh, this message translates to:
  /// **'美國'**
  String get conventionUnitedStates;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.europeanUnion)
  ///
  /// In zh, this message translates to:
  /// **'歐盟'**
  String get conventionEuropeanUnion;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.australiaNewZealand)
  ///
  /// In zh, this message translates to:
  /// **'澳洲、紐西蘭'**
  String get conventionAustraliaNewZealand;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.korea)
  ///
  /// In zh, this message translates to:
  /// **'韓國'**
  String get conventionKorea;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.china)
  ///
  /// In zh, this message translates to:
  /// **'中國'**
  String get conventionChina;

  /// A country whose way of reading nutrition labels the user follows. (NutritionConvention.canada)
  ///
  /// In zh, this message translates to:
  /// **'加拿大'**
  String get conventionCanada;

  /// Energy of food, in kcal.
  ///
  /// In zh, this message translates to:
  /// **'熱量'**
  String get macroEnergy;

  /// Macronutrient.
  ///
  /// In zh, this message translates to:
  /// **'蛋白質'**
  String get macroProtein;

  /// Macronutrient; the total, fibre included.
  ///
  /// In zh, this message translates to:
  /// **'碳水化合物'**
  String get macroCarb;

  /// Macronutrient.
  ///
  /// In zh, this message translates to:
  /// **'脂肪'**
  String get macroFat;

  /// Dietary fibre.
  ///
  /// In zh, this message translates to:
  /// **'膳食纖維'**
  String get macroFibre;

  /// A drink's serving given as the cup's capacity; amount is formatted with its unit.
  ///
  /// In zh, this message translates to:
  /// **'杯容量 {amount}'**
  String foodCupCapacity({required String amount});

  /// Tag on a food whose figures come from the maker's own published data.
  ///
  /// In zh, this message translates to:
  /// **'官方資料'**
  String get foodOfficialData;

  /// Button adding a food to the plate being logged.
  ///
  /// In zh, this message translates to:
  /// **'加入「{food}」'**
  String foodAdd({required String food});

  /// What a food opens at: last time's portion and its energy (both formatted).
  ///
  /// In zh, this message translates to:
  /// **'上次 {portion} · {kcal}'**
  String foodLastPortion({required String portion, required String kcal});

  /// A drink that comes in several cup sizes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 種杯型'**
  String foodCupSizes({required int count});

  /// What a new food opens at: one serving (described) and its energy.
  ///
  /// In zh, this message translates to:
  /// **'一份 {serving} · {kcal}'**
  String foodOneServing({required String serving, required String kcal});

  /// Warning on an AI draft item whose energy is far from what its macronutrients add up to.
  ///
  /// In zh, this message translates to:
  /// **'{item}的熱量和蛋白質、碳水化合物、脂肪算起來差得多，請核對。'**
  String draftEnergyMismatchItem({required String item});

  /// Warning on a scanned label whose energy is far from what its macronutrients add up to.
  ///
  /// In zh, this message translates to:
  /// **'熱量和蛋白質、碳水化合物、脂肪算起來差得多，請核對這幾格。'**
  String get draftEnergyMismatch;

  /// Warning on a scanned label whose per-serving figures may have been read from the per-100 column.
  ///
  /// In zh, this message translates to:
  /// **'每份的熱量和每 100 的熱量依份量換算對不上，可能填到另一欄，請核對。'**
  String get draftColumnMismatch;

  /// Warning on a scanned EU or Australian label whose total carbohydrate cannot be worked out.
  ///
  /// In zh, this message translates to:
  /// **'這張標示的碳水化合物不含膳食纖維，又沒有印膳食纖維，碳水化合物留白。'**
  String get draftCarbWithoutFibre;

  /// A group of activity types in the picker. (ActivityGroup.walkRun)
  ///
  /// In zh, this message translates to:
  /// **'走路與跑步'**
  String get activityGroupWalkRun;

  /// A group of activity types in the picker. (ActivityGroup.cycling)
  ///
  /// In zh, this message translates to:
  /// **'自行車'**
  String get activityGroupCycling;

  /// A group of activity types in the picker. (ActivityGroup.water)
  ///
  /// In zh, this message translates to:
  /// **'水上運動'**
  String get activityGroupWater;

  /// A group of activity types in the picker. (ActivityGroup.ball)
  ///
  /// In zh, this message translates to:
  /// **'球類'**
  String get activityGroupBall;

  /// A group of activity types in the picker. (ActivityGroup.indoor)
  ///
  /// In zh, this message translates to:
  /// **'室內器材'**
  String get activityGroupIndoor;

  /// A group of activity types in the picker. (ActivityGroup.mindBody)
  ///
  /// In zh, this message translates to:
  /// **'身心與伸展'**
  String get activityGroupMindBody;

  /// A group of activity types in the picker. (ActivityGroup.other)
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get activityGroupOther;

  /// How the activity page groups its health metrics, following Apple Health. (ActivityMetricGroup.movement)
  ///
  /// In zh, this message translates to:
  /// **'日常活動'**
  String get activityMetricGroupMovement;

  /// How the activity page groups its health metrics, following Apple Health. (ActivityMetricGroup.heart)
  ///
  /// In zh, this message translates to:
  /// **'心臟與心肺'**
  String get activityMetricGroupHeart;

  /// How the activity page groups its health metrics, following Apple Health. (ActivityMetricGroup.mobility)
  ///
  /// In zh, this message translates to:
  /// **'行動能力'**
  String get activityMetricGroupMobility;

  /// How the activity page groups its health metrics, following Apple Health. (ActivityMetricGroup.running)
  ///
  /// In zh, this message translates to:
  /// **'跑步'**
  String get activityMetricGroupRunning;

  /// How the activity page groups its health metrics, following Apple Health. (ActivityMetricGroup.cycling)
  ///
  /// In zh, this message translates to:
  /// **'騎車'**
  String get activityMetricGroupCycling;

  /// How the activity page groups its health metrics, following Apple Health. (ActivityMetricGroup.swimmingWheelchair)
  ///
  /// In zh, this message translates to:
  /// **'游泳與輪椅'**
  String get activityMetricGroupSwimmingWheelchair;

  /// A movement or fitness figure from a health platform. (ActivityMetric.steps)
  ///
  /// In zh, this message translates to:
  /// **'步數'**
  String get activityMetricSteps;

  /// A movement or fitness figure from a health platform. (ActivityMetric.distance)
  ///
  /// In zh, this message translates to:
  /// **'距離'**
  String get activityMetricDistance;

  /// A movement or fitness figure from a health platform. (ActivityMetric.activeEnergy)
  ///
  /// In zh, this message translates to:
  /// **'動態能量'**
  String get activityMetricActiveEnergy;

  /// A movement or fitness figure from a health platform. (ActivityMetric.basalEnergy)
  ///
  /// In zh, this message translates to:
  /// **'靜止能量'**
  String get activityMetricBasalEnergy;

  /// A movement or fitness figure from a health platform. (ActivityMetric.exerciseTime)
  ///
  /// In zh, this message translates to:
  /// **'運動時間'**
  String get activityMetricExerciseTime;

  /// A movement or fitness figure from a health platform. (ActivityMetric.standTime)
  ///
  /// In zh, this message translates to:
  /// **'站立時間'**
  String get activityMetricStandTime;

  /// A movement or fitness figure from a health platform. (ActivityMetric.floors)
  ///
  /// In zh, this message translates to:
  /// **'爬樓'**
  String get activityMetricFloors;

  /// A movement or fitness figure from a health platform. (ActivityMetric.elevationGained)
  ///
  /// In zh, this message translates to:
  /// **'爬升高度'**
  String get activityMetricElevationGained;

  /// A movement or fitness figure from a health platform. (ActivityMetric.timeInDaylight)
  ///
  /// In zh, this message translates to:
  /// **'日光時間'**
  String get activityMetricTimeInDaylight;

  /// A movement or fitness figure from a health platform. (ActivityMetric.heartRate)
  ///
  /// In zh, this message translates to:
  /// **'平均心率'**
  String get activityMetricHeartRate;

  /// A movement or fitness figure from a health platform. (ActivityMetric.restingHeartRate)
  ///
  /// In zh, this message translates to:
  /// **'靜止心率'**
  String get activityMetricRestingHeartRate;

  /// A movement or fitness figure from a health platform. (ActivityMetric.walkingHeartRate)
  ///
  /// In zh, this message translates to:
  /// **'步行平均心率'**
  String get activityMetricWalkingHeartRate;

  /// A movement or fitness figure from a health platform. (ActivityMetric.hrvSdnn)
  ///
  /// In zh, this message translates to:
  /// **'心率變異度（SDNN）'**
  String get activityMetricHrvSdnn;

  /// A movement or fitness figure from a health platform. (ActivityMetric.hrvRmssd)
  ///
  /// In zh, this message translates to:
  /// **'心率變異度（RMSSD）'**
  String get activityMetricHrvRmssd;

  /// A movement or fitness figure from a health platform. (ActivityMetric.heartRateRecovery)
  ///
  /// In zh, this message translates to:
  /// **'一分鐘心率恢復'**
  String get activityMetricHeartRateRecovery;

  /// A movement or fitness figure from a health platform. (ActivityMetric.vo2Max)
  ///
  /// In zh, this message translates to:
  /// **'最大攝氧量'**
  String get activityMetricVo2Max;

  /// A movement or fitness figure from a health platform. (ActivityMetric.physicalEffort)
  ///
  /// In zh, this message translates to:
  /// **'身體耗力'**
  String get activityMetricPhysicalEffort;

  /// A movement or fitness figure from a health platform. (ActivityMetric.walkingSpeed)
  ///
  /// In zh, this message translates to:
  /// **'步行速度'**
  String get activityMetricWalkingSpeed;

  /// A movement or fitness figure from a health platform. (ActivityMetric.walkingStepLength)
  ///
  /// In zh, this message translates to:
  /// **'步長'**
  String get activityMetricWalkingStepLength;

  /// A movement or fitness figure from a health platform. (ActivityMetric.walkingAsymmetry)
  ///
  /// In zh, this message translates to:
  /// **'步行不對稱'**
  String get activityMetricWalkingAsymmetry;

  /// A movement or fitness figure from a health platform. (ActivityMetric.doubleSupport)
  ///
  /// In zh, this message translates to:
  /// **'雙腳支撐時間'**
  String get activityMetricDoubleSupport;

  /// A movement or fitness figure from a health platform. (ActivityMetric.walkingSteadiness)
  ///
  /// In zh, this message translates to:
  /// **'步行穩定度'**
  String get activityMetricWalkingSteadiness;

  /// A movement or fitness figure from a health platform. (ActivityMetric.stairAscentSpeed)
  ///
  /// In zh, this message translates to:
  /// **'上樓速度'**
  String get activityMetricStairAscentSpeed;

  /// A movement or fitness figure from a health platform. (ActivityMetric.stairDescentSpeed)
  ///
  /// In zh, this message translates to:
  /// **'下樓速度'**
  String get activityMetricStairDescentSpeed;

  /// A movement or fitness figure from a health platform. (ActivityMetric.sixMinuteWalk)
  ///
  /// In zh, this message translates to:
  /// **'六分鐘步行距離'**
  String get activityMetricSixMinuteWalk;

  /// A movement or fitness figure from a health platform. (ActivityMetric.runningSpeed)
  ///
  /// In zh, this message translates to:
  /// **'跑步速度'**
  String get activityMetricRunningSpeed;

  /// A movement or fitness figure from a health platform. (ActivityMetric.runningPower)
  ///
  /// In zh, this message translates to:
  /// **'跑步功率'**
  String get activityMetricRunningPower;

  /// A movement or fitness figure from a health platform. (ActivityMetric.runningStrideLength)
  ///
  /// In zh, this message translates to:
  /// **'跑步步幅'**
  String get activityMetricRunningStrideLength;

  /// A movement or fitness figure from a health platform. (ActivityMetric.groundContactTime)
  ///
  /// In zh, this message translates to:
  /// **'觸地時間'**
  String get activityMetricGroundContactTime;

  /// A movement or fitness figure from a health platform. (ActivityMetric.verticalOscillation)
  ///
  /// In zh, this message translates to:
  /// **'垂直振幅'**
  String get activityMetricVerticalOscillation;

  /// A movement or fitness figure from a health platform. (ActivityMetric.cyclingDistance)
  ///
  /// In zh, this message translates to:
  /// **'騎車距離'**
  String get activityMetricCyclingDistance;

  /// A movement or fitness figure from a health platform. (ActivityMetric.cyclingSpeed)
  ///
  /// In zh, this message translates to:
  /// **'騎車速度'**
  String get activityMetricCyclingSpeed;

  /// A movement or fitness figure from a health platform. (ActivityMetric.cyclingPower)
  ///
  /// In zh, this message translates to:
  /// **'騎車功率'**
  String get activityMetricCyclingPower;

  /// A movement or fitness figure from a health platform. (ActivityMetric.cyclingCadence)
  ///
  /// In zh, this message translates to:
  /// **'踏頻'**
  String get activityMetricCyclingCadence;

  /// A movement or fitness figure from a health platform. (ActivityMetric.functionalThresholdPower)
  ///
  /// In zh, this message translates to:
  /// **'功能性閾值功率'**
  String get activityMetricFunctionalThresholdPower;

  /// A movement or fitness figure from a health platform. (ActivityMetric.swimmingDistance)
  ///
  /// In zh, this message translates to:
  /// **'游泳距離'**
  String get activityMetricSwimmingDistance;

  /// A movement or fitness figure from a health platform. (ActivityMetric.swimmingStrokes)
  ///
  /// In zh, this message translates to:
  /// **'划水次數'**
  String get activityMetricSwimmingStrokes;

  /// A movement or fitness figure from a health platform. (ActivityMetric.wheelchairPushes)
  ///
  /// In zh, this message translates to:
  /// **'輪椅推動'**
  String get activityMetricWheelchairPushes;

  /// A movement or fitness figure from a health platform. (ActivityMetric.wheelchairDistance)
  ///
  /// In zh, this message translates to:
  /// **'輪椅距離'**
  String get activityMetricWheelchairDistance;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.steps)
  ///
  /// In zh, this message translates to:
  /// **'步'**
  String get activityMetricUnitSteps;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.distance)
  ///
  /// In zh, this message translates to:
  /// **'km'**
  String get activityMetricUnitDistance;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.activeEnergy)
  ///
  /// In zh, this message translates to:
  /// **'kcal'**
  String get activityMetricUnitActiveEnergy;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.basalEnergy)
  ///
  /// In zh, this message translates to:
  /// **'kcal'**
  String get activityMetricUnitBasalEnergy;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.exerciseTime)
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get activityMetricUnitExerciseTime;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.standTime)
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get activityMetricUnitStandTime;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.floors)
  ///
  /// In zh, this message translates to:
  /// **'層'**
  String get activityMetricUnitFloors;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.elevationGained)
  ///
  /// In zh, this message translates to:
  /// **'m'**
  String get activityMetricUnitElevationGained;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.timeInDaylight)
  ///
  /// In zh, this message translates to:
  /// **'分'**
  String get activityMetricUnitTimeInDaylight;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.heartRate)
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get activityMetricUnitHeartRate;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.restingHeartRate)
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get activityMetricUnitRestingHeartRate;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.walkingHeartRate)
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get activityMetricUnitWalkingHeartRate;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.hrvSdnn)
  ///
  /// In zh, this message translates to:
  /// **'ms'**
  String get activityMetricUnitHrvSdnn;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.hrvRmssd)
  ///
  /// In zh, this message translates to:
  /// **'ms'**
  String get activityMetricUnitHrvRmssd;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.heartRateRecovery)
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get activityMetricUnitHeartRateRecovery;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.vo2Max)
  ///
  /// In zh, this message translates to:
  /// **'mL/kg/min'**
  String get activityMetricUnitVo2Max;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.physicalEffort)
  ///
  /// In zh, this message translates to:
  /// **'MET'**
  String get activityMetricUnitPhysicalEffort;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.walkingSpeed)
  ///
  /// In zh, this message translates to:
  /// **'km/h'**
  String get activityMetricUnitWalkingSpeed;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.walkingStepLength)
  ///
  /// In zh, this message translates to:
  /// **'cm'**
  String get activityMetricUnitWalkingStepLength;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.walkingAsymmetry)
  ///
  /// In zh, this message translates to:
  /// **'%'**
  String get activityMetricUnitWalkingAsymmetry;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.doubleSupport)
  ///
  /// In zh, this message translates to:
  /// **'%'**
  String get activityMetricUnitDoubleSupport;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.walkingSteadiness)
  ///
  /// In zh, this message translates to:
  /// **'%'**
  String get activityMetricUnitWalkingSteadiness;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.stairAscentSpeed)
  ///
  /// In zh, this message translates to:
  /// **'m/s'**
  String get activityMetricUnitStairAscentSpeed;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.stairDescentSpeed)
  ///
  /// In zh, this message translates to:
  /// **'m/s'**
  String get activityMetricUnitStairDescentSpeed;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.sixMinuteWalk)
  ///
  /// In zh, this message translates to:
  /// **'m'**
  String get activityMetricUnitSixMinuteWalk;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.runningSpeed)
  ///
  /// In zh, this message translates to:
  /// **'km/h'**
  String get activityMetricUnitRunningSpeed;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.runningPower)
  ///
  /// In zh, this message translates to:
  /// **'W'**
  String get activityMetricUnitRunningPower;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.runningStrideLength)
  ///
  /// In zh, this message translates to:
  /// **'m'**
  String get activityMetricUnitRunningStrideLength;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.groundContactTime)
  ///
  /// In zh, this message translates to:
  /// **'ms'**
  String get activityMetricUnitGroundContactTime;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.verticalOscillation)
  ///
  /// In zh, this message translates to:
  /// **'cm'**
  String get activityMetricUnitVerticalOscillation;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.cyclingDistance)
  ///
  /// In zh, this message translates to:
  /// **'km'**
  String get activityMetricUnitCyclingDistance;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.cyclingSpeed)
  ///
  /// In zh, this message translates to:
  /// **'km/h'**
  String get activityMetricUnitCyclingSpeed;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.cyclingPower)
  ///
  /// In zh, this message translates to:
  /// **'W'**
  String get activityMetricUnitCyclingPower;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.cyclingCadence)
  ///
  /// In zh, this message translates to:
  /// **'rpm'**
  String get activityMetricUnitCyclingCadence;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.functionalThresholdPower)
  ///
  /// In zh, this message translates to:
  /// **'W'**
  String get activityMetricUnitFunctionalThresholdPower;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.swimmingDistance)
  ///
  /// In zh, this message translates to:
  /// **'m'**
  String get activityMetricUnitSwimmingDistance;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.swimmingStrokes)
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get activityMetricUnitSwimmingStrokes;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.wheelchairPushes)
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get activityMetricUnitWheelchairPushes;

  /// The unit an activity metric is shown in; symbols stay as they are. (ActivityMetric.wheelchairDistance)
  ///
  /// In zh, this message translates to:
  /// **'km'**
  String get activityMetricUnitWheelchairDistance;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'跑步'**
  String get activityTypeRunning;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'健走'**
  String get activityTypeWalking;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'健行'**
  String get activityTypeHiking;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'騎自行車'**
  String get activityTypeCycling;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'游泳'**
  String get activityTypeSwimming;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'划船機'**
  String get activityTypeRowing;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'橢圓機'**
  String get activityTypeElliptical;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'爬樓梯'**
  String get activityTypeStairs;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'籃球'**
  String get activityTypeBasketball;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'羽球'**
  String get activityTypeBadminton;

  /// An activity type.
  ///
  /// In zh, this message translates to:
  /// **'瑜伽'**
  String get activityTypeYoga;

  /// An activity type for anything not listed.
  ///
  /// In zh, this message translates to:
  /// **'其他運動'**
  String get activityTypeOther;

  /// A length of time in whole minutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分'**
  String durationMinutes({required int minutes});

  /// A figure charted over the course of an activity. (ActivitySeries.heartRate)
  ///
  /// In zh, this message translates to:
  /// **'心率'**
  String get activitySeriesHeartRate;

  /// A figure charted over the course of an activity. (ActivitySeries.speed)
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get activitySeriesSpeed;

  /// A figure charted over the course of an activity. (ActivitySeries.power)
  ///
  /// In zh, this message translates to:
  /// **'功率'**
  String get activitySeriesPower;

  /// A figure charted over the course of an activity. (ActivitySeries.cadence)
  ///
  /// In zh, this message translates to:
  /// **'踏頻'**
  String get activitySeriesCadence;

  /// A figure charted over the course of an activity. (ActivitySeries.strideLength)
  ///
  /// In zh, this message translates to:
  /// **'步幅'**
  String get activitySeriesStrideLength;

  /// A figure charted over the course of an activity. (ActivitySeries.groundContactTime)
  ///
  /// In zh, this message translates to:
  /// **'觸地時間'**
  String get activitySeriesGroundContactTime;

  /// A figure charted over the course of an activity. (ActivitySeries.verticalOscillation)
  ///
  /// In zh, this message translates to:
  /// **'垂直振幅'**
  String get activitySeriesVerticalOscillation;

  /// A figure charted over the course of an activity. (ActivitySeries.altitude)
  ///
  /// In zh, this message translates to:
  /// **'高度'**
  String get activitySeriesAltitude;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.heartRate)
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get activitySeriesUnitHeartRate;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.speed)
  ///
  /// In zh, this message translates to:
  /// **'km/h'**
  String get activitySeriesUnitSpeed;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.power)
  ///
  /// In zh, this message translates to:
  /// **'W'**
  String get activitySeriesUnitPower;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.cadence)
  ///
  /// In zh, this message translates to:
  /// **'rpm'**
  String get activitySeriesUnitCadence;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.strideLength)
  ///
  /// In zh, this message translates to:
  /// **'m'**
  String get activitySeriesUnitStrideLength;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.groundContactTime)
  ///
  /// In zh, this message translates to:
  /// **'ms'**
  String get activitySeriesUnitGroundContactTime;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.verticalOscillation)
  ///
  /// In zh, this message translates to:
  /// **'cm'**
  String get activitySeriesUnitVerticalOscillation;

  /// The unit a charted activity figure is shown in; symbols stay as they are. (ActivitySeries.altitude)
  ///
  /// In zh, this message translates to:
  /// **'m'**
  String get activitySeriesUnitAltitude;

  /// Heart rate unit, beats a minute.
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get unitBpm;

  /// Undo toast after an activity was deleted; activity is its type.
  ///
  /// In zh, this message translates to:
  /// **'已刪除{activity}'**
  String activityDeleted({required String activity});

  /// Shown on a record's page once it is gone.
  ///
  /// In zh, this message translates to:
  /// **'這筆紀錄已經刪除。'**
  String get recordDeletedNotice;

  /// Opens an activity's route on a map.
  ///
  /// In zh, this message translates to:
  /// **'路線地圖'**
  String get activityRouteMap;

  /// Error: an activity's detail could not be read from the health platform.
  ///
  /// In zh, this message translates to:
  /// **'無法讀取健康資料的詳細紀錄。'**
  String get healthDetailUnreadable;

  /// Section of an activity's figures.
  ///
  /// In zh, this message translates to:
  /// **'詳細資料'**
  String get activityDetailsSection;

  /// Section of per-kilometre splits.
  ///
  /// In zh, this message translates to:
  /// **'分段 · 每 1 km'**
  String get activitySplitsSection;

  /// Section of heart rate in the minutes after an activity.
  ///
  /// In zh, this message translates to:
  /// **'運動後心率'**
  String get activityRecoverySection;

  /// Time per kilometre.
  ///
  /// In zh, this message translates to:
  /// **'配速'**
  String get activityPace;

  /// Section holding the user's note on a record.
  ///
  /// In zh, this message translates to:
  /// **'備註'**
  String get notesSection;

  /// Section of actions on an item.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get manageSection;

  /// Opens an activity to correct it.
  ///
  /// In zh, this message translates to:
  /// **'編輯內容'**
  String get activityEdit;

  /// What editing an activity covers.
  ///
  /// In zh, this message translates to:
  /// **'類型、時間、時長'**
  String get activityEditDetail;

  /// Deletes the record this page shows.
  ///
  /// In zh, this message translates to:
  /// **'刪除這筆紀錄'**
  String get recordDelete;

  /// Deletes a whole body composition measurement: its weight and every figure.
  ///
  /// In zh, this message translates to:
  /// **'刪除這次量測'**
  String get deleteMeasurement;

  /// Time spent moving in an activity.
  ///
  /// In zh, this message translates to:
  /// **'運動時間'**
  String get activityActiveTime;

  /// An activity's distance.
  ///
  /// In zh, this message translates to:
  /// **'距離'**
  String get activityDistance;

  /// Active plus resting energy of an activity.
  ///
  /// In zh, this message translates to:
  /// **'總能量'**
  String get activityTotalEnergy;

  /// Height climbed in an activity.
  ///
  /// In zh, this message translates to:
  /// **'爬升'**
  String get activityClimb;

  /// An activity's average pace.
  ///
  /// In zh, this message translates to:
  /// **'平均配速'**
  String get activityAveragePace;

  /// An activity's average speed.
  ///
  /// In zh, this message translates to:
  /// **'平均速度'**
  String get activityAverageSpeed;

  /// Highest heart rate in an activity.
  ///
  /// In zh, this message translates to:
  /// **'最高心率'**
  String get activityMaxHeartRate;

  /// An activity's average power.
  ///
  /// In zh, this message translates to:
  /// **'平均功率'**
  String get activityAveragePower;

  /// An activity's average cadence.
  ///
  /// In zh, this message translates to:
  /// **'平均踏頻'**
  String get activityAverageCadence;

  /// How hard an activity felt, out of 10.
  ///
  /// In zh, this message translates to:
  /// **'費力程度'**
  String get activityEffort;

  /// Effort the platform estimated rather than the user rated.
  ///
  /// In zh, this message translates to:
  /// **'費力程度（估計）'**
  String get activityEffortEstimated;

  /// An activity type done indoors.
  ///
  /// In zh, this message translates to:
  /// **'{activity}（室內）'**
  String activityIndoor({required String activity});

  /// An activity type done outdoors.
  ///
  /// In zh, this message translates to:
  /// **'{activity}（戶外）'**
  String activityOutdoor({required String activity});

  /// The temperature during an activity.
  ///
  /// In zh, this message translates to:
  /// **'天氣'**
  String get weatherLabel;

  /// The humidity during an activity.
  ///
  /// In zh, this message translates to:
  /// **'濕度'**
  String get humidityLabel;

  /// Column of each split's time.
  ///
  /// In zh, this message translates to:
  /// **'時間'**
  String get splitTime;

  /// A chart's average; value is formatted with its unit.
  ///
  /// In zh, this message translates to:
  /// **'平均 {value}'**
  String statAverage({required String value});

  /// A heart rate zone.
  ///
  /// In zh, this message translates to:
  /// **'區間 {number}'**
  String heartZone({required int number});

  /// How the zones were worked out.
  ///
  /// In zh, this message translates to:
  /// **'依儲備心率估計'**
  String get heartZonesByReserve;

  /// How the zones were worked out.
  ///
  /// In zh, this message translates to:
  /// **'依年齡估計最大心率'**
  String get heartZonesByAge;

  /// The zones are the app's own, not the platform's.
  ///
  /// In zh, this message translates to:
  /// **'本 App 的區間'**
  String get heartZonesOwn;

  /// Heart rate at the moment an activity ended.
  ///
  /// In zh, this message translates to:
  /// **'結束時'**
  String get recoveryAtEnd;

  /// Heart rate some minutes after the end.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分後'**
  String recoveryAfter({required int minutes});

  /// The window the recovery chart covers; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{time} 起 3 分鐘'**
  String recoveryWindow({required String time});

  /// Log row for a weighing; weight is formatted with its unit.
  ///
  /// In zh, this message translates to:
  /// **'體重 {weight}'**
  String timelineWeight({required String weight});

  /// A night's rated sleep quality.
  ///
  /// In zh, this message translates to:
  /// **'品質 {score} / 5'**
  String sleepQualityScore({required int score});

  /// A record's note quoted in the log.
  ///
  /// In zh, this message translates to:
  /// **'備註：{note}'**
  String noteLine({required String note});

  /// A number of sets.
  ///
  /// In zh, this message translates to:
  /// **'{count} 組'**
  String setsCount({required int count});

  /// Log row tag naming the personal record a workout set; weight is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{exercise} {weight} kg × {reps} 為個人紀錄'**
  String personalRecordLine({
    required String exercise,
    required String weight,
    required int reps,
  });

  /// How hard an activity felt, out of 10.
  ///
  /// In zh, this message translates to:
  /// **'強度 {effort} / 10'**
  String effortOutOfTen({required int effort});

  /// A number of activity sessions in a day.
  ///
  /// In zh, this message translates to:
  /// **'{count} 場'**
  String activitiesCount({required int count});

  /// A number of items in a meal.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項'**
  String itemsCount({required int count});

  /// A number of meals in a day.
  ///
  /// In zh, this message translates to:
  /// **'{count} 餐'**
  String mealsCount({required int count});

  /// Log warning on a past day with too few meals logged.
  ///
  /// In zh, this message translates to:
  /// **'有未記錄的餐'**
  String get foodLogIncomplete;

  /// The log's heading for today; date is formatted.
  ///
  /// In zh, this message translates to:
  /// **'今天 · {date}'**
  String todayWithDate({required String date});

  /// A routine never completed.
  ///
  /// In zh, this message translates to:
  /// **'未完成過'**
  String get routineNeverDone;

  /// When a routine was last completed; date is formatted.
  ///
  /// In zh, this message translates to:
  /// **'上次 {date} 完成'**
  String routineLastDone({required String date});

  /// An exercise's last set; weight is formatted.
  ///
  /// In zh, this message translates to:
  /// **'上次 {weight} kg × {reps}'**
  String exerciseLastSet({required String weight, required int reps});

  /// A form section that may be left empty; field is its name.
  ///
  /// In zh, this message translates to:
  /// **'{field}（選填）'**
  String optionalField({required String field});

  /// Warning: timing an activity cannot start while a workout runs.
  ///
  /// In zh, this message translates to:
  /// **'訓練進行中，先結束訓練才能開始運動'**
  String get workoutBlocksActivity;

  /// Form error on an activity's duration.
  ///
  /// In zh, this message translates to:
  /// **'時長請介於 {min} – {max} 分鐘。'**
  String activityDurationRange({required int min, required int max});

  /// Form error on an activity's distance.
  ///
  /// In zh, this message translates to:
  /// **'距離請輸入 0 – {max} km 之間。'**
  String activityDistanceRange({required int max});

  /// Form error on an activity's elevation gain.
  ///
  /// In zh, this message translates to:
  /// **'爬升請輸入 0 – {max} m 之間。'**
  String activityClimbRange({required int max});

  /// Toast after an activity was logged.
  ///
  /// In zh, this message translates to:
  /// **'已記錄{activity} {minutes} 分'**
  String activityLogged({required String activity, required int minutes});

  /// Toast after an activity was corrected.
  ///
  /// In zh, this message translates to:
  /// **'已更新{activity}'**
  String activityUpdated({required String activity});

  /// Page logging an activity after the fact.
  ///
  /// In zh, this message translates to:
  /// **'記錄運動'**
  String get activityRecordTitle;

  /// Page correcting a logged activity.
  ///
  /// In zh, this message translates to:
  /// **'編輯運動'**
  String get activityEditTitle;

  /// Row choosing what kind of activity.
  ///
  /// In zh, this message translates to:
  /// **'運動類型'**
  String get activityTypeRow;

  /// Row starting a live timer instead of logging after.
  ///
  /// In zh, this message translates to:
  /// **'現在開始計時'**
  String get activityStartTimer;

  /// What timing live means.
  ///
  /// In zh, this message translates to:
  /// **'邊做邊計時，距離與強度結束後再補'**
  String get activityStartTimerDetail;

  /// When an activity started.
  ///
  /// In zh, this message translates to:
  /// **'開始時間'**
  String get activityStartTime;

  /// How long an activity lasted.
  ///
  /// In zh, this message translates to:
  /// **'時長'**
  String get activityDurationSection;

  /// Unit beside a minutes field.
  ///
  /// In zh, this message translates to:
  /// **'分鐘'**
  String get minutesUnit;

  /// When an activity ends, from its start and duration; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'結束 {time}'**
  String activityEndsAt({required String time});

  /// An activity's pace; pace is formatted as m:ss.
  ///
  /// In zh, this message translates to:
  /// **'配速 {pace} /km'**
  String activityPaceValue({required String pace});

  /// How hard an activity felt, 1 to 10.
  ///
  /// In zh, this message translates to:
  /// **'強度'**
  String get effortSection;

  /// What the effort scale's ends mean.
  ///
  /// In zh, this message translates to:
  /// **'1 很輕鬆、10 拼盡全力。'**
  String get effortScaleHint;

  /// Placeholder of an activity's note.
  ///
  /// In zh, this message translates to:
  /// **'例如：河濱，風很大'**
  String get activityNoteHint;

  /// Page picking an activity type.
  ///
  /// In zh, this message translates to:
  /// **'選擇運動'**
  String get activityPickTitle;

  /// Section of recently used choices.
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get recentlyUsed;

  /// Section of common choices.
  ///
  /// In zh, this message translates to:
  /// **'常用'**
  String get commonlyUsed;

  /// Section listing every activity type.
  ///
  /// In zh, this message translates to:
  /// **'所有運動'**
  String get activityAllTypes;

  /// Shown on the live page once the activity is over.
  ///
  /// In zh, this message translates to:
  /// **'這次運動已經結束。'**
  String get activityEnded;

  /// A live session is running.
  ///
  /// In zh, this message translates to:
  /// **'進行中'**
  String get sessionInProgress;

  /// Ends a running session.
  ///
  /// In zh, this message translates to:
  /// **'結束'**
  String get commonEnd;

  /// Resumes a paused session.
  ///
  /// In zh, this message translates to:
  /// **'繼續'**
  String get commonResume;

  /// Pauses a running session.
  ///
  /// In zh, this message translates to:
  /// **'暫停'**
  String get commonPause;

  /// Chart range: one day.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get chartRangeDay;

  /// Chart range: one week.
  ///
  /// In zh, this message translates to:
  /// **'週'**
  String get chartRangeWeek;

  /// Chart range: one month.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get chartRangeMonth;

  /// Chart range: six months.
  ///
  /// In zh, this message translates to:
  /// **'半年'**
  String get chartRangeHalfYear;

  /// Chart range: one year.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get chartRangeYear;

  /// Steps back a day.
  ///
  /// In zh, this message translates to:
  /// **'前一天'**
  String get previousDay;

  /// Steps forward a day.
  ///
  /// In zh, this message translates to:
  /// **'後一天'**
  String get nextDay;

  /// Row naming what was recorded.
  ///
  /// In zh, this message translates to:
  /// **'紀錄'**
  String get entriesRow;

  /// Nothing recorded for this.
  ///
  /// In zh, this message translates to:
  /// **'沒有資料'**
  String get noData;

  /// The figure for the day shown.
  ///
  /// In zh, this message translates to:
  /// **'這一天'**
  String get thisDay;

  /// Average of the days with a reading.
  ///
  /// In zh, this message translates to:
  /// **'每日平均'**
  String get dailyAverage;

  /// The range a figure usually falls in.
  ///
  /// In zh, this message translates to:
  /// **'平常範圍'**
  String get usualRange;

  /// How many days had a reading.
  ///
  /// In zh, this message translates to:
  /// **'紀錄天數'**
  String get daysRecorded;

  /// A number of days.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天'**
  String daysCount({required int count});

  /// A week in a long chart, by its first day; date is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{date}起一週'**
  String weekOf({required String date});

  /// A number of readings or entries.
  ///
  /// In zh, this message translates to:
  /// **'{count} 筆'**
  String readingsCount({required int count});

  /// A chart of daily totals.
  ///
  /// In zh, this message translates to:
  /// **'每日'**
  String get perDay;

  /// A day's movement from the health platform.
  ///
  /// In zh, this message translates to:
  /// **'活動'**
  String get dailyActivityTitle;

  /// Empty state: no health platform activity has come in.
  ///
  /// In zh, this message translates to:
  /// **'沒有活動資料'**
  String get noActivityData;

  /// Opens where the app's data comes from.
  ///
  /// In zh, this message translates to:
  /// **'資料來源'**
  String get dataSourcesLink;

  /// Empty state for a day without activity data.
  ///
  /// In zh, this message translates to:
  /// **'這一天沒有活動資料'**
  String get noActivityThisDay;

  /// A metric's usual range; range is formatted with its unit.
  ///
  /// In zh, this message translates to:
  /// **'平常 {range}'**
  String usualRangeValue({required String range});

  /// A chart of hourly totals.
  ///
  /// In zh, this message translates to:
  /// **'每小時'**
  String get perHour;

  /// An hour of the day on a chart.
  ///
  /// In zh, this message translates to:
  /// **'{start}–{end} 時'**
  String hourSpan({required int start, required int end});

  /// An hour mark on a chart's axis.
  ///
  /// In zh, this message translates to:
  /// **'{hour} 時'**
  String hourOfDay({required int hour});

  /// Where on the body a tape measure went. (MeasurementSite.waist)
  ///
  /// In zh, this message translates to:
  /// **'腰圍'**
  String get measurementSiteWaist;

  /// Where on the body a tape measure went. (MeasurementSite.hips)
  ///
  /// In zh, this message translates to:
  /// **'臀圍'**
  String get measurementSiteHips;

  /// Where on the body a tape measure went. (MeasurementSite.chest)
  ///
  /// In zh, this message translates to:
  /// **'胸圍'**
  String get measurementSiteChest;

  /// Where on the body a tape measure went. (MeasurementSite.arm)
  ///
  /// In zh, this message translates to:
  /// **'上臂'**
  String get measurementSiteArm;

  /// Where on the body a tape measure went. (MeasurementSite.thigh)
  ///
  /// In zh, this message translates to:
  /// **'大腿'**
  String get measurementSiteThigh;

  /// Where on the body a tape measure went. (MeasurementSite.calf)
  ///
  /// In zh, this message translates to:
  /// **'小腿'**
  String get measurementSiteCalf;

  /// Where on the body a tape measure went. (MeasurementSite.neck)
  ///
  /// In zh, this message translates to:
  /// **'頸圍'**
  String get measurementSiteNeck;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.height)
  ///
  /// In zh, this message translates to:
  /// **'身高'**
  String get bodyMetricHeight;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.bodyFat)
  ///
  /// In zh, this message translates to:
  /// **'體脂率'**
  String get bodyMetricBodyFat;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.skeletalMuscle)
  ///
  /// In zh, this message translates to:
  /// **'骨骼肌'**
  String get bodyMetricSkeletalMuscle;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.muscleMass)
  ///
  /// In zh, this message translates to:
  /// **'肌肉量'**
  String get bodyMetricMuscleMass;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.leanMass)
  ///
  /// In zh, this message translates to:
  /// **'除脂體重'**
  String get bodyMetricLeanMass;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.visceralFat)
  ///
  /// In zh, this message translates to:
  /// **'內臟脂肪'**
  String get bodyMetricVisceralFat;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.bodyWater)
  ///
  /// In zh, this message translates to:
  /// **'體水分'**
  String get bodyMetricBodyWater;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.boneMass)
  ///
  /// In zh, this message translates to:
  /// **'骨量'**
  String get bodyMetricBoneMass;

  /// A body figure, typed in or from a body composition scale. (BodyMetric.basalMetabolicRate)
  ///
  /// In zh, this message translates to:
  /// **'基礎代謝'**
  String get bodyMetricBasalMetabolicRate;

  /// The user's sex, for energy and targets. (Sex.female)
  ///
  /// In zh, this message translates to:
  /// **'女性'**
  String get sexFemale;

  /// The user's sex, for energy and targets. (Sex.male)
  ///
  /// In zh, this message translates to:
  /// **'男性'**
  String get sexMale;

  /// Whether a sleep was the night's or a nap. (SleepKind.night)
  ///
  /// In zh, this message translates to:
  /// **'睡眠'**
  String get sleepKindNight;

  /// Whether a sleep was the night's or a nap. (SleepKind.nap)
  ///
  /// In zh, this message translates to:
  /// **'小睡'**
  String get sleepKindNap;

  /// Which length of a sleep a figure counts. (SleepMeasure.asleep)
  ///
  /// In zh, this message translates to:
  /// **'睡著時間'**
  String get sleepMeasureAsleep;

  /// Which length of a sleep a figure counts. (SleepMeasure.inBed)
  ///
  /// In zh, this message translates to:
  /// **'在床時間'**
  String get sleepMeasureInBed;

  /// A stretch of a sleep record. (SleepStage.inBed)
  ///
  /// In zh, this message translates to:
  /// **'在床'**
  String get sleepStageInBed;

  /// A stretch of a sleep record. (SleepStage.awake)
  ///
  /// In zh, this message translates to:
  /// **'清醒'**
  String get sleepStageAwake;

  /// A stretch of a sleep record. (SleepStage.asleep)
  ///
  /// In zh, this message translates to:
  /// **'睡著'**
  String get sleepStageAsleep;

  /// A stretch of a sleep record. (SleepStage.core)
  ///
  /// In zh, this message translates to:
  /// **'淺層／核心'**
  String get sleepStageCore;

  /// A stretch of a sleep record. (SleepStage.deep)
  ///
  /// In zh, this message translates to:
  /// **'深層'**
  String get sleepStageDeep;

  /// A stretch of a sleep record. (SleepStage.rem)
  ///
  /// In zh, this message translates to:
  /// **'REM'**
  String get sleepStageRem;

  /// A reading taken overnight during a sleep. (OvernightMeasure.heartRate)
  ///
  /// In zh, this message translates to:
  /// **'心率'**
  String get overnightMeasureHeartRate;

  /// A reading taken overnight during a sleep. (OvernightMeasure.respiratoryRate)
  ///
  /// In zh, this message translates to:
  /// **'呼吸速率'**
  String get overnightMeasureRespiratoryRate;

  /// A reading taken overnight during a sleep. (OvernightMeasure.oxygenSaturation)
  ///
  /// In zh, this message translates to:
  /// **'血氧'**
  String get overnightMeasureOxygenSaturation;

  /// A reading taken overnight during a sleep. (OvernightMeasure.wristTemperature)
  ///
  /// In zh, this message translates to:
  /// **'手腕溫度'**
  String get overnightMeasureWristTemperature;

  /// A reading taken overnight during a sleep. (OvernightMeasure.skinTemperatureChange)
  ///
  /// In zh, this message translates to:
  /// **'皮膚溫度變化'**
  String get overnightMeasureSkinTemperatureChange;

  /// A reading taken overnight during a sleep. (OvernightMeasure.hrvSdnn)
  ///
  /// In zh, this message translates to:
  /// **'心率變異度（SDNN）'**
  String get overnightMeasureHrvSdnn;

  /// A reading taken overnight during a sleep. (OvernightMeasure.hrvRmssd)
  ///
  /// In zh, this message translates to:
  /// **'心率變異度（RMSSD）'**
  String get overnightMeasureHrvRmssd;

  /// A reading taken overnight during a sleep. (OvernightMeasure.breathingDisturbances)
  ///
  /// In zh, this message translates to:
  /// **'呼吸干擾'**
  String get overnightMeasureBreathingDisturbances;

  /// How active a day usually is, for the energy target. (ActivityLevel.sedentary)
  ///
  /// In zh, this message translates to:
  /// **'久坐'**
  String get activityLevelSedentary;

  /// How active a day usually is, for the energy target. (ActivityLevel.light)
  ///
  /// In zh, this message translates to:
  /// **'輕度'**
  String get activityLevelLight;

  /// How active a day usually is, for the energy target. (ActivityLevel.moderate)
  ///
  /// In zh, this message translates to:
  /// **'中度'**
  String get activityLevelModerate;

  /// How active a day usually is, for the energy target. (ActivityLevel.active)
  ///
  /// In zh, this message translates to:
  /// **'高度'**
  String get activityLevelActive;

  /// How active a day usually is, for the energy target. (ActivityLevel.veryActive)
  ///
  /// In zh, this message translates to:
  /// **'非常高'**
  String get activityLevelVeryActive;

  /// What the energy target is for. (WeightGoal.lose)
  ///
  /// In zh, this message translates to:
  /// **'減脂'**
  String get weightGoalLose;

  /// What the energy target is for. (WeightGoal.recomp)
  ///
  /// In zh, this message translates to:
  /// **'增肌減脂'**
  String get weightGoalRecomp;

  /// What the energy target is for. (WeightGoal.maintain)
  ///
  /// In zh, this message translates to:
  /// **'維持'**
  String get weightGoalMaintain;

  /// What the energy target is for. (WeightGoal.gain)
  ///
  /// In zh, this message translates to:
  /// **'增肌'**
  String get weightGoalGain;

  /// What working out the energy target still needs, inside a sentence. (TargetInput.weight)
  ///
  /// In zh, this message translates to:
  /// **'體重'**
  String get targetInputWeight;

  /// What working out the energy target still needs, inside a sentence. (TargetInput.height)
  ///
  /// In zh, this message translates to:
  /// **'身高'**
  String get targetInputHeight;

  /// What working out the energy target still needs, inside a sentence. (TargetInput.birthYear)
  ///
  /// In zh, this message translates to:
  /// **'出生年'**
  String get targetInputBirthYear;

  /// What working out the energy target still needs, inside a sentence. (TargetInput.sex)
  ///
  /// In zh, this message translates to:
  /// **'性別'**
  String get targetInputSex;

  /// What the app reads from a health platform. (HealthDataKind.sleep)
  ///
  /// In zh, this message translates to:
  /// **'睡眠'**
  String get healthDataSleep;

  /// What the app reads from a health platform. (HealthDataKind.weight)
  ///
  /// In zh, this message translates to:
  /// **'體重'**
  String get healthDataWeight;

  /// What the app reads from a health platform. (HealthDataKind.waist)
  ///
  /// In zh, this message translates to:
  /// **'腰圍'**
  String get healthDataWaist;

  /// What the app reads from a health platform. (HealthDataKind.body)
  ///
  /// In zh, this message translates to:
  /// **'身體組成'**
  String get healthDataBody;

  /// What the app reads from a health platform. (HealthDataKind.workouts)
  ///
  /// In zh, this message translates to:
  /// **'運動'**
  String get healthDataWorkouts;

  /// What the app reads from a health platform. (HealthDataKind.water)
  ///
  /// In zh, this message translates to:
  /// **'喝水'**
  String get healthDataWater;

  /// What the app reads from a health platform. (HealthDataKind.overnight)
  ///
  /// In zh, this message translates to:
  /// **'夜間數據'**
  String get healthDataOvernight;

  /// What the app reads from a health platform. (HealthDataKind.activity)
  ///
  /// In zh, this message translates to:
  /// **'活動與心肺'**
  String get healthDataActivity;

  /// A kind of record, as the log and calendar colour it. (RecordCategory.training)
  ///
  /// In zh, this message translates to:
  /// **'訓練'**
  String get recordCategoryTraining;

  /// A kind of record, as the log and calendar colour it. (RecordCategory.activity)
  ///
  /// In zh, this message translates to:
  /// **'運動'**
  String get recordCategoryActivity;

  /// A kind of record, as the log and calendar colour it. (RecordCategory.nutrition)
  ///
  /// In zh, this message translates to:
  /// **'飲食'**
  String get recordCategoryNutrition;

  /// A kind of record, as the log and calendar colour it. (RecordCategory.body)
  ///
  /// In zh, this message translates to:
  /// **'身體'**
  String get recordCategoryBody;

  /// A kind of record, as the log and calendar colour it. (RecordCategory.wellness)
  ///
  /// In zh, this message translates to:
  /// **'睡眠與狀態'**
  String get recordCategoryWellness;

  /// An AI provider; product names stay as they are. (AiProviderKind.appleOnDevice)
  ///
  /// In zh, this message translates to:
  /// **'Apple Intelligence'**
  String get aiProviderAppleOnDevice;

  /// An AI provider; product names stay as they are. (AiProviderKind.ollamaCloud)
  ///
  /// In zh, this message translates to:
  /// **'Ollama Cloud'**
  String get aiProviderOllamaCloud;

  /// An AI provider; product names stay as they are. (AiProviderKind.googleAiStudio)
  ///
  /// In zh, this message translates to:
  /// **'Google AI Studio'**
  String get aiProviderGoogleAiStudio;

  /// An AI provider; product names stay as they are. (AiProviderKind.anthropic)
  ///
  /// In zh, this message translates to:
  /// **'Anthropic'**
  String get aiProviderAnthropic;

  /// An AI provider; product names stay as they are. (AiProviderKind.azureAiFoundry)
  ///
  /// In zh, this message translates to:
  /// **'Azure AI Foundry'**
  String get aiProviderAzureAiFoundry;

  /// An AI provider; product names stay as they are. (AiProviderKind.microsoftCopilot)
  ///
  /// In zh, this message translates to:
  /// **'Microsoft 365 Copilot'**
  String get aiProviderMicrosoftCopilot;

  /// An AI provider; product names stay as they are. (AiProviderKind.openAiCompatible)
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 相容端點'**
  String get aiProviderOpenAiCompatible;

  /// What a check-in rates, 1 to 5. (WellnessKind.energy)
  ///
  /// In zh, this message translates to:
  /// **'精力'**
  String get wellnessKindEnergy;

  /// What a check-in rates, 1 to 5. (WellnessKind.mood)
  ///
  /// In zh, this message translates to:
  /// **'心情'**
  String get wellnessKindMood;

  /// What a check-in rates, 1 to 5. (WellnessKind.symptom)
  ///
  /// In zh, this message translates to:
  /// **'症狀'**
  String get wellnessKindSymptom;

  /// What a check-in rates, 1 to 5. (WellnessKind.sleep)
  ///
  /// In zh, this message translates to:
  /// **'睡眠品質'**
  String get wellnessKindSleep;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.height)
  ///
  /// In zh, this message translates to:
  /// **'cm'**
  String get bodyMetricUnitHeight;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.bodyFat)
  ///
  /// In zh, this message translates to:
  /// **'%'**
  String get bodyMetricUnitBodyFat;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.skeletalMuscle)
  ///
  /// In zh, this message translates to:
  /// **'kg'**
  String get bodyMetricUnitSkeletalMuscle;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.muscleMass)
  ///
  /// In zh, this message translates to:
  /// **'kg'**
  String get bodyMetricUnitMuscleMass;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.leanMass)
  ///
  /// In zh, this message translates to:
  /// **'kg'**
  String get bodyMetricUnitLeanMass;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.visceralFat)
  ///
  /// In zh, this message translates to:
  /// **'級'**
  String get bodyMetricUnitVisceralFat;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.bodyWater)
  ///
  /// In zh, this message translates to:
  /// **'%'**
  String get bodyMetricUnitBodyWater;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.boneMass)
  ///
  /// In zh, this message translates to:
  /// **'kg'**
  String get bodyMetricUnitBoneMass;

  /// The unit a body figure is shown in; symbols stay as they are. (BodyMetric.basalMetabolicRate)
  ///
  /// In zh, this message translates to:
  /// **'kcal'**
  String get bodyMetricUnitBasalMetabolicRate;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.heartRate)
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get overnightMeasureUnitHeartRate;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.respiratoryRate)
  ///
  /// In zh, this message translates to:
  /// **'次/分'**
  String get overnightMeasureUnitRespiratoryRate;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.oxygenSaturation)
  ///
  /// In zh, this message translates to:
  /// **'%'**
  String get overnightMeasureUnitOxygenSaturation;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.wristTemperature)
  ///
  /// In zh, this message translates to:
  /// **'°C'**
  String get overnightMeasureUnitWristTemperature;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.skinTemperatureChange)
  ///
  /// In zh, this message translates to:
  /// **'°C'**
  String get overnightMeasureUnitSkinTemperatureChange;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.hrvSdnn)
  ///
  /// In zh, this message translates to:
  /// **'ms'**
  String get overnightMeasureUnitHrvSdnn;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.hrvRmssd)
  ///
  /// In zh, this message translates to:
  /// **'ms'**
  String get overnightMeasureUnitHrvRmssd;

  /// The unit an overnight reading is shown in; symbols stay as they are. (OvernightMeasure.breathingDisturbances)
  ///
  /// In zh, this message translates to:
  /// **''**
  String get overnightMeasureUnitBreathingDisturbances;

  /// What an activity level means in practice. (ActivityLevel.sedentary)
  ///
  /// In zh, this message translates to:
  /// **'幾乎不運動'**
  String get activityLevelDetailSedentary;

  /// What an activity level means in practice. (ActivityLevel.light)
  ///
  /// In zh, this message translates to:
  /// **'每週運動 1–3 天'**
  String get activityLevelDetailLight;

  /// What an activity level means in practice. (ActivityLevel.moderate)
  ///
  /// In zh, this message translates to:
  /// **'每週運動 3–5 天'**
  String get activityLevelDetailModerate;

  /// What an activity level means in practice. (ActivityLevel.active)
  ///
  /// In zh, this message translates to:
  /// **'每週運動 6–7 天'**
  String get activityLevelDetailActive;

  /// What an activity level means in practice. (ActivityLevel.veryActive)
  ///
  /// In zh, this message translates to:
  /// **'體力勞動或一天兩練'**
  String get activityLevelDetailVeryActive;

  /// No AI provider is chosen.
  ///
  /// In zh, this message translates to:
  /// **'AI 未啟用'**
  String get aiOff;

  /// Sends what was written to the AI for a draft.
  ///
  /// In zh, this message translates to:
  /// **'產生草稿'**
  String get aiDraftGenerate;

  /// While the AI drafts.
  ///
  /// In zh, this message translates to:
  /// **'產生中…'**
  String get aiDrafting;

  /// Discards the draft to write the request again.
  ///
  /// In zh, this message translates to:
  /// **'重新輸入'**
  String get aiRewrite;

  /// Undo toast after a record was deleted; item names what it was.
  ///
  /// In zh, this message translates to:
  /// **'已刪除{item}'**
  String deletedItem({required String item});

  /// Title of a record's page once its kind is not known.
  ///
  /// In zh, this message translates to:
  /// **'紀錄'**
  String get recordTitle;

  /// Opens a record to change it.
  ///
  /// In zh, this message translates to:
  /// **'編輯'**
  String get commonEdit;

  /// A body figure a body composition scale estimated rather than measured.
  ///
  /// In zh, this message translates to:
  /// **'體脂計估計'**
  String get bodyScaleEstimate;

  /// A night with no quality rating.
  ///
  /// In zh, this message translates to:
  /// **'沒有評分'**
  String get notRated;

  /// A weighing against the one before; change is signed with its unit, date formatted.
  ///
  /// In zh, this message translates to:
  /// **'較上次 {change}（{date}）'**
  String weightSinceLast({required String change, required String date});

  /// Log filter showing every kind of record.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get logFilterAll;

  /// Screen reader label of the month button; month is formatted.
  ///
  /// In zh, this message translates to:
  /// **'選擇月份，目前 {month}'**
  String pickMonthCurrent({required String month});

  /// Search field of the log.
  ///
  /// In zh, this message translates to:
  /// **'搜尋紀錄'**
  String get logSearch;

  /// Jumps the log to today.
  ///
  /// In zh, this message translates to:
  /// **'回到今天'**
  String get backToToday;

  /// Switches the log to a month calendar.
  ///
  /// In zh, this message translates to:
  /// **'以月曆顯示'**
  String get showAsCalendar;

  /// Switches the log to a timeline.
  ///
  /// In zh, this message translates to:
  /// **'以時間軸顯示'**
  String get showAsTimeline;

  /// Steps back a month.
  ///
  /// In zh, this message translates to:
  /// **'上個月'**
  String get previousMonth;

  /// Steps forward a month.
  ///
  /// In zh, this message translates to:
  /// **'下個月'**
  String get nextMonth;

  /// Empty log month; month is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{month}沒有紀錄'**
  String noEntriesInMonth({required String month});

  /// No log entry matches the search.
  ///
  /// In zh, this message translates to:
  /// **'找不到符合「{query}」的紀錄。'**
  String noEntriesMatching({required String query});

  /// The calendar's chosen day has no records.
  ///
  /// In zh, this message translates to:
  /// **'這天沒有紀錄。'**
  String get noEntriesThisDay;

  /// Nothing recorded yet of this kind.
  ///
  /// In zh, this message translates to:
  /// **'沒有紀錄。'**
  String get noEntriesSentence;

  /// No import has been made.
  ///
  /// In zh, this message translates to:
  /// **'沒有匯入紀錄。'**
  String get noImports;

  /// An import that was taken back.
  ///
  /// In zh, this message translates to:
  /// **'已復原'**
  String get importUndone;

  /// A number of products in a catalogue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 款'**
  String productsCount({required int count});

  /// When a built-in catalogue's figures were last checked; date is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{catalogue}更新於 {date}'**
  String catalogueUpdated({required String catalogue, required String date});

  /// Error reading from the health platform.
  ///
  /// In zh, this message translates to:
  /// **'讀取失敗：{error}'**
  String healthReadFailed({required String error});

  /// What disconnecting from the health platform keeps.
  ///
  /// In zh, this message translates to:
  /// **'中斷連接後紀錄保留。'**
  String get healthDisconnectKeeps;

  /// Reads from the health platform now.
  ///
  /// In zh, this message translates to:
  /// **'立即讀取'**
  String get healthReadNow;

  /// Stops reading from the health platform.
  ///
  /// In zh, this message translates to:
  /// **'中斷連接'**
  String get healthDisconnect;

  /// The health platform cannot be used here.
  ///
  /// In zh, this message translates to:
  /// **'這台裝置沒有 {source}，或版本太舊。'**
  String healthUnavailable({required String source});

  /// While something is being checked.
  ///
  /// In zh, this message translates to:
  /// **'檢查中…'**
  String get checking;

  /// Reading from the health platform is on.
  ///
  /// In zh, this message translates to:
  /// **'已連接'**
  String get healthConnected;

  /// Starts reading from the health platform.
  ///
  /// In zh, this message translates to:
  /// **'連接 {source}'**
  String healthConnect({required String source});

  /// While the health platform is being read.
  ///
  /// In zh, this message translates to:
  /// **'讀取中…'**
  String get healthReading;

  /// What connecting asks for.
  ///
  /// In zh, this message translates to:
  /// **'允許讀取'**
  String get healthAllowReading;

  /// The background read from the health platform failed.
  ///
  /// In zh, this message translates to:
  /// **'上次自動讀取失敗'**
  String get healthAutoReadFailed;

  /// Short state on Today's bar: the last read of Apple Health or Health Connect failed; tapping it reads again.
  ///
  /// In zh, this message translates to:
  /// **'讀取失敗'**
  String get healthReadFailedState;

  /// Announced to a screen reader when a read the user pulled Today down for is done.
  ///
  /// In zh, this message translates to:
  /// **'讀取完成'**
  String get healthReadDone;

  /// When the health platform was last read; when is formatted.
  ///
  /// In zh, this message translates to:
  /// **'上次讀取 {when}'**
  String healthLastRead({required String when});

  /// What the app reads from the health platform; kinds is a list.
  ///
  /// In zh, this message translates to:
  /// **'讀取：{kinds}'**
  String healthReads({required String kinds});

  /// Opens the privacy page.
  ///
  /// In zh, this message translates to:
  /// **'隱私說明'**
  String get privacyLink;

  /// While the platform's permissions are checked.
  ///
  /// In zh, this message translates to:
  /// **'檢查權限中…'**
  String get checkingPermissions;

  /// Where Apple Health's permissions are changed; Apple does not tell the app.
  ///
  /// In zh, this message translates to:
  /// **'權限在「設定 > 健康 > 資料存取與裝置 > MISHIRUBE」修改。'**
  String get healthPermissionsPath;

  /// A health data type the user allowed.
  ///
  /// In zh, this message translates to:
  /// **'已允許'**
  String get permissionAllowed;

  /// A health data type the user did not allow.
  ///
  /// In zh, this message translates to:
  /// **'未允許'**
  String get permissionDenied;

  /// Asks again for the types not allowed.
  ///
  /// In zh, this message translates to:
  /// **'允許其他類別'**
  String get healthAllowOthers;

  /// Reading found no connection to the health platform.
  ///
  /// In zh, this message translates to:
  /// **'沒有連上。'**
  String get healthNotConnected;

  /// Nothing came in, and these types are not allowed.
  ///
  /// In zh, this message translates to:
  /// **'沒有讀到資料。未允許：{kinds}。'**
  String healthNothingReadDenied({required String kinds});

  /// Nothing came in, and the platform will not say what is allowed.
  ///
  /// In zh, this message translates to:
  /// **'沒有讀到資料。到系統的健康設定確認允許的類別。'**
  String get healthNothingRead;

  /// A number of nights.
  ///
  /// In zh, this message translates to:
  /// **'{count} 晚'**
  String nightsCount({required int count});

  /// A number of times.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String timesCount({required int count});

  /// A read changed nights already logged.
  ///
  /// In zh, this message translates to:
  /// **'更新 {count} 晚睡眠'**
  String healthUpdatedNights({required int count});

  /// A read left nights the user logged by hand.
  ///
  /// In zh, this message translates to:
  /// **'{count} 晚保留手動紀錄'**
  String healthKeptManual({required int count});

  /// The types the user did not allow.
  ///
  /// In zh, this message translates to:
  /// **'未允許：{kinds}'**
  String healthNotAllowedList({required String kinds});

  /// Empty state of the sleep page.
  ///
  /// In zh, this message translates to:
  /// **'沒有睡眠紀錄'**
  String get noSleepRecords;

  /// Opens a form to type a record in.
  ///
  /// In zh, this message translates to:
  /// **'手動記錄'**
  String get logByHand;

  /// The sleep owed against the goal.
  ///
  /// In zh, this message translates to:
  /// **'睡眠債'**
  String get sleepDebtSection;

  /// Section of the day's naps.
  ///
  /// In zh, this message translates to:
  /// **'小睡'**
  String get napsSection;

  /// Section of a goal's settings.
  ///
  /// In zh, this message translates to:
  /// **'目標'**
  String get goalSection;

  /// The night's stages.
  ///
  /// In zh, this message translates to:
  /// **'睡眠階段'**
  String get sleepStagesSection;

  /// The source did not record this.
  ///
  /// In zh, this message translates to:
  /// **'未提供'**
  String get notProvided;

  /// How long falling asleep took.
  ///
  /// In zh, this message translates to:
  /// **'入睡所需'**
  String get fallAsleepTime;

  /// An estimated number of minutes.
  ///
  /// In zh, this message translates to:
  /// **'約 {minutes} 分'**
  String aboutMinutes({required int minutes});

  /// Time asleep as a share of time in bed.
  ///
  /// In zh, this message translates to:
  /// **'睡眠效率'**
  String get sleepEfficiency;

  /// Time awake during the night.
  ///
  /// In zh, this message translates to:
  /// **'夜間清醒'**
  String get awakeAtNight;

  /// How often the sleeper woke.
  ///
  /// In zh, this message translates to:
  /// **'醒來 {count} 次'**
  String wokeTimes({required int count});

  /// How unbroken the night was.
  ///
  /// In zh, this message translates to:
  /// **'連續性'**
  String get continuitySection;

  /// How the continuity figures were worked out.
  ///
  /// In zh, this message translates to:
  /// **'依裝置的在床時間估算'**
  String get estimatedFromInBed;

  /// Section planning tonight's sleep.
  ///
  /// In zh, this message translates to:
  /// **'今晚'**
  String get tonightSection;

  /// When to go to bed for the goal.
  ///
  /// In zh, this message translates to:
  /// **'建議就寢'**
  String get suggestedBedtime;

  /// The wake time a bedtime is planned against; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{time} 起床'**
  String wakeAt({required String time});

  /// How the bedtime was worked out.
  ///
  /// In zh, this message translates to:
  /// **'依平常的起床時間'**
  String get fromUsualWake;

  /// Nights after a workout.
  ///
  /// In zh, this message translates to:
  /// **'訓練後'**
  String get afterTraining;

  /// Nights after caffeine late in the day.
  ///
  /// In zh, this message translates to:
  /// **'14:00 後有咖啡因'**
  String get caffeineAfter2pm;

  /// Nights after a late meal.
  ///
  /// In zh, this message translates to:
  /// **'21:00 後進食'**
  String get mealAfter9pm;

  /// How many nights each side of a comparison has.
  ///
  /// In zh, this message translates to:
  /// **'{withCount} 晚對 {withoutCount} 晚'**
  String nightsVersus({required int withCount, required int withoutCount});

  /// What went with longer or shorter nights.
  ///
  /// In zh, this message translates to:
  /// **'影響因素'**
  String get factorsSection;

  /// What the factors compare.
  ///
  /// In zh, this message translates to:
  /// **'近 90 天的平均睡著時間差'**
  String get factorsBasis;

  /// The factors show association only.
  ///
  /// In zh, this message translates to:
  /// **'相關，不代表因果'**
  String get correlationNotCause;

  /// Shorter sleep by a length; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'少睡 {time}'**
  String sleptLess({required String time});

  /// Longer sleep by a length; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'多睡 {time}'**
  String sleptMore({required String time});

  /// How a record was made.
  ///
  /// In zh, this message translates to:
  /// **'紀錄方式'**
  String get recordMethod;

  /// A source that recorded stages.
  ///
  /// In zh, this message translates to:
  /// **'含睡眠階段'**
  String get withStages;

  /// Apple's reading of breathing disturbances: raised.
  ///
  /// In zh, this message translates to:
  /// **'升高'**
  String get elevated;

  /// Apple's reading of breathing disturbances: not raised.
  ///
  /// In zh, this message translates to:
  /// **'未升高'**
  String get notElevated;

  /// A night as long as the usual one.
  ///
  /// In zh, this message translates to:
  /// **'與近 28 晚平均相同'**
  String get sameAsUsual;

  /// A night against the usual one; change is signed and formatted.
  ///
  /// In zh, this message translates to:
  /// **'較近 28 晚平均 {change}'**
  String versusUsual({required String change});

  /// A night that met the sleep goal; goal is formatted.
  ///
  /// In zh, this message translates to:
  /// **'目標 {goal} · 達成'**
  String goalMet({required String goal});

  /// A night short of the sleep goal; both are formatted.
  ///
  /// In zh, this message translates to:
  /// **'目標 {goal} · 少 {gap}'**
  String goalShort({required String goal, required String gap});

  /// A night whose length was typed in.
  ///
  /// In zh, this message translates to:
  /// **'紀錄的睡眠'**
  String get recordedSleep;

  /// Stages a device estimated.
  ///
  /// In zh, this message translates to:
  /// **'裝置估計'**
  String get deviceEstimate;

  /// The day's sleep with naps; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'含小睡共 {time}'**
  String withNapsTotal({required String time});

  /// Chart range: six months.
  ///
  /// In zh, this message translates to:
  /// **'6 個月'**
  String get chartRangeSixMonths;

  /// Nothing recorded for this.
  ///
  /// In zh, this message translates to:
  /// **'沒有紀錄'**
  String get noEntriesShort;

  /// Average length of the nights.
  ///
  /// In zh, this message translates to:
  /// **'平均睡著時間'**
  String get averageTimeAsleep;

  /// Average time of falling asleep.
  ///
  /// In zh, this message translates to:
  /// **'平均入睡'**
  String get averageBedtime;

  /// Average time of waking.
  ///
  /// In zh, this message translates to:
  /// **'平均起床'**
  String get averageWake;

  /// How much bedtimes vary.
  ///
  /// In zh, this message translates to:
  /// **'入睡時間變動'**
  String get bedtimeSpread;

  /// How much wake times vary.
  ///
  /// In zh, this message translates to:
  /// **'起床時間變動'**
  String get wakeSpread;

  /// A spread in minutes.
  ///
  /// In zh, this message translates to:
  /// **'±{minutes} 分'**
  String plusMinusMinutes({required int minutes});

  /// How many nights have a record.
  ///
  /// In zh, this message translates to:
  /// **'紀錄晚數'**
  String get nightsRecorded;

  /// Chart of each night's bedtime and wake time.
  ///
  /// In zh, this message translates to:
  /// **'入睡與起床'**
  String get bedAndWake;

  /// A sleep stage's average a night.
  ///
  /// In zh, this message translates to:
  /// **'平均{stage}'**
  String averageStage({required String stage});

  /// How many nights had stages.
  ///
  /// In zh, this message translates to:
  /// **'{count} 晚有睡眠階段'**
  String nightsWithStages({required int count});

  /// Screen reader label of a nightly chart.
  ///
  /// In zh, this message translates to:
  /// **'{measure}走勢，{count} 晚'**
  String trendOverNights({required String measure, required int count});

  /// Chart of heart rate through the night.
  ///
  /// In zh, this message translates to:
  /// **'睡眠時心率'**
  String get heartRateAsleep;

  /// Chart of breathing through the night.
  ///
  /// In zh, this message translates to:
  /// **'睡眠時呼吸速率'**
  String get respiratoryAsleep;

  /// How long each bar of a chart covers.
  ///
  /// In zh, this message translates to:
  /// **'每 {minutes} 分'**
  String everyMinutes({required int minutes});

  /// Screen reader label of the stage chart; times are formatted.
  ///
  /// In zh, this message translates to:
  /// **'睡眠階段圖，{start} 到 {end}'**
  String stageChartLabel({required String start, required String end});

  /// The stage chart's reading for the whole night.
  ///
  /// In zh, this message translates to:
  /// **'整晚'**
  String get wholeNight;

  /// Screen reader label of the schedule chart.
  ///
  /// In zh, this message translates to:
  /// **'入睡與起床時間，{count} 晚'**
  String scheduleChartLabel({required int count});

  /// How long the user aims to sleep.
  ///
  /// In zh, this message translates to:
  /// **'睡眠目標'**
  String get sleepGoal;

  /// A setting left empty.
  ///
  /// In zh, this message translates to:
  /// **'未設定'**
  String get notSet;

  /// A daily reminder to go to bed.
  ///
  /// In zh, this message translates to:
  /// **'就寢提醒'**
  String get bedtimeReminder;

  /// When the reminder comes; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{time} 提醒'**
  String remindsAt({required String time});

  /// Removes a goal.
  ///
  /// In zh, this message translates to:
  /// **'清除目標'**
  String get clearGoal;

  /// Section with a figure's chart over time.
  ///
  /// In zh, this message translates to:
  /// **'走勢'**
  String get trendSection;

  /// Section listing day by day.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get eachDaySection;

  /// Too few records for a figure.
  ///
  /// In zh, this message translates to:
  /// **'紀錄不足'**
  String get notEnoughEntries;

  /// A chart's range; both are formatted.
  ///
  /// In zh, this message translates to:
  /// **'最高 {high} · 最低 {low}'**
  String highestLowest({required String high, required String low});

  /// A figure from fewer days than it settles on.
  ///
  /// In zh, this message translates to:
  /// **'初步'**
  String get preliminary;

  /// The need a debt is counted against when no goal is set; hours is formatted.
  ///
  /// In zh, this message translates to:
  /// **'以 {hours} 計'**
  String countedAt({required String hours});

  /// A goal's value; goal is formatted.
  ///
  /// In zh, this message translates to:
  /// **'目標 {goal}'**
  String goalValue({required String goal});

  /// Days missing from a count.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天沒有紀錄'**
  String daysWithoutEntries({required int count});

  /// Unit beside a number of hours.
  ///
  /// In zh, this message translates to:
  /// **'小時'**
  String get hoursUnit;

  /// Sleep over the goal in the last 14 days; hours is formatted.
  ///
  /// In zh, this message translates to:
  /// **'近 14 天 · 多睡 {hours}'**
  String lastFortnightExtra({required String hours});

  /// Why there is no sleep debt figure yet.
  ///
  /// In zh, this message translates to:
  /// **'需要近 14 天有 {minimum} 天紀錄（目前 {recorded} 天）'**
  String needsLoggedDays({required int minimum, required int recorded});

  /// The last week's debt and extra sleep; both are formatted.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天 {short} · 多睡 {extra}'**
  String lastWeekDebt({required String short, required String extra});

  /// A number of hours, to one decimal.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小時'**
  String hoursValue({required String hours});

  /// Short of a goal by a length; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'少 {time}'**
  String shortBy({required String time});

  /// Over a goal by a length; time is formatted.
  ///
  /// In zh, this message translates to:
  /// **'多 {time}'**
  String overBy({required String time});

  /// Error when on-device text recognition is unavailable.
  ///
  /// In zh, this message translates to:
  /// **'這台裝置無法讀取照片中的文字。'**
  String get photoTextUnavailable;

  /// Error when a photo held no body-composition figures.
  ///
  /// In zh, this message translates to:
  /// **'照片中沒有讀到身體組成的數字。'**
  String get photoNoBodyComposition;

  /// Error when a photo held no body measurements.
  ///
  /// In zh, this message translates to:
  /// **'照片中沒有讀到圍度的數字。'**
  String get photoNoGirths;

  /// A field's value is out of range; min and max are formatted.
  ///
  /// In zh, this message translates to:
  /// **'{field}請輸入 {min} – {max} {unit} 之間。'**
  String valueRangeError({
    required String field,
    required String min,
    required String max,
    required String unit,
  });

  /// Error when a form is saved empty.
  ///
  /// In zh, this message translates to:
  /// **'至少填一項。'**
  String get fillAtLeastOne;

  /// Error when no body measurement was entered.
  ///
  /// In zh, this message translates to:
  /// **'至少填一個部位。'**
  String get fillAtLeastOneSite;

  /// Toast after logging one reading; value is formatted with its unit.
  ///
  /// In zh, this message translates to:
  /// **'已記錄{item} {value}'**
  String loggedValue({required String item, required String value});

  /// Toast after editing one reading; value is formatted with its unit.
  ///
  /// In zh, this message translates to:
  /// **'已更新{item} {value}'**
  String updatedValue({required String item, required String value});

  /// Toast after logging several readings.
  ///
  /// In zh, this message translates to:
  /// **'已記錄 {count} 項'**
  String loggedItemsCount({required int count});

  /// Toast after logging several body measurements.
  ///
  /// In zh, this message translates to:
  /// **'已記錄 {count} 個部位'**
  String loggedSitesCount({required int count});

  /// Header action that reads figures from a photo.
  ///
  /// In zh, this message translates to:
  /// **'掃描'**
  String get scanAction;

  /// Shown while the chosen AI reads a photo taken in the food form, whether a label or food.
  ///
  /// In zh, this message translates to:
  /// **'正在讀取照片…'**
  String get readingPhoto;

  /// Screen-reader label of the scan action.
  ///
  /// In zh, this message translates to:
  /// **'拍照讀取身體組成'**
  String get scanBodyComposition;

  /// Screen-reader label of the scan action.
  ///
  /// In zh, this message translates to:
  /// **'拍照讀取圍度'**
  String get scanGirths;

  /// The previous reading under a field; value and date are formatted.
  ///
  /// In zh, this message translates to:
  /// **'上次 {value} · {date}'**
  String lastReadingOn({required String value, required String date});

  /// Tag after figures were filled in from a photo.
  ///
  /// In zh, this message translates to:
  /// **'照片讀到 {count} 項，請核對'**
  String photoReadCheck({required int count});

  /// Tag on the body-composition form.
  ///
  /// In zh, this message translates to:
  /// **'照體脂計顯示填寫'**
  String get fillFromScale;

  /// Toast after saving a new note.
  ///
  /// In zh, this message translates to:
  /// **'已記錄筆記'**
  String get noteLogged;

  /// Toast after editing a note.
  ///
  /// In zh, this message translates to:
  /// **'已更新筆記'**
  String get noteUpdated;

  /// Hint in the note field.
  ///
  /// In zh, this message translates to:
  /// **'例如：晚上聚餐，吃得比平常多'**
  String get noteHint;

  /// Error on the sleep form.
  ///
  /// In zh, this message translates to:
  /// **'起床時間要在入睡之後'**
  String get sleepWakeBeforeBed;

  /// Error on the sleep form.
  ///
  /// In zh, this message translates to:
  /// **'一次睡眠不超過 24 小時'**
  String get sleepOver24Hours;

  /// Error on the sleep form.
  ///
  /// In zh, this message translates to:
  /// **'起床時間不能晚於現在'**
  String get sleepWakeInFuture;

  /// Row for when sleep began.
  ///
  /// In zh, this message translates to:
  /// **'入睡'**
  String get sleepStartLabel;

  /// Row for when sleep ended.
  ///
  /// In zh, this message translates to:
  /// **'起床'**
  String get sleepEndLabel;

  /// Sleep quality score field.
  ///
  /// In zh, this message translates to:
  /// **'品質'**
  String get qualityLabel;

  /// Hint in the sleep note field.
  ///
  /// In zh, this message translates to:
  /// **'例如：睡前喝了咖啡、半夜醒來'**
  String get sleepNoteHint;

  /// Error on the weight form.
  ///
  /// In zh, this message translates to:
  /// **'請輸入 {min} – {max} kg 之間的數值。'**
  String weightRangeError({required String min, required String max});

  /// Toast after logging a weight; weight is formatted.
  ///
  /// In zh, this message translates to:
  /// **'已記錄 {weight} kg'**
  String weightLogged({required String weight});

  /// Toast after editing a weight; weight is formatted.
  ///
  /// In zh, this message translates to:
  /// **'已更新為 {weight} kg'**
  String weightUpdated({required String weight});

  /// Section over the symptom score.
  ///
  /// In zh, this message translates to:
  /// **'不適程度'**
  String get symptomSeverity;

  /// Section over a mood or energy score; kind is the lowercase-able name.
  ///
  /// In zh, this message translates to:
  /// **'{kind}如何？'**
  String wellnessKindHow({required String kind});

  /// Hint in the wellness note field.
  ///
  /// In zh, this message translates to:
  /// **'例如：久坐一整天，下背有點緊'**
  String get wellnessNoteHint;

  /// A BMI band under Taiwan's Health Promotion Administration adult standard. (BmiBand.under)
  ///
  /// In zh, this message translates to:
  /// **'體重過輕'**
  String get bmiBandUnder;

  /// A BMI band under Taiwan's Health Promotion Administration adult standard. (BmiBand.healthy)
  ///
  /// In zh, this message translates to:
  /// **'健康體重'**
  String get bmiBandHealthy;

  /// A BMI band under Taiwan's Health Promotion Administration adult standard. (BmiBand.over)
  ///
  /// In zh, this message translates to:
  /// **'過重'**
  String get bmiBandOver;

  /// A BMI band under Taiwan's Health Promotion Administration adult standard. (BmiBand.obese)
  ///
  /// In zh, this message translates to:
  /// **'肥胖'**
  String get bmiBandObese;

  /// A number of years.
  ///
  /// In zh, this message translates to:
  /// **'{count} 年'**
  String yearsCount({required int count});

  /// Title of the menu that picks what to log, and its button's label.
  ///
  /// In zh, this message translates to:
  /// **'記錄'**
  String get logAction;

  /// Button that logs a kind of record.
  ///
  /// In zh, this message translates to:
  /// **'記錄{item}'**
  String logItem({required String item});

  /// Screen-reader label of a chart.
  ///
  /// In zh, this message translates to:
  /// **'{item}走勢，{count} 筆'**
  String trendReadingsLabel({required String item, required int count});

  /// Tag under body-composition figures.
  ///
  /// In zh, this message translates to:
  /// **'體脂計估計，請用同一台比較'**
  String get bodyScaleCompareSame;

  /// Empty state of the weight section.
  ///
  /// In zh, this message translates to:
  /// **'沒有體重紀錄'**
  String get noWeightEntries;

  /// Label of the smoothed weight figure.
  ///
  /// In zh, this message translates to:
  /// **'趨勢體重'**
  String get trendWeight;

  /// The latest reading; date and value are formatted.
  ///
  /// In zh, this message translates to:
  /// **'最近 {date} {value}'**
  String latestOn({required String date, required String value});

  /// Screen-reader label of the weight chart.
  ///
  /// In zh, this message translates to:
  /// **'體重走勢，{count} 次'**
  String weightChartLabel({required int count});

  /// Caption under the weight chart.
  ///
  /// In zh, this message translates to:
  /// **'線為 7 日平均 · {count} 次秤重'**
  String weightChartIdle({required int count});

  /// The smoothed value at a point; value is formatted.
  ///
  /// In zh, this message translates to:
  /// **'趨勢 {value}'**
  String trendValue({required String value});

  /// Row that opens every weight entry.
  ///
  /// In zh, this message translates to:
  /// **'所有體重紀錄'**
  String get allWeightEntries;

  /// Section with BMI, FFMI and waist-to-hip ratio.
  ///
  /// In zh, this message translates to:
  /// **'體位'**
  String get buildSection;

  /// A body figure.
  ///
  /// In zh, this message translates to:
  /// **'腰臀比'**
  String get waistToHipRatio;

  /// Tag naming the standard the BMI bands follow.
  ///
  /// In zh, this message translates to:
  /// **'國健署成人標準'**
  String get bmiStandardTaiwan;

  /// A body figure worked out from weight and body fat.
  ///
  /// In zh, this message translates to:
  /// **'脂肪量'**
  String get fatMass;

  /// Tag under the waist measurement.
  ///
  /// In zh, this message translates to:
  /// **'國健署建議腰圍：男 < 90 cm、女 < 80 cm'**
  String get waistAdviceTaiwan;

  /// The weekly goal of active days.
  ///
  /// In zh, this message translates to:
  /// **'每週目標'**
  String get weeklyGoal;

  /// Screen-reader label of the goal button while paused.
  ///
  /// In zh, this message translates to:
  /// **'每週目標已暫停'**
  String get weeklyGoalPaused;

  /// Screen-reader label of the goal button.
  ///
  /// In zh, this message translates to:
  /// **'本週 {active} / {target} 個運動日，查看每週目標'**
  String weeklyGoalButtonLabel({required int active, required int target});

  /// The goal's size.
  ///
  /// In zh, this message translates to:
  /// **'每週 {count} 個運動日'**
  String activeDaysPerWeek({required int count});

  /// Screen-reader label of the goal settings action.
  ///
  /// In zh, this message translates to:
  /// **'調整每週目標'**
  String get adjustWeeklyGoal;

  /// Body of the card before a goal is set.
  ///
  /// In zh, this message translates to:
  /// **'每週要有幾個運動日。'**
  String get weeklyGoalPrompt;

  /// Button and title that set a first goal.
  ///
  /// In zh, this message translates to:
  /// **'設定每週目標'**
  String get setWeeklyGoal;

  /// Section and state about weeks met in a row.
  ///
  /// In zh, this message translates to:
  /// **'連續達標'**
  String get streakSection;

  /// Headline when this week's goal is met.
  ///
  /// In zh, this message translates to:
  /// **'本週目標已完成'**
  String get weekGoalMet;

  /// Headline while this week's goal is under way.
  ///
  /// In zh, this message translates to:
  /// **'本週運動'**
  String get weekActivity;

  /// Detail of a paused week.
  ///
  /// In zh, this message translates to:
  /// **'不計入連續達標'**
  String get notCountedInStreak;

  /// A number of active days.
  ///
  /// In zh, this message translates to:
  /// **'{count} 個運動日'**
  String activeDaysCount({required int count});

  /// Active days still needed this week.
  ///
  /// In zh, this message translates to:
  /// **'還差 {count} 個運動日'**
  String activeDaysToGo({required int count});

  /// Streak card when the last streak ended.
  ///
  /// In zh, this message translates to:
  /// **'本週重新開始'**
  String get streakRestartsThisWeek;

  /// Streak card before any week was met.
  ///
  /// In zh, this message translates to:
  /// **'沒有連續達標紀錄'**
  String get noStreakYet;

  /// Detail when the last streak ended.
  ///
  /// In zh, this message translates to:
  /// **'上次連續達標 {previous} 週，最佳 {best} 週'**
  String lastStreak({required int previous, required int best});

  /// Detail before any week was met.
  ///
  /// In zh, this message translates to:
  /// **'達成一週目標後開始累積'**
  String get streakStartsAfterGoal;

  /// Streak headline.
  ///
  /// In zh, this message translates to:
  /// **'連續達標 {count} 週'**
  String streakWeeks({required int count});

  /// Streak detail while this week is under way.
  ///
  /// In zh, this message translates to:
  /// **'本週進行中 · 最佳 {best} 週'**
  String streakPendingBest({required int best});

  /// Longest streak.
  ///
  /// In zh, this message translates to:
  /// **'最佳 {best} 週'**
  String streakBest({required int best});

  /// Screen-reader label of a day in the goal month.
  ///
  /// In zh, this message translates to:
  /// **'{day} 日'**
  String goalDayLabel({required int day});

  /// Screen-reader label of a day with activity.
  ///
  /// In zh, this message translates to:
  /// **'{day} 日，有運動'**
  String goalDayActive({required int day});

  /// A week's progress.
  ///
  /// In zh, this message translates to:
  /// **'{active} / {target} 個運動日'**
  String activeDaysFraction({required int active, required int target});

  /// Toast after saving a goal that applies now.
  ///
  /// In zh, this message translates to:
  /// **'本週起每週 {count} 天'**
  String goalFromThisWeek({required int count});

  /// Toast after saving a goal that applies next week.
  ///
  /// In zh, this message translates to:
  /// **'下週起每週 {count} 天'**
  String goalFromNextWeek({required int count});

  /// Title of the pause dialog and its switch.
  ///
  /// In zh, this message translates to:
  /// **'暫停每週目標'**
  String get pauseWeeklyGoal;

  /// Consequence stated in the pause dialog.
  ///
  /// In zh, this message translates to:
  /// **'暫停期間的週不會累積，也不會中斷連續達標。'**
  String get pauseWeeklyGoalMessage;

  /// Pause dialog choice.
  ///
  /// In zh, this message translates to:
  /// **'暫停本週'**
  String get pauseThisWeek;

  /// Pause dialog choice.
  ///
  /// In zh, this message translates to:
  /// **'直到手動恢復'**
  String get pauseUntilResumed;

  /// Subtitle of the goal setup page.
  ///
  /// In zh, this message translates to:
  /// **'一週想要有幾個運動日'**
  String get activeDaysPerWeekQuestion;

  /// The suggested goal size.
  ///
  /// In zh, this message translates to:
  /// **'過去四週平均：每週 {count} 天'**
  String suggestedDays({required int count});

  /// Section choosing when a changed goal applies.
  ///
  /// In zh, this message translates to:
  /// **'從什麼時候開始'**
  String get goalStartSection;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'下週起'**
  String get fromNextWeek;

  /// Detail of the choice.
  ///
  /// In zh, this message translates to:
  /// **'本週仍用原本的目標計算'**
  String get fromNextWeekDetail;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'本週就套用'**
  String get applyThisWeek;

  /// Detail of the choice.
  ///
  /// In zh, this message translates to:
  /// **'重新計算本週'**
  String get applyThisWeekDetail;

  /// Section with the pause and off switches.
  ///
  /// In zh, this message translates to:
  /// **'暫停或關閉'**
  String get pauseOrTurnOff;

  /// Detail of the goal switch.
  ///
  /// In zh, this message translates to:
  /// **'關閉時隱藏目標與連續達標'**
  String get weeklyGoalOffDetail;

  /// Screen-reader label of a paused ring.
  ///
  /// In zh, this message translates to:
  /// **'本週已暫停'**
  String get thisWeekPaused;

  /// Screen-reader label of the ring.
  ///
  /// In zh, this message translates to:
  /// **'本週 {active} / {target} 個運動日'**
  String thisWeekActiveDays({required int active, required int target});

  /// Label of the running-workout card.
  ///
  /// In zh, this message translates to:
  /// **'訓練進行中'**
  String get workoutInProgress;

  /// Where a running workout is.
  ///
  /// In zh, this message translates to:
  /// **'{exercise} · 第 {set} 組 · 已完成 {done} 組'**
  String workoutCurrentSet({
    required String exercise,
    required int set,
    required int done,
  });

  /// Button that opens the running workout.
  ///
  /// In zh, this message translates to:
  /// **'回到訓練'**
  String get backToWorkout;

  /// Heading over a running workout's figures.
  ///
  /// In zh, this message translates to:
  /// **'本次'**
  String get thisSession;

  /// Stat label.
  ///
  /// In zh, this message translates to:
  /// **'已完成組數'**
  String get setsCompleted;

  /// Stat label: exercises done of all.
  ///
  /// In zh, this message translates to:
  /// **'動作進度'**
  String get exerciseProgress;

  /// Stat label: personal records set.
  ///
  /// In zh, this message translates to:
  /// **'個人紀錄'**
  String get personalRecords;

  /// Section of today's other records during a workout.
  ///
  /// In zh, this message translates to:
  /// **'其他紀錄'**
  String get otherEntries;

  /// Title of the page choosing Today's sections.
  ///
  /// In zh, this message translates to:
  /// **'自訂首頁'**
  String get customiseToday;

  /// Link that shows every hidden section.
  ///
  /// In zh, this message translates to:
  /// **'全部顯示'**
  String get showAll;

  /// Eyebrow of the next-meal card.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get nextStep;

  /// Tag when some figures are estimated.
  ///
  /// In zh, this message translates to:
  /// **'含估計值'**
  String get includesEstimates;

  /// Warning when some records lack a macro; macros is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'{macros}有紀錄沒有數字，未計入。'**
  String partialMacros({required String macros});

  /// Card after a workout finished today.
  ///
  /// In zh, this message translates to:
  /// **'{name} 已完成'**
  String routineCompleted({required String name});

  /// Stat label.
  ///
  /// In zh, this message translates to:
  /// **'總組數'**
  String get totalSets;

  /// Stat label and section of exercises.
  ///
  /// In zh, this message translates to:
  /// **'動作'**
  String get exercisesLabel;

  /// A Today section.
  ///
  /// In zh, this message translates to:
  /// **'今日指標'**
  String get todaySectionGlance;

  /// A Today section.
  ///
  /// In zh, this message translates to:
  /// **'今日活動'**
  String get todaySectionActivity;

  /// A Today section.
  ///
  /// In zh, this message translates to:
  /// **'本週'**
  String get todaySectionWeek;

  /// A Today section.
  ///
  /// In zh, this message translates to:
  /// **'今天的紀錄'**
  String get todaySectionRecords;

  /// A Today section.
  ///
  /// In zh, this message translates to:
  /// **'值得注意'**
  String get todaySectionInsights;

  /// Screen-reader label of an active day in the week strip.
  ///
  /// In zh, this message translates to:
  /// **'{weekday}，有訓練或運動'**
  String weekdayActive({required String weekday});

  /// Link to every record of the day.
  ///
  /// In zh, this message translates to:
  /// **'全部 {count} 筆'**
  String allCount({required int count});

  /// Days done of a target.
  ///
  /// In zh, this message translates to:
  /// **'{active} / {target} 天'**
  String daysFraction({required int active, required int target});

  /// A week's weight change; change is signed and formatted.
  ///
  /// In zh, this message translates to:
  /// **'7 日 {change}'**
  String weightChange7Days({required String change});

  /// Error when an exercise's tracking type can't change.
  ///
  /// In zh, this message translates to:
  /// **'已有 {count} 次紀錄用這個追蹤方式，改了會讓舊紀錄變成另一種意思。要換成別的追蹤方式，請建立一個新動作。'**
  String trackingChangeRefused({required int count});

  /// Title and action that creates an exercise.
  ///
  /// In zh, this message translates to:
  /// **'建立自訂動作'**
  String get createCustomExercise;

  /// Title and row that edit an exercise.
  ///
  /// In zh, this message translates to:
  /// **'編輯動作'**
  String get editExercise;

  /// Where an exercise came from; source is 內建, 自訂 or 匯入.
  ///
  /// In zh, this message translates to:
  /// **'{source}動作'**
  String exerciseOfSource({required String source});

  /// Button that creates an exercise and adds it.
  ///
  /// In zh, this message translates to:
  /// **'建立並加入'**
  String get createAndAdd;

  /// Section with a name field.
  ///
  /// In zh, this message translates to:
  /// **'名稱'**
  String get nameSection;

  /// Hint in the exercise name field.
  ///
  /// In zh, this message translates to:
  /// **'例如：啞鈴臥推'**
  String get exerciseNameHint;

  /// How an exercise's sets are measured.
  ///
  /// In zh, this message translates to:
  /// **'追蹤方式'**
  String get trackingTypeSection;

  /// Warning under the tracking choice.
  ///
  /// In zh, this message translates to:
  /// **'建立後不能改成不相容的追蹤方式。'**
  String get trackingTypeLocked;

  /// Section choosing a new exercise's region.
  ///
  /// In zh, this message translates to:
  /// **'主要肌群或動作模式'**
  String get primaryMuscleOrPattern;

  /// An exercise's equipment.
  ///
  /// In zh, this message translates to:
  /// **'器材'**
  String get equipmentSection;

  /// No particular equipment.
  ///
  /// In zh, this message translates to:
  /// **'不指定'**
  String get equipmentAny;

  /// Warning when a new exercise looks like an existing one.
  ///
  /// In zh, this message translates to:
  /// **'可能已經有這個動作'**
  String get possibleDuplicate;

  /// A number of records.
  ///
  /// In zh, this message translates to:
  /// **'{count} 筆紀錄'**
  String entriesCount({required int count});

  /// Link choosing an existing exercise.
  ///
  /// In zh, this message translates to:
  /// **'使用這個'**
  String get useThis;

  /// Why to pick the existing exercise.
  ///
  /// In zh, this message translates to:
  /// **'選既有動作，歷史與個人紀錄才不會被拆成好幾份。'**
  String get duplicateAdvice;

  /// Screen-reader label of the demonstration.
  ///
  /// In zh, this message translates to:
  /// **'{name}示範，{count} 個姿勢'**
  String exerciseDemoLabel({required String name, required int count});

  /// State of the demonstration.
  ///
  /// In zh, this message translates to:
  /// **'播放中'**
  String get playing;

  /// Credit the licence asks for.
  ///
  /// In zh, this message translates to:
  /// **'圖：Workout Guide／Everkinetic · CC BY-SA 4.0'**
  String get exerciseDemoCredit;

  /// Names the user finds an exercise by.
  ///
  /// In zh, this message translates to:
  /// **'我的別名'**
  String get myAliases;

  /// Hint in the aliases dialog.
  ///
  /// In zh, this message translates to:
  /// **'用、分隔，例如：深蹲、squat'**
  String get aliasesHint;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已更新別名'**
  String get aliasesUpdated;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'不能和自己合併'**
  String get cannotMergeSelf;

  /// Merge confirmation title.
  ///
  /// In zh, this message translates to:
  /// **'把「{duplicate}」併入「{canonical}」？'**
  String mergeTitle({required String duplicate, required String canonical});

  /// Consequence of merging.
  ///
  /// In zh, this message translates to:
  /// **'過去的紀錄改算在「{canonical}」下，動作不再出現在選擇器。紀錄的內容不會被改寫，但這個合併無法復原。'**
  String mergeMessage({required String canonical});

  /// Destructive merge button.
  ///
  /// In zh, this message translates to:
  /// **'併入「{canonical}」'**
  String mergeInto({required String canonical});

  /// Toast after merging.
  ///
  /// In zh, this message translates to:
  /// **'已併入「{canonical}」'**
  String mergedInto({required String canonical});

  /// Footer button on an exercise opened from the picker.
  ///
  /// In zh, this message translates to:
  /// **'加入這個動作'**
  String get addThisExercise;

  /// Section of related exercises.
  ///
  /// In zh, this message translates to:
  /// **'同一動作的其他做法'**
  String get otherVariations;

  /// Section of an exercise's cues.
  ///
  /// In zh, this message translates to:
  /// **'重點提示'**
  String get cuesSection;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get removeFavorite;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'加入收藏'**
  String get addFavorite;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get favoriteRemoved;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已加入收藏'**
  String get favoriteAdded;

  /// What editing an exercise changes.
  ///
  /// In zh, this message translates to:
  /// **'名稱、器材、部位'**
  String get editExerciseDetail;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'編輯我的別名'**
  String get editMyAliases;

  /// Subtitle when no personal alias is set; names is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'目前用內建名稱：{names}'**
  String builtInNames({required String names});

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'合併到另一個動作'**
  String get mergeIntoAnother;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'重複建立時，把紀錄併到同一個動作下'**
  String get mergeIntoAnotherDetail;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'取消隱藏'**
  String get unhide;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'隱藏這個動作'**
  String get hideExercise;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已取消隱藏「{name}」'**
  String unhidden({required String name});

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已隱藏「{name}」'**
  String hidden({required String name});

  /// Spec row.
  ///
  /// In zh, this message translates to:
  /// **'部位'**
  String get bodyPartLabel;

  /// Spec row.
  ///
  /// In zh, this message translates to:
  /// **'主要肌群'**
  String get primaryMuscles;

  /// Spec row.
  ///
  /// In zh, this message translates to:
  /// **'次要肌群'**
  String get secondaryMuscles;

  /// Spec row and filter group.
  ///
  /// In zh, this message translates to:
  /// **'動作模式'**
  String get movementPatternLabel;

  /// Spec row.
  ///
  /// In zh, this message translates to:
  /// **'左右'**
  String get lateralityLabel;

  /// Stat label.
  ///
  /// In zh, this message translates to:
  /// **'上次工作組'**
  String get lastWorkingSet;

  /// Stat label.
  ///
  /// In zh, this message translates to:
  /// **'估計最大重量'**
  String get estimatedMax;

  /// Unit beside a count of sessions.
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get sessionsUnit;

  /// Stat label.
  ///
  /// In zh, this message translates to:
  /// **'訓練紀錄'**
  String get trainingEntries;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'估計最大重量走勢，{count} 次訓練'**
  String estimatedMaxTrend({required int count});

  /// Tag naming the formula.
  ///
  /// In zh, this message translates to:
  /// **'Epley 估計'**
  String get epleyEstimate;

  /// A set's external weight as a percentage of the previous estimated one-rep max.
  ///
  /// In zh, this message translates to:
  /// **'相對負荷 {percent}%'**
  String relativeLoadPercent({required int percent});

  /// Tag naming the window.
  ///
  /// In zh, this message translates to:
  /// **'近 90 天'**
  String get last90Days;

  /// Filter page, button and row label.
  ///
  /// In zh, this message translates to:
  /// **'篩選'**
  String get filterTitle;

  /// Filter page subtitle.
  ///
  /// In zh, this message translates to:
  /// **'已套用 {count} 個條件'**
  String filtersApplied({required int count});

  /// Filter footer button.
  ///
  /// In zh, this message translates to:
  /// **'顯示 {count} 個動作'**
  String showExercises({required int count});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'清除全部'**
  String get clearAll;

  /// Filter chip for a whole body region.
  ///
  /// In zh, this message translates to:
  /// **'整個{region}'**
  String wholeRegion({required String region});

  /// Filter group of where an exercise came from.
  ///
  /// In zh, this message translates to:
  /// **'來源'**
  String get sourceLabel;

  /// Picker tab.
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get pickerTabRecent;

  /// Picker tab.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get pickerTabFavorites;

  /// Picker tab.
  ///
  /// In zh, this message translates to:
  /// **'本健身房'**
  String get pickerTabHomeGym;

  /// Picker tab.
  ///
  /// In zh, this message translates to:
  /// **'所有動作'**
  String get pickerTabAll;

  /// What the picker is open for.
  ///
  /// In zh, this message translates to:
  /// **'加入課表'**
  String get pickerAddToRoutine;

  /// What the picker is open for.
  ///
  /// In zh, this message translates to:
  /// **'加入進行中的'**
  String get pickerAddToWorkout;

  /// What the picker is open for.
  ///
  /// In zh, this message translates to:
  /// **'加入紀錄'**
  String get pickerAddToEntry;

  /// What the picker is open for.
  ///
  /// In zh, this message translates to:
  /// **'瀏覽與搜尋所有動作'**
  String get pickerBrowse;

  /// What the picker is open for.
  ///
  /// In zh, this message translates to:
  /// **'選擇一個動作'**
  String get pickerSingle;

  /// What the picker is for, and what it adds to.
  ///
  /// In zh, this message translates to:
  /// **'{purpose}「{name}」'**
  String pickerPurposeFor({required String purpose, required String name});

  /// Confirmation.
  ///
  /// In zh, this message translates to:
  /// **'放棄已選的 {count} 個動作？'**
  String discardSelectedTitle({required int count});

  /// Destructive button.
  ///
  /// In zh, this message translates to:
  /// **'放棄已選的動作'**
  String get discardSelected;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'繼續選擇'**
  String get keepChoosing;

  /// Picker title while browsing.
  ///
  /// In zh, this message translates to:
  /// **'動作庫'**
  String get exerciseLibrary;

  /// Picker title for one pick.
  ///
  /// In zh, this message translates to:
  /// **'選擇動作'**
  String get chooseExercise;

  /// Picker title when adding.
  ///
  /// In zh, this message translates to:
  /// **'新增動作'**
  String get addExercises;

  /// Card at the end of the list.
  ///
  /// In zh, this message translates to:
  /// **'找不到？建立自訂動作'**
  String get cantFindCreate;

  /// Search hint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋動作、別名或器材…'**
  String get searchExercisesHint;

  /// Link that clears filters.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clearAction;

  /// How long ago.
  ///
  /// In zh, this message translates to:
  /// **'{count} 天前'**
  String daysAgo({required int count});

  /// Tooltip of an info button.
  ///
  /// In zh, this message translates to:
  /// **'{name}說明'**
  String aboutItem({required String name});

  /// Caption above the selected exercises.
  ///
  /// In zh, this message translates to:
  /// **'加入順序 · 點一下可移除'**
  String get selectionOrderHint;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'移除第 {index} 個：{name}'**
  String removeNumbered({required int index, required String name});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'加入 {count} 個動作'**
  String addExercisesCount({required int count});

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有符合的動作'**
  String get noMatchingExercises;

  /// Why nothing was found.
  ///
  /// In zh, this message translates to:
  /// **'套用了「器材：{equipment}」，要找的動作可能是別種器材。'**
  String equipmentFilterHint({required String equipment});

  /// Why nothing was found.
  ///
  /// In zh, this message translates to:
  /// **'換個說法、英文名稱或別名再試一次。'**
  String get searchAgainHint;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'移除器材篩選再找一次'**
  String get removeEquipmentFilter;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'相近的動作'**
  String get similarExercises;

  /// Card creating an exercise with the searched name.
  ///
  /// In zh, this message translates to:
  /// **'建立「{name}」'**
  String createNamed({required String name});

  /// An estimated one-rep max; weight is rounded.
  ///
  /// In zh, this message translates to:
  /// **'估計最大重量 {weight} kg'**
  String estimatedMaxValue({required int weight});

  /// The last set; date and set are formatted.
  ///
  /// In zh, this message translates to:
  /// **'上次 {date} {set}'**
  String lastSetOn({required String date, required String set});

  /// Weekly working sets of an exercise.
  ///
  /// In zh, this message translates to:
  /// **'訓練量'**
  String get volumeTitle;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'訓練紀錄不足。'**
  String get notEnoughWorkouts;

  /// Title.
  ///
  /// In zh, this message translates to:
  /// **'{exercise}的訓練量'**
  String volumeOf({required String exercise});

  /// Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'值得注意 · 近 {weeks} 週'**
  String insightWeeks({required int weeks});

  /// Statement when nothing changed; estimate is a weight or 尚無法估計.
  ///
  /// In zh, this message translates to:
  /// **'每週工作組數維持在 {sets} 組，估計最大重量 {estimate}。'**
  String volumeSteady({required int sets, required String estimate});

  /// When no max can be estimated.
  ///
  /// In zh, this message translates to:
  /// **'尚無法估計'**
  String get notYetEstimable;

  /// Section naming what a statement rests on.
  ///
  /// In zh, this message translates to:
  /// **'依據'**
  String get basisSection;

  /// Basis of the volume chart.
  ///
  /// In zh, this message translates to:
  /// **'每週工作組數，取自 {count} 次訓練紀錄。'**
  String weeklySetsFrom({required int count});

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'資料品質與完整度'**
  String get dataQualitySection;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次訓練皆有紀錄'**
  String workoutsAllLogged({required int count});

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'重量與次數為手動輸入'**
  String get weightRepsManual;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'時間範圍'**
  String get timeRangeSection;

  /// Caption.
  ///
  /// In zh, this message translates to:
  /// **'{count} 個完整週'**
  String fullWeeks({required int count});

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'可採取的行動'**
  String get actionsSection;

  /// Suggested action.
  ///
  /// In zh, this message translates to:
  /// **'每週組數比這段期間開始時少。要繼續進步，拉回 {sets} 組左右。'**
  String volumeDropped({required int sets});

  /// Suggested action.
  ///
  /// In zh, this message translates to:
  /// **'目前的組數穩定。要繼續進步，小幅增加每週組數或重量。'**
  String get volumeStable;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'調整「{routine}」的組數'**
  String adjustRoutineSets({required String routine});

  /// Disclaimer.
  ///
  /// In zh, this message translates to:
  /// **'這是訓練紀錄的描述，不是醫療建議。'**
  String get notMedicalAdvice;

  /// Link.
  ///
  /// In zh, this message translates to:
  /// **'查看這段期間的原始紀錄'**
  String get viewRawEntries;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有工作組紀錄'**
  String get noWorkingSets;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'{muscle} 每週 {sets} 組'**
  String muscleWeeklySets({required String muscle, required int sets});

  /// Screen-reader label of the legend.
  ///
  /// In zh, this message translates to:
  /// **'色階由 0 到 {top} 組以上'**
  String muscleScaleLabel({required int top});

  /// Legend unit.
  ///
  /// In zh, this message translates to:
  /// **'組 / 週'**
  String get setsPerWeek;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'肌群訓練量人體圖，詳細數值列在下方'**
  String get muscleMapLabel;

  /// Title and section.
  ///
  /// In zh, this message translates to:
  /// **'肌群'**
  String get musclesTitle;

  /// Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'每週工作組數 · 近 8 週'**
  String get weeklySetsLast8;

  /// Unit beside this week's sets.
  ///
  /// In zh, this message translates to:
  /// **'組 · 本週'**
  String get setsThisWeekUnit;

  /// Usual range; sets is a number or a range.
  ///
  /// In zh, this message translates to:
  /// **'前 {weeks} 週 {sets} 組'**
  String priorWeeksSets({required int weeks, required String sets});

  /// Screen-reader label; sets is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'{muscle}每週組數，{sets}'**
  String muscleSetsChart({required String muscle, required String sets});

  /// Heaviest set; set and date are formatted.
  ///
  /// In zh, this message translates to:
  /// **'最重 {set} · {date}'**
  String heaviestSet({required String set, required String date});

  /// Best estimate and when.
  ///
  /// In zh, this message translates to:
  /// **'估計最大重量 {weight} kg · {date}'**
  String estimatedMaxOn({required int weight, required String date});

  /// Range.
  ///
  /// In zh, this message translates to:
  /// **'近 4 週'**
  String get last4Weeks;

  /// Range.
  ///
  /// In zh, this message translates to:
  /// **'{count} 個月'**
  String monthsCount({required int count});

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'每週組數'**
  String get weeklySetsTitle;

  /// Range.
  ///
  /// In zh, this message translates to:
  /// **'近 8 週'**
  String get last8Weeks;

  /// Tile.
  ///
  /// In zh, this message translates to:
  /// **'每週訓練'**
  String get weeklyWorkouts;

  /// Tile.
  ///
  /// In zh, this message translates to:
  /// **'每週運動'**
  String get weeklyActivities;

  /// Unit.
  ///
  /// In zh, this message translates to:
  /// **'次 · 本週'**
  String get timesThisWeekUnit;

  /// Empty caption.
  ///
  /// In zh, this message translates to:
  /// **'沒有運動紀錄'**
  String get noActivityEntries;

  /// Week's minutes against a usual week.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分 · 平常 {usual} 分'**
  String minutesVersusUsual({required int minutes, required int usual});

  /// An area of records the trends page follows. (TrendDomain.body)
  ///
  /// In zh, this message translates to:
  /// **'身體'**
  String get trendDomainBody;

  /// An area of records the trends page follows. (TrendDomain.training)
  ///
  /// In zh, this message translates to:
  /// **'訓練'**
  String get trendDomainTraining;

  /// An area of records the trends page follows. (TrendDomain.sleep)
  ///
  /// In zh, this message translates to:
  /// **'睡眠'**
  String get trendDomainSleep;

  /// An area of records the trends page follows. (TrendDomain.nutrition)
  ///
  /// In zh, this message translates to:
  /// **'飲食'**
  String get trendDomainNutrition;

  /// An area of records the trends page follows. (TrendDomain.activity)
  ///
  /// In zh, this message translates to:
  /// **'活動'**
  String get trendDomainActivity;

  /// Title of an area's trend page.
  ///
  /// In zh, this message translates to:
  /// **'{area}趨勢'**
  String areaTrend({required String area});

  /// Average bed and wake times.
  ///
  /// In zh, this message translates to:
  /// **'{bedtime} 入睡 · {wake} 起床'**
  String sleepTimesAverage({required String bedtime, required String wake});

  /// Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'近 4 週平均'**
  String get last4WeeksAverage;

  /// Section comparing weekdays.
  ///
  /// In zh, this message translates to:
  /// **'星期'**
  String get weekdaySection;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'同期其他領域'**
  String get otherAreasSection;

  /// Link to the day-by-day page.
  ///
  /// In zh, this message translates to:
  /// **'每日紀錄'**
  String get dailyEntries;

  /// A weekly rate; count is formatted.
  ///
  /// In zh, this message translates to:
  /// **'每週 {count} 次'**
  String perWeekTimes({required String count});

  /// Steps; steps is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{steps} 步'**
  String stepsValue({required String steps});

  /// A formatted count of times.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String timesValue({required String count});

  /// The week a chart point stands for.
  ///
  /// In zh, this message translates to:
  /// **'{date} 起'**
  String weekFrom({required String date});

  /// Range.
  ///
  /// In zh, this message translates to:
  /// **'近 13 週'**
  String get last13Weeks;

  /// Baseline range.
  ///
  /// In zh, this message translates to:
  /// **'過去一年'**
  String get pastYear;

  /// Baseline range.
  ///
  /// In zh, this message translates to:
  /// **'前 12 週'**
  String get prior12Weeks;

  /// Label of a period's average.
  ///
  /// In zh, this message translates to:
  /// **'{period}平均'**
  String periodAverage({required String period});

  /// Chart caption.
  ///
  /// In zh, this message translates to:
  /// **'每週次數'**
  String get weeklyCount;

  /// Chart caption.
  ///
  /// In zh, this message translates to:
  /// **'每週平均'**
  String get weeklyAverage;

  /// Chart caption.
  ///
  /// In zh, this message translates to:
  /// **'每週合計'**
  String get weeklyTotal;

  /// How complete the recent weeks are; days is formatted.
  ///
  /// In zh, this message translates to:
  /// **'近 4 週每週平均 {days} 天有紀錄'**
  String daysLoggedPerWeek({required String days});

  /// Paired figure.
  ///
  /// In zh, this message translates to:
  /// **'秤上體重'**
  String get scaleWeight;

  /// Paired figure.
  ///
  /// In zh, this message translates to:
  /// **'每週訓練量'**
  String get weeklyVolume;

  /// Paired figure.
  ///
  /// In zh, this message translates to:
  /// **'靜止心率'**
  String get restingHeartRate;

  /// Trends section.
  ///
  /// In zh, this message translates to:
  /// **'體重與飲食'**
  String get weightAndNutrition;

  /// Insight title.
  ///
  /// In zh, this message translates to:
  /// **'能量平衡'**
  String get energyBalance;

  /// What the energy insight needs.
  ///
  /// In zh, this message translates to:
  /// **'需要近 {window} 天有 {foodDays} 天完整飲食、{weighings} 次體重（目前 {currentFood} 天、{currentWeighings} 次）'**
  String energyNeeds({
    required int window,
    required int foodDays,
    required int weighings,
    required int currentFood,
    required int currentWeighings,
  });

  /// What the protein insight needs.
  ///
  /// In zh, this message translates to:
  /// **'需要近 {window} 天有 {days} 天完整飲食與體重'**
  String proteinNeeds({required int window, required int days});

  /// Insight title.
  ///
  /// In zh, this message translates to:
  /// **'肌群組數'**
  String get muscleSetsTitle;

  /// What the training insight needs.
  ///
  /// In zh, this message translates to:
  /// **'需要近 4 週至少 {count} 次訓練'**
  String muscleSetsNeeds({required int count});

  /// Trends section.
  ///
  /// In zh, this message translates to:
  /// **'可能的關聯'**
  String get possibleRelations;

  /// Trends section.
  ///
  /// In zh, this message translates to:
  /// **'長期走向'**
  String get longRunSection;

  /// Energy insight headline; kcal is formatted.
  ///
  /// In zh, this message translates to:
  /// **'實際消耗約 {kcal} kcal/天'**
  String actualExpenditure({required String kcal});

  /// Energy line; figures formatted.
  ///
  /// In zh, this message translates to:
  /// **'近 {window} 天平均攝取 {intake} kcal，每天赤字 {balance} kcal'**
  String intakeDeficit({
    required int window,
    required String intake,
    required String balance,
  });

  /// Energy line; figures formatted.
  ///
  /// In zh, this message translates to:
  /// **'近 {window} 天平均攝取 {intake} kcal，每天盈餘 {balance} kcal'**
  String intakeSurplus({
    required int window,
    required String intake,
    required String balance,
  });

  /// Energy line; figures formatted.
  ///
  /// In zh, this message translates to:
  /// **'趨勢體重每週 {change} kg，{weeks} 週後約 {forecast} kg'**
  String weightForecast({
    required String change,
    required int weeks,
    required String forecast,
  });

  /// Basis.
  ///
  /// In zh, this message translates to:
  /// **'{foodDays} 天完整飲食 · {weighings} 次體重'**
  String foodDaysWeighings({required int foodDays, required int weighings});

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'估計的消耗低於靜止代謝，紀錄的攝取可能少於實際。'**
  String get intakeUnderlogged;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'依紀錄估算'**
  String get estimatedFromEntries;

  /// Headline; kcal formatted.
  ///
  /// In zh, this message translates to:
  /// **'週末每天多吃 {kcal} kcal'**
  String weekendEatsMore({required String kcal});

  /// Headline; kcal formatted.
  ///
  /// In zh, this message translates to:
  /// **'週末每天少吃 {kcal} kcal'**
  String weekendEatsLess({required String kcal});

  /// Line; figures formatted.
  ///
  /// In zh, this message translates to:
  /// **'平日 {weekday} kcal · 週末 {weekend} kcal'**
  String weekdayWeekendKcal({required String weekday, required String weekend});

  /// Line.
  ///
  /// In zh, this message translates to:
  /// **'抵掉平日全部的赤字'**
  String get offsetsAllDeficit;

  /// Line.
  ///
  /// In zh, this message translates to:
  /// **'抵掉平日赤字約 {percent}%'**
  String offsetsDeficitShare({required int percent});

  /// Basis.
  ///
  /// In zh, this message translates to:
  /// **'近 {window} 天，{weekdays} 個平日、{weekends} 個週末日'**
  String weekdaysWeekends({
    required int window,
    required int weekdays,
    required int weekends,
  });

  /// Headline; target is formatted.
  ///
  /// In zh, this message translates to:
  /// **'蛋白質達到 {target} g/kg'**
  String proteinMet({required String target});

  /// Headline.
  ///
  /// In zh, this message translates to:
  /// **'蛋白質每天約差 {grams} g'**
  String proteinShort({required int grams});

  /// Line; figures formatted.
  ///
  /// In zh, this message translates to:
  /// **'訓練日 {trained} · 休息日 {rest} g/kg'**
  String trainingRestProtein({required String trained, required String rest});

  /// Basis; figures formatted.
  ///
  /// In zh, this message translates to:
  /// **'以 {weight} kg、目標 {target} g/kg 計 · {days} 天完整飲食'**
  String proteinBasis({
    required String weight,
    required String target,
    required int days,
  });

  /// Headline.
  ///
  /// In zh, this message translates to:
  /// **'練到的肌群每週都有 {target} 組以上'**
  String allMusclesEnough({required int target});

  /// Headline.
  ///
  /// In zh, this message translates to:
  /// **'{muscle}每週只有 {sets} 組'**
  String muscleOnlySets({required String muscle, required int sets});

  /// Line; muscles is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'不到 {target} 組：{muscles}'**
  String underSets({required int target, required String muscles});

  /// Line; muscles is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'{target} 組以上：{muscles}'**
  String atLeastSets({required int target, required String muscles});

  /// Line comparing opposing muscles.
  ///
  /// In zh, this message translates to:
  /// **'{first}對{second} {firstSets} : {secondSets} 組'**
  String pairRatio({
    required String first,
    required String second,
    required int firstSets,
    required int secondSets,
  });

  /// Pushing muscles.
  ///
  /// In zh, this message translates to:
  /// **'推'**
  String get musclePush;

  /// Pulling muscles.
  ///
  /// In zh, this message translates to:
  /// **'拉'**
  String get musclePull;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'近 4 週每週組數，只計主要肌群'**
  String get muscleSetsBasis;

  /// Headline; time formatted.
  ///
  /// In zh, this message translates to:
  /// **'週末起床晚 {time}'**
  String weekendWakeLater({required String time});

  /// Headline; time formatted.
  ///
  /// In zh, this message translates to:
  /// **'週末起床早 {time}'**
  String weekendWakeEarlier({required String time});

  /// Line; times formatted.
  ///
  /// In zh, this message translates to:
  /// **'平日約 {weekday} · 週末約 {weekend} 起床'**
  String weekdayWeekendWake({required String weekday, required String weekend});

  /// Tag on a relation between areas.
  ///
  /// In zh, this message translates to:
  /// **'關聯，不代表因果'**
  String get correlationCaveat;

  /// Body drawn on the muscle map.
  ///
  /// In zh, this message translates to:
  /// **'男性'**
  String get muscleFigureMale;

  /// Body drawn on the muscle map.
  ///
  /// In zh, this message translates to:
  /// **'女性'**
  String get muscleFigureFemale;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已放棄這次訓練'**
  String get workoutDiscarded;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'結束訓練'**
  String get endWorkout;

  /// Card.
  ///
  /// In zh, this message translates to:
  /// **'加入動作'**
  String get addExercise;

  /// An empty field.
  ///
  /// In zh, this message translates to:
  /// **'未填寫'**
  String get notFilled;

  /// Button that starts the workout's clock.
  ///
  /// In zh, this message translates to:
  /// **'開始運動'**
  String get startExercising;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'完成訓練'**
  String get finishWorkout;

  /// Toast; set is formatted.
  ///
  /// In zh, this message translates to:
  /// **'個人紀錄 · {set}'**
  String personalRecordSet({required String set});

  /// Measuring sample only.
  ///
  /// In zh, this message translates to:
  /// **'總'**
  String get totalShort;

  /// State.
  ///
  /// In zh, this message translates to:
  /// **'未開始'**
  String get notStarted;

  /// Label.
  ///
  /// In zh, this message translates to:
  /// **'總訓練量'**
  String get totalVolume;

  /// Change; change is signed and formatted.
  ///
  /// In zh, this message translates to:
  /// **'比上次 {change}'**
  String versusLastTime({required String change});

  /// Progress.
  ///
  /// In zh, this message translates to:
  /// **'{done} / {total} 組'**
  String setsOfTotal({required int done, required int total});

  /// Rest dialog title and clock label.
  ///
  /// In zh, this message translates to:
  /// **'休息'**
  String get restTitle;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'多休息 30 秒'**
  String get rest30More;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'跳過休息'**
  String get skipRest;

  /// Clock label.
  ///
  /// In zh, this message translates to:
  /// **'時間'**
  String get elapsedTime;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'這次訓練的備註'**
  String get workoutNotesTitle;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如：睡不好，握力先到極限'**
  String get workoutNotesHint;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'加入熱身組'**
  String get addWarmupSets;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'加入遞減組'**
  String get addDropSet;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'加入力竭組'**
  String get addFailureSet;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'替換這個動作'**
  String get replaceExercise;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'從這次訓練移除'**
  String get removeFromWorkout;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'超級組'**
  String get superset;

  /// Tooltip.
  ///
  /// In zh, this message translates to:
  /// **'{name}的選項'**
  String optionsFor({required String name});

  /// Caption; volume formatted.
  ///
  /// In zh, this message translates to:
  /// **'訓練量 {volume} kg'**
  String volumeValue({required String volume});

  /// Caption; date and set formatted.
  ///
  /// In zh, this message translates to:
  /// **'上次 {date} · {set}'**
  String lastSetShort({required String date, required String set});

  /// Chip.
  ///
  /// In zh, this message translates to:
  /// **'載入'**
  String get loadPrevious;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'填入上次的重量與次數'**
  String get loadPreviousLabel;

  /// Chip.
  ///
  /// In zh, this message translates to:
  /// **'快速填入'**
  String get quickFill;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'以第一組填入其他組'**
  String get quickFillLabel;

  /// Column heading.
  ///
  /// In zh, this message translates to:
  /// **'組'**
  String get setColumn;

  /// Column heading.
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get repsColumn;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'刪除組'**
  String get removeSet;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'新增組'**
  String get addSet;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'編輯{item}'**
  String editItem({required String item});

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'{set}重量'**
  String setWeight({required String set});

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'{set}次數'**
  String setReps({required String set});

  /// Checkbox label.
  ///
  /// In zh, this message translates to:
  /// **'{set}完成'**
  String setDone({required String set});

  /// Undo toast.
  ///
  /// In zh, this message translates to:
  /// **'已移除「{name}」'**
  String removedNamed({required String name});

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'課表名稱'**
  String get routineName;

  /// Destructive confirmation title.
  ///
  /// In zh, this message translates to:
  /// **'刪除「{name}」？'**
  String deleteNamedTitle({required String name});

  /// Consequence stated in the delete dialog.
  ///
  /// In zh, this message translates to:
  /// **'已完成的訓練紀錄會保留。'**
  String get routineDeleteKeeps;

  /// Destructive button.
  ///
  /// In zh, this message translates to:
  /// **'刪除這份課表'**
  String get deleteRoutine;

  /// Undo toast.
  ///
  /// In zh, this message translates to:
  /// **'已刪除「{name}」'**
  String deletedNamed({required String name});

  /// A routine's expected length.
  ///
  /// In zh, this message translates to:
  /// **'約 {minutes} 分'**
  String aboutMinutesShort({required int minutes});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'開始訓練'**
  String get startWorkout;

  /// Warning toast.
  ///
  /// In zh, this message translates to:
  /// **'運動進行中，先結束運動才能開始訓練'**
  String get activityBlocksWorkout;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'計畫的動作'**
  String get plannedExercises;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'今天酸痛的肌群'**
  String get soreMusclesToday;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'最近實際完成'**
  String get recentlyDone;

  /// A workout's size.
  ///
  /// In zh, this message translates to:
  /// **'{sets} 組 · {minutes} 分'**
  String setsAndMinutes({required int sets, required int minutes});

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'重新命名'**
  String get rename;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'上移'**
  String get moveUp;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'下移'**
  String get moveDown;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'與下一個組成超級組'**
  String get joinSuperset;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'解除超級組'**
  String get leaveSuperset;

  /// Menu.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeAction;

  /// Qualifier on a one-sided exercise.
  ///
  /// In zh, this message translates to:
  /// **'單邊'**
  String get eachSide;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'今天少 1 組'**
  String get oneSetLessToday;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'以上次的重量與次數填入'**
  String get loadPreviousFill;

  /// Segment.
  ///
  /// In zh, this message translates to:
  /// **'我的課表'**
  String get myRoutines;

  /// Segment.
  ///
  /// In zh, this message translates to:
  /// **'載入紀錄'**
  String get loadFromHistory;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'開始訓練（{count} 個動作）'**
  String startWorkoutCount({required int count});

  /// Button that drafts from a sentence.
  ///
  /// In zh, this message translates to:
  /// **'一句話'**
  String get describeInWords;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'手動新增動作'**
  String get addExercisesByHand;

  /// Swipe action.
  ///
  /// In zh, this message translates to:
  /// **'刪除'**
  String get deleteAction;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'刪除「{name}」'**
  String deleteNamed({required String name});

  /// Card.
  ///
  /// In zh, this message translates to:
  /// **'新增課表'**
  String get newRoutine;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有訓練紀錄'**
  String get noWorkouts;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'選擇全部'**
  String get selectAll;

  /// A done set; weight is formatted.
  ///
  /// In zh, this message translates to:
  /// **'{number} 組 {weight} kg {reps} 次'**
  String pastSet({
    required int number,
    required String weight,
    required int reps,
  });

  /// A routine's size.
  ///
  /// In zh, this message translates to:
  /// **'{exercises} 個動作 · {sets} 組'**
  String routineSummary({required int exercises, required int sets});

  /// Button and page title.
  ///
  /// In zh, this message translates to:
  /// **'存成課表'**
  String get saveAsRoutine;

  /// Hint in the workout description field.
  ///
  /// In zh, this message translates to:
  /// **'例如：\n槓鈴深蹲 4×8 60kg\n臥推 3 組 10 下 40 公斤\n引體向上 3x8'**
  String get describeWorkoutHint;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有讀到動作'**
  String get noExercisesRead;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'移除「{name}」'**
  String removeNamed({required String name});

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'找不到這個動作'**
  String get exerciseNotFound;

  /// Planned sets; weight formatted.
  ///
  /// In zh, this message translates to:
  /// **'{sets} 組 × {reps} 下 · {weight} kg'**
  String setsTimesReps({
    required int sets,
    required int reps,
    required String weight,
  });

  /// Planned sets; weight formatted; reps is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'{sets} 組 · {weight} kg × {reps} 下'**
  String setsSameWeight({
    required int sets,
    required String weight,
    required String reps,
  });

  /// Title.
  ///
  /// In zh, this message translates to:
  /// **'編輯訓練'**
  String get editWorkout;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'時間'**
  String get timeSection;

  /// Field.
  ///
  /// In zh, this message translates to:
  /// **'時長'**
  String get durationLabel;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已存成課表「{name}」'**
  String savedAsRoutine({required String name});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'維持原本'**
  String get keepAsIs;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'套用'**
  String get applyAction;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'加重'**
  String get progressionIncrease;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'維持'**
  String get progressionHold;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'退一階'**
  String get progressionDeload;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'下次的建議'**
  String get nextTimeSuggestions;

  /// Toast; weight formatted.
  ///
  /// In zh, this message translates to:
  /// **'{name} 改為 {weight} kg'**
  String changedTo({required String name, required String weight});

  /// Stepper label; amount formatted with unit.
  ///
  /// In zh, this message translates to:
  /// **'減少 {amount}'**
  String decreaseBy({required String amount});

  /// Stepper label; amount formatted with unit.
  ///
  /// In zh, this message translates to:
  /// **'增加 {amount}'**
  String increaseBy({required String amount});

  /// Stepper label.
  ///
  /// In zh, this message translates to:
  /// **'少 1 次'**
  String get oneRepLess;

  /// Stepper label.
  ///
  /// In zh, this message translates to:
  /// **'多 1 次'**
  String get oneRepMore;

  /// RIR chip for none.
  ///
  /// In zh, this message translates to:
  /// **'未記'**
  String get notLogged;

  /// Destructive action.
  ///
  /// In zh, this message translates to:
  /// **'刪除這一組'**
  String get deleteThisSet;

  /// Plate helper.
  ///
  /// In zh, this message translates to:
  /// **'槓片湊不出這個重量'**
  String get platesImpossible;

  /// Plate helper.
  ///
  /// In zh, this message translates to:
  /// **'空槓'**
  String get emptyBar;

  /// Plate helper; plates like 20 + 5.
  ///
  /// In zh, this message translates to:
  /// **'每邊 {plates}'**
  String platesPerSide({required String plates});

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 組重量'**
  String setNumberWeight({required int number});

  /// Field label.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 組次數'**
  String setNumberReps({required int number});

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'只替換今天'**
  String get replaceTodayOnly;

  /// Choice detail.
  ///
  /// In zh, this message translates to:
  /// **'只有這次用新動作'**
  String get replaceTodayOnlyDetail;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'也更新課表'**
  String get replaceInRoutine;

  /// Choice detail.
  ///
  /// In zh, this message translates to:
  /// **'之後都改用新動作'**
  String get replaceInRoutineDetail;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'今天改做「{name}」'**
  String replacedToday({required String name});

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'今天與之後的「{routine}」都改做「{name}」'**
  String replacedInRoutine({required String routine, required String name});

  /// Title.
  ///
  /// In zh, this message translates to:
  /// **'替換 {pattern}'**
  String replacePattern({required String pattern});

  /// Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'今天的「{routine}」· 第 {number} 個動作'**
  String todaysExerciseNumber({required String routine, required int number});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'替換'**
  String get replaceAction;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'候選動作'**
  String get candidateExercises;

  /// Card.
  ///
  /// In zh, this message translates to:
  /// **'從所有動作選擇'**
  String get chooseFromAll;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'套用範圍'**
  String get applyScope;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'{from}換{to}沒有可靠的重量換算：保留組數、次數與 RIR，重量重新設定。'**
  String equipmentChangeWarning({required String from, required String to});

  /// Tooltip.
  ///
  /// In zh, this message translates to:
  /// **'動作說明'**
  String get exerciseInfo;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有完成的訓練'**
  String get noFinishedWorkout;

  /// Figure.
  ///
  /// In zh, this message translates to:
  /// **'總量'**
  String get totalAmount;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'這次的負荷'**
  String get workloadSection;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'訓練部位'**
  String get trainedAreas;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天肌群組數'**
  String get muscleSetsLast7;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'編輯這筆紀錄'**
  String get editThisEntry;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'總量與上次相同'**
  String get volumeSame;

  /// Tag; change is signed.
  ///
  /// In zh, this message translates to:
  /// **'總量比上次 {change}%'**
  String volumeChangePercent({required String change});

  /// Caption; volume formatted.
  ///
  /// In zh, this message translates to:
  /// **'{sets} 組 · {volume} kg'**
  String setsAndVolume({required int sets, required String volume});

  /// A meal's figures confirmed by the user.
  ///
  /// In zh, this message translates to:
  /// **'已確認'**
  String get qualityConfirmed;

  /// A meal whose portion is a guess.
  ///
  /// In zh, this message translates to:
  /// **'份量為估計'**
  String get qualityPortionEstimated;

  /// Logged from a saved food.
  ///
  /// In zh, this message translates to:
  /// **'自訂食物'**
  String get qualityCustomFood;

  /// Logged without saving a food; also the quick-log page title.
  ///
  /// In zh, this message translates to:
  /// **'快速記錄'**
  String get qualityQuickLog;

  /// Logged from an AI draft.
  ///
  /// In zh, this message translates to:
  /// **'AI 估計'**
  String get qualityAiEstimate;

  /// Logged from an AI draft, naming which AI and model: `Ollama Cloud / gemma4:31b 估計`.
  ///
  /// In zh, this message translates to:
  /// **'{source} 估計'**
  String qualityAiEstimateBy({required String source});

  /// Scan choice, camera title and section.
  ///
  /// In zh, this message translates to:
  /// **'營養標示'**
  String get nutritionLabel;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'照片裡有 {count} 項'**
  String photoItemsCount({required int count});

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'合併成一個食物'**
  String get mergeIntoOneFood;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'逐項記錄'**
  String get logEachItem;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'營養素不能是負數。'**
  String get nutrientNegative;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已更新「{name}」'**
  String updatedNamed({required String name});

  /// Title.
  ///
  /// In zh, this message translates to:
  /// **'編輯這一餐'**
  String get editThisMeal;

  /// Title and button.
  ///
  /// In zh, this message translates to:
  /// **'新增食物'**
  String get newFood;

  /// Title.
  ///
  /// In zh, this message translates to:
  /// **'編輯食物'**
  String get editFood;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'掃描食物或營養標示'**
  String get scanFoodOrLabel;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'只建立'**
  String get createOnly;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'建立並記錄'**
  String get createAndLog;

  /// Warning after reading a label.
  ///
  /// In zh, this message translates to:
  /// **'數字來自 {provider}（{model}）的判讀，請對照包裝核對。'**
  String labelReadBy({required String provider, required String model});

  /// Warning after estimating a photo.
  ///
  /// In zh, this message translates to:
  /// **'數字是 {provider}（{model}）從照片的估算，請核對。'**
  String photoEstimatedBy({required String provider, required String model});

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如：雞胸肉'**
  String get foodNameHint;

  /// Field name used with optionalField.
  ///
  /// In zh, this message translates to:
  /// **'餐次'**
  String get mealTypeOptional;

  /// Switch.
  ///
  /// In zh, this message translates to:
  /// **'存入食物庫'**
  String get saveToLibrary;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'杯型'**
  String get cupSize;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如：Tall'**
  String get cupSizeHint;

  /// Field name used with optionalField.
  ///
  /// In zh, this message translates to:
  /// **'品牌'**
  String get brandLabel;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如：大成'**
  String get brandHint;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'食物或飲品'**
  String get foodOrDrink;

  /// Field.
  ///
  /// In zh, this message translates to:
  /// **'容量'**
  String get volumeLabel;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'份量'**
  String get portionSection;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如：一碗'**
  String get portionHint;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'新增杯型'**
  String get newCupSize;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'營養素'**
  String get nutrientsSection;

  /// Basis chip.
  ///
  /// In zh, this message translates to:
  /// **'每 100 {unit}'**
  String per100Unit({required String unit});

  /// Basis chip.
  ///
  /// In zh, this message translates to:
  /// **'一份總共'**
  String get perServingTotal;

  /// Field.
  ///
  /// In zh, this message translates to:
  /// **'酒精度'**
  String get abvLabel;

  /// Destructive row.
  ///
  /// In zh, this message translates to:
  /// **'刪除這一餐'**
  String get deleteThisMeal;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'台灣'**
  String get countryTW;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'日本'**
  String get countryJP;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'美國'**
  String get countryUS;

  /// Region.
  ///
  /// In zh, this message translates to:
  /// **'歐盟'**
  String get countryEU;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'澳洲'**
  String get countryAU;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'紐西蘭'**
  String get countryNZ;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'韓國'**
  String get countryKR;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'中國'**
  String get countryCN;

  /// Country.
  ///
  /// In zh, this message translates to:
  /// **'加拿大'**
  String get countryCA;

  /// A chain with the country its figures are for.
  ///
  /// In zh, this message translates to:
  /// **'{brand}（{country}）'**
  String brandInCountry({required String brand, required String country});

  /// Source of a chain's figures.
  ///
  /// In zh, this message translates to:
  /// **'官方資料'**
  String get officialData;

  /// When a catalogue was checked; date formatted.
  ///
  /// In zh, this message translates to:
  /// **'更新 {date}'**
  String updatedOn({required String date});

  /// Food list scope.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get foodScopeAll;

  /// Food list scope and section.
  ///
  /// In zh, this message translates to:
  /// **'最近'**
  String get foodScopeRecent;

  /// Food list scope and section.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get foodScopeStarred;

  /// Food list scope and section.
  ///
  /// In zh, this message translates to:
  /// **'自己的'**
  String get foodScopeOwn;

  /// Food list scope.
  ///
  /// In zh, this message translates to:
  /// **'品牌'**
  String get foodScopeBrands;

  /// Undo toast.
  ///
  /// In zh, this message translates to:
  /// **'已記錄「{name}」'**
  String loggedNamed({required String name});

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已記錄'**
  String get loggedToast;

  /// Screen-reader label of the meal-type button.
  ///
  /// In zh, this message translates to:
  /// **'這是哪一餐，目前{meal}'**
  String mealTypeHeaderLabel({required String meal});

  /// No meal type chosen.
  ///
  /// In zh, this message translates to:
  /// **'不指定'**
  String get unspecified;

  /// Search hint.
  ///
  /// In zh, this message translates to:
  /// **'搜尋食物或品牌'**
  String get searchFoodHint;

  /// Way in.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get takePhotoAction;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'近期用餐'**
  String get recentMealsSection;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有食物'**
  String get noFoods;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'吃過的食物'**
  String get eatenFoods;

  /// Empty banner.
  ///
  /// In zh, this message translates to:
  /// **'沒有最近吃過的食物。'**
  String get noRecentFoods;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'收藏的食物'**
  String get starredFoods;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'收藏的餐'**
  String get starredMeals;

  /// Empty banner.
  ///
  /// In zh, this message translates to:
  /// **'沒有收藏。'**
  String get noFavorites;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有自己的食物'**
  String get noOwnFoods;

  /// Empty banner.
  ///
  /// In zh, this message translates to:
  /// **'沒有內建的連鎖品牌。'**
  String get noBuiltInBrands;

  /// Row opening a chain's menu.
  ///
  /// In zh, this message translates to:
  /// **'{brand} · 查看完整菜單'**
  String viewFullMenu({required String brand});

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'沒有符合的項目'**
  String get noMatchingItems;

  /// Before the create link.
  ///
  /// In zh, this message translates to:
  /// **'找不到？'**
  String get notFoundQuestion;

  /// Section choosing lose, keep or gain weight.
  ///
  /// In zh, this message translates to:
  /// **'目的'**
  String get purposeSection;

  /// Undo toast.
  ///
  /// In zh, this message translates to:
  /// **'已合併 {count} 筆'**
  String mergedCount({required int count});

  /// Undo toast.
  ///
  /// In zh, this message translates to:
  /// **'已移除 {millilitres} mL 的水'**
  String removedWater({required int millilitres});

  /// Undo toast.
  ///
  /// In zh, this message translates to:
  /// **'已拆成獨立紀錄'**
  String get splitDone;

  /// Header action.
  ///
  /// In zh, this message translates to:
  /// **'合併'**
  String get mergeAction;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'合併幾筆紀錄'**
  String get mergeEntries;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'取消合併'**
  String get cancelMerge;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'合併成一餐'**
  String get mergeIntoMeal;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'合併 {count} 筆成一餐'**
  String mergeCountIntoMeal({required int count});

  /// Link.
  ///
  /// In zh, this message translates to:
  /// **'設定目標'**
  String get setGoal;

  /// Link.
  ///
  /// In zh, this message translates to:
  /// **'變更'**
  String get changeAction;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'每日指標'**
  String get dailyIndicators;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'餐點'**
  String get mealsSection;

  /// Link beside the meals section: shows each meal's share of the day's energy and daily indicators.
  ///
  /// In zh, this message translates to:
  /// **'佔比'**
  String get mealShare;

  /// Link beside the meals section, while shares are shown: hides them again.
  ///
  /// In zh, this message translates to:
  /// **'隱藏佔比'**
  String get mealShareHide;

  /// Empty state.
  ///
  /// In zh, this message translates to:
  /// **'這一天沒有記錄任何一餐'**
  String get noMealsThisDay;

  /// Section and row.
  ///
  /// In zh, this message translates to:
  /// **'水'**
  String get waterSection;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'移除 {time} 的水'**
  String removeWaterAt({required String time});

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'其他營養素'**
  String get otherNutrients;

  /// Items in a meal.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項'**
  String itemsCountShort({required int count});

  /// Chip.
  ///
  /// In zh, this message translates to:
  /// **'拆成獨立紀錄'**
  String get splitIntoEntry;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'{count} 筆沒有熱量，實際更多'**
  String entriesWithoutKcal({required int count});

  /// Screen-reader label; kcal formatted.
  ///
  /// In zh, this message translates to:
  /// **'已吃 {kcal} kcal'**
  String eatenKcal({required String kcal});

  /// Screen-reader label; figures formatted.
  ///
  /// In zh, this message translates to:
  /// **'已吃 {kcal} kcal，目標 {target} kcal'**
  String eatenOfTarget({required String kcal, required String target});

  /// Ring title.
  ///
  /// In zh, this message translates to:
  /// **'已吃 kcal'**
  String get eatenKcalTitle;

  /// Ring title.
  ///
  /// In zh, this message translates to:
  /// **'剩餘 kcal'**
  String get remainingKcalTitle;

  /// Ring title.
  ///
  /// In zh, this message translates to:
  /// **'超過 kcal'**
  String get overKcalTitle;

  /// Note beside a figure worked out from others.
  ///
  /// In zh, this message translates to:
  /// **'推算'**
  String get workedOut;

  /// Meter.
  ///
  /// In zh, this message translates to:
  /// **'估計殘留咖啡因'**
  String get caffeineRemaining;

  /// Note; hours is formatted.
  ///
  /// In zh, this message translates to:
  /// **'依半衰期 {hours} 小時推算'**
  String halfLifeBasis({required String hours});

  /// Label on the dashed bedtime reference line of the caffeine curve; mg is formatted.
  ///
  /// In zh, this message translates to:
  /// **'就寢參考 {mg} mg'**
  String caffeineReference({required String mg});

  /// Section label: records of the last 24 hours.
  ///
  /// In zh, this message translates to:
  /// **'近 24 小時'**
  String get last24Hours;

  /// A figure worked out from others; value formatted.
  ///
  /// In zh, this message translates to:
  /// **'{value} · 推算'**
  String workedOutValue({required String value});

  /// A cup size's caffeine; mg formatted.
  ///
  /// In zh, this message translates to:
  /// **'咖啡因 {mg} mg'**
  String caffeineValue({required String mg});

  /// Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'一份 = {serving}'**
  String oneServingIs({required String serving});

  /// Header action state.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get starred;

  /// Header action.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get starAction;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'收藏這個食物'**
  String get starThisFood;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'編輯這個食物'**
  String get editThisFood;

  /// Button; portion formatted.
  ///
  /// In zh, this message translates to:
  /// **'加入 {portion}'**
  String addPortion({required String portion});

  /// Field.
  ///
  /// In zh, this message translates to:
  /// **'份數'**
  String get servingsLabel;

  /// Field.
  ///
  /// In zh, this message translates to:
  /// **'實際份量'**
  String get actualAmount;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'條碼'**
  String get barcode;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'過敏原'**
  String get allergens;

  /// Declared as none.
  ///
  /// In zh, this message translates to:
  /// **'無'**
  String get none;

  /// Note.
  ///
  /// In zh, this message translates to:
  /// **'標示上限值，實際可能較低。'**
  String get valueTypeMaxNote;

  /// Line naming a food's source.
  ///
  /// In zh, this message translates to:
  /// **'資料來源：{source}'**
  String dataSource({required String source});

  /// Link.
  ///
  /// In zh, this message translates to:
  /// **'刪除這個食物'**
  String get deleteThisFood;

  /// Plate note.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項沒有熱量'**
  String itemsWithoutKcal({required int count});

  /// Plate title.
  ///
  /// In zh, this message translates to:
  /// **'這一餐'**
  String get thisMeal;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'完成編輯'**
  String get finishEditing;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'記錄 {count} 項'**
  String logItemsCount({required int count});

  /// Empty caption.
  ///
  /// In zh, this message translates to:
  /// **'這一餐沒有項目。'**
  String get plateEmpty;

  /// Title.
  ///
  /// In zh, this message translates to:
  /// **'照片估算'**
  String get photoEstimate;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'重試'**
  String get retry;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'先選一個 AI 才能產生草稿。'**
  String get chooseAiFirst;

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'食物照片'**
  String get foodPhoto;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如：早餐 蛋餅加大杯冰奶茶'**
  String get describeMealHint;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get draftSection;

  /// Button; me is the Me tab's name.
  ///
  /// In zh, this message translates to:
  /// **'到「{me} > AI」設定'**
  String openAiSettings({required String me});

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'每日熱量目標'**
  String get dailyKcalGoal;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'請填 800–6000 kcal。'**
  String get kcalRangeError;

  /// Error; min and max formatted.
  ///
  /// In zh, this message translates to:
  /// **'請填 {min}–{max}。'**
  String numberRangeError({required String min, required String max});

  /// Row and dialog title.
  ///
  /// In zh, this message translates to:
  /// **'每週變化'**
  String get weeklyChange;

  /// Page title.
  ///
  /// In zh, this message translates to:
  /// **'每日目標'**
  String get dailyTargets;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'熱量目標'**
  String get kcalTarget;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'依身體資料估算'**
  String get estimateFromBody;

  /// Choice detail.
  ///
  /// In zh, this message translates to:
  /// **'體重、身高、年齡、性別與活動量'**
  String get estimateFromBodyDetail;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'自己設定'**
  String get setMyself;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'身體資料'**
  String get bodyData;

  /// A year.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年'**
  String yearValue({required int year});

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'活動量'**
  String get activityLevelSection;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'營養素分配'**
  String get macroSplit;

  /// Default from the goal.
  ///
  /// In zh, this message translates to:
  /// **'依目的'**
  String get byGoal;

  /// Protein rate; grams formatted.
  ///
  /// In zh, this message translates to:
  /// **'每公斤體重 {grams} g'**
  String perKgBodyWeight({required String grams});

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'蛋白質（每公斤體重）'**
  String get proteinPerKgTitle;

  /// Hint; grams formatted.
  ///
  /// In zh, this message translates to:
  /// **'依目的 {grams} g'**
  String byGoalGrams({required String grams});

  /// Fat share.
  ///
  /// In zh, this message translates to:
  /// **'熱量的 {percent}%'**
  String percentOfKcal({required int percent});

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'脂肪（占熱量 %）'**
  String get fatPercentTitle;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'預設 {percent}%'**
  String defaultPercent({required int percent});

  /// Carb subtitle.
  ///
  /// In zh, this message translates to:
  /// **'其餘的熱量'**
  String get restOfKcal;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'結果'**
  String get resultSection;

  /// Figure.
  ///
  /// In zh, this message translates to:
  /// **'基礎代謝'**
  String get restingMetabolism;

  /// Figure.
  ///
  /// In zh, this message translates to:
  /// **'維持熱量'**
  String get maintenanceKcal;

  /// Figure.
  ///
  /// In zh, this message translates to:
  /// **'每日熱量'**
  String get dailyKcal;

  /// Why there is no figure; inputs is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'缺少{inputs}'**
  String missingInputs({required String inputs});

  /// A limit; value formatted with unit.
  ///
  /// In zh, this message translates to:
  /// **'上限 {value}'**
  String limitValue({required String value});

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'依近 {days} 天飲食與體重'**
  String fromRecentFoodAndWeight({required int days});

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'Mifflin-St Jeor 估計'**
  String get mifflinEstimate;

  /// Camera page.
  ///
  /// In zh, this message translates to:
  /// **'沒有可用的相機'**
  String get noCamera;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'從相簿選取'**
  String get pickFromLibrary;

  /// Food row; kcal formatted or a dash.
  ///
  /// In zh, this message translates to:
  /// **'一份 {serving} · {kcal} kcal'**
  String servingAndKcal({required String serving, required String kcal});

  /// Page title.
  ///
  /// In zh, this message translates to:
  /// **'食物庫'**
  String get foodLibrary;

  /// Empty caption.
  ///
  /// In zh, this message translates to:
  /// **'沒有自己的食物。'**
  String get noOwnFoodsSentence;

  /// Empty caption.
  ///
  /// In zh, this message translates to:
  /// **'沒有符合的食物。'**
  String get noMatchingFoods;

  /// Brand row detail.
  ///
  /// In zh, this message translates to:
  /// **'官方資料，唯讀'**
  String get officialReadOnly;

  /// Undo toast.
  ///
  /// In zh, this message translates to:
  /// **'已拆成 {count} 筆'**
  String splitIntoCount({required int count});

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'拆開這一餐'**
  String get splitThisMeal;

  /// Suggestion.
  ///
  /// In zh, this message translates to:
  /// **'常用：{meal}'**
  String usualMealType({required String meal});

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'這是哪一餐'**
  String get whichMeal;

  /// Sheet title.
  ///
  /// In zh, this message translates to:
  /// **'要把這道料理拆成 {count} 筆獨立紀錄嗎？'**
  String splitDishTitle({required int count});

  /// Consequence.
  ///
  /// In zh, this message translates to:
  /// **'拆開後每項成分各自成為一筆紀錄，可以單獨編輯、移到別餐或刪除，「{dish}」這一層就不存在了。'**
  String splitDishMessage({required String dish});

  /// Preview heading.
  ///
  /// In zh, this message translates to:
  /// **'現在'**
  String get nowLabel;

  /// Preview heading.
  ///
  /// In zh, this message translates to:
  /// **'拆開後'**
  String get afterSplit;

  /// Preview line.
  ///
  /// In zh, this message translates to:
  /// **'{count} 項成分'**
  String componentsCount({required int count});

  /// Preview line.
  ///
  /// In zh, this message translates to:
  /// **'其他 {count} 項'**
  String otherCount({required int count});

  /// Note.
  ///
  /// In zh, this message translates to:
  /// **'30 秒內可以復原。'**
  String get undoWithin30s;

  /// Water amount preset.
  ///
  /// In zh, this message translates to:
  /// **'一杯'**
  String get waterGlass;

  /// Water amount preset.
  ///
  /// In zh, this message translates to:
  /// **'大杯'**
  String get waterLargeGlass;

  /// Water amount preset.
  ///
  /// In zh, this message translates to:
  /// **'一瓶'**
  String get waterBottle;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'一次記多少'**
  String get waterPerTap;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'自訂'**
  String get customAction;

  /// Link beside a shortened list that opens the rest of it.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get moreAction;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'一次記多少 mL'**
  String get waterPerTapMl;

  /// Water: the daily amount the level fills towards.
  ///
  /// In zh, this message translates to:
  /// **'每日參考量'**
  String get waterReference;

  /// Title of the dialog typing a custom daily water reference.
  ///
  /// In zh, this message translates to:
  /// **'每日參考量 mL'**
  String get waterReferenceMl;

  /// The one line on the choice of a daily water reference.
  ///
  /// In zh, this message translates to:
  /// **'族群參考值，實際需求因人而異'**
  String get waterReferenceNote;

  /// Source tag: Taiwan Health Promotion Administration.
  ///
  /// In zh, this message translates to:
  /// **'國健署'**
  String get waterReferenceHpa;

  /// Choice: no daily water reference, so no level.
  ///
  /// In zh, this message translates to:
  /// **'不設定'**
  String get waterReferenceNone;

  /// Warning when a lot of water is logged within an hour; millilitres formatted.
  ///
  /// In zh, this message translates to:
  /// **'1 小時內已記錄 {millilitres} mL。短時間大量喝水可能造成低血鈉，請分次慢慢喝。'**
  String waterFastWarning({required String millilitres});

  /// Screen-reader label.
  ///
  /// In zh, this message translates to:
  /// **'一次記多少，目前 {millilitres} 毫升'**
  String waterPerTapLabel({required int millilitres});

  /// Water line.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次 · 最近 {time}'**
  String waterTimesLast({required int count, required String time});

  /// Link.
  ///
  /// In zh, this message translates to:
  /// **'飲品總量 {millilitres} mL（含咖啡、茶等）'**
  String allDrinksTotal({required int millilitres});

  /// When a meal was eaten.
  ///
  /// In zh, this message translates to:
  /// **'今天 {time}'**
  String todayAt({required String time});

  /// When a meal was eaten.
  ///
  /// In zh, this message translates to:
  /// **'昨天 {time}'**
  String yesterdayAt({required String time});

  /// Tooltip.
  ///
  /// In zh, this message translates to:
  /// **'加入{name}'**
  String addNamed({required String name});

  /// Section listing what a meal holds.
  ///
  /// In zh, this message translates to:
  /// **'內容'**
  String get contentsSection;

  /// Setting choosing the muscle map's body.
  ///
  /// In zh, this message translates to:
  /// **'人體圖'**
  String get muscleMapSetting;

  /// What the nutrition-label choice changes.
  ///
  /// In zh, this message translates to:
  /// **'每日總計的名稱、鹽分單位與上限；食物頁照它自己的標示。'**
  String get conventionMessage;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'個人資料'**
  String get profileSection;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'目標與提醒'**
  String get goalsAndReminders;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'功能'**
  String get featuresSection;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'瀏覽、搜尋與建立自訂動作'**
  String get exerciseLibraryDetail;

  /// Row subtitle; modules is a joined list.
  ///
  /// In zh, this message translates to:
  /// **'{modules} 已啟用'**
  String modulesEnabled({required String modules});

  /// State.
  ///
  /// In zh, this message translates to:
  /// **'未啟用'**
  String get notEnabled;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'資料'**
  String get dataSection;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'上次的資料檔無法讀取，已移到 {path}，並從空白重新開始。舊檔案沒有被刪除。'**
  String databaseRecovered({required String path});

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'本機資料'**
  String get localData;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'手動輸入、匯入與內建目錄'**
  String get dataSourcesDetail;

  /// Switch.
  ///
  /// In zh, this message translates to:
  /// **'顯示示範資料'**
  String get showDemoData;

  /// Row and page title.
  ///
  /// In zh, this message translates to:
  /// **'匯出'**
  String get exportTitle;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'完整封存 JSON · CSV 檢視'**
  String get exportDetail;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'資料存在哪裡、會送出什麼'**
  String get privacyDetail;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'關於'**
  String get aboutSection;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get versionLabel;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'動作圖'**
  String get exerciseImages;

  /// Row and page title.
  ///
  /// In zh, this message translates to:
  /// **'文獻來源'**
  String get referencesTitle;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'開源授權'**
  String get openSourceLicenses;

  /// Figure.
  ///
  /// In zh, this message translates to:
  /// **'訓練'**
  String get workoutsFigure;

  /// Figure.
  ///
  /// In zh, this message translates to:
  /// **'運動日'**
  String get activeDaysFigure;

  /// Unit.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get daysUnit;

  /// Unit.
  ///
  /// In zh, this message translates to:
  /// **'週'**
  String get weeksUnit;

  /// Figure.
  ///
  /// In zh, this message translates to:
  /// **'開始紀錄'**
  String get startedLogging;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'每週 {target} 個運動日 · 本週 {active}'**
  String goalSummaryText({required int target, required int active});

  /// Row detail; grams is formatted.
  ///
  /// In zh, this message translates to:
  /// **'蛋白質 {grams} g'**
  String proteinGrams({required String grams});

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'自己的 {own} 種 · 品牌 {brands} 家'**
  String foodLibrarySummary({required int own, required int brands});

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如 1995'**
  String get birthYearHint;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'出生年請填 4 位數西元年。'**
  String get birthYearError;

  /// Consequence in the dialog.
  ///
  /// In zh, this message translates to:
  /// **'只用來估算每日熱量。'**
  String get sexUseMessage;

  /// Export choice.
  ///
  /// In zh, this message translates to:
  /// **'完整封存（JSON）'**
  String get fullArchiveJson;

  /// Export choice detail.
  ///
  /// In zh, this message translates to:
  /// **'可完整還原'**
  String get fullArchiveDetail;

  /// Toast prefix.
  ///
  /// In zh, this message translates to:
  /// **'已建立完整封存'**
  String get fullArchiveDone;

  /// Export choice.
  ///
  /// In zh, this message translates to:
  /// **'CSV 檢視'**
  String get csvViews;

  /// Export choice detail.
  ///
  /// In zh, this message translates to:
  /// **'方便閱讀，不保證無損'**
  String get csvViewsDetail;

  /// Toast prefix.
  ///
  /// In zh, this message translates to:
  /// **'已建立 CSV 檢視'**
  String get csvViewsDone;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'匯出的檔案沒有加密。'**
  String get exportNotEncrypted;

  /// Toast naming the written file.
  ///
  /// In zh, this message translates to:
  /// **'{done}：{file}'**
  String exportDoneFile({required String done, required String file});

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'匯出失敗：{error}'**
  String exportFailed({required String error});

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已套用到「{routine}」'**
  String appliedTo({required String routine});

  /// Title.
  ///
  /// In zh, this message translates to:
  /// **'AI 建議的修改'**
  String get aiProposalTitle;

  /// Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'訓練「{routine}」· 尚未套用'**
  String aiProposalSubtitle({required String routine});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'拒絕'**
  String get reject;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'接受並套用'**
  String get acceptAndApply;

  /// Heading.
  ///
  /// In zh, this message translates to:
  /// **'提問'**
  String get questionLabel;

  /// The user's question in the demo proposal.
  ///
  /// In zh, this message translates to:
  /// **'「最近深蹲的組數是不是太少了？幫我加回來。」'**
  String get proposalQuestion;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'改動 {count} 個動作'**
  String changesCount({required int count});

  /// Heading.
  ///
  /// In zh, this message translates to:
  /// **'理由'**
  String get reasonLabel;

  /// The demo proposal's reason.
  ///
  /// In zh, this message translates to:
  /// **'每週工作組數從 12 降到 8，依「肌力維持」目標，訓練引擎建議的區間是 10 – 12 組。'**
  String get proposalReason;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'送出的資料：近 4 週訓練紀錄'**
  String get proposalDataSent;

  /// Tag.
  ///
  /// In zh, this message translates to:
  /// **'模型：自架端點'**
  String get proposalModel;

  /// Change kind.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get addedLabel;

  /// Change kind.
  ///
  /// In zh, this message translates to:
  /// **'不變'**
  String get unchangedLabel;

  /// A prescription.
  ///
  /// In zh, this message translates to:
  /// **'{sets} 組 × {reps} 次'**
  String setsTimesRepsShort({required int sets, required int reps});

  /// Privacy section.
  ///
  /// In zh, this message translates to:
  /// **'儲存'**
  String get privacyStorage;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'紀錄'**
  String get privacyRecords;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'只在這台裝置'**
  String get privacyRecordsValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'帳號'**
  String get privacyAccount;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'伺服器'**
  String get privacyServer;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'刪除的紀錄'**
  String get privacyDeleted;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'可復原'**
  String get privacyDeletedValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'解除安裝 App'**
  String get privacyUninstall;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'清除所有紀錄'**
  String get privacyUninstallValue;

  /// Privacy section.
  ///
  /// In zh, this message translates to:
  /// **'相機與相簿'**
  String get privacyCameraSection;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'相機'**
  String get privacyCamera;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'只在掃描時開啟'**
  String get privacyCameraValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'相簿'**
  String get privacyPhotos;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'讀取最新一張做為選取按鈕的縮圖'**
  String get privacyPhotosValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'體脂計與圍度照片'**
  String get privacyScalePhotos;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'在裝置上讀取數字，不送出'**
  String get privacyScalePhotosValue;

  /// Privacy section.
  ///
  /// In zh, this message translates to:
  /// **'健康資料（{platform}）'**
  String privacyHealthSection({required String platform});

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'權限'**
  String get privacyPermission;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'讀取與寫入'**
  String get privacyPermissionValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'讀取'**
  String get privacyReading;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'第一次讀取全部紀錄，之後開啟 App 時讀取最近 30 天'**
  String get privacyReadingValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'送出裝置'**
  String get privacyLeavesDevice;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get privacyNo;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'提供給 AI'**
  String get privacyToAi;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'用於廣告'**
  String get privacyAds;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'中斷連接後'**
  String get privacyDisconnect;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'已讀入的紀錄保留'**
  String get privacyDisconnectValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'讀取類別'**
  String get privacyKinds;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'預設'**
  String get privacyDefault;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'不使用'**
  String get privacyNotUsed;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'在裝置上執行'**
  String get privacyAppleIntelligence;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'雲端 AI 收到'**
  String get privacyCloudReceives;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'輸入的文字、照片辨識出的文字、估算用的食物照片'**
  String get privacyCloudReceivesValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'食物照片'**
  String get privacyFoodPhotos;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'先移除位置與拍攝資訊，不保存'**
  String get privacyFoodPhotosValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'其他照片、其他紀錄、健康資料'**
  String get privacyOtherData;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'不送出'**
  String get privacyNotSent;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'第一次送出文字或照片前'**
  String get privacyFirstSend;

  /// Privacy value; me is the Me tab's name.
  ///
  /// In zh, this message translates to:
  /// **'分別詢問同意，可在「{me} > AI」撤回'**
  String privacyFirstSendValue({required String me});

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'AI 的結果'**
  String get privacyAiResults;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'草稿，確認後才記錄'**
  String get privacyAiResultsValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'Google AI Studio 免費額度'**
  String get privacyGoogleFree;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'內容可能用於改進產品並經人工審閱'**
  String get privacyGoogleFreeValue;

  /// Privacy section.
  ///
  /// In zh, this message translates to:
  /// **'金鑰與匯出'**
  String get privacyKeysSection;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'API 金鑰'**
  String get privacyApiKeys;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'系統安全儲存區，不進資料庫'**
  String get privacyApiKeysValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'匯出檔案'**
  String get privacyExportFiles;

  /// Privacy value; me is the Me tab's name.
  ///
  /// In zh, this message translates to:
  /// **'只在「{me} > 匯出」手動建立'**
  String privacyExportFilesValue({required String me});

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'匯出內容'**
  String get privacyExportContents;

  /// Privacy value.
  ///
  /// In zh, this message translates to:
  /// **'不含 API 金鑰'**
  String get privacyExportContentsValue;

  /// Privacy row.
  ///
  /// In zh, this message translates to:
  /// **'上傳'**
  String get privacyUpload;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'基礎代謝的估算公式'**
  String get refUse01;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'健康成人以 Mifflin-St Jeor 估算最接近實測'**
  String get refUse02;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'活動量（身體活動程度）的分級'**
  String get refUse03;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'維持與增肌的蛋白質，每公斤 1.6–1.8 g（範圍 1.4–2.0 g）'**
  String get refUse04;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'減脂每週 0.5–1% 體重、提高蛋白質、脂肪占熱量 15–30%'**
  String get refUse05;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'減脂的蛋白質每公斤 2.2 g'**
  String get refUse06;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'減脂預設每週 0.5% 體重，慢一點保留較多去脂體重'**
  String get refUse07;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'增肌只用小盈餘，預設每週 0.25% 體重'**
  String get refUse08;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'每公斤體重約 7,700 kcal 只是粗略的起點'**
  String get refUse09;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'膳食纖維每 1,000 kcal 14 g、脂肪占熱量 20–35%'**
  String get refUse10;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'台灣：成人每日鈉 2,400 mg 以下'**
  String get refUse11;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'日本：成人每日食塩相当量男性 7.5 g、女性 6.5 g 以下'**
  String get refUse12;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'日本標示：食塩相当量（g）＝鈉（mg）× 2.54 ÷ 1,000'**
  String get refUse13;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'美國、加拿大：成人每日鈉 2,300 mg 以下'**
  String get refUse14;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'歐盟：成人每日鈉 2.0 g，即鹽 5 g'**
  String get refUse15;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'歐盟標示：碳水化合物不含膳食纖維；鹽＝鈉 × 2.5'**
  String get refUse16;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'澳洲、紐西蘭：成人每日鈉 2,000 mg'**
  String get refUse17;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'澳洲、紐西蘭標示：碳水化合物不含膳食纖維，能量以 kJ 標示'**
  String get refUse18;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'韓國：成人每日鈉 2,300 mg 以下'**
  String get refUse19;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'中國：成人每日食鹽 5 g 以下'**
  String get refUse20;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'殘留咖啡因依半衰期 5 小時推算'**
  String get refUse21;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'半衰期因人而異，推算值不是量測'**
  String get refUse22;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'睡前 4 小時 100 mg 未測得影響，參考線不是安全門檻'**
  String get refUse23;

  /// What Gardiner et al. (2023) support.
  ///
  /// In zh, this message translates to:
  /// **'35 mg 參考線由睡前 8.8 小時 107 mg、13.2 小時 217.5 mg 推算'**
  String get refUse46;

  /// What 國健署 (2021) supports.
  ///
  /// In zh, this message translates to:
  /// **'每日參考量 1,500 mL，只計白開水'**
  String get refUse47;

  /// What the Institute of Medicine (2005) supports.
  ///
  /// In zh, this message translates to:
  /// **'腎臟每小時約可排出 0.7–1.0 L，1 小時內 1,000 mL 以上時提醒'**
  String get refUse48;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'未設定目標時以每晚 8 小時計（共識為 7 小時以上）'**
  String get refUse24;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'少睡的影響在 14 天內持續累積'**
  String get refUse25;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'多睡不以一比一抵銷少睡'**
  String get refUse26;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'恢復沒有公認的速率，不設衰減'**
  String get refUse27;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'估計最大重量（1RM）的公式'**
  String get refUse28;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'超過 10 下不估計；5 下最準'**
  String get refUse29;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'7–10 下的估計仍準確'**
  String get refUse30;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'次數越多，個人與動作之間的差異越大'**
  String get refUse31;

  /// What the 2009 ACSM position stand supports.
  ///
  /// In zh, this message translates to:
  /// **'以 %1RM 表示訓練負荷'**
  String get refUse42;

  /// What the 2026 ACSM position stand supports.
  ///
  /// In zh, this message translates to:
  /// **'以 %1RM 表示負荷的更新指引'**
  String get refUse43;

  /// What Pelland et al. (2022) support.
  ///
  /// In zh, this message translates to:
  /// **'負荷與接近力竭程度是不同變數'**
  String get refUse44;

  /// What Zourdos et al. (2016) support.
  ///
  /// In zh, this message translates to:
  /// **'以剩餘次數（RIR）表示接近力竭程度'**
  String get refUse45;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'每肌群每週 10 組以上的組數劑量反應'**
  String get refUse32;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'蛋白質每公斤 1.6 g 後增益不再明顯'**
  String get refUse33;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'最大心率以 208 − 0.7 × 年齡估算'**
  String get refUse34;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'有安靜心率時以心率儲備劃分區間'**
  String get refUse35;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'BMI 過輕、正常、過重、肥胖的分級'**
  String get refUse36;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'去脂體重指數（FFMI）的定義'**
  String get refUse37;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'增肌減脂只用小赤字：每天約 500 kcal 時瘦體重不再增加'**
  String get refUse38;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'增肌減脂可選小赤字或維持熱量，搭配高蛋白質'**
  String get refUse39;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'增肌減脂在維持熱量時蛋白質每公斤 2.0 g'**
  String get refUse40;

  /// What a reference supports.
  ///
  /// In zh, this message translates to:
  /// **'增肌減脂的蛋白質以 BMI 30 的體重為上限'**
  String get refUse41;

  /// References section.
  ///
  /// In zh, this message translates to:
  /// **'每日熱量與營養素目標'**
  String get refSectionTargets;

  /// References section.
  ///
  /// In zh, this message translates to:
  /// **'營養標示'**
  String get refSectionLabels;

  /// References section.
  ///
  /// In zh, this message translates to:
  /// **'咖啡因'**
  String get refSectionCaffeine;

  /// References section.
  ///
  /// In zh, this message translates to:
  /// **'睡眠債'**
  String get refSectionSleepDebt;

  /// References section.
  ///
  /// In zh, this message translates to:
  /// **'訓練與趨勢'**
  String get refSectionTraining;

  /// References section.
  ///
  /// In zh, this message translates to:
  /// **'運動心率區間'**
  String get refSectionHeartZones;

  /// References section.
  ///
  /// In zh, this message translates to:
  /// **'身體'**
  String get refSectionBody;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'開啟連結'**
  String get openLink;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'開啟'**
  String get openAction;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'無法開啟連結'**
  String get cannotOpenLink;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'{provider} API 金鑰'**
  String apiKeyTitle({required String provider});

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'貼上金鑰，留空即刪除'**
  String get apiKeyHint;

  /// Row and dialog title.
  ///
  /// In zh, this message translates to:
  /// **'API 位址'**
  String get apiEndpoint;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'Azure AI Foundry 資源網址'**
  String get azureResourceUrl;

  /// Row and dialog title.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get modelLabel;

  /// Dialog message.
  ///
  /// In zh, this message translates to:
  /// **'讀不到模型清單，請直接輸入名稱。'**
  String get modelListUnavailable;

  /// Choice.
  ///
  /// In zh, this message translates to:
  /// **'自己輸入'**
  String get typeOwn;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'部署名稱'**
  String get deploymentName;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'例如 gemini-3.8-flash'**
  String get modelHint;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'在瀏覽器登入'**
  String get signInInBrowser;

  /// Instructions.
  ///
  /// In zh, this message translates to:
  /// **'到 {uri} 輸入代碼 {code}，以公司或學校帳號登入。'**
  String signInInstructions({required String uri, required String code});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'複製代碼'**
  String get copyCode;

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'好'**
  String get okAction;

  /// Toast.
  ///
  /// In zh, this message translates to:
  /// **'已登入 Microsoft 365 Copilot'**
  String get signedInCopilot;

  /// Row and dialog title.
  ///
  /// In zh, this message translates to:
  /// **'用戶端 ID'**
  String get clientId;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'Entra 應用程式註冊的 Application (client) ID'**
  String get clientIdHint;

  /// Row and dialog title.
  ///
  /// In zh, this message translates to:
  /// **'租用戶'**
  String get tenant;

  /// Hint.
  ///
  /// In zh, this message translates to:
  /// **'留空代表 organizations'**
  String get tenantHint;

  /// Dialog title.
  ///
  /// In zh, this message translates to:
  /// **'撤回同意？'**
  String get revokeConsentTitle;

  /// Consequence.
  ///
  /// In zh, this message translates to:
  /// **'下次使用雲端 AI 前會再次詢問。'**
  String get revokeConsentMessage;

  /// Destructive button and row.
  ///
  /// In zh, this message translates to:
  /// **'撤回同意'**
  String get revokeConsent;

  /// Section.
  ///
  /// In zh, this message translates to:
  /// **'服務'**
  String get serviceSection;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'已登入'**
  String get signedIn;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'登入'**
  String get signIn;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'等待瀏覽器登入…'**
  String get waitingForBrowser;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'重新登入'**
  String get signInAgain;

  /// Row.
  ///
  /// In zh, this message translates to:
  /// **'API 金鑰'**
  String get apiKey;

  /// State.
  ///
  /// In zh, this message translates to:
  /// **'已設定'**
  String get isSet;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'讀取模型…'**
  String get loadingModels;

  /// State.
  ///
  /// In zh, this message translates to:
  /// **'未選擇'**
  String get notChosen;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'目前已同意送出文字與照片'**
  String get consentTextAndPhotos;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'目前已同意送出文字'**
  String get consentText;

  /// Row subtitle.
  ///
  /// In zh, this message translates to:
  /// **'目前已同意送出照片'**
  String get consentPhotos;

  /// Status.
  ///
  /// In zh, this message translates to:
  /// **'檢查中…'**
  String get checkingEllipsis;

  /// Status.
  ///
  /// In zh, this message translates to:
  /// **'這台裝置不支援 Apple Intelligence'**
  String get appleNotEligible;

  /// Status.
  ///
  /// In zh, this message translates to:
  /// **'到「設定 > Apple Intelligence 與 Siri」開啟'**
  String get appleNotEnabled;

  /// Status.
  ///
  /// In zh, this message translates to:
  /// **'模型下載中'**
  String get appleModelNotReady;

  /// Status.
  ///
  /// In zh, this message translates to:
  /// **'需要 iOS 26 以上且支援 Apple Intelligence'**
  String get appleUnavailable;

  /// Where an Azure key is created.
  ///
  /// In zh, this message translates to:
  /// **'Azure 入口網站'**
  String get azurePortal;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'Beta API，不支援正式產品。需要公司或學校帳號、Microsoft 365 Copilot 授權與 Entra 應用程式註冊。'**
  String get copilotWarning;

  /// Warning.
  ///
  /// In zh, this message translates to:
  /// **'免費額度的內容可能被 Google 用於改進產品並經人工審閱。請使用已啟用計費的金鑰。'**
  String get googleFreeWarning;

  /// Fallback provider name.
  ///
  /// In zh, this message translates to:
  /// **'雲端 AI'**
  String get cloudAi;

  /// Consent title.
  ///
  /// In zh, this message translates to:
  /// **'送到 {provider}？'**
  String sendToProvider({required String provider});

  /// Consent message; me is the Me tab's name.
  ///
  /// In zh, this message translates to:
  /// **'只送出輸入的文字或從照片辨識出的文字，不送出照片與其他紀錄。可在「{me} > AI」撤回。'**
  String cloudConsentMessage({required String me});

  /// Button.
  ///
  /// In zh, this message translates to:
  /// **'同意並送出'**
  String get agreeAndSend;

  /// Consent title.
  ///
  /// In zh, this message translates to:
  /// **'送出食物照片到 {provider}？'**
  String sendPhotoToProvider({required String provider});

  /// Consent message; me is the Me tab's name.
  ///
  /// In zh, this message translates to:
  /// **'只送出這張照片與補充說明，先移除照片裡的位置與拍攝資訊，不保存照片。可在「{me} > AI」撤回。'**
  String photoConsentMessage({required String me});

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'AI 功能尚未設定，到「{me} > AI」設定。'**
  String aiFailureUnavailable({required String me});

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'未同意送出文字。'**
  String get aiFailureNeedsConsent;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'金鑰無效或沒有權限，到「{me} > AI」重新設定。'**
  String aiFailureAuthentication({required String me});

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'請求太頻繁或額度用完，稍後再試。'**
  String get aiFailureRateLimited;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'連不上網路，稍後再試。'**
  String get aiFailureNetwork;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'AI 服務出了問題，稍後再試。'**
  String get aiFailureProvider;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'AI 的回覆無法解讀，再試一次。'**
  String get aiFailureUnreadable;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'未同意送出照片。'**
  String get aiFailureNeedsPhotoConsent;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'目前的 AI 不能讀照片，到「{me} > AI」換一個。'**
  String aiFailurePhotoUnsupported({required String me});

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'照片裡看不到食物或飲料，換一張再試。'**
  String get aiFailureNoFood;

  /// Error.
  ///
  /// In zh, this message translates to:
  /// **'這張照片的格式無法讀取，換一張再試。'**
  String get aiFailurePhotoFormat;

  /// Baseline range.
  ///
  /// In zh, this message translates to:
  /// **'前 4 週'**
  String get prior4Weeks;

  /// What a change is set against.
  ///
  /// In zh, this message translates to:
  /// **'比{baseline}'**
  String againstBaseline({required String baseline});

  /// What a change is set against.
  ///
  /// In zh, this message translates to:
  /// **'{recent}比{baseline}'**
  String againstRecentBaseline({
    required String recent,
    required String baseline,
  });

  /// A change upward; amount formatted.
  ///
  /// In zh, this message translates to:
  /// **'{against}多 {amount}'**
  String changeMore({required String against, required String amount});

  /// A change downward; amount formatted.
  ///
  /// In zh, this message translates to:
  /// **'{against}少 {amount}'**
  String changeLess({required String against, required String amount});

  /// Relation; percent formatted.
  ///
  /// In zh, this message translates to:
  /// **'前一晚睡得較久的訓練，訓練量平均多 {percent}。'**
  String sleepLoadMore({required String percent});

  /// Relation; percent formatted.
  ///
  /// In zh, this message translates to:
  /// **'前一晚睡得較久的訓練，訓練量平均少 {percent}。'**
  String sleepLoadLess({required String percent});

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次訓練'**
  String workoutsCount({required int count});

  /// Evidence; time formatted.
  ///
  /// In zh, this message translates to:
  /// **'以 {time} 區分睡得較久或較少'**
  String sleepSplitAt({required String time});

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'與同一訓練的平均相比'**
  String get againstSameWorkout;

  /// Trend line change; change signed.
  ///
  /// In zh, this message translates to:
  /// **'4 週 {change} kg'**
  String weightChange4Weeks({required String change});

  /// Trend line change; count formatted.
  ///
  /// In zh, this message translates to:
  /// **'{baseline} {count} 次'**
  String baselineTimes({required String baseline, required String count});

  /// Food completeness.
  ///
  /// In zh, this message translates to:
  /// **'完整 {complete}/{tracked} 天'**
  String completeDays({required int complete, required int tracked});

  /// Steps a day; steps formatted.
  ///
  /// In zh, this message translates to:
  /// **'每天 {steps} 步'**
  String perDaySteps({required String steps});

  /// Insight.
  ///
  /// In zh, this message translates to:
  /// **'體重在這段期間大致持平，沒有明顯變化。'**
  String get weightSteady;

  /// Insight; kg formatted.
  ///
  /// In zh, this message translates to:
  /// **'體重以每週約 {kg} kg 的速度下降。'**
  String weightFalling({required String kg});

  /// Insight; kg formatted.
  ///
  /// In zh, this message translates to:
  /// **'體重以每週約 {kg} kg 的速度上升。'**
  String weightRising({required String kg});

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'依據 {count} 筆體重紀錄'**
  String basedOnWeights({required int count});

  /// Insight.
  ///
  /// In zh, this message translates to:
  /// **'這是本週第 {count} 次訓練，達成每週 {goal} 次的目標。'**
  String trainingGoalMet({required int count, required int goal});

  /// Insight.
  ///
  /// In zh, this message translates to:
  /// **'本週已完成 {count} 次訓練，距離每週 {goal} 次還差 {left} 次。'**
  String trainingGoalShort({
    required int count,
    required int goal,
    required int left,
  });

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'依據本週訓練紀錄'**
  String get basedOnThisWeek;

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'每週目標 {goal} 次'**
  String weeklyGoalTimes({required int goal});

  /// Insight.
  ///
  /// In zh, this message translates to:
  /// **'{exercise}的每週組數從 {first} 組掉到 {last} 組，估計最大重量沒有跟著掉。'**
  String volumeDropMaxHolding({
    required String exercise,
    required int first,
    required int last,
  });

  /// Insight.
  ///
  /// In zh, this message translates to:
  /// **'{exercise}的每週組數從 {first} 組掉到 {last} 組，估計最大重量也跟著下降。'**
  String volumeDropMaxFalling({
    required String exercise,
    required int first,
    required int last,
  });

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'依據 {count} 次訓練紀錄'**
  String basedOnWorkouts({required int count});

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'不含熱身組'**
  String get excludesWarmups;

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'資料完整'**
  String get dataComplete;

  /// Evidence.
  ///
  /// In zh, this message translates to:
  /// **'資料不完整，只有 {points} / {days} 天有紀錄'**
  String dataIncomplete({required int points, required int days});

  /// Window.
  ///
  /// In zh, this message translates to:
  /// **'近 {count} 週'**
  String lastWeeksCount({required int count});

  /// Window.
  ///
  /// In zh, this message translates to:
  /// **'近 {count} 天'**
  String lastDaysCount({required int count});

  /// Suggestion reason.
  ///
  /// In zh, this message translates to:
  /// **'連續 {count} 次沒做到 {reps} 下，先退一階把次數做滿。'**
  String progressionDeloadReason({required int count, required int reps});

  /// Suggestion reason; sets like 3 × 5.
  ///
  /// In zh, this message translates to:
  /// **'上次 {sets}，未做到 {reps} 下，先維持同重量。'**
  String progressionMissedReps({required String sets, required int reps});

  /// Suggestion reason.
  ///
  /// In zh, this message translates to:
  /// **'上次只做了 {done} 組，先把 {planned} 組做滿再加重。'**
  String progressionMissedSets({required int done, required int planned});

  /// Suggestion reason.
  ///
  /// In zh, this message translates to:
  /// **'上次做滿了，但那次訓練評為太吃力，先維持同重量。'**
  String get progressionTooHard;

  /// Suggestion reason.
  ///
  /// In zh, this message translates to:
  /// **'上次做滿了，但最後一組已經接近極限（RIR {rir}），先維持同重量。'**
  String progressionNearLimit({required String rir});

  /// Suggestion reason; reserve is empty or the next message.
  ///
  /// In zh, this message translates to:
  /// **'上次 {done} 做滿了 {planned}{reserve}，可以加 {added} kg。'**
  String progressionIncreaseReason({
    required String done,
    required String planned,
    required String reserve,
    required String added,
  });

  /// Part of the increase reason.
  ///
  /// In zh, this message translates to:
  /// **'，最後一組還留 {rir} 下'**
  String progressionReserve({required String rir});

  /// A total while some meals lack the figure.
  ///
  /// In zh, this message translates to:
  /// **'至少 {value}'**
  String atLeastValue({required String value});

  /// The Apple Health app's name.
  ///
  /// In zh, this message translates to:
  /// **'Apple 健康'**
  String get appleHealth;

  /// Android's Health Connect's name.
  ///
  /// In zh, this message translates to:
  /// **'健康資料同步'**
  String get healthConnectName;

  /// Where there is no health platform.
  ///
  /// In zh, this message translates to:
  /// **'健康資料'**
  String get healthDataGeneric;

  /// Name of an imported workout that had none.
  ///
  /// In zh, this message translates to:
  /// **'Strong 訓練'**
  String get strongWorkoutName;

  /// Section showing the meal a merge makes.
  ///
  /// In zh, this message translates to:
  /// **'合併後'**
  String get afterMerge;

  /// Button that takes a meal apart.
  ///
  /// In zh, this message translates to:
  /// **'拆開'**
  String get splitAction;

  /// Way in to drafting a meal from a photo, words or both, and that page's title.
  ///
  /// In zh, this message translates to:
  /// **'AI 草稿'**
  String get aiDraftAction;

  /// Takes the photo off an AI draft before it is sent.
  ///
  /// In zh, this message translates to:
  /// **'移除照片'**
  String get removePhoto;

  /// Privacy fact label.
  ///
  /// In zh, this message translates to:
  /// **'網路搜尋'**
  String get privacyWebSearch;

  /// Privacy fact: which providers search the web while drafting.
  ///
  /// In zh, this message translates to:
  /// **'Anthropic、Google AI Studio 依內容搜尋公開的營養資料'**
  String get privacyWebSearchValue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
