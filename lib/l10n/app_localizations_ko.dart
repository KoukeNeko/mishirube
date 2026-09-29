// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appLanguage => '한국어';

  @override
  String get meLanguageRow => '언어';

  @override
  String get meSettingsOpenFailed => '설정을 열 수 없음';

  @override
  String get commonUndo => '실행 취소';

  @override
  String get commonSearch => '검색';

  @override
  String get commonCloseSearch => '검색 닫기';

  @override
  String get commonBack => '뒤로';

  @override
  String get commonClose => '닫기';

  @override
  String get commonSave => '저장';

  @override
  String get commonCancel => '취소';

  @override
  String get insightCardTitle => '주목할 점';

  @override
  String get monthPickerPreviousYear => '이전 연도';

  @override
  String get monthPickerNextYear => '다음 연도';

  @override
  String get monthPickerClose => '월 선택 닫기';

  @override
  String get monthPickerYear => '연도';

  @override
  String get monthPickerMonth => '월';

  @override
  String dayStripHasRecords({required String date}) {
    return '$date, 기록 있음';
  }

  @override
  String get moduleNutrition => '식단';

  @override
  String get moduleNutritionDescription => '식사, 요리, 재료와 영양';

  @override
  String get moduleWaterDescription => '마신 물의 양과 시간';

  @override
  String get moduleWeight => '체중';

  @override
  String get moduleWeightDescription => '체중과 둘레';

  @override
  String get moduleTraining => '트레이닝';

  @override
  String get moduleTrainingDescription => '운동 동작, 루틴과 트레이닝 기록';

  @override
  String get moduleActivity => '활동';

  @override
  String get moduleActivityDescription => '달리기, 걷기, 자전거, 구기, 요가';

  @override
  String get moduleSleep => '수면';

  @override
  String get moduleSleepDescription => '수면 시간과 질';

  @override
  String get moduleWellness => '기분, 에너지, 증상';

  @override
  String get moduleWellnessDescription => '하루 컨디션 일지';

  @override
  String get moduleNotes => '메모';

  @override
  String get moduleNotesDescription => '날짜나 기록에 연결';

  @override
  String get sourceManual => '직접 입력';

  @override
  String get sourceDemo => '예시 데이터';

  @override
  String get sourceImport => '가져옴';

  @override
  String get sourceAiDraft => 'AI 초안(확인됨)';

  @override
  String get sourceCatalogue => '내장 카탈로그';

  @override
  String get sourceUnknown => '알 수 없음';

  @override
  String get sourceAppleHealth => 'Apple 건강';

  @override
  String get modulesTitle => '모듈';

  @override
  String get modulesPickSeveral => '여러 개 선택 가능';

  @override
  String get commonDone => '완료';

  @override
  String get commonContinue => '계속';

  @override
  String get journalSourceRow => '출처';

  @override
  String get sessionWorkout => '트레이닝';

  @override
  String sessionEndTitle({required String session}) {
    return '$session을(를) 끝낼까요?';
  }

  @override
  String get sessionEndWorkoutMessage =>
      '완료한 세트는 기록으로 저장됩니다. 버리면 트레이닝으로 남지 않습니다.';

  @override
  String get sessionEndActivityMessage =>
      '종료하면 활동 기록으로 저장됩니다. 버리면 아무것도 남지 않습니다.';

  @override
  String get sessionFinishAndSave => '종료하고 저장';

  @override
  String get sessionDiscardWorkout => '이번 트레이닝 버리기';

  @override
  String get sessionDiscardActivity => '이번 활동 버리기';

  @override
  String sessionKeepGoing({required String session}) {
    return '계속하기';
  }

  @override
  String sessionDiscarded({required String session}) {
    return '$session을(를) 버렸습니다';
  }

  @override
  String sessionResume({required String session}) {
    return '재개';
  }

  @override
  String sessionPause({required String session}) {
    return '일시정지';
  }

  @override
  String sessionEnd({required String session}) {
    return '종료';
  }

  @override
  String sessionPausedOpen({required String session}) {
    return '$session 일시정지됨, 돌아가기';
  }

  @override
  String sessionRunningOpen({required String session}) {
    return '$session 진행 중, 돌아가기';
  }

  @override
  String get sessionPausedStatus => '일시정지됨';

  @override
  String sessionRunningStatus({required String session}) {
    return '$session 진행 중';
  }

  @override
  String get dockAddEntry => '기록 추가';

  @override
  String addEntryToDay({required String date}) {
    return '$date에 기록 추가';
  }

  @override
  String get tabToday => '오늘';

  @override
  String get tabLog => '기록';

  @override
  String get tabTrends => '추세';

  @override
  String get tabMe => '내 정보';

  @override
  String get detailNothingSelected => '선택한 항목 없음';

  @override
  String get detailNoEntrySelected => '선택한 기록 없음';

  @override
  String get recordWater => '물';

  @override
  String get recordMeasurements => '둘레';

  @override
  String get recordBodyComposition => '체성분';

  @override
  String waterLogged({required int millilitres}) {
    return '물 $millilitres mL 기록됨';
  }

  @override
  String get quickLogClose => '기록 추가 닫기';

  @override
  String get bedtimeReminderTitle => '잘 준비할 시간';

  @override
  String bedtimeReminderBody({required String bedtime, required String wake}) {
    return '$bedtime 취침, $wake 기상';
  }

  @override
  String get restResting => '휴식 중';

  @override
  String get restEnded => '휴식 끝';

  @override
  String restNextSet({required String exercise}) {
    return '다음 세트 · $exercise';
  }

  @override
  String setsProgress({required int done, required int total}) {
    return '$done / $total 세트';
  }

  @override
  String get trackingTypeWeightReps => '무게 + 횟수';

  @override
  String get trackingTypeReps => '횟수';

  @override
  String get trackingTypeDuration => '시간';

  @override
  String get trackingTypeDistance => '거리';

  @override
  String get exerciseSourceBuiltIn => '기본';

  @override
  String get exerciseSourceCustom => '사용자 지정';

  @override
  String get exerciseSourceImported => '가져옴';

  @override
  String get bodyRegionChest => '가슴';

  @override
  String get bodyRegionShoulders => '어깨';

  @override
  String get bodyRegionBack => '등';

  @override
  String get bodyRegionArms => '팔';

  @override
  String get bodyRegionCore => '코어';

  @override
  String get bodyRegionLegs => '하체';

  @override
  String get muscleChest => '가슴';

  @override
  String get muscleFrontDelts => '전면 삼각근';

  @override
  String get muscleSideDelts => '측면 삼각근';

  @override
  String get muscleRearDelts => '후면 삼각근';

  @override
  String get muscleBiceps => '이두근';

  @override
  String get muscleTriceps => '삼두근';

  @override
  String get muscleForearms => '전완';

  @override
  String get muscleTraps => '승모근';

  @override
  String get muscleLats => '광배근';

  @override
  String get muscleUpperBack => '상부 등';

  @override
  String get muscleSpinalErectors => '척추기립근';

  @override
  String get muscleAbs => '복직근';

  @override
  String get muscleObliques => '복사근';

  @override
  String get muscleGlutes => '둔근';

  @override
  String get muscleQuads => '대퇴사두';

  @override
  String get muscleHamstrings => '햄스트링';

  @override
  String get muscleAdductors => '내전근';

  @override
  String get muscleAbductors => '외전근';

  @override
  String get muscleCalves => '종아리';

  @override
  String get muscleBack => '등';

  @override
  String get muscleShoulders => '어깨';

  @override
  String get muscleArms => '팔';

  @override
  String get muscleCore => '코어';

  @override
  String get equipmentBarbell => '바벨';

  @override
  String get equipmentDumbbell => '덤벨';

  @override
  String get equipmentCable => '케이블';

  @override
  String get equipmentMachine => '머신';

  @override
  String get equipmentSmithMachine => '스미스 머신';

  @override
  String get equipmentKettlebell => '케틀벨';

  @override
  String get equipmentEzBar => 'EZ 바';

  @override
  String get equipmentTrapBar => '트랩 바';

  @override
  String get equipmentLandmine => '랜드마인';

  @override
  String get equipmentPlate => '원판';

  @override
  String get equipmentBand => '밴드';

  @override
  String get equipmentBodyweight => '맨몸';

  @override
  String get equipmentCardio => '유산소 기구';

  @override
  String get equipmentOther => '기타';

  @override
  String get movementPatternSquat => '스쿼트';

  @override
  String get movementPatternHinge => '힌지';

  @override
  String get movementPatternLunge => '런지·한 다리';

  @override
  String get movementPatternHorizontalPush => '수평 밀기';

  @override
  String get movementPatternHorizontalPull => '수평 당기기';

  @override
  String get movementPatternVerticalPush => '수직 밀기';

  @override
  String get movementPatternVerticalPull => '수직 당기기';

  @override
  String get movementPatternIsolation => '단관절';

  @override
  String get movementPatternCore => '코어';

  @override
  String get movementPatternCarry => '캐리';

  @override
  String get movementPatternConditioning => '컨디셔닝';

  @override
  String get movementPatternUnilateral => '한쪽';

  @override
  String get lateralityBilateral => '양쪽';

  @override
  String get lateralityUnilateral => '한쪽';

  @override
  String get lateralityAlternating => '좌우 교대';

  @override
  String get setTypeWorking => '본 세트';

  @override
  String get setTypeWarmup => '워밍업 세트';

  @override
  String get setTypeDrop => '드롭 세트';

  @override
  String get setTypeFailure => '실패 세트';

  @override
  String get workloadTooLight => '너무 가벼움';

  @override
  String get workloadRight => '적당함';

  @override
  String get workloadTooHard => '너무 힘듦';

  @override
  String get setKindWorking => '본';

  @override
  String get setKindWarmup => '워밍업';

  @override
  String get setKindDrop => '드롭';

  @override
  String get setKindFailure => '실패';

  @override
  String substitutionSamePattern({required String pattern}) {
    return '같은 $pattern 패턴';
  }

  @override
  String substitutionSameMuscles({required String muscles}) {
    return '$muscles도 단련';
  }

  @override
  String substitutionEquipmentAvailable({required String equipment}) {
    return '$equipment 사용 가능';
  }

  @override
  String substitutionTrackingChanges({required String tracking}) {
    return '기록 방식이 $tracking(으)로 변경';
  }

  @override
  String substitutionEquipmentChanges({required String equipment}) {
    return '$equipment(으)로 바뀌어 무게를 다시 설정';
  }

  @override
  String get substitutionOneSide => '한쪽 동작이므로 횟수를 다시 설정';

  @override
  String get routineUntitled => '새 루틴';

  @override
  String get workoutFreeName => '자유 트레이닝';

  @override
  String setOrdinal({required int number}) {
    return '$number세트';
  }

  @override
  String muscleSetCount({required String muscle, required int sets}) {
    return '$muscle $sets세트';
  }

  @override
  String get valueTypeDeclared => '표시값';

  @override
  String get valueTypeMax => '최대값';

  @override
  String get valueTypeEstimate => '추정값';

  @override
  String get mealTypeBreakfast => '아침';

  @override
  String get mealTypeLunch => '점심';

  @override
  String get mealTypeDinner => '저녁';

  @override
  String get mealTypeSnack => '간식';

  @override
  String get consumptionKindFood => '음식';

  @override
  String get consumptionKindBeverage => '음료';

  @override
  String get consumptionKindUnknown => '미지정';

  @override
  String get servingUnitGram => 'g';

  @override
  String get servingUnitKilogram => 'kg';

  @override
  String get servingUnitOunce => 'oz';

  @override
  String get servingUnitPound => 'lb';

  @override
  String get servingUnitTael => '대만 냥';

  @override
  String get servingUnitCatty => '대만 근';

  @override
  String get servingUnitMillilitre => 'ml';

  @override
  String get servingUnitLitre => 'L';

  @override
  String get servingUnitServing => '인분';

  @override
  String get allergenCrustacean => '갑각류';

  @override
  String get allergenMango => '망고';

  @override
  String get allergenPeanut => '땅콩';

  @override
  String get allergenMilk => '우유';

  @override
  String get allergenEgg => '달걀';

  @override
  String get allergenTreeNut => '견과류';

  @override
  String get allergenSesame => '참깨';

  @override
  String get allergenGluten => '글루텐';

  @override
  String get allergenSoy => '대두';

  @override
  String get allergenFish => '생선';

  @override
  String get allergenSulphite => '아황산염';

  @override
  String get nutrientSaturatedFat => '포화지방';

  @override
  String get nutrientTransFat => '트랜스지방';

  @override
  String get nutrientSugar => '당류';

  @override
  String get nutrientSodium => '나트륨';

  @override
  String get nutrientNetCarb => '당질';

  @override
  String get nutrientSaltEquivalent => '식염상당량';

  @override
  String get nutrientPolyols => '당알코올';

  @override
  String get nutrientAlcohol => '알코올';

  @override
  String get nutrientCholesterol => '콜레스테롤';

  @override
  String get nutrientCaffeine => '카페인';

  @override
  String get nutrientEssentialAminoAcids => '필수 아미노산';

  @override
  String get nutrientBcaa => 'BCAA';

  @override
  String get nutrientLeucine => '류신';

  @override
  String get nutrientIsoleucine => '이소류신';

  @override
  String get nutrientValine => '발린';

  @override
  String get nutrientGlutamine => '글루타민';

  @override
  String get nutrientCalcium => '칼슘';

  @override
  String get nutrientPhosphorus => '인';

  @override
  String get nutrientMagnesium => '마그네슘';

  @override
  String get nutrientIron => '철';

  @override
  String get nutrientZinc => '아연';

  @override
  String get nutrientPotassium => '칼륨';

  @override
  String get nutrientIodine => '요오드';

  @override
  String get nutrientSelenium => '셀레늄';

  @override
  String get nutrientVitaminA => '비타민 A';

  @override
  String get nutrientVitaminD => '비타민 D';

  @override
  String get nutrientVitaminE => '비타민 E';

  @override
  String get nutrientVitaminK => '비타민 K';

  @override
  String get nutrientVitaminC => '비타민 C';

  @override
  String get nutrientVitaminB1 => '비타민 B1';

  @override
  String get nutrientVitaminB2 => '비타민 B2';

  @override
  String get nutrientNiacin => '나이아신';

  @override
  String get nutrientVitaminB6 => '비타민 B6';

  @override
  String get nutrientVitaminB12 => '비타민 B12';

  @override
  String get nutrientFolate => '엽산';

  @override
  String get nutrientPantothenicAcid => '판토텐산';

  @override
  String get nutrientBiotin => '비오틴';

  @override
  String get nutrientMonounsaturatedFat => '단일불포화지방';

  @override
  String get nutrientPolyunsaturatedFat => '다중불포화지방';

  @override
  String get nutrientCopper => '구리';

  @override
  String get nutrientManganese => '망간';

  @override
  String get nutrientChromium => '크롬';

  @override
  String get nutrientMolybdenum => '몰리브덴';

  @override
  String get nutrientChloride => '염소';

  @override
  String get conventionTaiwan => '대만';

  @override
  String get conventionJapan => '일본';

  @override
  String get conventionUnitedStates => '미국';

  @override
  String get conventionEuropeanUnion => 'EU';

  @override
  String get conventionAustraliaNewZealand => '호주·뉴질랜드';

  @override
  String get conventionKorea => '한국';

  @override
  String get conventionChina => '중국';

  @override
  String get conventionCanada => '캐나다';

  @override
  String get macroEnergy => '열량';

  @override
  String get macroProtein => '단백질';

  @override
  String get macroCarb => '탄수화물';

  @override
  String get macroFat => '지방';

  @override
  String get macroFibre => '식이섬유';

  @override
  String foodCupCapacity({required String amount}) {
    return '컵 용량 $amount';
  }

  @override
  String get foodOfficialData => '공식 데이터';

  @override
  String foodAdd({required String food}) {
    return '\'$food\' 추가';
  }

  @override
  String foodLastPortion({required String portion, required String kcal}) {
    return '지난번 $portion · $kcal';
  }

  @override
  String foodCupSizes({required int count}) {
    return '컵 크기 $count종';
  }

  @override
  String foodOneServing({required String serving, required String kcal}) {
    return '1인분 $serving · $kcal';
  }

  @override
  String draftEnergyMismatchItem({required String item}) {
    return '$item의 열량이 단백질·탄수화물·지방으로 계산한 값과 크게 다릅니다. 확인하세요.';
  }

  @override
  String get draftEnergyMismatch =>
      '열량이 단백질·탄수화물·지방으로 계산한 값과 크게 다릅니다. 이 항목들을 확인하세요.';

  @override
  String get draftColumnMismatch =>
      '1회분 열량과 100당 열량이 분량으로 환산한 값과 맞지 않습니다. 다른 열의 숫자일 수 있으니 확인하세요.';

  @override
  String get draftCarbWithoutFibre =>
      '이 표시의 탄수화물은 식이섬유를 포함하지 않고 식이섬유 표기도 없어 탄수화물을 비워 둡니다.';

  @override
  String get activityGroupWalkRun => '걷기·달리기';

  @override
  String get activityGroupCycling => '자전거';

  @override
  String get activityGroupWater => '수상 스포츠';

  @override
  String get activityGroupBall => '구기';

  @override
  String get activityGroupIndoor => '실내 기구';

  @override
  String get activityGroupMindBody => '심신·스트레칭';

  @override
  String get activityGroupOther => '기타';

  @override
  String get activityMetricGroupMovement => '일상 활동';

  @override
  String get activityMetricGroupHeart => '심장·심폐';

  @override
  String get activityMetricGroupVitals => '바이탈';

  @override
  String get activityMetricMindfulTime => '마음챙김 시간';

  @override
  String get activityMetricGroupMindfulness => '마음챙김';

  @override
  String get activityMetricBodyTemperature => '체온';

  @override
  String get activityMetricBloodPressureSystolic => '수축기 혈압';

  @override
  String get activityMetricBloodPressureDiastolic => '이완기 혈압';

  @override
  String get activityMetricRespiratoryRate => '호흡수';

  @override
  String get activityMetricOxygenSaturation => '혈중 산소';

  @override
  String get activityMetricUnitRespiratoryRate => '회/분';

  @override
  String get activityMetricGroupMobility => '이동성';

  @override
  String get activityMetricGroupRunning => '달리기';

  @override
  String get activityMetricGroupCycling => '사이클';

  @override
  String get activityMetricGroupSwimmingWheelchair => '수영·휠체어';

  @override
  String get activityMetricSteps => '걸음 수';

  @override
  String get activityMetricDistance => '거리';

  @override
  String get activityMetricActiveEnergy => '활동 에너지';

  @override
  String get activityMetricBasalEnergy => '휴식 에너지';

  @override
  String get activityMetricExerciseTime => '운동 시간';

  @override
  String get activityMetricStandTime => '일어서기 시간';

  @override
  String get activityMetricMoveTime => '움직이기 시간';

  @override
  String get activityMetricFloors => '오른 층수';

  @override
  String get activityMetricElevationGained => '상승 고도';

  @override
  String get activityMetricTimeInDaylight => '일광 노출 시간';

  @override
  String get activityMetricHeartRate => '평균 심박수';

  @override
  String get activityMetricRestingHeartRate => '휴식 심박수';

  @override
  String get activityMetricWalkingHeartRate => '걷기 평균 심박수';

  @override
  String get activityMetricHrvSdnn => '심박 변이도(SDNN)';

  @override
  String get activityMetricHrvRmssd => '심박 변이도(RMSSD)';

  @override
  String get activityMetricHeartRateRecovery => '1분 심박 회복';

  @override
  String get activityMetricVo2Max => '최대 산소 섭취량';

  @override
  String get activityMetricPhysicalEffort => '신체 활동 강도';

  @override
  String get activityMetricWalkingSpeed => '걷기 속도';

  @override
  String get activityMetricWalkingStepLength => '보폭';

  @override
  String get activityMetricWalkingAsymmetry => '걷기 비대칭성';

  @override
  String get activityMetricDoubleSupport => '양발 지지 시간';

  @override
  String get activityMetricWalkingSteadiness => '걷기 안정성';

  @override
  String get activityMetricStairAscentSpeed => '계단 오르기 속도';

  @override
  String get activityMetricStairDescentSpeed => '계단 내려가기 속도';

  @override
  String get activityMetricSixMinuteWalk => '6분 걷기 거리';

  @override
  String get activityMetricRunningSpeed => '달리기 속도';

  @override
  String get activityMetricRunningPower => '달리기 파워';

  @override
  String get activityMetricRunningStrideLength => '달리기 보폭';

  @override
  String get activityMetricGroundContactTime => '지면 접촉 시간';

  @override
  String get activityMetricVerticalOscillation => '수직 진폭';

  @override
  String get activityMetricCyclingDistance => '사이클 거리';

  @override
  String get activityMetricCyclingSpeed => '사이클 속도';

  @override
  String get activityMetricCyclingPower => '사이클 파워';

  @override
  String get activityMetricCyclingCadence => '케이던스';

  @override
  String get activityMetricFunctionalThresholdPower => '기능적 역치 파워';

  @override
  String get activityMetricSwimmingDistance => '수영 거리';

  @override
  String get activityMetricSwimmingStrokes => '스트로크 수';

  @override
  String get activityMetricWheelchairPushes => '휠체어 밀기';

  @override
  String get activityMetricWheelchairDistance => '휠체어 거리';

  @override
  String get activityMetricUnitSteps => '걸음';

  @override
  String get activityMetricUnitDistance => 'km';

  @override
  String get activityMetricUnitActiveEnergy => 'kcal';

  @override
  String get activityMetricUnitBasalEnergy => 'kcal';

  @override
  String get activityMetricUnitExerciseTime => '분';

  @override
  String get activityMetricUnitStandTime => '분';

  @override
  String get activityMetricUnitFloors => '층';

  @override
  String get activityMetricUnitElevationGained => 'm';

  @override
  String get activityMetricUnitTimeInDaylight => '분';

  @override
  String get activityMetricUnitHeartRate => 'bpm';

  @override
  String get activityMetricUnitRestingHeartRate => 'bpm';

  @override
  String get activityMetricUnitWalkingHeartRate => 'bpm';

  @override
  String get activityMetricUnitHrvSdnn => 'ms';

  @override
  String get activityMetricUnitHrvRmssd => 'ms';

  @override
  String get activityMetricUnitHeartRateRecovery => 'bpm';

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
  String get activityMetricUnitSwimmingStrokes => '회';

  @override
  String get activityMetricUnitWheelchairPushes => '회';

  @override
  String get activityMetricUnitWheelchairDistance => 'km';

  @override
  String get activityTypeRunning => '달리기';

  @override
  String get activityTypeWalking => '걷기';

  @override
  String get activityTypeHiking => '하이킹';

  @override
  String get activityTypeCycling => '사이클링';

  @override
  String get activityTypeSwimming => '수영';

  @override
  String get activityTypeRowing => '로잉 머신';

  @override
  String get activityTypeElliptical => '일립티컬';

  @override
  String get activityTypeStairs => '계단 오르기';

  @override
  String get activityTypeBasketball => '농구';

  @override
  String get activityTypeBadminton => '배드민턴';

  @override
  String get activityTypeYoga => '요가';

  @override
  String get activityTypeOther => '기타 운동';

  @override
  String durationMinutes({required int minutes}) {
    return '$minutes분';
  }

  @override
  String get activitySeriesHeartRate => '심박수';

  @override
  String get activitySeriesSpeed => '속도';

  @override
  String get activitySeriesPower => '파워';

  @override
  String get activitySeriesCadence => '케이던스';

  @override
  String get activitySeriesStrideLength => '보폭';

  @override
  String get activitySeriesGroundContactTime => '지면 접촉 시간';

  @override
  String get activitySeriesVerticalOscillation => '수직 진폭';

  @override
  String get activitySeriesAltitude => '고도';

  @override
  String get activitySeriesUnitHeartRate => 'bpm';

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
  String get unitBpm => 'bpm';

  @override
  String activityDeleted({required String activity}) {
    return '$activity 삭제됨';
  }

  @override
  String get recordDeletedNotice => '이 기록은 삭제되었습니다.';

  @override
  String get activityRouteMap => '경로 지도';

  @override
  String get healthDetailUnreadable => '건강 앱의 세부 기록을 읽을 수 없습니다.';

  @override
  String get activityDetailsSection => '세부 정보';

  @override
  String get activitySplitsSection => '구간 · 1 km마다';

  @override
  String get activityRecoverySection => '운동 후 심박수';

  @override
  String get activityPace => '페이스';

  @override
  String get notesSection => '메모';

  @override
  String get manageSection => '관리';

  @override
  String get activityEdit => '내용 편집';

  @override
  String get activityEditDetail => '종류, 시간, 길이';

  @override
  String get recordDelete => '이 기록 삭제';

  @override
  String get deleteMeasurement => '이 측정 삭제';

  @override
  String get activityActiveTime => '운동 시간';

  @override
  String get activityDistance => '거리';

  @override
  String get activityTotalEnergy => '총 에너지';

  @override
  String get activityClimb => '상승 고도';

  @override
  String get activityAveragePace => '평균 페이스';

  @override
  String get activityAverageSpeed => '평균 속도';

  @override
  String get activityMaxHeartRate => '최고 심박수';

  @override
  String get activityAveragePower => '평균 파워';

  @override
  String get activityAverageCadence => '평균 케이던스';

  @override
  String get activityEffort => '운동 강도';

  @override
  String get activityEffortEstimated => '운동 강도(추정)';

  @override
  String activityIndoor({required String activity}) {
    return '$activity(실내)';
  }

  @override
  String activityOutdoor({required String activity}) {
    return '$activity(실외)';
  }

  @override
  String get weatherLabel => '날씨';

  @override
  String get humidityLabel => '습도';

  @override
  String get splitTime => '시간';

  @override
  String statAverage({required String value}) {
    return '평균 $value';
  }

  @override
  String heartZone({required int number}) {
    return '존 $number';
  }

  @override
  String get heartZonesByReserve => '여유 심박수로 추정';

  @override
  String get heartZonesByAge => '나이로 최대 심박수 추정';

  @override
  String get heartZonesOwn => '이 앱의 구간';

  @override
  String get recoveryAtEnd => '종료 시';

  @override
  String recoveryAfter({required int minutes}) {
    return '$minutes분 후';
  }

  @override
  String recoveryWindow({required String time}) {
    return '$time부터 3분';
  }

  @override
  String timelineWeight({required String weight}) {
    return '체중 $weight';
  }

  @override
  String sleepQualityScore({required int score}) {
    return '질 $score / 5';
  }

  @override
  String noteLine({required String note}) {
    return '메모: $note';
  }

  @override
  String setsCount({required int count}) {
    return '$count세트';
  }

  @override
  String personalRecordLine({
    required String exercise,
    required String weight,
    required int reps,
  }) {
    return '$exercise $weight kg × $reps 개인 기록';
  }

  @override
  String effortOutOfTen({required int effort}) {
    return '강도 $effort / 10';
  }

  @override
  String activitiesCount({required int count}) {
    return '$count회';
  }

  @override
  String itemsCount({required int count}) {
    return '$count개';
  }

  @override
  String mealsCount({required int count}) {
    return '$count끼';
  }

  @override
  String get foodLogIncomplete => '기록하지 않은 식사 있음';

  @override
  String todayWithDate({required String date}) {
    return '오늘 · $date';
  }

  @override
  String get routineNeverDone => '완료한 적 없음';

  @override
  String routineLastDone({required String date}) {
    return '마지막 완료 $date';
  }

  @override
  String exerciseLastSet({required String weight, required int reps}) {
    return '지난번 $weight kg × $reps';
  }

  @override
  String optionalField({required String field}) {
    return '$field(선택)';
  }

  @override
  String get workoutBlocksActivity => '트레이닝이 진행 중입니다. 종료한 후 활동을 시작하세요.';

  @override
  String activityDurationRange({required int min, required int max}) {
    return '시간은 $min~$max분 사이로 입력하세요.';
  }

  @override
  String activityDistanceRange({required int max}) {
    return '거리는 0~$max km 사이로 입력하세요.';
  }

  @override
  String activityClimbRange({required int max}) {
    return '상승 고도는 0~$max m 사이로 입력하세요.';
  }

  @override
  String activityLogged({required String activity, required int minutes}) {
    return '$activity $minutes분 기록됨';
  }

  @override
  String activityUpdated({required String activity}) {
    return '$activity 업데이트됨';
  }

  @override
  String get activityRecordTitle => '활동 기록';

  @override
  String get activityEditTitle => '활동 편집';

  @override
  String get activityTypeRow => '활동 종류';

  @override
  String get activityStartTimer => '지금 기록 시작';

  @override
  String get activityStartTimerDetail => '하면서 기록하고, 거리와 강도는 끝난 후 입력';

  @override
  String get activityStartTime => '시작 시간';

  @override
  String get activityDurationSection => '시간';

  @override
  String get minutesUnit => '분';

  @override
  String activityEndsAt({required String time}) {
    return '종료 $time';
  }

  @override
  String activityPaceValue({required String pace}) {
    return '페이스 $pace /km';
  }

  @override
  String get effortSection => '강도';

  @override
  String get effortScaleHint => '1은 매우 쉬움, 10은 전력.';

  @override
  String get activityNoteHint => '예: 강변, 바람이 강함';

  @override
  String get activityPickTitle => '활동 선택';

  @override
  String get recentlyUsed => '최근 사용';

  @override
  String get commonlyUsed => '자주 사용';

  @override
  String get activityAllTypes => '모든 활동';

  @override
  String get activityEnded => '이 활동은 종료되었습니다.';

  @override
  String get sessionInProgress => '진행 중';

  @override
  String get commonEnd => '종료';

  @override
  String get commonResume => '재개';

  @override
  String get commonPause => '일시정지';

  @override
  String get chartRangeDay => '일';

  @override
  String get chartRangeWeek => '주';

  @override
  String get chartRangeMonth => '월';

  @override
  String get chartRangeHalfYear => '6개월';

  @override
  String get chartRangeYear => '년';

  @override
  String get previousDay => '이전 날';

  @override
  String get nextDay => '다음 날';

  @override
  String get entriesRow => '기록';

  @override
  String get noData => '데이터 없음';

  @override
  String get thisDay => '이 날';

  @override
  String get dailyAverage => '하루 평균';

  @override
  String get usualRange => '평소 범위';

  @override
  String get daysRecorded => '기록 일수';

  @override
  String daysCount({required int count}) {
    return '$count일';
  }

  @override
  String weekOf({required String date}) {
    return '$date부터 1주';
  }

  @override
  String readingsCount({required int count}) {
    return '$count개';
  }

  @override
  String get perDay => '매일';

  @override
  String get dailyActivityTitle => '활동';

  @override
  String get noActivityData => '활동 데이터 없음';

  @override
  String get dataSourcesLink => '데이터 출처';

  @override
  String get noActivityThisDay => '이 날의 활동 데이터 없음';

  @override
  String usualRangeValue({required String range}) {
    return '평소 $range';
  }

  @override
  String get perHour => '시간별';

  @override
  String hourSpan({required int start, required int end}) {
    return '$start~$end시';
  }

  @override
  String hourOfDay({required int hour}) {
    return '$hour시';
  }

  @override
  String get measurementSiteWaist => '허리';

  @override
  String get measurementSiteHips => '엉덩이';

  @override
  String get measurementSiteChest => '가슴';

  @override
  String get measurementSiteArm => '위팔';

  @override
  String get measurementSiteThigh => '허벅지';

  @override
  String get measurementSiteCalf => '종아리';

  @override
  String get measurementSiteNeck => '목';

  @override
  String get bodyMetricHeight => '키';

  @override
  String get bodyMetricBodyFat => '체지방률';

  @override
  String get bodyMetricSkeletalMuscle => '골격근량';

  @override
  String get bodyMetricMuscleMass => '근육량';

  @override
  String get bodyMetricLeanMass => '제지방량';

  @override
  String get bodyMetricVisceralFat => '내장지방';

  @override
  String get bodyMetricBodyWater => '체수분';

  @override
  String get bodyMetricBoneMass => '골량';

  @override
  String get bodyMetricBasalMetabolicRate => '기초대사량';

  @override
  String get sexFemale => '여성';

  @override
  String get sexMale => '남성';

  @override
  String get sleepKindNight => '수면';

  @override
  String get sleepKindNap => '낮잠';

  @override
  String get sleepMeasureAsleep => '수면 시간';

  @override
  String get sleepMeasureInBed => '침대에 있던 시간';

  @override
  String get sleepStageInBed => '침대';

  @override
  String get sleepStageAwake => '깨어 있음';

  @override
  String get sleepStageAsleep => '수면';

  @override
  String get sleepStageCore => '코어';

  @override
  String get sleepStageDeep => '깊은 수면';

  @override
  String get sleepStageRem => '렘';

  @override
  String get overnightMeasureHeartRate => '심박수';

  @override
  String get overnightMeasureRespiratoryRate => '호흡수';

  @override
  String get overnightMeasureOxygenSaturation => '혈중 산소';

  @override
  String get overnightMeasureWristTemperature => '손목 온도';

  @override
  String get overnightMeasureSkinTemperatureChange => '피부 온도 변화';

  @override
  String get overnightMeasureHrvSdnn => '심박 변이도(SDNN)';

  @override
  String get overnightMeasureHrvRmssd => '심박 변이도(RMSSD)';

  @override
  String get overnightMeasureBreathingDisturbances => '호흡 장애';

  @override
  String get activityLevelSedentary => '주로 앉아 있음';

  @override
  String get activityLevelLight => '가벼움';

  @override
  String get activityLevelModerate => '보통';

  @override
  String get activityLevelActive => '활발함';

  @override
  String get activityLevelVeryActive => '매우 활발함';

  @override
  String get weightGoalLose => '감량';

  @override
  String get weightGoalRecomp => '바디 리컴포지션';

  @override
  String get weightGoalMaintain => '유지';

  @override
  String get weightGoalGain => '증량';

  @override
  String get targetInputWeight => '체중';

  @override
  String get targetInputHeight => '키';

  @override
  String get targetInputBirthYear => '출생 연도';

  @override
  String get targetInputSex => '성별';

  @override
  String get healthDataSleep => '수면';

  @override
  String get healthDataWeight => '체중';

  @override
  String get healthDataWaist => '허리';

  @override
  String get healthDataBody => '체성분';

  @override
  String get healthDataWorkouts => '운동';

  @override
  String get healthDataWater => '물';

  @override
  String get healthDataOvernight => '야간 데이터';

  @override
  String get healthDataActivity => '활동·심폐';

  @override
  String get recordCategoryTraining => '트레이닝';

  @override
  String get recordCategoryActivity => '활동';

  @override
  String get recordCategoryNutrition => '식단';

  @override
  String get recordCategoryBody => '신체';

  @override
  String get recordCategoryWellness => '수면·컨디션';

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
  String get aiProviderOpenAiCompatible => 'OpenAI 호환 엔드포인트';

  @override
  String get wellnessKindEnergy => '에너지';

  @override
  String get wellnessKindMood => '기분';

  @override
  String get wellnessKindSymptom => '증상';

  @override
  String get wellnessKindSleep => '수면의 질';

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
  String get bodyMetricUnitVisceralFat => '레벨';

  @override
  String get bodyMetricUnitBodyWater => '%';

  @override
  String get bodyMetricUnitBoneMass => 'kg';

  @override
  String get bodyMetricUnitBasalMetabolicRate => 'kcal';

  @override
  String get overnightMeasureUnitHeartRate => 'bpm';

  @override
  String get overnightMeasureUnitRespiratoryRate => '회/분';

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
  String get activityLevelDetailSedentary => '거의 운동하지 않음';

  @override
  String get activityLevelDetailLight => '주 1~3일 운동';

  @override
  String get activityLevelDetailModerate => '주 3~5일 운동';

  @override
  String get activityLevelDetailActive => '주 6~7일 운동';

  @override
  String get activityLevelDetailVeryActive => '육체노동 또는 하루 두 번 운동';

  @override
  String get aiOff => 'AI 꺼짐';

  @override
  String get aiDraftGenerate => '초안 만들기';

  @override
  String get aiDrafting => '만드는 중…';

  @override
  String get aiRewrite => '다시 입력';

  @override
  String deletedItem({required String item}) {
    return '$item 삭제됨';
  }

  @override
  String get recordTitle => '기록';

  @override
  String get commonEdit => '편집';

  @override
  String get bodyScaleEstimate => '체성분계 추정';

  @override
  String get notRated => '평가 없음';

  @override
  String weightSinceLast({required String change, required String date}) {
    return '지난번 대비 $change($date)';
  }

  @override
  String get logFilterAll => '전체';

  @override
  String pickMonthCurrent({required String month}) {
    return '월 선택, 현재 $month';
  }

  @override
  String get logSearch => '기록 검색';

  @override
  String get backToToday => '오늘로 이동';

  @override
  String get showAsCalendar => '달력으로 보기';

  @override
  String get showAsTimeline => '타임라인으로 보기';

  @override
  String get previousMonth => '이전 달';

  @override
  String get nextMonth => '다음 달';

  @override
  String noEntriesInMonth({required String month}) {
    return '$month 기록 없음';
  }

  @override
  String noEntriesMatching({required String query}) {
    return '\'$query\'와(과) 일치하는 기록이 없습니다.';
  }

  @override
  String get noEntriesThisDay => '이 날의 기록이 없습니다.';

  @override
  String get noEntriesSentence => '기록이 없습니다.';

  @override
  String get noImports => '가져온 기록이 없습니다.';

  @override
  String get importUndone => '실행 취소됨';

  @override
  String productsCount({required int count}) {
    return '상품 $count개';
  }

  @override
  String catalogueUpdated({required String catalogue, required String date}) {
    return '$catalogue $date 업데이트';
  }

  @override
  String healthReadFailed({required String error}) {
    return '읽기 실패: $error';
  }

  @override
  String get healthDisconnectKeeps => '연결을 끊어도 기록은 남습니다.';

  @override
  String get healthReadNow => '지금 읽기';

  @override
  String get healthDisconnect => '연결 끊기';

  @override
  String healthUnavailable({required String source}) {
    return '이 기기에 $source이(가) 없거나 버전이 너무 오래되었습니다.';
  }

  @override
  String get checking => '확인 중…';

  @override
  String get healthConnected => '연결됨';

  @override
  String healthConnect({required String source}) {
    return '$source 연결';
  }

  @override
  String get healthReading => '읽는 중…';

  @override
  String get healthAllowReading => '읽기 허용';

  @override
  String get healthAutoReadFailed => '마지막 자동 읽기 실패';

  @override
  String get healthReadFailedState => '읽기 실패';

  @override
  String get healthReadDone => '읽기 완료';

  @override
  String healthLastRead({required String when}) {
    return '마지막 읽기 $when';
  }

  @override
  String healthReads({required String kinds}) {
    return '읽는 항목: $kinds';
  }

  @override
  String get privacyLink => '개인정보 보호';

  @override
  String get checkingPermissions => '권한 확인 중…';

  @override
  String get healthPermissionsPath =>
      '권한은 \'설정 > 건강 > 데이터 접근 및 기기 > MISHIRUBE\'에서 변경합니다.';

  @override
  String get permissionAllowed => '허용됨';

  @override
  String get permissionDenied => '허용 안 됨';

  @override
  String get healthAllowOthers => '다른 항목 허용';

  @override
  String get healthNotConnected => '연결되지 않았습니다.';

  @override
  String healthNothingReadDenied({required String kinds}) {
    return '읽은 데이터가 없습니다. 허용 안 됨: $kinds.';
  }

  @override
  String get healthNothingRead => '읽은 데이터가 없습니다. 시스템 건강 설정에서 허용한 항목을 확인하세요.';

  @override
  String nightsCount({required int count}) {
    return '$count박';
  }

  @override
  String timesCount({required int count}) {
    return '$count회';
  }

  @override
  String healthUpdatedNights({required int count}) {
    return '수면 $count박 업데이트';
  }

  @override
  String healthKeptManual({required int count}) {
    return '$count박은 직접 입력한 기록 유지';
  }

  @override
  String healthNotAllowedList({required String kinds}) {
    return '허용 안 됨: $kinds';
  }

  @override
  String get noSleepRecords => '수면 기록 없음';

  @override
  String get logByHand => '직접 기록';

  @override
  String get sleepDebtSection => '수면 부채';

  @override
  String get napsSection => '낮잠';

  @override
  String get goalSection => '목표';

  @override
  String get sleepStagesSection => '수면 단계';

  @override
  String get notProvided => '제공되지 않음';

  @override
  String get fallAsleepTime => '잠들기까지';

  @override
  String aboutMinutes({required int minutes}) {
    return '약 $minutes분';
  }

  @override
  String get sleepEfficiency => '수면 효율';

  @override
  String get awakeAtNight => '야간 각성';

  @override
  String wokeTimes({required int count}) {
    return '$count회 깸';
  }

  @override
  String get continuitySection => '연속성';

  @override
  String get estimatedFromInBed => '기기의 침대 시간으로 추정';

  @override
  String get tonightSection => '오늘 밤';

  @override
  String get suggestedBedtime => '권장 취침';

  @override
  String wakeAt({required String time}) {
    return '$time 기상';
  }

  @override
  String get fromUsualWake => '평소 기상 시간 기준';

  @override
  String get afterTraining => '트레이닝 후';

  @override
  String get caffeineAfter2pm => '14:00 이후 카페인';

  @override
  String get mealAfter9pm => '21:00 이후 식사';

  @override
  String nightsVersus({required int withCount, required int withoutCount}) {
    return '$withCount박 대 $withoutCount박';
  }

  @override
  String get factorsSection => '영향 요인';

  @override
  String get factorsBasis => '최근 90일 평균 수면 시간 차이';

  @override
  String get correlationNotCause => '상관관계일 뿐 인과는 아님';

  @override
  String sleptLess({required String time}) {
    return '$time 덜 잠';
  }

  @override
  String sleptMore({required String time}) {
    return '$time 더 잠';
  }

  @override
  String get recordMethod => '기록 방법';

  @override
  String get withStages => '수면 단계 포함';

  @override
  String get elevated => '높음';

  @override
  String get notElevated => '높지 않음';

  @override
  String get sameAsUsual => '최근 28박 평균과 같음';

  @override
  String versusUsual({required String change}) {
    return '최근 28박 평균 대비 $change';
  }

  @override
  String goalMet({required String goal}) {
    return '목표 $goal · 달성';
  }

  @override
  String goalShort({required String goal, required String gap}) {
    return '목표 $goal · $gap 부족';
  }

  @override
  String get recordedSleep => '기록한 수면';

  @override
  String get deviceEstimate => '기기 추정';

  @override
  String withNapsTotal({required String time}) {
    return '낮잠 포함 $time';
  }

  @override
  String get chartRangeSixMonths => '6개월';

  @override
  String get noEntriesShort => '기록 없음';

  @override
  String get averageTimeAsleep => '평균 수면 시간';

  @override
  String get averageBedtime => '평균 취침';

  @override
  String get averageWake => '평균 기상';

  @override
  String get bedtimeSpread => '취침 시간 편차';

  @override
  String get wakeSpread => '기상 시간 편차';

  @override
  String plusMinusMinutes({required int minutes}) {
    return '±$minutes분';
  }

  @override
  String get nightsRecorded => '기록한 밤 수';

  @override
  String get bedAndWake => '취침과 기상';

  @override
  String averageStage({required String stage}) {
    return '평균 $stage';
  }

  @override
  String nightsWithStages({required int count}) {
    return '단계가 있는 밤 $count박';
  }

  @override
  String trendOverNights({required String measure, required int count}) {
    return '$measure 추이, $count박';
  }

  @override
  String get heartRateAsleep => '수면 중 심박수';

  @override
  String get respiratoryAsleep => '수면 중 호흡수';

  @override
  String everyMinutes({required int minutes}) {
    return '$minutes분마다';
  }

  @override
  String stageChartLabel({required String start, required String end}) {
    return '수면 단계 그래프, $start~$end';
  }

  @override
  String get wholeNight => '밤 전체';

  @override
  String scheduleChartLabel({required int count}) {
    return '취침과 기상 시간, $count박';
  }

  @override
  String get sleepGoal => '수면 목표';

  @override
  String get notSet => '설정 안 됨';

  @override
  String get bedtimeReminder => '취침 알림';

  @override
  String remindsAt({required String time}) {
    return '$time 알림';
  }

  @override
  String get clearGoal => '목표 지우기';

  @override
  String get trendSection => '추이';

  @override
  String get eachDaySection => '날마다';

  @override
  String get notEnoughEntries => '기록 부족';

  @override
  String highestLowest({required String high, required String low}) {
    return '최고 $high · 최저 $low';
  }

  @override
  String get preliminary => '잠정';

  @override
  String countedAt({required String hours}) {
    return '$hours 기준';
  }

  @override
  String goalValue({required String goal}) {
    return '목표 $goal';
  }

  @override
  String daysWithoutEntries({required int count}) {
    return '$count일 기록 없음';
  }

  @override
  String get hoursUnit => '시간';

  @override
  String lastFortnightExtra({required String hours}) {
    return '최근 14일 · $hours 더 잠';
  }

  @override
  String needsLoggedDays({required int minimum, required int recorded}) {
    return '최근 14일 중 $minimum일 기록 필요(현재 $recorded일)';
  }

  @override
  String lastWeekDebt({required String short, required String extra}) {
    return '최근 7일 $short · $extra 더';
  }

  @override
  String hoursValue({required String hours}) {
    return '$hours시간';
  }

  @override
  String shortBy({required String time}) {
    return '$time 부족';
  }

  @override
  String overBy({required String time}) {
    return '$time 초과';
  }

  @override
  String get photoTextUnavailable => '이 기기에서는 사진 속 글자를 읽을 수 없습니다.';

  @override
  String get photoNoBodyComposition => '사진에서 체성분 수치를 찾지 못했습니다.';

  @override
  String get photoNoGirths => '사진에서 둘레 수치를 찾지 못했습니다.';

  @override
  String valueRangeError({
    required String field,
    required String min,
    required String max,
    required String unit,
  }) {
    return '$field은(는) $min–$max $unit 사이로 입력하세요.';
  }

  @override
  String get fillAtLeastOne => '하나 이상 입력하세요.';

  @override
  String get fillAtLeastOneSite => '한 부위 이상 입력하세요.';

  @override
  String loggedValue({required String item, required String value}) {
    return '$item $value 기록됨';
  }

  @override
  String updatedValue({required String item, required String value}) {
    return '$item $value(으)로 업데이트됨';
  }

  @override
  String loggedItemsCount({required int count}) {
    return '$count개 기록됨';
  }

  @override
  String loggedSitesCount({required int count}) {
    return '$count개 부위 기록됨';
  }

  @override
  String get scanAction => '스캔';

  @override
  String get readingPhoto => '사진을 읽는 중…';

  @override
  String get scanBodyComposition => '사진으로 체성분 읽기';

  @override
  String get scanGirths => '사진으로 둘레 읽기';

  @override
  String lastReadingOn({required String value, required String date}) {
    return '지난번 $value · $date';
  }

  @override
  String photoReadCheck({required int count}) {
    return '사진에서 $count개 읽음, 확인하세요';
  }

  @override
  String get fillFromScale => '체지방계 표시대로 입력';

  @override
  String get noteLogged => '메모 기록됨';

  @override
  String get noteUpdated => '메모 업데이트됨';

  @override
  String get noteHint => '예: 저녁 모임, 평소보다 많이 먹음';

  @override
  String get sleepWakeBeforeBed => '기상 시간은 취침 이후여야 합니다';

  @override
  String get sleepOver24Hours => '한 번의 수면은 24시간을 넘을 수 없습니다';

  @override
  String get sleepWakeInFuture => '기상 시간은 현재보다 늦을 수 없습니다';

  @override
  String get sleepStartLabel => '취침';

  @override
  String get sleepEndLabel => '기상';

  @override
  String get qualityLabel => '질';

  @override
  String get sleepNoteHint => '예: 자기 전 커피, 밤중에 깸';

  @override
  String weightRangeError({required String min, required String max}) {
    return '$min–$max kg 사이 값을 입력하세요.';
  }

  @override
  String weightLogged({required String weight}) {
    return '$weight kg 기록됨';
  }

  @override
  String weightUpdated({required String weight}) {
    return '$weight kg(으)로 업데이트됨';
  }

  @override
  String get symptomSeverity => '불편 정도';

  @override
  String wellnessKindHow({required String kind}) {
    return '$kind은(는) 어떤가요?';
  }

  @override
  String get wellnessNoteHint => '예: 하루 종일 앉아 있어 허리가 뻐근함';

  @override
  String get bmiBandUnder => '저체중';

  @override
  String get bmiBandHealthy => '정상 체중';

  @override
  String get bmiBandOver => '과체중';

  @override
  String get bmiBandObese => '비만';

  @override
  String yearsCount({required int count}) {
    return '$count년';
  }

  @override
  String get logAction => '기록';

  @override
  String logItem({required String item}) {
    return '$item 기록';
  }

  @override
  String trendReadingsLabel({required String item, required int count}) {
    return '$item 추이, $count건';
  }

  @override
  String get bodyScaleCompareSame => '체지방계 추정치, 같은 기기로 비교';

  @override
  String get noWeightEntries => '체중 기록 없음';

  @override
  String get trendWeight => '추세 체중';

  @override
  String latestOn({required String date, required String value}) {
    return '최근 $date $value';
  }

  @override
  String weightChartLabel({required int count}) {
    return '체중 추이, $count회';
  }

  @override
  String weightChartIdle({required int count}) {
    return '선은 7일 평균 · 측정 $count회';
  }

  @override
  String trendValue({required String value}) {
    return '추세 $value';
  }

  @override
  String get allWeightEntries => '모든 체중 기록';

  @override
  String get buildSection => '체격';

  @override
  String get waistToHipRatio => '허리-엉덩이 비율';

  @override
  String get bmiStandardTaiwan => '대만 국민건강서 성인 기준';

  @override
  String get fatMass => '체지방량';

  @override
  String get waistAdviceTaiwan => '대만 국민건강서 권장 허리둘레: 남 < 90 cm, 여 < 80 cm';

  @override
  String get weeklyGoal => '주간 목표';

  @override
  String get weeklyGoalPaused => '주간 목표 일시중지됨';

  @override
  String weeklyGoalButtonLabel({required int active, required int target}) {
    return '이번 주 운동일 $active / $target, 주간 목표 보기';
  }

  @override
  String activeDaysPerWeek({required int count}) {
    return '주 $count일 운동';
  }

  @override
  String get adjustWeeklyGoal => '주간 목표 조정';

  @override
  String get weeklyGoalPrompt => '매주 운동할 날 수.';

  @override
  String get setWeeklyGoal => '주간 목표 설정';

  @override
  String get streakSection => '연속 달성';

  @override
  String get weekGoalMet => '이번 주 목표 달성';

  @override
  String get weekActivity => '이번 주 운동';

  @override
  String get notCountedInStreak => '연속 달성에 포함 안 됨';

  @override
  String activeDaysCount({required int count}) {
    return '운동일 $count일';
  }

  @override
  String activeDaysToGo({required int count}) {
    return '$count일 남음';
  }

  @override
  String get streakRestartsThisWeek => '이번 주 다시 시작';

  @override
  String get noStreakYet => '연속 달성 기록 없음';

  @override
  String lastStreak({required int previous, required int best}) {
    return '지난 연속 $previous주, 최고 $best주';
  }

  @override
  String get streakStartsAfterGoal => '한 주 목표를 달성하면 시작';

  @override
  String streakWeeks({required int count}) {
    return '$count주 연속 달성';
  }

  @override
  String streakPendingBest({required int best}) {
    return '이번 주 진행 중 · 최고 $best주';
  }

  @override
  String streakBest({required int best}) {
    return '최고 $best주';
  }

  @override
  String goalDayLabel({required int day}) {
    return '$day일';
  }

  @override
  String goalDayActive({required int day}) {
    return '$day일, 운동함';
  }

  @override
  String activeDaysFraction({required int active, required int target}) {
    return '운동일 $active / $target';
  }

  @override
  String goalFromThisWeek({required int count}) {
    return '이번 주부터 주 $count일';
  }

  @override
  String goalFromNextWeek({required int count}) {
    return '다음 주부터 주 $count일';
  }

  @override
  String get pauseWeeklyGoal => '주간 목표 일시중지';

  @override
  String get pauseWeeklyGoalMessage => '일시중지 기간의 주는 누적되지 않으며 연속 달성도 끊기지 않습니다.';

  @override
  String get pauseThisWeek => '이번 주 일시중지';

  @override
  String get pauseUntilResumed => '직접 재개할 때까지';

  @override
  String get activeDaysPerWeekQuestion => '주당 운동일 수';

  @override
  String suggestedDays({required int count}) {
    return '지난 4주 평균: 주 $count일';
  }

  @override
  String get goalStartSection => '시작 시점';

  @override
  String get fromNextWeek => '다음 주부터';

  @override
  String get fromNextWeekDetail => '이번 주는 기존 목표로 계산';

  @override
  String get applyThisWeek => '이번 주부터 적용';

  @override
  String get applyThisWeekDetail => '이번 주 다시 계산';

  @override
  String get pauseOrTurnOff => '일시중지 또는 끄기';

  @override
  String get weeklyGoalOffDetail => '끄면 목표와 연속 달성을 숨김';

  @override
  String get thisWeekPaused => '이번 주 일시중지됨';

  @override
  String thisWeekActiveDays({required int active, required int target}) {
    return '이번 주 운동일 $active / $target';
  }

  @override
  String get workoutInProgress => '운동 진행 중';

  @override
  String workoutCurrentSet({
    required String exercise,
    required int set,
    required int done,
  }) {
    return '$exercise · $set세트째 · $done세트 완료';
  }

  @override
  String get backToWorkout => '운동으로 돌아가기';

  @override
  String get thisSession => '이번 세션';

  @override
  String get setsCompleted => '완료 세트';

  @override
  String get exerciseProgress => '운동 진행';

  @override
  String get personalRecords => '개인 기록';

  @override
  String get otherEntries => '기타 기록';

  @override
  String get customiseToday => '홈 맞춤 설정';

  @override
  String get showAll => '모두 표시';

  @override
  String get nextStep => '다음 단계';

  @override
  String get includesEstimates => '추정치 포함';

  @override
  String partialMacros({required String macros}) {
    return '일부 기록에 $macros 수치가 없어 포함하지 않았습니다.';
  }

  @override
  String routineCompleted({required String name}) {
    return '$name 완료';
  }

  @override
  String get totalSets => '총 세트';

  @override
  String get exercisesLabel => '운동';

  @override
  String get todaySectionGlance => '오늘 지표';

  @override
  String get todaySectionActivity => '오늘 활동';

  @override
  String get todaySectionWeek => '이번 주';

  @override
  String get todaySectionRecords => '오늘 기록';

  @override
  String get todaySectionInsights => '주목할 점';

  @override
  String weekdayActive({required String weekday}) {
    return '$weekday, 운동함';
  }

  @override
  String allCount({required int count}) {
    return '전체 $count건';
  }

  @override
  String daysFraction({required int active, required int target}) {
    return '$active / $target일';
  }

  @override
  String weightChange7Days({required String change}) {
    return '7일 $change';
  }

  @override
  String trackingChangeRefused({required int count}) {
    return '이 기록 방식으로 $count회 기록되어 있어 바꾸면 이전 기록의 의미가 달라집니다. 다른 기록 방식을 쓰려면 새 운동을 만드세요.';
  }

  @override
  String get createCustomExercise => '사용자 운동 만들기';

  @override
  String get editExercise => '운동 편집';

  @override
  String exerciseOfSource({required String source}) {
    return '$source 운동';
  }

  @override
  String get createAndAdd => '만들고 추가';

  @override
  String get nameSection => '이름';

  @override
  String get exerciseNameHint => '예: 덤벨 벤치 프레스';

  @override
  String get trackingTypeSection => '기록 방식';

  @override
  String get trackingTypeLocked => '만든 후에는 호환되지 않는 기록 방식으로 바꿀 수 없습니다.';

  @override
  String get primaryMuscleOrPattern => '주요 근육 또는 동작 패턴';

  @override
  String get equipmentSection => '기구';

  @override
  String get equipmentAny => '지정 안 함';

  @override
  String get possibleDuplicate => '이미 있는 운동일 수 있습니다';

  @override
  String entriesCount({required int count}) {
    return '기록 $count건';
  }

  @override
  String get useThis => '이것 사용';

  @override
  String get duplicateAdvice => '기존 운동을 고르면 기록과 개인 기록이 나뉘지 않습니다.';

  @override
  String exerciseDemoLabel({required String name, required int count}) {
    return '$name 시범, 자세 $count개';
  }

  @override
  String get playing => '재생 중';

  @override
  String get exerciseDemoCredit =>
      '이미지: Workout Guide / Everkinetic · CC BY-SA 4.0';

  @override
  String get myAliases => '내 별칭';

  @override
  String get aliasesHint => '쉼표로 구분, 예: 스쿼트, squat';

  @override
  String get aliasesUpdated => '별칭 업데이트됨';

  @override
  String get cannotMergeSelf => '자기 자신과 병합할 수 없습니다';

  @override
  String mergeTitle({required String duplicate, required String canonical}) {
    return '\'$duplicate\'을(를) \'$canonical\'에 병합할까요?';
  }

  @override
  String mergeMessage({required String canonical}) {
    return '이전 기록은 \'$canonical\'(으)로 집계되고 이 운동은 선택 목록에서 사라집니다. 기록 내용은 바뀌지 않지만 병합은 되돌릴 수 없습니다.';
  }

  @override
  String mergeInto({required String canonical}) {
    return '\'$canonical\'에 병합';
  }

  @override
  String mergedInto({required String canonical}) {
    return '\'$canonical\'에 병합됨';
  }

  @override
  String get addThisExercise => '이 운동 추가';

  @override
  String get otherVariations => '같은 동작의 다른 방법';

  @override
  String get cuesSection => '핵심 팁';

  @override
  String get removeFavorite => '즐겨찾기 해제';

  @override
  String get addFavorite => '즐겨찾기 추가';

  @override
  String get favoriteRemoved => '즐겨찾기 해제됨';

  @override
  String get favoriteAdded => '즐겨찾기에 추가됨';

  @override
  String get editExerciseDetail => '이름, 기구, 부위';

  @override
  String get editMyAliases => '내 별칭 편집';

  @override
  String builtInNames({required String names}) {
    return '기본 이름: $names';
  }

  @override
  String get mergeIntoAnother => '다른 운동에 병합';

  @override
  String get mergeIntoAnotherDetail => '중복 생성 시 기록을 한 운동으로 합침';

  @override
  String get unhide => '숨김 해제';

  @override
  String get hideExercise => '이 운동 숨기기';

  @override
  String unhidden({required String name}) {
    return '\'$name\' 숨김 해제됨';
  }

  @override
  String hidden({required String name}) {
    return '\'$name\' 숨김';
  }

  @override
  String get bodyPartLabel => '부위';

  @override
  String get primaryMuscles => '주 근육';

  @override
  String get secondaryMuscles => '보조 근육';

  @override
  String get movementPatternLabel => '동작 패턴';

  @override
  String get lateralityLabel => '좌우';

  @override
  String get lastWorkingSet => '지난 본세트';

  @override
  String get estimatedMax => '추정 최대 중량';

  @override
  String get sessionsUnit => '회';

  @override
  String get trainingEntries => '운동 기록';

  @override
  String estimatedMaxTrend({required int count}) {
    return '추정 최대 중량 추이, $count회';
  }

  @override
  String get epleyEstimate => 'Epley 추정';

  @override
  String relativeLoadPercent({required int percent}) {
    return '상대 부하 $percent%';
  }

  @override
  String get last90Days => '최근 90일';

  @override
  String get filterTitle => '필터';

  @override
  String filtersApplied({required int count}) {
    return '필터 $count개 적용됨';
  }

  @override
  String showExercises({required int count}) {
    return '운동 $count개 보기';
  }

  @override
  String get clearAll => '모두 지우기';

  @override
  String wholeRegion({required String region}) {
    return '$region 전체';
  }

  @override
  String get sourceLabel => '출처';

  @override
  String get pickerTabRecent => '최근 사용';

  @override
  String get pickerTabFavorites => '즐겨찾기';

  @override
  String get pickerTabHomeGym => '내 헬스장';

  @override
  String get pickerTabAll => '모든 운동';

  @override
  String get pickerAddToRoutine => '루틴에 추가';

  @override
  String get pickerAddToWorkout => '진행 중에 추가';

  @override
  String get pickerAddToEntry => '기록에 추가';

  @override
  String get pickerBrowse => '모든 운동 둘러보기 및 검색';

  @override
  String get pickerSingle => '운동 하나 선택';

  @override
  String pickerPurposeFor({required String purpose, required String name}) {
    return '$purpose \'$name\'';
  }

  @override
  String discardSelectedTitle({required int count}) {
    return '선택한 운동 $count개를 버릴까요?';
  }

  @override
  String get discardSelected => '선택 버리기';

  @override
  String get keepChoosing => '계속 선택';

  @override
  String get exerciseLibrary => '운동 라이브러리';

  @override
  String get chooseExercise => '운동 선택';

  @override
  String get addExercises => '운동 추가';

  @override
  String get cantFindCreate => '없나요? 사용자 운동 만들기';

  @override
  String get searchExercisesHint => '운동, 별칭, 기구 검색…';

  @override
  String get clearAction => '지우기';

  @override
  String daysAgo({required int count}) {
    return '$count일 전';
  }

  @override
  String aboutItem({required String name}) {
    return '$name 정보';
  }

  @override
  String get selectionOrderHint => '추가 순서 · 탭하여 제거';

  @override
  String removeNumbered({required int index, required String name}) {
    return '$index번째 제거: $name';
  }

  @override
  String addExercisesCount({required int count}) {
    return '운동 $count개 추가';
  }

  @override
  String get noMatchingExercises => '일치하는 운동 없음';

  @override
  String equipmentFilterHint({required String equipment}) {
    return '\'기구: $equipment\' 필터 적용 중. 다른 기구의 운동일 수 있습니다.';
  }

  @override
  String get searchAgainHint => '다른 표현, 영어 이름 또는 별칭으로 다시 시도하세요.';

  @override
  String get removeEquipmentFilter => '기구 필터 제거 후 다시 찾기';

  @override
  String get similarExercises => '비슷한 운동';

  @override
  String createNamed({required String name}) {
    return '\'$name\' 만들기';
  }

  @override
  String estimatedMaxValue({required int weight}) {
    return '추정 최대 $weight kg';
  }

  @override
  String lastSetOn({required String date, required String set}) {
    return '지난번 $date $set';
  }

  @override
  String get volumeTitle => '훈련량';

  @override
  String get notEnoughWorkouts => '운동 기록이 부족합니다.';

  @override
  String volumeOf({required String exercise}) {
    return '$exercise 훈련량';
  }

  @override
  String insightWeeks({required int weeks}) {
    return '주목할 점 · 최근 $weeks주';
  }

  @override
  String volumeSteady({required int sets, required String estimate}) {
    return '주간 본세트는 $sets세트로 유지, 추정 최대 중량 $estimate.';
  }

  @override
  String get notYetEstimable => '아직 추정 불가';

  @override
  String get basisSection => '근거';

  @override
  String weeklySetsFrom({required int count}) {
    return '운동 기록 $count회의 주간 본세트.';
  }

  @override
  String get dataQualitySection => '데이터 품질 및 완전성';

  @override
  String workoutsAllLogged({required int count}) {
    return '운동 $count회 모두 기록됨';
  }

  @override
  String get weightRepsManual => '중량과 횟수는 직접 입력';

  @override
  String get timeRangeSection => '기간';

  @override
  String fullWeeks({required int count}) {
    return '완전한 $count주';
  }

  @override
  String get actionsSection => '할 수 있는 일';

  @override
  String volumeDropped({required int sets}) {
    return '주간 세트가 기간 초보다 줄었습니다. 계속 발전하려면 $sets세트 정도로 되돌리세요.';
  }

  @override
  String get volumeStable => '세트 수가 안정적입니다. 계속 발전하려면 주간 세트나 중량을 조금 늘리세요.';

  @override
  String adjustRoutineSets({required String routine}) {
    return '\'$routine\' 세트 조정';
  }

  @override
  String get notMedicalAdvice => '운동 기록에 대한 설명이며 의료 조언이 아닙니다.';

  @override
  String get viewRawEntries => '이 기간의 기록 보기';

  @override
  String get noWorkingSets => '본세트 기록 없음';

  @override
  String muscleWeeklySets({required String muscle, required int sets}) {
    return '$muscle 주 $sets세트';
  }

  @override
  String muscleScaleLabel({required int top}) {
    return '색상 범위 0–$top세트 이상';
  }

  @override
  String get setsPerWeek => '세트 / 주';

  @override
  String get muscleMapLabel => '근육별 훈련량 인체 지도, 수치는 아래에';

  @override
  String get musclesTitle => '근육';

  @override
  String get weeklySetsLast8 => '주간 본세트 · 최근 8주';

  @override
  String get setsThisWeekUnit => '세트 · 이번 주';

  @override
  String priorWeeksSets({required int weeks, required String sets}) {
    return '이전 $weeks주 $sets세트';
  }

  @override
  String muscleSetsChart({required String muscle, required String sets}) {
    return '$muscle 주간 세트, $sets';
  }

  @override
  String heaviestSet({required String set, required String date}) {
    return '최고 중량 $set · $date';
  }

  @override
  String estimatedMaxOn({required int weight, required String date}) {
    return '추정 최대 $weight kg · $date';
  }

  @override
  String get last4Weeks => '최근 4주';

  @override
  String monthsCount({required int count}) {
    return '$count개월';
  }

  @override
  String get weeklySetsTitle => '주간 세트';

  @override
  String get last8Weeks => '최근 8주';

  @override
  String get weeklyWorkouts => '주간 운동';

  @override
  String get weeklyActivities => '주간 활동';

  @override
  String get timesThisWeekUnit => '회 · 이번 주';

  @override
  String get noActivityEntries => '활동 기록 없음';

  @override
  String minutesVersusUsual({required int minutes, required int usual}) {
    return '$minutes분 · 평소 $usual분';
  }

  @override
  String get trendDomainBody => '신체';

  @override
  String get trendDomainTraining => '운동';

  @override
  String get trendDomainSleep => '수면';

  @override
  String get trendDomainNutrition => '식단';

  @override
  String get trendDomainActivity => '활동';

  @override
  String areaTrend({required String area}) {
    return '$area 추이';
  }

  @override
  String sleepTimesAverage({required String bedtime, required String wake}) {
    return '취침 $bedtime · 기상 $wake';
  }

  @override
  String get last4WeeksAverage => '최근 4주 평균';

  @override
  String get weekdaySection => '요일';

  @override
  String get otherAreasSection => '같은 기간 다른 영역';

  @override
  String get dailyEntries => '일별 기록';

  @override
  String perWeekTimes({required String count}) {
    return '주 $count회';
  }

  @override
  String stepsValue({required String steps}) {
    return '$steps걸음';
  }

  @override
  String timesValue({required String count}) {
    return '$count회';
  }

  @override
  String weekFrom({required String date}) {
    return '$date부터';
  }

  @override
  String get last13Weeks => '최근 13주';

  @override
  String get pastYear => '지난 1년';

  @override
  String get prior12Weeks => '이전 12주';

  @override
  String periodAverage({required String period}) {
    return '$period 평균';
  }

  @override
  String get weeklyCount => '주간 횟수';

  @override
  String get weeklyAverage => '주간 평균';

  @override
  String get weeklyTotal => '주간 합계';

  @override
  String daysLoggedPerWeek({required String days}) {
    return '최근 4주 주 평균 $days일 기록';
  }

  @override
  String get scaleWeight => '체중계 체중';

  @override
  String get weeklyVolume => '주간 훈련량';

  @override
  String get restingHeartRate => '안정 시 심박수';

  @override
  String get weightAndNutrition => '체중과 식단';

  @override
  String get energyBalance => '에너지 균형';

  @override
  String energyNeeds({
    required int window,
    required int foodDays,
    required int weighings,
    required int currentFood,
    required int currentWeighings,
  }) {
    return '최근 $window일 중 완전한 식단 $foodDays일과 체중 $weighings회 필요(현재 $currentFood일, $currentWeighings회)';
  }

  @override
  String proteinNeeds({required int window, required int days}) {
    return '최근 $window일 중 완전한 식단과 체중 $days일 필요';
  }

  @override
  String get muscleSetsTitle => '근육별 세트';

  @override
  String muscleSetsNeeds({required int count}) {
    return '최근 4주 동안 최소 $count회 운동 필요';
  }

  @override
  String get possibleRelations => '가능한 연관성';

  @override
  String get longRunSection => '장기 추이';

  @override
  String actualExpenditure({required String kcal}) {
    return '실제 소비 약 $kcal kcal/일';
  }

  @override
  String intakeDeficit({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '최근 $window일 평균 섭취 $intake kcal, 하루 $balance kcal 적자';
  }

  @override
  String intakeSurplus({
    required int window,
    required String intake,
    required String balance,
  }) {
    return '최근 $window일 평균 섭취 $intake kcal, 하루 $balance kcal 잉여';
  }

  @override
  String weightForecast({
    required String change,
    required int weeks,
    required String forecast,
  }) {
    return '추세 체중 주 $change kg, $weeks주 후 약 $forecast kg';
  }

  @override
  String foodDaysWeighings({required int foodDays, required int weighings}) {
    return '완전한 식단 $foodDays일 · 체중 $weighings회';
  }

  @override
  String get intakeUnderlogged =>
      '추정 소비가 안정 시 대사량보다 낮아 기록한 섭취량이 실제보다 적을 수 있습니다.';

  @override
  String get estimatedFromEntries => '기록으로 추정';

  @override
  String weekendEatsMore({required String kcal}) {
    return '주말에 하루 $kcal kcal 더 먹음';
  }

  @override
  String weekendEatsLess({required String kcal}) {
    return '주말에 하루 $kcal kcal 덜 먹음';
  }

  @override
  String weekdayWeekendKcal({
    required String weekday,
    required String weekend,
  }) {
    return '평일 $weekday kcal · 주말 $weekend kcal';
  }

  @override
  String get offsetsAllDeficit => '평일 적자를 모두 상쇄';

  @override
  String offsetsDeficitShare({required int percent}) {
    return '평일 적자의 약 $percent% 상쇄';
  }

  @override
  String weekdaysWeekends({
    required int window,
    required int weekdays,
    required int weekends,
  }) {
    return '최근 $window일, 평일 $weekdays일, 주말 $weekends일';
  }

  @override
  String proteinMet({required String target}) {
    return '단백질 $target g/kg 달성';
  }

  @override
  String proteinShort({required int grams}) {
    return '단백질 하루 약 $grams g 부족';
  }

  @override
  String trainingRestProtein({required String trained, required String rest}) {
    return '운동일 $trained · 휴식일 $rest g/kg';
  }

  @override
  String proteinBasis({
    required String weight,
    required String target,
    required int days,
  }) {
    return '$weight kg, 목표 $target g/kg 기준 · 완전한 식단 $days일';
  }

  @override
  String allMusclesEnough({required int target}) {
    return '운동한 근육 모두 주 $target세트 이상';
  }

  @override
  String muscleOnlySets({required String muscle, required int sets}) {
    return '$muscle 주 $sets세트뿐';
  }

  @override
  String underSets({required int target, required String muscles}) {
    return '$target세트 미만: $muscles';
  }

  @override
  String atLeastSets({required int target, required String muscles}) {
    return '$target세트 이상: $muscles';
  }

  @override
  String pairRatio({
    required String first,
    required String second,
    required int firstSets,
    required int secondSets,
  }) {
    return '$first 대 $second $firstSets : $secondSets세트';
  }

  @override
  String get musclePush => '밀기';

  @override
  String get musclePull => '당기기';

  @override
  String get muscleSetsBasis => '최근 4주 주간 세트, 주 근육만';

  @override
  String weekendWakeLater({required String time}) {
    return '주말에 $time 늦게 기상';
  }

  @override
  String weekendWakeEarlier({required String time}) {
    return '주말에 $time 일찍 기상';
  }

  @override
  String weekdayWeekendWake({
    required String weekday,
    required String weekend,
  }) {
    return '평일 $weekday · 주말 $weekend 기상';
  }

  @override
  String get correlationCaveat => '상관관계이지 인과관계는 아님';

  @override
  String get muscleFigureMale => '남성';

  @override
  String get muscleFigureFemale => '여성';

  @override
  String get workoutDiscarded => '운동을 버렸습니다';

  @override
  String get endWorkout => '운동 종료';

  @override
  String get addExercise => '운동 추가';

  @override
  String get notFilled => '입력 안 됨';

  @override
  String get startExercising => '시작';

  @override
  String get finishWorkout => '운동 완료';

  @override
  String personalRecordSet({required String set}) {
    return '개인 기록 · $set';
  }

  @override
  String get totalShort => '총';

  @override
  String get notStarted => '시작 안 함';

  @override
  String get totalVolume => '총 훈련량';

  @override
  String versusLastTime({required String change}) {
    return '지난번 대비 $change';
  }

  @override
  String setsOfTotal({required int done, required int total}) {
    return '$done / $total세트';
  }

  @override
  String get restTitle => '휴식';

  @override
  String get rest30More => '30초 더 쉬기';

  @override
  String get skipRest => '휴식 건너뛰기';

  @override
  String get elapsedTime => '시간';

  @override
  String get workoutNotesTitle => '이번 운동 메모';

  @override
  String get workoutNotesHint => '예: 잠을 못 자서 악력이 먼저 한계';

  @override
  String get addWarmupSets => '워밍업 세트 추가';

  @override
  String get addDropSet => '드롭 세트 추가';

  @override
  String get addFailureSet => '실패 세트 추가';

  @override
  String get replaceExercise => '이 운동 교체';

  @override
  String get removeFromWorkout => '이번 운동에서 제거';

  @override
  String get superset => '슈퍼세트';

  @override
  String optionsFor({required String name}) {
    return '$name 옵션';
  }

  @override
  String volumeValue({required String volume}) {
    return '훈련량 $volume kg';
  }

  @override
  String lastSetShort({required String date, required String set}) {
    return '지난번 $date · $set';
  }

  @override
  String get loadPrevious => '불러오기';

  @override
  String get loadPreviousLabel => '지난번 중량과 횟수 입력';

  @override
  String get quickFill => '빠른 입력';

  @override
  String get quickFillLabel => '첫 세트로 나머지 채우기';

  @override
  String get setColumn => '세트';

  @override
  String get repsColumn => '회';

  @override
  String get removeSet => '세트 삭제';

  @override
  String get addSet => '세트 추가';

  @override
  String editItem({required String item}) {
    return '$item 편집';
  }

  @override
  String setWeight({required String set}) {
    return '$set 중량';
  }

  @override
  String setReps({required String set}) {
    return '$set 횟수';
  }

  @override
  String setDone({required String set}) {
    return '$set 완료';
  }

  @override
  String removedNamed({required String name}) {
    return '\'$name\' 제거됨';
  }

  @override
  String get routineName => '루틴 이름';

  @override
  String deleteNamedTitle({required String name}) {
    return '\'$name\'을(를) 삭제할까요?';
  }

  @override
  String get routineDeleteKeeps => '완료한 운동 기록은 유지됩니다.';

  @override
  String get deleteRoutine => '이 루틴 삭제';

  @override
  String deletedNamed({required String name}) {
    return '\'$name\' 삭제됨';
  }

  @override
  String aboutMinutesShort({required int minutes}) {
    return '약 $minutes분';
  }

  @override
  String get startWorkout => '운동 시작';

  @override
  String get activityBlocksWorkout => '활동이 진행 중입니다. 운동을 시작하려면 먼저 종료하세요';

  @override
  String get plannedExercises => '계획한 운동';

  @override
  String get soreMusclesToday => '오늘 뻐근한 근육';

  @override
  String get recentlyDone => '최근 완료';

  @override
  String setsAndMinutes({required int sets, required int minutes}) {
    return '$sets세트 · $minutes분';
  }

  @override
  String get rename => '이름 변경';

  @override
  String get moveUp => '위로 이동';

  @override
  String get moveDown => '아래로 이동';

  @override
  String get joinSuperset => '다음 운동과 슈퍼세트';

  @override
  String get leaveSuperset => '슈퍼세트 해제';

  @override
  String get removeAction => '제거';

  @override
  String get eachSide => '한쪽';

  @override
  String get oneSetLessToday => '오늘 1세트 적게';

  @override
  String get loadPreviousFill => '지난번 중량과 횟수로 채우기';

  @override
  String get myRoutines => '내 루틴';

  @override
  String get loadFromHistory => '기록에서';

  @override
  String startWorkoutCount({required int count}) {
    return '운동 시작($count개 운동)';
  }

  @override
  String get describeInWords => '한 줄 입력';

  @override
  String get addExercisesByHand => '직접 운동 추가';

  @override
  String get deleteAction => '삭제';

  @override
  String deleteNamed({required String name}) {
    return '\'$name\' 삭제';
  }

  @override
  String get newRoutine => '새 루틴';

  @override
  String get noWorkouts => '운동 기록 없음';

  @override
  String get selectAll => '모두 선택';

  @override
  String pastSet({
    required int number,
    required String weight,
    required int reps,
  }) {
    return '$number세트 $weight kg $reps회';
  }

  @override
  String routineSummary({required int exercises, required int sets}) {
    return '운동 $exercises개 · $sets세트';
  }

  @override
  String get saveAsRoutine => '루틴으로 저장';

  @override
  String get describeWorkoutHint =>
      '예:\n바벨 스쿼트 4×8 60kg\n벤치 프레스 10회 3세트 40kg\n풀업 3x8';

  @override
  String get noExercisesRead => '운동을 찾지 못함';

  @override
  String removeNamed({required String name}) {
    return '\'$name\' 제거';
  }

  @override
  String get exerciseNotFound => '운동을 찾을 수 없음';

  @override
  String setsTimesReps({
    required int sets,
    required int reps,
    required String weight,
  }) {
    return '$sets세트 × $reps회 · $weight kg';
  }

  @override
  String setsSameWeight({
    required int sets,
    required String weight,
    required String reps,
  }) {
    return '$sets세트 · $weight kg × $reps회';
  }

  @override
  String get editWorkout => '운동 편집';

  @override
  String get timeSection => '시간';

  @override
  String get durationLabel => '시간';

  @override
  String savedAsRoutine({required String name}) {
    return '\'$name\' 루틴으로 저장됨';
  }

  @override
  String get keepAsIs => '그대로 유지';

  @override
  String get applyAction => '적용';

  @override
  String get progressionIncrease => '증량';

  @override
  String get progressionHold => '유지';

  @override
  String get progressionDeload => '한 단계 낮춤';

  @override
  String get nextTimeSuggestions => '다음 제안';

  @override
  String changedTo({required String name, required String weight}) {
    return '$name $weight kg로 변경';
  }

  @override
  String decreaseBy({required String amount}) {
    return '$amount 줄이기';
  }

  @override
  String increaseBy({required String amount}) {
    return '$amount 늘리기';
  }

  @override
  String get oneRepLess => '1회 줄이기';

  @override
  String get oneRepMore => '1회 늘리기';

  @override
  String get notLogged => '기록 안 함';

  @override
  String get deleteThisSet => '이 세트 삭제';

  @override
  String get platesImpossible => '원판으로 이 무게를 만들 수 없음';

  @override
  String get emptyBar => '빈 바';

  @override
  String platesPerSide({required String plates}) {
    return '한쪽 $plates';
  }

  @override
  String setNumberWeight({required int number}) {
    return '$number세트 중량';
  }

  @override
  String setNumberReps({required int number}) {
    return '$number세트 횟수';
  }

  @override
  String get replaceTodayOnly => '오늘만 교체';

  @override
  String get replaceTodayOnlyDetail => '이번에만 새 운동 사용';

  @override
  String get replaceInRoutine => '루틴도 업데이트';

  @override
  String get replaceInRoutineDetail => '앞으로 새 운동 사용';

  @override
  String replacedToday({required String name}) {
    return '오늘은 \'$name\' 진행';
  }

  @override
  String replacedInRoutine({required String routine, required String name}) {
    return '오늘부터 \'$routine\'에서 \'$name\' 진행';
  }

  @override
  String replacePattern({required String pattern}) {
    return '$pattern 교체';
  }

  @override
  String todaysExerciseNumber({required String routine, required int number}) {
    return '오늘의 \'$routine\' · $number번째 운동';
  }

  @override
  String get replaceAction => '교체';

  @override
  String get candidateExercises => '후보 운동';

  @override
  String get chooseFromAll => '모든 운동에서 선택';

  @override
  String get applyScope => '적용 범위';

  @override
  String equipmentChangeWarning({required String from, required String to}) {
    return '$from에서 $to(으)로 신뢰할 만한 중량 환산이 없습니다. 세트, 횟수, RIR은 유지되며 중량은 다시 설정하세요.';
  }

  @override
  String get exerciseInfo => '운동 설명';

  @override
  String get noFinishedWorkout => '완료한 운동 없음';

  @override
  String get totalAmount => '총량';

  @override
  String get workloadSection => '이번 부하';

  @override
  String get trainedAreas => '운동 부위';

  @override
  String get muscleSetsLast7 => '최근 7일 근육별 세트';

  @override
  String get editThisEntry => '이 기록 편집';

  @override
  String get volumeSame => '총량 지난번과 동일';

  @override
  String volumeChangePercent({required String change}) {
    return '총량 지난번 대비 $change%';
  }

  @override
  String setsAndVolume({required int sets, required String volume}) {
    return '$sets세트 · $volume kg';
  }

  @override
  String get qualityConfirmed => '확인됨';

  @override
  String get qualityPortionEstimated => '분량 추정';

  @override
  String get qualityCustomFood => '사용자 음식';

  @override
  String get qualityQuickLog => '빠른 기록';

  @override
  String get qualityAiEstimate => 'AI 추정';

  @override
  String qualityAiEstimateBy({required String source}) {
    return '$source 추정';
  }

  @override
  String get nutritionLabel => '영양성분표';

  @override
  String photoItemsCount({required int count}) {
    return '사진에 $count개 항목';
  }

  @override
  String get mergeIntoOneFood => '한 음식으로 합치기';

  @override
  String get logEachItem => '항목별 기록';

  @override
  String get nutrientNegative => '영양소는 음수일 수 없습니다.';

  @override
  String updatedNamed({required String name}) {
    return '\'$name\' 업데이트됨';
  }

  @override
  String get editThisMeal => '이 식사 편집';

  @override
  String get newFood => '음식 추가';

  @override
  String get editFood => '음식 편집';

  @override
  String get scanFoodOrLabel => '음식 또는 영양성분표 스캔';

  @override
  String get createOnly => '만들기만';

  @override
  String get createAndLog => '만들고 기록';

  @override
  String labelReadBy({required String provider, required String model}) {
    return '$provider($model)가 읽은 수치입니다. 포장과 대조하세요.';
  }

  @override
  String photoEstimatedBy({required String provider, required String model}) {
    return '$provider($model)가 사진으로 추정한 수치입니다. 확인하세요.';
  }

  @override
  String get foodNameHint => '예: 닭가슴살';

  @override
  String get mealTypeOptional => '식사 구분';

  @override
  String get saveToLibrary => '라이브러리에 저장';

  @override
  String get cupSize => '컵 사이즈';

  @override
  String get cupSizeHint => '예: Tall';

  @override
  String get brandLabel => '브랜드';

  @override
  String get brandHint => '예: 브랜드명';

  @override
  String get foodOrDrink => '음식 또는 음료';

  @override
  String get volumeLabel => '용량';

  @override
  String get portionSection => '분량';

  @override
  String get portionHint => '예: 한 그릇';

  @override
  String get newCupSize => '컵 사이즈 추가';

  @override
  String get nutrientsSection => '영양소';

  @override
  String per100Unit({required String unit}) {
    return '100$unit당';
  }

  @override
  String get perServingTotal => '1회분 합계';

  @override
  String get abvLabel => '알코올 도수';

  @override
  String get deleteThisMeal => '이 식사 삭제';

  @override
  String get countryTW => '대만';

  @override
  String get countryJP => '일본';

  @override
  String get countryUS => '미국';

  @override
  String get countryEU => 'EU';

  @override
  String get countryAU => '호주';

  @override
  String get countryNZ => '뉴질랜드';

  @override
  String get countryKR => '한국';

  @override
  String get countryCN => '중국';

  @override
  String get countryCA => '캐나다';

  @override
  String brandInCountry({required String brand, required String country}) {
    return '$brand($country)';
  }

  @override
  String get officialData => '공식 데이터';

  @override
  String updatedOn({required String date}) {
    return '업데이트 $date';
  }

  @override
  String get foodScopeAll => '전체';

  @override
  String get foodScopeRecent => '최근';

  @override
  String get foodScopeStarred => '즐겨찾기';

  @override
  String get foodScopeOwn => '내 음식';

  @override
  String get foodScopeBrands => '브랜드';

  @override
  String loggedNamed({required String name}) {
    return '\'$name\' 기록됨';
  }

  @override
  String get loggedToast => '기록됨';

  @override
  String mealTypeHeaderLabel({required String meal}) {
    return '식사 구분, 현재 $meal';
  }

  @override
  String get unspecified => '지정 안 함';

  @override
  String get searchFoodHint => '음식 또는 브랜드 검색';

  @override
  String get takePhotoAction => '사진';

  @override
  String get recentMealsSection => '최근 식사';

  @override
  String get noFoods => '음식 없음';

  @override
  String get eatenFoods => '먹은 음식';

  @override
  String get noRecentFoods => '최근 먹은 음식이 없습니다.';

  @override
  String get starredFoods => '즐겨찾는 음식';

  @override
  String get starredMeals => '즐겨찾는 식사';

  @override
  String get noFavorites => '즐겨찾기가 없습니다.';

  @override
  String get noOwnFoods => '내 음식 없음';

  @override
  String get noBuiltInBrands => '기본 제공 체인이 없습니다.';

  @override
  String viewFullMenu({required String brand}) {
    return '$brand · 전체 메뉴 보기';
  }

  @override
  String get noMatchingItems => '일치 항목 없음';

  @override
  String get notFoundQuestion => '없나요?';

  @override
  String get purposeSection => '목적';

  @override
  String mergedCount({required int count}) {
    return '$count건 병합됨';
  }

  @override
  String removedWater({required int millilitres}) {
    return '물 $millilitres mL 제거됨';
  }

  @override
  String get splitDone => '개별 기록으로 분리됨';

  @override
  String get mergeAction => '병합';

  @override
  String get mergeEntries => '기록 병합';

  @override
  String get cancelMerge => '병합 취소';

  @override
  String get mergeIntoMeal => '한 끼로 병합';

  @override
  String mergeCountIntoMeal({required int count}) {
    return '$count건을 한 끼로 병합';
  }

  @override
  String get setGoal => '목표 설정';

  @override
  String get changeAction => '변경';

  @override
  String get dailyIndicators => '일일 지표';

  @override
  String get mealsSection => '식사';

  @override
  String get mealShare => '비율';

  @override
  String get mealShareHide => '비율 숨기기';

  @override
  String get noMealsThisDay => '이날 기록된 식사 없음';

  @override
  String get waterSection => '물';

  @override
  String removeWaterAt({required String time}) {
    return '$time 물 제거';
  }

  @override
  String get otherNutrients => '기타 영양소';

  @override
  String itemsCountShort({required int count}) {
    return '$count개 항목';
  }

  @override
  String get splitIntoEntry => '개별 기록으로 분리';

  @override
  String entriesWithoutKcal({required int count}) {
    return '$count건 칼로리 없음, 실제로는 더 많음';
  }

  @override
  String eatenKcal({required String kcal}) {
    return '$kcal kcal 섭취';
  }

  @override
  String eatenOfTarget({required String kcal, required String target}) {
    return '$kcal kcal 섭취, 목표 $target kcal';
  }

  @override
  String get eatenKcalTitle => '섭취 kcal';

  @override
  String get remainingKcalTitle => '남은 kcal';

  @override
  String get overKcalTitle => '초과 kcal';

  @override
  String get workedOut => '계산값';

  @override
  String get caffeineRemaining => '추정 잔류 카페인';

  @override
  String halfLifeBasis({required String hours}) {
    return '반감기 $hours시간 기준';
  }

  @override
  String caffeineReference({required String mg}) {
    return '취침 참고 $mg mg';
  }

  @override
  String get last24Hours => '최근 24시간';

  @override
  String workedOutValue({required String value}) {
    return '$value · 계산값';
  }

  @override
  String caffeineValue({required String mg}) {
    return '카페인 $mg mg';
  }

  @override
  String oneServingIs({required String serving}) {
    return '1회분 = $serving';
  }

  @override
  String get starred => '저장됨';

  @override
  String get starAction => '저장';

  @override
  String get starThisFood => '이 음식 즐겨찾기';

  @override
  String get editThisFood => '이 음식 편집';

  @override
  String addPortion({required String portion}) {
    return '$portion 추가';
  }

  @override
  String get servingsLabel => '인분';

  @override
  String get actualAmount => '실제 분량';

  @override
  String get barcode => '바코드';

  @override
  String get allergens => '알레르기 유발 성분';

  @override
  String get none => '없음';

  @override
  String get valueTypeMaxNote => '표시는 상한값이며 실제는 더 낮을 수 있습니다.';

  @override
  String dataSource({required String source}) {
    return '출처: $source';
  }

  @override
  String get deleteThisFood => '이 음식 삭제';

  @override
  String itemsWithoutKcal({required int count}) {
    return '$count개 칼로리 없음';
  }

  @override
  String get thisMeal => '이 식사';

  @override
  String get finishEditing => '편집 완료';

  @override
  String logItemsCount({required int count}) {
    return '$count개 기록';
  }

  @override
  String get plateEmpty => '이 식사에 항목이 없습니다.';

  @override
  String get photoEstimate => '사진 추정';

  @override
  String get retry => '다시 시도';

  @override
  String get chooseAiFirst => '초안을 만들려면 AI를 선택하세요.';

  @override
  String get foodPhoto => '음식 사진';

  @override
  String get describeMealHint => '예: 아침 계란전병과 아이스 밀크티 라지';

  @override
  String get draftSection => '초안';

  @override
  String openAiSettings({required String me}) {
    return '\'$me > AI\'에서 설정';
  }

  @override
  String get dailyKcalGoal => '일일 칼로리 목표';

  @override
  String get kcalRangeError => '800–6000 kcal로 입력하세요.';

  @override
  String numberRangeError({required String min, required String max}) {
    return '$min–$max로 입력하세요.';
  }

  @override
  String get weeklyChange => '주간 변화';

  @override
  String get dailyTargets => '일일 목표';

  @override
  String get kcalTarget => '칼로리 목표';

  @override
  String get estimateFromBody => '신체 정보로 추정';

  @override
  String get estimateFromBodyDetail => '체중, 키, 나이, 성별, 활동량';

  @override
  String get setMyself => '직접 설정';

  @override
  String get bodyData => '신체 정보';

  @override
  String yearValue({required int year}) {
    return '$year년';
  }

  @override
  String get activityLevelSection => '활동량';

  @override
  String get macroSplit => '영양소 배분';

  @override
  String get byGoal => '목적에 따라';

  @override
  String perKgBodyWeight({required String grams}) {
    return '체중 1kg당 $grams g';
  }

  @override
  String get proteinPerKgTitle => '단백질(체중 1kg당)';

  @override
  String byGoalGrams({required String grams}) {
    return '목적에 따라 $grams g';
  }

  @override
  String percentOfKcal({required int percent}) {
    return '칼로리의 $percent%';
  }

  @override
  String get fatPercentTitle => '지방(칼로리 %)';

  @override
  String defaultPercent({required int percent}) {
    return '기본 $percent%';
  }

  @override
  String get restOfKcal => '나머지 칼로리';

  @override
  String get resultSection => '결과';

  @override
  String get restingMetabolism => '기초대사량';

  @override
  String get maintenanceKcal => '유지 칼로리';

  @override
  String get dailyKcal => '일일 칼로리';

  @override
  String missingInputs({required String inputs}) {
    return '$inputs 누락';
  }

  @override
  String limitValue({required String value}) {
    return '상한 $value';
  }

  @override
  String fromRecentFoodAndWeight({required int days}) {
    return '최근 $days일 식단과 체중 기준';
  }

  @override
  String get mifflinEstimate => 'Mifflin-St Jeor 추정';

  @override
  String get noCamera => '사용 가능한 카메라 없음';

  @override
  String get pickFromLibrary => '앨범에서 선택';

  @override
  String servingAndKcal({required String serving, required String kcal}) {
    return '1회분 $serving · $kcal kcal';
  }

  @override
  String get foodLibrary => '음식 라이브러리';

  @override
  String get noOwnFoodsSentence => '내 음식이 없습니다.';

  @override
  String get noMatchingFoods => '일치하는 음식이 없습니다.';

  @override
  String get officialReadOnly => '공식 데이터, 읽기 전용';

  @override
  String splitIntoCount({required int count}) {
    return '$count건으로 분리됨';
  }

  @override
  String get splitThisMeal => '이 식사 분리';

  @override
  String usualMealType({required String meal}) {
    return '자주 쓰는: $meal';
  }

  @override
  String get whichMeal => '식사 구분';

  @override
  String splitDishTitle({required int count}) {
    return '이 요리를 $count건의 기록으로 분리할까요?';
  }

  @override
  String splitDishMessage({required String dish}) {
    return '분리하면 각 성분이 개별 기록이 되어 편집, 이동, 삭제할 수 있고 \'$dish\' 단위는 사라집니다.';
  }

  @override
  String get nowLabel => '현재';

  @override
  String get afterSplit => '분리 후';

  @override
  String componentsCount({required int count}) {
    return '성분 $count개';
  }

  @override
  String otherCount({required int count}) {
    return '기타 $count개';
  }

  @override
  String get undoWithin30s => '30초 안에 되돌릴 수 있습니다.';

  @override
  String get waterGlass => '한 잔';

  @override
  String get waterLargeGlass => '큰 잔';

  @override
  String get waterBottle => '한 병';

  @override
  String get waterPerTap => '1회 기록량';

  @override
  String get customAction => '직접 입력';

  @override
  String get moreAction => '더 보기';

  @override
  String get waterPerTapMl => '1회 기록량(mL)';

  @override
  String get waterReference => '하루 참고량';

  @override
  String get waterReferenceMl => '하루 참고량(mL)';

  @override
  String get waterReferenceNote => '집단 참고값이며 실제 필요량은 사람마다 다름';

  @override
  String get waterReferenceHpa => '대만 국민건강서';

  @override
  String get waterReferenceNone => '설정 안 함';

  @override
  String waterFastWarning({required String millilitres}) {
    return '1시간 안에 $millilitres mL 기록. 짧은 시간에 많이 마시면 저나트륨혈증이 생길 수 있으니 나눠서 천천히 마실 것.';
  }

  @override
  String waterPerTapLabel({required int millilitres}) {
    return '1회 기록량, 현재 $millilitres밀리리터';
  }

  @override
  String waterTimesLast({required int count, required String time}) {
    return '$count회 · 최근 $time';
  }

  @override
  String allDrinksTotal({required int millilitres}) {
    return '음료 합계 $millilitres mL(커피, 차 포함)';
  }

  @override
  String todayAt({required String time}) {
    return '오늘 $time';
  }

  @override
  String yesterdayAt({required String time}) {
    return '어제 $time';
  }

  @override
  String addNamed({required String name}) {
    return '$name 추가';
  }

  @override
  String get contentsSection => '구성';

  @override
  String get muscleMapSetting => '인체 지도';

  @override
  String get conventionMessage => '일일 합계의 명칭, 나트륨 단위와 상한. 음식 페이지는 해당 표시를 따릅니다.';

  @override
  String get profileSection => '프로필';

  @override
  String get goalsAndReminders => '목표 및 알림';

  @override
  String get featuresSection => '기능';

  @override
  String get exerciseLibraryDetail => '운동 둘러보기, 검색, 만들기';

  @override
  String modulesEnabled({required String modules}) {
    return '$modules 켜짐';
  }

  @override
  String get notEnabled => '꺼짐';

  @override
  String get dataSection => '데이터';

  @override
  String databaseRecovered({required String path}) {
    return '이전 데이터 파일을 읽을 수 없어 $path(으)로 옮기고 빈 상태로 시작했습니다. 이전 파일은 삭제되지 않았습니다.';
  }

  @override
  String get localData => '기기 내 데이터';

  @override
  String get dataSourcesDetail => '직접 입력, 가져오기, 기본 카탈로그';

  @override
  String get showDemoData => '데모 데이터 표시';

  @override
  String get exportTitle => '내보내기';

  @override
  String get exportDetail => '전체 보관 JSON · CSV 보기';

  @override
  String get privacyDetail => '데이터 저장 위치와 전송 내용';

  @override
  String get aboutSection => '정보';

  @override
  String get versionLabel => '버전';

  @override
  String get exerciseImages => '운동 이미지';

  @override
  String get referencesTitle => '참고 문헌';

  @override
  String get openSourceLicenses => '오픈 소스 라이선스';

  @override
  String get workoutsFigure => '운동';

  @override
  String get activeDaysFigure => '운동일';

  @override
  String get daysUnit => '일';

  @override
  String get weeksUnit => '주';

  @override
  String get startedLogging => '기록 시작';

  @override
  String goalSummaryText({required int target, required int active}) {
    return '주 $target일 · 이번 주 $active일';
  }

  @override
  String proteinGrams({required String grams}) {
    return '단백질 $grams g';
  }

  @override
  String foodLibrarySummary({required int own, required int brands}) {
    return '내 음식 $own개 · 브랜드 $brands개';
  }

  @override
  String get birthYearHint => '예: 1995';

  @override
  String get birthYearError => '출생 연도는 네 자리 연도로 입력하세요.';

  @override
  String get sexUseMessage => '일일 칼로리 추정에만 사용됩니다.';

  @override
  String get fullArchiveJson => '전체 보관(JSON)';

  @override
  String get fullArchiveDetail => '전체 복원 가능';

  @override
  String get fullArchiveDone => '전체 보관 파일 생성됨';

  @override
  String get csvViews => 'CSV 보기';

  @override
  String get csvViewsDetail => '읽기 쉬우나 손실 가능';

  @override
  String get csvViewsDone => 'CSV 보기 생성됨';

  @override
  String get exportNotEncrypted => '내보낸 파일은 암호화되지 않습니다.';

  @override
  String exportDoneFile({required String done, required String file}) {
    return '$done: $file';
  }

  @override
  String exportFailed({required String error}) {
    return '내보내기 실패: $error';
  }

  @override
  String appliedTo({required String routine}) {
    return '\'$routine\'에 적용됨';
  }

  @override
  String get aiProposalTitle => 'AI 제안 변경';

  @override
  String aiProposalSubtitle({required String routine}) {
    return '루틴 \'$routine\' · 미적용';
  }

  @override
  String get reject => '거절';

  @override
  String get acceptAndApply => '수락 후 적용';

  @override
  String get questionLabel => '질문';

  @override
  String get proposalQuestion => '\"최근 스쿼트 세트가 너무 적지 않아? 다시 늘려줘.\"';

  @override
  String changesCount({required int count}) {
    return '운동 $count개 변경';
  }

  @override
  String get reasonLabel => '이유';

  @override
  String get proposalReason =>
      '주간 본세트가 12에서 8로 감소. \'근력 유지\' 목표 권장 범위는 10–12세트입니다.';

  @override
  String get proposalDataSent => '전송 데이터: 최근 4주 운동 기록';

  @override
  String get proposalModel => '모델: 자체 호스팅 엔드포인트';

  @override
  String get addedLabel => '추가';

  @override
  String get unchangedLabel => '변경 없음';

  @override
  String setsTimesRepsShort({required int sets, required int reps}) {
    return '$sets세트 × $reps회';
  }

  @override
  String get privacyStorage => '저장';

  @override
  String get privacyRecords => '기록';

  @override
  String get privacyRecordsValue => '이 기기에만';

  @override
  String get privacyAccount => '계정';

  @override
  String get privacyServer => '서버';

  @override
  String get privacyDeleted => '삭제한 기록';

  @override
  String get privacyDeletedValue => '복원 가능';

  @override
  String get privacyUninstall => '앱 삭제';

  @override
  String get privacyUninstallValue => '모든 기록 삭제';

  @override
  String get privacyCameraSection => '카메라 및 사진';

  @override
  String get privacyCamera => '카메라';

  @override
  String get privacyCameraValue => '스캔할 때만 켜짐';

  @override
  String get privacyPhotos => '사진 보관함';

  @override
  String get privacyPhotosValue => '최신 사진 한 장을 선택 버튼 미리보기로 사용';

  @override
  String get privacyScalePhotos => '체지방계 및 둘레 사진';

  @override
  String get privacyScalePhotosValue => '기기에서 읽으며 전송하지 않음';

  @override
  String privacyHealthSection({required String platform}) {
    return '건강 데이터($platform)';
  }

  @override
  String get privacyPermission => '권한';

  @override
  String get privacyPermissionValue => '읽기와 쓰기';

  @override
  String get privacyReading => '읽기';

  @override
  String get privacyReadingValue => '처음에는 전체, 이후 앱을 열 때 최근 30일';

  @override
  String get privacyLeavesDevice => '기기 밖 전송';

  @override
  String get privacyNo => '아니요';

  @override
  String get privacyToAi => 'AI에 제공';

  @override
  String get privacyAds => '광고에 사용';

  @override
  String get privacyDisconnect => '연결 해제 후';

  @override
  String get privacyDisconnectValue => '이미 읽은 기록은 유지';

  @override
  String get privacyKinds => '읽는 항목';

  @override
  String get privacyDefault => '기본값';

  @override
  String get privacyNotUsed => '사용 안 함';

  @override
  String get privacyAppleIntelligence => '기기에서 실행';

  @override
  String get privacyCloudReceives => '클라우드 AI가 받는 것';

  @override
  String get privacyCloudReceivesValue => '입력한 글, 사진에서 읽은 글, 추정용 음식 사진';

  @override
  String get privacyFoodPhotos => '음식 사진';

  @override
  String get privacyFoodPhotosValue => '위치와 촬영 정보 제거 후 전송, 저장 안 함';

  @override
  String get privacyOtherData => '기타 사진, 기록, 건강 데이터';

  @override
  String get privacyNotSent => '전송 안 함';

  @override
  String get privacyFirstSend => '글이나 사진을 처음 보내기 전';

  @override
  String privacyFirstSendValue({required String me}) {
    return '각각 동의를 묻고 \'$me > AI\'에서 철회 가능';
  }

  @override
  String get privacyAiResults => 'AI 결과';

  @override
  String get privacyAiResultsValue => '초안이며 확인 후 기록';

  @override
  String get privacyGoogleFree => 'Google AI Studio 무료 사용량';

  @override
  String get privacyGoogleFreeValue => '콘텐츠가 제품 개선에 쓰이고 사람이 검토할 수 있음';

  @override
  String get privacyKeysSection => '키 및 내보내기';

  @override
  String get privacyApiKeys => 'API 키';

  @override
  String get privacyApiKeysValue => '시스템 보안 저장소, 데이터베이스에 저장 안 함';

  @override
  String get privacyExportFiles => '내보낸 파일';

  @override
  String privacyExportFilesValue({required String me}) {
    return '\'$me > 내보내기\'에서 직접 만들 때만';
  }

  @override
  String get privacyExportContents => '내보내기 내용';

  @override
  String get privacyExportContentsValue => 'API 키 미포함';

  @override
  String get privacyUpload => '업로드';

  @override
  String get refUse01 => '기초대사량 추정 공식';

  @override
  String get refUse02 => '건강한 성인에서 Mifflin-St Jeor가 실측에 가장 가까움';

  @override
  String get refUse03 => '활동량(신체활동 수준) 구분';

  @override
  String get refUse04 => '유지·증량 단백질 체중 1kg당 1.6–1.8 g(범위 1.4–2.0 g)';

  @override
  String get refUse05 => '감량은 주당 체중 0.5–1%, 단백질 증가, 지방은 칼로리의 15–30%';

  @override
  String get refUse06 => '감량 시 단백질 체중 1kg당 2.2 g';

  @override
  String get refUse07 => '감량 기본값 주 0.5%, 천천히 할수록 제지방량 유지';

  @override
  String get refUse08 => '증량은 작은 잉여만, 기본값 주 0.25%';

  @override
  String get refUse09 => '체중 1kg당 약 7,700 kcal는 대략적인 출발점일 뿐';

  @override
  String get refUse10 => '식이섬유 1,000 kcal당 14 g, 지방은 칼로리의 20–35%';

  @override
  String get refUse11 => '대만: 성인 하루 나트륨 2,400 mg 이하';

  @override
  String get refUse12 => '일본: 성인 하루 식염상당량 남성 7.5 g, 여성 6.5 g 미만';

  @override
  String get refUse13 => '일본 표시: 식염상당량(g) = 나트륨(mg) × 2.54 ÷ 1,000';

  @override
  String get refUse14 => '미국·캐나다: 성인 하루 나트륨 2,300 mg 이하';

  @override
  String get refUse15 => 'EU: 성인 하루 나트륨 2.0 g, 소금 5 g';

  @override
  String get refUse16 => 'EU 표시: 탄수화물에 식이섬유 제외, 소금 = 나트륨 × 2.5';

  @override
  String get refUse17 => '호주·뉴질랜드: 성인 하루 나트륨 2,000 mg';

  @override
  String get refUse18 => '호주·뉴질랜드 표시: 탄수화물에 식이섬유 제외, 에너지는 kJ';

  @override
  String get refUse19 => '한국: 성인 하루 나트륨 2,300 mg 이하';

  @override
  String get refUse20 => '중국: 성인 하루 소금 5 g 이하';

  @override
  String get refUse21 => '잔류 카페인은 반감기 5시간으로 계산';

  @override
  String get refUse22 => '반감기는 사람마다 달라 계산값은 측정값이 아님';

  @override
  String get refUse23 => '취침 4시간 전 100 mg은 영향 없음. 참고선은 안전 기준이 아님';

  @override
  String get refUse46 => '35 mg 참고선은 취침 8.8시간 전 107 mg, 13.2시간 전 217.5 mg에서 추산';

  @override
  String get refUse47 => '하루 참고량 1,500 mL, 물만 계산';

  @override
  String get refUse48 => '신장은 시간당 약 0.7–1.0 L 배출. 1시간 안에 1,000 mL 이상이면 경고';

  @override
  String get refUse24 => '목표가 없으면 하룻밤 8시간 기준(합의는 7시간 이상)';

  @override
  String get refUse25 => '수면 부족의 영향은 14일간 누적됨';

  @override
  String get refUse26 => '더 자도 부족분을 1대1로 상쇄하지 않음';

  @override
  String get refUse27 => '회복에 합의된 속도가 없어 감쇠를 두지 않음';

  @override
  String get refUse28 => '추정 최대 중량(1RM) 공식';

  @override
  String get refUse29 => '10회 초과는 추정 안 함, 5회가 가장 정확';

  @override
  String get refUse30 => '7–10회 추정도 정확함';

  @override
  String get refUse31 => '횟수가 많을수록 개인·운동 간 차이가 커짐';

  @override
  String get refUse42 => '훈련 부하를 %1RM으로 표시';

  @override
  String get refUse43 => '%1RM을 사용한 부하 지침 업데이트';

  @override
  String get refUse44 => '부하와 실패 근접도는 서로 다른 변수';

  @override
  String get refUse45 => '여유 반복 횟수(RIR)로 실패 근접도 표시';

  @override
  String get refUse32 => '근육당 주 10세트 이상의 용량 반응';

  @override
  String get refUse33 => '단백질 체중 1kg당 1.6 g 이후 효과가 뚜렷하지 않음';

  @override
  String get refUse34 => '최대 심박수는 208 − 0.7 × 나이로 추정';

  @override
  String get refUse35 => '안정 시 심박수가 있으면 심박 예비량으로 구간 구분';

  @override
  String get refUse36 => 'BMI 저체중·정상·과체중·비만 구분';

  @override
  String get refUse37 => '제지방량 지수(FFMI) 정의';

  @override
  String get refUse38 => '바디 리컴포지션은 작은 적자만: 하루 약 500 kcal에서 제지방량 증가가 멈춤';

  @override
  String get refUse39 => '바디 리컴포지션은 작은 적자나 유지 칼로리 모두 가능, 고단백과 함께';

  @override
  String get refUse40 => '유지 칼로리의 바디 리컴포지션 단백질은 체중 1kg당 2.0 g';

  @override
  String get refUse41 => '바디 리컴포지션 단백질은 BMI 30의 체중을 상한으로 계산';

  @override
  String get refSectionTargets => '일일 칼로리 및 영양소 목표';

  @override
  String get refSectionLabels => '영양성분표';

  @override
  String get refSectionCaffeine => '카페인';

  @override
  String get refSectionSleepDebt => '수면 부채';

  @override
  String get refSectionTraining => '운동과 추이';

  @override
  String get refSectionHeartZones => '운동 심박 구간';

  @override
  String get refSectionBody => '신체';

  @override
  String get openLink => '링크 열기';

  @override
  String get openAction => '열기';

  @override
  String get cannotOpenLink => '링크를 열 수 없음';

  @override
  String apiKeyTitle({required String provider}) {
    return '$provider API 키';
  }

  @override
  String get apiKeyHint => '키를 붙여넣기, 비우면 삭제';

  @override
  String get apiEndpoint => 'API 주소';

  @override
  String get azureResourceUrl => 'Azure AI Foundry 리소스 URL';

  @override
  String get modelLabel => '모델';

  @override
  String get modelListUnavailable => '모델 목록을 불러올 수 없습니다. 이름을 입력하세요.';

  @override
  String get typeOwn => '직접 입력';

  @override
  String get deploymentName => '배포 이름';

  @override
  String get modelHint => '예: gemini-3.8-flash';

  @override
  String get signInInBrowser => '브라우저에서 로그인';

  @override
  String signInInstructions({required String uri, required String code}) {
    return '$uri에서 코드 $code를 입력하고 회사 또는 학교 계정으로 로그인하세요.';
  }

  @override
  String get copyCode => '코드 복사';

  @override
  String get okAction => '확인';

  @override
  String get signedInCopilot => 'Microsoft 365 Copilot에 로그인됨';

  @override
  String get clientId => '클라이언트 ID';

  @override
  String get clientIdHint => 'Entra 앱 등록의 Application (client) ID';

  @override
  String get tenant => '테넌트';

  @override
  String get tenantHint => '비우면 organizations';

  @override
  String get revokeConsentTitle => '동의를 철회할까요?';

  @override
  String get revokeConsentMessage => '다음에 클라우드 AI를 사용하기 전에 다시 묻습니다.';

  @override
  String get revokeConsent => '동의 철회';

  @override
  String get serviceSection => '서비스';

  @override
  String get signedIn => '로그인됨';

  @override
  String get signIn => '로그인';

  @override
  String get waitingForBrowser => '브라우저 로그인 대기 중…';

  @override
  String get signInAgain => '다시 로그인';

  @override
  String get apiKey => 'API 키';

  @override
  String get isSet => '설정됨';

  @override
  String get loadingModels => '모델 불러오는 중…';

  @override
  String get notChosen => '선택 안 됨';

  @override
  String get consentTextAndPhotos => '글과 사진 전송에 동의함';

  @override
  String get consentText => '글 전송에 동의함';

  @override
  String get consentPhotos => '사진 전송에 동의함';

  @override
  String get checkingEllipsis => '확인 중…';

  @override
  String get appleNotEligible => '이 기기는 Apple Intelligence를 지원하지 않습니다';

  @override
  String get appleNotEnabled => '\'설정 > Apple Intelligence 및 Siri\'에서 켜기';

  @override
  String get appleModelNotReady => '모델 다운로드 중';

  @override
  String get appleUnavailable => 'iOS 26 이상 및 Apple Intelligence 지원 필요';

  @override
  String get azurePortal => 'Azure 포털';

  @override
  String get copilotWarning =>
      '베타 API로 정식 제품에는 지원되지 않습니다. 회사 또는 학교 계정, Microsoft 365 Copilot 라이선스, Entra 앱 등록이 필요합니다.';

  @override
  String get googleFreeWarning =>
      '무료 사용량의 콘텐츠는 Google이 제품 개선에 사용하고 사람이 검토할 수 있습니다. 결제가 활성화된 키를 사용하세요.';

  @override
  String get cloudAi => '클라우드 AI';

  @override
  String sendToProvider({required String provider}) {
    return '$provider(으)로 보낼까요?';
  }

  @override
  String cloudConsentMessage({required String me}) {
    return '입력한 글이나 사진에서 읽은 글만 보내며 사진과 다른 기록은 보내지 않습니다. \'$me > AI\'에서 철회할 수 있습니다.';
  }

  @override
  String get agreeAndSend => '동의하고 보내기';

  @override
  String sendPhotoToProvider({required String provider}) {
    return '음식 사진을 $provider(으)로 보낼까요?';
  }

  @override
  String photoConsentMessage({required String me}) {
    return '이 사진과 추가 설명만 보내며 위치와 촬영 정보는 먼저 제거하고 사진은 저장하지 않습니다. \'$me > AI\'에서 철회할 수 있습니다.';
  }

  @override
  String aiFailureUnavailable({required String me}) {
    return 'AI 기능이 설정되지 않았습니다. \'$me > AI\'에서 설정하세요.';
  }

  @override
  String get aiFailureNeedsConsent => '글 전송에 동의하지 않았습니다.';

  @override
  String aiFailureAuthentication({required String me}) {
    return '키가 잘못되었거나 권한이 없습니다. \'$me > AI\'에서 다시 설정하세요.';
  }

  @override
  String get aiFailureRateLimited => '요청이 너무 많거나 한도를 다 썼습니다. 나중에 다시 시도하세요.';

  @override
  String get aiFailureNetwork => '네트워크에 연결할 수 없습니다. 나중에 다시 시도하세요.';

  @override
  String get aiFailureProvider => 'AI 서비스에 문제가 생겼습니다. 나중에 다시 시도하세요.';

  @override
  String get aiFailureUnreadable => 'AI 응답을 해석할 수 없습니다. 다시 시도하세요.';

  @override
  String get aiFailureNeedsPhotoConsent => '사진 전송에 동의하지 않았습니다.';

  @override
  String aiFailurePhotoUnsupported({required String me}) {
    return '현재 AI는 사진을 읽을 수 없습니다. \'$me > AI\'에서 바꾸세요.';
  }

  @override
  String get aiFailureNoFood => '사진에 음식이나 음료가 없습니다. 다른 사진으로 시도하세요.';

  @override
  String get aiFailurePhotoFormat => '이 사진 형식을 읽을 수 없습니다. 다른 사진으로 시도하세요.';

  @override
  String get prior4Weeks => '이전 4주';

  @override
  String againstBaseline({required String baseline}) {
    return '$baseline 대비';
  }

  @override
  String againstRecentBaseline({
    required String recent,
    required String baseline,
  }) {
    return '$recent, $baseline 대비';
  }

  @override
  String changeMore({required String against, required String amount}) {
    return '$against $amount 많음';
  }

  @override
  String changeLess({required String against, required String amount}) {
    return '$against $amount 적음';
  }

  @override
  String sleepLoadMore({required String percent}) {
    return '전날 더 오래 잔 날의 운동은 훈련량이 평균 $percent 많음.';
  }

  @override
  String sleepLoadLess({required String percent}) {
    return '전날 더 오래 잔 날의 운동은 훈련량이 평균 $percent 적음.';
  }

  @override
  String workoutsCount({required int count}) {
    return '운동 $count회';
  }

  @override
  String sleepSplitAt({required String time}) {
    return '$time 기준으로 긴 수면과 짧은 수면 구분';
  }

  @override
  String get againstSameWorkout => '같은 운동의 평균과 비교';

  @override
  String weightChange4Weeks({required String change}) {
    return '4주 $change kg';
  }

  @override
  String baselineTimes({required String baseline, required String count}) {
    return '$baseline $count회';
  }

  @override
  String completeDays({required int complete, required int tracked}) {
    return '완전 $complete/$tracked일';
  }

  @override
  String perDaySteps({required String steps}) {
    return '하루 $steps걸음';
  }

  @override
  String get weightSteady => '이 기간 체중은 거의 변화가 없었습니다.';

  @override
  String weightFalling({required String kg}) {
    return '체중이 주당 약 $kg kg씩 감소하고 있습니다.';
  }

  @override
  String weightRising({required String kg}) {
    return '체중이 주당 약 $kg kg씩 증가하고 있습니다.';
  }

  @override
  String basedOnWeights({required int count}) {
    return '체중 기록 $count건 기준';
  }

  @override
  String trainingGoalMet({required int count, required int goal}) {
    return '이번 주 $count번째 운동으로 주 $goal회 목표를 달성했습니다.';
  }

  @override
  String trainingGoalShort({
    required int count,
    required int goal,
    required int left,
  }) {
    return '이번 주 $count회 운동, 주 $goal회까지 $left회 남았습니다.';
  }

  @override
  String get basedOnThisWeek => '이번 주 운동 기록 기준';

  @override
  String weeklyGoalTimes({required int goal}) {
    return '주간 목표 $goal회';
  }

  @override
  String volumeDropMaxHolding({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise 주간 세트가 $first에서 $last로 줄었지만 추정 최대 중량은 유지되었습니다.';
  }

  @override
  String volumeDropMaxFalling({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise 주간 세트가 $first에서 $last로 줄었고 추정 최대 중량도 떨어졌습니다.';
  }

  @override
  String basedOnWorkouts({required int count}) {
    return '운동 기록 $count회 기준';
  }

  @override
  String get excludesWarmups => '워밍업 제외';

  @override
  String get dataComplete => '데이터 완전';

  @override
  String dataIncomplete({required int points, required int days}) {
    return '데이터 불완전, $points / $days일만 기록';
  }

  @override
  String lastWeeksCount({required int count}) {
    return '최근 $count주';
  }

  @override
  String lastDaysCount({required int count}) {
    return '최근 $count일';
  }

  @override
  String progressionDeloadReason({required int count, required int reps}) {
    return '$count회 연속 $reps회를 못 채워 한 단계 낮춰 횟수부터 채웁니다.';
  }

  @override
  String progressionMissedReps({required String sets, required int reps}) {
    return '지난번 $sets, $reps회 미달로 같은 중량 유지.';
  }

  @override
  String progressionMissedSets({required int done, required int planned}) {
    return '지난번 $done세트만 함. $planned세트를 채운 뒤 증량.';
  }

  @override
  String get progressionTooHard => '지난번 다 채웠지만 너무 힘들었다고 평가해 같은 중량 유지.';

  @override
  String progressionNearLimit({required String rir}) {
    return '지난번 다 채웠지만 마지막 세트가 한계에 가까워(RIR $rir) 같은 중량 유지.';
  }

  @override
  String progressionIncreaseReason({
    required String done,
    required String planned,
    required String reserve,
    required String added,
  }) {
    return '지난번 $done로 $planned를 채움$reserve. $added kg 늘릴 수 있음.';
  }

  @override
  String progressionReserve({required String rir}) {
    return ', 마지막 세트 $rir회 여유';
  }

  @override
  String atLeastValue({required String value}) {
    return '최소 $value';
  }

  @override
  String get appleHealth => 'Apple 건강';

  @override
  String get healthConnectName => '헬스 커넥트';

  @override
  String get healthDataGeneric => '건강 데이터';

  @override
  String get strongWorkoutName => 'Strong 운동';

  @override
  String get afterMerge => '병합 후';

  @override
  String get splitAction => '분리';

  @override
  String get aiDraftAction => 'AI 초안';

  @override
  String get removePhoto => '사진 제거';

  @override
  String get privacyWebSearch => '웹 검색';

  @override
  String get privacyWebSearchValue =>
      'Anthropic, Google AI Studio는 보낸 내용으로 공개된 영양 정보를 검색';
}
