// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appLanguage => '日本語';

  @override
  String get meLanguageRow => '言語';

  @override
  String get meSettingsOpenFailed => '設定を開けません';

  @override
  String get commonUndo => '元に戻す';

  @override
  String get commonSearch => '検索';

  @override
  String get commonCloseSearch => '検索を閉じる';

  @override
  String get commonBack => '戻る';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get insightCardTitle => '注目ポイント';

  @override
  String get monthPickerPreviousYear => '前の年';

  @override
  String get monthPickerNextYear => '次の年';

  @override
  String get monthPickerClose => '月の選択を閉じる';

  @override
  String get monthPickerYear => '年';

  @override
  String get monthPickerMonth => '月';

  @override
  String dayStripHasRecords({required String date}) {
    return '$date、記録あり';
  }

  @override
  String get moduleNutrition => '食事';

  @override
  String get moduleNutritionDescription => '食事、料理、材料、栄養';

  @override
  String get moduleWaterDescription => '飲んだ水の量と時刻';

  @override
  String get moduleWeight => '体重';

  @override
  String get moduleWeightDescription => '体重と周囲径';

  @override
  String get moduleTraining => 'トレーニング';

  @override
  String get moduleTrainingDescription => '種目、ルーティン、トレーニング記録';

  @override
  String get moduleActivity => 'アクティビティ';

  @override
  String get moduleActivityDescription => 'ランニング、ウォーキング、サイクリング、球技、ヨガ';

  @override
  String get moduleSleep => '睡眠';

  @override
  String get moduleSleepDescription => '睡眠時間と質';

  @override
  String get moduleWellness => '気分・活力・症状';

  @override
  String get moduleWellnessDescription => '一日の調子の記録';

  @override
  String get moduleNotes => 'メモ';

  @override
  String get moduleNotesDescription => '日付や記録にひも付け';

  @override
  String get sourceManual => '手入力';

  @override
  String get sourceDemo => 'デモデータ';

  @override
  String get sourceImport => 'インポート';

  @override
  String get sourceAiDraft => 'AI 下書き（確認済み）';

  @override
  String get sourceCatalogue => '内蔵カタログ';

  @override
  String get sourceUnknown => '不明';

  @override
  String get sourceAppleHealth => 'Apple ヘルスケア';

  @override
  String get modulesTitle => 'モジュール';

  @override
  String get modulesPickSeveral => '複数選択可';

  @override
  String get commonDone => '完了';

  @override
  String get commonContinue => '続ける';

  @override
  String get journalSourceRow => 'ソース';

  @override
  String get sessionWorkout => 'トレーニング';

  @override
  String sessionEndTitle({required String session}) {
    return '$sessionを終了しますか？';
  }

  @override
  String get sessionEndWorkoutMessage =>
      '完了したセットは記録に保存されます。破棄するとトレーニングとして残りません。';

  @override
  String get sessionEndActivityMessage => '終了するとアクティビティとして保存されます。破棄すると何も残りません。';

  @override
  String get sessionFinishAndSave => '終了して保存';

  @override
  String get sessionDiscardWorkout => 'このトレーニングを破棄';

  @override
  String get sessionDiscardActivity => 'このアクティビティを破棄';

  @override
  String sessionKeepGoing({required String session}) {
    return '$sessionを続ける';
  }

  @override
  String sessionDiscarded({required String session}) {
    return '$sessionを破棄しました';
  }

  @override
  String sessionResume({required String session}) {
    return '$sessionを再開';
  }

  @override
  String sessionPause({required String session}) {
    return '$sessionを一時停止';
  }

  @override
  String sessionEnd({required String session}) {
    return '$sessionを終了';
  }

  @override
  String sessionPausedOpen({required String session}) {
    return '$session一時停止中、$sessionに戻る';
  }

  @override
  String sessionRunningOpen({required String session}) {
    return '$session中、$sessionに戻る';
  }

  @override
  String get sessionPausedStatus => '一時停止中';

  @override
  String sessionRunningStatus({required String session}) {
    return '$session中';
  }

  @override
  String get dockAddEntry => '記録を追加';

  @override
  String addEntryToDay({required String date}) {
    return '$dateに記録を追加';
  }

  @override
  String get tabToday => '今日';

  @override
  String get tabLog => '記録';

  @override
  String get tabTrends => 'トレンド';

  @override
  String get tabMe => 'マイページ';

  @override
  String get detailNothingSelected => '未選択';

  @override
  String get detailNoEntrySelected => '記録が未選択';

  @override
  String get recordWater => '水';

  @override
  String get recordMeasurements => '周囲径';

  @override
  String get recordBodyComposition => '体組成';

  @override
  String waterLogged({required int millilitres}) {
    return '水 $millilitres mL を記録しました';
  }

  @override
  String get quickLogClose => '記録の追加を閉じる';

  @override
  String get bedtimeReminderTitle => 'そろそろ就寝';

  @override
  String bedtimeReminderBody({required String bedtime, required String wake}) {
    return '$bedtimeに就寝、$wakeに起床';
  }

  @override
  String get restResting => '休憩中';

  @override
  String get restEnded => '休憩終了';

  @override
  String restNextSet({required String exercise}) {
    return '次のセット · $exercise';
  }

  @override
  String setsProgress({required int done, required int total}) {
    return '$done / $total セット';
  }

  @override
  String get trackingTypeWeightReps => '重量 + 回数';

  @override
  String get trackingTypeReps => '回数';

  @override
  String get trackingTypeDuration => '時間';

  @override
  String get trackingTypeDistance => '距離';

  @override
  String get exerciseSourceBuiltIn => '内蔵';

  @override
  String get exerciseSourceCustom => 'カスタム';

  @override
  String get exerciseSourceImported => 'インポート';

  @override
  String get bodyRegionChest => '胸';

  @override
  String get bodyRegionShoulders => '肩';

  @override
  String get bodyRegionBack => '背中';

  @override
  String get bodyRegionArms => '腕';

  @override
  String get bodyRegionCore => '体幹';

  @override
  String get bodyRegionLegs => '脚・お尻';

  @override
  String get muscleChest => '胸';

  @override
  String get muscleFrontDelts => '三角筋前部';

  @override
  String get muscleSideDelts => '三角筋中部';

  @override
  String get muscleRearDelts => '三角筋後部';

  @override
  String get muscleBiceps => '上腕二頭筋';

  @override
  String get muscleTriceps => '上腕三頭筋';

  @override
  String get muscleForearms => '前腕';

  @override
  String get muscleTraps => '僧帽筋';

  @override
  String get muscleLats => '広背筋';

  @override
  String get muscleUpperBack => '背中上部';

  @override
  String get muscleSpinalErectors => '脊柱起立筋';

  @override
  String get muscleAbs => '腹直筋';

  @override
  String get muscleObliques => '腹斜筋';

  @override
  String get muscleGlutes => 'お尻';

  @override
  String get muscleQuads => '大腿四頭筋';

  @override
  String get muscleHamstrings => 'ハムストリング';

  @override
  String get muscleAdductors => '内転筋';

  @override
  String get muscleAbductors => '外転筋';

  @override
  String get muscleCalves => 'ふくらはぎ';

  @override
  String get muscleBack => '背中';

  @override
  String get muscleShoulders => '肩';

  @override
  String get muscleArms => '腕';

  @override
  String get muscleCore => '体幹';

  @override
  String get equipmentBarbell => 'バーベル';

  @override
  String get equipmentDumbbell => 'ダンベル';

  @override
  String get equipmentCable => 'ケーブル';

  @override
  String get equipmentMachine => 'マシン';

  @override
  String get equipmentSmithMachine => 'スミスマシン';

  @override
  String get equipmentKettlebell => 'ケトルベル';

  @override
  String get equipmentEzBar => 'EZバー';

  @override
  String get equipmentTrapBar => 'トラップバー';

  @override
  String get equipmentLandmine => 'ランドマイン';

  @override
  String get equipmentPlate => 'プレート';

  @override
  String get equipmentBand => 'チューブ';

  @override
  String get equipmentBodyweight => '自重';

  @override
  String get equipmentCardio => '有酸素マシン';

  @override
  String get equipmentOther => 'その他';

  @override
  String get movementPatternSquat => 'スクワット';

  @override
  String get movementPatternHinge => 'ヒンジ';

  @override
  String get movementPatternLunge => 'ランジ・片脚';

  @override
  String get movementPatternHorizontalPush => '水平プッシュ';

  @override
  String get movementPatternHorizontalPull => '水平プル';

  @override
  String get movementPatternVerticalPush => '垂直プッシュ';

  @override
  String get movementPatternVerticalPull => '垂直プル';

  @override
  String get movementPatternIsolation => '単関節';

  @override
  String get movementPatternCore => '体幹';

  @override
  String get movementPatternCarry => 'キャリー';

  @override
  String get movementPatternConditioning => 'コンディショニング';

  @override
  String get movementPatternUnilateral => '片側';

  @override
  String get lateralityBilateral => '両側';

  @override
  String get lateralityUnilateral => '片側';

  @override
  String get lateralityAlternating => '左右交互';

  @override
  String get setTypeWorking => '本番セット';

  @override
  String get setTypeWarmup => 'ウォームアップセット';

  @override
  String get setTypeDrop => 'ドロップセット';

  @override
  String get setTypeFailure => '限界セット';

  @override
  String get workloadTooLight => '軽すぎ';

  @override
  String get workloadRight => 'ちょうどいい';

  @override
  String get workloadTooHard => 'きつすぎ';

  @override
  String get setKindWorking => '本番';

  @override
  String get setKindWarmup => 'ウォームアップ';

  @override
  String get setKindDrop => 'ドロップ';

  @override
  String get setKindFailure => '限界';

  @override
  String substitutionSamePattern({required String pattern}) {
    return '同じ$patternパターン';
  }

  @override
  String substitutionSameMuscles({required String muscles}) {
    return '同じく$musclesを鍛える';
  }

  @override
  String substitutionEquipmentAvailable({required String equipment}) {
    return '$equipmentあり';
  }

  @override
  String substitutionTrackingChanges({required String tracking}) {
    return '記録方法が$trackingに変わる';
  }

  @override
  String substitutionEquipmentChanges({required String equipment}) {
    return '$equipmentに変わるため重量を設定し直す';
  }

  @override
  String get substitutionOneSide => '片側種目のため回数を設定し直す';

  @override
  String get routineUntitled => '新しいルーティン';

  @override
  String get workoutFreeName => 'フリートレーニング';

  @override
  String setOrdinal({required int number}) {
    return '$numberセット目';
  }

  @override
  String muscleSetCount({required String muscle, required int sets}) {
    return '$muscle $setsセット';
  }

  @override
  String get valueTypeDeclared => '表示値';

  @override
  String get valueTypeMax => '最大値';

  @override
  String get valueTypeEstimate => '推定値';

  @override
  String get mealTypeBreakfast => '朝食';

  @override
  String get mealTypeLunch => '昼食';

  @override
  String get mealTypeDinner => '夕食';

  @override
  String get mealTypeSnack => '間食';

  @override
  String get consumptionKindFood => '食べ物';

  @override
  String get consumptionKindBeverage => '飲み物';

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
  String get servingUnitTael => '台湾両';

  @override
  String get servingUnitCatty => '台湾斤';

  @override
  String get servingUnitMillilitre => 'ml';

  @override
  String get servingUnitLitre => 'L';

  @override
  String get servingUnitServing => '人前';

  @override
  String get allergenCrustacean => '甲殻類';

  @override
  String get allergenMango => 'マンゴー';

  @override
  String get allergenPeanut => '落花生';

  @override
  String get allergenMilk => '乳';

  @override
  String get allergenEgg => '卵';

  @override
  String get allergenTreeNut => '木の実';

  @override
  String get allergenSesame => 'ごま';

  @override
  String get allergenGluten => 'グルテン';

  @override
  String get allergenSoy => '大豆';

  @override
  String get allergenFish => '魚';

  @override
  String get allergenSulphite => '亜硫酸塩';

  @override
  String get nutrientSaturatedFat => '飽和脂肪酸';

  @override
  String get nutrientTransFat => 'トランス脂肪酸';

  @override
  String get nutrientSugar => '糖類';

  @override
  String get nutrientSodium => 'ナトリウム';

  @override
  String get nutrientNetCarb => '糖質';

  @override
  String get nutrientSaltEquivalent => '食塩相当量';

  @override
  String get nutrientPolyols => '糖アルコール';

  @override
  String get nutrientAlcohol => 'アルコール';

  @override
  String get nutrientCholesterol => 'コレステロール';

  @override
  String get nutrientCaffeine => 'カフェイン';

  @override
  String get nutrientEssentialAminoAcids => '必須アミノ酸';

  @override
  String get nutrientBcaa => 'BCAA';

  @override
  String get nutrientLeucine => 'ロイシン';

  @override
  String get nutrientIsoleucine => 'イソロイシン';

  @override
  String get nutrientValine => 'バリン';

  @override
  String get nutrientGlutamine => 'グルタミン';

  @override
  String get nutrientCalcium => 'カルシウム';

  @override
  String get nutrientPhosphorus => 'リン';

  @override
  String get nutrientMagnesium => 'マグネシウム';

  @override
  String get nutrientIron => '鉄';

  @override
  String get nutrientZinc => '亜鉛';

  @override
  String get nutrientPotassium => 'カリウム';

  @override
  String get nutrientIodine => 'ヨウ素';

  @override
  String get nutrientSelenium => 'セレン';

  @override
  String get nutrientVitaminA => 'ビタミンA';

  @override
  String get nutrientVitaminD => 'ビタミンD';

  @override
  String get nutrientVitaminE => 'ビタミンE';

  @override
  String get nutrientVitaminK => 'ビタミンK';

  @override
  String get nutrientVitaminC => 'ビタミンC';

  @override
  String get nutrientVitaminB1 => 'ビタミンB1';

  @override
  String get nutrientVitaminB2 => 'ビタミンB2';

  @override
  String get nutrientNiacin => 'ナイアシン';

  @override
  String get nutrientVitaminB6 => 'ビタミンB6';

  @override
  String get nutrientVitaminB12 => 'ビタミンB12';

  @override
  String get nutrientFolate => '葉酸';

  @override
  String get nutrientPantothenicAcid => 'パントテン酸';

  @override
  String get nutrientBiotin => 'ビオチン';

  @override
  String get nutrientMonounsaturatedFat => '一価不飽和脂肪酸';

  @override
  String get nutrientPolyunsaturatedFat => '多価不飽和脂肪酸';

  @override
  String get nutrientCopper => '銅';

  @override
  String get nutrientManganese => 'マンガン';

  @override
  String get nutrientChromium => 'クロム';

  @override
  String get nutrientMolybdenum => 'モリブデン';

  @override
  String get nutrientChloride => '塩素';

  @override
  String get conventionTaiwan => '台湾';

  @override
  String get conventionJapan => '日本';

  @override
  String get conventionUnitedStates => 'アメリカ';

  @override
  String get conventionEuropeanUnion => 'EU';

  @override
  String get conventionAustraliaNewZealand => 'オーストラリア・ニュージーランド';

  @override
  String get conventionKorea => '韓国';

  @override
  String get conventionChina => '中国';

  @override
  String get conventionCanada => 'カナダ';

  @override
  String get macroEnergy => 'エネルギー';

  @override
  String get macroProtein => 'たんぱく質';

  @override
  String get macroCarb => '炭水化物';

  @override
  String get macroFat => '脂質';

  @override
  String get macroFibre => '食物繊維';

  @override
  String foodCupCapacity({required String amount}) {
    return 'カップ容量 $amount';
  }

  @override
  String get foodOfficialData => '公式データ';

  @override
  String foodAdd({required String food}) {
    return '「$food」を追加';
  }

  @override
  String foodLastPortion({required String portion, required String kcal}) {
    return '前回 $portion · $kcal';
  }

  @override
  String foodCupSizes({required int count}) {
    return '$count種類のサイズ';
  }

  @override
  String foodOneServing({required String serving, required String kcal}) {
    return '1人前 $serving · $kcal';
  }

  @override
  String draftEnergyMismatchItem({required String item}) {
    return '$itemのエネルギーがたんぱく質・炭水化物・脂質から計算した値と大きく違います。確認してください。';
  }

  @override
  String get draftEnergyMismatch =>
      'エネルギーがたんぱく質・炭水化物・脂質から計算した値と大きく違います。これらの欄を確認してください。';

  @override
  String get draftColumnMismatch =>
      '1食分と100あたりのエネルギーが分量から換算した値と合いません。別の欄の数字かもしれません。確認してください。';

  @override
  String get draftCarbWithoutFibre =>
      'この表示の炭水化物は食物繊維を含まず、食物繊維の記載もないため、炭水化物は空欄にしています。';

  @override
  String get activityGroupWalkRun => 'ウォーキング・ランニング';

  @override
  String get activityGroupCycling => 'サイクリング';

  @override
  String get activityGroupWater => '水上スポーツ';

  @override
  String get activityGroupBall => '球技';

  @override
  String get activityGroupIndoor => '室内マシン';

  @override
  String get activityGroupMindBody => 'マインド&ボディ';

  @override
  String get activityGroupOther => 'その他';

  @override
  String get activityMetricGroupMovement => '日常の活動';

  @override
  String get activityMetricGroupHeart => '心臓・心肺';

  @override
  String get activityMetricGroupVitals => 'バイタル';

  @override
  String get activityMetricMindfulTime => 'マインドフルネスの時間';

  @override
  String get activityMetricGroupMindfulness => 'マインドフルネス';

  @override
  String get activityMetricBodyTemperature => '体温';

  @override
  String get activityMetricBloodPressureSystolic => '収縮期血圧';

  @override
  String get activityMetricBloodPressureDiastolic => '拡張期血圧';

  @override
  String get vitalBloodPressure => '血圧';

  @override
  String get activityMetricRespiratoryRate => '呼吸数';

  @override
  String get activityMetricOxygenSaturation => '血中酸素';

  @override
  String get activityMetricUnitRespiratoryRate => '回/分';

  @override
  String get activityMetricGroupMobility => '移動能力';

  @override
  String get activityMetricGroupRunning => 'ランニング';

  @override
  String get activityMetricGroupCycling => 'サイクリング';

  @override
  String get activityMetricGroupSwimmingWheelchair => '水泳・車椅子';

  @override
  String get activityMetricSteps => '歩数';

  @override
  String get activityMetricDistance => '距離';

  @override
  String get activityMetricActiveEnergy => 'アクティブエネルギー';

  @override
  String get activityMetricBasalEnergy => '安静時消費エネルギー';

  @override
  String get activityMetricExerciseTime => 'エクササイズ時間';

  @override
  String get activityMetricStandTime => 'スタンド時間';

  @override
  String get activityMetricMoveTime => 'ムーブ時間';

  @override
  String get activityMetricFloors => '上った階数';

  @override
  String get activityMetricElevationGained => '獲得標高';

  @override
  String get activityMetricTimeInDaylight => '日光を浴びた時間';

  @override
  String get activityMetricHeartRate => '平均心拍数';

  @override
  String get activityMetricRestingHeartRate => '安静時心拍数';

  @override
  String get activityMetricWalkingHeartRate => '歩行時平均心拍数';

  @override
  String get activityMetricHrvSdnn => '心拍変動（SDNN）';

  @override
  String get activityMetricHrvRmssd => '心拍変動（RMSSD）';

  @override
  String get activityMetricHeartRateRecovery => '1分間心拍数回復';

  @override
  String get activityMetricVo2Max => 'VO₂max';

  @override
  String get activityMetricPhysicalEffort => '身体的負荷';

  @override
  String get activityMetricWalkingSpeed => '歩行速度';

  @override
  String get activityMetricWalkingStepLength => '歩幅';

  @override
  String get activityMetricWalkingAsymmetry => '歩行非対称性';

  @override
  String get activityMetricDoubleSupport => '両脚支持時間';

  @override
  String get activityMetricWalkingSteadiness => '歩行安定性';

  @override
  String get activityMetricStairAscentSpeed => '階段の上り速度';

  @override
  String get activityMetricStairDescentSpeed => '階段の下り速度';

  @override
  String get activityMetricSixMinuteWalk => '6分間歩行距離';

  @override
  String get activityMetricRunningSpeed => 'ランニング速度';

  @override
  String get activityMetricRunningPower => 'ランニングパワー';

  @override
  String get activityMetricRunningStrideLength => 'ランニングストライド長';

  @override
  String get activityMetricGroundContactTime => '接地時間';

  @override
  String get activityMetricVerticalOscillation => '上下動';

  @override
  String get activityMetricCyclingDistance => 'サイクリング距離';

  @override
  String get activityMetricCyclingSpeed => 'サイクリング速度';

  @override
  String get activityMetricCyclingPower => 'サイクリングパワー';

  @override
  String get activityMetricCyclingCadence => 'ケイデンス';

  @override
  String get activityMetricFunctionalThresholdPower => '機能的作業閾値パワー';

  @override
  String get activityMetricSwimmingDistance => '水泳距離';

  @override
  String get activityMetricSwimmingStrokes => 'ストローク数';

  @override
  String get activityMetricWheelchairPushes => '車椅子のプッシュ回数';

  @override
  String get activityMetricWheelchairDistance => '車椅子の距離';

  @override
  String get activityMetricUnitSteps => '歩';

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
  String get activityMetricUnitFloors => '階';

  @override
  String get activityMetricUnitElevationGained => 'm';

  @override
  String get activityMetricUnitTimeInDaylight => '分';

  @override
  String get activityMetricUnitHeartRate => '拍/分';

  @override
  String get activityMetricUnitRestingHeartRate => '拍/分';

  @override
  String get activityMetricUnitWalkingHeartRate => '拍/分';

  @override
  String get activityMetricUnitHrvSdnn => 'ms';

  @override
  String get activityMetricUnitHrvRmssd => 'ms';

  @override
  String get activityMetricUnitHeartRateRecovery => '拍/分';

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
  String get activityMetricUnitSwimmingStrokes => '回';

  @override
  String get activityMetricUnitWheelchairPushes => '回';

  @override
  String get activityMetricUnitWheelchairDistance => 'km';

  @override
  String get activityTypeRunning => 'ランニング';

  @override
  String get activityTypeWalking => 'ウォーキング';

  @override
  String get activityTypeHiking => 'ハイキング';

  @override
  String get activityTypeCycling => 'サイクリング';

  @override
  String get activityTypeSwimming => '水泳';

  @override
  String get activityTypeRowing => 'ローイングマシン';

  @override
  String get activityTypeElliptical => 'エリプティカル';

  @override
  String get activityTypeStairs => '階段';

  @override
  String get activityTypeBasketball => 'バスケットボール';

  @override
  String get activityTypeBadminton => 'バドミントン';

  @override
  String get activityTypeYoga => 'ヨガ';

  @override
  String get activityTypeOther => 'その他の運動';

  @override
  String hoursMinutes({required int hours, required int minutes}) {
    return '$hours時間$minutes分';
  }

  @override
  String durationMinutes({required int minutes}) {
    return '$minutes分';
  }

  @override
  String get activitySeriesHeartRate => '心拍数';

  @override
  String get activitySeriesSpeed => '速度';

  @override
  String get activitySeriesPower => 'パワー';

  @override
  String get activitySeriesCadence => 'ケイデンス';

  @override
  String get activitySeriesStrideLength => 'ストライド長';

  @override
  String get activitySeriesGroundContactTime => '接地時間';

  @override
  String get activitySeriesVerticalOscillation => '上下動';

  @override
  String get activitySeriesAltitude => '高度';

  @override
  String get activitySeriesUnitHeartRate => '拍/分';

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
  String get unitBpm => '拍/分';

  @override
  String activityDeleted({required String activity}) {
    return '$activityを削除しました';
  }

  @override
  String get recordDeletedNotice => 'この記録は削除されました。';

  @override
  String get activityRouteMap => 'ルートマップ';

  @override
  String get healthDetailUnreadable => 'ヘルスケアの詳細データを読み込めません。';

  @override
  String get activityDetailsSection => '詳細';

  @override
  String get activitySplitsSection => 'スプリット · 1 kmごと';

  @override
  String get activityRecoverySection => '運動後の心拍数';

  @override
  String get activityPace => 'ペース';

  @override
  String get notesSection => 'メモ';

  @override
  String get manageSection => '管理';

  @override
  String get activityEdit => '内容を編集';

  @override
  String get activityEditDetail => '種類・時刻・時間';

  @override
  String get recordDelete => 'この記録を削除';

  @override
  String get deleteMeasurement => 'この測定を削除';

  @override
  String get activityActiveTime => '運動時間';

  @override
  String get activityDistance => '距離';

  @override
  String get activityTotalEnergy => '総消費エネルギー';

  @override
  String get activityClimb => '獲得標高';

  @override
  String get activityAveragePace => '平均ペース';

  @override
  String get activityAverageSpeed => '平均速度';

  @override
  String get activityMaxHeartRate => '最大心拍数';

  @override
  String get activityAveragePower => '平均パワー';

  @override
  String get activityAverageCadence => '平均ケイデンス';

  @override
  String get activityEffort => 'きつさ';

  @override
  String get activityEffortEstimated => 'きつさ（推定）';

  @override
  String activityIndoor({required String activity}) {
    return '$activity（屋内）';
  }

  @override
  String activityOutdoor({required String activity}) {
    return '$activity（屋外）';
  }

  @override
  String get weatherLabel => '天気';

  @override
  String get humidityLabel => '湿度';

  @override
  String get splitTime => 'タイム';

  @override
  String statAverage({required String value}) {
    return '平均 $value';
  }

  @override
  String heartZone({required int number}) {
    return 'ゾーン$number';
  }

  @override
  String get heartZonesByReserve => '予備心拍数から推定';

  @override
  String get heartZonesByAge => '年齢から最大心拍数を推定';

  @override
  String get heartZonesOwn => 'このアプリのゾーン';

  @override
  String get recoveryAtEnd => '終了時';

  @override
  String recoveryAfter({required int minutes}) {
    return '$minutes分後';
  }

  @override
  String recoveryWindow({required String time}) {
    return '$timeから3分間';
  }

  @override
  String timelineWeight({required String weight}) {
    return '体重 $weight';
  }

  @override
  String sleepQualityScore({required int score}) {
    return '質 $score / 5';
  }

  @override
  String noteLine({required String note}) {
    return 'メモ：$note';
  }

  @override
  String setsCount({required int count}) {
    return '$countセット';
  }

  @override
  String personalRecordLine({
    required String exercise,
    required String weight,
    required int reps,
  }) {
    return '$exercise $weight kg × $reps で自己ベスト';
  }

  @override
  String effortOutOfTen({required int effort}) {
    return 'きつさ $effort / 10';
  }

  @override
  String activitiesCount({required int count}) {
    return '$count件';
  }

  @override
  String itemsCount({required int count}) {
    return '$count品';
  }

  @override
  String mealsCount({required int count}) {
    return '$count食';
  }

  @override
  String get foodLogIncomplete => '記録していない食事あり';

  @override
  String todayWithDate({required String date}) {
    return '今日 · $date';
  }

  @override
  String get routineNeverDone => '未実施';

  @override
  String routineLastDone({required String date}) {
    return '前回 $dateに完了';
  }

  @override
  String optionalField({required String field}) {
    return '$field（任意）';
  }

  @override
  String get workoutBlocksActivity => 'トレーニング中です。終了してからアクティビティを開始してください。';

  @override
  String activityDurationRange({required int min, required int max}) {
    return '時間は$min〜$max分で入力してください。';
  }

  @override
  String activityDistanceRange({required int max}) {
    return '距離は0〜$max kmで入力してください。';
  }

  @override
  String activityClimbRange({required int max}) {
    return '獲得標高は0〜$max mで入力してください。';
  }

  @override
  String activityLogged({required String activity, required int minutes}) {
    return '$activity $minutes分を記録しました';
  }

  @override
  String activityUpdated({required String activity}) {
    return '$activityを更新しました';
  }

  @override
  String get activityRecordTitle => 'アクティビティを記録';

  @override
  String get activityEditTitle => 'アクティビティを編集';

  @override
  String get activityTypeRow => '種類';

  @override
  String get activityStartTimer => '今すぐ計測開始';

  @override
  String get activityStartTimerDetail => '運動しながら計測し、距離ときつさは終了後に入力';

  @override
  String get activityStartTime => '開始時刻';

  @override
  String get activityDurationSection => '時間';

  @override
  String get minutesUnit => '分';

  @override
  String activityEndsAt({required String time}) {
    return '終了 $time';
  }

  @override
  String activityPaceValue({required String pace}) {
    return 'ペース $pace /km';
  }

  @override
  String get effortSection => 'きつさ';

  @override
  String get effortScaleHint => '1はとても楽、10は全力。';

  @override
  String get activityNoteHint => '例：河川敷、風が強い';

  @override
  String get activityPickTitle => 'アクティビティを選択';

  @override
  String get recentlyUsed => '最近使ったもの';

  @override
  String get commonlyUsed => 'よく使う';

  @override
  String get activityAllTypes => 'すべてのアクティビティ';

  @override
  String get activityEnded => 'このアクティビティは終了しました。';

  @override
  String get sessionInProgress => '進行中';

  @override
  String get commonEnd => '終了';

  @override
  String get commonResume => '再開';

  @override
  String get commonPause => '一時停止';

  @override
  String get chartRangeDay => '日';

  @override
  String get chartRangeWeek => '週';

  @override
  String get chartRangeMonth => '月';

  @override
  String get previousDay => '前の日';

  @override
  String get nextDay => '次の日';

  @override
  String get entriesRow => '記録';

  @override
  String get thisDay => 'この日';

  @override
  String get dailyAverage => '1日の平均';

  @override
  String get usualRange => '普段の範囲';

  @override
  String get daysRecorded => '記録日数';

  @override
  String daysCount({required int count}) {
    return '$count日';
  }

  @override
  String weekOf({required String date}) {
    return '$dateからの1週間';
  }

  @override
  String readingsCount({required int count}) {
    return '$count件';
  }

  @override
  String get perDay => '毎日';

  @override
  String get dailyActivityTitle => 'アクティビティ';

  @override
  String get noActivityData => 'アクティビティのデータなし';

  @override
  String get dataSourcesLink => 'データソース';

  @override
  String get noActivityThisDay => 'この日のアクティビティのデータなし';

  @override
  String get heartZonesTitle => '心拍ゾーン';

  @override
  String get needsBirthYear => '生まれ年が必要';

  @override
  String nightsWithinUsual({required int count, required int total}) {
    return '$total晩中$count晩が普段の範囲内';
  }

  @override
  String daysWithinUsual({required int count, required int total}) {
    return '$total日中$count日が普段の範囲内';
  }

  @override
  String daysAllWithinUsual({required int count}) {
    return '$count日すべてが普段の範囲内';
  }

  @override
  String daysRecordedWithinUsual({required int recorded, required int count}) {
    return '$recorded日記録、$count日が普段の範囲内';
  }

  @override
  String usualRangeNeedsDays({required int count}) {
    return '直近28日に14日分の記録が必要（現在$count日）';
  }

  @override
  String nightsAllWithinUsual({required int count}) {
    return '$count晩すべてが普段の範囲内';
  }

  @override
  String nightsRecordedWithinUsual({
    required int recorded,
    required int count,
  }) {
    return '$recorded晩記録、$count晩が普段の範囲内';
  }

  @override
  String usualRangeNeedsNights({required int count}) {
    return '直近28日に14晩分の記録が必要（現在$count晩）';
  }

  @override
  String get outsideUsual => '範囲外';

  @override
  String get targetBedtime => '目標の入眠';

  @override
  String get targetWake => '目標の起床';

  @override
  String get clearTargetSchedule => '目標スケジュールを消去';

  @override
  String get targetSchedule => '目標スケジュール';

  @override
  String get refSectionUsualRange => '普段の範囲';

  @override
  String get refSectionSleepStages => '睡眠段階';

  @override
  String get refUseUsualRangeMinMax => '普段の範囲は直前28日の最小から最大（記録が14日以上）';

  @override
  String get refUseUsualRangeWindow => '個人の基準は当日を除く直前28日の記録から';

  @override
  String get refUseUsualRangeMarks => '範囲外の日は白抜きの丸だけで示し、良し悪しの色は使わない';

  @override
  String get refUseUsualRangeNoAnchor => '範囲外の点に臨床的な目安はないため、印は控えめにして数値を添える';

  @override
  String get refUseStagesEstimate => '睡眠段階は端末の推定なので、同年代ではなく自分の夜と比べる';

  @override
  String get refUseStagesNoTarget => '睡眠構造には合意がないため、段階ごとの目標は設けない';

  @override
  String get refUseStagesNoSummary =>
      '睡眠段階と効率には範囲内の晩数を書かない：否定的な睡眠フィードバックは日中の感じ方に影響する';

  @override
  String get refUseRegularityOutcomes => '規則的な睡眠は低い死亡リスクと関連（観察研究）';

  @override
  String get refUseTargetScheduleAssociation => '目標スケジュール：規則性と健康の関連、時刻は自分で決める';

  @override
  String get refUseTargetScheduleTrial =>
      '目標スケジュール：4週間の固定スケジュールで日中の眠気が低下（小規模試験）';

  @override
  String get refUseMaxHeartRateError =>
      '年齢から推定した最大心拍数は個人で約11拍/分ずれるため、1日のグラフにはゾーンを描かない';

  @override
  String get refUseHeartRateReserve => '心拍予備量は酸素摂取予備量に対応し、ゾーンはそれで決める';

  @override
  String usualRangeValue({required String range}) {
    return '普段 $range';
  }

  @override
  String get vitalsTitle => '心臓とバイタル';

  @override
  String get noVitalsData => '心臓とバイタルのデータなし';

  @override
  String get vitalsOnToday => '今日に表示';

  @override
  String get perHour => '1時間ごと';

  @override
  String hourSpan({required int start, required int end}) {
    return '$start〜$end時';
  }

  @override
  String hourOfDay({required int hour}) {
    return '$hour時';
  }

  @override
  String get measurementSiteWaist => 'ウエスト';

  @override
  String get measurementSiteHips => 'ヒップ';

  @override
  String get measurementSiteChest => '胸囲';

  @override
  String get measurementSiteArm => '二の腕';

  @override
  String get measurementSiteThigh => '太もも';

  @override
  String get measurementSiteCalf => 'ふくらはぎ';

  @override
  String get measurementSiteNeck => '首回り';

  @override
  String get bodyMetricHeight => '身長';

  @override
  String get bodyMetricBodyFat => '体脂肪率';

  @override
  String get bodyMetricSkeletalMuscle => '骨格筋量';

  @override
  String get bodyMetricMuscleMass => '筋肉量';

  @override
  String get bodyMetricLeanMass => '除脂肪体重';

  @override
  String get bodyMetricVisceralFat => '内臓脂肪';

  @override
  String get bodyMetricBodyWater => '体水分率';

  @override
  String get bodyMetricBoneMass => '骨量';

  @override
  String get bodyMetricBasalMetabolicRate => '基礎代謝量';

  @override
  String get sexFemale => '女性';

  @override
  String get sexMale => '男性';

  @override
  String get sleepKindNight => '睡眠';

  @override
  String get sleepKindNap => '仮眠';

  @override
  String get sleepMeasureAsleep => '睡眠時間';

  @override
  String get sleepMeasureInBed => '就床時間';

  @override
  String get sleepStageInBed => 'ベッド';

  @override
  String get sleepStageAwake => '覚醒';

  @override
  String get sleepStageAsleep => '睡眠';

  @override
  String get sleepStageCore => 'コア';

  @override
  String get sleepStageDeep => '深い';

  @override
  String get sleepStageRem => 'レム';

  @override
  String get overnightMeasureHeartRate => '心拍数';

  @override
  String get overnightMeasureRespiratoryRate => '呼吸数';

  @override
  String get overnightMeasureOxygenSaturation => '血中酸素';

  @override
  String get overnightMeasureWristTemperature => '手首の皮膚温';

  @override
  String get overnightMeasureSkinTemperatureChange => '皮膚温の変化';

  @override
  String get overnightMeasureHrvSdnn => '心拍変動（SDNN）';

  @override
  String get overnightMeasureHrvRmssd => '心拍変動（RMSSD）';

  @override
  String get overnightMeasureBreathingDisturbances => '呼吸の乱れ';

  @override
  String get activityLevelSedentary => '座りがち';

  @override
  String get activityLevelLight => '軽い';

  @override
  String get activityLevelModerate => '中程度';

  @override
  String get activityLevelActive => '高い';

  @override
  String get activityLevelVeryActive => '非常に高い';

  @override
  String get weightGoalLose => '減量';

  @override
  String get weightGoalRecomp => 'ボディメイク';

  @override
  String get weightGoalMaintain => '維持';

  @override
  String get weightGoalGain => '増量';

  @override
  String get targetInputWeight => '体重';

  @override
  String get targetInputHeight => '身長';

  @override
  String get targetInputBirthYear => '生年';

  @override
  String get targetInputSex => '性別';

  @override
  String get healthDataSleep => '睡眠';

  @override
  String get healthDataWeight => '体重';

  @override
  String get healthDataWaist => 'ウエスト';

  @override
  String get healthDataBody => '体組成';

  @override
  String get healthDataWorkouts => 'ワークアウト';

  @override
  String get healthDataWater => '水分';

  @override
  String get healthDataOvernight => '夜間のデータ';

  @override
  String get healthDataActivity => 'アクティビティと心肺';

  @override
  String get recordCategoryTraining => 'トレーニング';

  @override
  String get recordCategoryActivity => 'アクティビティ';

  @override
  String get recordCategoryNutrition => '食事';

  @override
  String get recordCategoryBody => 'からだ';

  @override
  String get recordCategoryWellness => '睡眠と体調';

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
  String get aiProviderOpenAiCompatible => 'OpenAI互換エンドポイント';

  @override
  String get wellnessKindEnergy => '活力';

  @override
  String get wellnessKindMood => '気分';

  @override
  String get wellnessKindSymptom => '症状';

  @override
  String get wellnessKindSleep => '睡眠の質';

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
  String get bodyMetricUnitVisceralFat => 'レベル';

  @override
  String get bodyMetricUnitBodyWater => '%';

  @override
  String get bodyMetricUnitBoneMass => 'kg';

  @override
  String get bodyMetricUnitBasalMetabolicRate => 'kcal';

  @override
  String get overnightMeasureUnitHeartRate => '拍/分';

  @override
  String get overnightMeasureUnitRespiratoryRate => '回/分';

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
  String get activityLevelDetailSedentary => 'ほとんど運動しない';

  @override
  String get activityLevelDetailLight => '週1〜3日運動';

  @override
  String get activityLevelDetailModerate => '週3〜5日運動';

  @override
  String get activityLevelDetailActive => '週6〜7日運動';

  @override
  String get activityLevelDetailVeryActive => '肉体労働または1日2回の運動';

  @override
  String get aiOff => 'AI オフ';

  @override
  String get aiDraftGenerate => '下書きを作成';

  @override
  String get aiDrafting => '作成中…';

  @override
  String get aiRewrite => '入力し直す';

  @override
  String deletedItem({required String item}) {
    return '$itemを削除しました';
  }

  @override
  String get recordTitle => '記録';

  @override
  String get commonEdit => '編集';

  @override
  String get bodyScaleEstimate => '体組成計の推定値';

  @override
  String get notRated => '評価なし';

  @override
  String weightSinceLast({required String change, required String date}) {
    return '前回から$change（$date）';
  }

  @override
  String get logFilterAll => 'すべて';

  @override
  String pickMonthCurrent({required String month}) {
    return '月を選択、現在 $month';
  }

  @override
  String get logSearch => '記録を検索';

  @override
  String get backToToday => '今日に戻る';

  @override
  String get showAsCalendar => 'カレンダー表示';

  @override
  String get showAsTimeline => 'タイムライン表示';

  @override
  String get previousMonth => '前の月';

  @override
  String get nextMonth => '次の月';

  @override
  String noEntriesInMonth({required String month}) {
    return '$monthの記録なし';
  }

  @override
  String noEntriesMatching({required String query}) {
    return '「$query」に一致する記録はありません。';
  }

  @override
  String get noEntriesThisDay => 'この日の記録はありません。';

  @override
  String get noEntriesSentence => '記録はありません。';

  @override
  String get noImports => 'インポートした記録はありません。';

  @override
  String get importUndone => '取り消し済み';

  @override
  String productsCount({required int count}) {
    return '$count品目';
  }

  @override
  String catalogueUpdated({required String catalogue, required String date}) {
    return '$catalogue $date更新';
  }

  @override
  String healthReadFailed({required String error}) {
    return '読み込みに失敗しました：$error';
  }

  @override
  String get healthDisconnectKeeps => '接続を解除しても記録は残ります。';

  @override
  String get healthReadNow => '今すぐ読み込む';

  @override
  String get healthDisconnect => '接続を解除';

  @override
  String healthUnavailable({required String source}) {
    return 'このデバイスには$sourceがないか、バージョンが古すぎます。';
  }

  @override
  String get checking => '確認中…';

  @override
  String get healthConnected => '接続済み';

  @override
  String healthConnect({required String source}) {
    return '$sourceに接続';
  }

  @override
  String get healthReading => '読み込み中…';

  @override
  String get healthAllowReading => '読み込みを許可';

  @override
  String get healthAutoReadFailed => '前回の自動読み込みに失敗';

  @override
  String get healthReadFailedState => '読み込み失敗';

  @override
  String get healthReadDone => '読み込み完了';

  @override
  String healthLastRead({required String when}) {
    return '前回の読み込み $when';
  }

  @override
  String healthReads({required String kinds}) {
    return '読み込む項目：$kinds';
  }

  @override
  String get privacyLink => 'プライバシー';

  @override
  String get checkingPermissions => '権限を確認中…';

  @override
  String get healthPermissionsPath =>
      '権限は「設定 > ヘルスケア > データアクセスとデバイス > MISHIRUBE」で変更します。';

  @override
  String get permissionAllowed => '許可済み';

  @override
  String get permissionDenied => '未許可';

  @override
  String get healthAllowOthers => 'ほかの項目を許可';

  @override
  String get healthNotConnected => '接続されていません。';

  @override
  String healthNothingReadDenied({required String kinds}) {
    return 'データを読み込めませんでした。未許可：$kinds。';
  }

  @override
  String get healthNothingRead =>
      'データを読み込めませんでした。システムのヘルスケア設定で許可した項目を確認してください。';

  @override
  String nightsCount({required int count}) {
    return '$count晩';
  }

  @override
  String timesCount({required int count}) {
    return '$count回';
  }

  @override
  String healthUpdatedNights({required int count}) {
    return '$count晩の睡眠を更新';
  }

  @override
  String healthKeptManual({required int count}) {
    return '$count晩は手入力の記録を保持';
  }

  @override
  String healthNotAllowedList({required String kinds}) {
    return '未許可：$kinds';
  }

  @override
  String get noSleepRecords => '睡眠の記録なし';

  @override
  String get logByHand => '手動で記録';

  @override
  String get sleepDebtSection => '睡眠負債';

  @override
  String get napsSection => '仮眠';

  @override
  String get goalSection => '目標';

  @override
  String get sleepStagesSection => '睡眠ステージ';

  @override
  String get notProvided => 'なし';

  @override
  String get fallAsleepTime => '入眠までの時間';

  @override
  String get sleepEfficiency => '睡眠効率';

  @override
  String get awakeAtNight => '夜間の覚醒';

  @override
  String wokeTimes({required int count}) {
    return '$count回目覚め';
  }

  @override
  String get continuitySection => '連続性';

  @override
  String get estimatedFromInBed => 'デバイスの就床時間から推定';

  @override
  String get tonightSection => '今夜';

  @override
  String get suggestedBedtime => '推奨就寝時刻';

  @override
  String wakeAt({required String time}) {
    return '$time起床';
  }

  @override
  String get fromUsualWake => '普段の起床時刻から';

  @override
  String get afterTraining => 'トレーニング後';

  @override
  String get caffeineAfter2pm => '14:00以降のカフェイン';

  @override
  String get mealAfter9pm => '21:00以降の食事';

  @override
  String nightsVersus({required int withCount, required int withoutCount}) {
    return '$withCount晩対$withoutCount晩';
  }

  @override
  String get factorsSection => '影響する要因';

  @override
  String get factorsBasis => '過去90日の平均睡眠時間の差';

  @override
  String get correlationNotCause => '相関であり因果ではない';

  @override
  String sleptLess({required String time}) {
    return '$time少ない';
  }

  @override
  String sleptMore({required String time}) {
    return '$time多い';
  }

  @override
  String get recordMethod => '記録方法';

  @override
  String get withStages => '睡眠ステージあり';

  @override
  String get elevated => '上昇';

  @override
  String get notElevated => '上昇なし';

  @override
  String get sameAsUsual => '過去28晩の平均と同じ';

  @override
  String versusUsual({required String change}) {
    return '過去28晩の平均より$change';
  }

  @override
  String goalMet({required String goal}) {
    return '目標 $goal · 達成';
  }

  @override
  String goalShort({required String goal, required String gap}) {
    return '目標 $goal · $gap不足';
  }

  @override
  String get recordedSleep => '記録した睡眠';

  @override
  String get deviceEstimate => 'デバイス推定';

  @override
  String withNapsTotal({required String time}) {
    return '仮眠を含めて$time';
  }

  @override
  String get noEntriesShort => '記録なし';

  @override
  String get averageTimeAsleep => '平均睡眠時間';

  @override
  String get averageBedtime => '平均就寝時刻';

  @override
  String get averageWake => '平均起床時刻';

  @override
  String plusMinusMinutes({required int minutes}) {
    return '±$minutes分';
  }

  @override
  String get nightsRecorded => '記録した夜の数';

  @override
  String get bedAndWake => '就寝と起床';

  @override
  String averageStage({required String stage}) {
    return '平均$stage';
  }

  @override
  String trendOverNights({required String measure, required int count}) {
    return '$measureの推移、$count晩';
  }

  @override
  String everyMinutes({required int minutes}) {
    return '$minutes分ごと';
  }

  @override
  String stageChartLabel({required String start, required String end}) {
    return '睡眠ステージのグラフ、$start〜$end';
  }

  @override
  String get wholeNight => '一晩全体';

  @override
  String scheduleChartLabel({required int count}) {
    return '就寝と起床の時刻、$count晩';
  }

  @override
  String get sleepGoal => '睡眠の目標';

  @override
  String get notSet => '未設定';

  @override
  String get bedtimeReminder => '就寝リマインダー';

  @override
  String remindsAt({required String time}) {
    return '$timeに通知';
  }

  @override
  String get clearGoal => '目標を消去';

  @override
  String rollingSum({required int count}) {
    return '$count日間の累計';
  }

  @override
  String get nightlyShortfall => '毎晩の不足';

  @override
  String get trendSection => '推移';

  @override
  String get eachDaySection => '日ごと';

  @override
  String get notEnoughEntries => '記録不足';

  @override
  String highestLowest({required String high, required String low}) {
    return '最高 $high · 最低 $low';
  }

  @override
  String get preliminary => '暫定';

  @override
  String countedAt({required String hours}) {
    return '$hoursで計算';
  }

  @override
  String goalValue({required String goal}) {
    return '目標 $goal';
  }

  @override
  String daysWithoutEntries({required int count}) {
    return '$count日は記録なし';
  }

  @override
  String get hoursUnit => '時間';

  @override
  String lastFortnightExtra({required String hours}) {
    return '過去14日 · $hours多く睡眠';
  }

  @override
  String needsLoggedDays({required int minimum, required int recorded}) {
    return '過去14日のうち$minimum日の記録が必要（現在$recorded日）';
  }

  @override
  String lastWeekDebt({required String short, required String extra}) {
    return '過去7日 $short · $extra多く';
  }

  @override
  String hoursValue({required String hours}) {
    return '$hours時間';
  }

  @override
  String shortBy({required String time}) {
    return '$time不足';
  }

  @override
  String overBy({required String time}) {
    return '$time超過';
  }

  @override
  String get photoTextUnavailable => 'このデバイスでは写真の文字を読み取れません。';

  @override
  String get photoNoBodyComposition => '写真から体組成の数値が見つかりません。';

  @override
  String get photoNoGirths => '写真からサイズの数値が見つかりません。';

  @override
  String valueRangeError({
    required String field,
    required String min,
    required String max,
    required String unit,
  }) {
    return '$fieldは$min～$max $unitで入力してください。';
  }

  @override
  String get fillAtLeastOne => '1つ以上入力してください。';

  @override
  String get fillAtLeastOneSite => '1か所以上入力してください。';

  @override
  String loggedValue({required String item, required String value}) {
    return '$item $valueを記録しました';
  }

  @override
  String updatedValue({required String item, required String value}) {
    return '$itemを$valueに更新しました';
  }

  @override
  String loggedItemsCount({required int count}) {
    return '$count件を記録しました';
  }

  @override
  String loggedSitesCount({required int count}) {
    return '$countか所を記録しました';
  }

  @override
  String get scanAction => 'スキャン';

  @override
  String get readingPhoto => '写真を読み取っています…';

  @override
  String get scanBodyComposition => '写真から体組成を読み取る';

  @override
  String get scanGirths => '写真からサイズを読み取る';

  @override
  String lastReadingOn({required String value, required String date}) {
    return '前回 $value · $date';
  }

  @override
  String photoReadCheck({required int count}) {
    return '写真から$count件読み取り、確認してください';
  }

  @override
  String get fillFromScale => '体組成計の表示どおりに入力';

  @override
  String get noteLogged => 'メモを記録しました';

  @override
  String get noteUpdated => 'メモを更新しました';

  @override
  String get noteHint => '例：夜に会食、いつもより多く食べた';

  @override
  String get sleepWakeBeforeBed => '起床時刻は就寝より後にしてください';

  @override
  String get sleepOver24Hours => '1回の睡眠は24時間以内です';

  @override
  String get sleepWakeInFuture => '起床時刻を現在より後にはできません';

  @override
  String get sleepStartLabel => '就寝';

  @override
  String get sleepEndLabel => '起床';

  @override
  String get qualityLabel => '質';

  @override
  String get sleepNoteHint => '例：寝る前にコーヒー、夜中に目が覚めた';

  @override
  String weightRangeError({required String min, required String max}) {
    return '$min～$max kgの値を入力してください。';
  }

  @override
  String weightLogged({required String weight}) {
    return '$weight kgを記録しました';
  }

  @override
  String weightUpdated({required String weight}) {
    return '$weight kgに更新しました';
  }

  @override
  String get symptomSeverity => '不調の程度';

  @override
  String wellnessKindHow({required String kind}) {
    return '$kindはどうですか？';
  }

  @override
  String get wellnessNoteHint => '例：一日中座りっぱなしで腰が張っている';

  @override
  String get bmiBandUnder => '低体重';

  @override
  String get bmiBandHealthy => '普通体重';

  @override
  String get bmiBandOver => '過体重';

  @override
  String get bmiBandObese => '肥満';

  @override
  String yearsCount({required int count}) {
    return '$count年';
  }

  @override
  String get logAction => '記録';

  @override
  String logItem({required String item}) {
    return '$itemを記録';
  }

  @override
  String trendReadingsLabel({required String item, required int count}) {
    return '$itemの推移、$count件';
  }

  @override
  String get bodyScaleCompareSame => '体組成計の推定値、同じ機器で比較';

  @override
  String get noWeightEntries => '体重の記録なし';

  @override
  String get trendWeight => 'トレンド体重';

  @override
  String latestOn({required String date, required String value}) {
    return '最新 $date $value';
  }

  @override
  String weightChartLabel({required int count}) {
    return '体重の推移、$count回';
  }

  @override
  String weightChartIdle({required int count}) {
    return '線は7日平均 · 計量$count回';
  }

  @override
  String trendValue({required String value}) {
    return 'トレンド $value';
  }

  @override
  String get allWeightEntries => 'すべての体重記録';

  @override
  String get buildSection => '体格';

  @override
  String get waistToHipRatio => 'ウエスト・ヒップ比';

  @override
  String get bmiStandardTaiwan => '台湾国民健康署の成人基準';

  @override
  String get fatMass => '体脂肪量';

  @override
  String get waistAdviceTaiwan => '台湾国民健康署の推奨腹囲：男性 < 90 cm、女性 < 80 cm';

  @override
  String get weeklyGoal => '週間目標';

  @override
  String get weeklyGoalPaused => '週間目標を一時停止中';

  @override
  String weeklyGoalButtonLabel({required int active, required int target}) {
    return '今週 $active / $target 運動日、週間目標を表示';
  }

  @override
  String activeDaysPerWeek({required int count}) {
    return '週$count日の運動日';
  }

  @override
  String get adjustWeeklyGoal => '週間目標を調整';

  @override
  String get weeklyGoalPrompt => '週に何日運動するか。';

  @override
  String get setWeeklyGoal => '週間目標を設定';

  @override
  String get streakSection => '連続達成';

  @override
  String get weekGoalMet => '今週の目標を達成';

  @override
  String get weekActivity => '今週の運動';

  @override
  String get notCountedInStreak => '連続達成に含めない';

  @override
  String activeDaysCount({required int count}) {
    return '運動日 $count日';
  }

  @override
  String activeDaysToGo({required int count}) {
    return 'あと$count日';
  }

  @override
  String get streakRestartsThisWeek => '今週から再開';

  @override
  String get noStreakYet => '連続達成の記録なし';

  @override
  String lastStreak({required int previous, required int best}) {
    return '前回の連続達成 $previous週、最高 $best週';
  }

  @override
  String get streakStartsAfterGoal => '1週の目標を達成すると始まります';

  @override
  String streakWeeks({required int count}) {
    return '$count週連続達成';
  }

  @override
  String streakPendingBest({required int best}) {
    return '今週進行中 · 最高 $best週';
  }

  @override
  String streakBest({required int best}) {
    return '最高 $best週';
  }

  @override
  String goalDayLabel({required int day}) {
    return '$day日';
  }

  @override
  String goalDayActive({required int day}) {
    return '$day日、運動あり';
  }

  @override
  String activeDaysFraction({required int active, required int target}) {
    return '$active / $target 運動日';
  }

  @override
  String goalFromThisWeek({required int count}) {
    return '今週から週$count日';
  }

  @override
  String goalFromNextWeek({required int count}) {
    return '来週から週$count日';
  }

  @override
  String get pauseWeeklyGoal => '週間目標を一時停止';

  @override
  String get pauseWeeklyGoalMessage => '一時停止中の週は加算されず、連続達成も途切れません。';

  @override
  String get pauseThisWeek => '今週を一時停止';

  @override
  String get pauseUntilResumed => '手動で再開するまで';

  @override
  String get activeDaysPerWeekQuestion => '週あたりの運動日数';

  @override
  String suggestedDays({required int count}) {
    return '過去4週の平均：週$count日';
  }

  @override
  String get goalStartSection => '開始時期';

  @override
  String get fromNextWeek => '来週から';

  @override
  String get fromNextWeekDetail => '今週は元の目標で計算';

  @override
  String get applyThisWeek => '今週から適用';

  @override
  String get applyThisWeekDetail => '今週を再計算';

  @override
  String get pauseOrTurnOff => '一時停止またはオフ';

  @override
  String get weeklyGoalOffDetail => 'オフにすると目標と連続達成を非表示';

  @override
  String get thisWeekPaused => '今週は一時停止中';

  @override
  String thisWeekActiveDays({required int active, required int target}) {
    return '今週 $active / $target 運動日';
  }

  @override
  String get workoutInProgress => 'トレーニング中';

  @override
  String workoutCurrentSet({
    required String exercise,
    required int set,
    required int done,
  }) {
    return '$exercise · 第$setセット · $doneセット完了';
  }

  @override
  String get backToWorkout => 'トレーニングに戻る';

  @override
  String get thisSession => '今回';

  @override
  String get setsCompleted => '完了セット数';

  @override
  String get exerciseProgress => '種目の進捗';

  @override
  String get personalRecords => '自己ベスト';

  @override
  String get otherEntries => 'その他の記録';

  @override
  String get customiseToday => 'ホームをカスタマイズ';

  @override
  String get showAll => 'すべて表示';

  @override
  String get todayOnlyWithData => '数値があるときだけ表示';

  @override
  String reorderSection({required String section}) {
    return '$sectionの順序を変更';
  }

  @override
  String moreItemsCount({required int count}) {
    return 'ほか $count 項目';
  }

  @override
  String get nextStep => '次のステップ';

  @override
  String get includesEstimates => '推定値を含む';

  @override
  String partialMacros({required String macros}) {
    return '$macrosの数値がない記録があり、含めていません。';
  }

  @override
  String routineCompleted({required String name}) {
    return '$name 完了';
  }

  @override
  String get totalSets => '合計セット数';

  @override
  String get exercisesLabel => '種目';

  @override
  String get todaySectionGlance => '今日の指標';

  @override
  String get todaySectionActivity => '今日のアクティビティ';

  @override
  String get todaySectionWeek => '今週';

  @override
  String get todaySectionRecords => '今日の記録';

  @override
  String get todaySectionInsights => '注目';

  @override
  String weekdayActive({required String weekday}) {
    return '$weekday、トレーニングまたは運動あり';
  }

  @override
  String allCount({required int count}) {
    return 'すべて $count件';
  }

  @override
  String daysFraction({required int active, required int target}) {
    return '$active / $target日';
  }

  @override
  String weightChange7Days({required String change}) {
    return '7日 $change';
  }

  @override
  String trackingChangeRefused({required int count}) {
    return 'この記録方法の記録が$count回あり、変更すると過去の記録の意味が変わります。別の記録方法にするには新しい種目を作成してください。';
  }

  @override
  String get createCustomExercise => 'カスタム種目を作成';

  @override
  String get editExercise => '種目を編集';

  @override
  String exerciseOfSource({required String source}) {
    return '$source種目';
  }

  @override
  String get createAndAdd => '作成して追加';

  @override
  String get nameSection => '名前';

  @override
  String get exerciseNameHint => '例：ダンベルベンチプレス';

  @override
  String get trackingTypeSection => '記録方法';

  @override
  String get trackingTypeLocked => '作成後に互換性のない記録方法へは変更できません。';

  @override
  String get primaryMuscleOrPattern => '主な筋群または動作パターン';

  @override
  String get equipmentSection => '器具';

  @override
  String get equipmentAny => '指定なし';

  @override
  String get possibleDuplicate => 'この種目はすでにある可能性があります';

  @override
  String entriesCount({required int count}) {
    return '記録$count件';
  }

  @override
  String get useThis => 'これを使う';

  @override
  String get duplicateAdvice => '既存の種目を選ぶと、履歴と自己ベストが分かれません。';

  @override
  String exerciseDemoLabel({required String name, required int count}) {
    return '$nameのデモ、$countポーズ';
  }

  @override
  String get playing => '再生中';

  @override
  String get exerciseDemoCredit =>
      '画像：Workout Guide／Everkinetic · CC BY-SA 4.0';

  @override
  String get myAliases => 'マイ別名';

  @override
  String get aliasesHint => '「、」で区切る。例：スクワット、squat';

  @override
  String get aliasesUpdated => '別名を更新しました';

  @override
  String get cannotMergeSelf => '同じ種目には統合できません';

  @override
  String mergeTitle({required String duplicate, required String canonical}) {
    return '「$duplicate」を「$canonical」に統合しますか？';
  }

  @override
  String mergeMessage({required String canonical}) {
    return '過去の記録は「$canonical」に数えられ、この種目は選択肢から消えます。記録の内容は変わりませんが、統合は元に戻せません。';
  }

  @override
  String mergeInto({required String canonical}) {
    return '「$canonical」に統合';
  }

  @override
  String mergedInto({required String canonical}) {
    return '「$canonical」に統合しました';
  }

  @override
  String get addThisExercise => 'この種目を追加';

  @override
  String get otherVariations => '同じ動作の別バリエーション';

  @override
  String get cuesSection => 'ポイント';

  @override
  String get removeFavorite => 'お気に入りから外す';

  @override
  String get addFavorite => 'お気に入りに追加';

  @override
  String get favoriteRemoved => 'お気に入りから外しました';

  @override
  String get favoriteAdded => 'お気に入りに追加しました';

  @override
  String get editExerciseDetail => '名前、器具、部位';

  @override
  String get editMyAliases => 'マイ別名を編集';

  @override
  String builtInNames({required String names}) {
    return '組み込みの名前：$names';
  }

  @override
  String get mergeIntoAnother => '別の種目に統合';

  @override
  String get mergeIntoAnotherDetail => '重複作成した場合、記録を1つの種目にまとめる';

  @override
  String get unhide => '非表示を解除';

  @override
  String get hideExercise => 'この種目を非表示';

  @override
  String unhidden({required String name}) {
    return '「$name」の非表示を解除しました';
  }

  @override
  String hidden({required String name}) {
    return '「$name」を非表示にしました';
  }

  @override
  String get bodyPartLabel => '部位';

  @override
  String get primaryMuscles => '主な筋群';

  @override
  String get secondaryMuscles => '補助筋群';

  @override
  String get movementPatternLabel => '動作パターン';

  @override
  String get lateralityLabel => '左右';

  @override
  String get lastWorkingSet => '前回のメインセット';

  @override
  String get estimatedMax => '推定最大重量';

  @override
  String get sessionsUnit => '回';

  @override
  String get trainingEntries => 'トレーニング記録';

  @override
  String estimatedMaxTrend({required int count}) {
    return '推定最大重量の推移、$count回';
  }

  @override
  String get epleyEstimate => 'Epley推定';

  @override
  String relativeLoadPercent({required int percent}) {
    return '相対負荷 $percent%';
  }

  @override
  String get last90Days => '過去90日';

  @override
  String get filterTitle => '絞り込み';

  @override
  String filtersApplied({required int count}) {
    return '$count件の条件を適用中';
  }

  @override
  String showExercises({required int count}) {
    return '$count種目を表示';
  }

  @override
  String get clearAll => 'すべてクリア';

  @override
  String wholeRegion({required String region}) {
    return '$region全体';
  }

  @override
  String get sourceLabel => 'ソース';

  @override
  String get pickerTabRecent => '最近使用';

  @override
  String get pickerTabFavorites => 'お気に入り';

  @override
  String get pickerTabHomeGym => 'マイジム';

  @override
  String get pickerTabAll => 'すべての種目';

  @override
  String get pickerAddToRoutine => 'ルーティンに追加';

  @override
  String get pickerAddToWorkout => '進行中に追加';

  @override
  String get pickerAddToEntry => '記録に追加';

  @override
  String get pickerBrowse => 'すべての種目を閲覧・検索';

  @override
  String get pickerSingle => '種目を1つ選択';

  @override
  String pickerPurposeFor({required String purpose, required String name}) {
    return '$purpose「$name」';
  }

  @override
  String discardSelectedTitle({required int count}) {
    return '選んだ$count種目を破棄しますか？';
  }

  @override
  String get discardSelected => '選択を破棄';

  @override
  String get keepChoosing => '選択を続ける';

  @override
  String get exerciseLibrary => '種目ライブラリ';

  @override
  String get chooseExercise => '種目を選択';

  @override
  String get addExercises => '種目を追加';

  @override
  String get cantFindCreate => '見つからない？カスタム種目を作成';

  @override
  String get searchExercisesHint => '種目・別名・器具を検索…';

  @override
  String get clearAction => 'クリア';

  @override
  String daysAgo({required int count}) {
    return '$count日前';
  }

  @override
  String aboutItem({required String name}) {
    return '$nameについて';
  }

  @override
  String get selectionOrderHint => '追加順 · タップで削除';

  @override
  String removeNumbered({required int index, required String name}) {
    return '$index番目を削除：$name';
  }

  @override
  String addExercisesCount({required int count}) {
    return '$count種目を追加';
  }

  @override
  String get noMatchingExercises => '該当する種目なし';

  @override
  String equipmentFilterHint({required String equipment}) {
    return '「器具：$equipment」で絞り込み中です。別の器具の種目かもしれません。';
  }

  @override
  String get searchAgainHint => '別の言い方、英語名、別名で試してください。';

  @override
  String get removeEquipmentFilter => '器具の絞り込みを外して再検索';

  @override
  String get similarExercises => '似た種目';

  @override
  String createNamed({required String name}) {
    return '「$name」を作成';
  }

  @override
  String estimatedMaxValue({required int weight}) {
    return '推定最大 $weight kg';
  }

  @override
  String lastSetOn({required String date, required String set}) {
    return '前回 $date $set';
  }

  @override
  String get volumeTitle => 'トレーニング量';

  @override
  String get notEnoughWorkouts => 'トレーニング記録が不足しています。';

  @override
  String volumeOf({required String exercise}) {
    return '$exerciseのトレーニング量';
  }

  @override
  String insightWeeks({required int weeks}) {
    return '注目 · 過去$weeks週';
  }

  @override
  String volumeSteady({required int sets, required String estimate}) {
    return '週あたりのメインセット数は$setsセットで安定、推定最大重量は$estimate。';
  }

  @override
  String get notYetEstimable => 'まだ推定できません';

  @override
  String get basisSection => '根拠';

  @override
  String weeklySetsFrom({required int count}) {
    return '$count回のトレーニング記録から週あたりのメインセット数。';
  }

  @override
  String get dataQualitySection => 'データの質と完全性';

  @override
  String workoutsAllLogged({required int count}) {
    return '$count回すべて記録あり';
  }

  @override
  String get weightRepsManual => '重量と回数は手入力';

  @override
  String get timeRangeSection => '期間';

  @override
  String fullWeeks({required int count}) {
    return '完全な$count週';
  }

  @override
  String get actionsSection => 'できること';

  @override
  String volumeDropped({required int sets}) {
    return '週あたりのセット数が期間の初めより減っています。伸ばし続けるには$setsセット前後に戻しましょう。';
  }

  @override
  String get volumeStable => 'セット数は安定しています。伸ばし続けるには週のセット数か重量を少し増やしましょう。';

  @override
  String adjustRoutineSets({required String routine}) {
    return '「$routine」のセット数を調整';
  }

  @override
  String get notMedicalAdvice => 'トレーニング記録の説明であり、医療上の助言ではありません。';

  @override
  String get viewRawEntries => 'この期間の記録を見る';

  @override
  String get noWorkingSets => 'メインセットの記録なし';

  @override
  String muscleWeeklySets({required String muscle, required int sets}) {
    return '$muscle 週$setsセット';
  }

  @override
  String muscleScaleLabel({required int top}) {
    return '色の段階は0〜$topセット以上';
  }

  @override
  String get setsPerWeek => 'セット / 週';

  @override
  String get muscleMapLabel => '筋群のトレーニング量の人体図、詳細は下に表示';

  @override
  String get musclesTitle => '筋群';

  @override
  String get weeklySetsLast8 => '週あたりのメインセット · 過去8週';

  @override
  String get setsThisWeekUnit => 'セット · 今週';

  @override
  String priorWeeksSets({required int weeks, required String sets}) {
    return '前の$weeks週 $setsセット';
  }

  @override
  String muscleSetsChart({required String muscle, required String sets}) {
    return '$muscleの週セット数、$sets';
  }

  @override
  String heaviestSet({required String set, required String date}) {
    return '最重量 $set · $date';
  }

  @override
  String estimatedMaxOn({required int weight, required String date}) {
    return '推定最大 $weight kg · $date';
  }

  @override
  String get last4Weeks => '過去4週';

  @override
  String monthsCount({required int count}) {
    return '$countか月';
  }

  @override
  String get weeklySetsTitle => '週あたりのセット数';

  @override
  String get last8Weeks => '過去8週';

  @override
  String get weeklyWorkouts => '週あたりのトレーニング';

  @override
  String get weeklyActivities => '週あたりの運動';

  @override
  String get timesThisWeekUnit => '回 · 今週';

  @override
  String get noActivityEntries => '運動の記録なし';

  @override
  String minutesVersusUsual({required int minutes, required int usual}) {
    return '$minutes分 · 通常$usual分';
  }

  @override
  String get trendDomainBody => '身体';

  @override
  String get trendDomainTraining => 'トレーニング';

  @override
  String get trendDomainSleep => '睡眠';

  @override
  String get trendDomainNutrition => '食事';

  @override
  String get trendDomainActivity => 'アクティビティ';

  @override
  String areaTrend({required String area}) {
    return '$areaの推移';
  }

  @override
  String get weekdaySection => '曜日';

  @override
  String get otherAreasSection => '同期間のほかの項目';

  @override
  String get dailyEntries => '日々の記録';

  @override
  String perWeekTimes({required String count}) {
    return '週$count回';
  }

  @override
  String stepsValue({required String steps}) {
    return '$steps歩';
  }

  @override
  String timesValue({required String count}) {
    return '$count回';
  }

  @override
  String weekFrom({required String date}) {
    return '$dateから';
  }

  @override
  String get last13Weeks => '過去13週';

  @override
  String get pastYear => '過去1年';

  @override
  String get prior12Weeks => 'その前の12週';

  @override
  String periodAverage({required String period}) {
    return '$periodの平均';
  }

  @override
  String get weeklyCount => '週あたりの回数';

  @override
  String get weeklyAverage => '週平均';

  @override
  String get weeklyTotal => '週合計';

  @override
  String daysLoggedPerWeek({required String days}) {
    return '過去4週、週平均$days日記録あり';
  }

  @override
  String get scaleWeight => '体重計の値';

  @override
  String get weeklyVolume => '週のトレーニング量';

  @override
  String get restingHeartRate => '安静時心拍数';

  @override
  String get weightAndNutrition => '体重と食事';

  @override
  String get energyBalance => 'エネルギーバランス';

  @override
  String energyNeeds({
    required int window,
    required int foodDays,
    required int weighings,
    required int currentFood,
    required int currentWeighings,
  }) {
    return '過去$window日のうち完全な食事記録$foodDays日と体重$weighings回が必要（現在$currentFood日、$currentWeighings回）';
  }

  @override
  String proteinNeeds({
    required int window,
    required int days,
    required int current,
  }) {
    return '過去$window日のうち完全な食事と体重の記録$days日が必要（現在$current日）';
  }

  @override
  String get muscleSetsTitle => '筋群別セット数';

  @override
  String muscleSetsNeeds({required int count, required int current}) {
    return '過去4週で$count回以上のトレーニングが必要（現在$current回）';
  }

  @override
  String get possibleRelations => '考えられる関連';

  @override
  String get longRunSection => '長期の推移';

  @override
  String actualExpenditure({required String kcal}) {
    return '実際の消費は$kcal kcal/日';
  }

  @override
  String intakeDeficit({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '過去$window日の平均摂取 $intake kcal、1日あたり$balance kcalの不足';
  }

  @override
  String intakeSurplus({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '過去$window日の平均摂取 $intake kcal、1日あたり$balance kcalの余剰';
  }

  @override
  String weightForecast({
    required String change,
    required int weeks,
    required String forecast,
  }) {
    return 'トレンド体重は週$change kg、$weeks週後は$forecast kg';
  }

  @override
  String foodDaysWeighings({required int foodDays, required int weighings}) {
    return '完全な食事記録$foodDays日 · 体重$weighings回';
  }

  @override
  String get intakeUnderlogged => '推定消費が安静時代謝を下回っており、記録した摂取量が実際より少ない可能性があります。';

  @override
  String get estimatedFromEntries => '記録から推定';

  @override
  String weekendEatsMore({required String kcal}) {
    return '週末は1日$kcal kcal多く食べる';
  }

  @override
  String weekendEatsLess({required String kcal}) {
    return '週末は1日$kcal kcal少なく食べる';
  }

  @override
  String weekdayWeekendKcal({
    required String weekday,
    required String weekend,
  }) {
    return '平日 $weekday kcal · 週末 $weekend kcal';
  }

  @override
  String get offsetsAllDeficit => '平日の不足をすべて相殺';

  @override
  String offsetsDeficitShare({required int percent}) {
    return '平日の不足の$percent%を相殺';
  }

  @override
  String weekdaysWeekends({
    required int window,
    required int weekdays,
    required int weekends,
  }) {
    return '過去$window日、平日$weekdays日・週末$weekends日';
  }

  @override
  String proteinMet({required String target}) {
    return 'タンパク質 $target g/kgに到達';
  }

  @override
  String proteinShort({required int grams}) {
    return 'タンパク質が1日$grams g不足';
  }

  @override
  String trainingRestProtein({required String trained, required String rest}) {
    return 'トレーニング日 $trained · 休息日 $rest g/kg';
  }

  @override
  String proteinBasis({
    required String weight,
    required String target,
    required int days,
  }) {
    return '$weight kg、目標 $target g/kgで計算 · 完全な食事記録$days日';
  }

  @override
  String allMusclesEnough({required int target}) {
    return '鍛えた筋群はすべて週$targetセット以上';
  }

  @override
  String muscleOnlySets({required String muscle, required int sets}) {
    return '$muscleは週$setsセットのみ';
  }

  @override
  String underSets({required int target, required String muscles}) {
    return '$targetセット未満：$muscles';
  }

  @override
  String atLeastSets({required int target, required String muscles}) {
    return '$targetセット以上：$muscles';
  }

  @override
  String pairRatio({
    required String first,
    required String second,
    required int firstSets,
    required int secondSets,
  }) {
    return '$first対$second $firstSets : $secondSetsセット';
  }

  @override
  String get musclePush => 'プッシュ';

  @override
  String get musclePull => 'プル';

  @override
  String get muscleSetsBasis => '過去4週の週セット数、主な筋群のみ';

  @override
  String weekendWakeLater({required String time}) {
    return '週末は$time遅く起床';
  }

  @override
  String weekendWakeEarlier({required String time}) {
    return '週末は$time早く起床';
  }

  @override
  String weekdayWeekendWake({
    required String weekday,
    required String weekend,
  }) {
    return '平日 $weekday · 週末 $weekend 起床';
  }

  @override
  String get correlationCaveat => '相関であり因果ではない';

  @override
  String get muscleFigureMale => '男性';

  @override
  String get muscleFigureFemale => '女性';

  @override
  String get workoutDiscarded => 'トレーニングを破棄しました';

  @override
  String get endWorkout => 'トレーニングを終了';

  @override
  String get addExercise => '種目を追加';

  @override
  String get notFilled => '未入力';

  @override
  String get startExercising => '開始';

  @override
  String get finishWorkout => 'トレーニングを完了';

  @override
  String personalRecordSet({required String set}) {
    return '自己ベスト · $set';
  }

  @override
  String get totalShort => '合計';

  @override
  String get totalVolume => '総トレーニング量';

  @override
  String versusLastTime({required String change}) {
    return '前回比 $change';
  }

  @override
  String setsOfTotal({required int done, required int total}) {
    return '$done / $totalセット';
  }

  @override
  String get restTitle => '休憩';

  @override
  String get skipRest => '休憩をスキップ';

  @override
  String get elapsedTime => '時間';

  @override
  String get workoutNotesTitle => 'このトレーニングのメモ';

  @override
  String get workoutNotesHint => '例：寝不足で握力が先に限界';

  @override
  String get addWarmupSets => 'ウォームアップを追加';

  @override
  String get addDropSet => 'ドロップセットを追加';

  @override
  String get addFailureSet => '限界セットを追加';

  @override
  String get replaceExercise => 'この種目を置き換え';

  @override
  String get removeFromWorkout => 'このトレーニングから削除';

  @override
  String get superset => 'スーパーセット';

  @override
  String optionsFor({required String name}) {
    return '$nameのオプション';
  }

  @override
  String volumeValue({required String volume}) {
    return 'トレーニング量 $volume kg';
  }

  @override
  String lastSetShort({required String date, required String set}) {
    return '前回 $date · $set';
  }

  @override
  String get loadPrevious => '読み込む';

  @override
  String get loadPreviousLabel => '過去の記録';

  @override
  String get quickFill => 'クイック入力';

  @override
  String get quickFillLabel => 'セット方式';

  @override
  String get setColumn => 'セット';

  @override
  String get repsColumn => '回';

  @override
  String get removeSet => 'セットを削除';

  @override
  String get addSet => 'セットを追加';

  @override
  String editItem({required String item}) {
    return '$itemを編集';
  }

  @override
  String setWeight({required String set}) {
    return '$setの重量';
  }

  @override
  String setReps({required String set}) {
    return '$setの回数';
  }

  @override
  String setDone({required String set}) {
    return '$set完了';
  }

  @override
  String removedNamed({required String name}) {
    return '「$name」を削除しました';
  }

  @override
  String get routineName => 'ルーティン名';

  @override
  String deleteNamedTitle({required String name}) {
    return '「$name」を削除しますか？';
  }

  @override
  String get routineDeleteKeeps => '完了したトレーニング記録は残ります。';

  @override
  String get deleteRoutine => 'このルーティンを削除';

  @override
  String deletedNamed({required String name}) {
    return '「$name」を削除しました';
  }

  @override
  String get startWorkout => 'トレーニング開始';

  @override
  String get activityBlocksWorkout => '運動中です。トレーニングを始めるには先に運動を終了してください';

  @override
  String get plannedExercises => '予定の種目';

  @override
  String get soreMusclesToday => '今日の筋肉痛';

  @override
  String get recentlyDone => '最近の実施';

  @override
  String setsAndMinutes({required int sets, required int minutes}) {
    return '$setsセット · $minutes分';
  }

  @override
  String get rename => '名前を変更';

  @override
  String get moveUp => '上へ移動';

  @override
  String get moveDown => '下へ移動';

  @override
  String get joinSuperset => '次とスーパーセットにする';

  @override
  String get leaveSuperset => 'スーパーセットを解除';

  @override
  String get removeAction => '削除';

  @override
  String get eachSide => '片側';

  @override
  String get oneSetLessToday => '今日は1セット減';

  @override
  String get loadPreviousFill => '前回の重量と回数で入力';

  @override
  String get myRoutines => 'マイルーティン';

  @override
  String get loadFromHistory => '記録から';

  @override
  String startWorkoutCount({required int count}) {
    return 'トレーニング開始（$count種目）';
  }

  @override
  String get describeInWords => 'ひとこと';

  @override
  String get addExercisesByHand => '手動で種目を追加';

  @override
  String get deleteAction => '削除';

  @override
  String deleteNamed({required String name}) {
    return '「$name」を削除';
  }

  @override
  String get newRoutine => 'ルーティンを追加';

  @override
  String get noWorkouts => 'トレーニング記録なし';

  @override
  String get selectAll => 'すべて選択';

  @override
  String pastSet({
    required int number,
    required String weight,
    required int reps,
  }) {
    return '$numberセット目 $weight kg $reps回';
  }

  @override
  String routineSummary({required int exercises, required int sets}) {
    return '$exercises種目 · $setsセット';
  }

  @override
  String get saveAsRoutine => 'ルーティンとして保存';

  @override
  String get describeWorkoutHint =>
      '例：\nバーベルスクワット 4×8 60kg\nベンチプレス 10回×3セット 40kg\n懸垂 3x8';

  @override
  String get noExercisesRead => '種目が見つかりません';

  @override
  String removeNamed({required String name}) {
    return '「$name」を削除';
  }

  @override
  String get exerciseNotFound => '種目が見つかりません';

  @override
  String setsTimesReps({
    required int sets,
    required int reps,
    required String weight,
  }) {
    return '$setsセット × $reps回 · $weight kg';
  }

  @override
  String setsSameWeight({
    required int sets,
    required String weight,
    required String reps,
  }) {
    return '$setsセット · $weight kg × $reps回';
  }

  @override
  String get editWorkout => 'トレーニングを編集';

  @override
  String get timeSection => '時間';

  @override
  String get durationLabel => '時間';

  @override
  String savedAsRoutine({required String name}) {
    return 'ルーティン「$name」として保存しました';
  }

  @override
  String get keepAsIs => 'そのまま';

  @override
  String get applyAction => '適用';

  @override
  String get progressionIncrease => '増量';

  @override
  String get progressionHold => '維持';

  @override
  String get progressionDeload => '一段階下げる';

  @override
  String get nextTimeSuggestions => '次回の提案';

  @override
  String changedTo({required String name, required String weight}) {
    return '$nameを$weight kgに変更';
  }

  @override
  String decreaseBy({required String amount}) {
    return '$amount減らす';
  }

  @override
  String increaseBy({required String amount}) {
    return '$amount増やす';
  }

  @override
  String get oneRepLess => '1回減らす';

  @override
  String get oneRepMore => '1回増やす';

  @override
  String get notLogged => '未記録';

  @override
  String get deleteThisSet => 'このセットを削除';

  @override
  String get platesImpossible => 'プレートでこの重量は作れません';

  @override
  String get emptyBar => 'バーのみ';

  @override
  String platesPerSide({required String plates}) {
    return '片側 $plates';
  }

  @override
  String setNumberWeight({required int number}) {
    return '$numberセット目の重量';
  }

  @override
  String setNumberReps({required int number}) {
    return '$numberセット目の回数';
  }

  @override
  String get replaceTodayOnly => '今日だけ置き換え';

  @override
  String get replaceTodayOnlyDetail => '今回だけ新しい種目を使う';

  @override
  String get replaceInRoutine => 'ルーティンも更新';

  @override
  String get replaceInRoutineDetail => '今後は新しい種目を使う';

  @override
  String replacedToday({required String name}) {
    return '今日は「$name」を行います';
  }

  @override
  String replacedInRoutine({required String routine, required String name}) {
    return '今日以降の「$routine」は「$name」を行います';
  }

  @override
  String replacePattern({required String pattern}) {
    return '$patternを置き換え';
  }

  @override
  String todaysExerciseNumber({required String routine, required int number}) {
    return '今日の「$routine」· $number種目目';
  }

  @override
  String get replaceAction => '置き換え';

  @override
  String get candidateExercises => '候補の種目';

  @override
  String get chooseFromAll => 'すべての種目から選ぶ';

  @override
  String get applyScope => '適用範囲';

  @override
  String equipmentChangeWarning({required String from, required String to}) {
    return '$fromから$toへの重量換算はできません。セット数、回数、RIRは残し、重量は設定し直してください。';
  }

  @override
  String get exerciseInfo => '種目の説明';

  @override
  String get noFinishedWorkout => '完了したトレーニングなし';

  @override
  String get totalAmount => '総量';

  @override
  String get workloadSection => '今回の負荷';

  @override
  String get trainedAreas => '鍛えた部位';

  @override
  String get muscleSetsLast7 => '過去7日の筋群別セット数';

  @override
  String get editThisEntry => 'この記録を編集';

  @override
  String get volumeSame => '総量は前回と同じ';

  @override
  String volumeChangePercent({required String change}) {
    return '総量は前回比 $change%';
  }

  @override
  String setsAndVolume({required int sets, required String volume}) {
    return '$setsセット · $volume kg';
  }

  @override
  String get qualityConfirmed => '確認済み';

  @override
  String get qualityPortionEstimated => '分量は推定';

  @override
  String get qualityCustomFood => 'カスタム食品';

  @override
  String get qualityQuickLog => 'クイック記録';

  @override
  String get qualityAiEstimate => 'AI推定';

  @override
  String qualityAiEstimateBy({required String source}) {
    return '$source 推定';
  }

  @override
  String get nutritionLabel => '栄養成分表示';

  @override
  String photoItemsCount({required int count}) {
    return '写真に$count品';
  }

  @override
  String get mergeIntoOneFood => '1つの食品にまとめる';

  @override
  String get logEachItem => '1品ずつ記録';

  @override
  String get nutrientNegative => '栄養素は負の値にできません。';

  @override
  String updatedNamed({required String name}) {
    return '「$name」を更新しました';
  }

  @override
  String get editThisMeal => 'この食事を編集';

  @override
  String get newFood => '食品を追加';

  @override
  String get editFood => '食品を編集';

  @override
  String get scanFoodOrLabel => '食べ物か栄養成分表示をスキャン';

  @override
  String get createOnly => '作成のみ';

  @override
  String get createAndLog => '作成して記録';

  @override
  String labelReadBy({required String provider, required String model}) {
    return '数値は$provider（$model）の読み取りです。パッケージと照合してください。';
  }

  @override
  String photoEstimatedBy({required String provider, required String model}) {
    return '数値は$provider（$model）による写真からの推定です。確認してください。';
  }

  @override
  String get foodNameHint => '例：鶏むね肉';

  @override
  String get mealTypeOptional => '食事区分';

  @override
  String get saveToLibrary => 'ライブラリに保存';

  @override
  String get cupSize => 'カップサイズ';

  @override
  String get cupSizeHint => '例：Tall';

  @override
  String get brandLabel => 'ブランド';

  @override
  String get brandHint => '例：ブランド名';

  @override
  String get foodOrDrink => '食べ物か飲み物';

  @override
  String get volumeLabel => '容量';

  @override
  String get portionSection => '分量';

  @override
  String get portionHint => '例：1杯';

  @override
  String get newCupSize => 'カップサイズを追加';

  @override
  String get nutrientsSection => '栄養素';

  @override
  String per100Unit({required String unit}) {
    return '100 $unitあたり';
  }

  @override
  String get perServingTotal => '1食分合計';

  @override
  String get abvLabel => 'アルコール度数';

  @override
  String get deleteThisMeal => 'この食事を削除';

  @override
  String get countryTW => '台湾';

  @override
  String get countryJP => '日本';

  @override
  String get countryUS => 'アメリカ';

  @override
  String get countryEU => 'EU';

  @override
  String get countryAU => 'オーストラリア';

  @override
  String get countryNZ => 'ニュージーランド';

  @override
  String get countryKR => '韓国';

  @override
  String get countryCN => '中国';

  @override
  String get countryCA => 'カナダ';

  @override
  String brandInCountry({required String brand, required String country}) {
    return '$brand（$country）';
  }

  @override
  String get officialData => '公式データ';

  @override
  String updatedOn({required String date}) {
    return '更新 $date';
  }

  @override
  String get foodScopeAll => 'すべて';

  @override
  String get foodScopeRecent => '最近';

  @override
  String get foodScopeStarred => 'お気に入り';

  @override
  String get foodScopeOwn => 'マイ食品';

  @override
  String get foodScopeBrands => 'ブランド';

  @override
  String loggedNamed({required String name}) {
    return '「$name」を記録しました';
  }

  @override
  String get loggedToast => '記録しました';

  @override
  String mealTypeHeaderLabel({required String meal}) {
    return '食事区分、現在は$meal';
  }

  @override
  String get unspecified => '指定なし';

  @override
  String get searchFoodHint => '食品・ブランドを検索';

  @override
  String get takePhotoAction => '写真';

  @override
  String get recentMealsSection => '最近の食事';

  @override
  String get noFoods => '食品なし';

  @override
  String get eatenFoods => '食べた食品';

  @override
  String get noRecentFoods => '最近食べた食品はありません。';

  @override
  String get starredFoods => 'お気に入りの食品';

  @override
  String get starredMeals => 'お気に入りの食事';

  @override
  String get noFavorites => 'お気に入りはありません。';

  @override
  String get noOwnFoods => 'マイ食品なし';

  @override
  String get noBuiltInBrands => '組み込みのチェーンはありません。';

  @override
  String viewFullMenu({required String brand}) {
    return '$brand · メニュー全体を見る';
  }

  @override
  String get noMatchingItems => '該当なし';

  @override
  String get notFoundQuestion => '見つからない？';

  @override
  String get purposeSection => '目的';

  @override
  String mergedCount({required int count}) {
    return '$count件をまとめました';
  }

  @override
  String removedWater({required int millilitres}) {
    return '水 $millilitres mLを削除しました';
  }

  @override
  String get splitDone => '個別の記録に分けました';

  @override
  String get mergeAction => 'まとめる';

  @override
  String get mergeEntries => '記録をまとめる';

  @override
  String get cancelMerge => 'まとめるのをやめる';

  @override
  String get mergeIntoMeal => '1食にまとめる';

  @override
  String mergeCountIntoMeal({required int count}) {
    return '$count件を1食にまとめる';
  }

  @override
  String get setGoal => '目標を設定';

  @override
  String get changeAction => '変更';

  @override
  String get dailyIndicators => '1日の指標';

  @override
  String get mealsSection => '食事';

  @override
  String get mealShare => '割合';

  @override
  String get mealShareHide => '割合を隠す';

  @override
  String get noMealsThisDay => 'この日の食事記録なし';

  @override
  String get waterSection => '水';

  @override
  String removeWaterAt({required String time}) {
    return '$timeの水を削除';
  }

  @override
  String get otherNutrients => 'その他の栄養素';

  @override
  String itemsCountShort({required int count}) {
    return '$count品';
  }

  @override
  String get splitIntoEntry => '個別の記録に分ける';

  @override
  String entriesWithoutKcal({required int count}) {
    return '$count件はカロリーなし、実際はもっと多い';
  }

  @override
  String eatenKcal({required String kcal}) {
    return '$kcal kcal摂取';
  }

  @override
  String eatenOfTarget({required String kcal, required String target}) {
    return '$kcal kcal摂取、目標 $target kcal';
  }

  @override
  String get eatenKcalTitle => '摂取 kcal';

  @override
  String get remainingKcalTitle => '残り kcal';

  @override
  String get overKcalTitle => '超過 kcal';

  @override
  String get workedOut => '算出';

  @override
  String get caffeineRemaining => '残存カフェイン推定';

  @override
  String halfLifeBasis({required String hours}) {
    return '半減期$hours時間で算出';
  }

  @override
  String caffeineReference({required String mg}) {
    return '就寝時の目安 $mg mg';
  }

  @override
  String get caffeineBelowReference => '就寝時の目安を下回る';

  @override
  String get caffeineBelowReferenceDone => '就寝時の目安以下';

  @override
  String get liveActivities => 'ライブアクティビティ';

  @override
  String get endLiveActivity => 'ライブアクティビティを終了';

  @override
  String get last24Hours => '過去 24 時間';

  @override
  String workedOutValue({required String value}) {
    return '$value · 算出';
  }

  @override
  String caffeineValue({required String mg}) {
    return 'カフェイン $mg mg';
  }

  @override
  String oneServingIs({required String serving}) {
    return '1食分 = $serving';
  }

  @override
  String get starred => '保存済み';

  @override
  String get starAction => '保存';

  @override
  String get starThisFood => 'この食品をお気に入りに';

  @override
  String get editThisFood => 'この食品を編集';

  @override
  String addPortion({required String portion}) {
    return '$portionを追加';
  }

  @override
  String get servingsLabel => '食数';

  @override
  String get actualAmount => '実際の量';

  @override
  String get barcode => 'バーコード';

  @override
  String get allergens => 'アレルゲン';

  @override
  String get none => 'なし';

  @override
  String get valueTypeMaxNote => '表示は上限値で、実際はより低い可能性があります。';

  @override
  String dataSource({required String source}) {
    return '出典：$source';
  }

  @override
  String get deleteThisFood => 'この食品を削除';

  @override
  String itemsWithoutKcal({required int count}) {
    return '$count品はカロリーなし';
  }

  @override
  String get thisMeal => 'この食事';

  @override
  String get finishEditing => '編集を完了';

  @override
  String logItemsCount({required int count}) {
    return '$count品を記録';
  }

  @override
  String get plateEmpty => 'この食事に品目はありません。';

  @override
  String get photoEstimate => '写真で推定';

  @override
  String get retry => '再試行';

  @override
  String get chooseAiFirst => '下書きを作るにはAIを選んでください。';

  @override
  String get foodPhoto => '食べ物の写真';

  @override
  String get describeMealHint => '例：朝食 卵焼きとアイスミルクティーL';

  @override
  String get draftSection => '下書き';

  @override
  String openAiSettings({required String me}) {
    return '「$me > AI」で設定';
  }

  @override
  String get dailyKcalGoal => '1日のカロリー目標';

  @override
  String get kcalRangeError => '800〜6000 kcalで入力してください。';

  @override
  String numberRangeError({required String min, required String max}) {
    return '$min〜$maxで入力してください。';
  }

  @override
  String get weeklyChange => '週ごとの変化';

  @override
  String get dailyTargets => '1日の目標';

  @override
  String get kcalTarget => 'カロリー目標';

  @override
  String get estimateFromBody => '身体データから推定';

  @override
  String get estimateFromBodyDetail => '体重、身長、年齢、性別、活動量';

  @override
  String get setMyself => '自分で設定';

  @override
  String get bodyData => '身体データ';

  @override
  String yearValue({required int year}) {
    return '$year年';
  }

  @override
  String get activityLevelSection => '活動量';

  @override
  String get macroSplit => '栄養素の配分';

  @override
  String get byGoal => '目的に応じて';

  @override
  String perKgBodyWeight({required String grams}) {
    return '体重1kgあたり$grams g';
  }

  @override
  String get proteinPerKgTitle => 'タンパク質（体重1kgあたり）';

  @override
  String byGoalGrams({required String grams}) {
    return '目的に応じて$grams g';
  }

  @override
  String percentOfKcal({required int percent}) {
    return 'カロリーの$percent%';
  }

  @override
  String get fatPercentTitle => '脂質（カロリー比 %）';

  @override
  String defaultPercent({required int percent}) {
    return '既定 $percent%';
  }

  @override
  String get restOfKcal => '残りのカロリー';

  @override
  String get resultSection => '結果';

  @override
  String get restingMetabolism => '基礎代謝';

  @override
  String get maintenanceKcal => '維持カロリー';

  @override
  String get dailyKcal => '1日のカロリー';

  @override
  String missingInputs({required String inputs}) {
    return '$inputsが未入力';
  }

  @override
  String limitValue({required String value}) {
    return '上限 $value';
  }

  @override
  String fromRecentFoodAndWeight({required int days}) {
    return '過去$days日の食事と体重から';
  }

  @override
  String get mifflinEstimate => 'Mifflin-St Jeor推定';

  @override
  String get noCamera => '使用できるカメラがありません';

  @override
  String get pickFromLibrary => 'ライブラリから選択';

  @override
  String servingAndKcal({required String serving, required String kcal}) {
    return '1食分 $serving · $kcal kcal';
  }

  @override
  String get foodLibrary => '食品ライブラリ';

  @override
  String get noOwnFoodsSentence => 'マイ食品はありません。';

  @override
  String get noMatchingFoods => '該当する食品はありません。';

  @override
  String get officialReadOnly => '公式データ、読み取り専用';

  @override
  String splitIntoCount({required int count}) {
    return '$count件に分けました';
  }

  @override
  String get splitThisMeal => 'この食事を分ける';

  @override
  String usualMealType({required String meal}) {
    return 'よく使う：$meal';
  }

  @override
  String get whichMeal => '食事区分';

  @override
  String splitDishTitle({required int count}) {
    return 'この料理を$count件の記録に分けますか？';
  }

  @override
  String splitDishMessage({required String dish}) {
    return '分けると各成分が個別の記録になり、編集・移動・削除できます。「$dish」という単位はなくなります。';
  }

  @override
  String get nowLabel => '現在';

  @override
  String get afterSplit => '分けた後';

  @override
  String componentsCount({required int count}) {
    return '成分$count品';
  }

  @override
  String otherCount({required int count}) {
    return 'ほか$count品';
  }

  @override
  String get undoWithin30s => '30秒以内なら元に戻せます。';

  @override
  String get waterGlass => 'コップ1杯';

  @override
  String get waterLargeGlass => '大きいコップ';

  @override
  String get waterBottle => '1本';

  @override
  String get waterPerTap => '1回の量';

  @override
  String get customAction => 'カスタム';

  @override
  String get moreAction => 'もっと見る';

  @override
  String get waterPerTapMl => '1回の量（mL）';

  @override
  String get waterReference => '1日の目安量';

  @override
  String get waterReferenceMl => '1日の目安量（mL）';

  @override
  String get waterReferenceNote => '集団の参考値で、実際の必要量は人によって異なる';

  @override
  String get waterReferenceHpa => '台湾 国民健康署';

  @override
  String get waterReferenceNone => '設定しない';

  @override
  String waterFastWarning({required String millilitres}) {
    return '1時間以内に $millilitres mL を記録。短時間に大量の水を飲むと低ナトリウム血症になることがあるので、少しずつ飲む。';
  }

  @override
  String waterPerTapLabel({required int millilitres}) {
    return '1回の量、現在$millilitresミリリットル';
  }

  @override
  String waterTimesLast({required int count, required String time}) {
    return '$count回 · 最新 $time';
  }

  @override
  String allDrinksTotal({required int millilitres}) {
    return '飲み物合計 $millilitres mL（コーヒー・お茶を含む）';
  }

  @override
  String todayAt({required String time}) {
    return '今日 $time';
  }

  @override
  String yesterdayAt({required String time}) {
    return '昨日 $time';
  }

  @override
  String addNamed({required String name}) {
    return '$nameを追加';
  }

  @override
  String get contentsSection => '内容';

  @override
  String get muscleMapSetting => '人体図';

  @override
  String get conventionMessage => '1日合計の名称、塩分の単位と上限。食品ページはその食品の表示に従います。';

  @override
  String get profileSection => 'プロフィール';

  @override
  String get goalsAndReminders => '目標とリマインダー';

  @override
  String get featuresSection => '機能';

  @override
  String get exerciseLibraryDetail => '閲覧・検索・カスタム種目の作成';

  @override
  String modulesEnabled({required String modules}) {
    return '$modulesがオン';
  }

  @override
  String get notEnabled => 'オフ';

  @override
  String get dataSection => 'データ';

  @override
  String databaseRecovered({required String path}) {
    return '前回のデータファイルを読み込めなかったため、$pathに移動し、空の状態から開始しました。古いファイルは削除されていません。';
  }

  @override
  String get localData => '端末内のデータ';

  @override
  String get dataSourcesDetail => '手入力、インポート、組み込みカタログ';

  @override
  String get showDemoData => 'デモデータを表示';

  @override
  String get exportTitle => 'エクスポート';

  @override
  String get exportDetail => '完全アーカイブ JSON · CSVビュー';

  @override
  String get privacyDetail => 'データの保存先と送信内容';

  @override
  String get aboutSection => 'このアプリについて';

  @override
  String get versionLabel => 'バージョン';

  @override
  String get exerciseImages => '種目の画像';

  @override
  String get referencesTitle => '参考文献';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get workoutsFigure => 'トレーニング';

  @override
  String get activeDaysFigure => '運動日';

  @override
  String get daysUnit => '日';

  @override
  String get weeksUnit => '週';

  @override
  String get startedLogging => '記録開始';

  @override
  String goalSummaryText({required int target, required int active}) {
    return '週$target日 · 今週$active日';
  }

  @override
  String proteinGrams({required String grams}) {
    return 'タンパク質 $grams g';
  }

  @override
  String foodLibrarySummary({required int own, required int brands}) {
    return 'マイ食品$own件 · ブランド$brands件';
  }

  @override
  String get birthYearHint => '例：1995';

  @override
  String get birthYearError => '生まれ年は西暦4桁で入力してください。';

  @override
  String get sexUseMessage => '1日のカロリー推定にのみ使います。';

  @override
  String get fullArchiveJson => '完全アーカイブ（JSON）';

  @override
  String get fullArchiveDetail => '完全に復元可能';

  @override
  String get fullArchiveDone => '完全アーカイブを作成しました';

  @override
  String get csvViews => 'CSVビュー';

  @override
  String get csvViewsDetail => '読みやすいが完全ではない';

  @override
  String get csvViewsDone => 'CSVビューを作成しました';

  @override
  String get exportNotEncrypted => 'エクスポートしたファイルは暗号化されていません。';

  @override
  String exportDoneFile({required String done, required String file}) {
    return '$done：$file';
  }

  @override
  String exportFailed({required String error}) {
    return 'エクスポートに失敗しました：$error';
  }

  @override
  String appliedTo({required String routine}) {
    return '「$routine」に適用しました';
  }

  @override
  String get aiProposalTitle => 'AIの提案';

  @override
  String aiProposalSubtitle({required String routine}) {
    return 'ルーティン「$routine」· 未適用';
  }

  @override
  String get reject => '却下';

  @override
  String get acceptAndApply => '承認して適用';

  @override
  String get questionLabel => '質問';

  @override
  String get proposalQuestion => '「最近スクワットのセット数が少なすぎない？戻して。」';

  @override
  String changesCount({required int count}) {
    return '$count種目を変更';
  }

  @override
  String get reasonLabel => '理由';

  @override
  String get proposalReason => '週のメインセットが12から8に減少。「筋力維持」目標では10〜12セットが推奨です。';

  @override
  String get proposalDataSent => '送信データ：過去4週のトレーニング記録';

  @override
  String get proposalModel => 'モデル：セルフホスト';

  @override
  String get addedLabel => '追加';

  @override
  String get unchangedLabel => '変更なし';

  @override
  String setsTimesRepsShort({required int sets, required int reps}) {
    return '$setsセット × $reps回';
  }

  @override
  String get privacyStorage => '保存';

  @override
  String get privacyRecords => '記録';

  @override
  String get privacyRecordsValue => 'この端末のみ';

  @override
  String get privacyAccount => 'アカウント';

  @override
  String get privacyServer => 'サーバー';

  @override
  String get privacyDeleted => '削除した記録';

  @override
  String get privacyDeletedValue => '復元可能';

  @override
  String get privacyUninstall => 'アプリの削除';

  @override
  String get privacyUninstallValue => 'すべての記録を消去';

  @override
  String get privacyCameraSection => 'カメラと写真';

  @override
  String get privacyCamera => 'カメラ';

  @override
  String get privacyCameraValue => 'スキャン時のみ起動';

  @override
  String get privacyPhotos => '写真ライブラリ';

  @override
  String get privacyPhotosValue => '最新の1枚を選択ボタンのサムネイルに使用';

  @override
  String get privacyScalePhotos => '体組成計・サイズの写真';

  @override
  String get privacyScalePhotosValue => '端末上で読み取り、送信しない';

  @override
  String privacyHealthSection({required String platform}) {
    return 'ヘルスケアデータ（$platform）';
  }

  @override
  String get privacyPermission => '権限';

  @override
  String get privacyPermissionValue => '読み取りと書き込み';

  @override
  String get privacyReading => '読み取り';

  @override
  String get privacyReadingValue => '初回はすべて、以降は起動時に過去30日分';

  @override
  String get privacyLeavesDevice => '端末外への送信';

  @override
  String get privacyNo => 'いいえ';

  @override
  String get privacyToAi => 'AIへの提供';

  @override
  String get privacyAds => '広告への利用';

  @override
  String get privacyDisconnect => '接続解除後';

  @override
  String get privacyDisconnectValue => '読み込み済みの記録は残る';

  @override
  String get privacyKinds => '読み取る種類';

  @override
  String get privacyDefault => '既定';

  @override
  String get privacyNotUsed => '使用しない';

  @override
  String get privacyAppleIntelligence => '端末上で実行';

  @override
  String get privacyCloudReceives => 'クラウドAIが受け取るもの';

  @override
  String get privacyCloudReceivesValue => '入力した文字、写真から読み取った文字、推定用の食べ物の写真';

  @override
  String get privacyFoodPhotos => '食べ物の写真';

  @override
  String get privacyFoodPhotosValue => '位置情報と撮影情報を削除してから送信、保存しない';

  @override
  String get privacyOtherData => 'ほかの写真・記録・ヘルスケアデータ';

  @override
  String get privacyNotSent => '送信しない';

  @override
  String get privacyFirstSend => '文字や写真を初めて送信する前';

  @override
  String privacyFirstSendValue({required String me}) {
    return 'それぞれ同意を確認、「$me > AI」で撤回可能';
  }

  @override
  String get privacyAiResults => 'AIの結果';

  @override
  String get privacyAiResultsValue => '下書き、確認後に記録';

  @override
  String get privacyGoogleFree => 'Google AI Studio 無料枠';

  @override
  String get privacyGoogleFreeValue => '内容は製品改善に使われ、人が確認する場合がある';

  @override
  String get privacyKeysSection => 'キーとエクスポート';

  @override
  String get privacyApiKeys => 'APIキー';

  @override
  String get privacyApiKeysValue => 'システムの安全な保存領域、データベースには入らない';

  @override
  String get privacyExportFiles => 'エクスポートファイル';

  @override
  String privacyExportFilesValue({required String me}) {
    return '「$me > エクスポート」で手動作成のみ';
  }

  @override
  String get privacyExportContents => 'エクスポート内容';

  @override
  String get privacyExportContentsValue => 'APIキーは含まない';

  @override
  String get privacyUpload => 'アップロード';

  @override
  String get refUse01 => '基礎代謝の推定式';

  @override
  String get refUse02 => '健康な成人ではMifflin-St Jeorが実測に最も近い';

  @override
  String get refUse03 => '活動量（身体活動レベル）の区分';

  @override
  String get refUse04 => '維持・増量のタンパク質は体重1kgあたり1.6–1.8 g（範囲1.4–2.0 g）';

  @override
  String get refUse05 => '減量は週に体重の0.5–1%、タンパク質を増やし脂質はカロリーの15–30%';

  @override
  String get refUse06 => '減量時のタンパク質は体重1kgあたり2.2 g';

  @override
  String get refUse07 => '減量の既定は週0.5%、ゆっくりの方が除脂肪量を保てる';

  @override
  String get refUse08 => '増量は小さな余剰のみ、既定は週0.25%';

  @override
  String get refUse09 => '体重1kgあたり約7,700 kcalは大まかな目安にすぎない';

  @override
  String get refUse10 => '食物繊維は1,000 kcalあたり14 g、脂質はカロリーの20–35%';

  @override
  String get refUse11 => '台湾：成人のナトリウムは1日2,400 mg以下';

  @override
  String get refUse12 => '日本：成人の食塩相当量は1日男性7.5 g、女性6.5 g未満';

  @override
  String get refUse13 => '日本の表示：食塩相当量（g）＝ナトリウム（mg）× 2.54 ÷ 1,000';

  @override
  String get refUse14 => '米国・カナダ：成人のナトリウムは1日2,300 mg以下';

  @override
  String get refUse15 => 'EU：成人のナトリウムは1日2.0 g、塩5 gに相当';

  @override
  String get refUse16 => 'EUの表示：炭水化物に食物繊維を含まない、塩＝ナトリウム × 2.5';

  @override
  String get refUse17 => 'オーストラリア・ニュージーランド：成人のナトリウムは1日2,000 mg';

  @override
  String get refUse18 => 'オーストラリア・ニュージーランドの表示：炭水化物に食物繊維を含まず、エネルギーはkJ表示';

  @override
  String get refUse19 => '韓国：成人のナトリウムは1日2,300 mg以下';

  @override
  String get refUse20 => '中国：成人の食塩は1日5 g以下';

  @override
  String get refUse21 => '残存カフェインは半減期5時間で算出';

  @override
  String get refUse22 => '半減期には個人差があり、算出値は測定値ではない';

  @override
  String get refUse23 => '就寝 4 時間前の 100 mg で影響なし。目安は安全な閾値ではない';

  @override
  String get refUse46 => '35 mg の目安は就寝 8.8 時間前の 107 mg、13.2 時間前の 217.5 mg から推算';

  @override
  String get refUse47 => '1日の目安量 1,500 mL、水のみ';

  @override
  String get refUse48 => '腎臓が1時間に排出できるのは約 0.7–1.0 L。1時間に 1,000 mL 以上で注意';

  @override
  String get refUse24 => '目標未設定時は1晩8時間で計算（合意は7時間以上）';

  @override
  String get refUse25 => '睡眠不足の影響は14日間蓄積し続ける';

  @override
  String get refUse26 => '多く寝ても不足分を1対1では相殺しない';

  @override
  String get refUse27 => '回復に定まった速度はなく、減衰は設けない';

  @override
  String get refUse28 => '推定最大重量（1RM）の式';

  @override
  String get refUse29 => '10回を超えると推定しない、5回が最も正確';

  @override
  String get refUse30 => '7–10回の推定も正確';

  @override
  String get refUse31 => '回数が多いほど個人差と種目差が大きい';

  @override
  String get refUse42 => 'トレーニング負荷を%1RMで表す';

  @override
  String get refUse43 => '%1RMによる負荷の最新指針';

  @override
  String get refUse44 => '負荷と限界への近さは異なる変数';

  @override
  String get refUse45 => '残りの反復回数（RIR）による限界への近さの評価';

  @override
  String get refUse32 => '筋群ごとに週10セット以上の用量反応';

  @override
  String get refUse33 => 'タンパク質は体重1kgあたり1.6 gを超えると効果が頭打ち';

  @override
  String get refUse34 => '最大心拍数は208 − 0.7 × 年齢で推定';

  @override
  String get refUse35 => '安静時心拍数がある場合は予備心拍数で区分';

  @override
  String get refUse36 => 'BMIの低体重・普通・過体重・肥満の区分';

  @override
  String get refUse37 => '除脂肪量指数（FFMI）の定義';

  @override
  String get refUse38 => 'ボディメイクは小さな不足のみ：1日約500 kcalで除脂肪量が増えなくなる';

  @override
  String get refUse39 => 'ボディメイクは小さな不足でも維持カロリーでも可能、高タンパク質と組み合わせる';

  @override
  String get refUse40 => '維持カロリーでのボディメイクのタンパク質は体重1kgあたり2.0 g';

  @override
  String get refUse41 => 'ボディメイクのタンパク質はBMI 30の体重を上限に計算';

  @override
  String get refSectionTargets => '1日のカロリーと栄養素の目標';

  @override
  String get refSectionLabels => '栄養成分表示';

  @override
  String get refSectionCaffeine => 'カフェイン';

  @override
  String get refSectionSleepDebt => '睡眠負債';

  @override
  String get refSectionTraining => 'トレーニングと推移';

  @override
  String get refSectionHeartZones => '運動時の心拍ゾーン';

  @override
  String get refSectionBody => '身体';

  @override
  String get openLink => 'リンクを開く';

  @override
  String get openAction => '開く';

  @override
  String get cannotOpenLink => 'リンクを開けません';

  @override
  String apiKeyTitle({required String provider}) {
    return '$provider APIキー';
  }

  @override
  String get apiKeyHint => 'キーを貼り付け、空欄で削除';

  @override
  String get apiEndpoint => 'APIアドレス';

  @override
  String get azureResourceUrl => 'Azure AI Foundry リソースURL';

  @override
  String get modelLabel => 'モデル';

  @override
  String get modelListUnavailable => 'モデル一覧を取得できません。名前を入力してください。';

  @override
  String get typeOwn => '直接入力';

  @override
  String get deploymentName => 'デプロイ名';

  @override
  String get modelHint => '例：gemini-3.8-flash';

  @override
  String get signInInBrowser => 'ブラウザでサインイン';

  @override
  String signInInstructions({required String uri, required String code}) {
    return '$uriでコード$codeを入力し、職場または学校のアカウントでサインインしてください。';
  }

  @override
  String get copyCode => 'コードをコピー';

  @override
  String get okAction => 'OK';

  @override
  String get signedInCopilot => 'Microsoft 365 Copilotにサインインしました';

  @override
  String get clientId => 'クライアントID';

  @override
  String get clientIdHint => 'Entraアプリ登録のApplication (client) ID';

  @override
  String get tenant => 'テナント';

  @override
  String get tenantHint => '空欄はorganizations';

  @override
  String get revokeConsentTitle => '同意を撤回しますか？';

  @override
  String get revokeConsentMessage => '次にクラウドAIを使う前に再度確認します。';

  @override
  String get revokeConsent => '同意を撤回';

  @override
  String get autoNameMergedMeals => 'まとめた食事を自動で命名';

  @override
  String get serviceSection => 'サービス';

  @override
  String get signedIn => 'サインイン済み';

  @override
  String get signIn => 'サインイン';

  @override
  String get waitingForBrowser => 'ブラウザでのサインインを待機中…';

  @override
  String get signInAgain => '再サインイン';

  @override
  String get apiKey => 'APIキー';

  @override
  String get isSet => '設定済み';

  @override
  String get loadingModels => 'モデルを読み込み中…';

  @override
  String get notChosen => '未選択';

  @override
  String get consentTextAndPhotos => '文字と写真の送信に同意済み';

  @override
  String get consentText => '文字の送信に同意済み';

  @override
  String get consentPhotos => '写真の送信に同意済み';

  @override
  String get checkingEllipsis => '確認中…';

  @override
  String get appleNotEligible => 'このデバイスはApple Intelligenceに対応していません';

  @override
  String get appleNotEnabled => '「設定 > Apple IntelligenceとSiri」でオン';

  @override
  String get appleModelNotReady => 'モデルをダウンロード中';

  @override
  String get appleUnavailable => 'iOS 26以降とApple Intelligence対応が必要';

  @override
  String get azurePortal => 'Azureポータル';

  @override
  String get copilotWarning =>
      'ベータAPIで本番利用は非対応です。職場または学校のアカウント、Microsoft 365 Copilotライセンス、Entraアプリ登録が必要です。';

  @override
  String get googleFreeWarning =>
      '無料枠の内容はGoogleが製品改善に使い、人が確認する場合があります。課金を有効にしたキーを使ってください。';

  @override
  String get cloudAi => 'クラウドAI';

  @override
  String sendToProvider({required String provider}) {
    return '$providerに送信しますか？';
  }

  @override
  String cloudConsentMessage({required String me}) {
    return '入力した文字か写真から読み取った文字だけを送信し、写真やほかの記録は送信しません。「$me > AI」で撤回できます。';
  }

  @override
  String get agreeAndSend => '同意して送信';

  @override
  String sendPhotoToProvider({required String provider}) {
    return '食べ物の写真を$providerに送信しますか？';
  }

  @override
  String photoConsentMessage({required String me}) {
    return 'この写真と補足だけを送信し、位置情報と撮影情報は先に削除、写真は保存しません。「$me > AI」で撤回できます。';
  }

  @override
  String aiFailureUnavailable({required String me}) {
    return 'AI機能は未設定です。「$me > AI」で設定してください。';
  }

  @override
  String get aiFailureNeedsConsent => '文字の送信に同意していません。';

  @override
  String aiFailureAuthentication({required String me}) {
    return 'キーが無効か権限がありません。「$me > AI」で設定し直してください。';
  }

  @override
  String get aiFailureRateLimited => 'リクエストが多すぎるか上限に達しました。後でもう一度お試しください。';

  @override
  String get aiFailureNetwork => 'ネットワークに接続できません。後でもう一度お試しください。';

  @override
  String get aiFailureProvider => 'AIサービスで問題が発生しました。後でもう一度お試しください。';

  @override
  String get aiFailureUnreadable => 'AIの応答を解釈できません。もう一度お試しください。';

  @override
  String get aiFailureNeedsPhotoConsent => '写真の送信に同意していません。';

  @override
  String aiFailurePhotoUnsupported({required String me}) {
    return '現在のAIは写真を読めません。「$me > AI」で変更してください。';
  }

  @override
  String get aiFailureNoFood => '写真に食べ物や飲み物が見当たりません。別の写真でお試しください。';

  @override
  String get aiFailurePhotoFormat => 'この写真の形式は読み込めません。別の写真でお試しください。';

  @override
  String get prior4Weeks => 'その前の4週';

  @override
  String againstBaseline({required String baseline}) {
    return '$baseline比';
  }

  @override
  String againstRecentBaseline({
    required String recent,
    required String baseline,
  }) {
    return '$recentは$baseline比';
  }

  @override
  String changeMore({required String against, required String amount}) {
    return '$against$amount多い';
  }

  @override
  String changeLess({required String against, required String amount}) {
    return '$against$amount少ない';
  }

  @override
  String sleepLoadMore({required String percent}) {
    return '前夜に長く眠った日のトレーニングは、量が平均$percent多い。';
  }

  @override
  String sleepLoadLess({required String percent}) {
    return '前夜に長く眠った日のトレーニングは、量が平均$percent少ない。';
  }

  @override
  String workoutsCount({required int count}) {
    return 'トレーニング$count回';
  }

  @override
  String sleepSplitAt({required String time}) {
    return '$timeで長い睡眠と短い睡眠を区分';
  }

  @override
  String get againstSameWorkout => '同じトレーニングの平均と比較';

  @override
  String weightChange4Weeks({required String change}) {
    return '4週 $change kg';
  }

  @override
  String baselineTimes({required String baseline, required String count}) {
    return '$baseline $count回';
  }

  @override
  String completeDays({required int complete, required int tracked}) {
    return '完全 $complete/$tracked日';
  }

  @override
  String perDaySteps({required String steps}) {
    return '1日$steps歩';
  }

  @override
  String get weightSteady => 'この期間、体重はほぼ横ばいでした。';

  @override
  String weightFalling({required String kg}) {
    return '体重は週に$kg kgのペースで減少しています。';
  }

  @override
  String weightRising({required String kg}) {
    return '体重は週に$kg kgのペースで増加しています。';
  }

  @override
  String basedOnWeights({required int count}) {
    return '体重記録$count件に基づく';
  }

  @override
  String trainingGoalMet({required int count, required int goal}) {
    return '今週$count回目のトレーニングで、週$goal回の目標を達成しました。';
  }

  @override
  String trainingGoalShort({
    required int count,
    required int goal,
    required int left,
  }) {
    return '今週は$count回トレーニング済み、週$goal回まであと$left回です。';
  }

  @override
  String get basedOnThisWeek => '今週のトレーニング記録に基づく';

  @override
  String weeklyGoalTimes({required int goal}) {
    return '週の目標 $goal回';
  }

  @override
  String volumeDropMaxHolding({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exerciseの週セット数が$firstから$lastに減りましたが、推定最大重量は維持されています。';
  }

  @override
  String volumeDropMaxFalling({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exerciseの週セット数が$firstから$lastに減り、推定最大重量も下がりました。';
  }

  @override
  String basedOnWorkouts({required int count}) {
    return 'トレーニング記録$count回に基づく';
  }

  @override
  String get excludesWarmups => 'ウォームアップを除く';

  @override
  String get dataComplete => 'データは完全';

  @override
  String dataIncomplete({required int points, required int days}) {
    return 'データ不完全、記録は$points / $days日のみ';
  }

  @override
  String lastWeeksCount({required int count}) {
    return '過去$count週';
  }

  @override
  String lastDaysAverage({required int count}) {
    return '過去$count日の平均';
  }

  @override
  String lastDaysCount({required int count}) {
    return '過去$count日';
  }

  @override
  String progressionDeloadReason({required int count, required int reps}) {
    return '$count回続けて$reps回に届かなかったため、一段階下げて回数をこなしましょう。';
  }

  @override
  String progressionMissedReps({required String sets, required int reps}) {
    return '前回は$setsで$reps回に届かず、同じ重量を維持。';
  }

  @override
  String progressionMissedSets({required int done, required int planned}) {
    return '前回は$doneセットのみ。$plannedセットこなしてから増量。';
  }

  @override
  String get progressionTooHard => '前回はこなせたが、きつすぎたと評価したため同じ重量を維持。';

  @override
  String progressionNearLimit({required String rir}) {
    return '前回はこなせたが、最終セットが限界に近かった（RIR $rir）ため同じ重量を維持。';
  }

  @override
  String progressionIncreaseReason({
    required String done,
    required String planned,
    required String reserve,
    required String added,
  }) {
    return '前回$doneで$plannedをこなした$reserve。$added kg増やせます。';
  }

  @override
  String progressionReserve({required String rir}) {
    return '（最終セットは余力$rir回）';
  }

  @override
  String atLeastValue({required String value}) {
    return '少なくとも$value';
  }

  @override
  String get appleHealth => 'ヘルスケア';

  @override
  String get healthConnectName => 'ヘルスコネクト';

  @override
  String get healthDataGeneric => 'ヘルスケアデータ';

  @override
  String get strongWorkoutName => 'Strongのトレーニング';

  @override
  String get afterMerge => 'まとめた後';

  @override
  String get splitAction => '分ける';

  @override
  String get aiDraftAction => 'AI 下書き';

  @override
  String get removePhoto => '写真を削除';

  @override
  String get privacyWebSearch => 'ウェブ検索';

  @override
  String get privacyWebSearchValue =>
      'Anthropic と Google AI Studio は送った内容から公開されている栄養成分を検索';

  @override
  String get workoutScheduled => '予定済み';

  @override
  String get cancelSchedule => '予定を取消';

  @override
  String get cancelWorkoutTitle => 'このトレーニングを取り消しますか？';

  @override
  String get cancelWorkoutAction => 'トレーニングを取り消す';

  @override
  String get keepWorkout => '残す';

  @override
  String get commonView => '表示';

  @override
  String get schemeStraight => 'ストレート';

  @override
  String get schemeStraightHint => '全セット同じ重量';

  @override
  String get schemeAscending => '漸増';

  @override
  String get schemeAscendingHint => 'セットごとに重量が増え、回数が減る';

  @override
  String get schemeReverse => '高重量から';

  @override
  String get schemeReverseHint => '最初が最重量、以降は軽くして回数を増やす';

  @override
  String get schemeFiveByFive => '5×5 筋力';

  @override
  String get schemeFiveByFiveHint => '同じ重量で5セット×5回';

  @override
  String get schemeTopSet => 'トップセット';

  @override
  String get schemeTopSetHint => '1セットだけ最重量、残りは軽く';

  @override
  String get schemeDrop => 'ドロップ';

  @override
  String get schemeDropHint => '最初が最重量、以降は少しずつ軽く';

  @override
  String get mainWeight => 'メイン重量';

  @override
  String get mainWeightRecent => '直近90日の最高';

  @override
  String get mainWeightEver => '歴代最高';

  @override
  String get setCountLabel => 'セット数';

  @override
  String get repCountLabel => '回数';

  @override
  String get oneSetLess => '1セット減らす';

  @override
  String get oneSetMore => '1セット増やす';

  @override
  String exerciseRecordsTitle({required String name}) {
    return '$nameの記録';
  }

  @override
  String get earlierRecord => '前の記録';

  @override
  String get laterRecord => '次の記録';

  @override
  String get workoutTimeTitle => '運動時間';

  @override
  String get restTimeTitle => '休憩時間';

  @override
  String get autoRestTitle => 'セット完了後に自動で休憩を開始';

  @override
  String durationSeconds({required int seconds}) {
    return '$seconds秒';
  }

  @override
  String sessionScheduledOpen({required String session}) {
    return '$sessionは予定済み、$sessionに戻る';
  }

  @override
  String get trackingTypeWeightDuration => '重量 + 時間';

  @override
  String repsValue({required int reps}) {
    return '$reps回';
  }

  @override
  String get totalTime => '合計時間';

  @override
  String get totalReps => '合計回数';

  @override
  String get totalDistance => '合計距離';

  @override
  String exerciseLastFigures({required String set}) {
    return '前回 $set';
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
    return '最長距離 $set · $date';
  }

  @override
  String get timeColumn => '時間';

  @override
  String setTime({required String set}) {
    return '$setの時間';
  }

  @override
  String setDistance({required String set}) {
    return '$setの距離';
  }

  @override
  String setNumberTime({required int number}) {
    return '$numberセット目の時間';
  }

  @override
  String setNumberDistance({required int number}) {
    return '$numberセット目の距離';
  }

  @override
  String get unitMinutes => '分';

  @override
  String get unitSeconds => '秒';

  @override
  String get setTimerStart => '開始';

  @override
  String get setTimerStartLabel => '計測を開始';

  @override
  String get goalReached => '達成';

  @override
  String goalMetNights({required int count}) {
    return '$count 晩達成';
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
  String get periodChange => '期間の変化';

  @override
  String get changePerWeek => '週あたり';

  @override
  String get measurementsCount => '測定回数';

  @override
  String get sleepGoalMetLabel => '睡眠目標達成';

  @override
  String get weeklyGoalMetLabel => '週間目標達成';

  @override
  String get workoutsTotal => 'トレーニング回数';

  @override
  String get stepsUnit => '歩';

  @override
  String get gistUsual => 'いつもと同じくらい';

  @override
  String get gistMore => 'いつもより多い';

  @override
  String get gistLess => 'いつもより少ない';

  @override
  String get gistSteady => '横ばい';

  @override
  String get gistRising => '上昇';

  @override
  String get gistFalling => '下降';

  @override
  String get gistNotEnough => '記録が少なく比較できません';

  @override
  String coverageDays({required int count, required int total}) {
    return '$total日中$count日に記録';
  }

  @override
  String perNightChange({required String change}) {
    return '1晩あたり $change';
  }

  @override
  String perDayChange({required String change}) {
    return '1日あたり $change';
  }

  @override
  String perWeekChange({required String change}) {
    return '週あたり $change';
  }

  @override
  String get halfNightsOver => '半数の夜がこれ以上';

  @override
  String get halfDaysOver => '半数の日がこれ以上';

  @override
  String nightsOutOf({required int count, required int total}) {
    return '$total晩中$count晩';
  }

  @override
  String weeksOutOf({required int count, required int total}) {
    return '$total週中$count週';
  }

  @override
  String completeOutOf({required int count, required int total}) {
    return '$total日中$count日が完全';
  }

  @override
  String get refSectionSummaries => '傾向のまとめ';

  @override
  String get refUseSummaryNarrative => '各傾向ページの先頭で全体の動きを一文で要約';

  @override
  String get refUseSummaryVerbal => '「いつもより多い」などの言葉は必ず数値と併記し、個人の通常範囲で判定';

  @override
  String get refUseSummaryAbsolute => '差は絶対量（1晩あたり +18 分）で示し、割合だけにしない';

  @override
  String get refUseSummaryFrequencies => '達成回数は割合でなく「7晩中5晩」と数える';

  @override
  String get refUseSummaryIntegers => '要約の数値は丸め、不要な小数を出さない';

  @override
  String get refUseSummaryReference => '比較基準は個人の通常範囲と直前12週に固定';

  @override
  String get sleepRegularityIndexLabel => '睡眠規則性指数';

  @override
  String get refSectionSleepRegularity => '睡眠の規則性';

  @override
  String get refUseSleepRegularityIndex => '睡眠規則性指数の定義：連続する2日の同じ時刻の睡眠・覚醒の一致度';

  @override
  String get refUseSocialJetlag => 'ソーシャル・ジェットラグ：休日と平日の睡眠中央時刻の差';

  @override
  String get stepGoal => '歩数目標';

  @override
  String get stepGoalMetLabel => '歩数目標達成';

  @override
  String daysOutOf({required int count, required int total}) {
    return '$total日中$count日';
  }

  @override
  String get refSectionSteps => '歩数';

  @override
  String get refUseStepGoalChosen => '歩数目標は利用者が選び、既定値も自動調整もしない';

  @override
  String get refUseStepGoalSet => '歩数目標の設定は歩数の増加と関連';

  @override
  String get sleepRegularitySection => '睡眠の規則性';

  @override
  String priorDays({required int count}) {
    return '前の$count日';
  }

  @override
  String weekendMidsleepLater({required String time}) {
    return '週末の睡眠中央時刻が $time 遅い';
  }

  @override
  String weekendMidsleepEarlier({required String time}) {
    return '週末の睡眠中央時刻が $time 早い';
  }

  @override
  String get weekendMidsleepSame => '週末と平日の睡眠中央時刻が同じ';

  @override
  String regularityNeeds({required int count}) {
    return '過去28日のうち就寝と起床の時刻がある夜が14晩必要（現在$count晩）';
  }
}
