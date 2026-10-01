// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appLanguage => '繁體中文';

  @override
  String get meLanguageRow => '語言';

  @override
  String get meSettingsOpenFailed => '無法開啟設定';

  @override
  String get commonUndo => '復原';

  @override
  String get commonSearch => '搜尋';

  @override
  String get commonCloseSearch => '關閉搜尋';

  @override
  String get commonBack => '返回';

  @override
  String get commonClose => '關閉';

  @override
  String get commonSave => '儲存';

  @override
  String get commonCancel => '取消';

  @override
  String get insightCardTitle => '值得注意';

  @override
  String get monthPickerPreviousYear => '上一年';

  @override
  String get monthPickerNextYear => '下一年';

  @override
  String get monthPickerClose => '關閉月份選擇';

  @override
  String get monthPickerYear => '年份';

  @override
  String get monthPickerMonth => '月份';

  @override
  String dayStripHasRecords({required String date}) {
    return '$date，有紀錄';
  }

  @override
  String get moduleNutrition => '飲食';

  @override
  String get moduleNutritionDescription => '一餐、料理、成分與營養';

  @override
  String get moduleWaterDescription => '每次喝水的量與時間';

  @override
  String get moduleWeight => '體重';

  @override
  String get moduleWeightDescription => '體重與圍度';

  @override
  String get moduleTraining => '訓練';

  @override
  String get moduleTrainingDescription => '動作、課表與訓練紀錄';

  @override
  String get moduleActivity => '運動';

  @override
  String get moduleActivityDescription => '跑步、健走、騎車、球類、瑜伽';

  @override
  String get moduleSleep => '睡眠';

  @override
  String get moduleSleepDescription => '睡眠時間與品質';

  @override
  String get moduleWellness => '心情、精力、症狀';

  @override
  String get moduleWellnessDescription => '一天的狀態日誌';

  @override
  String get moduleNotes => '筆記';

  @override
  String get moduleNotesDescription => '和任何一天或一筆紀錄關聯';

  @override
  String get sourceManual => '手動輸入';

  @override
  String get sourceDemo => '示範資料';

  @override
  String get sourceImport => '匯入';

  @override
  String get sourceAiDraft => 'AI 草稿（已確認）';

  @override
  String get sourceCatalogue => '內建目錄';

  @override
  String get sourceUnknown => '不明';

  @override
  String get sourceAppleHealth => 'Apple 健康';

  @override
  String get modulesTitle => '模組';

  @override
  String get modulesPickSeveral => '可複選';

  @override
  String get commonDone => '完成';

  @override
  String get commonContinue => '繼續';

  @override
  String get journalSourceRow => '來源';

  @override
  String get sessionWorkout => '訓練';

  @override
  String sessionEndTitle({required String session}) {
    return '結束這次$session？';
  }

  @override
  String get sessionEndWorkoutMessage => '已完成的組數會存成紀錄；放棄則不會算成一次訓練。';

  @override
  String get sessionEndActivityMessage => '結束會存成一筆運動紀錄；放棄則什麼都不留。';

  @override
  String get sessionFinishAndSave => '結束並儲存';

  @override
  String get sessionDiscardWorkout => '放棄這次訓練';

  @override
  String get sessionDiscardActivity => '放棄這次運動';

  @override
  String sessionKeepGoing({required String session}) {
    return '繼續$session';
  }

  @override
  String sessionDiscarded({required String session}) {
    return '已放棄這次$session';
  }

  @override
  String sessionResume({required String session}) {
    return '繼續$session';
  }

  @override
  String sessionPause({required String session}) {
    return '暫停$session';
  }

  @override
  String sessionEnd({required String session}) {
    return '結束$session';
  }

  @override
  String sessionPausedOpen({required String session}) {
    return '$session已暫停，回到$session';
  }

  @override
  String sessionRunningOpen({required String session}) {
    return '$session進行中，回到$session';
  }

  @override
  String get sessionPausedStatus => '已暫停';

  @override
  String sessionRunningStatus({required String session}) {
    return '$session進行中';
  }

  @override
  String get dockAddEntry => '新增紀錄';

  @override
  String addEntryToDay({required String date}) {
    return '新增紀錄到 $date';
  }

  @override
  String get tabToday => '今天';

  @override
  String get tabLog => '紀錄';

  @override
  String get tabTrends => '趨勢';

  @override
  String get tabMe => '我的';

  @override
  String get detailNothingSelected => '未選取項目';

  @override
  String get detailNoEntrySelected => '未選取紀錄';

  @override
  String get recordWater => '水';

  @override
  String get recordMeasurements => '圍度';

  @override
  String get recordBodyComposition => '身體組成';

  @override
  String waterLogged({required int millilitres}) {
    return '已記錄 $millilitres mL 水';
  }

  @override
  String get quickLogClose => '關閉新增紀錄';

  @override
  String get bedtimeReminderTitle => '準備就寢';

  @override
  String bedtimeReminderBody({required String bedtime, required String wake}) {
    return '$bedtime 就寢，$wake 起床';
  }

  @override
  String get restResting => '休息中';

  @override
  String get restEnded => '休息結束';

  @override
  String restNextSet({required String exercise}) {
    return '下一組 · $exercise';
  }

  @override
  String setsProgress({required int done, required int total}) {
    return '$done / $total 組';
  }

  @override
  String get trackingTypeWeightReps => '重量 + 次數';

  @override
  String get trackingTypeReps => '次數';

  @override
  String get trackingTypeDuration => '時間';

  @override
  String get trackingTypeDistance => '距離';

  @override
  String get exerciseSourceBuiltIn => '內建';

  @override
  String get exerciseSourceCustom => '自訂';

  @override
  String get exerciseSourceImported => '匯入';

  @override
  String get bodyRegionChest => '胸';

  @override
  String get bodyRegionShoulders => '肩';

  @override
  String get bodyRegionBack => '背';

  @override
  String get bodyRegionArms => '手臂';

  @override
  String get bodyRegionCore => '核心';

  @override
  String get bodyRegionLegs => '腿臀';

  @override
  String get muscleChest => '胸';

  @override
  String get muscleFrontDelts => '三角肌前束';

  @override
  String get muscleSideDelts => '三角肌中束';

  @override
  String get muscleRearDelts => '三角肌後束';

  @override
  String get muscleBiceps => '二頭肌';

  @override
  String get muscleTriceps => '三頭肌';

  @override
  String get muscleForearms => '前臂';

  @override
  String get muscleTraps => '斜方肌';

  @override
  String get muscleLats => '背闊肌';

  @override
  String get muscleUpperBack => '上背';

  @override
  String get muscleSpinalErectors => '豎脊肌';

  @override
  String get muscleAbs => '腹直肌';

  @override
  String get muscleObliques => '腹斜肌';

  @override
  String get muscleGlutes => '臀';

  @override
  String get muscleQuads => '股四頭';

  @override
  String get muscleHamstrings => '腿後';

  @override
  String get muscleAdductors => '內收肌';

  @override
  String get muscleAbductors => '外展肌';

  @override
  String get muscleCalves => '小腿';

  @override
  String get muscleBack => '背';

  @override
  String get muscleShoulders => '肩';

  @override
  String get muscleArms => '手臂';

  @override
  String get muscleCore => '核心';

  @override
  String get equipmentBarbell => '槓鈴';

  @override
  String get equipmentDumbbell => '啞鈴';

  @override
  String get equipmentCable => '滑輪';

  @override
  String get equipmentMachine => '機械';

  @override
  String get equipmentSmithMachine => '史密斯機';

  @override
  String get equipmentKettlebell => '壺鈴';

  @override
  String get equipmentEzBar => 'EZ 槓';

  @override
  String get equipmentTrapBar => '六角槓';

  @override
  String get equipmentLandmine => '地雷管';

  @override
  String get equipmentPlate => '槓片';

  @override
  String get equipmentBand => '彈力帶';

  @override
  String get equipmentBodyweight => '徒手';

  @override
  String get equipmentCardio => '有氧器材';

  @override
  String get equipmentOther => '其他';

  @override
  String get movementPatternSquat => '深蹲';

  @override
  String get movementPatternHinge => '髖伸';

  @override
  String get movementPatternLunge => '弓步與單腳';

  @override
  String get movementPatternHorizontalPush => '水平推';

  @override
  String get movementPatternHorizontalPull => '水平拉';

  @override
  String get movementPatternVerticalPush => '垂直推';

  @override
  String get movementPatternVerticalPull => '垂直拉';

  @override
  String get movementPatternIsolation => '單關節';

  @override
  String get movementPatternCore => '核心';

  @override
  String get movementPatternCarry => '搬運';

  @override
  String get movementPatternConditioning => '體能';

  @override
  String get movementPatternUnilateral => '單側';

  @override
  String get lateralityBilateral => '雙側';

  @override
  String get lateralityUnilateral => '單側';

  @override
  String get lateralityAlternating => '左右交替';

  @override
  String get setTypeWorking => '工作組';

  @override
  String get setTypeWarmup => '熱身組';

  @override
  String get setTypeDrop => '遞減組';

  @override
  String get setTypeFailure => '力竭組';

  @override
  String get workloadTooLight => '太輕';

  @override
  String get workloadRight => '剛好';

  @override
  String get workloadTooHard => '太吃力';

  @override
  String get setKindWorking => '工作';

  @override
  String get setKindWarmup => '熱身';

  @override
  String get setKindDrop => '遞減';

  @override
  String get setKindFailure => '力竭';

  @override
  String substitutionSamePattern({required String pattern}) {
    return '同為$pattern模式';
  }

  @override
  String substitutionSameMuscles({required String muscles}) {
    return '同樣練$muscles';
  }

  @override
  String substitutionEquipmentAvailable({required String equipment}) {
    return '$equipment可用';
  }

  @override
  String substitutionTrackingChanges({required String tracking}) {
    return '記錄方式改為$tracking';
  }

  @override
  String substitutionEquipmentChanges({required String equipment}) {
    return '換$equipment，重量需重新設定';
  }

  @override
  String get substitutionOneSide => '單側動作，次數請重新設定';

  @override
  String get routineUntitled => '新的課表';

  @override
  String get workoutFreeName => '自由訓練';

  @override
  String setOrdinal({required int number}) {
    return '第 $number 組';
  }

  @override
  String muscleSetCount({required String muscle, required int sets}) {
    return '$muscle $sets 組';
  }

  @override
  String get valueTypeDeclared => '標示值';

  @override
  String get valueTypeMax => '最高值';

  @override
  String get valueTypeEstimate => '估計值';

  @override
  String get mealTypeBreakfast => '早餐';

  @override
  String get mealTypeLunch => '午餐';

  @override
  String get mealTypeDinner => '晚餐';

  @override
  String get mealTypeSnack => '點心';

  @override
  String get consumptionKindFood => '食物';

  @override
  String get consumptionKindBeverage => '飲品';

  @override
  String get consumptionKindUnknown => '未指定';

  @override
  String get servingUnitGram => 'g';

  @override
  String get servingUnitKilogram => 'kg';

  @override
  String get servingUnitOunce => 'oz';

  @override
  String get servingUnitPound => 'lb';

  @override
  String get servingUnitTael => '台兩';

  @override
  String get servingUnitCatty => '台斤';

  @override
  String get servingUnitMillilitre => 'ml';

  @override
  String get servingUnitLitre => 'L';

  @override
  String get servingUnitServing => '份';

  @override
  String get allergenCrustacean => '甲殼類';

  @override
  String get allergenMango => '芒果';

  @override
  String get allergenPeanut => '花生';

  @override
  String get allergenMilk => '牛奶';

  @override
  String get allergenEgg => '蛋';

  @override
  String get allergenTreeNut => '堅果';

  @override
  String get allergenSesame => '芝麻';

  @override
  String get allergenGluten => '麩質';

  @override
  String get allergenSoy => '大豆';

  @override
  String get allergenFish => '魚類';

  @override
  String get allergenSulphite => '亞硫酸鹽';

  @override
  String get nutrientSaturatedFat => '飽和脂肪';

  @override
  String get nutrientTransFat => '反式脂肪';

  @override
  String get nutrientSugar => '糖';

  @override
  String get nutrientSodium => '鈉';

  @override
  String get nutrientNetCarb => '糖質';

  @override
  String get nutrientSaltEquivalent => '食鹽相當量';

  @override
  String get nutrientPolyols => '糖醇';

  @override
  String get nutrientAlcohol => '酒精';

  @override
  String get nutrientCholesterol => '膽固醇';

  @override
  String get nutrientCaffeine => '咖啡因';

  @override
  String get nutrientEssentialAminoAcids => '必需胺基酸';

  @override
  String get nutrientBcaa => '支鏈胺基酸';

  @override
  String get nutrientLeucine => '白胺酸';

  @override
  String get nutrientIsoleucine => '異白胺酸';

  @override
  String get nutrientValine => '纈胺酸';

  @override
  String get nutrientGlutamine => '麩醯胺酸';

  @override
  String get nutrientCalcium => '鈣';

  @override
  String get nutrientPhosphorus => '磷';

  @override
  String get nutrientMagnesium => '鎂';

  @override
  String get nutrientIron => '鐵';

  @override
  String get nutrientZinc => '鋅';

  @override
  String get nutrientPotassium => '鉀';

  @override
  String get nutrientIodine => '碘';

  @override
  String get nutrientSelenium => '硒';

  @override
  String get nutrientVitaminA => '維生素 A';

  @override
  String get nutrientVitaminD => '維生素 D';

  @override
  String get nutrientVitaminE => '維生素 E';

  @override
  String get nutrientVitaminK => '維生素 K';

  @override
  String get nutrientVitaminC => '維生素 C';

  @override
  String get nutrientVitaminB1 => '維生素 B1';

  @override
  String get nutrientVitaminB2 => '維生素 B2';

  @override
  String get nutrientNiacin => '菸鹼素';

  @override
  String get nutrientVitaminB6 => '維生素 B6';

  @override
  String get nutrientVitaminB12 => '維生素 B12';

  @override
  String get nutrientFolate => '葉酸';

  @override
  String get nutrientPantothenicAcid => '泛酸';

  @override
  String get nutrientBiotin => '生物素';

  @override
  String get nutrientMonounsaturatedFat => '單元不飽和脂肪';

  @override
  String get nutrientPolyunsaturatedFat => '多元不飽和脂肪';

  @override
  String get nutrientCopper => '銅';

  @override
  String get nutrientManganese => '錳';

  @override
  String get nutrientChromium => '鉻';

  @override
  String get nutrientMolybdenum => '鉬';

  @override
  String get nutrientChloride => '氯';

  @override
  String get conventionTaiwan => '台灣';

  @override
  String get conventionJapan => '日本';

  @override
  String get conventionUnitedStates => '美國';

  @override
  String get conventionEuropeanUnion => '歐盟';

  @override
  String get conventionAustraliaNewZealand => '澳洲、紐西蘭';

  @override
  String get conventionKorea => '韓國';

  @override
  String get conventionChina => '中國';

  @override
  String get conventionCanada => '加拿大';

  @override
  String get macroEnergy => '熱量';

  @override
  String get macroProtein => '蛋白質';

  @override
  String get macroCarb => '碳水化合物';

  @override
  String get macroFat => '脂肪';

  @override
  String get macroFibre => '膳食纖維';

  @override
  String foodCupCapacity({required String amount}) {
    return '杯容量 $amount';
  }

  @override
  String get foodOfficialData => '官方資料';

  @override
  String foodAdd({required String food}) {
    return '加入「$food」';
  }

  @override
  String foodLastPortion({required String portion, required String kcal}) {
    return '上次 $portion · $kcal';
  }

  @override
  String foodCupSizes({required int count}) {
    return '$count 種杯型';
  }

  @override
  String foodOneServing({required String serving, required String kcal}) {
    return '一份 $serving · $kcal';
  }

  @override
  String draftEnergyMismatchItem({required String item}) {
    return '$item的熱量和蛋白質、碳水化合物、脂肪算起來差得多，請核對。';
  }

  @override
  String get draftEnergyMismatch => '熱量和蛋白質、碳水化合物、脂肪算起來差得多，請核對這幾格。';

  @override
  String get draftColumnMismatch => '每份的熱量和每 100 的熱量依份量換算對不上，可能填到另一欄，請核對。';

  @override
  String get draftCarbWithoutFibre => '這張標示的碳水化合物不含膳食纖維，又沒有印膳食纖維，碳水化合物留白。';

  @override
  String get activityGroupWalkRun => '走路與跑步';

  @override
  String get activityGroupCycling => '自行車';

  @override
  String get activityGroupWater => '水上運動';

  @override
  String get activityGroupBall => '球類';

  @override
  String get activityGroupIndoor => '室內器材';

  @override
  String get activityGroupMindBody => '身心與伸展';

  @override
  String get activityGroupOther => '其他';

  @override
  String get activityMetricGroupMovement => '日常活動';

  @override
  String get activityMetricGroupHeart => '心臟與心肺';

  @override
  String get activityMetricGroupVitals => '生命徵象';

  @override
  String get activityMetricMindfulTime => '正念時間';

  @override
  String get activityMetricGroupMindfulness => '正念';

  @override
  String get activityMetricBodyTemperature => '體溫';

  @override
  String get activityMetricBloodPressureSystolic => '收縮壓';

  @override
  String get activityMetricBloodPressureDiastolic => '舒張壓';

  @override
  String get vitalBloodPressure => '血壓';

  @override
  String get activityMetricRespiratoryRate => '呼吸速率';

  @override
  String get activityMetricOxygenSaturation => '血氧';

  @override
  String get activityMetricUnitRespiratoryRate => '次/分';

  @override
  String get activityMetricGroupMobility => '行動能力';

  @override
  String get activityMetricGroupRunning => '跑步';

  @override
  String get activityMetricGroupCycling => '騎車';

  @override
  String get activityMetricGroupSwimmingWheelchair => '游泳與輪椅';

  @override
  String get activityMetricSteps => '步數';

  @override
  String get activityMetricDistance => '距離';

  @override
  String get activityMetricActiveEnergy => '動態能量';

  @override
  String get activityMetricBasalEnergy => '靜止能量';

  @override
  String get activityMetricExerciseTime => '運動時間';

  @override
  String get activityMetricStandTime => '站立時間';

  @override
  String get activityMetricMoveTime => '移動時間';

  @override
  String get activityMetricFloors => '爬樓';

  @override
  String get activityMetricElevationGained => '爬升高度';

  @override
  String get activityMetricTimeInDaylight => '日光時間';

  @override
  String get activityMetricHeartRate => '平均心率';

  @override
  String get activityMetricRestingHeartRate => '靜止心率';

  @override
  String get activityMetricWalkingHeartRate => '步行平均心率';

  @override
  String get activityMetricHrvSdnn => '心率變異度（SDNN）';

  @override
  String get activityMetricHrvRmssd => '心率變異度（RMSSD）';

  @override
  String get activityMetricHeartRateRecovery => '一分鐘心率恢復';

  @override
  String get activityMetricVo2Max => '最大攝氧量';

  @override
  String get activityMetricPhysicalEffort => '身體耗力';

  @override
  String get activityMetricWalkingSpeed => '步行速度';

  @override
  String get activityMetricWalkingStepLength => '步長';

  @override
  String get activityMetricWalkingAsymmetry => '步行不對稱';

  @override
  String get activityMetricDoubleSupport => '雙腳支撐時間';

  @override
  String get activityMetricWalkingSteadiness => '步行穩定度';

  @override
  String get activityMetricStairAscentSpeed => '上樓速度';

  @override
  String get activityMetricStairDescentSpeed => '下樓速度';

  @override
  String get activityMetricSixMinuteWalk => '六分鐘步行距離';

  @override
  String get activityMetricRunningSpeed => '跑步速度';

  @override
  String get activityMetricRunningPower => '跑步功率';

  @override
  String get activityMetricRunningStrideLength => '跑步步幅';

  @override
  String get activityMetricGroundContactTime => '觸地時間';

  @override
  String get activityMetricVerticalOscillation => '垂直振幅';

  @override
  String get activityMetricCyclingDistance => '騎車距離';

  @override
  String get activityMetricCyclingSpeed => '騎車速度';

  @override
  String get activityMetricCyclingPower => '騎車功率';

  @override
  String get activityMetricCyclingCadence => '踏頻';

  @override
  String get activityMetricFunctionalThresholdPower => '功能性閾值功率';

  @override
  String get activityMetricSwimmingDistance => '游泳距離';

  @override
  String get activityMetricSwimmingStrokes => '划水次數';

  @override
  String get activityMetricWheelchairPushes => '輪椅推動';

  @override
  String get activityMetricWheelchairDistance => '輪椅距離';

  @override
  String get activityMetricUnitSteps => '步';

  @override
  String get activityMetricUnitDistance => 'km';

  @override
  String get activityMetricUnitActiveEnergy => 'kcal';

  @override
  String get activityMetricUnitBasalEnergy => 'kcal';

  @override
  String get activityMetricUnitExerciseTime => '分';

  @override
  String get activityMetricUnitStandTime => '分';

  @override
  String get activityMetricUnitFloors => '層';

  @override
  String get activityMetricUnitElevationGained => 'm';

  @override
  String get activityMetricUnitTimeInDaylight => '分';

  @override
  String get activityMetricUnitHeartRate => '次/分';

  @override
  String get activityMetricUnitRestingHeartRate => '次/分';

  @override
  String get activityMetricUnitWalkingHeartRate => '次/分';

  @override
  String get activityMetricUnitHrvSdnn => 'ms';

  @override
  String get activityMetricUnitHrvRmssd => 'ms';

  @override
  String get activityMetricUnitHeartRateRecovery => '次/分';

  @override
  String get activityMetricUnitVo2Max => 'mL/kg/min';

  @override
  String get activityMetricUnitPhysicalEffort => 'MET';

  @override
  String get activityMetricUnitWalkingSpeed => 'km/h';

  @override
  String get activityMetricUnitWalkingStepLength => 'cm';

  @override
  String get activityMetricUnitWalkingAsymmetry => '%';

  @override
  String get activityMetricUnitDoubleSupport => '%';

  @override
  String get activityMetricUnitWalkingSteadiness => '%';

  @override
  String get activityMetricUnitStairAscentSpeed => 'm/s';

  @override
  String get activityMetricUnitStairDescentSpeed => 'm/s';

  @override
  String get activityMetricUnitSixMinuteWalk => 'm';

  @override
  String get activityMetricUnitRunningSpeed => 'km/h';

  @override
  String get activityMetricUnitRunningPower => 'W';

  @override
  String get activityMetricUnitRunningStrideLength => 'm';

  @override
  String get activityMetricUnitGroundContactTime => 'ms';

  @override
  String get activityMetricUnitVerticalOscillation => 'cm';

  @override
  String get activityMetricUnitCyclingDistance => 'km';

  @override
  String get activityMetricUnitCyclingSpeed => 'km/h';

  @override
  String get activityMetricUnitCyclingPower => 'W';

  @override
  String get activityMetricUnitCyclingCadence => 'rpm';

  @override
  String get activityMetricUnitFunctionalThresholdPower => 'W';

  @override
  String get activityMetricUnitSwimmingDistance => 'm';

  @override
  String get activityMetricUnitSwimmingStrokes => '次';

  @override
  String get activityMetricUnitWheelchairPushes => '次';

  @override
  String get activityMetricUnitWheelchairDistance => 'km';

  @override
  String get activityTypeRunning => '跑步';

  @override
  String get activityTypeWalking => '健走';

  @override
  String get activityTypeHiking => '健行';

  @override
  String get activityTypeCycling => '騎自行車';

  @override
  String get activityTypeSwimming => '游泳';

  @override
  String get activityTypeRowing => '划船機';

  @override
  String get activityTypeElliptical => '橢圓機';

  @override
  String get activityTypeStairs => '爬樓梯';

  @override
  String get activityTypeBasketball => '籃球';

  @override
  String get activityTypeBadminton => '羽球';

  @override
  String get activityTypeYoga => '瑜伽';

  @override
  String get activityTypeOther => '其他運動';

  @override
  String hoursMinutes({required int hours, required int minutes}) {
    return '$hours 小時 $minutes 分';
  }

  @override
  String durationMinutes({required int minutes}) {
    return '$minutes 分';
  }

  @override
  String get activitySeriesHeartRate => '心率';

  @override
  String get activitySeriesSpeed => '速度';

  @override
  String get activitySeriesPower => '功率';

  @override
  String get activitySeriesCadence => '踏頻';

  @override
  String get activitySeriesStrideLength => '步幅';

  @override
  String get activitySeriesGroundContactTime => '觸地時間';

  @override
  String get activitySeriesVerticalOscillation => '垂直振幅';

  @override
  String get activitySeriesAltitude => '高度';

  @override
  String get activitySeriesUnitHeartRate => '次/分';

  @override
  String get activitySeriesUnitSpeed => 'km/h';

  @override
  String get activitySeriesUnitPower => 'W';

  @override
  String get activitySeriesUnitCadence => 'rpm';

  @override
  String get activitySeriesUnitStrideLength => 'm';

  @override
  String get activitySeriesUnitGroundContactTime => 'ms';

  @override
  String get activitySeriesUnitVerticalOscillation => 'cm';

  @override
  String get activitySeriesUnitAltitude => 'm';

  @override
  String get unitBpm => '次/分';

  @override
  String activityDeleted({required String activity}) {
    return '已刪除$activity';
  }

  @override
  String get recordDeletedNotice => '這筆紀錄已經刪除。';

  @override
  String get activityRouteMap => '路線地圖';

  @override
  String get healthDetailUnreadable => '無法讀取健康資料的詳細紀錄。';

  @override
  String get activityDetailsSection => '詳細資料';

  @override
  String get activitySplitsSection => '分段 · 每 1 km';

  @override
  String get activityRecoverySection => '運動後心率';

  @override
  String get activityPace => '配速';

  @override
  String get notesSection => '備註';

  @override
  String get manageSection => '管理';

  @override
  String get activityEdit => '編輯內容';

  @override
  String get activityEditDetail => '類型、時間、時長';

  @override
  String get recordDelete => '刪除這筆紀錄';

  @override
  String get deleteMeasurement => '刪除這次量測';

  @override
  String get activityActiveTime => '運動時間';

  @override
  String get activityDistance => '距離';

  @override
  String get activityTotalEnergy => '總能量';

  @override
  String get activityClimb => '爬升';

  @override
  String get activityAveragePace => '平均配速';

  @override
  String get activityAverageSpeed => '平均速度';

  @override
  String get activityMaxHeartRate => '最高心率';

  @override
  String get activityAveragePower => '平均功率';

  @override
  String get activityAverageCadence => '平均踏頻';

  @override
  String get activityEffort => '費力程度';

  @override
  String get activityEffortEstimated => '費力程度（估計）';

  @override
  String activityIndoor({required String activity}) {
    return '$activity（室內）';
  }

  @override
  String activityOutdoor({required String activity}) {
    return '$activity（戶外）';
  }

  @override
  String get weatherLabel => '天氣';

  @override
  String get humidityLabel => '濕度';

  @override
  String get splitTime => '時間';

  @override
  String statAverage({required String value}) {
    return '平均 $value';
  }

  @override
  String heartZone({required int number}) {
    return '區間 $number';
  }

  @override
  String get heartZonesByReserve => '依儲備心率估計';

  @override
  String get heartZonesByAge => '依年齡估計最大心率';

  @override
  String get heartZonesOwn => '本 App 的區間';

  @override
  String get recoveryAtEnd => '結束時';

  @override
  String recoveryAfter({required int minutes}) {
    return '$minutes 分後';
  }

  @override
  String recoveryWindow({required String time}) {
    return '$time 起 3 分鐘';
  }

  @override
  String timelineWeight({required String weight}) {
    return '體重 $weight';
  }

  @override
  String sleepQualityScore({required int score}) {
    return '品質 $score / 5';
  }

  @override
  String noteLine({required String note}) {
    return '備註：$note';
  }

  @override
  String setsCount({required int count}) {
    return '$count 組';
  }

  @override
  String personalRecordLine({
    required String exercise,
    required String weight,
    required int reps,
  }) {
    return '$exercise $weight kg × $reps 為個人紀錄';
  }

  @override
  String effortOutOfTen({required int effort}) {
    return '強度 $effort / 10';
  }

  @override
  String activitiesCount({required int count}) {
    return '$count 場';
  }

  @override
  String itemsCount({required int count}) {
    return '$count 項';
  }

  @override
  String mealsCount({required int count}) {
    return '$count 餐';
  }

  @override
  String get foodLogIncomplete => '有未記錄的餐';

  @override
  String todayWithDate({required String date}) {
    return '今天 · $date';
  }

  @override
  String get routineNeverDone => '未完成過';

  @override
  String routineLastDone({required String date}) {
    return '上次 $date 完成';
  }

  @override
  String optionalField({required String field}) {
    return '$field（選填）';
  }

  @override
  String get workoutBlocksActivity => '訓練進行中，先結束訓練才能開始運動';

  @override
  String activityDurationRange({required int min, required int max}) {
    return '時長請介於 $min – $max 分鐘。';
  }

  @override
  String activityDistanceRange({required int max}) {
    return '距離請輸入 0 – $max km 之間。';
  }

  @override
  String activityClimbRange({required int max}) {
    return '爬升請輸入 0 – $max m 之間。';
  }

  @override
  String activityLogged({required String activity, required int minutes}) {
    return '已記錄$activity $minutes 分';
  }

  @override
  String activityUpdated({required String activity}) {
    return '已更新$activity';
  }

  @override
  String get activityRecordTitle => '記錄運動';

  @override
  String get activityEditTitle => '編輯運動';

  @override
  String get activityTypeRow => '運動類型';

  @override
  String get activityStartTimer => '現在開始計時';

  @override
  String get activityStartTimerDetail => '邊做邊計時，距離與強度結束後再補';

  @override
  String get activityStartTime => '開始時間';

  @override
  String get activityDurationSection => '時長';

  @override
  String get minutesUnit => '分鐘';

  @override
  String activityEndsAt({required String time}) {
    return '結束 $time';
  }

  @override
  String activityPaceValue({required String pace}) {
    return '配速 $pace /km';
  }

  @override
  String get effortSection => '強度';

  @override
  String get effortScaleHint => '1 很輕鬆、10 拼盡全力。';

  @override
  String get activityNoteHint => '例如：河濱，風很大';

  @override
  String get activityPickTitle => '選擇運動';

  @override
  String get recentlyUsed => '最近使用';

  @override
  String get commonlyUsed => '常用';

  @override
  String get activityAllTypes => '所有運動';

  @override
  String get activityEnded => '這次運動已經結束。';

  @override
  String get sessionInProgress => '進行中';

  @override
  String get commonEnd => '結束';

  @override
  String get commonResume => '繼續';

  @override
  String get commonPause => '暫停';

  @override
  String get chartRangeDay => '日';

  @override
  String get chartRangeWeek => '週';

  @override
  String get chartRangeMonth => '月';

  @override
  String get previousDay => '前一天';

  @override
  String get nextDay => '後一天';

  @override
  String get entriesRow => '紀錄';

  @override
  String get thisDay => '這一天';

  @override
  String get dailyAverage => '每日平均';

  @override
  String get usualRange => '平常範圍';

  @override
  String get daysRecorded => '紀錄天數';

  @override
  String daysCount({required int count}) {
    return '$count 天';
  }

  @override
  String weekOf({required String date}) {
    return '$date起一週';
  }

  @override
  String readingsCount({required int count}) {
    return '$count 筆';
  }

  @override
  String get perDay => '每日';

  @override
  String get dailyActivityTitle => '活動';

  @override
  String get noActivityData => '沒有活動資料';

  @override
  String get dataSourcesLink => '資料來源';

  @override
  String get noActivityThisDay => '這一天沒有活動資料';

  @override
  String get heartZonesTitle => '心率區間';

  @override
  String get needsBirthYear => '需要出生年';

  @override
  String nightsWithinUsual({required int count, required int total}) {
    return '$total 晚中 $count 晚在平常範圍內';
  }

  @override
  String daysWithinUsual({required int count, required int total}) {
    return '$total 天中 $count 天在平常範圍內';
  }

  @override
  String daysAllWithinUsual({required int count}) {
    return '$count 天都在平常範圍內';
  }

  @override
  String daysRecordedWithinUsual({required int recorded, required int count}) {
    return '$recorded 天有紀錄，$count 天在平常範圍內';
  }

  @override
  String usualRangeNeedsDays({required int count}) {
    return '需要近 28 天有 14 天的紀錄（目前 $count 天）';
  }

  @override
  String nightsAllWithinUsual({required int count}) {
    return '$count 晚都在平常範圍內';
  }

  @override
  String nightsRecordedWithinUsual({
    required int recorded,
    required int count,
  }) {
    return '$recorded 晚有紀錄，$count 晚在平常範圍內';
  }

  @override
  String usualRangeNeedsNights({required int count}) {
    return '需要近 28 天有 14 晚的紀錄（目前 $count 晚）';
  }

  @override
  String get outsideUsual => '範圍外';

  @override
  String get targetBedtime => '目標入睡';

  @override
  String get targetWake => '目標起床';

  @override
  String get clearTargetSchedule => '清除目標作息';

  @override
  String get targetSchedule => '目標作息';

  @override
  String get refSectionUsualRange => '平常範圍';

  @override
  String get refSectionSleepStages => '睡眠階段';

  @override
  String get refUseUsualRangeMinMax => '平常範圍是前 28 天的最低到最高，有值的日子至少 14 天';

  @override
  String get refUseUsualRangeWindow => '個人基線取前 28 天的紀錄，不含當天';

  @override
  String get refUseUsualRangeMarks => '範圍外只用空心圈標出，不分好壞、不用警示色';

  @override
  String get refUseUsualRangeNoAnchor => '範圍外的點沒有臨床界線可對照，所以標記要弱並附上數字';

  @override
  String get refUseStagesEstimate => '睡眠階段是裝置估計，只和自己的夜晚比，不用同年齡的範圍';

  @override
  String get refUseStagesNoTarget => '睡眠結構沒有共識，不設各階段的目標';

  @override
  String get refUseStagesNoSummary => '睡眠階段與效率不寫幾晚在範圍內：負面的睡眠回饋會影響白天的感受';

  @override
  String get refUseRegularityOutcomes => '規律的作息與較低的死亡風險相關（觀察性）';

  @override
  String get refUseTargetScheduleAssociation => '目標作息：作息規律與健康結果的關聯，目標時刻由使用者自訂';

  @override
  String get refUseTargetScheduleTrial => '目標作息：固定作息四週，白天嗜睡下降（小型實驗）';

  @override
  String get refUseMaxHeartRateError => '依年齡估計的最大心率，個人誤差約 11 次/分，所以全天心率圖不畫區間';

  @override
  String get refUseHeartRateReserve => '儲備心率對應儲備攝氧量，區間依此計算';

  @override
  String usualRangeValue({required String range}) {
    return '平常 $range';
  }

  @override
  String get vitalsTitle => '心臟與生命徵象';

  @override
  String get noVitalsData => '沒有心臟與生命徵象資料';

  @override
  String get perHour => '每小時';

  @override
  String hourSpan({required int start, required int end}) {
    return '$start–$end 時';
  }

  @override
  String hourOfDay({required int hour}) {
    return '$hour 時';
  }

  @override
  String get measurementSiteWaist => '腰圍';

  @override
  String get measurementSiteHips => '臀圍';

  @override
  String get measurementSiteChest => '胸圍';

  @override
  String get measurementSiteArm => '上臂';

  @override
  String get measurementSiteThigh => '大腿';

  @override
  String get measurementSiteCalf => '小腿';

  @override
  String get measurementSiteNeck => '頸圍';

  @override
  String get bodyMetricHeight => '身高';

  @override
  String get bodyMetricBodyFat => '體脂率';

  @override
  String get bodyMetricSkeletalMuscle => '骨骼肌';

  @override
  String get bodyMetricMuscleMass => '肌肉量';

  @override
  String get bodyMetricLeanMass => '除脂體重';

  @override
  String get bodyMetricVisceralFat => '內臟脂肪';

  @override
  String get bodyMetricBodyWater => '體水分';

  @override
  String get bodyMetricBoneMass => '骨量';

  @override
  String get bodyMetricBasalMetabolicRate => '基礎代謝';

  @override
  String get sexFemale => '女性';

  @override
  String get sexMale => '男性';

  @override
  String get sleepKindNight => '睡眠';

  @override
  String get sleepKindNap => '小睡';

  @override
  String get sleepMeasureAsleep => '睡著時間';

  @override
  String get sleepMeasureInBed => '在床時間';

  @override
  String get sleepStageInBed => '在床';

  @override
  String get sleepStageAwake => '清醒';

  @override
  String get sleepStageAsleep => '睡著';

  @override
  String get sleepStageCore => '淺層／核心';

  @override
  String get sleepStageDeep => '深層';

  @override
  String get sleepStageRem => 'REM';

  @override
  String get overnightMeasureHeartRate => '心率';

  @override
  String get overnightMeasureRespiratoryRate => '呼吸速率';

  @override
  String get overnightMeasureOxygenSaturation => '血氧';

  @override
  String get overnightMeasureWristTemperature => '手腕溫度';

  @override
  String get overnightMeasureSkinTemperatureChange => '皮膚溫度變化';

  @override
  String get overnightMeasureHrvSdnn => '心率變異度（SDNN）';

  @override
  String get overnightMeasureHrvRmssd => '心率變異度（RMSSD）';

  @override
  String get overnightMeasureBreathingDisturbances => '呼吸干擾';

  @override
  String get activityLevelSedentary => '久坐';

  @override
  String get activityLevelLight => '輕度';

  @override
  String get activityLevelModerate => '中度';

  @override
  String get activityLevelActive => '高度';

  @override
  String get activityLevelVeryActive => '非常高';

  @override
  String get weightGoalLose => '減脂';

  @override
  String get weightGoalRecomp => '增肌減脂';

  @override
  String get weightGoalMaintain => '維持';

  @override
  String get weightGoalGain => '增肌';

  @override
  String get targetInputWeight => '體重';

  @override
  String get targetInputHeight => '身高';

  @override
  String get targetInputBirthYear => '出生年';

  @override
  String get targetInputSex => '性別';

  @override
  String get healthDataSleep => '睡眠';

  @override
  String get healthDataWeight => '體重';

  @override
  String get healthDataWaist => '腰圍';

  @override
  String get healthDataBody => '身體組成';

  @override
  String get healthDataWorkouts => '運動';

  @override
  String get healthDataWater => '喝水';

  @override
  String get healthDataOvernight => '夜間資料';

  @override
  String get healthDataActivity => '活動與心肺';

  @override
  String get recordCategoryTraining => '訓練';

  @override
  String get recordCategoryActivity => '運動';

  @override
  String get recordCategoryNutrition => '飲食';

  @override
  String get recordCategoryBody => '身體';

  @override
  String get recordCategoryWellness => '睡眠與狀態';

  @override
  String get aiProviderAppleOnDevice => 'Apple Intelligence';

  @override
  String get aiProviderOllamaCloud => 'Ollama Cloud';

  @override
  String get aiProviderGoogleAiStudio => 'Google AI Studio';

  @override
  String get aiProviderAnthropic => 'Anthropic';

  @override
  String get aiProviderAzureAiFoundry => 'Azure AI Foundry';

  @override
  String get aiProviderMicrosoftCopilot => 'Microsoft 365 Copilot';

  @override
  String get aiProviderOpenAiCompatible => 'OpenAI 相容端點';

  @override
  String get wellnessKindEnergy => '精力';

  @override
  String get wellnessKindMood => '心情';

  @override
  String get wellnessKindSymptom => '症狀';

  @override
  String get wellnessKindSleep => '睡眠品質';

  @override
  String get bodyMetricUnitHeight => 'cm';

  @override
  String get bodyMetricUnitBodyFat => '%';

  @override
  String get bodyMetricUnitSkeletalMuscle => 'kg';

  @override
  String get bodyMetricUnitMuscleMass => 'kg';

  @override
  String get bodyMetricUnitLeanMass => 'kg';

  @override
  String get bodyMetricUnitVisceralFat => '級';

  @override
  String get bodyMetricUnitBodyWater => '%';

  @override
  String get bodyMetricUnitBoneMass => 'kg';

  @override
  String get bodyMetricUnitBasalMetabolicRate => 'kcal';

  @override
  String get overnightMeasureUnitHeartRate => '次/分';

  @override
  String get overnightMeasureUnitRespiratoryRate => '次/分';

  @override
  String get overnightMeasureUnitOxygenSaturation => '%';

  @override
  String get overnightMeasureUnitWristTemperature => '°C';

  @override
  String get overnightMeasureUnitSkinTemperatureChange => '°C';

  @override
  String get overnightMeasureUnitHrvSdnn => 'ms';

  @override
  String get overnightMeasureUnitHrvRmssd => 'ms';

  @override
  String get overnightMeasureUnitBreathingDisturbances => '';

  @override
  String get activityLevelDetailSedentary => '幾乎不運動';

  @override
  String get activityLevelDetailLight => '每週運動 1–3 天';

  @override
  String get activityLevelDetailModerate => '每週運動 3–5 天';

  @override
  String get activityLevelDetailActive => '每週運動 6–7 天';

  @override
  String get activityLevelDetailVeryActive => '體力勞動或一天兩練';

  @override
  String get aiOff => 'AI 未啟用';

  @override
  String get aiDraftGenerate => '產生草稿';

  @override
  String get aiDrafting => '產生中…';

  @override
  String get aiRewrite => '重新輸入';

  @override
  String deletedItem({required String item}) {
    return '已刪除$item';
  }

  @override
  String get recordTitle => '紀錄';

  @override
  String get commonEdit => '編輯';

  @override
  String get bodyScaleEstimate => '體脂計估計';

  @override
  String get notRated => '沒有評分';

  @override
  String weightSinceLast({required String change, required String date}) {
    return '較上次 $change（$date）';
  }

  @override
  String get logFilterAll => '全部';

  @override
  String pickMonthCurrent({required String month}) {
    return '選擇月份，目前 $month';
  }

  @override
  String get logSearch => '搜尋紀錄';

  @override
  String get backToToday => '回到今天';

  @override
  String get showAsCalendar => '以月曆顯示';

  @override
  String get showAsTimeline => '以時間軸顯示';

  @override
  String get previousMonth => '上個月';

  @override
  String get nextMonth => '下個月';

  @override
  String noEntriesInMonth({required String month}) {
    return '$month沒有紀錄';
  }

  @override
  String noEntriesMatching({required String query}) {
    return '找不到符合「$query」的紀錄。';
  }

  @override
  String get noEntriesThisDay => '這天沒有紀錄。';

  @override
  String get noEntriesSentence => '沒有紀錄。';

  @override
  String get noImports => '沒有匯入紀錄。';

  @override
  String get importUndone => '已復原';

  @override
  String productsCount({required int count}) {
    return '$count 款';
  }

  @override
  String catalogueUpdated({required String catalogue, required String date}) {
    return '$catalogue更新於 $date';
  }

  @override
  String healthReadFailed({required String error}) {
    return '讀取失敗：$error';
  }

  @override
  String get healthDisconnectKeeps => '中斷連接後紀錄保留。';

  @override
  String get healthReadNow => '立即讀取';

  @override
  String get healthDisconnect => '中斷連接';

  @override
  String healthUnavailable({required String source}) {
    return '這台裝置沒有 $source，或版本太舊。';
  }

  @override
  String get checking => '檢查中…';

  @override
  String get healthConnected => '已連接';

  @override
  String healthConnect({required String source}) {
    return '連接 $source';
  }

  @override
  String get healthReading => '讀取中…';

  @override
  String get healthAllowReading => '允許讀取';

  @override
  String get healthAutoReadFailed => '上次自動讀取失敗';

  @override
  String get healthReadFailedState => '讀取失敗';

  @override
  String get healthReadDone => '讀取完成';

  @override
  String healthLastRead({required String when}) {
    return '上次讀取 $when';
  }

  @override
  String healthReads({required String kinds}) {
    return '讀取：$kinds';
  }

  @override
  String get privacyLink => '隱私說明';

  @override
  String get checkingPermissions => '檢查權限中…';

  @override
  String get healthPermissionsPath => '權限在「設定 > 健康 > 資料存取與裝置 > MISHIRUBE」修改。';

  @override
  String get permissionAllowed => '已允許';

  @override
  String get permissionDenied => '未允許';

  @override
  String get healthAllowOthers => '允許其他類別';

  @override
  String get healthNotConnected => '沒有連上。';

  @override
  String healthNothingReadDenied({required String kinds}) {
    return '沒有讀到資料。未允許：$kinds。';
  }

  @override
  String get healthNothingRead => '沒有讀到資料。到系統的健康設定確認允許的類別。';

  @override
  String nightsCount({required int count}) {
    return '$count 晚';
  }

  @override
  String timesCount({required int count}) {
    return '$count 次';
  }

  @override
  String healthUpdatedNights({required int count}) {
    return '更新 $count 晚睡眠';
  }

  @override
  String healthKeptManual({required int count}) {
    return '$count 晚保留手動紀錄';
  }

  @override
  String healthNotAllowedList({required String kinds}) {
    return '未允許：$kinds';
  }

  @override
  String get noSleepRecords => '沒有睡眠紀錄';

  @override
  String get logByHand => '手動記錄';

  @override
  String get sleepDebtSection => '睡眠債';

  @override
  String get napsSection => '小睡';

  @override
  String get goalSection => '目標';

  @override
  String get sleepStagesSection => '睡眠階段';

  @override
  String get notProvided => '未提供';

  @override
  String get fallAsleepTime => '入睡所需';

  @override
  String get sleepEfficiency => '睡眠效率';

  @override
  String get awakeAtNight => '夜間清醒';

  @override
  String wokeTimes({required int count}) {
    return '醒來 $count 次';
  }

  @override
  String get continuitySection => '連續性';

  @override
  String get estimatedFromInBed => '依裝置的在床時間估算';

  @override
  String get tonightSection => '今晚';

  @override
  String get suggestedBedtime => '建議就寢';

  @override
  String wakeAt({required String time}) {
    return '$time 起床';
  }

  @override
  String get fromUsualWake => '依平常的起床時間';

  @override
  String get afterTraining => '訓練後';

  @override
  String get caffeineAfter2pm => '14:00 後有咖啡因';

  @override
  String get mealAfter9pm => '21:00 後進食';

  @override
  String nightsVersus({required int withCount, required int withoutCount}) {
    return '$withCount 晚對 $withoutCount 晚';
  }

  @override
  String get factorsSection => '影響因素';

  @override
  String get factorsBasis => '近 90 天的平均睡著時間差';

  @override
  String get correlationNotCause => '相關，不代表因果';

  @override
  String sleptLess({required String time}) {
    return '少睡 $time';
  }

  @override
  String sleptMore({required String time}) {
    return '多睡 $time';
  }

  @override
  String get recordMethod => '紀錄方式';

  @override
  String get withStages => '含睡眠階段';

  @override
  String get elevated => '升高';

  @override
  String get notElevated => '未升高';

  @override
  String get sameAsUsual => '與近 28 晚平均相同';

  @override
  String versusUsual({required String change}) {
    return '較近 28 晚平均 $change';
  }

  @override
  String goalMet({required String goal}) {
    return '目標 $goal · 達成';
  }

  @override
  String goalShort({required String goal, required String gap}) {
    return '目標 $goal · 少 $gap';
  }

  @override
  String get recordedSleep => '紀錄的睡眠';

  @override
  String get deviceEstimate => '裝置估計';

  @override
  String withNapsTotal({required String time}) {
    return '含小睡共 $time';
  }

  @override
  String get noEntriesShort => '沒有紀錄';

  @override
  String get averageTimeAsleep => '平均睡著時間';

  @override
  String get averageBedtime => '平均入睡';

  @override
  String get averageWake => '平均起床';

  @override
  String plusMinusMinutes({required int minutes}) {
    return '±$minutes 分';
  }

  @override
  String get nightsRecorded => '紀錄晚數';

  @override
  String get bedAndWake => '入睡與起床';

  @override
  String averageStage({required String stage}) {
    return '平均$stage';
  }

  @override
  String trendOverNights({required String measure, required int count}) {
    return '$measure走勢，$count 晚';
  }

  @override
  String everyMinutes({required int minutes}) {
    return '每 $minutes 分';
  }

  @override
  String stageChartLabel({required String start, required String end}) {
    return '睡眠階段圖，$start 到 $end';
  }

  @override
  String get wholeNight => '整晚';

  @override
  String scheduleChartLabel({required int count}) {
    return '入睡與起床時間，$count 晚';
  }

  @override
  String get sleepGoal => '睡眠目標';

  @override
  String get notSet => '未設定';

  @override
  String get bedtimeReminder => '就寢提醒';

  @override
  String remindsAt({required String time}) {
    return '$time 提醒';
  }

  @override
  String get clearGoal => '清除目標';

  @override
  String rollingSum({required int count}) {
    return '$count 天累計';
  }

  @override
  String get nightlyShortfall => '每晚少睡';

  @override
  String get trendSection => '走勢';

  @override
  String get eachDaySection => '每天';

  @override
  String get notEnoughEntries => '紀錄不足';

  @override
  String highestLowest({required String high, required String low}) {
    return '最高 $high · 最低 $low';
  }

  @override
  String get preliminary => '初步';

  @override
  String countedAt({required String hours}) {
    return '以 $hours計';
  }

  @override
  String goalValue({required String goal}) {
    return '目標 $goal';
  }

  @override
  String daysWithoutEntries({required int count}) {
    return '$count 天沒有紀錄';
  }

  @override
  String get hoursUnit => '小時';

  @override
  String lastFortnightExtra({required String hours}) {
    return '近 14 天 · 多睡 $hours';
  }

  @override
  String needsLoggedDays({required int minimum, required int recorded}) {
    return '需要近 14 天有 $minimum 天紀錄（目前 $recorded 天）';
  }

  @override
  String lastWeekDebt({required String short, required String extra}) {
    return '近 7 天 $short · 多睡 $extra';
  }

  @override
  String hoursValue({required String hours}) {
    return '$hours 小時';
  }

  @override
  String shortBy({required String time}) {
    return '少 $time';
  }

  @override
  String overBy({required String time}) {
    return '多 $time';
  }

  @override
  String get photoTextUnavailable => '這台裝置無法讀取照片中的文字。';

  @override
  String get photoNoBodyComposition => '照片中沒有讀到身體組成的數字。';

  @override
  String get photoNoGirths => '照片中沒有讀到圍度的數字。';

  @override
  String valueRangeError({
    required String field,
    required String min,
    required String max,
    required String unit,
  }) {
    return '$field請輸入 $min – $max $unit 之間。';
  }

  @override
  String get fillAtLeastOne => '至少填一項。';

  @override
  String get fillAtLeastOneSite => '至少填一個部位。';

  @override
  String loggedValue({required String item, required String value}) {
    return '已記錄$item $value';
  }

  @override
  String updatedValue({required String item, required String value}) {
    return '已更新$item $value';
  }

  @override
  String loggedItemsCount({required int count}) {
    return '已記錄 $count 項';
  }

  @override
  String loggedSitesCount({required int count}) {
    return '已記錄 $count 個部位';
  }

  @override
  String get scanAction => '掃描';

  @override
  String get readingPhoto => '正在讀取照片…';

  @override
  String get scanBodyComposition => '拍照讀取身體組成';

  @override
  String get scanGirths => '拍照讀取圍度';

  @override
  String lastReadingOn({required String value, required String date}) {
    return '上次 $value · $date';
  }

  @override
  String photoReadCheck({required int count}) {
    return '照片讀到 $count 項，請核對';
  }

  @override
  String get fillFromScale => '照體脂計顯示填寫';

  @override
  String get noteLogged => '已記錄筆記';

  @override
  String get noteUpdated => '已更新筆記';

  @override
  String get noteHint => '例如：晚上聚餐，吃得比平常多';

  @override
  String get sleepWakeBeforeBed => '起床時間要在入睡之後';

  @override
  String get sleepOver24Hours => '一次睡眠不超過 24 小時';

  @override
  String get sleepWakeInFuture => '起床時間不能晚於現在';

  @override
  String get sleepStartLabel => '入睡';

  @override
  String get sleepEndLabel => '起床';

  @override
  String get qualityLabel => '品質';

  @override
  String get sleepNoteHint => '例如：睡前喝了咖啡、半夜醒來';

  @override
  String weightRangeError({required String min, required String max}) {
    return '請輸入 $min – $max kg 之間的數值。';
  }

  @override
  String weightLogged({required String weight}) {
    return '已記錄 $weight kg';
  }

  @override
  String weightUpdated({required String weight}) {
    return '已更新為 $weight kg';
  }

  @override
  String get symptomSeverity => '不適程度';

  @override
  String wellnessKindHow({required String kind}) {
    return '$kind如何？';
  }

  @override
  String get wellnessNoteHint => '例如：久坐一整天，下背有點緊';

  @override
  String get bmiBandUnder => '體重過輕';

  @override
  String get bmiBandHealthy => '健康體重';

  @override
  String get bmiBandOver => '過重';

  @override
  String get bmiBandObese => '肥胖';

  @override
  String yearsCount({required int count}) {
    return '$count 年';
  }

  @override
  String get logAction => '記錄';

  @override
  String logItem({required String item}) {
    return '記錄$item';
  }

  @override
  String trendReadingsLabel({required String item, required int count}) {
    return '$item走勢，$count 筆';
  }

  @override
  String get bodyScaleCompareSame => '體脂計估計，請用同一台比較';

  @override
  String get noWeightEntries => '沒有體重紀錄';

  @override
  String get trendWeight => '趨勢體重';

  @override
  String latestOn({required String date, required String value}) {
    return '最近 $date $value';
  }

  @override
  String weightChartLabel({required int count}) {
    return '體重走勢，$count 次';
  }

  @override
  String weightChartIdle({required int count}) {
    return '線為 7 日平均 · $count 次秤重';
  }

  @override
  String trendValue({required String value}) {
    return '趨勢 $value';
  }

  @override
  String get allWeightEntries => '所有體重紀錄';

  @override
  String get buildSection => '體位';

  @override
  String get waistToHipRatio => '腰臀比';

  @override
  String get bmiStandardTaiwan => '國健署成人標準';

  @override
  String get fatMass => '脂肪量';

  @override
  String get waistAdviceTaiwan => '國健署建議腰圍：男 < 90 cm、女 < 80 cm';

  @override
  String get weeklyGoal => '每週目標';

  @override
  String get weeklyGoalPaused => '每週目標已暫停';

  @override
  String weeklyGoalButtonLabel({required int active, required int target}) {
    return '本週 $active / $target 個運動日，查看每週目標';
  }

  @override
  String activeDaysPerWeek({required int count}) {
    return '每週 $count 個運動日';
  }

  @override
  String get adjustWeeklyGoal => '調整每週目標';

  @override
  String get weeklyGoalPrompt => '每週要有幾個運動日。';

  @override
  String get setWeeklyGoal => '設定每週目標';

  @override
  String get streakSection => '連續達標';

  @override
  String get weekGoalMet => '本週目標已完成';

  @override
  String get weekActivity => '本週運動';

  @override
  String get notCountedInStreak => '不計入連續達標';

  @override
  String activeDaysCount({required int count}) {
    return '$count 個運動日';
  }

  @override
  String activeDaysToGo({required int count}) {
    return '還差 $count 個運動日';
  }

  @override
  String get streakRestartsThisWeek => '本週重新開始';

  @override
  String get noStreakYet => '沒有連續達標紀錄';

  @override
  String lastStreak({required int previous, required int best}) {
    return '上次連續達標 $previous 週，最佳 $best 週';
  }

  @override
  String get streakStartsAfterGoal => '達成一週目標後開始累積';

  @override
  String streakWeeks({required int count}) {
    return '連續達標 $count 週';
  }

  @override
  String streakPendingBest({required int best}) {
    return '本週進行中 · 最佳 $best 週';
  }

  @override
  String streakBest({required int best}) {
    return '最佳 $best 週';
  }

  @override
  String goalDayLabel({required int day}) {
    return '$day 日';
  }

  @override
  String goalDayActive({required int day}) {
    return '$day 日，有運動';
  }

  @override
  String activeDaysFraction({required int active, required int target}) {
    return '$active / $target 個運動日';
  }

  @override
  String goalFromThisWeek({required int count}) {
    return '本週起每週 $count 天';
  }

  @override
  String goalFromNextWeek({required int count}) {
    return '下週起每週 $count 天';
  }

  @override
  String get pauseWeeklyGoal => '暫停每週目標';

  @override
  String get pauseWeeklyGoalMessage => '暫停期間的週不會累積，也不會中斷連續達標。';

  @override
  String get pauseThisWeek => '暫停本週';

  @override
  String get pauseUntilResumed => '直到手動恢復';

  @override
  String get activeDaysPerWeekQuestion => '一週想要有幾個運動日';

  @override
  String suggestedDays({required int count}) {
    return '過去四週平均：每週 $count 天';
  }

  @override
  String get goalStartSection => '從什麼時候開始';

  @override
  String get fromNextWeek => '下週起';

  @override
  String get fromNextWeekDetail => '本週仍用原本的目標計算';

  @override
  String get applyThisWeek => '本週就套用';

  @override
  String get applyThisWeekDetail => '重新計算本週';

  @override
  String get pauseOrTurnOff => '暫停或關閉';

  @override
  String get weeklyGoalOffDetail => '關閉時隱藏目標與連續達標';

  @override
  String get thisWeekPaused => '本週已暫停';

  @override
  String thisWeekActiveDays({required int active, required int target}) {
    return '本週 $active / $target 個運動日';
  }

  @override
  String get workoutInProgress => '訓練進行中';

  @override
  String workoutCurrentSet({
    required String exercise,
    required int set,
    required int done,
  }) {
    return '$exercise · 第 $set 組 · 已完成 $done 組';
  }

  @override
  String get backToWorkout => '回到訓練';

  @override
  String get thisSession => '本次';

  @override
  String get setsCompleted => '已完成組數';

  @override
  String get exerciseProgress => '動作進度';

  @override
  String get personalRecords => '個人紀錄';

  @override
  String get otherEntries => '其他紀錄';

  @override
  String get customiseToday => '自訂首頁';

  @override
  String get showAll => '全部顯示';

  @override
  String get todayOnlyWithData => '僅在有數值時顯示';

  @override
  String reorderSection({required String section}) {
    return '調整$section的順序';
  }

  @override
  String moreItemsCount({required int count}) {
    return '另 $count 項';
  }

  @override
  String get nextStep => '下一步';

  @override
  String get includesEstimates => '含估計值';

  @override
  String partialMacros({required String macros}) {
    return '$macros有紀錄沒有數字，未計入。';
  }

  @override
  String routineCompleted({required String name}) {
    return '$name 已完成';
  }

  @override
  String get totalSets => '總組數';

  @override
  String get exercisesLabel => '動作';

  @override
  String get todaySectionGlance => '今日指標';

  @override
  String get todaySectionActivity => '今日活動';

  @override
  String get todaySectionWeek => '本週';

  @override
  String get todaySectionRecords => '今天的紀錄';

  @override
  String get todaySectionInsights => '值得注意';

  @override
  String weekdayActive({required String weekday}) {
    return '$weekday，有訓練或運動';
  }

  @override
  String allCount({required int count}) {
    return '全部 $count 筆';
  }

  @override
  String daysFraction({required int active, required int target}) {
    return '$active / $target 天';
  }

  @override
  String weightChange7Days({required String change}) {
    return '7 日 $change';
  }

  @override
  String trackingChangeRefused({required int count}) {
    return '已有 $count 次紀錄用這個追蹤方式，改了會讓舊紀錄變成另一種意思。要換成別的追蹤方式，請建立一個新動作。';
  }

  @override
  String get createCustomExercise => '建立自訂動作';

  @override
  String get editExercise => '編輯動作';

  @override
  String exerciseOfSource({required String source}) {
    return '$source動作';
  }

  @override
  String get createAndAdd => '建立並加入';

  @override
  String get nameSection => '名稱';

  @override
  String get exerciseNameHint => '例如：啞鈴臥推';

  @override
  String get trackingTypeSection => '追蹤方式';

  @override
  String get trackingTypeLocked => '建立後不能改成不相容的追蹤方式。';

  @override
  String get primaryMuscleOrPattern => '主要肌群或動作模式';

  @override
  String get equipmentSection => '器材';

  @override
  String get equipmentAny => '不指定';

  @override
  String get possibleDuplicate => '可能已經有這個動作';

  @override
  String entriesCount({required int count}) {
    return '$count 筆紀錄';
  }

  @override
  String get useThis => '使用這個';

  @override
  String get duplicateAdvice => '選既有動作，歷史與個人紀錄才不會被拆成好幾份。';

  @override
  String exerciseDemoLabel({required String name, required int count}) {
    return '$name示範，$count 個姿勢';
  }

  @override
  String get playing => '播放中';

  @override
  String get exerciseDemoCredit => '圖：Workout Guide／Everkinetic · CC BY-SA 4.0';

  @override
  String get myAliases => '我的別名';

  @override
  String get aliasesHint => '用、分隔，例如：深蹲、squat';

  @override
  String get aliasesUpdated => '已更新別名';

  @override
  String get cannotMergeSelf => '不能和自己合併';

  @override
  String mergeTitle({required String duplicate, required String canonical}) {
    return '把「$duplicate」併入「$canonical」？';
  }

  @override
  String mergeMessage({required String canonical}) {
    return '過去的紀錄改算在「$canonical」下，動作不再出現在選擇器。紀錄的內容不會被改寫，但這個合併無法復原。';
  }

  @override
  String mergeInto({required String canonical}) {
    return '併入「$canonical」';
  }

  @override
  String mergedInto({required String canonical}) {
    return '已併入「$canonical」';
  }

  @override
  String get addThisExercise => '加入這個動作';

  @override
  String get otherVariations => '同一動作的其他做法';

  @override
  String get cuesSection => '重點提示';

  @override
  String get removeFavorite => '取消收藏';

  @override
  String get addFavorite => '加入收藏';

  @override
  String get favoriteRemoved => '已取消收藏';

  @override
  String get favoriteAdded => '已加入收藏';

  @override
  String get editExerciseDetail => '名稱、器材、部位';

  @override
  String get editMyAliases => '編輯我的別名';

  @override
  String builtInNames({required String names}) {
    return '目前用內建名稱：$names';
  }

  @override
  String get mergeIntoAnother => '合併到另一個動作';

  @override
  String get mergeIntoAnotherDetail => '重複建立時，把紀錄併到同一個動作下';

  @override
  String get unhide => '取消隱藏';

  @override
  String get hideExercise => '隱藏這個動作';

  @override
  String unhidden({required String name}) {
    return '已取消隱藏「$name」';
  }

  @override
  String hidden({required String name}) {
    return '已隱藏「$name」';
  }

  @override
  String get bodyPartLabel => '部位';

  @override
  String get primaryMuscles => '主要肌群';

  @override
  String get secondaryMuscles => '次要肌群';

  @override
  String get movementPatternLabel => '動作模式';

  @override
  String get lateralityLabel => '左右';

  @override
  String get lastWorkingSet => '上次工作組';

  @override
  String get estimatedMax => '估計最大重量';

  @override
  String get sessionsUnit => '次';

  @override
  String get trainingEntries => '訓練紀錄';

  @override
  String estimatedMaxTrend({required int count}) {
    return '估計最大重量走勢，$count 次訓練';
  }

  @override
  String get epleyEstimate => 'Epley 估計';

  @override
  String relativeLoadPercent({required int percent}) {
    return '相對負荷 $percent%';
  }

  @override
  String get last90Days => '近 90 天';

  @override
  String get filterTitle => '篩選';

  @override
  String filtersApplied({required int count}) {
    return '已套用 $count 個條件';
  }

  @override
  String showExercises({required int count}) {
    return '顯示 $count 個動作';
  }

  @override
  String get clearAll => '清除全部';

  @override
  String wholeRegion({required String region}) {
    return '整個$region';
  }

  @override
  String get sourceLabel => '來源';

  @override
  String get pickerTabRecent => '最近使用';

  @override
  String get pickerTabFavorites => '收藏';

  @override
  String get pickerTabHomeGym => '本健身房';

  @override
  String get pickerTabAll => '所有動作';

  @override
  String get pickerAddToRoutine => '加入課表';

  @override
  String get pickerAddToWorkout => '加入進行中的';

  @override
  String get pickerAddToEntry => '加入紀錄';

  @override
  String get pickerBrowse => '瀏覽與搜尋所有動作';

  @override
  String get pickerSingle => '選擇一個動作';

  @override
  String pickerPurposeFor({required String purpose, required String name}) {
    return '$purpose「$name」';
  }

  @override
  String discardSelectedTitle({required int count}) {
    return '放棄已選的 $count 個動作？';
  }

  @override
  String get discardSelected => '放棄已選的動作';

  @override
  String get keepChoosing => '繼續選擇';

  @override
  String get exerciseLibrary => '動作庫';

  @override
  String get chooseExercise => '選擇動作';

  @override
  String get addExercises => '新增動作';

  @override
  String get cantFindCreate => '找不到？建立自訂動作';

  @override
  String get searchExercisesHint => '搜尋動作、別名或器材…';

  @override
  String get clearAction => '清除';

  @override
  String daysAgo({required int count}) {
    return '$count 天前';
  }

  @override
  String aboutItem({required String name}) {
    return '$name說明';
  }

  @override
  String get selectionOrderHint => '加入順序 · 點一下可移除';

  @override
  String removeNumbered({required int index, required String name}) {
    return '移除第 $index 個：$name';
  }

  @override
  String addExercisesCount({required int count}) {
    return '加入 $count 個動作';
  }

  @override
  String get noMatchingExercises => '沒有符合的動作';

  @override
  String equipmentFilterHint({required String equipment}) {
    return '套用了「器材：$equipment」，要找的動作可能是別種器材。';
  }

  @override
  String get searchAgainHint => '換個說法、英文名稱或別名再試一次。';

  @override
  String get removeEquipmentFilter => '移除器材篩選再找一次';

  @override
  String get similarExercises => '相近的動作';

  @override
  String createNamed({required String name}) {
    return '建立「$name」';
  }

  @override
  String estimatedMaxValue({required int weight}) {
    return '估計最大重量 $weight kg';
  }

  @override
  String lastSetOn({required String date, required String set}) {
    return '上次 $date $set';
  }

  @override
  String get volumeTitle => '訓練量';

  @override
  String get notEnoughWorkouts => '訓練紀錄不足。';

  @override
  String volumeOf({required String exercise}) {
    return '$exercise的訓練量';
  }

  @override
  String insightWeeks({required int weeks}) {
    return '值得注意 · 近 $weeks 週';
  }

  @override
  String volumeSteady({required int sets, required String estimate}) {
    return '每週工作組數維持在 $sets 組，估計最大重量 $estimate。';
  }

  @override
  String get notYetEstimable => '尚無法估計';

  @override
  String get basisSection => '依據';

  @override
  String weeklySetsFrom({required int count}) {
    return '每週工作組數，取自 $count 次訓練紀錄。';
  }

  @override
  String get dataQualitySection => '資料品質與完整度';

  @override
  String workoutsAllLogged({required int count}) {
    return '$count 次訓練皆有紀錄';
  }

  @override
  String get weightRepsManual => '重量與次數為手動輸入';

  @override
  String get timeRangeSection => '時間範圍';

  @override
  String fullWeeks({required int count}) {
    return '$count 個完整週';
  }

  @override
  String get actionsSection => '可採取的行動';

  @override
  String volumeDropped({required int sets}) {
    return '每週組數比這段期間開始時少。要繼續進步，拉回 $sets 組左右。';
  }

  @override
  String get volumeStable => '目前的組數穩定。要繼續進步，小幅增加每週組數或重量。';

  @override
  String adjustRoutineSets({required String routine}) {
    return '調整「$routine」的組數';
  }

  @override
  String get notMedicalAdvice => '這是訓練紀錄的描述，不是醫療建議。';

  @override
  String get viewRawEntries => '查看這段期間的原始紀錄';

  @override
  String get noWorkingSets => '沒有工作組紀錄';

  @override
  String muscleWeeklySets({required String muscle, required int sets}) {
    return '$muscle 每週 $sets 組';
  }

  @override
  String muscleScaleLabel({required int top}) {
    return '色階由 0 到 $top 組以上';
  }

  @override
  String get setsPerWeek => '組 / 週';

  @override
  String get muscleMapLabel => '肌群訓練量人體圖，詳細數值列在下方';

  @override
  String get musclesTitle => '肌群';

  @override
  String get weeklySetsLast8 => '每週工作組數 · 近 8 週';

  @override
  String get setsThisWeekUnit => '組 · 本週';

  @override
  String priorWeeksSets({required int weeks, required String sets}) {
    return '前 $weeks 週 $sets 組';
  }

  @override
  String muscleSetsChart({required String muscle, required String sets}) {
    return '$muscle每週組數，$sets';
  }

  @override
  String heaviestSet({required String set, required String date}) {
    return '最重 $set · $date';
  }

  @override
  String estimatedMaxOn({required int weight, required String date}) {
    return '估計最大重量 $weight kg · $date';
  }

  @override
  String get last4Weeks => '近 4 週';

  @override
  String monthsCount({required int count}) {
    return '$count 個月';
  }

  @override
  String get weeklySetsTitle => '每週組數';

  @override
  String get last8Weeks => '近 8 週';

  @override
  String get weeklyWorkouts => '每週訓練';

  @override
  String get weeklyActivities => '每週運動';

  @override
  String get timesThisWeekUnit => '次 · 本週';

  @override
  String get noActivityEntries => '沒有運動紀錄';

  @override
  String minutesVersusUsual({required int minutes, required int usual}) {
    return '$minutes 分 · 平常 $usual 分';
  }

  @override
  String get trendDomainBody => '身體';

  @override
  String get trendDomainTraining => '訓練';

  @override
  String get trendDomainSleep => '睡眠';

  @override
  String get trendDomainNutrition => '飲食';

  @override
  String get trendDomainActivity => '活動';

  @override
  String areaTrend({required String area}) {
    return '$area趨勢';
  }

  @override
  String get weekdaySection => '星期';

  @override
  String get otherAreasSection => '同期其他領域';

  @override
  String get dailyEntries => '每日紀錄';

  @override
  String perWeekTimes({required String count}) {
    return '每週 $count 次';
  }

  @override
  String stepsValue({required String steps}) {
    return '$steps 步';
  }

  @override
  String timesValue({required String count}) {
    return '$count 次';
  }

  @override
  String weekFrom({required String date}) {
    return '$date 起';
  }

  @override
  String get last13Weeks => '近 13 週';

  @override
  String get pastYear => '過去一年';

  @override
  String get prior12Weeks => '前 12 週';

  @override
  String periodAverage({required String period}) {
    return '$period平均';
  }

  @override
  String get weeklyCount => '每週次數';

  @override
  String get weeklyAverage => '每週平均';

  @override
  String get weeklyTotal => '每週合計';

  @override
  String daysLoggedPerWeek({required String days}) {
    return '近 4 週每週平均 $days 天有紀錄';
  }

  @override
  String get scaleWeight => '秤上體重';

  @override
  String get weeklyVolume => '每週訓練量';

  @override
  String get restingHeartRate => '靜止心率';

  @override
  String get weightAndNutrition => '體重與飲食';

  @override
  String get energyBalance => '能量平衡';

  @override
  String energyNeeds({
    required int window,
    required int foodDays,
    required int weighings,
    required int currentFood,
    required int currentWeighings,
  }) {
    return '需要近 $window 天有 $foodDays 天完整飲食、$weighings 次體重（目前 $currentFood 天、$currentWeighings 次）';
  }

  @override
  String proteinNeeds({
    required int window,
    required int days,
    required int current,
  }) {
    return '需要近 $window 天有 $days 天完整飲食與體重（目前 $current 天）';
  }

  @override
  String get muscleSetsTitle => '肌群組數';

  @override
  String muscleSetsNeeds({required int count, required int current}) {
    return '需要近 4 週至少 $count 次訓練（目前 $current 次）';
  }

  @override
  String get possibleRelations => '可能的關聯';

  @override
  String get longRunSection => '長期走向';

  @override
  String actualExpenditure({required String kcal}) {
    return '實際消耗 $kcal kcal/天';
  }

  @override
  String intakeDeficit({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '近 $window 天平均攝取 $intake kcal，每天赤字 $balance kcal';
  }

  @override
  String intakeSurplus({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '近 $window 天平均攝取 $intake kcal，每天盈餘 $balance kcal';
  }

  @override
  String weightForecast({
    required String change,
    required int weeks,
    required String forecast,
  }) {
    return '趨勢體重每週 $change kg，$weeks 週後 $forecast kg';
  }

  @override
  String foodDaysWeighings({required int foodDays, required int weighings}) {
    return '$foodDays 天完整飲食 · $weighings 次體重';
  }

  @override
  String get intakeUnderlogged => '估計的消耗低於靜止代謝，紀錄的攝取可能少於實際。';

  @override
  String get estimatedFromEntries => '依紀錄估算';

  @override
  String weekendEatsMore({required String kcal}) {
    return '週末每天多吃 $kcal kcal';
  }

  @override
  String weekendEatsLess({required String kcal}) {
    return '週末每天少吃 $kcal kcal';
  }

  @override
  String weekdayWeekendKcal({
    required String weekday,
    required String weekend,
  }) {
    return '平日 $weekday kcal · 週末 $weekend kcal';
  }

  @override
  String get offsetsAllDeficit => '抵掉平日全部的赤字';

  @override
  String offsetsDeficitShare({required int percent}) {
    return '抵掉平日赤字 $percent%';
  }

  @override
  String weekdaysWeekends({
    required int window,
    required int weekdays,
    required int weekends,
  }) {
    return '近 $window 天，$weekdays 個平日、$weekends 個週末日';
  }

  @override
  String proteinMet({required String target}) {
    return '蛋白質達到 $target g/kg';
  }

  @override
  String proteinShort({required int grams}) {
    return '蛋白質每天差 $grams g';
  }

  @override
  String trainingRestProtein({required String trained, required String rest}) {
    return '訓練日 $trained · 休息日 $rest g/kg';
  }

  @override
  String proteinBasis({
    required String weight,
    required String target,
    required int days,
  }) {
    return '以 $weight kg、目標 $target g/kg 計 · $days 天完整飲食';
  }

  @override
  String allMusclesEnough({required int target}) {
    return '練到的肌群每週都有 $target 組以上';
  }

  @override
  String muscleOnlySets({required String muscle, required int sets}) {
    return '$muscle每週只有 $sets 組';
  }

  @override
  String underSets({required int target, required String muscles}) {
    return '不到 $target 組：$muscles';
  }

  @override
  String atLeastSets({required int target, required String muscles}) {
    return '$target 組以上：$muscles';
  }

  @override
  String pairRatio({
    required String first,
    required String second,
    required int firstSets,
    required int secondSets,
  }) {
    return '$first對$second $firstSets : $secondSets 組';
  }

  @override
  String get musclePush => '推';

  @override
  String get musclePull => '拉';

  @override
  String get muscleSetsBasis => '近 4 週每週組數，只計主要肌群';

  @override
  String weekendWakeLater({required String time}) {
    return '週末起床晚 $time';
  }

  @override
  String weekendWakeEarlier({required String time}) {
    return '週末起床早 $time';
  }

  @override
  String weekdayWeekendWake({
    required String weekday,
    required String weekend,
  }) {
    return '平日 $weekday · 週末 $weekend 起床';
  }

  @override
  String get correlationCaveat => '關聯，不代表因果';

  @override
  String get muscleFigureMale => '男性';

  @override
  String get muscleFigureFemale => '女性';

  @override
  String get workoutDiscarded => '已放棄這次訓練';

  @override
  String get endWorkout => '結束訓練';

  @override
  String get addExercise => '加入動作';

  @override
  String get notFilled => '未填寫';

  @override
  String get startExercising => '開始運動';

  @override
  String get finishWorkout => '完成訓練';

  @override
  String personalRecordSet({required String set}) {
    return '個人紀錄 · $set';
  }

  @override
  String get totalShort => '總';

  @override
  String get totalVolume => '總訓練量';

  @override
  String versusLastTime({required String change}) {
    return '比上次 $change';
  }

  @override
  String setsOfTotal({required int done, required int total}) {
    return '$done / $total 組';
  }

  @override
  String get restTitle => '休息';

  @override
  String get skipRest => '跳過休息';

  @override
  String get elapsedTime => '時間';

  @override
  String get workoutNotesTitle => '這次訓練的備註';

  @override
  String get workoutNotesHint => '例如：睡不好，握力先到極限';

  @override
  String get addWarmupSets => '加入熱身組';

  @override
  String get addDropSet => '加入遞減組';

  @override
  String get addFailureSet => '加入力竭組';

  @override
  String get replaceExercise => '替換這個動作';

  @override
  String get removeFromWorkout => '從這次訓練移除';

  @override
  String get superset => '超級組';

  @override
  String optionsFor({required String name}) {
    return '$name的選項';
  }

  @override
  String volumeValue({required String volume}) {
    return '訓練量 $volume kg';
  }

  @override
  String lastSetShort({required String date, required String set}) {
    return '上次 $date · $set';
  }

  @override
  String get loadPrevious => '載入';

  @override
  String get loadPreviousLabel => '過往紀錄';

  @override
  String get quickFill => '快速填入';

  @override
  String get quickFillLabel => '組數方案';

  @override
  String get setColumn => '組';

  @override
  String get repsColumn => '次';

  @override
  String get removeSet => '刪除組';

  @override
  String get addSet => '新增組';

  @override
  String editItem({required String item}) {
    return '編輯$item';
  }

  @override
  String setWeight({required String set}) {
    return '$set重量';
  }

  @override
  String setReps({required String set}) {
    return '$set次數';
  }

  @override
  String setDone({required String set}) {
    return '$set完成';
  }

  @override
  String removedNamed({required String name}) {
    return '已移除「$name」';
  }

  @override
  String get routineName => '課表名稱';

  @override
  String deleteNamedTitle({required String name}) {
    return '刪除「$name」？';
  }

  @override
  String get routineDeleteKeeps => '已完成的訓練紀錄會保留。';

  @override
  String get deleteRoutine => '刪除這份課表';

  @override
  String deletedNamed({required String name}) {
    return '已刪除「$name」';
  }

  @override
  String get startWorkout => '開始訓練';

  @override
  String get activityBlocksWorkout => '運動進行中，先結束運動才能開始訓練';

  @override
  String get plannedExercises => '計畫的動作';

  @override
  String get soreMusclesToday => '今天酸痛的肌群';

  @override
  String get recentlyDone => '最近實際完成';

  @override
  String setsAndMinutes({required int sets, required int minutes}) {
    return '$sets 組 · $minutes 分';
  }

  @override
  String get rename => '重新命名';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get joinSuperset => '與下一個組成超級組';

  @override
  String get leaveSuperset => '解除超級組';

  @override
  String get removeAction => '移除';

  @override
  String get eachSide => '單邊';

  @override
  String get oneSetLessToday => '今天少 1 組';

  @override
  String get loadPreviousFill => '以上次的重量與次數填入';

  @override
  String get myRoutines => '我的課表';

  @override
  String get loadFromHistory => '載入紀錄';

  @override
  String startWorkoutCount({required int count}) {
    return '開始訓練（$count 個動作）';
  }

  @override
  String get describeInWords => '一句話';

  @override
  String get addExercisesByHand => '手動新增動作';

  @override
  String get deleteAction => '刪除';

  @override
  String deleteNamed({required String name}) {
    return '刪除「$name」';
  }

  @override
  String get newRoutine => '新增課表';

  @override
  String get noWorkouts => '沒有訓練紀錄';

  @override
  String get selectAll => '選擇全部';

  @override
  String pastSet({
    required int number,
    required String weight,
    required int reps,
  }) {
    return '$number 組 $weight kg $reps 次';
  }

  @override
  String routineSummary({required int exercises, required int sets}) {
    return '$exercises 個動作 · $sets 組';
  }

  @override
  String get saveAsRoutine => '存成課表';

  @override
  String get describeWorkoutHint =>
      '例如：\n槓鈴深蹲 4×8 60kg\n臥推 3 組 10 下 40 公斤\n引體向上 3x8';

  @override
  String get noExercisesRead => '沒有讀到動作';

  @override
  String removeNamed({required String name}) {
    return '移除「$name」';
  }

  @override
  String get exerciseNotFound => '找不到這個動作';

  @override
  String setsTimesReps({
    required int sets,
    required int reps,
    required String weight,
  }) {
    return '$sets 組 × $reps 下 · $weight kg';
  }

  @override
  String setsSameWeight({
    required int sets,
    required String weight,
    required String reps,
  }) {
    return '$sets 組 · $weight kg × $reps 下';
  }

  @override
  String get editWorkout => '編輯訓練';

  @override
  String get timeSection => '時間';

  @override
  String get durationLabel => '時長';

  @override
  String savedAsRoutine({required String name}) {
    return '已存成課表「$name」';
  }

  @override
  String get keepAsIs => '維持原本';

  @override
  String get applyAction => '套用';

  @override
  String get progressionIncrease => '加重';

  @override
  String get progressionHold => '維持';

  @override
  String get progressionDeload => '退一階';

  @override
  String get nextTimeSuggestions => '下次的建議';

  @override
  String changedTo({required String name, required String weight}) {
    return '$name 改為 $weight kg';
  }

  @override
  String decreaseBy({required String amount}) {
    return '減少 $amount';
  }

  @override
  String increaseBy({required String amount}) {
    return '增加 $amount';
  }

  @override
  String get oneRepLess => '少 1 次';

  @override
  String get oneRepMore => '多 1 次';

  @override
  String get notLogged => '未記';

  @override
  String get deleteThisSet => '刪除這一組';

  @override
  String get platesImpossible => '槓片湊不出這個重量';

  @override
  String get emptyBar => '空槓';

  @override
  String platesPerSide({required String plates}) {
    return '每邊 $plates';
  }

  @override
  String setNumberWeight({required int number}) {
    return '第 $number 組重量';
  }

  @override
  String setNumberReps({required int number}) {
    return '第 $number 組次數';
  }

  @override
  String get replaceTodayOnly => '只替換今天';

  @override
  String get replaceTodayOnlyDetail => '只有這次用新動作';

  @override
  String get replaceInRoutine => '也更新課表';

  @override
  String get replaceInRoutineDetail => '之後都改用新動作';

  @override
  String replacedToday({required String name}) {
    return '今天改做「$name」';
  }

  @override
  String replacedInRoutine({required String routine, required String name}) {
    return '今天與之後的「$routine」都改做「$name」';
  }

  @override
  String replacePattern({required String pattern}) {
    return '替換 $pattern';
  }

  @override
  String todaysExerciseNumber({required String routine, required int number}) {
    return '今天的「$routine」· 第 $number 個動作';
  }

  @override
  String get replaceAction => '替換';

  @override
  String get candidateExercises => '候選動作';

  @override
  String get chooseFromAll => '從所有動作選擇';

  @override
  String get applyScope => '套用範圍';

  @override
  String equipmentChangeWarning({required String from, required String to}) {
    return '$from換$to沒有可靠的重量換算：保留組數、次數與 RIR，重量重新設定。';
  }

  @override
  String get exerciseInfo => '動作說明';

  @override
  String get noFinishedWorkout => '沒有完成的訓練';

  @override
  String get totalAmount => '總量';

  @override
  String get workloadSection => '這次的負荷';

  @override
  String get trainedAreas => '訓練部位';

  @override
  String get muscleSetsLast7 => '近 7 天肌群組數';

  @override
  String get editThisEntry => '編輯這筆紀錄';

  @override
  String get volumeSame => '總量與上次相同';

  @override
  String volumeChangePercent({required String change}) {
    return '總量比上次 $change%';
  }

  @override
  String setsAndVolume({required int sets, required String volume}) {
    return '$sets 組 · $volume kg';
  }

  @override
  String get qualityConfirmed => '已確認';

  @override
  String get qualityPortionEstimated => '份量為估計';

  @override
  String get qualityCustomFood => '自訂食物';

  @override
  String get qualityQuickLog => '快速記錄';

  @override
  String get qualityAiEstimate => 'AI 估計';

  @override
  String qualityAiEstimateBy({required String source}) {
    return '$source 估計';
  }

  @override
  String get nutritionLabel => '營養標示';

  @override
  String photoItemsCount({required int count}) {
    return '照片裡有 $count 項';
  }

  @override
  String get mergeIntoOneFood => '合併成一個食物';

  @override
  String get logEachItem => '逐項記錄';

  @override
  String get nutrientNegative => '營養素不能是負數。';

  @override
  String updatedNamed({required String name}) {
    return '已更新「$name」';
  }

  @override
  String get editThisMeal => '編輯這一餐';

  @override
  String get newFood => '新增食物';

  @override
  String get editFood => '編輯食物';

  @override
  String get scanFoodOrLabel => '掃描食物或營養標示';

  @override
  String get createOnly => '只建立';

  @override
  String get createAndLog => '建立並記錄';

  @override
  String labelReadBy({required String provider, required String model}) {
    return '數字來自 $provider（$model）的判讀，請對照包裝核對。';
  }

  @override
  String photoEstimatedBy({required String provider, required String model}) {
    return '數字是 $provider（$model）從照片的估算，請核對。';
  }

  @override
  String get foodNameHint => '例如：雞胸肉';

  @override
  String get mealTypeOptional => '餐次';

  @override
  String get saveToLibrary => '存入食物庫';

  @override
  String get cupSize => '杯型';

  @override
  String get cupSizeHint => '例如：Tall';

  @override
  String get brandLabel => '品牌';

  @override
  String get brandHint => '例如：大成';

  @override
  String get foodOrDrink => '食物或飲品';

  @override
  String get volumeLabel => '容量';

  @override
  String get portionSection => '份量';

  @override
  String get portionHint => '例如：一碗';

  @override
  String get newCupSize => '新增杯型';

  @override
  String get nutrientsSection => '營養素';

  @override
  String per100Unit({required String unit}) {
    return '每 100 $unit';
  }

  @override
  String get perServingTotal => '一份總共';

  @override
  String get abvLabel => '酒精度';

  @override
  String get deleteThisMeal => '刪除這一餐';

  @override
  String get countryTW => '台灣';

  @override
  String get countryJP => '日本';

  @override
  String get countryUS => '美國';

  @override
  String get countryEU => '歐盟';

  @override
  String get countryAU => '澳洲';

  @override
  String get countryNZ => '紐西蘭';

  @override
  String get countryKR => '韓國';

  @override
  String get countryCN => '中國';

  @override
  String get countryCA => '加拿大';

  @override
  String brandInCountry({required String brand, required String country}) {
    return '$brand（$country）';
  }

  @override
  String get officialData => '官方資料';

  @override
  String updatedOn({required String date}) {
    return '更新 $date';
  }

  @override
  String get foodScopeAll => '全部';

  @override
  String get foodScopeRecent => '最近';

  @override
  String get foodScopeStarred => '收藏';

  @override
  String get foodScopeOwn => '自己的';

  @override
  String get foodScopeBrands => '品牌';

  @override
  String loggedNamed({required String name}) {
    return '已記錄「$name」';
  }

  @override
  String get loggedToast => '已記錄';

  @override
  String mealTypeHeaderLabel({required String meal}) {
    return '這是哪一餐，目前$meal';
  }

  @override
  String get unspecified => '不指定';

  @override
  String get searchFoodHint => '搜尋食物或品牌';

  @override
  String get takePhotoAction => '拍照';

  @override
  String get recentMealsSection => '近期用餐';

  @override
  String get noFoods => '沒有食物';

  @override
  String get eatenFoods => '吃過的食物';

  @override
  String get noRecentFoods => '沒有最近吃過的食物。';

  @override
  String get starredFoods => '收藏的食物';

  @override
  String get starredMeals => '收藏的餐';

  @override
  String get noFavorites => '沒有收藏。';

  @override
  String get noOwnFoods => '沒有自己的食物';

  @override
  String get noBuiltInBrands => '沒有內建的連鎖品牌。';

  @override
  String viewFullMenu({required String brand}) {
    return '$brand · 查看完整菜單';
  }

  @override
  String get noMatchingItems => '沒有符合的項目';

  @override
  String get notFoundQuestion => '找不到？';

  @override
  String get purposeSection => '目的';

  @override
  String mergedCount({required int count}) {
    return '已合併 $count 筆';
  }

  @override
  String removedWater({required int millilitres}) {
    return '已移除 $millilitres mL 的水';
  }

  @override
  String get splitDone => '已拆成獨立紀錄';

  @override
  String get mergeAction => '合併';

  @override
  String get mergeEntries => '合併幾筆紀錄';

  @override
  String get cancelMerge => '取消合併';

  @override
  String get mergeIntoMeal => '合併成一餐';

  @override
  String mergeCountIntoMeal({required int count}) {
    return '合併 $count 筆成一餐';
  }

  @override
  String get setGoal => '設定目標';

  @override
  String get changeAction => '變更';

  @override
  String get dailyIndicators => '每日指標';

  @override
  String get mealsSection => '餐點';

  @override
  String get mealShare => '佔比';

  @override
  String get mealShareHide => '隱藏佔比';

  @override
  String get noMealsThisDay => '這一天沒有記錄任何一餐';

  @override
  String get waterSection => '水';

  @override
  String removeWaterAt({required String time}) {
    return '移除 $time 的水';
  }

  @override
  String get otherNutrients => '其他營養素';

  @override
  String itemsCountShort({required int count}) {
    return '$count 項';
  }

  @override
  String get splitIntoEntry => '拆成獨立紀錄';

  @override
  String entriesWithoutKcal({required int count}) {
    return '$count 筆沒有熱量，實際更多';
  }

  @override
  String eatenKcal({required String kcal}) {
    return '已吃 $kcal kcal';
  }

  @override
  String eatenOfTarget({required String kcal, required String target}) {
    return '已吃 $kcal kcal，目標 $target kcal';
  }

  @override
  String get eatenKcalTitle => '已吃 kcal';

  @override
  String get remainingKcalTitle => '剩餘 kcal';

  @override
  String get overKcalTitle => '超過 kcal';

  @override
  String get workedOut => '推算';

  @override
  String get caffeineRemaining => '估計殘留咖啡因';

  @override
  String halfLifeBasis({required String hours}) {
    return '依半衰期 $hours 小時推算';
  }

  @override
  String caffeineReference({required String mg}) {
    return '就寢參考 $mg mg';
  }

  @override
  String get caffeineBelowReference => '低於就寢參考';

  @override
  String get caffeineBelowReferenceDone => '已低於就寢參考';

  @override
  String get liveActivities => '即時動態';

  @override
  String get endLiveActivity => '結束即時動態';

  @override
  String get last24Hours => '近 24 小時';

  @override
  String workedOutValue({required String value}) {
    return '$value · 推算';
  }

  @override
  String caffeineValue({required String mg}) {
    return '咖啡因 $mg mg';
  }

  @override
  String oneServingIs({required String serving}) {
    return '一份 = $serving';
  }

  @override
  String get starred => '已收藏';

  @override
  String get starAction => '收藏';

  @override
  String get starThisFood => '收藏這個食物';

  @override
  String get editThisFood => '編輯這個食物';

  @override
  String addPortion({required String portion}) {
    return '加入 $portion';
  }

  @override
  String get servingsLabel => '份數';

  @override
  String get actualAmount => '實際份量';

  @override
  String get barcode => '條碼';

  @override
  String get allergens => '過敏原';

  @override
  String get none => '無';

  @override
  String get valueTypeMaxNote => '標示上限值，實際可能較低。';

  @override
  String dataSource({required String source}) {
    return '資料來源：$source';
  }

  @override
  String get deleteThisFood => '刪除這個食物';

  @override
  String itemsWithoutKcal({required int count}) {
    return '$count 項沒有熱量';
  }

  @override
  String get thisMeal => '這一餐';

  @override
  String get finishEditing => '完成編輯';

  @override
  String logItemsCount({required int count}) {
    return '記錄 $count 項';
  }

  @override
  String get plateEmpty => '這一餐沒有項目。';

  @override
  String get photoEstimate => '照片估算';

  @override
  String get retry => '重試';

  @override
  String get chooseAiFirst => '先選一個 AI 才能產生草稿。';

  @override
  String get foodPhoto => '食物照片';

  @override
  String get describeMealHint => '例如：早餐 蛋餅加大杯冰奶茶';

  @override
  String get draftSection => '草稿';

  @override
  String openAiSettings({required String me}) {
    return '到「$me > AI」設定';
  }

  @override
  String get dailyKcalGoal => '每日熱量目標';

  @override
  String get kcalRangeError => '請填 800–6000 kcal。';

  @override
  String numberRangeError({required String min, required String max}) {
    return '請填 $min–$max。';
  }

  @override
  String get weeklyChange => '每週變化';

  @override
  String get dailyTargets => '每日目標';

  @override
  String get kcalTarget => '熱量目標';

  @override
  String get estimateFromBody => '依身體資料估算';

  @override
  String get estimateFromBodyDetail => '體重、身高、年齡、性別與活動量';

  @override
  String get setMyself => '自己設定';

  @override
  String get bodyData => '身體資料';

  @override
  String yearValue({required int year}) {
    return '$year 年';
  }

  @override
  String get activityLevelSection => '活動量';

  @override
  String get macroSplit => '營養素分配';

  @override
  String get byGoal => '依目的';

  @override
  String perKgBodyWeight({required String grams}) {
    return '每公斤體重 $grams g';
  }

  @override
  String get proteinPerKgTitle => '蛋白質（每公斤體重）';

  @override
  String byGoalGrams({required String grams}) {
    return '依目的 $grams g';
  }

  @override
  String percentOfKcal({required int percent}) {
    return '熱量的 $percent%';
  }

  @override
  String get fatPercentTitle => '脂肪（占熱量 %）';

  @override
  String defaultPercent({required int percent}) {
    return '預設 $percent%';
  }

  @override
  String get restOfKcal => '其餘的熱量';

  @override
  String get resultSection => '結果';

  @override
  String get restingMetabolism => '基礎代謝';

  @override
  String get maintenanceKcal => '維持熱量';

  @override
  String get dailyKcal => '每日熱量';

  @override
  String missingInputs({required String inputs}) {
    return '缺少$inputs';
  }

  @override
  String limitValue({required String value}) {
    return '上限 $value';
  }

  @override
  String fromRecentFoodAndWeight({required int days}) {
    return '依近 $days 天飲食與體重';
  }

  @override
  String get mifflinEstimate => 'Mifflin-St Jeor 估計';

  @override
  String get noCamera => '沒有可用的相機';

  @override
  String get pickFromLibrary => '從相簿選取';

  @override
  String servingAndKcal({required String serving, required String kcal}) {
    return '一份 $serving · $kcal kcal';
  }

  @override
  String get foodLibrary => '食物庫';

  @override
  String get noOwnFoodsSentence => '沒有自己的食物。';

  @override
  String get noMatchingFoods => '沒有符合的食物。';

  @override
  String get officialReadOnly => '官方資料，唯讀';

  @override
  String splitIntoCount({required int count}) {
    return '已拆成 $count 筆';
  }

  @override
  String get splitThisMeal => '拆開這一餐';

  @override
  String usualMealType({required String meal}) {
    return '常用：$meal';
  }

  @override
  String get whichMeal => '這是哪一餐';

  @override
  String splitDishTitle({required int count}) {
    return '要把這道料理拆成 $count 筆獨立紀錄嗎？';
  }

  @override
  String splitDishMessage({required String dish}) {
    return '拆開後每項成分各自成為一筆紀錄，可以單獨編輯、移到別餐或刪除，「$dish」這一層就不存在了。';
  }

  @override
  String get nowLabel => '現在';

  @override
  String get afterSplit => '拆開後';

  @override
  String componentsCount({required int count}) {
    return '$count 項成分';
  }

  @override
  String otherCount({required int count}) {
    return '其他 $count 項';
  }

  @override
  String get undoWithin30s => '30 秒內可以復原。';

  @override
  String get waterGlass => '一杯';

  @override
  String get waterLargeGlass => '大杯';

  @override
  String get waterBottle => '一瓶';

  @override
  String get waterPerTap => '一次記多少';

  @override
  String get customAction => '自訂';

  @override
  String get moreAction => '更多';

  @override
  String get waterPerTapMl => '一次記多少 mL';

  @override
  String get waterReference => '每日參考量';

  @override
  String get waterReferenceMl => '每日參考量 mL';

  @override
  String get waterReferenceNote => '族群參考值，實際需求因人而異';

  @override
  String get waterReferenceHpa => '國健署';

  @override
  String get waterReferenceNone => '不設定';

  @override
  String waterFastWarning({required String millilitres}) {
    return '1 小時內已記錄 $millilitres mL。短時間大量喝水可能造成低血鈉，請分次慢慢喝。';
  }

  @override
  String waterPerTapLabel({required int millilitres}) {
    return '一次記多少，目前 $millilitres 毫升';
  }

  @override
  String waterTimesLast({required int count, required String time}) {
    return '$count 次 · 最近 $time';
  }

  @override
  String allDrinksTotal({required int millilitres}) {
    return '飲品總量 $millilitres mL（含咖啡、茶等）';
  }

  @override
  String todayAt({required String time}) {
    return '今天 $time';
  }

  @override
  String yesterdayAt({required String time}) {
    return '昨天 $time';
  }

  @override
  String addNamed({required String name}) {
    return '加入$name';
  }

  @override
  String get contentsSection => '內容';

  @override
  String get muscleMapSetting => '人體圖';

  @override
  String get conventionMessage => '每日總計的名稱、鹽分單位與上限；食物頁照它自己的標示。';

  @override
  String get profileSection => '個人資料';

  @override
  String get goalsAndReminders => '目標與提醒';

  @override
  String get featuresSection => '功能';

  @override
  String get exerciseLibraryDetail => '瀏覽、搜尋與建立自訂動作';

  @override
  String modulesEnabled({required String modules}) {
    return '$modules 已啟用';
  }

  @override
  String get notEnabled => '未啟用';

  @override
  String get dataSection => '資料';

  @override
  String databaseRecovered({required String path}) {
    return '上次的資料檔無法讀取，已移到 $path，並從空白重新開始。舊檔案沒有被刪除。';
  }

  @override
  String get localData => '本機資料';

  @override
  String get dataSourcesDetail => '手動輸入、匯入與內建目錄';

  @override
  String get showDemoData => '顯示示範資料';

  @override
  String get exportTitle => '匯出';

  @override
  String get exportDetail => '完整封存 JSON · CSV 檢視';

  @override
  String get privacyDetail => '資料存在哪裡、會送出什麼';

  @override
  String get aboutSection => '關於';

  @override
  String get versionLabel => '版本';

  @override
  String get exerciseImages => '動作圖';

  @override
  String get referencesTitle => '文獻來源';

  @override
  String get openSourceLicenses => '開源授權';

  @override
  String get workoutsFigure => '訓練';

  @override
  String get activeDaysFigure => '運動日';

  @override
  String get daysUnit => '天';

  @override
  String get weeksUnit => '週';

  @override
  String get startedLogging => '開始紀錄';

  @override
  String goalSummaryText({required int target, required int active}) {
    return '每週 $target 個運動日 · 本週 $active';
  }

  @override
  String proteinGrams({required String grams}) {
    return '蛋白質 $grams g';
  }

  @override
  String foodLibrarySummary({required int own, required int brands}) {
    return '自己的 $own 種 · 品牌 $brands 家';
  }

  @override
  String get birthYearHint => '例如 1995';

  @override
  String get birthYearError => '出生年請填 4 位數西元年。';

  @override
  String get sexUseMessage => '只用來估算每日熱量。';

  @override
  String get fullArchiveJson => '完整封存（JSON）';

  @override
  String get fullArchiveDetail => '可完整還原';

  @override
  String get fullArchiveDone => '已建立完整封存';

  @override
  String get csvViews => 'CSV 檢視';

  @override
  String get csvViewsDetail => '方便閱讀，不保證無損';

  @override
  String get csvViewsDone => '已建立 CSV 檢視';

  @override
  String get exportNotEncrypted => '匯出的檔案沒有加密。';

  @override
  String exportDoneFile({required String done, required String file}) {
    return '$done：$file';
  }

  @override
  String exportFailed({required String error}) {
    return '匯出失敗：$error';
  }

  @override
  String appliedTo({required String routine}) {
    return '已套用到「$routine」';
  }

  @override
  String get aiProposalTitle => 'AI 建議的修改';

  @override
  String aiProposalSubtitle({required String routine}) {
    return '訓練「$routine」· 尚未套用';
  }

  @override
  String get reject => '拒絕';

  @override
  String get acceptAndApply => '接受並套用';

  @override
  String get questionLabel => '提問';

  @override
  String get proposalQuestion => '「最近深蹲的組數是不是太少了？幫我加回來。」';

  @override
  String changesCount({required int count}) {
    return '改動 $count 個動作';
  }

  @override
  String get reasonLabel => '理由';

  @override
  String get proposalReason =>
      '每週工作組數從 12 降到 8，依「肌力維持」目標，訓練引擎建議的區間是 10 – 12 組。';

  @override
  String get proposalDataSent => '送出的資料：近 4 週訓練紀錄';

  @override
  String get proposalModel => '模型：自架端點';

  @override
  String get addedLabel => '新增';

  @override
  String get unchangedLabel => '不變';

  @override
  String setsTimesRepsShort({required int sets, required int reps}) {
    return '$sets 組 × $reps 次';
  }

  @override
  String get privacyStorage => '儲存';

  @override
  String get privacyRecords => '紀錄';

  @override
  String get privacyRecordsValue => '只在這台裝置';

  @override
  String get privacyAccount => '帳號';

  @override
  String get privacyServer => '伺服器';

  @override
  String get privacyDeleted => '刪除的紀錄';

  @override
  String get privacyDeletedValue => '可復原';

  @override
  String get privacyUninstall => '解除安裝 App';

  @override
  String get privacyUninstallValue => '清除所有紀錄';

  @override
  String get privacyCameraSection => '相機與相簿';

  @override
  String get privacyCamera => '相機';

  @override
  String get privacyCameraValue => '只在掃描時開啟';

  @override
  String get privacyPhotos => '相簿';

  @override
  String get privacyPhotosValue => '讀取最新一張做為選取按鈕的縮圖';

  @override
  String get privacyScalePhotos => '體脂計與圍度照片';

  @override
  String get privacyScalePhotosValue => '在裝置上讀取數字，不送出';

  @override
  String privacyHealthSection({required String platform}) {
    return '健康資料（$platform）';
  }

  @override
  String get privacyPermission => '權限';

  @override
  String get privacyPermissionValue => '讀取與寫入';

  @override
  String get privacyReading => '讀取';

  @override
  String get privacyReadingValue => '第一次讀取全部紀錄，之後開啟 App 時讀取最近 30 天';

  @override
  String get privacyLeavesDevice => '送出裝置';

  @override
  String get privacyNo => '否';

  @override
  String get privacyToAi => '提供給 AI';

  @override
  String get privacyAds => '用於廣告';

  @override
  String get privacyDisconnect => '中斷連接後';

  @override
  String get privacyDisconnectValue => '已讀入的紀錄保留';

  @override
  String get privacyKinds => '讀取類別';

  @override
  String get privacyDefault => '預設';

  @override
  String get privacyNotUsed => '不使用';

  @override
  String get privacyAppleIntelligence => '在裝置上執行';

  @override
  String get privacyCloudReceives => '雲端 AI 收到';

  @override
  String get privacyCloudReceivesValue => '輸入的文字、照片辨識出的文字、估算用的食物照片';

  @override
  String get privacyFoodPhotos => '食物照片';

  @override
  String get privacyFoodPhotosValue => '先移除位置與拍攝資訊，不保存';

  @override
  String get privacyOtherData => '其他照片、其他紀錄、健康資料';

  @override
  String get privacyNotSent => '不送出';

  @override
  String get privacyFirstSend => '第一次送出文字或照片前';

  @override
  String privacyFirstSendValue({required String me}) {
    return '分別詢問同意，可在「$me > AI」撤回';
  }

  @override
  String get privacyAiResults => 'AI 的結果';

  @override
  String get privacyAiResultsValue => '草稿，確認後才記錄';

  @override
  String get privacyGoogleFree => 'Google AI Studio 免費額度';

  @override
  String get privacyGoogleFreeValue => '內容可能用於改進產品並經人工審閱';

  @override
  String get privacyKeysSection => '金鑰與匯出';

  @override
  String get privacyApiKeys => 'API 金鑰';

  @override
  String get privacyApiKeysValue => '系統安全儲存區，不進資料庫';

  @override
  String get privacyExportFiles => '匯出檔案';

  @override
  String privacyExportFilesValue({required String me}) {
    return '只在「$me > 匯出」手動建立';
  }

  @override
  String get privacyExportContents => '匯出內容';

  @override
  String get privacyExportContentsValue => '不含 API 金鑰';

  @override
  String get privacyUpload => '上傳';

  @override
  String get refUse01 => '基礎代謝的估算公式';

  @override
  String get refUse02 => '健康成人以 Mifflin-St Jeor 估算最接近實測';

  @override
  String get refUse03 => '活動量（身體活動程度）的分級';

  @override
  String get refUse04 => '維持與增肌的蛋白質，每公斤 1.6–1.8 g（範圍 1.4–2.0 g）';

  @override
  String get refUse05 => '減脂每週 0.5–1% 體重、提高蛋白質、脂肪占熱量 15–30%';

  @override
  String get refUse06 => '減脂的蛋白質每公斤 2.2 g';

  @override
  String get refUse07 => '減脂預設每週 0.5% 體重，慢一點保留較多去脂體重';

  @override
  String get refUse08 => '增肌只用小盈餘，預設每週 0.25% 體重';

  @override
  String get refUse09 => '每公斤體重約 7,700 kcal 只是粗略的起點';

  @override
  String get refUse10 => '膳食纖維每 1,000 kcal 14 g、脂肪占熱量 20–35%';

  @override
  String get refUse11 => '台灣：成人每日鈉 2,400 mg 以下';

  @override
  String get refUse12 => '日本：成人每日食塩相当量男性 7.5 g、女性 6.5 g 以下';

  @override
  String get refUse13 => '日本標示：食塩相当量（g）＝鈉（mg）× 2.54 ÷ 1,000';

  @override
  String get refUse14 => '美國、加拿大：成人每日鈉 2,300 mg 以下';

  @override
  String get refUse15 => '歐盟：成人每日鈉 2.0 g，即鹽 5 g';

  @override
  String get refUse16 => '歐盟標示：碳水化合物不含膳食纖維；鹽＝鈉 × 2.5';

  @override
  String get refUse17 => '澳洲、紐西蘭：成人每日鈉 2,000 mg';

  @override
  String get refUse18 => '澳洲、紐西蘭標示：碳水化合物不含膳食纖維，能量以 kJ 標示';

  @override
  String get refUse19 => '韓國：成人每日鈉 2,300 mg 以下';

  @override
  String get refUse20 => '中國：成人每日食鹽 5 g 以下';

  @override
  String get refUse21 => '殘留咖啡因依半衰期 5 小時推算';

  @override
  String get refUse22 => '半衰期因人而異，推算值不是量測';

  @override
  String get refUse23 => '睡前 4 小時 100 mg 未測得影響，參考線不是安全門檻';

  @override
  String get refUse46 => '35 mg 參考線由睡前 8.8 小時 107 mg、13.2 小時 217.5 mg 推算';

  @override
  String get refUse47 => '每日參考量 1,500 mL，只計白開水';

  @override
  String get refUse48 => '腎臟每小時約可排出 0.7–1.0 L，1 小時內 1,000 mL 以上時提醒';

  @override
  String get refUse24 => '未設定目標時以每晚 8 小時計（共識為 7 小時以上）';

  @override
  String get refUse25 => '少睡的影響在 14 天內持續累積';

  @override
  String get refUse26 => '多睡不以一比一抵銷少睡';

  @override
  String get refUse27 => '恢復沒有公認的速率，不設衰減';

  @override
  String get refUse28 => '估計最大重量（1RM）的公式';

  @override
  String get refUse29 => '超過 10 下不估計；5 下最準';

  @override
  String get refUse30 => '7–10 下的估計仍準確';

  @override
  String get refUse31 => '次數越多，個人與動作之間的差異越大';

  @override
  String get refUse42 => '以 %1RM 表示訓練負荷';

  @override
  String get refUse43 => '以 %1RM 表示負荷的更新指引';

  @override
  String get refUse44 => '負荷與接近力竭程度是不同變數';

  @override
  String get refUse45 => '以剩餘次數（RIR）表示接近力竭程度';

  @override
  String get refUse32 => '每肌群每週 10 組以上的組數劑量反應';

  @override
  String get refUse33 => '蛋白質每公斤 1.6 g 後增益不再明顯';

  @override
  String get refUse34 => '最大心率以 208 − 0.7 × 年齡估算';

  @override
  String get refUse35 => '有安靜心率時以心率儲備劃分區間';

  @override
  String get refUse36 => 'BMI 過輕、正常、過重、肥胖的分級';

  @override
  String get refUse37 => '去脂體重指數（FFMI）的定義';

  @override
  String get refUse38 => '增肌減脂只用小赤字：每天約 500 kcal 時瘦體重不再增加';

  @override
  String get refUse39 => '增肌減脂可選小赤字或維持熱量，搭配高蛋白質';

  @override
  String get refUse40 => '增肌減脂在維持熱量時蛋白質每公斤 2.0 g';

  @override
  String get refUse41 => '增肌減脂的蛋白質以 BMI 30 的體重為上限';

  @override
  String get refSectionTargets => '每日熱量與營養素目標';

  @override
  String get refSectionLabels => '營養標示';

  @override
  String get refSectionCaffeine => '咖啡因';

  @override
  String get refSectionSleepDebt => '睡眠債';

  @override
  String get refSectionTraining => '訓練與趨勢';

  @override
  String get refSectionHeartZones => '運動心率區間';

  @override
  String get refSectionBody => '身體';

  @override
  String get openLink => '開啟連結';

  @override
  String get openAction => '開啟';

  @override
  String get cannotOpenLink => '無法開啟連結';

  @override
  String apiKeyTitle({required String provider}) {
    return '$provider API 金鑰';
  }

  @override
  String get apiKeyHint => '貼上金鑰，留空即刪除';

  @override
  String get apiEndpoint => 'API 位址';

  @override
  String get azureResourceUrl => 'Azure AI Foundry 資源網址';

  @override
  String get modelLabel => '模型';

  @override
  String get modelListUnavailable => '讀不到模型清單，請直接輸入名稱。';

  @override
  String get typeOwn => '自己輸入';

  @override
  String get deploymentName => '部署名稱';

  @override
  String get modelHint => '例如 gemini-3.8-flash';

  @override
  String get signInInBrowser => '在瀏覽器登入';

  @override
  String signInInstructions({required String uri, required String code}) {
    return '到 $uri 輸入代碼 $code，以公司或學校帳號登入。';
  }

  @override
  String get copyCode => '複製代碼';

  @override
  String get okAction => '好';

  @override
  String get signedInCopilot => '已登入 Microsoft 365 Copilot';

  @override
  String get clientId => '用戶端 ID';

  @override
  String get clientIdHint => 'Entra 應用程式註冊的 Application (client) ID';

  @override
  String get tenant => '租用戶';

  @override
  String get tenantHint => '留空代表 organizations';

  @override
  String get revokeConsentTitle => '撤回同意？';

  @override
  String get revokeConsentMessage => '下次使用雲端 AI 前會再次詢問。';

  @override
  String get revokeConsent => '撤回同意';

  @override
  String get autoNameMergedMeals => '自動命名合併的餐點';

  @override
  String get serviceSection => '服務';

  @override
  String get signedIn => '已登入';

  @override
  String get signIn => '登入';

  @override
  String get waitingForBrowser => '等待瀏覽器登入…';

  @override
  String get signInAgain => '重新登入';

  @override
  String get apiKey => 'API 金鑰';

  @override
  String get isSet => '已設定';

  @override
  String get loadingModels => '讀取模型…';

  @override
  String get notChosen => '未選擇';

  @override
  String get consentTextAndPhotos => '目前已同意送出文字與照片';

  @override
  String get consentText => '目前已同意送出文字';

  @override
  String get consentPhotos => '目前已同意送出照片';

  @override
  String get checkingEllipsis => '檢查中…';

  @override
  String get appleNotEligible => '這台裝置不支援 Apple Intelligence';

  @override
  String get appleNotEnabled => '到「設定 > Apple Intelligence 與 Siri」開啟';

  @override
  String get appleModelNotReady => '模型下載中';

  @override
  String get appleUnavailable => '需要 iOS 26 以上且支援 Apple Intelligence';

  @override
  String get azurePortal => 'Azure 入口網站';

  @override
  String get copilotWarning =>
      'Beta API，不支援正式產品。需要公司或學校帳號、Microsoft 365 Copilot 授權與 Entra 應用程式註冊。';

  @override
  String get googleFreeWarning => '免費額度的內容可能被 Google 用於改進產品並經人工審閱。請使用已啟用計費的金鑰。';

  @override
  String get cloudAi => '雲端 AI';

  @override
  String sendToProvider({required String provider}) {
    return '送到 $provider？';
  }

  @override
  String cloudConsentMessage({required String me}) {
    return '只送出輸入的文字或從照片辨識出的文字，不送出照片與其他紀錄。可在「$me > AI」撤回。';
  }

  @override
  String get agreeAndSend => '同意並送出';

  @override
  String sendPhotoToProvider({required String provider}) {
    return '送出食物照片到 $provider？';
  }

  @override
  String photoConsentMessage({required String me}) {
    return '只送出這張照片與補充說明，先移除照片裡的位置與拍攝資訊，不保存照片。可在「$me > AI」撤回。';
  }

  @override
  String aiFailureUnavailable({required String me}) {
    return 'AI 功能尚未設定，到「$me > AI」設定。';
  }

  @override
  String get aiFailureNeedsConsent => '未同意送出文字。';

  @override
  String aiFailureAuthentication({required String me}) {
    return '金鑰無效或沒有權限，到「$me > AI」重新設定。';
  }

  @override
  String get aiFailureRateLimited => '請求太頻繁或額度用完，稍後再試。';

  @override
  String get aiFailureNetwork => '連不上網路，稍後再試。';

  @override
  String get aiFailureProvider => 'AI 服務出了問題，稍後再試。';

  @override
  String get aiFailureUnreadable => 'AI 的回覆無法解讀，再試一次。';

  @override
  String get aiFailureNeedsPhotoConsent => '未同意送出照片。';

  @override
  String aiFailurePhotoUnsupported({required String me}) {
    return '目前的 AI 不能讀照片，到「$me > AI」換一個。';
  }

  @override
  String get aiFailureNoFood => '照片裡看不到食物或飲料，換一張再試。';

  @override
  String get aiFailurePhotoFormat => '這張照片的格式無法讀取，換一張再試。';

  @override
  String get prior4Weeks => '前 4 週';

  @override
  String againstBaseline({required String baseline}) {
    return '比$baseline';
  }

  @override
  String againstRecentBaseline({
    required String recent,
    required String baseline,
  }) {
    return '$recent比$baseline';
  }

  @override
  String changeMore({required String against, required String amount}) {
    return '$against多 $amount';
  }

  @override
  String changeLess({required String against, required String amount}) {
    return '$against少 $amount';
  }

  @override
  String sleepLoadMore({required String percent}) {
    return '前一晚睡得較久的訓練，訓練量平均多 $percent。';
  }

  @override
  String sleepLoadLess({required String percent}) {
    return '前一晚睡得較久的訓練，訓練量平均少 $percent。';
  }

  @override
  String workoutsCount({required int count}) {
    return '$count 次訓練';
  }

  @override
  String sleepSplitAt({required String time}) {
    return '以 $time 區分睡得較久或較少';
  }

  @override
  String get againstSameWorkout => '與同一訓練的平均相比';

  @override
  String weightChange4Weeks({required String change}) {
    return '4 週 $change kg';
  }

  @override
  String baselineTimes({required String baseline, required String count}) {
    return '$baseline $count 次';
  }

  @override
  String completeDays({required int complete, required int tracked}) {
    return '完整 $complete/$tracked 天';
  }

  @override
  String perDaySteps({required String steps}) {
    return '每天 $steps 步';
  }

  @override
  String get weightSteady => '體重在這段期間大致持平，沒有明顯變化。';

  @override
  String weightFalling({required String kg}) {
    return '體重以每週 $kg kg 的速度下降。';
  }

  @override
  String weightRising({required String kg}) {
    return '體重以每週 $kg kg 的速度上升。';
  }

  @override
  String basedOnWeights({required int count}) {
    return '依據 $count 筆體重紀錄';
  }

  @override
  String trainingGoalMet({required int count, required int goal}) {
    return '這是本週第 $count 次訓練，達成每週 $goal 次的目標。';
  }

  @override
  String trainingGoalShort({
    required int count,
    required int goal,
    required int left,
  }) {
    return '本週已完成 $count 次訓練，距離每週 $goal 次還差 $left 次。';
  }

  @override
  String get basedOnThisWeek => '依據本週訓練紀錄';

  @override
  String weeklyGoalTimes({required int goal}) {
    return '每週目標 $goal 次';
  }

  @override
  String volumeDropMaxHolding({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise的每週組數從 $first 組掉到 $last 組，估計最大重量沒有跟著掉。';
  }

  @override
  String volumeDropMaxFalling({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise的每週組數從 $first 組掉到 $last 組，估計最大重量也跟著下降。';
  }

  @override
  String basedOnWorkouts({required int count}) {
    return '依據 $count 次訓練紀錄';
  }

  @override
  String get excludesWarmups => '不含熱身組';

  @override
  String get dataComplete => '資料完整';

  @override
  String dataIncomplete({required int points, required int days}) {
    return '資料不完整，只有 $points / $days 天有紀錄';
  }

  @override
  String lastWeeksCount({required int count}) {
    return '近 $count 週';
  }

  @override
  String lastDaysAverage({required int count}) {
    return '近 $count 天平均';
  }

  @override
  String lastDaysCount({required int count}) {
    return '近 $count 天';
  }

  @override
  String progressionDeloadReason({required int count, required int reps}) {
    return '連續 $count 次沒做到 $reps 下，先退一階把次數做滿。';
  }

  @override
  String progressionMissedReps({required String sets, required int reps}) {
    return '上次 $sets，未做到 $reps 下，先維持同重量。';
  }

  @override
  String progressionMissedSets({required int done, required int planned}) {
    return '上次只做了 $done 組，先把 $planned 組做滿再加重。';
  }

  @override
  String get progressionTooHard => '上次做滿了，但那次訓練評為太吃力，先維持同重量。';

  @override
  String progressionNearLimit({required String rir}) {
    return '上次做滿了，但最後一組已經接近極限（RIR $rir），先維持同重量。';
  }

  @override
  String progressionIncreaseReason({
    required String done,
    required String planned,
    required String reserve,
    required String added,
  }) {
    return '上次 $done 做滿了 $planned$reserve，可以加 $added kg。';
  }

  @override
  String progressionReserve({required String rir}) {
    return '，最後一組還留 $rir 下';
  }

  @override
  String atLeastValue({required String value}) {
    return '至少 $value';
  }

  @override
  String get appleHealth => 'Apple 健康';

  @override
  String get healthConnectName => '健康資料同步';

  @override
  String get healthDataGeneric => '健康資料';

  @override
  String get strongWorkoutName => 'Strong 訓練';

  @override
  String get afterMerge => '合併後';

  @override
  String get splitAction => '拆開';

  @override
  String get aiDraftAction => 'AI 草稿';

  @override
  String get removePhoto => '移除照片';

  @override
  String get privacyWebSearch => '網路搜尋';

  @override
  String get privacyWebSearchValue => 'Anthropic、Google AI Studio 依內容搜尋公開的營養資料';

  @override
  String get workoutScheduled => '已安排';

  @override
  String get cancelSchedule => '取消安排';

  @override
  String get cancelWorkoutTitle => '取消這次訓練？';

  @override
  String get cancelWorkoutAction => '取消訓練';

  @override
  String get keepWorkout => '保留';

  @override
  String get commonView => '查看';

  @override
  String get schemeStraight => '基礎';

  @override
  String get schemeStraightHint => '每組同重量';

  @override
  String get schemeAscending => '逐漸加重';

  @override
  String get schemeAscendingHint => '重量逐組增加，次數逐組減少';

  @override
  String get schemeReverse => '大重量開始';

  @override
  String get schemeReverseHint => '第一組最重，之後逐組減重加次數';

  @override
  String get schemeFiveByFive => '5×5 力量';

  @override
  String get schemeFiveByFiveHint => '5 組 5 下同重量';

  @override
  String get schemeTopSet => '頂峰組';

  @override
  String get schemeTopSetHint => '一組最重，其餘減重';

  @override
  String get schemeDrop => '降重';

  @override
  String get schemeDropHint => '第一組最重，之後小幅減重';

  @override
  String get mainWeight => '主要重量';

  @override
  String get mainWeightRecent => '近 90 天最高';

  @override
  String get mainWeightEver => '歷史最高';

  @override
  String get setCountLabel => '組數';

  @override
  String get repCountLabel => '次數';

  @override
  String get oneSetLess => '少 1 組';

  @override
  String get oneSetMore => '多 1 組';

  @override
  String exerciseRecordsTitle({required String name}) {
    return '$name 紀錄';
  }

  @override
  String get earlierRecord => '較早的紀錄';

  @override
  String get laterRecord => '較新的紀錄';

  @override
  String get workoutTimeTitle => '運動時間';

  @override
  String get restTimeTitle => '休息時間';

  @override
  String get autoRestTitle => '完成一組後自動開始休息';

  @override
  String durationSeconds({required int seconds}) {
    return '$seconds 秒';
  }

  @override
  String sessionScheduledOpen({required String session}) {
    return '$session已安排，回到$session';
  }

  @override
  String get trackingTypeWeightDuration => '重量 + 時間';

  @override
  String repsValue({required int reps}) {
    return '$reps 次';
  }

  @override
  String get totalTime => '總時間';

  @override
  String get totalReps => '總次數';

  @override
  String get totalDistance => '總距離';

  @override
  String exerciseLastFigures({required String set}) {
    return '上次 $set';
  }

  @override
  String mostRepsSet({required String set, required String date}) {
    return '最多 $set · $date';
  }

  @override
  String longestSet({required String set, required String date}) {
    return '最長 $set · $date';
  }

  @override
  String furthestSet({required String set, required String date}) {
    return '最遠 $set · $date';
  }

  @override
  String get timeColumn => '時間';

  @override
  String setTime({required String set}) {
    return '$set時間';
  }

  @override
  String setDistance({required String set}) {
    return '$set距離';
  }

  @override
  String setNumberTime({required int number}) {
    return '第 $number 組時間';
  }

  @override
  String setNumberDistance({required int number}) {
    return '第 $number 組距離';
  }

  @override
  String get unitMinutes => '分';

  @override
  String get unitSeconds => '秒';

  @override
  String get setTimerStart => '開始';

  @override
  String get setTimerStartLabel => '開始計時';

  @override
  String get goalReached => '達成';

  @override
  String goalMetNights({required int count}) {
    return '達成 $count 晚';
  }

  @override
  String get statsSection => '統計';

  @override
  String get distributionSection => '分布';

  @override
  String get statHighest => '最高';

  @override
  String get statLowest => '最低';

  @override
  String get statLongest => '最長';

  @override
  String get statShortest => '最短';

  @override
  String get periodChange => '期間變化';

  @override
  String get changePerWeek => '每週變化';

  @override
  String get measurementsCount => '量測次數';

  @override
  String get sleepGoalMetLabel => '達成睡眠目標';

  @override
  String get weeklyGoalMetLabel => '達成每週目標';

  @override
  String get workoutsTotal => '訓練次數';

  @override
  String get stepsUnit => '步';

  @override
  String get gistUsual => '和平常差不多';

  @override
  String get gistMore => '比平常多';

  @override
  String get gistLess => '比平常少';

  @override
  String get gistSteady => '持平';

  @override
  String get gistRising => '上升';

  @override
  String get gistFalling => '下降';

  @override
  String get gistNotEnough => '資料不足，暫不比較';

  @override
  String coverageDays({required int count, required int total}) {
    return '$count/$total 天有紀錄';
  }

  @override
  String perNightChange({required String change}) {
    return '每晚 $change';
  }

  @override
  String perDayChange({required String change}) {
    return '每日 $change';
  }

  @override
  String perWeekChange({required String change}) {
    return '每週 $change';
  }

  @override
  String get halfNightsOver => '半數晚上超過';

  @override
  String get halfDaysOver => '半數日子超過';

  @override
  String nightsOutOf({required int count, required int total}) {
    return '$total 晚中 $count 晚';
  }

  @override
  String weeksOutOf({required int count, required int total}) {
    return '$total 週中 $count 週';
  }

  @override
  String completeOutOf({required int count, required int total}) {
    return '$total 天中 $count 天完整';
  }

  @override
  String get refSectionSummaries => '趨勢摘要';

  @override
  String get refUseSummaryNarrative => '趨勢頁頂端以一句摘要說明整體走向';

  @override
  String get refUseSummaryVerbal => '「比平常多」等字眼一律附數字，並由個人平常範圍判定';

  @override
  String get refUseSummaryAbsolute => '比較寫成絕對差（每晚 +18 分），不只寫百分比';

  @override
  String get refUseSummaryFrequencies => '達成次數寫成「7 晚中 5 晚」而非百分比';

  @override
  String get refUseSummaryIntegers => '摘要數字取整，不顯示多餘小數';

  @override
  String get refUseSummaryReference => '比較基準固定為個人平常範圍與前 12 週';

  @override
  String get sleepRegularityIndexLabel => '睡眠規律指數';

  @override
  String get refSectionSleepRegularity => '睡眠規律';

  @override
  String get refUseSleepRegularityIndex => '睡眠規律指數的定義：相鄰兩天同一時刻睡著或醒著的一致程度';

  @override
  String get refUseSocialJetlag => '社交時差：週末與平日的睡眠中點差';

  @override
  String get stepGoal => '步數目標';

  @override
  String get stepGoalMetLabel => '達成步數目標';

  @override
  String daysOutOf({required int count, required int total}) {
    return '$total 天中 $count 天';
  }

  @override
  String get refSectionSteps => '步數';

  @override
  String get refUseStepGoalChosen => '步數目標由使用者自選，不預設、不自動調整';

  @override
  String get refUseStepGoalSet => '設定步數目標與步數增加有關';

  @override
  String get sleepRegularitySection => '作息規律';

  @override
  String priorDays({required int count}) {
    return '前 $count 天';
  }

  @override
  String weekendMidsleepLater({required String time}) {
    return '週末睡眠中點晚 $time';
  }

  @override
  String weekendMidsleepEarlier({required String time}) {
    return '週末睡眠中點早 $time';
  }

  @override
  String get weekendMidsleepSame => '週末與平日睡眠中點相同';

  @override
  String regularityNeeds({required int count}) {
    return '需要近 28 天有 14 晚記下入睡與起床時間（目前 $count 晚）';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

  @override
  String get appLanguage => '简体中文';

  @override
  String get meLanguageRow => '语言';

  @override
  String get meSettingsOpenFailed => '无法打开设置';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonCloseSearch => '关闭搜索';

  @override
  String get commonBack => '返回';

  @override
  String get commonClose => '关闭';

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => '取消';

  @override
  String get insightCardTitle => '值得注意';

  @override
  String get monthPickerPreviousYear => '上一年';

  @override
  String get monthPickerNextYear => '下一年';

  @override
  String get monthPickerClose => '关闭月份选择';

  @override
  String get monthPickerYear => '年份';

  @override
  String get monthPickerMonth => '月份';

  @override
  String dayStripHasRecords({required String date}) {
    return '$date，有记录';
  }

  @override
  String get moduleNutrition => '饮食';

  @override
  String get moduleNutritionDescription => '一餐、菜品、成分与营养';

  @override
  String get moduleWaterDescription => '每次喝水的量与时间';

  @override
  String get moduleWeight => '体重';

  @override
  String get moduleWeightDescription => '体重与围度';

  @override
  String get moduleTraining => '训练';

  @override
  String get moduleTrainingDescription => '动作、训练计划与训练记录';

  @override
  String get moduleActivity => '运动';

  @override
  String get moduleActivityDescription => '跑步、健走、骑车、球类、瑜伽';

  @override
  String get moduleSleep => '睡眠';

  @override
  String get moduleSleepDescription => '睡眠时间与质量';

  @override
  String get moduleWellness => '心情、精力、症状';

  @override
  String get moduleWellnessDescription => '一天的状态日志';

  @override
  String get moduleNotes => '笔记';

  @override
  String get moduleNotesDescription => '可关联任何一天或一笔记录';

  @override
  String get sourceManual => '手动输入';

  @override
  String get sourceDemo => '示例数据';

  @override
  String get sourceImport => '导入';

  @override
  String get sourceAiDraft => 'AI 草稿（已确认）';

  @override
  String get sourceCatalogue => '内置目录';

  @override
  String get sourceUnknown => '不明';

  @override
  String get sourceAppleHealth => 'Apple 健康';

  @override
  String get modulesTitle => '模块';

  @override
  String get modulesPickSeveral => '可多选';

  @override
  String get commonDone => '完成';

  @override
  String get commonContinue => '继续';

  @override
  String get journalSourceRow => '来源';

  @override
  String get sessionWorkout => '训练';

  @override
  String sessionEndTitle({required String session}) {
    return '结束这次$session？';
  }

  @override
  String get sessionEndWorkoutMessage => '已完成的组数会保存为记录；放弃则不会算作一次训练。';

  @override
  String get sessionEndActivityMessage => '结束会保存为一笔运动记录；放弃则什么都不保留。';

  @override
  String get sessionFinishAndSave => '结束并保存';

  @override
  String get sessionDiscardWorkout => '放弃这次训练';

  @override
  String get sessionDiscardActivity => '放弃这次运动';

  @override
  String sessionKeepGoing({required String session}) {
    return '继续$session';
  }

  @override
  String sessionDiscarded({required String session}) {
    return '已放弃这次$session';
  }

  @override
  String sessionResume({required String session}) {
    return '继续$session';
  }

  @override
  String sessionPause({required String session}) {
    return '暂停$session';
  }

  @override
  String sessionEnd({required String session}) {
    return '结束$session';
  }

  @override
  String sessionPausedOpen({required String session}) {
    return '$session已暂停，回到$session';
  }

  @override
  String sessionRunningOpen({required String session}) {
    return '$session进行中，回到$session';
  }

  @override
  String get sessionPausedStatus => '已暂停';

  @override
  String sessionRunningStatus({required String session}) {
    return '$session进行中';
  }

  @override
  String get dockAddEntry => '添加记录';

  @override
  String addEntryToDay({required String date}) {
    return '添加记录到 $date';
  }

  @override
  String get tabToday => '今天';

  @override
  String get tabLog => '记录';

  @override
  String get tabTrends => '趋势';

  @override
  String get tabMe => '我的';

  @override
  String get detailNothingSelected => '未选择项目';

  @override
  String get detailNoEntrySelected => '未选择记录';

  @override
  String get recordWater => '水';

  @override
  String get recordMeasurements => '围度';

  @override
  String get recordBodyComposition => '身体成分';

  @override
  String waterLogged({required int millilitres}) {
    return '已记录 $millilitres mL 水';
  }

  @override
  String get quickLogClose => '关闭添加记录';

  @override
  String get bedtimeReminderTitle => '准备就寝';

  @override
  String bedtimeReminderBody({required String bedtime, required String wake}) {
    return '$bedtime 就寝，$wake 起床';
  }

  @override
  String get restResting => '休息中';

  @override
  String get restEnded => '休息结束';

  @override
  String restNextSet({required String exercise}) {
    return '下一组 · $exercise';
  }

  @override
  String setsProgress({required int done, required int total}) {
    return '$done / $total 组';
  }

  @override
  String get trackingTypeWeightReps => '重量 + 次数';

  @override
  String get trackingTypeReps => '次数';

  @override
  String get trackingTypeDuration => '时间';

  @override
  String get trackingTypeDistance => '距离';

  @override
  String get exerciseSourceBuiltIn => '内置';

  @override
  String get exerciseSourceCustom => '自定义';

  @override
  String get exerciseSourceImported => '导入';

  @override
  String get bodyRegionChest => '胸';

  @override
  String get bodyRegionShoulders => '肩';

  @override
  String get bodyRegionBack => '背';

  @override
  String get bodyRegionArms => '手臂';

  @override
  String get bodyRegionCore => '核心';

  @override
  String get bodyRegionLegs => '腿臀';

  @override
  String get muscleChest => '胸';

  @override
  String get muscleFrontDelts => '三角肌前束';

  @override
  String get muscleSideDelts => '三角肌中束';

  @override
  String get muscleRearDelts => '三角肌后束';

  @override
  String get muscleBiceps => '二头肌';

  @override
  String get muscleTriceps => '三头肌';

  @override
  String get muscleForearms => '前臂';

  @override
  String get muscleTraps => '斜方肌';

  @override
  String get muscleLats => '背阔肌';

  @override
  String get muscleUpperBack => '上背';

  @override
  String get muscleSpinalErectors => '竖脊肌';

  @override
  String get muscleAbs => '腹直肌';

  @override
  String get muscleObliques => '腹斜肌';

  @override
  String get muscleGlutes => '臀';

  @override
  String get muscleQuads => '股四头';

  @override
  String get muscleHamstrings => '腿后';

  @override
  String get muscleAdductors => '内收肌';

  @override
  String get muscleAbductors => '外展肌';

  @override
  String get muscleCalves => '小腿';

  @override
  String get muscleBack => '背';

  @override
  String get muscleShoulders => '肩';

  @override
  String get muscleArms => '手臂';

  @override
  String get muscleCore => '核心';

  @override
  String get equipmentBarbell => '杠铃';

  @override
  String get equipmentDumbbell => '哑铃';

  @override
  String get equipmentCable => '滑轮';

  @override
  String get equipmentMachine => '器械';

  @override
  String get equipmentSmithMachine => '史密斯机';

  @override
  String get equipmentKettlebell => '壶铃';

  @override
  String get equipmentEzBar => 'EZ 杠';

  @override
  String get equipmentTrapBar => '六角杠';

  @override
  String get equipmentLandmine => '地雷管';

  @override
  String get equipmentPlate => '杠铃片';

  @override
  String get equipmentBand => '弹力带';

  @override
  String get equipmentBodyweight => '徒手';

  @override
  String get equipmentCardio => '有氧器材';

  @override
  String get equipmentOther => '其他';

  @override
  String get movementPatternSquat => '深蹲';

  @override
  String get movementPatternHinge => '髋伸';

  @override
  String get movementPatternLunge => '弓步与单脚';

  @override
  String get movementPatternHorizontalPush => '水平推';

  @override
  String get movementPatternHorizontalPull => '水平拉';

  @override
  String get movementPatternVerticalPush => '垂直推';

  @override
  String get movementPatternVerticalPull => '垂直拉';

  @override
  String get movementPatternIsolation => '单关节';

  @override
  String get movementPatternCore => '核心';

  @override
  String get movementPatternCarry => '搬运';

  @override
  String get movementPatternConditioning => '体能';

  @override
  String get movementPatternUnilateral => '单侧';

  @override
  String get lateralityBilateral => '双侧';

  @override
  String get lateralityUnilateral => '单侧';

  @override
  String get lateralityAlternating => '左右交替';

  @override
  String get setTypeWorking => '工作组';

  @override
  String get setTypeWarmup => '热身组';

  @override
  String get setTypeDrop => '递减组';

  @override
  String get setTypeFailure => '力竭组';

  @override
  String get workloadTooLight => '太轻';

  @override
  String get workloadRight => '刚好';

  @override
  String get workloadTooHard => '太吃力';

  @override
  String get setKindWorking => '工作';

  @override
  String get setKindWarmup => '热身';

  @override
  String get setKindDrop => '递减';

  @override
  String get setKindFailure => '力竭';

  @override
  String substitutionSamePattern({required String pattern}) {
    return '同为$pattern模式';
  }

  @override
  String substitutionSameMuscles({required String muscles}) {
    return '同样练$muscles';
  }

  @override
  String substitutionEquipmentAvailable({required String equipment}) {
    return '$equipment可用';
  }

  @override
  String substitutionTrackingChanges({required String tracking}) {
    return '记录方式改为$tracking';
  }

  @override
  String substitutionEquipmentChanges({required String equipment}) {
    return '换$equipment，重量需重新设置';
  }

  @override
  String get substitutionOneSide => '单侧动作，次数请重新设置';

  @override
  String get routineUntitled => '新的训练计划';

  @override
  String get workoutFreeName => '自由训练';

  @override
  String setOrdinal({required int number}) {
    return '第 $number 组';
  }

  @override
  String muscleSetCount({required String muscle, required int sets}) {
    return '$muscle $sets 组';
  }

  @override
  String get valueTypeDeclared => '标示值';

  @override
  String get valueTypeMax => '最高值';

  @override
  String get valueTypeEstimate => '估计值';

  @override
  String get mealTypeBreakfast => '早餐';

  @override
  String get mealTypeLunch => '午餐';

  @override
  String get mealTypeDinner => '晚餐';

  @override
  String get mealTypeSnack => '点心';

  @override
  String get consumptionKindFood => '食物';

  @override
  String get consumptionKindBeverage => '饮品';

  @override
  String get consumptionKindUnknown => '未指定';

  @override
  String get servingUnitGram => 'g';

  @override
  String get servingUnitKilogram => 'kg';

  @override
  String get servingUnitOunce => 'oz';

  @override
  String get servingUnitPound => 'lb';

  @override
  String get servingUnitTael => '台两';

  @override
  String get servingUnitCatty => '台斤';

  @override
  String get servingUnitMillilitre => 'ml';

  @override
  String get servingUnitLitre => 'L';

  @override
  String get servingUnitServing => '份';

  @override
  String get allergenCrustacean => '甲壳类';

  @override
  String get allergenMango => '芒果';

  @override
  String get allergenPeanut => '花生';

  @override
  String get allergenMilk => '牛奶';

  @override
  String get allergenEgg => '蛋';

  @override
  String get allergenTreeNut => '坚果';

  @override
  String get allergenSesame => '芝麻';

  @override
  String get allergenGluten => '麸质';

  @override
  String get allergenSoy => '大豆';

  @override
  String get allergenFish => '鱼类';

  @override
  String get allergenSulphite => '亚硫酸盐';

  @override
  String get nutrientSaturatedFat => '饱和脂肪';

  @override
  String get nutrientTransFat => '反式脂肪';

  @override
  String get nutrientSugar => '糖';

  @override
  String get nutrientSodium => '钠';

  @override
  String get nutrientNetCarb => '糖质';

  @override
  String get nutrientSaltEquivalent => '食盐相当量';

  @override
  String get nutrientPolyols => '糖醇';

  @override
  String get nutrientAlcohol => '酒精';

  @override
  String get nutrientCholesterol => '胆固醇';

  @override
  String get nutrientCaffeine => '咖啡因';

  @override
  String get nutrientEssentialAminoAcids => '必需氨基酸';

  @override
  String get nutrientBcaa => '支链氨基酸';

  @override
  String get nutrientLeucine => '亮氨酸';

  @override
  String get nutrientIsoleucine => '异亮氨酸';

  @override
  String get nutrientValine => '缬氨酸';

  @override
  String get nutrientGlutamine => '谷氨酰胺';

  @override
  String get nutrientCalcium => '钙';

  @override
  String get nutrientPhosphorus => '磷';

  @override
  String get nutrientMagnesium => '镁';

  @override
  String get nutrientIron => '铁';

  @override
  String get nutrientZinc => '锌';

  @override
  String get nutrientPotassium => '钾';

  @override
  String get nutrientIodine => '碘';

  @override
  String get nutrientSelenium => '硒';

  @override
  String get nutrientVitaminA => '维生素 A';

  @override
  String get nutrientVitaminD => '维生素 D';

  @override
  String get nutrientVitaminE => '维生素 E';

  @override
  String get nutrientVitaminK => '维生素 K';

  @override
  String get nutrientVitaminC => '维生素 C';

  @override
  String get nutrientVitaminB1 => '维生素 B1';

  @override
  String get nutrientVitaminB2 => '维生素 B2';

  @override
  String get nutrientNiacin => '烟酸';

  @override
  String get nutrientVitaminB6 => '维生素 B6';

  @override
  String get nutrientVitaminB12 => '维生素 B12';

  @override
  String get nutrientFolate => '叶酸';

  @override
  String get nutrientPantothenicAcid => '泛酸';

  @override
  String get nutrientBiotin => '生物素';

  @override
  String get nutrientMonounsaturatedFat => '单不饱和脂肪';

  @override
  String get nutrientPolyunsaturatedFat => '多不饱和脂肪';

  @override
  String get nutrientCopper => '铜';

  @override
  String get nutrientManganese => '锰';

  @override
  String get nutrientChromium => '铬';

  @override
  String get nutrientMolybdenum => '钼';

  @override
  String get nutrientChloride => '氯';

  @override
  String get conventionTaiwan => '台湾';

  @override
  String get conventionJapan => '日本';

  @override
  String get conventionUnitedStates => '美国';

  @override
  String get conventionEuropeanUnion => '欧盟';

  @override
  String get conventionAustraliaNewZealand => '澳大利亚、新西兰';

  @override
  String get conventionKorea => '韩国';

  @override
  String get conventionChina => '中国';

  @override
  String get conventionCanada => '加拿大';

  @override
  String get macroEnergy => '热量';

  @override
  String get macroProtein => '蛋白质';

  @override
  String get macroCarb => '碳水化合物';

  @override
  String get macroFat => '脂肪';

  @override
  String get macroFibre => '膳食纤维';

  @override
  String foodCupCapacity({required String amount}) {
    return '杯容量 $amount';
  }

  @override
  String get foodOfficialData => '官方数据';

  @override
  String foodAdd({required String food}) {
    return '加入「$food」';
  }

  @override
  String foodLastPortion({required String portion, required String kcal}) {
    return '上次 $portion · $kcal';
  }

  @override
  String foodCupSizes({required int count}) {
    return '$count 种杯型';
  }

  @override
  String foodOneServing({required String serving, required String kcal}) {
    return '一份 $serving · $kcal';
  }

  @override
  String draftEnergyMismatchItem({required String item}) {
    return '$item的热量和蛋白质、碳水化合物、脂肪算起来差很多，请核对。';
  }

  @override
  String get draftEnergyMismatch => '热量和蛋白质、碳水化合物、脂肪算起来差很多，请核对这几格。';

  @override
  String get draftColumnMismatch => '每份的热量和每 100 的热量按份量换算对不上，可能填到了另一栏，请核对。';

  @override
  String get draftCarbWithoutFibre => '这张标示的碳水化合物不含膳食纤维，又没有印膳食纤维，碳水化合物留空。';

  @override
  String get activityGroupWalkRun => '走路与跑步';

  @override
  String get activityGroupCycling => '自行车';

  @override
  String get activityGroupWater => '水上运动';

  @override
  String get activityGroupBall => '球类';

  @override
  String get activityGroupIndoor => '室内器材';

  @override
  String get activityGroupMindBody => '身心与伸展';

  @override
  String get activityGroupOther => '其他';

  @override
  String get activityMetricGroupMovement => '日常活动';

  @override
  String get activityMetricGroupHeart => '心脏与心肺';

  @override
  String get activityMetricGroupVitals => '生命体征';

  @override
  String get activityMetricMindfulTime => '正念时间';

  @override
  String get activityMetricGroupMindfulness => '正念';

  @override
  String get activityMetricBodyTemperature => '体温';

  @override
  String get activityMetricBloodPressureSystolic => '收缩压';

  @override
  String get activityMetricBloodPressureDiastolic => '舒张压';

  @override
  String get vitalBloodPressure => '血压';

  @override
  String get activityMetricRespiratoryRate => '呼吸频率';

  @override
  String get activityMetricOxygenSaturation => '血氧';

  @override
  String get activityMetricUnitRespiratoryRate => '次/分';

  @override
  String get activityMetricGroupMobility => '行动能力';

  @override
  String get activityMetricGroupRunning => '跑步';

  @override
  String get activityMetricGroupCycling => '骑车';

  @override
  String get activityMetricGroupSwimmingWheelchair => '游泳与轮椅';

  @override
  String get activityMetricSteps => '步数';

  @override
  String get activityMetricDistance => '距离';

  @override
  String get activityMetricActiveEnergy => '活动能量';

  @override
  String get activityMetricBasalEnergy => '静息能量';

  @override
  String get activityMetricExerciseTime => '运动时间';

  @override
  String get activityMetricStandTime => '站立时间';

  @override
  String get activityMetricMoveTime => '活动时间';

  @override
  String get activityMetricFloors => '爬楼';

  @override
  String get activityMetricElevationGained => '爬升高度';

  @override
  String get activityMetricTimeInDaylight => '日光时间';

  @override
  String get activityMetricHeartRate => '平均心率';

  @override
  String get activityMetricRestingHeartRate => '静息心率';

  @override
  String get activityMetricWalkingHeartRate => '步行平均心率';

  @override
  String get activityMetricHrvSdnn => '心率变异性（SDNN）';

  @override
  String get activityMetricHrvRmssd => '心率变异性（RMSSD）';

  @override
  String get activityMetricHeartRateRecovery => '一分钟心率恢复';

  @override
  String get activityMetricVo2Max => '最大摄氧量';

  @override
  String get activityMetricPhysicalEffort => '身体耗力';

  @override
  String get activityMetricWalkingSpeed => '步行速度';

  @override
  String get activityMetricWalkingStepLength => '步长';

  @override
  String get activityMetricWalkingAsymmetry => '步行不对称';

  @override
  String get activityMetricDoubleSupport => '双脚支撑时间';

  @override
  String get activityMetricWalkingSteadiness => '步行稳定性';

  @override
  String get activityMetricStairAscentSpeed => '上楼速度';

  @override
  String get activityMetricStairDescentSpeed => '下楼速度';

  @override
  String get activityMetricSixMinuteWalk => '六分钟步行距离';

  @override
  String get activityMetricRunningSpeed => '跑步速度';

  @override
  String get activityMetricRunningPower => '跑步功率';

  @override
  String get activityMetricRunningStrideLength => '跑步步幅';

  @override
  String get activityMetricGroundContactTime => '触地时间';

  @override
  String get activityMetricVerticalOscillation => '垂直振幅';

  @override
  String get activityMetricCyclingDistance => '骑车距离';

  @override
  String get activityMetricCyclingSpeed => '骑车速度';

  @override
  String get activityMetricCyclingPower => '骑车功率';

  @override
  String get activityMetricCyclingCadence => '踏频';

  @override
  String get activityMetricFunctionalThresholdPower => '功能阈值功率';

  @override
  String get activityMetricSwimmingDistance => '游泳距离';

  @override
  String get activityMetricSwimmingStrokes => '划水次数';

  @override
  String get activityMetricWheelchairPushes => '轮椅推动';

  @override
  String get activityMetricWheelchairDistance => '轮椅距离';

  @override
  String get activityMetricUnitSteps => '步';

  @override
  String get activityMetricUnitDistance => 'km';

  @override
  String get activityMetricUnitActiveEnergy => 'kcal';

  @override
  String get activityMetricUnitBasalEnergy => 'kcal';

  @override
  String get activityMetricUnitExerciseTime => '分';

  @override
  String get activityMetricUnitStandTime => '分';

  @override
  String get activityMetricUnitFloors => '层';

  @override
  String get activityMetricUnitElevationGained => 'm';

  @override
  String get activityMetricUnitTimeInDaylight => '分';

  @override
  String get activityMetricUnitHeartRate => '次/分';

  @override
  String get activityMetricUnitRestingHeartRate => '次/分';

  @override
  String get activityMetricUnitWalkingHeartRate => '次/分';

  @override
  String get activityMetricUnitHrvSdnn => 'ms';

  @override
  String get activityMetricUnitHrvRmssd => 'ms';

  @override
  String get activityMetricUnitHeartRateRecovery => '次/分';

  @override
  String get activityMetricUnitVo2Max => 'mL/kg/min';

  @override
  String get activityMetricUnitPhysicalEffort => 'MET';

  @override
  String get activityMetricUnitWalkingSpeed => 'km/h';

  @override
  String get activityMetricUnitWalkingStepLength => 'cm';

  @override
  String get activityMetricUnitWalkingAsymmetry => '%';

  @override
  String get activityMetricUnitDoubleSupport => '%';

  @override
  String get activityMetricUnitWalkingSteadiness => '%';

  @override
  String get activityMetricUnitStairAscentSpeed => 'm/s';

  @override
  String get activityMetricUnitStairDescentSpeed => 'm/s';

  @override
  String get activityMetricUnitSixMinuteWalk => 'm';

  @override
  String get activityMetricUnitRunningSpeed => 'km/h';

  @override
  String get activityMetricUnitRunningPower => 'W';

  @override
  String get activityMetricUnitRunningStrideLength => 'm';

  @override
  String get activityMetricUnitGroundContactTime => 'ms';

  @override
  String get activityMetricUnitVerticalOscillation => 'cm';

  @override
  String get activityMetricUnitCyclingDistance => 'km';

  @override
  String get activityMetricUnitCyclingSpeed => 'km/h';

  @override
  String get activityMetricUnitCyclingPower => 'W';

  @override
  String get activityMetricUnitCyclingCadence => 'rpm';

  @override
  String get activityMetricUnitFunctionalThresholdPower => 'W';

  @override
  String get activityMetricUnitSwimmingDistance => 'm';

  @override
  String get activityMetricUnitSwimmingStrokes => '次';

  @override
  String get activityMetricUnitWheelchairPushes => '次';

  @override
  String get activityMetricUnitWheelchairDistance => 'km';

  @override
  String get activityTypeRunning => '跑步';

  @override
  String get activityTypeWalking => '健走';

  @override
  String get activityTypeHiking => '徒步';

  @override
  String get activityTypeCycling => '骑自行车';

  @override
  String get activityTypeSwimming => '游泳';

  @override
  String get activityTypeRowing => '划船机';

  @override
  String get activityTypeElliptical => '椭圆机';

  @override
  String get activityTypeStairs => '爬楼梯';

  @override
  String get activityTypeBasketball => '篮球';

  @override
  String get activityTypeBadminton => '羽毛球';

  @override
  String get activityTypeYoga => '瑜伽';

  @override
  String get activityTypeOther => '其他运动';

  @override
  String hoursMinutes({required int hours, required int minutes}) {
    return '$hours 小时 $minutes 分';
  }

  @override
  String durationMinutes({required int minutes}) {
    return '$minutes 分';
  }

  @override
  String get activitySeriesHeartRate => '心率';

  @override
  String get activitySeriesSpeed => '速度';

  @override
  String get activitySeriesPower => '功率';

  @override
  String get activitySeriesCadence => '踏频';

  @override
  String get activitySeriesStrideLength => '步幅';

  @override
  String get activitySeriesGroundContactTime => '触地时间';

  @override
  String get activitySeriesVerticalOscillation => '垂直振幅';

  @override
  String get activitySeriesAltitude => '高度';

  @override
  String get activitySeriesUnitHeartRate => '次/分';

  @override
  String get activitySeriesUnitSpeed => 'km/h';

  @override
  String get activitySeriesUnitPower => 'W';

  @override
  String get activitySeriesUnitCadence => 'rpm';

  @override
  String get activitySeriesUnitStrideLength => 'm';

  @override
  String get activitySeriesUnitGroundContactTime => 'ms';

  @override
  String get activitySeriesUnitVerticalOscillation => 'cm';

  @override
  String get activitySeriesUnitAltitude => 'm';

  @override
  String get unitBpm => '次/分';

  @override
  String activityDeleted({required String activity}) {
    return '已删除$activity';
  }

  @override
  String get recordDeletedNotice => '这笔记录已被删除。';

  @override
  String get activityRouteMap => '路线地图';

  @override
  String get healthDetailUnreadable => '无法读取健康数据的详细记录。';

  @override
  String get activityDetailsSection => '详细资料';

  @override
  String get activitySplitsSection => '分段 · 每 1 km';

  @override
  String get activityRecoverySection => '运动后心率';

  @override
  String get activityPace => '配速';

  @override
  String get notesSection => '备注';

  @override
  String get manageSection => '管理';

  @override
  String get activityEdit => '编辑内容';

  @override
  String get activityEditDetail => '类型、时间、时长';

  @override
  String get recordDelete => '删除这笔记录';

  @override
  String get deleteMeasurement => '删除这次测量';

  @override
  String get activityActiveTime => '运动时间';

  @override
  String get activityDistance => '距离';

  @override
  String get activityTotalEnergy => '总能量';

  @override
  String get activityClimb => '爬升';

  @override
  String get activityAveragePace => '平均配速';

  @override
  String get activityAverageSpeed => '平均速度';

  @override
  String get activityMaxHeartRate => '最高心率';

  @override
  String get activityAveragePower => '平均功率';

  @override
  String get activityAverageCadence => '平均踏频';

  @override
  String get activityEffort => '费力程度';

  @override
  String get activityEffortEstimated => '费力程度（估计）';

  @override
  String activityIndoor({required String activity}) {
    return '$activity（室内）';
  }

  @override
  String activityOutdoor({required String activity}) {
    return '$activity（户外）';
  }

  @override
  String get weatherLabel => '天气';

  @override
  String get humidityLabel => '湿度';

  @override
  String get splitTime => '时间';

  @override
  String statAverage({required String value}) {
    return '平均 $value';
  }

  @override
  String heartZone({required int number}) {
    return '区间 $number';
  }

  @override
  String get heartZonesByReserve => '依储备心率估计';

  @override
  String get heartZonesByAge => '依年龄估计最大心率';

  @override
  String get heartZonesOwn => '本 App 的区间';

  @override
  String get recoveryAtEnd => '结束时';

  @override
  String recoveryAfter({required int minutes}) {
    return '$minutes 分后';
  }

  @override
  String recoveryWindow({required String time}) {
    return '$time 起 3 分钟';
  }

  @override
  String timelineWeight({required String weight}) {
    return '体重 $weight';
  }

  @override
  String sleepQualityScore({required int score}) {
    return '质量 $score / 5';
  }

  @override
  String noteLine({required String note}) {
    return '备注：$note';
  }

  @override
  String setsCount({required int count}) {
    return '$count 组';
  }

  @override
  String personalRecordLine({
    required String exercise,
    required String weight,
    required int reps,
  }) {
    return '$exercise $weight kg × $reps 为个人纪录';
  }

  @override
  String effortOutOfTen({required int effort}) {
    return '强度 $effort / 10';
  }

  @override
  String activitiesCount({required int count}) {
    return '$count 场';
  }

  @override
  String itemsCount({required int count}) {
    return '$count 项';
  }

  @override
  String mealsCount({required int count}) {
    return '$count 餐';
  }

  @override
  String get foodLogIncomplete => '有未记录的餐';

  @override
  String todayWithDate({required String date}) {
    return '今天 · $date';
  }

  @override
  String get routineNeverDone => '未完成过';

  @override
  String routineLastDone({required String date}) {
    return '上次 $date 完成';
  }

  @override
  String optionalField({required String field}) {
    return '$field（选填）';
  }

  @override
  String get workoutBlocksActivity => '训练进行中，先结束训练才能开始运动';

  @override
  String activityDurationRange({required int min, required int max}) {
    return '时长请介于 $min – $max 分钟。';
  }

  @override
  String activityDistanceRange({required int max}) {
    return '距离请输入 0 – $max km 之间。';
  }

  @override
  String activityClimbRange({required int max}) {
    return '爬升请输入 0 – $max m 之间。';
  }

  @override
  String activityLogged({required String activity, required int minutes}) {
    return '已记录$activity $minutes 分';
  }

  @override
  String activityUpdated({required String activity}) {
    return '已更新$activity';
  }

  @override
  String get activityRecordTitle => '记录运动';

  @override
  String get activityEditTitle => '编辑运动';

  @override
  String get activityTypeRow => '运动类型';

  @override
  String get activityStartTimer => '现在开始计时';

  @override
  String get activityStartTimerDetail => '边做边计时，距离与强度结束后再补';

  @override
  String get activityStartTime => '开始时间';

  @override
  String get activityDurationSection => '时长';

  @override
  String get minutesUnit => '分钟';

  @override
  String activityEndsAt({required String time}) {
    return '结束 $time';
  }

  @override
  String activityPaceValue({required String pace}) {
    return '配速 $pace /km';
  }

  @override
  String get effortSection => '强度';

  @override
  String get effortScaleHint => '1 很轻松、10 拼尽全力。';

  @override
  String get activityNoteHint => '例如：河滨，风很大';

  @override
  String get activityPickTitle => '选择运动';

  @override
  String get recentlyUsed => '最近使用';

  @override
  String get commonlyUsed => '常用';

  @override
  String get activityAllTypes => '所有运动';

  @override
  String get activityEnded => '这次运动已经结束。';

  @override
  String get sessionInProgress => '进行中';

  @override
  String get commonEnd => '结束';

  @override
  String get commonResume => '继续';

  @override
  String get commonPause => '暂停';

  @override
  String get chartRangeDay => '日';

  @override
  String get chartRangeWeek => '周';

  @override
  String get chartRangeMonth => '月';

  @override
  String get previousDay => '前一天';

  @override
  String get nextDay => '后一天';

  @override
  String get entriesRow => '记录';

  @override
  String get thisDay => '这一天';

  @override
  String get dailyAverage => '每日平均';

  @override
  String get usualRange => '平常范围';

  @override
  String get daysRecorded => '记录天数';

  @override
  String daysCount({required int count}) {
    return '$count 天';
  }

  @override
  String weekOf({required String date}) {
    return '$date起一周';
  }

  @override
  String readingsCount({required int count}) {
    return '$count 笔';
  }

  @override
  String get perDay => '每日';

  @override
  String get dailyActivityTitle => '活动';

  @override
  String get noActivityData => '没有活动数据';

  @override
  String get dataSourcesLink => '数据来源';

  @override
  String get noActivityThisDay => '这一天没有活动数据';

  @override
  String get heartZonesTitle => '心率区间';

  @override
  String get needsBirthYear => '需要出生年';

  @override
  String nightsWithinUsual({required int count, required int total}) {
    return '$total 晚中 $count 晚在平常范围内';
  }

  @override
  String daysWithinUsual({required int count, required int total}) {
    return '$total 天中 $count 天在平常范围内';
  }

  @override
  String daysAllWithinUsual({required int count}) {
    return '$count 天都在平常范围内';
  }

  @override
  String daysRecordedWithinUsual({required int recorded, required int count}) {
    return '$recorded 天有记录，$count 天在平常范围内';
  }

  @override
  String usualRangeNeedsDays({required int count}) {
    return '需要近 28 天有 14 天的记录（目前 $count 天）';
  }

  @override
  String nightsAllWithinUsual({required int count}) {
    return '$count 晚都在平常范围内';
  }

  @override
  String nightsRecordedWithinUsual({
    required int recorded,
    required int count,
  }) {
    return '$recorded 晚有记录，$count 晚在平常范围内';
  }

  @override
  String usualRangeNeedsNights({required int count}) {
    return '需要近 28 天有 14 晚的记录（目前 $count 晚）';
  }

  @override
  String get outsideUsual => '范围外';

  @override
  String get targetBedtime => '目标入睡';

  @override
  String get targetWake => '目标起床';

  @override
  String get clearTargetSchedule => '清除目标作息';

  @override
  String get targetSchedule => '目标作息';

  @override
  String get refSectionUsualRange => '平常范围';

  @override
  String get refSectionSleepStages => '睡眠阶段';

  @override
  String get refUseUsualRangeMinMax => '平常范围是前 28 天的最低到最高，有值的日子至少 14 天';

  @override
  String get refUseUsualRangeWindow => '个人基线取前 28 天的记录，不含当天';

  @override
  String get refUseUsualRangeMarks => '范围外只用空心圈标出，不分好坏、不用警示色';

  @override
  String get refUseUsualRangeNoAnchor => '范围外的点没有临床界线可对照，所以标记要弱并附上数字';

  @override
  String get refUseStagesEstimate => '睡眠阶段是设备估计，只和自己的夜晚比，不用同年龄的范围';

  @override
  String get refUseStagesNoTarget => '睡眠结构没有共识，不设各阶段的目标';

  @override
  String get refUseStagesNoSummary => '睡眠阶段与效率不写几晚在范围内：负面的睡眠反馈会影响白天的感受';

  @override
  String get refUseRegularityOutcomes => '规律的作息与较低的死亡风险相关（观察性）';

  @override
  String get refUseTargetScheduleAssociation => '目标作息：作息规律与健康结果的关联，目标时刻由用户自订';

  @override
  String get refUseTargetScheduleTrial => '目标作息：固定作息四周，白天嗜睡下降（小型实验）';

  @override
  String get refUseMaxHeartRateError => '依年龄估计的最大心率，个人误差约 11 次/分，所以全天心率图不画区间';

  @override
  String get refUseHeartRateReserve => '储备心率对应储备摄氧量，区间依此计算';

  @override
  String usualRangeValue({required String range}) {
    return '平常 $range';
  }

  @override
  String get vitalsTitle => '心脏与生命体征';

  @override
  String get noVitalsData => '没有心脏与生命体征数据';

  @override
  String get perHour => '每小时';

  @override
  String hourSpan({required int start, required int end}) {
    return '$start–$end 时';
  }

  @override
  String hourOfDay({required int hour}) {
    return '$hour 时';
  }

  @override
  String get measurementSiteWaist => '腰围';

  @override
  String get measurementSiteHips => '臀围';

  @override
  String get measurementSiteChest => '胸围';

  @override
  String get measurementSiteArm => '上臂';

  @override
  String get measurementSiteThigh => '大腿';

  @override
  String get measurementSiteCalf => '小腿';

  @override
  String get measurementSiteNeck => '颈围';

  @override
  String get bodyMetricHeight => '身高';

  @override
  String get bodyMetricBodyFat => '体脂率';

  @override
  String get bodyMetricSkeletalMuscle => '骨骼肌';

  @override
  String get bodyMetricMuscleMass => '肌肉量';

  @override
  String get bodyMetricLeanMass => '去脂体重';

  @override
  String get bodyMetricVisceralFat => '内脏脂肪';

  @override
  String get bodyMetricBodyWater => '体水分';

  @override
  String get bodyMetricBoneMass => '骨量';

  @override
  String get bodyMetricBasalMetabolicRate => '基础代谢';

  @override
  String get sexFemale => '女性';

  @override
  String get sexMale => '男性';

  @override
  String get sleepKindNight => '睡眠';

  @override
  String get sleepKindNap => '小睡';

  @override
  String get sleepMeasureAsleep => '睡着时间';

  @override
  String get sleepMeasureInBed => '在床时间';

  @override
  String get sleepStageInBed => '在床';

  @override
  String get sleepStageAwake => '清醒';

  @override
  String get sleepStageAsleep => '睡着';

  @override
  String get sleepStageCore => '浅层／核心';

  @override
  String get sleepStageDeep => '深层';

  @override
  String get sleepStageRem => 'REM';

  @override
  String get overnightMeasureHeartRate => '心率';

  @override
  String get overnightMeasureRespiratoryRate => '呼吸速率';

  @override
  String get overnightMeasureOxygenSaturation => '血氧';

  @override
  String get overnightMeasureWristTemperature => '手腕温度';

  @override
  String get overnightMeasureSkinTemperatureChange => '皮肤温度变化';

  @override
  String get overnightMeasureHrvSdnn => '心率变异性（SDNN）';

  @override
  String get overnightMeasureHrvRmssd => '心率变异性（RMSSD）';

  @override
  String get overnightMeasureBreathingDisturbances => '呼吸干扰';

  @override
  String get activityLevelSedentary => '久坐';

  @override
  String get activityLevelLight => '轻度';

  @override
  String get activityLevelModerate => '中度';

  @override
  String get activityLevelActive => '高度';

  @override
  String get activityLevelVeryActive => '非常高';

  @override
  String get weightGoalLose => '减脂';

  @override
  String get weightGoalRecomp => '增肌减脂';

  @override
  String get weightGoalMaintain => '维持';

  @override
  String get weightGoalGain => '增肌';

  @override
  String get targetInputWeight => '体重';

  @override
  String get targetInputHeight => '身高';

  @override
  String get targetInputBirthYear => '出生年';

  @override
  String get targetInputSex => '性别';

  @override
  String get healthDataSleep => '睡眠';

  @override
  String get healthDataWeight => '体重';

  @override
  String get healthDataWaist => '腰围';

  @override
  String get healthDataBody => '身体成分';

  @override
  String get healthDataWorkouts => '运动';

  @override
  String get healthDataWater => '喝水';

  @override
  String get healthDataOvernight => '夜间数据';

  @override
  String get healthDataActivity => '活动与心肺';

  @override
  String get recordCategoryTraining => '训练';

  @override
  String get recordCategoryActivity => '运动';

  @override
  String get recordCategoryNutrition => '饮食';

  @override
  String get recordCategoryBody => '身体';

  @override
  String get recordCategoryWellness => '睡眠与状态';

  @override
  String get aiProviderAppleOnDevice => 'Apple Intelligence';

  @override
  String get aiProviderOllamaCloud => 'Ollama Cloud';

  @override
  String get aiProviderGoogleAiStudio => 'Google AI Studio';

  @override
  String get aiProviderAnthropic => 'Anthropic';

  @override
  String get aiProviderAzureAiFoundry => 'Azure AI Foundry';

  @override
  String get aiProviderMicrosoftCopilot => 'Microsoft 365 Copilot';

  @override
  String get aiProviderOpenAiCompatible => 'OpenAI 兼容端点';

  @override
  String get wellnessKindEnergy => '精力';

  @override
  String get wellnessKindMood => '心情';

  @override
  String get wellnessKindSymptom => '症状';

  @override
  String get wellnessKindSleep => '睡眠质量';

  @override
  String get bodyMetricUnitHeight => 'cm';

  @override
  String get bodyMetricUnitBodyFat => '%';

  @override
  String get bodyMetricUnitSkeletalMuscle => 'kg';

  @override
  String get bodyMetricUnitMuscleMass => 'kg';

  @override
  String get bodyMetricUnitLeanMass => 'kg';

  @override
  String get bodyMetricUnitVisceralFat => '级';

  @override
  String get bodyMetricUnitBodyWater => '%';

  @override
  String get bodyMetricUnitBoneMass => 'kg';

  @override
  String get bodyMetricUnitBasalMetabolicRate => 'kcal';

  @override
  String get overnightMeasureUnitHeartRate => '次/分';

  @override
  String get overnightMeasureUnitRespiratoryRate => '次/分';

  @override
  String get overnightMeasureUnitOxygenSaturation => '%';

  @override
  String get overnightMeasureUnitWristTemperature => '°C';

  @override
  String get overnightMeasureUnitSkinTemperatureChange => '°C';

  @override
  String get overnightMeasureUnitHrvSdnn => 'ms';

  @override
  String get overnightMeasureUnitHrvRmssd => 'ms';

  @override
  String get overnightMeasureUnitBreathingDisturbances => '';

  @override
  String get activityLevelDetailSedentary => '几乎不运动';

  @override
  String get activityLevelDetailLight => '每周运动 1–3 天';

  @override
  String get activityLevelDetailModerate => '每周运动 3–5 天';

  @override
  String get activityLevelDetailActive => '每周运动 6–7 天';

  @override
  String get activityLevelDetailVeryActive => '体力劳动或一天两练';

  @override
  String get aiOff => 'AI 未启用';

  @override
  String get aiDraftGenerate => '生成草稿';

  @override
  String get aiDrafting => '生成中…';

  @override
  String get aiRewrite => '重新输入';

  @override
  String deletedItem({required String item}) {
    return '已删除$item';
  }

  @override
  String get recordTitle => '记录';

  @override
  String get commonEdit => '编辑';

  @override
  String get bodyScaleEstimate => '体脂秤估计';

  @override
  String get notRated => '没有评分';

  @override
  String weightSinceLast({required String change, required String date}) {
    return '较上次 $change（$date）';
  }

  @override
  String get logFilterAll => '全部';

  @override
  String pickMonthCurrent({required String month}) {
    return '选择月份，当前 $month';
  }

  @override
  String get logSearch => '搜索记录';

  @override
  String get backToToday => '回到今天';

  @override
  String get showAsCalendar => '以月历显示';

  @override
  String get showAsTimeline => '以时间轴显示';

  @override
  String get previousMonth => '上个月';

  @override
  String get nextMonth => '下个月';

  @override
  String noEntriesInMonth({required String month}) {
    return '$month没有记录';
  }

  @override
  String noEntriesMatching({required String query}) {
    return '找不到符合「$query」的记录。';
  }

  @override
  String get noEntriesThisDay => '这天没有记录。';

  @override
  String get noEntriesSentence => '没有记录。';

  @override
  String get noImports => '没有导入记录。';

  @override
  String get importUndone => '已撤销';

  @override
  String productsCount({required int count}) {
    return '$count 款';
  }

  @override
  String catalogueUpdated({required String catalogue, required String date}) {
    return '$catalogue更新于 $date';
  }

  @override
  String healthReadFailed({required String error}) {
    return '读取失败：$error';
  }

  @override
  String get healthDisconnectKeeps => '断开连接后记录会保留。';

  @override
  String get healthReadNow => '立即读取';

  @override
  String get healthDisconnect => '断开连接';

  @override
  String healthUnavailable({required String source}) {
    return '这台设备没有 $source，或版本太旧。';
  }

  @override
  String get checking => '检查中…';

  @override
  String get healthConnected => '已连接';

  @override
  String healthConnect({required String source}) {
    return '连接 $source';
  }

  @override
  String get healthReading => '读取中…';

  @override
  String get healthAllowReading => '允许读取';

  @override
  String get healthAutoReadFailed => '上次自动读取失败';

  @override
  String get healthReadFailedState => '读取失败';

  @override
  String get healthReadDone => '读取完成';

  @override
  String healthLastRead({required String when}) {
    return '上次读取 $when';
  }

  @override
  String healthReads({required String kinds}) {
    return '读取：$kinds';
  }

  @override
  String get privacyLink => '隐私说明';

  @override
  String get checkingPermissions => '检查权限中…';

  @override
  String get healthPermissionsPath => '权限在“设置 > 健康 > 数据访问与设备 > MISHIRUBE”中修改。';

  @override
  String get permissionAllowed => '已允许';

  @override
  String get permissionDenied => '未允许';

  @override
  String get healthAllowOthers => '允许其他类别';

  @override
  String get healthNotConnected => '没有连上。';

  @override
  String healthNothingReadDenied({required String kinds}) {
    return '没有读到数据。未允许：$kinds。';
  }

  @override
  String get healthNothingRead => '没有读到数据。请到系统的健康设置确认允许的类别。';

  @override
  String nightsCount({required int count}) {
    return '$count 晚';
  }

  @override
  String timesCount({required int count}) {
    return '$count 次';
  }

  @override
  String healthUpdatedNights({required int count}) {
    return '更新 $count 晚睡眠';
  }

  @override
  String healthKeptManual({required int count}) {
    return '$count 晚保留手动记录';
  }

  @override
  String healthNotAllowedList({required String kinds}) {
    return '未允许：$kinds';
  }

  @override
  String get noSleepRecords => '没有睡眠记录';

  @override
  String get logByHand => '手动记录';

  @override
  String get sleepDebtSection => '睡眠债';

  @override
  String get napsSection => '小睡';

  @override
  String get goalSection => '目标';

  @override
  String get sleepStagesSection => '睡眠阶段';

  @override
  String get notProvided => '未提供';

  @override
  String get fallAsleepTime => '入睡所需';

  @override
  String get sleepEfficiency => '睡眠效率';

  @override
  String get awakeAtNight => '夜间清醒';

  @override
  String wokeTimes({required int count}) {
    return '醒来 $count 次';
  }

  @override
  String get continuitySection => '连续性';

  @override
  String get estimatedFromInBed => '依设备的在床时间估算';

  @override
  String get tonightSection => '今晚';

  @override
  String get suggestedBedtime => '建议就寝';

  @override
  String wakeAt({required String time}) {
    return '$time 起床';
  }

  @override
  String get fromUsualWake => '依平常的起床时间';

  @override
  String get afterTraining => '训练后';

  @override
  String get caffeineAfter2pm => '14:00 后有咖啡因';

  @override
  String get mealAfter9pm => '21:00 后进食';

  @override
  String nightsVersus({required int withCount, required int withoutCount}) {
    return '$withCount 晚对 $withoutCount 晚';
  }

  @override
  String get factorsSection => '影响因素';

  @override
  String get factorsBasis => '近 90 天的平均睡着时间差';

  @override
  String get correlationNotCause => '相关，不代表因果';

  @override
  String sleptLess({required String time}) {
    return '少睡 $time';
  }

  @override
  String sleptMore({required String time}) {
    return '多睡 $time';
  }

  @override
  String get recordMethod => '记录方式';

  @override
  String get withStages => '含睡眠阶段';

  @override
  String get elevated => '升高';

  @override
  String get notElevated => '未升高';

  @override
  String get sameAsUsual => '与近 28 晚平均相同';

  @override
  String versusUsual({required String change}) {
    return '较近 28 晚平均 $change';
  }

  @override
  String goalMet({required String goal}) {
    return '目标 $goal · 达成';
  }

  @override
  String goalShort({required String goal, required String gap}) {
    return '目标 $goal · 少 $gap';
  }

  @override
  String get recordedSleep => '记录的睡眠';

  @override
  String get deviceEstimate => '设备估计';

  @override
  String withNapsTotal({required String time}) {
    return '含小睡共 $time';
  }

  @override
  String get noEntriesShort => '没有记录';

  @override
  String get averageTimeAsleep => '平均睡着时间';

  @override
  String get averageBedtime => '平均入睡';

  @override
  String get averageWake => '平均起床';

  @override
  String plusMinusMinutes({required int minutes}) {
    return '±$minutes 分';
  }

  @override
  String get nightsRecorded => '记录晚数';

  @override
  String get bedAndWake => '入睡与起床';

  @override
  String averageStage({required String stage}) {
    return '平均$stage';
  }

  @override
  String trendOverNights({required String measure, required int count}) {
    return '$measure走势，$count 晚';
  }

  @override
  String everyMinutes({required int minutes}) {
    return '每 $minutes 分';
  }

  @override
  String stageChartLabel({required String start, required String end}) {
    return '睡眠阶段图，$start 到 $end';
  }

  @override
  String get wholeNight => '整晚';

  @override
  String scheduleChartLabel({required int count}) {
    return '入睡与起床时间，$count 晚';
  }

  @override
  String get sleepGoal => '睡眠目标';

  @override
  String get notSet => '未设置';

  @override
  String get bedtimeReminder => '就寝提醒';

  @override
  String remindsAt({required String time}) {
    return '$time 提醒';
  }

  @override
  String get clearGoal => '清除目标';

  @override
  String rollingSum({required int count}) {
    return '$count 天累计';
  }

  @override
  String get nightlyShortfall => '每晚少睡';

  @override
  String get trendSection => '走势';

  @override
  String get eachDaySection => '每天';

  @override
  String get notEnoughEntries => '记录不足';

  @override
  String highestLowest({required String high, required String low}) {
    return '最高 $high · 最低 $low';
  }

  @override
  String get preliminary => '初步';

  @override
  String countedAt({required String hours}) {
    return '按 $hours计';
  }

  @override
  String goalValue({required String goal}) {
    return '目标 $goal';
  }

  @override
  String daysWithoutEntries({required int count}) {
    return '$count 天没有记录';
  }

  @override
  String get hoursUnit => '小时';

  @override
  String lastFortnightExtra({required String hours}) {
    return '近 14 天 · 多睡 $hours';
  }

  @override
  String needsLoggedDays({required int minimum, required int recorded}) {
    return '需要近 14 天有 $minimum 天记录（目前 $recorded 天）';
  }

  @override
  String lastWeekDebt({required String short, required String extra}) {
    return '近 7 天 $short · 多睡 $extra';
  }

  @override
  String hoursValue({required String hours}) {
    return '$hours 小时';
  }

  @override
  String shortBy({required String time}) {
    return '少 $time';
  }

  @override
  String overBy({required String time}) {
    return '多 $time';
  }

  @override
  String get photoTextUnavailable => '这台设备无法读取照片中的文字。';

  @override
  String get photoNoBodyComposition => '照片中没有读到身体成分的数字。';

  @override
  String get photoNoGirths => '照片中没有读到围度的数字。';

  @override
  String valueRangeError({
    required String field,
    required String min,
    required String max,
    required String unit,
  }) {
    return '$field请输入 $min – $max $unit 之间。';
  }

  @override
  String get fillAtLeastOne => '至少填一项。';

  @override
  String get fillAtLeastOneSite => '至少填一个部位。';

  @override
  String loggedValue({required String item, required String value}) {
    return '已记录$item $value';
  }

  @override
  String updatedValue({required String item, required String value}) {
    return '已更新$item $value';
  }

  @override
  String loggedItemsCount({required int count}) {
    return '已记录 $count 项';
  }

  @override
  String loggedSitesCount({required int count}) {
    return '已记录 $count 个部位';
  }

  @override
  String get scanAction => '扫描';

  @override
  String get readingPhoto => '正在读取照片…';

  @override
  String get scanBodyComposition => '拍照读取身体成分';

  @override
  String get scanGirths => '拍照读取围度';

  @override
  String lastReadingOn({required String value, required String date}) {
    return '上次 $value · $date';
  }

  @override
  String photoReadCheck({required int count}) {
    return '照片读到 $count 项，请核对';
  }

  @override
  String get fillFromScale => '按体脂秤显示填写';

  @override
  String get noteLogged => '已记录笔记';

  @override
  String get noteUpdated => '已更新笔记';

  @override
  String get noteHint => '例如：晚上聚餐，吃得比平常多';

  @override
  String get sleepWakeBeforeBed => '起床时间要在入睡之后';

  @override
  String get sleepOver24Hours => '一次睡眠不超过 24 小时';

  @override
  String get sleepWakeInFuture => '起床时间不能晚于现在';

  @override
  String get sleepStartLabel => '入睡';

  @override
  String get sleepEndLabel => '起床';

  @override
  String get qualityLabel => '质量';

  @override
  String get sleepNoteHint => '例如：睡前喝了咖啡、半夜醒来';

  @override
  String weightRangeError({required String min, required String max}) {
    return '请输入 $min – $max kg 之间的数值。';
  }

  @override
  String weightLogged({required String weight}) {
    return '已记录 $weight kg';
  }

  @override
  String weightUpdated({required String weight}) {
    return '已更新为 $weight kg';
  }

  @override
  String get symptomSeverity => '不适程度';

  @override
  String wellnessKindHow({required String kind}) {
    return '$kind如何？';
  }

  @override
  String get wellnessNoteHint => '例如：久坐一整天，下背有点紧';

  @override
  String get bmiBandUnder => '体重过轻';

  @override
  String get bmiBandHealthy => '健康体重';

  @override
  String get bmiBandOver => '超重';

  @override
  String get bmiBandObese => '肥胖';

  @override
  String yearsCount({required int count}) {
    return '$count 年';
  }

  @override
  String get logAction => '记录';

  @override
  String logItem({required String item}) {
    return '记录$item';
  }

  @override
  String trendReadingsLabel({required String item, required int count}) {
    return '$item走势，$count 条';
  }

  @override
  String get bodyScaleCompareSame => '体脂秤估计，请用同一台比较';

  @override
  String get noWeightEntries => '没有体重记录';

  @override
  String get trendWeight => '趋势体重';

  @override
  String latestOn({required String date, required String value}) {
    return '最近 $date $value';
  }

  @override
  String weightChartLabel({required int count}) {
    return '体重走势，$count 次';
  }

  @override
  String weightChartIdle({required int count}) {
    return '线为 7 日平均 · $count 次称重';
  }

  @override
  String trendValue({required String value}) {
    return '趋势 $value';
  }

  @override
  String get allWeightEntries => '所有体重记录';

  @override
  String get buildSection => '体型';

  @override
  String get waistToHipRatio => '腰臀比';

  @override
  String get bmiStandardTaiwan => '台湾国健署成人标准';

  @override
  String get fatMass => '脂肪量';

  @override
  String get waistAdviceTaiwan => '台湾国健署建议腰围：男 < 90 cm、女 < 80 cm';

  @override
  String get weeklyGoal => '每周目标';

  @override
  String get weeklyGoalPaused => '每周目标已暂停';

  @override
  String weeklyGoalButtonLabel({required int active, required int target}) {
    return '本周 $active / $target 个运动日，查看每周目标';
  }

  @override
  String activeDaysPerWeek({required int count}) {
    return '每周 $count 个运动日';
  }

  @override
  String get adjustWeeklyGoal => '调整每周目标';

  @override
  String get weeklyGoalPrompt => '每周要有几个运动日。';

  @override
  String get setWeeklyGoal => '设置每周目标';

  @override
  String get streakSection => '连续达标';

  @override
  String get weekGoalMet => '本周目标已完成';

  @override
  String get weekActivity => '本周运动';

  @override
  String get notCountedInStreak => '不计入连续达标';

  @override
  String activeDaysCount({required int count}) {
    return '$count 个运动日';
  }

  @override
  String activeDaysToGo({required int count}) {
    return '还差 $count 个运动日';
  }

  @override
  String get streakRestartsThisWeek => '本周重新开始';

  @override
  String get noStreakYet => '没有连续达标记录';

  @override
  String lastStreak({required int previous, required int best}) {
    return '上次连续达标 $previous 周，最佳 $best 周';
  }

  @override
  String get streakStartsAfterGoal => '达成一周目标后开始累积';

  @override
  String streakWeeks({required int count}) {
    return '连续达标 $count 周';
  }

  @override
  String streakPendingBest({required int best}) {
    return '本周进行中 · 最佳 $best 周';
  }

  @override
  String streakBest({required int best}) {
    return '最佳 $best 周';
  }

  @override
  String goalDayLabel({required int day}) {
    return '$day 日';
  }

  @override
  String goalDayActive({required int day}) {
    return '$day 日，有运动';
  }

  @override
  String activeDaysFraction({required int active, required int target}) {
    return '$active / $target 个运动日';
  }

  @override
  String goalFromThisWeek({required int count}) {
    return '本周起每周 $count 天';
  }

  @override
  String goalFromNextWeek({required int count}) {
    return '下周起每周 $count 天';
  }

  @override
  String get pauseWeeklyGoal => '暂停每周目标';

  @override
  String get pauseWeeklyGoalMessage => '暂停期间的周不会累积，也不会中断连续达标。';

  @override
  String get pauseThisWeek => '暂停本周';

  @override
  String get pauseUntilResumed => '直到手动恢复';

  @override
  String get activeDaysPerWeekQuestion => '一周想要有几个运动日';

  @override
  String suggestedDays({required int count}) {
    return '过去四周平均：每周 $count 天';
  }

  @override
  String get goalStartSection => '从什么时候开始';

  @override
  String get fromNextWeek => '下周起';

  @override
  String get fromNextWeekDetail => '本周仍用原本的目标计算';

  @override
  String get applyThisWeek => '本周就套用';

  @override
  String get applyThisWeekDetail => '重新计算本周';

  @override
  String get pauseOrTurnOff => '暂停或关闭';

  @override
  String get weeklyGoalOffDetail => '关闭时隐藏目标与连续达标';

  @override
  String get thisWeekPaused => '本周已暂停';

  @override
  String thisWeekActiveDays({required int active, required int target}) {
    return '本周 $active / $target 个运动日';
  }

  @override
  String get workoutInProgress => '训练进行中';

  @override
  String workoutCurrentSet({
    required String exercise,
    required int set,
    required int done,
  }) {
    return '$exercise · 第 $set 组 · 已完成 $done 组';
  }

  @override
  String get backToWorkout => '回到训练';

  @override
  String get thisSession => '本次';

  @override
  String get setsCompleted => '已完成组数';

  @override
  String get exerciseProgress => '动作进度';

  @override
  String get personalRecords => '个人记录';

  @override
  String get otherEntries => '其他记录';

  @override
  String get customiseToday => '自定义首页';

  @override
  String get showAll => '全部显示';

  @override
  String get todayOnlyWithData => '仅在有数值时显示';

  @override
  String reorderSection({required String section}) {
    return '调整$section的顺序';
  }

  @override
  String moreItemsCount({required int count}) {
    return '另 $count 项';
  }

  @override
  String get nextStep => '下一步';

  @override
  String get includesEstimates => '含估计值';

  @override
  String partialMacros({required String macros}) {
    return '$macros有记录没有数字，未计入。';
  }

  @override
  String routineCompleted({required String name}) {
    return '$name 已完成';
  }

  @override
  String get totalSets => '总组数';

  @override
  String get exercisesLabel => '动作';

  @override
  String get todaySectionGlance => '今日指标';

  @override
  String get todaySectionActivity => '今日活动';

  @override
  String get todaySectionWeek => '本周';

  @override
  String get todaySectionRecords => '今天的记录';

  @override
  String get todaySectionInsights => '值得注意';

  @override
  String weekdayActive({required String weekday}) {
    return '$weekday，有训练或运动';
  }

  @override
  String allCount({required int count}) {
    return '全部 $count 条';
  }

  @override
  String daysFraction({required int active, required int target}) {
    return '$active / $target 天';
  }

  @override
  String weightChange7Days({required String change}) {
    return '7 日 $change';
  }

  @override
  String trackingChangeRefused({required int count}) {
    return '已有 $count 次记录用这个追踪方式，改了会让旧记录变成另一种意思。要换成别的追踪方式，请建立一个新动作。';
  }

  @override
  String get createCustomExercise => '创建自定义动作';

  @override
  String get editExercise => '编辑动作';

  @override
  String exerciseOfSource({required String source}) {
    return '$source动作';
  }

  @override
  String get createAndAdd => '创建并加入';

  @override
  String get nameSection => '名称';

  @override
  String get exerciseNameHint => '例如：哑铃卧推';

  @override
  String get trackingTypeSection => '追踪方式';

  @override
  String get trackingTypeLocked => '创建后不能改成不兼容的追踪方式。';

  @override
  String get primaryMuscleOrPattern => '主要肌群或动作模式';

  @override
  String get equipmentSection => '器材';

  @override
  String get equipmentAny => '不指定';

  @override
  String get possibleDuplicate => '可能已经有这个动作';

  @override
  String entriesCount({required int count}) {
    return '$count 条记录';
  }

  @override
  String get useThis => '使用这个';

  @override
  String get duplicateAdvice => '选既有动作，历史与个人记录才不会被拆成好几份。';

  @override
  String exerciseDemoLabel({required String name, required int count}) {
    return '$name示范，$count 个姿势';
  }

  @override
  String get playing => '播放中';

  @override
  String get exerciseDemoCredit => '图：Workout Guide／Everkinetic · CC BY-SA 4.0';

  @override
  String get myAliases => '我的别名';

  @override
  String get aliasesHint => '用、分隔，例如：深蹲、squat';

  @override
  String get aliasesUpdated => '已更新别名';

  @override
  String get cannotMergeSelf => '不能和自己合并';

  @override
  String mergeTitle({required String duplicate, required String canonical}) {
    return '把「$duplicate」并入「$canonical」？';
  }

  @override
  String mergeMessage({required String canonical}) {
    return '过去的记录改算在「$canonical」下，动作不再出现在选择器。记录的内容不会被改写，但这个合并无法复原。';
  }

  @override
  String mergeInto({required String canonical}) {
    return '并入「$canonical」';
  }

  @override
  String mergedInto({required String canonical}) {
    return '已并入「$canonical」';
  }

  @override
  String get addThisExercise => '加入这个动作';

  @override
  String get otherVariations => '同一动作的其他做法';

  @override
  String get cuesSection => '重点提示';

  @override
  String get removeFavorite => '取消收藏';

  @override
  String get addFavorite => '加入收藏';

  @override
  String get favoriteRemoved => '已取消收藏';

  @override
  String get favoriteAdded => '已加入收藏';

  @override
  String get editExerciseDetail => '名称、器材、部位';

  @override
  String get editMyAliases => '编辑我的别名';

  @override
  String builtInNames({required String names}) {
    return '目前用内置名称：$names';
  }

  @override
  String get mergeIntoAnother => '合并到另一个动作';

  @override
  String get mergeIntoAnotherDetail => '重复创建时，把记录并到同一个动作下';

  @override
  String get unhide => '取消隐藏';

  @override
  String get hideExercise => '隐藏这个动作';

  @override
  String unhidden({required String name}) {
    return '已取消隐藏「$name」';
  }

  @override
  String hidden({required String name}) {
    return '已隐藏「$name」';
  }

  @override
  String get bodyPartLabel => '部位';

  @override
  String get primaryMuscles => '主要肌群';

  @override
  String get secondaryMuscles => '次要肌群';

  @override
  String get movementPatternLabel => '动作模式';

  @override
  String get lateralityLabel => '左右';

  @override
  String get lastWorkingSet => '上次工作组';

  @override
  String get estimatedMax => '估计最大重量';

  @override
  String get sessionsUnit => '次';

  @override
  String get trainingEntries => '训练记录';

  @override
  String estimatedMaxTrend({required int count}) {
    return '估计最大重量走势，$count 次训练';
  }

  @override
  String get epleyEstimate => 'Epley 估计';

  @override
  String relativeLoadPercent({required int percent}) {
    return '相对负荷 $percent%';
  }

  @override
  String get last90Days => '近 90 天';

  @override
  String get filterTitle => '筛选';

  @override
  String filtersApplied({required int count}) {
    return '已应用 $count 个条件';
  }

  @override
  String showExercises({required int count}) {
    return '显示 $count 个动作';
  }

  @override
  String get clearAll => '清除全部';

  @override
  String wholeRegion({required String region}) {
    return '整个$region';
  }

  @override
  String get sourceLabel => '来源';

  @override
  String get pickerTabRecent => '最近使用';

  @override
  String get pickerTabFavorites => '收藏';

  @override
  String get pickerTabHomeGym => '本健身房';

  @override
  String get pickerTabAll => '所有动作';

  @override
  String get pickerAddToRoutine => '加入课表';

  @override
  String get pickerAddToWorkout => '加入进行中的';

  @override
  String get pickerAddToEntry => '加入记录';

  @override
  String get pickerBrowse => '浏览与搜索所有动作';

  @override
  String get pickerSingle => '选择一个动作';

  @override
  String pickerPurposeFor({required String purpose, required String name}) {
    return '$purpose「$name」';
  }

  @override
  String discardSelectedTitle({required int count}) {
    return '放弃已选的 $count 个动作？';
  }

  @override
  String get discardSelected => '放弃已选的动作';

  @override
  String get keepChoosing => '继续选择';

  @override
  String get exerciseLibrary => '动作库';

  @override
  String get chooseExercise => '选择动作';

  @override
  String get addExercises => '新增动作';

  @override
  String get cantFindCreate => '找不到？创建自定义动作';

  @override
  String get searchExercisesHint => '搜索动作、别名或器材…';

  @override
  String get clearAction => '清除';

  @override
  String daysAgo({required int count}) {
    return '$count 天前';
  }

  @override
  String aboutItem({required String name}) {
    return '$name说明';
  }

  @override
  String get selectionOrderHint => '加入顺序 · 点一下可移除';

  @override
  String removeNumbered({required int index, required String name}) {
    return '移除第 $index 个：$name';
  }

  @override
  String addExercisesCount({required int count}) {
    return '加入 $count 个动作';
  }

  @override
  String get noMatchingExercises => '没有符合的动作';

  @override
  String equipmentFilterHint({required String equipment}) {
    return '应用了「器材：$equipment」，要找的动作可能是别种器材。';
  }

  @override
  String get searchAgainHint => '换个说法、英文名称或别名再试一次。';

  @override
  String get removeEquipmentFilter => '移除器材筛选再找一次';

  @override
  String get similarExercises => '相近的动作';

  @override
  String createNamed({required String name}) {
    return '创建「$name」';
  }

  @override
  String estimatedMaxValue({required int weight}) {
    return '估计最大重量 $weight kg';
  }

  @override
  String lastSetOn({required String date, required String set}) {
    return '上次 $date $set';
  }

  @override
  String get volumeTitle => '训练量';

  @override
  String get notEnoughWorkouts => '训练记录不足。';

  @override
  String volumeOf({required String exercise}) {
    return '$exercise的训练量';
  }

  @override
  String insightWeeks({required int weeks}) {
    return '值得注意 · 近 $weeks 周';
  }

  @override
  String volumeSteady({required int sets, required String estimate}) {
    return '每周工作组数维持在 $sets 组，估计最大重量 $estimate。';
  }

  @override
  String get notYetEstimable => '尚无法估计';

  @override
  String get basisSection => '依据';

  @override
  String weeklySetsFrom({required int count}) {
    return '每周工作组数，取自 $count 次训练记录。';
  }

  @override
  String get dataQualitySection => '数据质量与完整度';

  @override
  String workoutsAllLogged({required int count}) {
    return '$count 次训练皆有记录';
  }

  @override
  String get weightRepsManual => '重量与次数为手动输入';

  @override
  String get timeRangeSection => '时间范围';

  @override
  String fullWeeks({required int count}) {
    return '$count 个完整周';
  }

  @override
  String get actionsSection => '可采取的行动';

  @override
  String volumeDropped({required int sets}) {
    return '每周组数比这段期间开始时少。要继续进步，拉回 $sets 组左右。';
  }

  @override
  String get volumeStable => '目前的组数稳定。要继续进步，小幅增加每周组数或重量。';

  @override
  String adjustRoutineSets({required String routine}) {
    return '调整「$routine」的组数';
  }

  @override
  String get notMedicalAdvice => '这是训练记录的描述，不是医疗建议。';

  @override
  String get viewRawEntries => '查看这段期间的原始记录';

  @override
  String get noWorkingSets => '没有工作组记录';

  @override
  String muscleWeeklySets({required String muscle, required int sets}) {
    return '$muscle 每周 $sets 组';
  }

  @override
  String muscleScaleLabel({required int top}) {
    return '色阶由 0 到 $top 组以上';
  }

  @override
  String get setsPerWeek => '组 / 周';

  @override
  String get muscleMapLabel => '肌群训练量人体图，详细数值列在下方';

  @override
  String get musclesTitle => '肌群';

  @override
  String get weeklySetsLast8 => '每周工作组数 · 近 8 周';

  @override
  String get setsThisWeekUnit => '组 · 本周';

  @override
  String priorWeeksSets({required int weeks, required String sets}) {
    return '前 $weeks 周 $sets 组';
  }

  @override
  String muscleSetsChart({required String muscle, required String sets}) {
    return '$muscle每周组数，$sets';
  }

  @override
  String heaviestSet({required String set, required String date}) {
    return '最重 $set · $date';
  }

  @override
  String estimatedMaxOn({required int weight, required String date}) {
    return '估计最大重量 $weight kg · $date';
  }

  @override
  String get last4Weeks => '近 4 周';

  @override
  String monthsCount({required int count}) {
    return '$count 个月';
  }

  @override
  String get weeklySetsTitle => '每周组数';

  @override
  String get last8Weeks => '近 8 周';

  @override
  String get weeklyWorkouts => '每周训练';

  @override
  String get weeklyActivities => '每周运动';

  @override
  String get timesThisWeekUnit => '次 · 本周';

  @override
  String get noActivityEntries => '没有运动记录';

  @override
  String minutesVersusUsual({required int minutes, required int usual}) {
    return '$minutes 分 · 平常 $usual 分';
  }

  @override
  String get trendDomainBody => '身体';

  @override
  String get trendDomainTraining => '训练';

  @override
  String get trendDomainSleep => '睡眠';

  @override
  String get trendDomainNutrition => '饮食';

  @override
  String get trendDomainActivity => '活动';

  @override
  String areaTrend({required String area}) {
    return '$area趋势';
  }

  @override
  String get weekdaySection => '星期';

  @override
  String get otherAreasSection => '同期其他领域';

  @override
  String get dailyEntries => '每日记录';

  @override
  String perWeekTimes({required String count}) {
    return '每周 $count 次';
  }

  @override
  String stepsValue({required String steps}) {
    return '$steps 步';
  }

  @override
  String timesValue({required String count}) {
    return '$count 次';
  }

  @override
  String weekFrom({required String date}) {
    return '$date 起';
  }

  @override
  String get last13Weeks => '近 13 周';

  @override
  String get pastYear => '过去一年';

  @override
  String get prior12Weeks => '前 12 周';

  @override
  String periodAverage({required String period}) {
    return '$period平均';
  }

  @override
  String get weeklyCount => '每周次数';

  @override
  String get weeklyAverage => '每周平均';

  @override
  String get weeklyTotal => '每周合计';

  @override
  String daysLoggedPerWeek({required String days}) {
    return '近 4 周每周平均 $days 天有记录';
  }

  @override
  String get scaleWeight => '秤上体重';

  @override
  String get weeklyVolume => '每周训练量';

  @override
  String get restingHeartRate => '静息心率';

  @override
  String get weightAndNutrition => '体重与饮食';

  @override
  String get energyBalance => '能量平衡';

  @override
  String energyNeeds({
    required int window,
    required int foodDays,
    required int weighings,
    required int currentFood,
    required int currentWeighings,
  }) {
    return '需要近 $window 天有 $foodDays 天完整饮食、$weighings 次体重（目前 $currentFood 天、$currentWeighings 次）';
  }

  @override
  String proteinNeeds({
    required int window,
    required int days,
    required int current,
  }) {
    return '需要近 $window 天有 $days 天完整饮食与体重（目前 $current 天）';
  }

  @override
  String get muscleSetsTitle => '肌群组数';

  @override
  String muscleSetsNeeds({required int count, required int current}) {
    return '需要近 4 周至少 $count 次训练（目前 $current 次）';
  }

  @override
  String get possibleRelations => '可能的关联';

  @override
  String get longRunSection => '长期走向';

  @override
  String actualExpenditure({required String kcal}) {
    return '实际消耗 $kcal kcal/天';
  }

  @override
  String intakeDeficit({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '近 $window 天平均摄入 $intake kcal，每天赤字 $balance kcal';
  }

  @override
  String intakeSurplus({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '近 $window 天平均摄入 $intake kcal，每天盈余 $balance kcal';
  }

  @override
  String weightForecast({
    required String change,
    required int weeks,
    required String forecast,
  }) {
    return '趋势体重每周 $change kg，$weeks 周后 $forecast kg';
  }

  @override
  String foodDaysWeighings({required int foodDays, required int weighings}) {
    return '$foodDays 天完整饮食 · $weighings 次体重';
  }

  @override
  String get intakeUnderlogged => '估计的消耗低于静息代谢，记录的摄入可能少于实际。';

  @override
  String get estimatedFromEntries => '依记录估算';

  @override
  String weekendEatsMore({required String kcal}) {
    return '周末每天多吃 $kcal kcal';
  }

  @override
  String weekendEatsLess({required String kcal}) {
    return '周末每天少吃 $kcal kcal';
  }

  @override
  String weekdayWeekendKcal({
    required String weekday,
    required String weekend,
  }) {
    return '平日 $weekday kcal · 周末 $weekend kcal';
  }

  @override
  String get offsetsAllDeficit => '抵掉平日全部的赤字';

  @override
  String offsetsDeficitShare({required int percent}) {
    return '抵掉平日赤字 $percent%';
  }

  @override
  String weekdaysWeekends({
    required int window,
    required int weekdays,
    required int weekends,
  }) {
    return '近 $window 天，$weekdays 个平日、$weekends 个周末日';
  }

  @override
  String proteinMet({required String target}) {
    return '蛋白质达到 $target g/kg';
  }

  @override
  String proteinShort({required int grams}) {
    return '蛋白质每天差 $grams g';
  }

  @override
  String trainingRestProtein({required String trained, required String rest}) {
    return '训练日 $trained · 休息日 $rest g/kg';
  }

  @override
  String proteinBasis({
    required String weight,
    required String target,
    required int days,
  }) {
    return '以 $weight kg、目标 $target g/kg 计 · $days 天完整饮食';
  }

  @override
  String allMusclesEnough({required int target}) {
    return '练到的肌群每周都有 $target 组以上';
  }

  @override
  String muscleOnlySets({required String muscle, required int sets}) {
    return '$muscle每周只有 $sets 组';
  }

  @override
  String underSets({required int target, required String muscles}) {
    return '不到 $target 组：$muscles';
  }

  @override
  String atLeastSets({required int target, required String muscles}) {
    return '$target 组以上：$muscles';
  }

  @override
  String pairRatio({
    required String first,
    required String second,
    required int firstSets,
    required int secondSets,
  }) {
    return '$first对$second $firstSets : $secondSets 组';
  }

  @override
  String get musclePush => '推';

  @override
  String get musclePull => '拉';

  @override
  String get muscleSetsBasis => '近 4 周每周组数，只计主要肌群';

  @override
  String weekendWakeLater({required String time}) {
    return '周末起床晚 $time';
  }

  @override
  String weekendWakeEarlier({required String time}) {
    return '周末起床早 $time';
  }

  @override
  String weekdayWeekendWake({
    required String weekday,
    required String weekend,
  }) {
    return '平日 $weekday · 周末 $weekend 起床';
  }

  @override
  String get correlationCaveat => '关联，不代表因果';

  @override
  String get muscleFigureMale => '男性';

  @override
  String get muscleFigureFemale => '女性';

  @override
  String get workoutDiscarded => '已放弃这次训练';

  @override
  String get endWorkout => '结束训练';

  @override
  String get addExercise => '加入动作';

  @override
  String get notFilled => '未填写';

  @override
  String get startExercising => '开始运动';

  @override
  String get finishWorkout => '完成训练';

  @override
  String personalRecordSet({required String set}) {
    return '个人记录 · $set';
  }

  @override
  String get totalShort => '总';

  @override
  String get totalVolume => '总训练量';

  @override
  String versusLastTime({required String change}) {
    return '比上次 $change';
  }

  @override
  String setsOfTotal({required int done, required int total}) {
    return '$done / $total 组';
  }

  @override
  String get restTitle => '休息';

  @override
  String get skipRest => '跳过休息';

  @override
  String get elapsedTime => '时间';

  @override
  String get workoutNotesTitle => '这次训练的备注';

  @override
  String get workoutNotesHint => '例如：睡不好，握力先到极限';

  @override
  String get addWarmupSets => '加入热身组';

  @override
  String get addDropSet => '加入递减组';

  @override
  String get addFailureSet => '加入力竭组';

  @override
  String get replaceExercise => '替换这个动作';

  @override
  String get removeFromWorkout => '从这次训练移除';

  @override
  String get superset => '超级组';

  @override
  String optionsFor({required String name}) {
    return '$name的选项';
  }

  @override
  String volumeValue({required String volume}) {
    return '训练量 $volume kg';
  }

  @override
  String lastSetShort({required String date, required String set}) {
    return '上次 $date · $set';
  }

  @override
  String get loadPrevious => '载入';

  @override
  String get loadPreviousLabel => '过往记录';

  @override
  String get quickFill => '快速填入';

  @override
  String get quickFillLabel => '组数方案';

  @override
  String get setColumn => '组';

  @override
  String get repsColumn => '次';

  @override
  String get removeSet => '删除组';

  @override
  String get addSet => '新增组';

  @override
  String editItem({required String item}) {
    return '编辑$item';
  }

  @override
  String setWeight({required String set}) {
    return '$set重量';
  }

  @override
  String setReps({required String set}) {
    return '$set次数';
  }

  @override
  String setDone({required String set}) {
    return '$set完成';
  }

  @override
  String removedNamed({required String name}) {
    return '已移除「$name」';
  }

  @override
  String get routineName => '课表名称';

  @override
  String deleteNamedTitle({required String name}) {
    return '删除「$name」？';
  }

  @override
  String get routineDeleteKeeps => '已完成的训练记录会保留。';

  @override
  String get deleteRoutine => '删除这份课表';

  @override
  String deletedNamed({required String name}) {
    return '已删除「$name」';
  }

  @override
  String get startWorkout => '开始训练';

  @override
  String get activityBlocksWorkout => '运动进行中，先结束运动才能开始训练';

  @override
  String get plannedExercises => '计划的动作';

  @override
  String get soreMusclesToday => '今天酸痛的肌群';

  @override
  String get recentlyDone => '最近实际完成';

  @override
  String setsAndMinutes({required int sets, required int minutes}) {
    return '$sets 组 · $minutes 分';
  }

  @override
  String get rename => '重命名';

  @override
  String get moveUp => '上移';

  @override
  String get moveDown => '下移';

  @override
  String get joinSuperset => '与下一个组成超级组';

  @override
  String get leaveSuperset => '解除超级组';

  @override
  String get removeAction => '移除';

  @override
  String get eachSide => '单边';

  @override
  String get oneSetLessToday => '今天少 1 组';

  @override
  String get loadPreviousFill => '以上次的重量与次数填入';

  @override
  String get myRoutines => '我的课表';

  @override
  String get loadFromHistory => '载入记录';

  @override
  String startWorkoutCount({required int count}) {
    return '开始训练（$count 个动作）';
  }

  @override
  String get describeInWords => '一句话';

  @override
  String get addExercisesByHand => '手动新增动作';

  @override
  String get deleteAction => '删除';

  @override
  String deleteNamed({required String name}) {
    return '删除「$name」';
  }

  @override
  String get newRoutine => '新增课表';

  @override
  String get noWorkouts => '没有训练记录';

  @override
  String get selectAll => '选择全部';

  @override
  String pastSet({
    required int number,
    required String weight,
    required int reps,
  }) {
    return '$number 组 $weight kg $reps 次';
  }

  @override
  String routineSummary({required int exercises, required int sets}) {
    return '$exercises 个动作 · $sets 组';
  }

  @override
  String get saveAsRoutine => '存成课表';

  @override
  String get describeWorkoutHint =>
      '例如：\n杠铃深蹲 4×8 60kg\n卧推 3 组 10 下 40 公斤\n引体向上 3x8';

  @override
  String get noExercisesRead => '没有读到动作';

  @override
  String removeNamed({required String name}) {
    return '移除「$name」';
  }

  @override
  String get exerciseNotFound => '找不到这个动作';

  @override
  String setsTimesReps({
    required int sets,
    required int reps,
    required String weight,
  }) {
    return '$sets 组 × $reps 下 · $weight kg';
  }

  @override
  String setsSameWeight({
    required int sets,
    required String weight,
    required String reps,
  }) {
    return '$sets 组 · $weight kg × $reps 下';
  }

  @override
  String get editWorkout => '编辑训练';

  @override
  String get timeSection => '时间';

  @override
  String get durationLabel => '时长';

  @override
  String savedAsRoutine({required String name}) {
    return '已存成课表「$name」';
  }

  @override
  String get keepAsIs => '维持原本';

  @override
  String get applyAction => '应用';

  @override
  String get progressionIncrease => '加重';

  @override
  String get progressionHold => '维持';

  @override
  String get progressionDeload => '退一阶';

  @override
  String get nextTimeSuggestions => '下次的建议';

  @override
  String changedTo({required String name, required String weight}) {
    return '$name 改为 $weight kg';
  }

  @override
  String decreaseBy({required String amount}) {
    return '减少 $amount';
  }

  @override
  String increaseBy({required String amount}) {
    return '增加 $amount';
  }

  @override
  String get oneRepLess => '少 1 次';

  @override
  String get oneRepMore => '多 1 次';

  @override
  String get notLogged => '未记';

  @override
  String get deleteThisSet => '删除这一组';

  @override
  String get platesImpossible => '杠片凑不出这个重量';

  @override
  String get emptyBar => '空杠';

  @override
  String platesPerSide({required String plates}) {
    return '每边 $plates';
  }

  @override
  String setNumberWeight({required int number}) {
    return '第 $number 组重量';
  }

  @override
  String setNumberReps({required int number}) {
    return '第 $number 组次数';
  }

  @override
  String get replaceTodayOnly => '只替换今天';

  @override
  String get replaceTodayOnlyDetail => '只有这次用新动作';

  @override
  String get replaceInRoutine => '也更新课表';

  @override
  String get replaceInRoutineDetail => '之后都改用新动作';

  @override
  String replacedToday({required String name}) {
    return '今天改做「$name」';
  }

  @override
  String replacedInRoutine({required String routine, required String name}) {
    return '今天与之后的「$routine」都改做「$name」';
  }

  @override
  String replacePattern({required String pattern}) {
    return '替换 $pattern';
  }

  @override
  String todaysExerciseNumber({required String routine, required int number}) {
    return '今天的「$routine」· 第 $number 个动作';
  }

  @override
  String get replaceAction => '替换';

  @override
  String get candidateExercises => '候选动作';

  @override
  String get chooseFromAll => '从所有动作选择';

  @override
  String get applyScope => '应用范围';

  @override
  String equipmentChangeWarning({required String from, required String to}) {
    return '$from换$to没有可靠的重量换算：保留组数、次数与 RIR，重量重新设定。';
  }

  @override
  String get exerciseInfo => '动作说明';

  @override
  String get noFinishedWorkout => '没有完成的训练';

  @override
  String get totalAmount => '总量';

  @override
  String get workloadSection => '这次的负荷';

  @override
  String get trainedAreas => '训练部位';

  @override
  String get muscleSetsLast7 => '近 7 天肌群组数';

  @override
  String get editThisEntry => '编辑这笔记录';

  @override
  String get volumeSame => '总量与上次相同';

  @override
  String volumeChangePercent({required String change}) {
    return '总量比上次 $change%';
  }

  @override
  String setsAndVolume({required int sets, required String volume}) {
    return '$sets 组 · $volume kg';
  }

  @override
  String get qualityConfirmed => '已确认';

  @override
  String get qualityPortionEstimated => '份量为估计';

  @override
  String get qualityCustomFood => '自定义食物';

  @override
  String get qualityQuickLog => '快速记录';

  @override
  String get qualityAiEstimate => 'AI 估计';

  @override
  String qualityAiEstimateBy({required String source}) {
    return '$source 估计';
  }

  @override
  String get nutritionLabel => '营养成分表';

  @override
  String photoItemsCount({required int count}) {
    return '照片里有 $count 项';
  }

  @override
  String get mergeIntoOneFood => '合并成一个食物';

  @override
  String get logEachItem => '逐项记录';

  @override
  String get nutrientNegative => '营养素不能是负数。';

  @override
  String updatedNamed({required String name}) {
    return '已更新「$name」';
  }

  @override
  String get editThisMeal => '编辑这一餐';

  @override
  String get newFood => '新增食物';

  @override
  String get editFood => '编辑食物';

  @override
  String get scanFoodOrLabel => '扫描食物或营养成分表';

  @override
  String get createOnly => '只创建';

  @override
  String get createAndLog => '创建并记录';

  @override
  String labelReadBy({required String provider, required String model}) {
    return '数字来自 $provider（$model）的判读，请对照包装核对。';
  }

  @override
  String photoEstimatedBy({required String provider, required String model}) {
    return '数字是 $provider（$model）从照片的估算，请核对。';
  }

  @override
  String get foodNameHint => '例如：鸡胸肉';

  @override
  String get mealTypeOptional => '餐次';

  @override
  String get saveToLibrary => '存入食物库';

  @override
  String get cupSize => '杯型';

  @override
  String get cupSizeHint => '例如：Tall';

  @override
  String get brandLabel => '品牌';

  @override
  String get brandHint => '例如：大成';

  @override
  String get foodOrDrink => '食物或饮品';

  @override
  String get volumeLabel => '容量';

  @override
  String get portionSection => '份量';

  @override
  String get portionHint => '例如：一碗';

  @override
  String get newCupSize => '新增杯型';

  @override
  String get nutrientsSection => '营养素';

  @override
  String per100Unit({required String unit}) {
    return '每 100 $unit';
  }

  @override
  String get perServingTotal => '一份总共';

  @override
  String get abvLabel => '酒精度';

  @override
  String get deleteThisMeal => '删除这一餐';

  @override
  String get countryTW => '台湾';

  @override
  String get countryJP => '日本';

  @override
  String get countryUS => '美国';

  @override
  String get countryEU => '欧盟';

  @override
  String get countryAU => '澳大利亚';

  @override
  String get countryNZ => '新西兰';

  @override
  String get countryKR => '韩国';

  @override
  String get countryCN => '中国';

  @override
  String get countryCA => '加拿大';

  @override
  String brandInCountry({required String brand, required String country}) {
    return '$brand（$country）';
  }

  @override
  String get officialData => '官方资料';

  @override
  String updatedOn({required String date}) {
    return '更新 $date';
  }

  @override
  String get foodScopeAll => '全部';

  @override
  String get foodScopeRecent => '最近';

  @override
  String get foodScopeStarred => '收藏';

  @override
  String get foodScopeOwn => '自己的';

  @override
  String get foodScopeBrands => '品牌';

  @override
  String loggedNamed({required String name}) {
    return '已记录「$name」';
  }

  @override
  String get loggedToast => '已记录';

  @override
  String mealTypeHeaderLabel({required String meal}) {
    return '这是哪一餐，目前$meal';
  }

  @override
  String get unspecified => '不指定';

  @override
  String get searchFoodHint => '搜索食物或品牌';

  @override
  String get takePhotoAction => '拍照';

  @override
  String get recentMealsSection => '近期用餐';

  @override
  String get noFoods => '没有食物';

  @override
  String get eatenFoods => '吃过的食物';

  @override
  String get noRecentFoods => '没有最近吃过的食物。';

  @override
  String get starredFoods => '收藏的食物';

  @override
  String get starredMeals => '收藏的餐';

  @override
  String get noFavorites => '没有收藏。';

  @override
  String get noOwnFoods => '没有自己的食物';

  @override
  String get noBuiltInBrands => '没有内置的连锁品牌。';

  @override
  String viewFullMenu({required String brand}) {
    return '$brand · 查看完整菜单';
  }

  @override
  String get noMatchingItems => '没有符合的项目';

  @override
  String get notFoundQuestion => '找不到？';

  @override
  String get purposeSection => '目的';

  @override
  String mergedCount({required int count}) {
    return '已合并 $count 条';
  }

  @override
  String removedWater({required int millilitres}) {
    return '已移除 $millilitres mL 的水';
  }

  @override
  String get splitDone => '已拆成独立记录';

  @override
  String get mergeAction => '合并';

  @override
  String get mergeEntries => '合并几条记录';

  @override
  String get cancelMerge => '取消合并';

  @override
  String get mergeIntoMeal => '合并成一餐';

  @override
  String mergeCountIntoMeal({required int count}) {
    return '合并 $count 条成一餐';
  }

  @override
  String get setGoal => '设置目标';

  @override
  String get changeAction => '更改';

  @override
  String get dailyIndicators => '每日指标';

  @override
  String get mealsSection => '餐点';

  @override
  String get mealShare => '占比';

  @override
  String get mealShareHide => '隐藏占比';

  @override
  String get noMealsThisDay => '这一天没有记录任何一餐';

  @override
  String get waterSection => '水';

  @override
  String removeWaterAt({required String time}) {
    return '移除 $time 的水';
  }

  @override
  String get otherNutrients => '其他营养素';

  @override
  String itemsCountShort({required int count}) {
    return '$count 项';
  }

  @override
  String get splitIntoEntry => '拆成独立记录';

  @override
  String entriesWithoutKcal({required int count}) {
    return '$count 条没有热量，实际更多';
  }

  @override
  String eatenKcal({required String kcal}) {
    return '已吃 $kcal kcal';
  }

  @override
  String eatenOfTarget({required String kcal, required String target}) {
    return '已吃 $kcal kcal，目标 $target kcal';
  }

  @override
  String get eatenKcalTitle => '已吃 kcal';

  @override
  String get remainingKcalTitle => '剩余 kcal';

  @override
  String get overKcalTitle => '超过 kcal';

  @override
  String get workedOut => '推算';

  @override
  String get caffeineRemaining => '估计残留咖啡因';

  @override
  String halfLifeBasis({required String hours}) {
    return '依半衰期 $hours 小时推算';
  }

  @override
  String caffeineReference({required String mg}) {
    return '就寝参考 $mg mg';
  }

  @override
  String get caffeineBelowReference => '低于就寝参考';

  @override
  String get caffeineBelowReferenceDone => '已低于就寝参考';

  @override
  String get liveActivities => '实时活动';

  @override
  String get endLiveActivity => '结束实时活动';

  @override
  String get last24Hours => '近 24 小时';

  @override
  String workedOutValue({required String value}) {
    return '$value · 推算';
  }

  @override
  String caffeineValue({required String mg}) {
    return '咖啡因 $mg mg';
  }

  @override
  String oneServingIs({required String serving}) {
    return '一份 = $serving';
  }

  @override
  String get starred => '已收藏';

  @override
  String get starAction => '收藏';

  @override
  String get starThisFood => '收藏这个食物';

  @override
  String get editThisFood => '编辑这个食物';

  @override
  String addPortion({required String portion}) {
    return '加入 $portion';
  }

  @override
  String get servingsLabel => '份数';

  @override
  String get actualAmount => '实际份量';

  @override
  String get barcode => '条码';

  @override
  String get allergens => '过敏原';

  @override
  String get none => '无';

  @override
  String get valueTypeMaxNote => '标示上限值，实际可能较低。';

  @override
  String dataSource({required String source}) {
    return '数据来源：$source';
  }

  @override
  String get deleteThisFood => '删除这个食物';

  @override
  String itemsWithoutKcal({required int count}) {
    return '$count 项没有热量';
  }

  @override
  String get thisMeal => '这一餐';

  @override
  String get finishEditing => '完成编辑';

  @override
  String logItemsCount({required int count}) {
    return '记录 $count 项';
  }

  @override
  String get plateEmpty => '这一餐没有项目。';

  @override
  String get photoEstimate => '照片估算';

  @override
  String get retry => '重试';

  @override
  String get chooseAiFirst => '先选一个 AI 才能生成草稿。';

  @override
  String get foodPhoto => '食物照片';

  @override
  String get describeMealHint => '例如：早餐 蛋饼加大杯冰奶茶';

  @override
  String get draftSection => '草稿';

  @override
  String openAiSettings({required String me}) {
    return '到「$me > AI」设置';
  }

  @override
  String get dailyKcalGoal => '每日热量目标';

  @override
  String get kcalRangeError => '请填 800–6000 kcal。';

  @override
  String numberRangeError({required String min, required String max}) {
    return '请填 $min–$max。';
  }

  @override
  String get weeklyChange => '每周变化';

  @override
  String get dailyTargets => '每日目标';

  @override
  String get kcalTarget => '热量目标';

  @override
  String get estimateFromBody => '依身体资料估算';

  @override
  String get estimateFromBodyDetail => '体重、身高、年龄、性别与活动量';

  @override
  String get setMyself => '自己设置';

  @override
  String get bodyData => '身体资料';

  @override
  String yearValue({required int year}) {
    return '$year 年';
  }

  @override
  String get activityLevelSection => '活动量';

  @override
  String get macroSplit => '营养素分配';

  @override
  String get byGoal => '依目的';

  @override
  String perKgBodyWeight({required String grams}) {
    return '每公斤体重 $grams g';
  }

  @override
  String get proteinPerKgTitle => '蛋白质（每公斤体重）';

  @override
  String byGoalGrams({required String grams}) {
    return '依目的 $grams g';
  }

  @override
  String percentOfKcal({required int percent}) {
    return '热量的 $percent%';
  }

  @override
  String get fatPercentTitle => '脂肪（占热量 %）';

  @override
  String defaultPercent({required int percent}) {
    return '默认 $percent%';
  }

  @override
  String get restOfKcal => '其余的热量';

  @override
  String get resultSection => '结果';

  @override
  String get restingMetabolism => '基础代谢';

  @override
  String get maintenanceKcal => '维持热量';

  @override
  String get dailyKcal => '每日热量';

  @override
  String missingInputs({required String inputs}) {
    return '缺少$inputs';
  }

  @override
  String limitValue({required String value}) {
    return '上限 $value';
  }

  @override
  String fromRecentFoodAndWeight({required int days}) {
    return '依近 $days 天饮食与体重';
  }

  @override
  String get mifflinEstimate => 'Mifflin-St Jeor 估计';

  @override
  String get noCamera => '没有可用的相机';

  @override
  String get pickFromLibrary => '从相册选取';

  @override
  String servingAndKcal({required String serving, required String kcal}) {
    return '一份 $serving · $kcal kcal';
  }

  @override
  String get foodLibrary => '食物库';

  @override
  String get noOwnFoodsSentence => '没有自己的食物。';

  @override
  String get noMatchingFoods => '没有符合的食物。';

  @override
  String get officialReadOnly => '官方资料，只读';

  @override
  String splitIntoCount({required int count}) {
    return '已拆成 $count 条';
  }

  @override
  String get splitThisMeal => '拆开这一餐';

  @override
  String usualMealType({required String meal}) {
    return '常用：$meal';
  }

  @override
  String get whichMeal => '这是哪一餐';

  @override
  String splitDishTitle({required int count}) {
    return '要把这道料理拆成 $count 条独立记录吗？';
  }

  @override
  String splitDishMessage({required String dish}) {
    return '拆开后每项成分各自成为一条记录，可以单独编辑、移到别餐或删除，「$dish」这一层就不存在了。';
  }

  @override
  String get nowLabel => '现在';

  @override
  String get afterSplit => '拆开后';

  @override
  String componentsCount({required int count}) {
    return '$count 项成分';
  }

  @override
  String otherCount({required int count}) {
    return '其他 $count 项';
  }

  @override
  String get undoWithin30s => '30 秒内可以复原。';

  @override
  String get waterGlass => '一杯';

  @override
  String get waterLargeGlass => '大杯';

  @override
  String get waterBottle => '一瓶';

  @override
  String get waterPerTap => '一次记多少';

  @override
  String get customAction => '自定义';

  @override
  String get moreAction => '更多';

  @override
  String get waterPerTapMl => '一次记多少 mL';

  @override
  String get waterReference => '每日参考量';

  @override
  String get waterReferenceMl => '每日参考量 mL';

  @override
  String get waterReferenceNote => '人群参考值，实际需求因人而异';

  @override
  String get waterReferenceHpa => '台湾国健署';

  @override
  String get waterReferenceNone => '不设定';

  @override
  String waterFastWarning({required String millilitres}) {
    return '1 小时内已记录 $millilitres mL。短时间大量喝水可能造成低血钠，请分次慢慢喝。';
  }

  @override
  String waterPerTapLabel({required int millilitres}) {
    return '一次记多少，目前 $millilitres 毫升';
  }

  @override
  String waterTimesLast({required int count, required String time}) {
    return '$count 次 · 最近 $time';
  }

  @override
  String allDrinksTotal({required int millilitres}) {
    return '饮品总量 $millilitres mL（含咖啡、茶等）';
  }

  @override
  String todayAt({required String time}) {
    return '今天 $time';
  }

  @override
  String yesterdayAt({required String time}) {
    return '昨天 $time';
  }

  @override
  String addNamed({required String name}) {
    return '加入$name';
  }

  @override
  String get contentsSection => '内容';

  @override
  String get muscleMapSetting => '人体图';

  @override
  String get conventionMessage => '每日总计的名称、盐分单位与上限；食物页按它自己的标示。';

  @override
  String get profileSection => '个人资料';

  @override
  String get goalsAndReminders => '目标与提醒';

  @override
  String get featuresSection => '功能';

  @override
  String get exerciseLibraryDetail => '浏览、搜索与创建自定义动作';

  @override
  String modulesEnabled({required String modules}) {
    return '$modules 已启用';
  }

  @override
  String get notEnabled => '未启用';

  @override
  String get dataSection => '数据';

  @override
  String databaseRecovered({required String path}) {
    return '上次的数据文件无法读取，已移到 $path，并从空白重新开始。旧文件没有被删除。';
  }

  @override
  String get localData => '本机数据';

  @override
  String get dataSourcesDetail => '手动输入、导入与内置目录';

  @override
  String get showDemoData => '显示示例数据';

  @override
  String get exportTitle => '导出';

  @override
  String get exportDetail => '完整归档 JSON · CSV 视图';

  @override
  String get privacyDetail => '数据存在哪里、会发送什么';

  @override
  String get aboutSection => '关于';

  @override
  String get versionLabel => '版本';

  @override
  String get exerciseImages => '动作图';

  @override
  String get referencesTitle => '文献来源';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get workoutsFigure => '训练';

  @override
  String get activeDaysFigure => '运动日';

  @override
  String get daysUnit => '天';

  @override
  String get weeksUnit => '周';

  @override
  String get startedLogging => '开始记录';

  @override
  String goalSummaryText({required int target, required int active}) {
    return '每周 $target 个运动日 · 本周 $active';
  }

  @override
  String proteinGrams({required String grams}) {
    return '蛋白质 $grams g';
  }

  @override
  String foodLibrarySummary({required int own, required int brands}) {
    return '自己的 $own 种 · 品牌 $brands 家';
  }

  @override
  String get birthYearHint => '例如 1995';

  @override
  String get birthYearError => '出生年请填 4 位数公元年。';

  @override
  String get sexUseMessage => '只用来估算每日热量。';

  @override
  String get fullArchiveJson => '完整归档（JSON）';

  @override
  String get fullArchiveDetail => '可完整还原';

  @override
  String get fullArchiveDone => '已创建完整归档';

  @override
  String get csvViews => 'CSV 视图';

  @override
  String get csvViewsDetail => '方便阅读，不保证无损';

  @override
  String get csvViewsDone => '已创建 CSV 视图';

  @override
  String get exportNotEncrypted => '导出的文件没有加密。';

  @override
  String exportDoneFile({required String done, required String file}) {
    return '$done：$file';
  }

  @override
  String exportFailed({required String error}) {
    return '导出失败：$error';
  }

  @override
  String appliedTo({required String routine}) {
    return '已应用到「$routine」';
  }

  @override
  String get aiProposalTitle => 'AI 建议的修改';

  @override
  String aiProposalSubtitle({required String routine}) {
    return '训练「$routine」· 尚未应用';
  }

  @override
  String get reject => '拒绝';

  @override
  String get acceptAndApply => '接受并应用';

  @override
  String get questionLabel => '提问';

  @override
  String get proposalQuestion => '「最近深蹲的组数是不是太少了？帮我加回来。」';

  @override
  String changesCount({required int count}) {
    return '改动 $count 个动作';
  }

  @override
  String get reasonLabel => '理由';

  @override
  String get proposalReason =>
      '每周工作组数从 12 降到 8，依「肌力维持」目标，训练引擎建议的区间是 10 – 12 组。';

  @override
  String get proposalDataSent => '发送的数据：近 4 周训练记录';

  @override
  String get proposalModel => '模型：自建端点';

  @override
  String get addedLabel => '新增';

  @override
  String get unchangedLabel => '不变';

  @override
  String setsTimesRepsShort({required int sets, required int reps}) {
    return '$sets 组 × $reps 次';
  }

  @override
  String get privacyStorage => '存储';

  @override
  String get privacyRecords => '记录';

  @override
  String get privacyRecordsValue => '只在这台设备';

  @override
  String get privacyAccount => '账号';

  @override
  String get privacyServer => '服务器';

  @override
  String get privacyDeleted => '删除的记录';

  @override
  String get privacyDeletedValue => '可复原';

  @override
  String get privacyUninstall => '卸载 App';

  @override
  String get privacyUninstallValue => '清除所有记录';

  @override
  String get privacyCameraSection => '相机与相册';

  @override
  String get privacyCamera => '相机';

  @override
  String get privacyCameraValue => '只在扫描时开启';

  @override
  String get privacyPhotos => '相册';

  @override
  String get privacyPhotosValue => '读取最新一张作为选取按钮的缩略图';

  @override
  String get privacyScalePhotos => '体脂秤与围度照片';

  @override
  String get privacyScalePhotosValue => '在设备上读取数字，不发送';

  @override
  String privacyHealthSection({required String platform}) {
    return '健康数据（$platform）';
  }

  @override
  String get privacyPermission => '权限';

  @override
  String get privacyPermissionValue => '读取与写入';

  @override
  String get privacyReading => '读取';

  @override
  String get privacyReadingValue => '第一次读取全部记录，之后打开 App 时读取最近 30 天';

  @override
  String get privacyLeavesDevice => '发送出设备';

  @override
  String get privacyNo => '否';

  @override
  String get privacyToAi => '提供给 AI';

  @override
  String get privacyAds => '用于广告';

  @override
  String get privacyDisconnect => '断开连接后';

  @override
  String get privacyDisconnectValue => '已读入的记录保留';

  @override
  String get privacyKinds => '读取类别';

  @override
  String get privacyDefault => '默认';

  @override
  String get privacyNotUsed => '不使用';

  @override
  String get privacyAppleIntelligence => '在设备上运行';

  @override
  String get privacyCloudReceives => '云端 AI 收到';

  @override
  String get privacyCloudReceivesValue => '输入的文字、照片识别出的文字、估算用的食物照片';

  @override
  String get privacyFoodPhotos => '食物照片';

  @override
  String get privacyFoodPhotosValue => '先移除位置与拍摄信息，不保存';

  @override
  String get privacyOtherData => '其他照片、其他记录、健康数据';

  @override
  String get privacyNotSent => '不发送';

  @override
  String get privacyFirstSend => '第一次发送文字或照片前';

  @override
  String privacyFirstSendValue({required String me}) {
    return '分别询问同意，可在「$me > AI」撤回';
  }

  @override
  String get privacyAiResults => 'AI 的结果';

  @override
  String get privacyAiResultsValue => '草稿，确认后才记录';

  @override
  String get privacyGoogleFree => 'Google AI Studio 免费额度';

  @override
  String get privacyGoogleFreeValue => '内容可能用于改进产品并经人工审阅';

  @override
  String get privacyKeysSection => '密钥与导出';

  @override
  String get privacyApiKeys => 'API 密钥';

  @override
  String get privacyApiKeysValue => '系统安全存储区，不进数据库';

  @override
  String get privacyExportFiles => '导出文件';

  @override
  String privacyExportFilesValue({required String me}) {
    return '只在「$me > 导出」手动创建';
  }

  @override
  String get privacyExportContents => '导出内容';

  @override
  String get privacyExportContentsValue => '不含 API 密钥';

  @override
  String get privacyUpload => '上传';

  @override
  String get refUse01 => '基础代谢的估算公式';

  @override
  String get refUse02 => '健康成人以 Mifflin-St Jeor 估算最接近实测';

  @override
  String get refUse03 => '活动量（身体活动程度）的分级';

  @override
  String get refUse04 => '维持与增肌的蛋白质，每公斤 1.6–1.8 g（范围 1.4–2.0 g）';

  @override
  String get refUse05 => '减脂每周 0.5–1% 体重、提高蛋白质、脂肪占热量 15–30%';

  @override
  String get refUse06 => '减脂的蛋白质每公斤 2.2 g';

  @override
  String get refUse07 => '减脂默认每周 0.5% 体重，慢一点保留较多去脂体重';

  @override
  String get refUse08 => '增肌只用小盈余，默认每周 0.25% 体重';

  @override
  String get refUse09 => '每公斤体重约 7,700 kcal 只是粗略的起点';

  @override
  String get refUse10 => '膳食纤维每 1,000 kcal 14 g、脂肪占热量 20–35%';

  @override
  String get refUse11 => '台湾：成人每日钠 2,400 mg 以下';

  @override
  String get refUse12 => '日本：成人每日食盐相当量男性 7.5 g、女性 6.5 g 以下';

  @override
  String get refUse13 => '日本标示：食盐相当量（g）＝钠（mg）× 2.54 ÷ 1,000';

  @override
  String get refUse14 => '美国、加拿大：成人每日钠 2,300 mg 以下';

  @override
  String get refUse15 => '欧盟：成人每日钠 2.0 g，即盐 5 g';

  @override
  String get refUse16 => '欧盟标示：碳水化合物不含膳食纤维；盐＝钠 × 2.5';

  @override
  String get refUse17 => '澳大利亚、新西兰：成人每日钠 2,000 mg';

  @override
  String get refUse18 => '澳大利亚、新西兰标示：碳水化合物不含膳食纤维，能量以 kJ 标示';

  @override
  String get refUse19 => '韩国：成人每日钠 2,300 mg 以下';

  @override
  String get refUse20 => '中国：成人每日食盐 5 g 以下';

  @override
  String get refUse21 => '残留咖啡因依半衰期 5 小时推算';

  @override
  String get refUse22 => '半衰期因人而异，推算值不是测量';

  @override
  String get refUse23 => '睡前 4 小时 100 mg 未测得影响，参考线不是安全门槛';

  @override
  String get refUse46 => '35 mg 参考线由睡前 8.8 小时 107 mg、13.2 小时 217.5 mg 推算';

  @override
  String get refUse47 => '每日参考量 1,500 mL，只计白开水';

  @override
  String get refUse48 => '肾脏每小时约可排出 0.7–1.0 L，1 小时内 1,000 mL 以上时提醒';

  @override
  String get refUse24 => '未设置目标时以每晚 8 小时计（共识为 7 小时以上）';

  @override
  String get refUse25 => '少睡的影响在 14 天内持续累积';

  @override
  String get refUse26 => '多睡不以一比一抵销少睡';

  @override
  String get refUse27 => '恢复没有公认的速率，不设衰减';

  @override
  String get refUse28 => '估计最大重量（1RM）的公式';

  @override
  String get refUse29 => '超过 10 下不估计；5 下最准';

  @override
  String get refUse30 => '7–10 下的估计仍准确';

  @override
  String get refUse31 => '次数越多，个人与动作之间的差异越大';

  @override
  String get refUse42 => '以 %1RM 表示训练负荷';

  @override
  String get refUse43 => '以 %1RM 表示负荷的更新指引';

  @override
  String get refUse44 => '负荷与接近力竭程度是不同变量';

  @override
  String get refUse45 => '以剩余次数（RIR）表示接近力竭程度';

  @override
  String get refUse32 => '每肌群每周 10 组以上的组数剂量反应';

  @override
  String get refUse33 => '蛋白质每公斤 1.6 g 后增益不再明显';

  @override
  String get refUse34 => '最大心率以 208 − 0.7 × 年龄估算';

  @override
  String get refUse35 => '有静息心率时以心率储备划分区间';

  @override
  String get refUse36 => 'BMI 过轻、正常、过重、肥胖的分级';

  @override
  String get refUse37 => '去脂体重指数（FFMI）的定义';

  @override
  String get refUse38 => '增肌减脂只用小赤字：每天约 500 kcal 时瘦体重不再增加';

  @override
  String get refUse39 => '增肌减脂可选小赤字或维持热量，搭配高蛋白质';

  @override
  String get refUse40 => '增肌减脂在维持热量时蛋白质每公斤 2.0 g';

  @override
  String get refUse41 => '增肌减脂的蛋白质以 BMI 30 的体重为上限';

  @override
  String get refSectionTargets => '每日热量与营养素目标';

  @override
  String get refSectionLabels => '营养成分表';

  @override
  String get refSectionCaffeine => '咖啡因';

  @override
  String get refSectionSleepDebt => '睡眠债';

  @override
  String get refSectionTraining => '训练与趋势';

  @override
  String get refSectionHeartZones => '运动心率区间';

  @override
  String get refSectionBody => '身体';

  @override
  String get openLink => '打开链接';

  @override
  String get openAction => '打开';

  @override
  String get cannotOpenLink => '无法打开链接';

  @override
  String apiKeyTitle({required String provider}) {
    return '$provider API 密钥';
  }

  @override
  String get apiKeyHint => '粘贴密钥，留空即删除';

  @override
  String get apiEndpoint => 'API 地址';

  @override
  String get azureResourceUrl => 'Azure AI Foundry 资源网址';

  @override
  String get modelLabel => '模型';

  @override
  String get modelListUnavailable => '读不到模型列表，请直接输入名称。';

  @override
  String get typeOwn => '自己输入';

  @override
  String get deploymentName => '部署名称';

  @override
  String get modelHint => '例如 gemini-3.8-flash';

  @override
  String get signInInBrowser => '在浏览器登录';

  @override
  String signInInstructions({required String uri, required String code}) {
    return '到 $uri 输入代码 $code，以公司或学校账号登录。';
  }

  @override
  String get copyCode => '复制代码';

  @override
  String get okAction => '好';

  @override
  String get signedInCopilot => '已登录 Microsoft 365 Copilot';

  @override
  String get clientId => '客户端 ID';

  @override
  String get clientIdHint => 'Entra 应用注册的 Application (client) ID';

  @override
  String get tenant => '租户';

  @override
  String get tenantHint => '留空代表 organizations';

  @override
  String get revokeConsentTitle => '撤回同意？';

  @override
  String get revokeConsentMessage => '下次使用云端 AI 前会再次询问。';

  @override
  String get revokeConsent => '撤回同意';

  @override
  String get autoNameMergedMeals => '自动命名合并的餐点';

  @override
  String get serviceSection => '服务';

  @override
  String get signedIn => '已登录';

  @override
  String get signIn => '登录';

  @override
  String get waitingForBrowser => '等待浏览器登录…';

  @override
  String get signInAgain => '重新登录';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get isSet => '已设置';

  @override
  String get loadingModels => '读取模型…';

  @override
  String get notChosen => '未选择';

  @override
  String get consentTextAndPhotos => '目前已同意发送文字与照片';

  @override
  String get consentText => '目前已同意发送文字';

  @override
  String get consentPhotos => '目前已同意发送照片';

  @override
  String get checkingEllipsis => '检查中…';

  @override
  String get appleNotEligible => '这台设备不支持 Apple 智能';

  @override
  String get appleNotEnabled => '到「设置 > Apple 智能与 Siri」开启';

  @override
  String get appleModelNotReady => '模型下载中';

  @override
  String get appleUnavailable => '需要 iOS 26 以上且支持 Apple 智能';

  @override
  String get azurePortal => 'Azure 门户';

  @override
  String get copilotWarning =>
      'Beta API，不支持正式产品。需要公司或学校账号、Microsoft 365 Copilot 许可与 Entra 应用注册。';

  @override
  String get googleFreeWarning => '免费额度的内容可能被 Google 用于改进产品并经人工审阅。请使用已启用计费的密钥。';

  @override
  String get cloudAi => '云端 AI';

  @override
  String sendToProvider({required String provider}) {
    return '发送到 $provider？';
  }

  @override
  String cloudConsentMessage({required String me}) {
    return '只发送输入的文字或从照片识别出的文字，不发送照片与其他记录。可在「$me > AI」撤回。';
  }

  @override
  String get agreeAndSend => '同意并发送';

  @override
  String sendPhotoToProvider({required String provider}) {
    return '发送食物照片到 $provider？';
  }

  @override
  String photoConsentMessage({required String me}) {
    return '只发送这张照片与补充说明，先移除照片里的位置与拍摄信息，不保存照片。可在「$me > AI」撤回。';
  }

  @override
  String aiFailureUnavailable({required String me}) {
    return 'AI 功能尚未设置，到「$me > AI」设置。';
  }

  @override
  String get aiFailureNeedsConsent => '未同意发送文字。';

  @override
  String aiFailureAuthentication({required String me}) {
    return '密钥无效或没有权限，到「$me > AI」重新设置。';
  }

  @override
  String get aiFailureRateLimited => '请求太频繁或额度用完，稍后再试。';

  @override
  String get aiFailureNetwork => '连不上网络，稍后再试。';

  @override
  String get aiFailureProvider => 'AI 服务出了问题，稍后再试。';

  @override
  String get aiFailureUnreadable => 'AI 的回复无法解读，再试一次。';

  @override
  String get aiFailureNeedsPhotoConsent => '未同意发送照片。';

  @override
  String aiFailurePhotoUnsupported({required String me}) {
    return '目前的 AI 不能读照片，到「$me > AI」换一个。';
  }

  @override
  String get aiFailureNoFood => '照片里看不到食物或饮料，换一张再试。';

  @override
  String get aiFailurePhotoFormat => '这张照片的格式无法读取，换一张再试。';

  @override
  String get prior4Weeks => '前 4 周';

  @override
  String againstBaseline({required String baseline}) {
    return '比$baseline';
  }

  @override
  String againstRecentBaseline({
    required String recent,
    required String baseline,
  }) {
    return '$recent比$baseline';
  }

  @override
  String changeMore({required String against, required String amount}) {
    return '$against多 $amount';
  }

  @override
  String changeLess({required String against, required String amount}) {
    return '$against少 $amount';
  }

  @override
  String sleepLoadMore({required String percent}) {
    return '前一晚睡得较久的训练，训练量平均多 $percent。';
  }

  @override
  String sleepLoadLess({required String percent}) {
    return '前一晚睡得较久的训练，训练量平均少 $percent。';
  }

  @override
  String workoutsCount({required int count}) {
    return '$count 次训练';
  }

  @override
  String sleepSplitAt({required String time}) {
    return '以 $time 区分睡得较久或较少';
  }

  @override
  String get againstSameWorkout => '与同一训练的平均相比';

  @override
  String weightChange4Weeks({required String change}) {
    return '4 周 $change kg';
  }

  @override
  String baselineTimes({required String baseline, required String count}) {
    return '$baseline $count 次';
  }

  @override
  String completeDays({required int complete, required int tracked}) {
    return '完整 $complete/$tracked 天';
  }

  @override
  String perDaySteps({required String steps}) {
    return '每天 $steps 步';
  }

  @override
  String get weightSteady => '体重在这段期间大致持平，没有明显变化。';

  @override
  String weightFalling({required String kg}) {
    return '体重以每周 $kg kg 的速度下降。';
  }

  @override
  String weightRising({required String kg}) {
    return '体重以每周 $kg kg 的速度上升。';
  }

  @override
  String basedOnWeights({required int count}) {
    return '依据 $count 条体重记录';
  }

  @override
  String trainingGoalMet({required int count, required int goal}) {
    return '这是本周第 $count 次训练，达成每周 $goal 次的目标。';
  }

  @override
  String trainingGoalShort({
    required int count,
    required int goal,
    required int left,
  }) {
    return '本周已完成 $count 次训练，距离每周 $goal 次还差 $left 次。';
  }

  @override
  String get basedOnThisWeek => '依据本周训练记录';

  @override
  String weeklyGoalTimes({required int goal}) {
    return '每周目标 $goal 次';
  }

  @override
  String volumeDropMaxHolding({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise的每周组数从 $first 组掉到 $last 组，估计最大重量没有跟着掉。';
  }

  @override
  String volumeDropMaxFalling({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise的每周组数从 $first 组掉到 $last 组，估计最大重量也跟着下降。';
  }

  @override
  String basedOnWorkouts({required int count}) {
    return '依据 $count 次训练记录';
  }

  @override
  String get excludesWarmups => '不含热身组';

  @override
  String get dataComplete => '数据完整';

  @override
  String dataIncomplete({required int points, required int days}) {
    return '数据不完整，只有 $points / $days 天有记录';
  }

  @override
  String lastWeeksCount({required int count}) {
    return '近 $count 周';
  }

  @override
  String lastDaysAverage({required int count}) {
    return '近 $count 天平均';
  }

  @override
  String lastDaysCount({required int count}) {
    return '近 $count 天';
  }

  @override
  String progressionDeloadReason({required int count, required int reps}) {
    return '连续 $count 次没做到 $reps 下，先退一阶把次数做满。';
  }

  @override
  String progressionMissedReps({required String sets, required int reps}) {
    return '上次 $sets，未做到 $reps 下，先维持同重量。';
  }

  @override
  String progressionMissedSets({required int done, required int planned}) {
    return '上次只做了 $done 组，先把 $planned 组做满再加重。';
  }

  @override
  String get progressionTooHard => '上次做满了，但那次训练评为太吃力，先维持同重量。';

  @override
  String progressionNearLimit({required String rir}) {
    return '上次做满了，但最后一组已经接近极限（RIR $rir），先维持同重量。';
  }

  @override
  String progressionIncreaseReason({
    required String done,
    required String planned,
    required String reserve,
    required String added,
  }) {
    return '上次 $done 做满了 $planned$reserve，可以加 $added kg。';
  }

  @override
  String progressionReserve({required String rir}) {
    return '，最后一组还留 $rir 下';
  }

  @override
  String atLeastValue({required String value}) {
    return '至少 $value';
  }

  @override
  String get appleHealth => 'Apple 健康';

  @override
  String get healthConnectName => 'Health Connect';

  @override
  String get healthDataGeneric => '健康数据';

  @override
  String get strongWorkoutName => 'Strong 训练';

  @override
  String get afterMerge => '合并后';

  @override
  String get splitAction => '拆开';

  @override
  String get aiDraftAction => 'AI 草稿';

  @override
  String get removePhoto => '移除照片';

  @override
  String get privacyWebSearch => '网络搜索';

  @override
  String get privacyWebSearchValue => 'Anthropic、Google AI Studio 依内容搜索公开的营养资料';

  @override
  String get workoutScheduled => '已安排';

  @override
  String get cancelSchedule => '取消安排';

  @override
  String get cancelWorkoutTitle => '取消这次训练？';

  @override
  String get cancelWorkoutAction => '取消训练';

  @override
  String get keepWorkout => '保留';

  @override
  String get commonView => '查看';

  @override
  String get schemeStraight => '基础';

  @override
  String get schemeStraightHint => '每组同重量';

  @override
  String get schemeAscending => '逐渐加重';

  @override
  String get schemeAscendingHint => '重量逐组增加，次数逐组减少';

  @override
  String get schemeReverse => '大重量开始';

  @override
  String get schemeReverseHint => '第一组最重，之后逐组减重加次数';

  @override
  String get schemeFiveByFive => '5×5 力量';

  @override
  String get schemeFiveByFiveHint => '5 组 5 下同重量';

  @override
  String get schemeTopSet => '顶峰组';

  @override
  String get schemeTopSetHint => '一组最重，其余减重';

  @override
  String get schemeDrop => '降重';

  @override
  String get schemeDropHint => '第一组最重，之后小幅减重';

  @override
  String get mainWeight => '主要重量';

  @override
  String get mainWeightRecent => '近 90 天最高';

  @override
  String get mainWeightEver => '历史最高';

  @override
  String get setCountLabel => '组数';

  @override
  String get repCountLabel => '次数';

  @override
  String get oneSetLess => '少 1 组';

  @override
  String get oneSetMore => '多 1 组';

  @override
  String exerciseRecordsTitle({required String name}) {
    return '$name 记录';
  }

  @override
  String get earlierRecord => '较早的记录';

  @override
  String get laterRecord => '较新的记录';

  @override
  String get workoutTimeTitle => '运动时间';

  @override
  String get restTimeTitle => '休息时间';

  @override
  String get autoRestTitle => '完成一组后自动开始休息';

  @override
  String durationSeconds({required int seconds}) {
    return '$seconds 秒';
  }

  @override
  String sessionScheduledOpen({required String session}) {
    return '$session已安排，回到$session';
  }

  @override
  String get trackingTypeWeightDuration => '重量 + 时间';

  @override
  String repsValue({required int reps}) {
    return '$reps 次';
  }

  @override
  String get totalTime => '总时间';

  @override
  String get totalReps => '总次数';

  @override
  String get totalDistance => '总距离';

  @override
  String exerciseLastFigures({required String set}) {
    return '上次 $set';
  }

  @override
  String mostRepsSet({required String set, required String date}) {
    return '最多 $set · $date';
  }

  @override
  String longestSet({required String set, required String date}) {
    return '最长 $set · $date';
  }

  @override
  String furthestSet({required String set, required String date}) {
    return '最远 $set · $date';
  }

  @override
  String get timeColumn => '时间';

  @override
  String setTime({required String set}) {
    return '$set时间';
  }

  @override
  String setDistance({required String set}) {
    return '$set距离';
  }

  @override
  String setNumberTime({required int number}) {
    return '第 $number 组时间';
  }

  @override
  String setNumberDistance({required int number}) {
    return '第 $number 组距离';
  }

  @override
  String get unitMinutes => '分';

  @override
  String get unitSeconds => '秒';

  @override
  String get setTimerStart => '开始';

  @override
  String get setTimerStartLabel => '开始计时';

  @override
  String get goalReached => '达成';

  @override
  String goalMetNights({required int count}) {
    return '达成 $count 晚';
  }

  @override
  String get statsSection => '统计';

  @override
  String get distributionSection => '分布';

  @override
  String get statHighest => '最高';

  @override
  String get statLowest => '最低';

  @override
  String get statLongest => '最长';

  @override
  String get statShortest => '最短';

  @override
  String get periodChange => '期间变化';

  @override
  String get changePerWeek => '每周变化';

  @override
  String get measurementsCount => '测量次数';

  @override
  String get sleepGoalMetLabel => '达成睡眠目标';

  @override
  String get weeklyGoalMetLabel => '达成每周目标';

  @override
  String get workoutsTotal => '训练次数';

  @override
  String get stepsUnit => '步';

  @override
  String get gistUsual => '和平常差不多';

  @override
  String get gistMore => '比平常多';

  @override
  String get gistLess => '比平常少';

  @override
  String get gistSteady => '持平';

  @override
  String get gistRising => '上升';

  @override
  String get gistFalling => '下降';

  @override
  String get gistNotEnough => '数据不足，暂不比较';

  @override
  String coverageDays({required int count, required int total}) {
    return '$count/$total 天有记录';
  }

  @override
  String perNightChange({required String change}) {
    return '每晚 $change';
  }

  @override
  String perDayChange({required String change}) {
    return '每日 $change';
  }

  @override
  String perWeekChange({required String change}) {
    return '每周 $change';
  }

  @override
  String get halfNightsOver => '半数晚上超过';

  @override
  String get halfDaysOver => '半数日子超过';

  @override
  String nightsOutOf({required int count, required int total}) {
    return '$total 晚中 $count 晚';
  }

  @override
  String weeksOutOf({required int count, required int total}) {
    return '$total 周中 $count 周';
  }

  @override
  String completeOutOf({required int count, required int total}) {
    return '$total 天中 $count 天完整';
  }

  @override
  String get refSectionSummaries => '趋势摘要';

  @override
  String get refUseSummaryNarrative => '趋势页顶端以一句摘要说明整体走向';

  @override
  String get refUseSummaryVerbal => '「比平常多」等字眼一律附数字，并由个人平常范围判定';

  @override
  String get refUseSummaryAbsolute => '比较写成绝对差（每晚 +18 分），不只写百分比';

  @override
  String get refUseSummaryFrequencies => '达成次数写成「7 晚中 5 晚」而非百分比';

  @override
  String get refUseSummaryIntegers => '摘要数字取整，不显示多余小数';

  @override
  String get refUseSummaryReference => '比较基准固定为个人平常范围与前 12 周';

  @override
  String get sleepRegularityIndexLabel => '睡眠规律指数';

  @override
  String get refSectionSleepRegularity => '睡眠规律';

  @override
  String get refUseSleepRegularityIndex => '睡眠规律指数的定义：相邻两天同一时刻睡着或醒着的一致程度';

  @override
  String get refUseSocialJetlag => '社交时差：周末与平日的睡眠中点差';

  @override
  String get stepGoal => '步数目标';

  @override
  String get stepGoalMetLabel => '达成步数目标';

  @override
  String daysOutOf({required int count, required int total}) {
    return '$total 天中 $count 天';
  }

  @override
  String get refSectionSteps => '步数';

  @override
  String get refUseStepGoalChosen => '步数目标由用户自选，不预设、不自动调整';

  @override
  String get refUseStepGoalSet => '设定步数目标与步数增加有关';

  @override
  String get sleepRegularitySection => '作息规律';

  @override
  String priorDays({required int count}) {
    return '前 $count 天';
  }

  @override
  String weekendMidsleepLater({required String time}) {
    return '周末睡眠中点晚 $time';
  }

  @override
  String weekendMidsleepEarlier({required String time}) {
    return '周末睡眠中点早 $time';
  }

  @override
  String get weekendMidsleepSame => '周末与平日睡眠中点相同';

  @override
  String regularityNeeds({required int count}) {
    return '需要近 28 天有 14 晚记下入睡与起床时间（目前 $count 晚）';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');
}
