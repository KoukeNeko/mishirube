// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appLanguage => 'English';

  @override
  String get meLanguageRow => 'Language';

  @override
  String get meSettingsOpenFailed => 'Couldn\'t open Settings';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonCloseSearch => 'Close search';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get insightCardTitle => 'Worth noting';

  @override
  String get monthPickerPreviousYear => 'Previous year';

  @override
  String get monthPickerNextYear => 'Next year';

  @override
  String get monthPickerClose => 'Close month picker';

  @override
  String get monthPickerYear => 'Year';

  @override
  String get monthPickerMonth => 'Month';

  @override
  String dayStripHasRecords({required String date}) {
    return '$date, has entries';
  }

  @override
  String get moduleNutrition => 'Food';

  @override
  String get moduleNutritionDescription =>
      'Meals, dishes, ingredients and nutrition';

  @override
  String get moduleWaterDescription => 'How much water, and when';

  @override
  String get moduleWeight => 'Weight';

  @override
  String get moduleWeightDescription => 'Weight and measurements';

  @override
  String get moduleTraining => 'Training';

  @override
  String get moduleTrainingDescription => 'Exercises, routines and workouts';

  @override
  String get moduleActivity => 'Activity';

  @override
  String get moduleActivityDescription =>
      'Running, walking, cycling, ball sports, yoga';

  @override
  String get moduleSleep => 'Sleep';

  @override
  String get moduleSleepDescription => 'Sleep time and quality';

  @override
  String get moduleWellness => 'Mood, energy, symptoms';

  @override
  String get moduleWellnessDescription => 'A journal of how the day went';

  @override
  String get moduleNotes => 'Notes';

  @override
  String get moduleNotesDescription => 'Linked to any day or entry';

  @override
  String get sourceManual => 'Entered by hand';

  @override
  String get sourceDemo => 'Demo data';

  @override
  String get sourceImport => 'Imported';

  @override
  String get sourceAiDraft => 'AI draft (confirmed)';

  @override
  String get sourceCatalogue => 'Built-in catalogue';

  @override
  String get sourceUnknown => 'Unknown';

  @override
  String get sourceAppleHealth => 'Apple Health';

  @override
  String get modulesTitle => 'Modules';

  @override
  String get modulesPickSeveral => 'Pick any';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get journalSourceRow => 'Source';

  @override
  String get sessionWorkout => 'workout';

  @override
  String sessionEndTitle({required String session}) {
    return 'End this session?';
  }

  @override
  String get sessionEndWorkoutMessage =>
      'Completed sets are saved. Discard it and it won\'t count as a workout.';

  @override
  String get sessionEndActivityMessage =>
      'Ending saves it as an activity. Discard it and nothing is kept.';

  @override
  String get sessionFinishAndSave => 'End and save';

  @override
  String get sessionDiscardWorkout => 'Discard workout';

  @override
  String get sessionDiscardActivity => 'Discard activity';

  @override
  String sessionKeepGoing({required String session}) {
    return 'Keep going';
  }

  @override
  String sessionDiscarded({required String session}) {
    return 'Session discarded';
  }

  @override
  String sessionResume({required String session}) {
    return 'Resume';
  }

  @override
  String sessionPause({required String session}) {
    return 'Pause';
  }

  @override
  String sessionEnd({required String session}) {
    return 'End';
  }

  @override
  String sessionPausedOpen({required String session}) {
    return 'Session paused, go back to it';
  }

  @override
  String sessionRunningOpen({required String session}) {
    return 'Session in progress, go back to it';
  }

  @override
  String get sessionPausedStatus => 'Paused';

  @override
  String sessionRunningStatus({required String session}) {
    return 'In progress';
  }

  @override
  String get dockAddEntry => 'Add entry';

  @override
  String addEntryToDay({required String date}) {
    return 'Add entry to $date';
  }

  @override
  String get tabToday => 'Today';

  @override
  String get tabLog => 'Log';

  @override
  String get tabTrends => 'Trends';

  @override
  String get tabMe => 'Me';

  @override
  String get detailNothingSelected => 'Nothing selected';

  @override
  String get detailNoEntrySelected => 'No entry selected';

  @override
  String get recordWater => 'Water';

  @override
  String get recordMeasurements => 'Measurements';

  @override
  String get recordBodyComposition => 'Body composition';

  @override
  String waterLogged({required int millilitres}) {
    return 'Logged $millilitres mL of water';
  }

  @override
  String get quickLogClose => 'Close add menu';

  @override
  String get bedtimeReminderTitle => 'Time to wind down';

  @override
  String bedtimeReminderBody({required String bedtime, required String wake}) {
    return 'Bed at $bedtime, up at $wake';
  }

  @override
  String get restResting => 'Resting';

  @override
  String get restEnded => 'Rest over';

  @override
  String restNextSet({required String exercise}) {
    return 'Next set · $exercise';
  }

  @override
  String setsProgress({required int done, required int total}) {
    return '$done / $total sets';
  }

  @override
  String get trackingTypeWeightReps => 'Weight + reps';

  @override
  String get trackingTypeReps => 'Reps';

  @override
  String get trackingTypeDuration => 'Time';

  @override
  String get trackingTypeDistance => 'Distance';

  @override
  String get exerciseSourceBuiltIn => 'Built-in';

  @override
  String get exerciseSourceCustom => 'Custom';

  @override
  String get exerciseSourceImported => 'Imported';

  @override
  String get bodyRegionChest => 'Chest';

  @override
  String get bodyRegionShoulders => 'Shoulders';

  @override
  String get bodyRegionBack => 'Back';

  @override
  String get bodyRegionArms => 'Arms';

  @override
  String get bodyRegionCore => 'Core';

  @override
  String get bodyRegionLegs => 'Legs & glutes';

  @override
  String get muscleChest => 'Chest';

  @override
  String get muscleFrontDelts => 'Front delts';

  @override
  String get muscleSideDelts => 'Side delts';

  @override
  String get muscleRearDelts => 'Rear delts';

  @override
  String get muscleBiceps => 'Biceps';

  @override
  String get muscleTriceps => 'Triceps';

  @override
  String get muscleForearms => 'Forearms';

  @override
  String get muscleTraps => 'Traps';

  @override
  String get muscleLats => 'Lats';

  @override
  String get muscleUpperBack => 'Upper back';

  @override
  String get muscleSpinalErectors => 'Spinal erectors';

  @override
  String get muscleAbs => 'Abs';

  @override
  String get muscleObliques => 'Obliques';

  @override
  String get muscleGlutes => 'Glutes';

  @override
  String get muscleQuads => 'Quads';

  @override
  String get muscleHamstrings => 'Hamstrings';

  @override
  String get muscleAdductors => 'Adductors';

  @override
  String get muscleAbductors => 'Abductors';

  @override
  String get muscleCalves => 'Calves';

  @override
  String get muscleBack => 'Back';

  @override
  String get muscleShoulders => 'Shoulders';

  @override
  String get muscleArms => 'Arms';

  @override
  String get muscleCore => 'Core';

  @override
  String get equipmentBarbell => 'Barbell';

  @override
  String get equipmentDumbbell => 'Dumbbell';

  @override
  String get equipmentCable => 'Cable';

  @override
  String get equipmentMachine => 'Machine';

  @override
  String get equipmentSmithMachine => 'Smith machine';

  @override
  String get equipmentKettlebell => 'Kettlebell';

  @override
  String get equipmentEzBar => 'EZ bar';

  @override
  String get equipmentTrapBar => 'Trap bar';

  @override
  String get equipmentLandmine => 'Landmine';

  @override
  String get equipmentPlate => 'Plate';

  @override
  String get equipmentBand => 'Band';

  @override
  String get equipmentBodyweight => 'Bodyweight';

  @override
  String get equipmentCardio => 'Cardio machine';

  @override
  String get equipmentOther => 'Other';

  @override
  String get movementPatternSquat => 'Squat';

  @override
  String get movementPatternHinge => 'Hinge';

  @override
  String get movementPatternLunge => 'Lunge & single leg';

  @override
  String get movementPatternHorizontalPush => 'Horizontal push';

  @override
  String get movementPatternHorizontalPull => 'Horizontal pull';

  @override
  String get movementPatternVerticalPush => 'Vertical push';

  @override
  String get movementPatternVerticalPull => 'Vertical pull';

  @override
  String get movementPatternIsolation => 'Isolation';

  @override
  String get movementPatternCore => 'Core';

  @override
  String get movementPatternCarry => 'Carry';

  @override
  String get movementPatternConditioning => 'Conditioning';

  @override
  String get movementPatternUnilateral => 'Unilateral';

  @override
  String get lateralityBilateral => 'Both sides';

  @override
  String get lateralityUnilateral => 'One side';

  @override
  String get lateralityAlternating => 'Alternating';

  @override
  String get setTypeWorking => 'Working set';

  @override
  String get setTypeWarmup => 'Warm-up set';

  @override
  String get setTypeDrop => 'Drop set';

  @override
  String get setTypeFailure => 'Failure set';

  @override
  String get workloadTooLight => 'Too light';

  @override
  String get workloadRight => 'Just right';

  @override
  String get workloadTooHard => 'Too hard';

  @override
  String get setKindWorking => 'working';

  @override
  String get setKindWarmup => 'warm-up';

  @override
  String get setKindDrop => 'drop';

  @override
  String get setKindFailure => 'failure';

  @override
  String substitutionSamePattern({required String pattern}) {
    return 'Same pattern: $pattern';
  }

  @override
  String substitutionSameMuscles({required String muscles}) {
    return 'Also trains $muscles';
  }

  @override
  String substitutionEquipmentAvailable({required String equipment}) {
    return '$equipment available';
  }

  @override
  String substitutionTrackingChanges({required String tracking}) {
    return 'Logged as $tracking instead';
  }

  @override
  String substitutionEquipmentChanges({required String equipment}) {
    return 'Uses $equipment; set the weight again';
  }

  @override
  String get substitutionOneSide => 'One side at a time; set the reps again';

  @override
  String get routineUntitled => 'New routine';

  @override
  String get workoutFreeName => 'Free workout';

  @override
  String setOrdinal({required int number}) {
    return 'Set $number';
  }

  @override
  String muscleSetCount({required String muscle, required int sets}) {
    return '$muscle $sets sets';
  }

  @override
  String get valueTypeDeclared => 'Label value';

  @override
  String get valueTypeMax => 'Maximum';

  @override
  String get valueTypeEstimate => 'Estimate';

  @override
  String get mealTypeBreakfast => 'Breakfast';

  @override
  String get mealTypeLunch => 'Lunch';

  @override
  String get mealTypeDinner => 'Dinner';

  @override
  String get mealTypeSnack => 'Snack';

  @override
  String get consumptionKindFood => 'Food';

  @override
  String get consumptionKindBeverage => 'Drink';

  @override
  String get consumptionKindUnknown => 'Not set';

  @override
  String get servingUnitGram => 'g';

  @override
  String get servingUnitKilogram => 'kg';

  @override
  String get servingUnitOunce => 'oz';

  @override
  String get servingUnitPound => 'lb';

  @override
  String get servingUnitTael => 'tael';

  @override
  String get servingUnitCatty => 'catty';

  @override
  String get servingUnitMillilitre => 'ml';

  @override
  String get servingUnitLitre => 'L';

  @override
  String get servingUnitServing => 'serving';

  @override
  String get allergenCrustacean => 'Crustaceans';

  @override
  String get allergenMango => 'Mango';

  @override
  String get allergenPeanut => 'Peanuts';

  @override
  String get allergenMilk => 'Milk';

  @override
  String get allergenEgg => 'Eggs';

  @override
  String get allergenTreeNut => 'Tree nuts';

  @override
  String get allergenSesame => 'Sesame';

  @override
  String get allergenGluten => 'Gluten';

  @override
  String get allergenSoy => 'Soy';

  @override
  String get allergenFish => 'Fish';

  @override
  String get allergenSulphite => 'Sulphites';

  @override
  String get nutrientSaturatedFat => 'Saturated fat';

  @override
  String get nutrientTransFat => 'Trans fat';

  @override
  String get nutrientSugar => 'Sugar';

  @override
  String get nutrientSodium => 'Sodium';

  @override
  String get nutrientNetCarb => 'Net carbs';

  @override
  String get nutrientSaltEquivalent => 'Salt equivalent';

  @override
  String get nutrientPolyols => 'Sugar alcohols';

  @override
  String get nutrientAlcohol => 'Alcohol';

  @override
  String get nutrientCholesterol => 'Cholesterol';

  @override
  String get nutrientCaffeine => 'Caffeine';

  @override
  String get nutrientEssentialAminoAcids => 'Essential amino acids';

  @override
  String get nutrientBcaa => 'BCAAs';

  @override
  String get nutrientLeucine => 'Leucine';

  @override
  String get nutrientIsoleucine => 'Isoleucine';

  @override
  String get nutrientValine => 'Valine';

  @override
  String get nutrientGlutamine => 'Glutamine';

  @override
  String get nutrientCalcium => 'Calcium';

  @override
  String get nutrientPhosphorus => 'Phosphorus';

  @override
  String get nutrientMagnesium => 'Magnesium';

  @override
  String get nutrientIron => 'Iron';

  @override
  String get nutrientZinc => 'Zinc';

  @override
  String get nutrientPotassium => 'Potassium';

  @override
  String get nutrientIodine => 'Iodine';

  @override
  String get nutrientSelenium => 'Selenium';

  @override
  String get nutrientVitaminA => 'Vitamin A';

  @override
  String get nutrientVitaminD => 'Vitamin D';

  @override
  String get nutrientVitaminE => 'Vitamin E';

  @override
  String get nutrientVitaminK => 'Vitamin K';

  @override
  String get nutrientVitaminC => 'Vitamin C';

  @override
  String get nutrientVitaminB1 => 'Vitamin B1';

  @override
  String get nutrientVitaminB2 => 'Vitamin B2';

  @override
  String get nutrientNiacin => 'Niacin';

  @override
  String get nutrientVitaminB6 => 'Vitamin B6';

  @override
  String get nutrientVitaminB12 => 'Vitamin B12';

  @override
  String get nutrientFolate => 'Folate';

  @override
  String get nutrientPantothenicAcid => 'Pantothenic acid';

  @override
  String get nutrientBiotin => 'Biotin';

  @override
  String get conventionTaiwan => 'Taiwan';

  @override
  String get conventionJapan => 'Japan';

  @override
  String get conventionUnitedStates => 'United States';

  @override
  String get conventionEuropeanUnion => 'EU';

  @override
  String get conventionAustraliaNewZealand => 'Australia & New Zealand';

  @override
  String get conventionKorea => 'Korea';

  @override
  String get conventionChina => 'China';

  @override
  String get conventionCanada => 'Canada';

  @override
  String get macroEnergy => 'Calories';

  @override
  String get macroProtein => 'Protein';

  @override
  String get macroCarb => 'Carbohydrate';

  @override
  String get macroFat => 'Fat';

  @override
  String get macroFibre => 'Fiber';

  @override
  String foodCupCapacity({required String amount}) {
    return 'Cup $amount';
  }

  @override
  String get foodOfficialData => 'Official data';

  @override
  String foodAdd({required String food}) {
    return 'Add \"$food\"';
  }

  @override
  String foodLastPortion({required String portion, required String kcal}) {
    return 'Last time $portion · $kcal';
  }

  @override
  String foodCupSizes({required int count}) {
    return '$count cup sizes';
  }

  @override
  String foodOneServing({required String serving, required String kcal}) {
    return '1 serving $serving · $kcal';
  }

  @override
  String draftEnergyMismatchItem({required String item}) {
    return '$item: the calories don\'t match its protein, carbs and fat. Check them.';
  }

  @override
  String get draftEnergyMismatch =>
      'The calories don\'t match the protein, carbs and fat. Check these fields.';

  @override
  String get draftColumnMismatch =>
      'Calories per serving and per 100 don\'t agree for this serving size; a figure may be from the other column. Check it.';

  @override
  String get draftCarbWithoutFibre =>
      'This label\'s carbohydrate leaves out fiber and it prints no fiber, so carbohydrate is left blank.';

  @override
  String get activityGroupWalkRun => 'Walking & running';

  @override
  String get activityGroupCycling => 'Cycling';

  @override
  String get activityGroupWater => 'Water sports';

  @override
  String get activityGroupBall => 'Ball sports';

  @override
  String get activityGroupIndoor => 'Indoor equipment';

  @override
  String get activityGroupMindBody => 'Mind & body';

  @override
  String get activityGroupOther => 'Other';

  @override
  String get activityMetricGroupMovement => 'Daily activity';

  @override
  String get activityMetricGroupHeart => 'Heart & fitness';

  @override
  String get activityMetricGroupMobility => 'Mobility';

  @override
  String get activityMetricGroupRunning => 'Running';

  @override
  String get activityMetricGroupCycling => 'Cycling';

  @override
  String get activityMetricGroupSwimmingWheelchair => 'Swimming & wheelchair';

  @override
  String get activityMetricSteps => 'Steps';

  @override
  String get activityMetricDistance => 'Distance';

  @override
  String get activityMetricActiveEnergy => 'Active energy';

  @override
  String get activityMetricBasalEnergy => 'Resting energy';

  @override
  String get activityMetricExerciseTime => 'Exercise time';

  @override
  String get activityMetricStandTime => 'Stand time';

  @override
  String get activityMetricFloors => 'Flights climbed';

  @override
  String get activityMetricElevationGained => 'Elevation gained';

  @override
  String get activityMetricTimeInDaylight => 'Time in daylight';

  @override
  String get activityMetricHeartRate => 'Average heart rate';

  @override
  String get activityMetricRestingHeartRate => 'Resting heart rate';

  @override
  String get activityMetricWalkingHeartRate => 'Walking heart rate';

  @override
  String get activityMetricHrvSdnn => 'Heart rate variability (SDNN)';

  @override
  String get activityMetricHrvRmssd => 'Heart rate variability (RMSSD)';

  @override
  String get activityMetricHeartRateRecovery => '1-minute heart rate recovery';

  @override
  String get activityMetricVo2Max => 'VO₂ max';

  @override
  String get activityMetricPhysicalEffort => 'Physical effort';

  @override
  String get activityMetricWalkingSpeed => 'Walking speed';

  @override
  String get activityMetricWalkingStepLength => 'Step length';

  @override
  String get activityMetricWalkingAsymmetry => 'Walking asymmetry';

  @override
  String get activityMetricDoubleSupport => 'Double support time';

  @override
  String get activityMetricWalkingSteadiness => 'Walking steadiness';

  @override
  String get activityMetricStairAscentSpeed => 'Stair speed: up';

  @override
  String get activityMetricStairDescentSpeed => 'Stair speed: down';

  @override
  String get activityMetricSixMinuteWalk => 'Six-minute walk';

  @override
  String get activityMetricRunningSpeed => 'Running speed';

  @override
  String get activityMetricRunningPower => 'Running power';

  @override
  String get activityMetricRunningStrideLength => 'Running stride length';

  @override
  String get activityMetricGroundContactTime => 'Ground contact time';

  @override
  String get activityMetricVerticalOscillation => 'Vertical oscillation';

  @override
  String get activityMetricCyclingDistance => 'Cycling distance';

  @override
  String get activityMetricCyclingSpeed => 'Cycling speed';

  @override
  String get activityMetricCyclingPower => 'Cycling power';

  @override
  String get activityMetricCyclingCadence => 'Cadence';

  @override
  String get activityMetricFunctionalThresholdPower =>
      'Functional threshold power';

  @override
  String get activityMetricSwimmingDistance => 'Swimming distance';

  @override
  String get activityMetricSwimmingStrokes => 'Swim strokes';

  @override
  String get activityMetricWheelchairPushes => 'Wheelchair pushes';

  @override
  String get activityMetricWheelchairDistance => 'Wheelchair distance';

  @override
  String get activityMetricUnitSteps => 'steps';

  @override
  String get activityMetricUnitDistance => 'km';

  @override
  String get activityMetricUnitActiveEnergy => 'kcal';

  @override
  String get activityMetricUnitBasalEnergy => 'kcal';

  @override
  String get activityMetricUnitExerciseTime => 'min';

  @override
  String get activityMetricUnitStandTime => 'min';

  @override
  String get activityMetricUnitFloors => 'floors';

  @override
  String get activityMetricUnitElevationGained => 'm';

  @override
  String get activityMetricUnitTimeInDaylight => 'min';

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
  String get activityMetricUnitSwimmingStrokes => 'strokes';

  @override
  String get activityMetricUnitWheelchairPushes => 'pushes';

  @override
  String get activityMetricUnitWheelchairDistance => 'km';

  @override
  String get activityTypeRunning => 'Running';

  @override
  String get activityTypeWalking => 'Walking';

  @override
  String get activityTypeHiking => 'Hiking';

  @override
  String get activityTypeCycling => 'Cycling';

  @override
  String get activityTypeSwimming => 'Swimming';

  @override
  String get activityTypeRowing => 'Rowing machine';

  @override
  String get activityTypeElliptical => 'Elliptical';

  @override
  String get activityTypeStairs => 'Stairs';

  @override
  String get activityTypeBasketball => 'Basketball';

  @override
  String get activityTypeBadminton => 'Badminton';

  @override
  String get activityTypeYoga => 'Yoga';

  @override
  String get activityTypeOther => 'Other activity';

  @override
  String durationMinutes({required int minutes}) {
    return '$minutes min';
  }

  @override
  String get activitySeriesHeartRate => 'Heart rate';

  @override
  String get activitySeriesSpeed => 'Speed';

  @override
  String get activitySeriesPower => 'Power';

  @override
  String get activitySeriesCadence => 'Cadence';

  @override
  String get activitySeriesStrideLength => 'Stride length';

  @override
  String get activitySeriesGroundContactTime => 'Ground contact time';

  @override
  String get activitySeriesVerticalOscillation => 'Vertical oscillation';

  @override
  String get activitySeriesAltitude => 'Altitude';

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
    return 'Deleted $activity';
  }

  @override
  String get recordDeletedNotice => 'This entry was deleted.';

  @override
  String get activityRouteMap => 'Route map';

  @override
  String get healthDetailUnreadable =>
      'Couldn\'t read the details from Health.';

  @override
  String get activityDetailsSection => 'Details';

  @override
  String get activitySplitsSection => 'Splits · per 1 km';

  @override
  String get activityRecoverySection => 'Heart rate after';

  @override
  String get activityPace => 'Pace';

  @override
  String get notesSection => 'Notes';

  @override
  String get manageSection => 'Manage';

  @override
  String get activityEdit => 'Edit details';

  @override
  String get activityEditDetail => 'Type, time, duration';

  @override
  String get recordDelete => 'Delete entry';

  @override
  String get deleteMeasurement => 'Delete this measurement';

  @override
  String get activityActiveTime => 'Workout time';

  @override
  String get activityDistance => 'Distance';

  @override
  String get activityTotalEnergy => 'Total energy';

  @override
  String get activityClimb => 'Elevation gain';

  @override
  String get activityAveragePace => 'Avg pace';

  @override
  String get activityAverageSpeed => 'Avg speed';

  @override
  String get activityMaxHeartRate => 'Max heart rate';

  @override
  String get activityAveragePower => 'Avg power';

  @override
  String get activityAverageCadence => 'Avg cadence';

  @override
  String get activityEffort => 'Effort';

  @override
  String get activityEffortEstimated => 'Effort (estimated)';

  @override
  String activityIndoor({required String activity}) {
    return '$activity (indoor)';
  }

  @override
  String activityOutdoor({required String activity}) {
    return '$activity (outdoor)';
  }

  @override
  String get weatherLabel => 'Weather';

  @override
  String get humidityLabel => 'Humidity';

  @override
  String get splitTime => 'Time';

  @override
  String statAverage({required String value}) {
    return 'Avg $value';
  }

  @override
  String heartZone({required int number}) {
    return 'Zone $number';
  }

  @override
  String get heartZonesByReserve => 'Estimated from heart rate reserve';

  @override
  String get heartZonesByAge => 'Max heart rate estimated from age';

  @override
  String get heartZonesOwn => 'This app\'s zones';

  @override
  String get recoveryAtEnd => 'At finish';

  @override
  String recoveryAfter({required int minutes}) {
    return '$minutes min after';
  }

  @override
  String recoveryWindow({required String time}) {
    return '3 min from $time';
  }

  @override
  String timelineWeight({required String weight}) {
    return 'Weight $weight';
  }

  @override
  String sleepQualityScore({required int score}) {
    return 'Quality $score / 5';
  }

  @override
  String noteLine({required String note}) {
    return 'Note: $note';
  }

  @override
  String setsCount({required int count}) {
    return '$count sets';
  }

  @override
  String personalRecordLine({
    required String exercise,
    required String weight,
    required int reps,
  }) {
    return '$exercise $weight kg × $reps is a personal record';
  }

  @override
  String effortOutOfTen({required int effort}) {
    return 'Effort $effort / 10';
  }

  @override
  String activitiesCount({required int count}) {
    return '$count activities';
  }

  @override
  String itemsCount({required int count}) {
    return '$count items';
  }

  @override
  String mealsCount({required int count}) {
    return '$count meals';
  }

  @override
  String get foodLogIncomplete => 'Meals missing';

  @override
  String todayWithDate({required String date}) {
    return 'Today · $date';
  }

  @override
  String get routineNeverDone => 'Not done yet';

  @override
  String routineLastDone({required String date}) {
    return 'Last done $date';
  }

  @override
  String exerciseLastSet({required String weight, required int reps}) {
    return 'Last $weight kg × $reps';
  }

  @override
  String optionalField({required String field}) {
    return '$field (optional)';
  }

  @override
  String get workoutBlocksActivity =>
      'A workout is running. End it before starting an activity.';

  @override
  String activityDurationRange({required int min, required int max}) {
    return 'Enter a duration from $min to $max minutes.';
  }

  @override
  String activityDistanceRange({required int max}) {
    return 'Enter a distance from 0 to $max km.';
  }

  @override
  String activityClimbRange({required int max}) {
    return 'Enter an elevation gain from 0 to $max m.';
  }

  @override
  String activityLogged({required String activity, required int minutes}) {
    return 'Logged $activity, $minutes min';
  }

  @override
  String activityUpdated({required String activity}) {
    return 'Updated $activity';
  }

  @override
  String get activityRecordTitle => 'Log activity';

  @override
  String get activityEditTitle => 'Edit activity';

  @override
  String get activityTypeRow => 'Activity type';

  @override
  String get activityStartTimer => 'Start timing now';

  @override
  String get activityStartTimerDetail =>
      'Time it as you go; add distance and effort after.';

  @override
  String get activityStartTime => 'Start time';

  @override
  String get activityDurationSection => 'Duration';

  @override
  String get minutesUnit => 'min';

  @override
  String activityEndsAt({required String time}) {
    return 'Ends $time';
  }

  @override
  String activityPaceValue({required String pace}) {
    return 'Pace $pace /km';
  }

  @override
  String get effortSection => 'Effort';

  @override
  String get effortScaleHint => '1 is very easy, 10 is all-out.';

  @override
  String get activityNoteHint => 'e.g. riverside, very windy';

  @override
  String get activityPickTitle => 'Choose activity';

  @override
  String get recentlyUsed => 'Recent';

  @override
  String get commonlyUsed => 'Common';

  @override
  String get activityAllTypes => 'All activities';

  @override
  String get activityEnded => 'This activity has ended.';

  @override
  String get sessionInProgress => 'In progress';

  @override
  String get commonEnd => 'End';

  @override
  String get commonResume => 'Resume';

  @override
  String get commonPause => 'Pause';

  @override
  String get chartRangeDay => 'D';

  @override
  String get chartRangeWeek => 'W';

  @override
  String get chartRangeMonth => 'M';

  @override
  String get chartRangeHalfYear => '6M';

  @override
  String get chartRangeYear => 'Y';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get entriesRow => 'Entries';

  @override
  String get noData => 'No data';

  @override
  String get thisDay => 'This day';

  @override
  String get dailyAverage => 'Daily average';

  @override
  String get usualRange => 'Usual range';

  @override
  String get daysRecorded => 'Days recorded';

  @override
  String daysCount({required int count}) {
    return '$count days';
  }

  @override
  String weekOf({required String date}) {
    return 'Week of $date';
  }

  @override
  String readingsCount({required int count}) {
    return '$count readings';
  }

  @override
  String get perDay => 'Per day';

  @override
  String get dailyActivityTitle => 'Activity';

  @override
  String get noActivityData => 'No activity data';

  @override
  String get dataSourcesLink => 'Data sources';

  @override
  String get noActivityThisDay => 'No activity data this day';

  @override
  String usualRangeValue({required String range}) {
    return 'Usually $range';
  }

  @override
  String get perHour => 'Per hour';

  @override
  String hourSpan({required int start, required int end}) {
    return '$start–$end h';
  }

  @override
  String hourOfDay({required int hour}) {
    return '${hour}h';
  }

  @override
  String get measurementSiteWaist => 'Waist';

  @override
  String get measurementSiteHips => 'Hips';

  @override
  String get measurementSiteChest => 'Chest';

  @override
  String get measurementSiteArm => 'Upper arm';

  @override
  String get measurementSiteThigh => 'Thigh';

  @override
  String get measurementSiteCalf => 'Calf';

  @override
  String get measurementSiteNeck => 'Neck';

  @override
  String get bodyMetricHeight => 'Height';

  @override
  String get bodyMetricBodyFat => 'Body fat';

  @override
  String get bodyMetricSkeletalMuscle => 'Skeletal muscle';

  @override
  String get bodyMetricMuscleMass => 'Muscle mass';

  @override
  String get bodyMetricLeanMass => 'Lean body mass';

  @override
  String get bodyMetricVisceralFat => 'Visceral fat';

  @override
  String get bodyMetricBodyWater => 'Body water';

  @override
  String get bodyMetricBoneMass => 'Bone mass';

  @override
  String get bodyMetricBasalMetabolicRate => 'Basal metabolic rate';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexMale => 'Male';

  @override
  String get sleepKindNight => 'Sleep';

  @override
  String get sleepKindNap => 'Nap';

  @override
  String get sleepMeasureAsleep => 'Time asleep';

  @override
  String get sleepMeasureInBed => 'Time in bed';

  @override
  String get sleepStageInBed => 'In bed';

  @override
  String get sleepStageAwake => 'Awake';

  @override
  String get sleepStageAsleep => 'Asleep';

  @override
  String get sleepStageCore => 'Core';

  @override
  String get sleepStageDeep => 'Deep';

  @override
  String get sleepStageRem => 'REM';

  @override
  String get overnightMeasureHeartRate => 'Heart rate';

  @override
  String get overnightMeasureRespiratoryRate => 'Respiratory rate';

  @override
  String get overnightMeasureOxygenSaturation => 'Blood oxygen';

  @override
  String get overnightMeasureWristTemperature => 'Wrist temperature';

  @override
  String get overnightMeasureSkinTemperatureChange => 'Skin temperature change';

  @override
  String get overnightMeasureHrvSdnn => 'Heart rate variability (SDNN)';

  @override
  String get overnightMeasureHrvRmssd => 'Heart rate variability (RMSSD)';

  @override
  String get overnightMeasureBreathingDisturbances => 'Breathing disturbances';

  @override
  String get activityLevelSedentary => 'Sedentary';

  @override
  String get activityLevelLight => 'Light';

  @override
  String get activityLevelModerate => 'Moderate';

  @override
  String get activityLevelActive => 'Active';

  @override
  String get activityLevelVeryActive => 'Very active';

  @override
  String get weightGoalLose => 'Lose fat';

  @override
  String get weightGoalRecomp => 'Recomposition';

  @override
  String get weightGoalMaintain => 'Maintain';

  @override
  String get weightGoalGain => 'Build muscle';

  @override
  String get targetInputWeight => 'weight';

  @override
  String get targetInputHeight => 'height';

  @override
  String get targetInputBirthYear => 'birth year';

  @override
  String get targetInputSex => 'sex';

  @override
  String get healthDataSleep => 'Sleep';

  @override
  String get healthDataWeight => 'Weight';

  @override
  String get healthDataWaist => 'Waist';

  @override
  String get healthDataBody => 'Body composition';

  @override
  String get healthDataWorkouts => 'Workouts';

  @override
  String get healthDataWater => 'Water';

  @override
  String get healthDataOvernight => 'Overnight data';

  @override
  String get healthDataActivity => 'Activity & fitness';

  @override
  String get recordCategoryTraining => 'Training';

  @override
  String get recordCategoryActivity => 'Activity';

  @override
  String get recordCategoryNutrition => 'Food';

  @override
  String get recordCategoryBody => 'Body';

  @override
  String get recordCategoryWellness => 'Sleep & wellbeing';

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
  String get aiProviderOpenAiCompatible => 'OpenAI-compatible endpoint';

  @override
  String get wellnessKindEnergy => 'Energy';

  @override
  String get wellnessKindMood => 'Mood';

  @override
  String get wellnessKindSymptom => 'Symptoms';

  @override
  String get wellnessKindSleep => 'Sleep quality';

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
  String get bodyMetricUnitVisceralFat => 'level';

  @override
  String get bodyMetricUnitBodyWater => '%';

  @override
  String get bodyMetricUnitBoneMass => 'kg';

  @override
  String get bodyMetricUnitBasalMetabolicRate => 'kcal';

  @override
  String get overnightMeasureUnitHeartRate => 'bpm';

  @override
  String get overnightMeasureUnitRespiratoryRate => 'breaths/min';

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
  String get activityLevelDetailSedentary => 'Little or no exercise';

  @override
  String get activityLevelDetailLight => 'Exercise 1–3 days a week';

  @override
  String get activityLevelDetailModerate => 'Exercise 3–5 days a week';

  @override
  String get activityLevelDetailActive => 'Exercise 6–7 days a week';

  @override
  String get activityLevelDetailVeryActive =>
      'Physical job or training twice a day';

  @override
  String get aiOff => 'AI off';

  @override
  String get aiDraftGenerate => 'Make draft';

  @override
  String get aiDrafting => 'Drafting…';

  @override
  String get aiRewrite => 'Start over';

  @override
  String deletedItem({required String item}) {
    return 'Deleted $item';
  }

  @override
  String get recordTitle => 'Entry';

  @override
  String get commonEdit => 'Edit';

  @override
  String get bodyScaleEstimate => 'Scale estimate';

  @override
  String get notRated => 'Not rated';

  @override
  String weightSinceLast({required String change, required String date}) {
    return '$change since $date';
  }

  @override
  String get logFilterAll => 'All';

  @override
  String pickMonthCurrent({required String month}) {
    return 'Choose month, now $month';
  }

  @override
  String get logSearch => 'Search entries';

  @override
  String get backToToday => 'Go to today';

  @override
  String get showAsCalendar => 'Show as calendar';

  @override
  String get showAsTimeline => 'Show as timeline';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String noEntriesInMonth({required String month}) {
    return 'No entries in $month';
  }

  @override
  String noEntriesMatching({required String query}) {
    return 'No entries match \"$query\".';
  }

  @override
  String get noEntriesThisDay => 'No entries this day.';

  @override
  String get noEntriesSentence => 'No entries.';

  @override
  String get noImports => 'Nothing imported.';

  @override
  String get importUndone => 'Undone';

  @override
  String productsCount({required int count}) {
    return '$count products';
  }

  @override
  String catalogueUpdated({required String catalogue, required String date}) {
    return '$catalogue updated $date';
  }

  @override
  String healthReadFailed({required String error}) {
    return 'Couldn\'t read: $error';
  }

  @override
  String get healthDisconnectKeeps => 'Records stay after you disconnect.';

  @override
  String get healthReadNow => 'Read now';

  @override
  String get healthDisconnect => 'Disconnect';

  @override
  String healthUnavailable({required String source}) {
    return '$source isn\'t available on this device, or it\'s too old.';
  }

  @override
  String get checking => 'Checking…';

  @override
  String get healthConnected => 'Connected';

  @override
  String healthConnect({required String source}) {
    return 'Connect $source';
  }

  @override
  String get healthReading => 'Reading…';

  @override
  String get healthAllowReading => 'Allow reading';

  @override
  String get healthAutoReadFailed => 'Last automatic read failed';

  @override
  String get healthReadFailedState => 'Reading failed';

  @override
  String get healthReadDone => 'Reading done';

  @override
  String healthLastRead({required String when}) {
    return 'Last read $when';
  }

  @override
  String healthReads({required String kinds}) {
    return 'Reads: $kinds';
  }

  @override
  String get privacyLink => 'Privacy';

  @override
  String get checkingPermissions => 'Checking permissions…';

  @override
  String get healthPermissionsPath =>
      'Change permissions in Settings > Health > Data Access & Devices > MISHIRUBE.';

  @override
  String get permissionAllowed => 'Allowed';

  @override
  String get permissionDenied => 'Not allowed';

  @override
  String get healthAllowOthers => 'Allow other types';

  @override
  String get healthNotConnected => 'Not connected.';

  @override
  String healthNothingReadDenied({required String kinds}) {
    return 'Nothing read. Not allowed: $kinds.';
  }

  @override
  String get healthNothingRead =>
      'Nothing read. Check which types are allowed in the system\'s Health settings.';

  @override
  String nightsCount({required int count}) {
    return '$count nights';
  }

  @override
  String timesCount({required int count}) {
    return '$count times';
  }

  @override
  String healthUpdatedNights({required int count}) {
    return 'Updated $count nights of sleep';
  }

  @override
  String healthKeptManual({required int count}) {
    return 'Kept $count nights logged by hand';
  }

  @override
  String healthNotAllowedList({required String kinds}) {
    return 'Not allowed: $kinds';
  }

  @override
  String get noSleepRecords => 'No sleep records';

  @override
  String get logByHand => 'Log by hand';

  @override
  String get sleepDebtSection => 'Sleep debt';

  @override
  String get napsSection => 'Naps';

  @override
  String get goalSection => 'Goal';

  @override
  String get sleepStagesSection => 'Sleep stages';

  @override
  String get notProvided => 'Not provided';

  @override
  String get fallAsleepTime => 'Time to fall asleep';

  @override
  String aboutMinutes({required int minutes}) {
    return 'About $minutes min';
  }

  @override
  String get sleepEfficiency => 'Sleep efficiency';

  @override
  String get awakeAtNight => 'Awake at night';

  @override
  String wokeTimes({required int count}) {
    return 'Woke $count times';
  }

  @override
  String get continuitySection => 'Continuity';

  @override
  String get estimatedFromInBed => 'Estimated from the device\'s time in bed';

  @override
  String get tonightSection => 'Tonight';

  @override
  String get suggestedBedtime => 'Suggested bedtime';

  @override
  String wakeAt({required String time}) {
    return 'Up at $time';
  }

  @override
  String get fromUsualWake => 'From your usual wake time';

  @override
  String get afterTraining => 'After training';

  @override
  String get caffeineAfter2pm => 'Caffeine after 14:00';

  @override
  String get mealAfter9pm => 'Eating after 21:00';

  @override
  String nightsVersus({required int withCount, required int withoutCount}) {
    return '$withCount vs $withoutCount nights';
  }

  @override
  String get factorsSection => 'Factors';

  @override
  String get factorsBasis => 'Difference in average sleep over 90 days';

  @override
  String get correlationNotCause => 'Correlation, not cause';

  @override
  String sleptLess({required String time}) {
    return '$time less sleep';
  }

  @override
  String sleptMore({required String time}) {
    return '$time more sleep';
  }

  @override
  String get recordMethod => 'Recorded by';

  @override
  String get withStages => 'With sleep stages';

  @override
  String get elevated => 'Elevated';

  @override
  String get notElevated => 'Not elevated';

  @override
  String get sameAsUsual => 'Same as the 28-night average';

  @override
  String versusUsual({required String change}) {
    return '$change vs the 28-night average';
  }

  @override
  String goalMet({required String goal}) {
    return 'Goal $goal · met';
  }

  @override
  String goalShort({required String goal, required String gap}) {
    return 'Goal $goal · $gap short';
  }

  @override
  String get recordedSleep => 'Recorded sleep';

  @override
  String get deviceEstimate => 'Device estimate';

  @override
  String withNapsTotal({required String time}) {
    return '$time with naps';
  }

  @override
  String get chartRangeSixMonths => '6M';

  @override
  String get noEntriesShort => 'No entries';

  @override
  String get averageTimeAsleep => 'Avg time asleep';

  @override
  String get averageBedtime => 'Avg bedtime';

  @override
  String get averageWake => 'Avg wake time';

  @override
  String get bedtimeSpread => 'Bedtime variation';

  @override
  String get wakeSpread => 'Wake time variation';

  @override
  String plusMinusMinutes({required int minutes}) {
    return '±$minutes min';
  }

  @override
  String get nightsRecorded => 'Nights recorded';

  @override
  String get bedAndWake => 'Bedtime & wake';

  @override
  String averageStage({required String stage}) {
    return 'Avg $stage';
  }

  @override
  String nightsWithStages({required int count}) {
    return '$count nights with stages';
  }

  @override
  String trendOverNights({required String measure, required int count}) {
    return '$measure trend, $count nights';
  }

  @override
  String get heartRateAsleep => 'Heart rate asleep';

  @override
  String get respiratoryAsleep => 'Respiratory rate asleep';

  @override
  String everyMinutes({required int minutes}) {
    return 'Every $minutes min';
  }

  @override
  String stageChartLabel({required String start, required String end}) {
    return 'Sleep stage chart, $start to $end';
  }

  @override
  String get wholeNight => 'Whole night';

  @override
  String scheduleChartLabel({required int count}) {
    return 'Bedtime and wake time, $count nights';
  }

  @override
  String get sleepGoal => 'Sleep goal';

  @override
  String get notSet => 'Not set';

  @override
  String get bedtimeReminder => 'Bedtime reminder';

  @override
  String remindsAt({required String time}) {
    return 'Reminds at $time';
  }

  @override
  String get clearGoal => 'Clear goal';

  @override
  String get trendSection => 'Trend';

  @override
  String get eachDaySection => 'Each day';

  @override
  String get notEnoughEntries => 'Not enough entries';

  @override
  String highestLowest({required String high, required String low}) {
    return 'Highest $high · lowest $low';
  }

  @override
  String get preliminary => 'Preliminary';

  @override
  String countedAt({required String hours}) {
    return 'Counted at $hours';
  }

  @override
  String goalValue({required String goal}) {
    return 'Goal $goal';
  }

  @override
  String daysWithoutEntries({required int count}) {
    return '$count days without entries';
  }

  @override
  String get hoursUnit => 'h';

  @override
  String lastFortnightExtra({required String hours}) {
    return 'Last 14 days · $hours extra sleep';
  }

  @override
  String needsLoggedDays({required int minimum, required int recorded}) {
    return 'Needs $minimum days logged in the last 14 (now $recorded)';
  }

  @override
  String lastWeekDebt({required String short, required String extra}) {
    return 'Last 7 days $short · $extra extra';
  }

  @override
  String hoursValue({required String hours}) {
    return '$hours h';
  }

  @override
  String shortBy({required String time}) {
    return '$time short';
  }

  @override
  String overBy({required String time}) {
    return '$time over';
  }

  @override
  String get photoTextUnavailable => 'This device can\'t read text in photos.';

  @override
  String get photoNoBodyComposition =>
      'No body composition figures found in the photo.';

  @override
  String get photoNoGirths => 'No measurements found in the photo.';

  @override
  String valueRangeError({
    required String field,
    required String min,
    required String max,
    required String unit,
  }) {
    return 'Enter $field between $min and $max $unit.';
  }

  @override
  String get fillAtLeastOne => 'Fill in at least one.';

  @override
  String get fillAtLeastOneSite => 'Fill in at least one measurement.';

  @override
  String loggedValue({required String item, required String value}) {
    return 'Logged $item $value';
  }

  @override
  String updatedValue({required String item, required String value}) {
    return 'Updated $item $value';
  }

  @override
  String loggedItemsCount({required int count}) {
    return 'Logged $count readings';
  }

  @override
  String loggedSitesCount({required int count}) {
    return 'Logged $count measurements';
  }

  @override
  String get scanAction => 'Scan';

  @override
  String get readingPhoto => 'Reading the photo…';

  @override
  String get scanBodyComposition => 'Read body composition from a photo';

  @override
  String get scanGirths => 'Read measurements from a photo';

  @override
  String lastReadingOn({required String value, required String date}) {
    return 'Last $value · $date';
  }

  @override
  String photoReadCheck({required int count}) {
    return '$count read from photo, please check';
  }

  @override
  String get fillFromScale => 'As shown on the scale';

  @override
  String get noteLogged => 'Note logged';

  @override
  String get noteUpdated => 'Note updated';

  @override
  String get noteHint => 'E.g. dinner out, ate more than usual';

  @override
  String get sleepWakeBeforeBed => 'Wake time must be after bedtime';

  @override
  String get sleepOver24Hours => 'One sleep can\'t exceed 24 hours';

  @override
  String get sleepWakeInFuture => 'Wake time can\'t be in the future';

  @override
  String get sleepStartLabel => 'Bedtime';

  @override
  String get sleepEndLabel => 'Wake';

  @override
  String get qualityLabel => 'Quality';

  @override
  String get sleepNoteHint => 'E.g. coffee before bed, woke at night';

  @override
  String weightRangeError({required String min, required String max}) {
    return 'Enter a value between $min and $max kg.';
  }

  @override
  String weightLogged({required String weight}) {
    return 'Logged $weight kg';
  }

  @override
  String weightUpdated({required String weight}) {
    return 'Updated to $weight kg';
  }

  @override
  String get symptomSeverity => 'Discomfort';

  @override
  String wellnessKindHow({required String kind}) {
    return 'How is your $kind?';
  }

  @override
  String get wellnessNoteHint => 'E.g. sat all day, lower back tight';

  @override
  String get bmiBandUnder => 'Underweight';

  @override
  String get bmiBandHealthy => 'Healthy weight';

  @override
  String get bmiBandOver => 'Overweight';

  @override
  String get bmiBandObese => 'Obese';

  @override
  String yearsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String get logAction => 'Log';

  @override
  String logItem({required String item}) {
    return 'Log $item';
  }

  @override
  String trendReadingsLabel({required String item, required int count}) {
    return '$item trend, $count readings';
  }

  @override
  String get bodyScaleCompareSame =>
      'Scale estimate; compare on the same scale';

  @override
  String get noWeightEntries => 'No weight entries';

  @override
  String get trendWeight => 'Trend weight';

  @override
  String latestOn({required String date, required String value}) {
    return 'Latest $date $value';
  }

  @override
  String weightChartLabel({required int count}) {
    return 'Weight trend, $count weigh-ins';
  }

  @override
  String weightChartIdle({required int count}) {
    return 'Line is 7-day average · $count weigh-ins';
  }

  @override
  String trendValue({required String value}) {
    return 'Trend $value';
  }

  @override
  String get allWeightEntries => 'All weight entries';

  @override
  String get buildSection => 'Build';

  @override
  String get waistToHipRatio => 'Waist-to-hip ratio';

  @override
  String get bmiStandardTaiwan => 'Taiwan HPA adult standard';

  @override
  String get fatMass => 'Fat mass';

  @override
  String get waistAdviceTaiwan =>
      'Taiwan HPA waist advice: men < 90 cm, women < 80 cm';

  @override
  String get weeklyGoal => 'Weekly goal';

  @override
  String get weeklyGoalPaused => 'Weekly goal paused';

  @override
  String weeklyGoalButtonLabel({required int active, required int target}) {
    return '$active / $target active days this week, view weekly goal';
  }

  @override
  String activeDaysPerWeek({required int count}) {
    return '$count active days a week';
  }

  @override
  String get adjustWeeklyGoal => 'Adjust weekly goal';

  @override
  String get weeklyGoalPrompt => 'How many active days each week.';

  @override
  String get setWeeklyGoal => 'Set weekly goal';

  @override
  String get streakSection => 'Streak';

  @override
  String get weekGoalMet => 'This week\'s goal met';

  @override
  String get weekActivity => 'This week';

  @override
  String get notCountedInStreak => 'Not counted in the streak';

  @override
  String activeDaysCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active days',
      one: '1 active day',
    );
    return '$_temp0';
  }

  @override
  String activeDaysToGo({required int count}) {
    return '$count active days to go';
  }

  @override
  String get streakRestartsThisWeek => 'Starting again this week';

  @override
  String get noStreakYet => 'No streak';

  @override
  String lastStreak({required int previous, required int best}) {
    return 'Last streak $previous weeks, best $best';
  }

  @override
  String get streakStartsAfterGoal => 'Starts once a week\'s goal is met';

  @override
  String streakWeeks({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-week streak',
      one: '1-week streak',
    );
    return '$_temp0';
  }

  @override
  String streakPendingBest({required int best}) {
    return 'This week in progress · best $best';
  }

  @override
  String streakBest({required int best}) {
    return 'Best $best weeks';
  }

  @override
  String goalDayLabel({required int day}) {
    return 'Day $day';
  }

  @override
  String goalDayActive({required int day}) {
    return 'Day $day, active';
  }

  @override
  String activeDaysFraction({required int active, required int target}) {
    return '$active / $target active days';
  }

  @override
  String goalFromThisWeek({required int count}) {
    return '$count days a week from this week';
  }

  @override
  String goalFromNextWeek({required int count}) {
    return '$count days a week from next week';
  }

  @override
  String get pauseWeeklyGoal => 'Pause weekly goal';

  @override
  String get pauseWeeklyGoalMessage =>
      'Paused weeks don\'t count and don\'t break the streak.';

  @override
  String get pauseThisWeek => 'Pause this week';

  @override
  String get pauseUntilResumed => 'Until resumed';

  @override
  String get activeDaysPerWeekQuestion => 'Active days per week';

  @override
  String suggestedDays({required int count}) {
    return 'Last 4 weeks\' average: $count days a week';
  }

  @override
  String get goalStartSection => 'Starts';

  @override
  String get fromNextWeek => 'From next week';

  @override
  String get fromNextWeekDetail => 'This week keeps the previous goal';

  @override
  String get applyThisWeek => 'Apply this week';

  @override
  String get applyThisWeekDetail => 'Recounts this week';

  @override
  String get pauseOrTurnOff => 'Pause or turn off';

  @override
  String get weeklyGoalOffDetail => 'Off hides the goal and streak';

  @override
  String get thisWeekPaused => 'This week paused';

  @override
  String thisWeekActiveDays({required int active, required int target}) {
    return '$active / $target active days this week';
  }

  @override
  String get workoutInProgress => 'Workout in progress';

  @override
  String workoutCurrentSet({
    required String exercise,
    required int set,
    required int done,
  }) {
    return '$exercise · set $set · $done sets done';
  }

  @override
  String get backToWorkout => 'Back to workout';

  @override
  String get thisSession => 'This session';

  @override
  String get setsCompleted => 'Sets done';

  @override
  String get exerciseProgress => 'Exercises';

  @override
  String get personalRecords => 'PRs';

  @override
  String get otherEntries => 'Other entries';

  @override
  String get customiseToday => 'Customize Today';

  @override
  String get showAll => 'Show all';

  @override
  String get nextStep => 'Next';

  @override
  String get includesEstimates => 'Includes estimates';

  @override
  String partialMacros({required String macros}) {
    return 'Some entries lack $macros; not counted.';
  }

  @override
  String routineCompleted({required String name}) {
    return '$name done';
  }

  @override
  String get totalSets => 'Total sets';

  @override
  String get exercisesLabel => 'Exercises';

  @override
  String get todaySectionGlance => 'Today\'s figures';

  @override
  String get todaySectionActivity => 'Today\'s activity';

  @override
  String get todaySectionWeek => 'This week';

  @override
  String get todaySectionRecords => 'Today\'s entries';

  @override
  String get todaySectionInsights => 'Worth noting';

  @override
  String weekdayActive({required String weekday}) {
    return '$weekday, active';
  }

  @override
  String allCount({required int count}) {
    return 'All $count';
  }

  @override
  String daysFraction({required int active, required int target}) {
    return '$active / $target days';
  }

  @override
  String weightChange7Days({required String change}) {
    return '7 days $change';
  }

  @override
  String trackingChangeRefused({required int count}) {
    return '$count sessions use this tracking type; changing it would change what they mean. To track differently, create a new exercise.';
  }

  @override
  String get createCustomExercise => 'Create custom exercise';

  @override
  String get editExercise => 'Edit exercise';

  @override
  String exerciseOfSource({required String source}) {
    return '$source exercise';
  }

  @override
  String get createAndAdd => 'Create and add';

  @override
  String get nameSection => 'Name';

  @override
  String get exerciseNameHint => 'E.g. Dumbbell bench press';

  @override
  String get trackingTypeSection => 'Tracking';

  @override
  String get trackingTypeLocked =>
      'Can\'t change to an incompatible tracking type later.';

  @override
  String get primaryMuscleOrPattern => 'Main muscles or movement';

  @override
  String get equipmentSection => 'Equipment';

  @override
  String get equipmentAny => 'Any';

  @override
  String get possibleDuplicate => 'This exercise may already exist';

  @override
  String entriesCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get useThis => 'Use this';

  @override
  String get duplicateAdvice =>
      'Pick the existing one to keep history and PRs in one place.';

  @override
  String exerciseDemoLabel({required String name, required int count}) {
    return '$name demonstration, $count positions';
  }

  @override
  String get playing => 'Playing';

  @override
  String get exerciseDemoCredit =>
      'Images: Workout Guide / Everkinetic · CC BY-SA 4.0';

  @override
  String get myAliases => 'My aliases';

  @override
  String get aliasesHint => 'Separate with commas, e.g. squat, 深蹲';

  @override
  String get aliasesUpdated => 'Aliases updated';

  @override
  String get cannotMergeSelf => 'Can\'t merge into itself';

  @override
  String mergeTitle({required String duplicate, required String canonical}) {
    return 'Merge \"$duplicate\" into \"$canonical\"?';
  }

  @override
  String mergeMessage({required String canonical}) {
    return 'Past entries count under \"$canonical\" and this exercise leaves the picker. Entries aren\'t rewritten, but the merge can\'t be undone.';
  }

  @override
  String mergeInto({required String canonical}) {
    return 'Merge into \"$canonical\"';
  }

  @override
  String mergedInto({required String canonical}) {
    return 'Merged into \"$canonical\"';
  }

  @override
  String get addThisExercise => 'Add this exercise';

  @override
  String get otherVariations => 'Other variations';

  @override
  String get cuesSection => 'Cues';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get favoriteRemoved => 'Removed from favorites';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get editExerciseDetail => 'Name, equipment, body part';

  @override
  String get editMyAliases => 'Edit my aliases';

  @override
  String builtInNames({required String names}) {
    return 'Built-in names: $names';
  }

  @override
  String get mergeIntoAnother => 'Merge into another exercise';

  @override
  String get mergeIntoAnotherDetail =>
      'For duplicates: keep entries under one exercise';

  @override
  String get unhide => 'Unhide';

  @override
  String get hideExercise => 'Hide this exercise';

  @override
  String unhidden({required String name}) {
    return '\"$name\" unhidden';
  }

  @override
  String hidden({required String name}) {
    return '\"$name\" hidden';
  }

  @override
  String get bodyPartLabel => 'Body part';

  @override
  String get primaryMuscles => 'Primary muscles';

  @override
  String get secondaryMuscles => 'Secondary muscles';

  @override
  String get movementPatternLabel => 'Movement pattern';

  @override
  String get lateralityLabel => 'Sides';

  @override
  String get lastWorkingSet => 'Last working set';

  @override
  String get estimatedMax => 'Estimated max';

  @override
  String get sessionsUnit => 'times';

  @override
  String get trainingEntries => 'Sessions';

  @override
  String estimatedMaxTrend({required int count}) {
    return 'Estimated max trend, $count sessions';
  }

  @override
  String get epleyEstimate => 'Epley estimate';

  @override
  String relativeLoadPercent({required int percent}) {
    return 'Relative load $percent%';
  }

  @override
  String get last90Days => 'Last 90 days';

  @override
  String get filterTitle => 'Filter';

  @override
  String filtersApplied({required int count}) {
    return '$count filters applied';
  }

  @override
  String showExercises({required int count}) {
    return 'Show $count exercises';
  }

  @override
  String get clearAll => 'Clear all';

  @override
  String wholeRegion({required String region}) {
    return 'All $region';
  }

  @override
  String get sourceLabel => 'Source';

  @override
  String get pickerTabRecent => 'Recent';

  @override
  String get pickerTabFavorites => 'Favorites';

  @override
  String get pickerTabHomeGym => 'Home gym';

  @override
  String get pickerTabAll => 'All exercises';

  @override
  String get pickerAddToRoutine => 'Add to routine';

  @override
  String get pickerAddToWorkout => 'Add to workout';

  @override
  String get pickerAddToEntry => 'Add to entry';

  @override
  String get pickerBrowse => 'Browse and search all exercises';

  @override
  String get pickerSingle => 'Choose one exercise';

  @override
  String pickerPurposeFor({required String purpose, required String name}) {
    return '$purpose \"$name\"';
  }

  @override
  String discardSelectedTitle({required int count}) {
    return 'Discard $count selected exercises?';
  }

  @override
  String get discardSelected => 'Discard selection';

  @override
  String get keepChoosing => 'Keep choosing';

  @override
  String get exerciseLibrary => 'Exercise library';

  @override
  String get chooseExercise => 'Choose exercise';

  @override
  String get addExercises => 'Add exercises';

  @override
  String get cantFindCreate => 'Not found? Create a custom exercise';

  @override
  String get searchExercisesHint => 'Search exercises, aliases or equipment…';

  @override
  String get clearAction => 'Clear';

  @override
  String daysAgo({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String aboutItem({required String name}) {
    return 'About $name';
  }

  @override
  String get selectionOrderHint => 'Order added · tap to remove';

  @override
  String removeNumbered({required int index, required String name}) {
    return 'Remove no. $index: $name';
  }

  @override
  String addExercisesCount({required int count}) {
    return 'Add $count exercises';
  }

  @override
  String get noMatchingExercises => 'No matching exercises';

  @override
  String equipmentFilterHint({required String equipment}) {
    return 'Filtered to \"$equipment\"; the exercise may use other equipment.';
  }

  @override
  String get searchAgainHint =>
      'Try other words, the English name or an alias.';

  @override
  String get removeEquipmentFilter => 'Remove equipment filter';

  @override
  String get similarExercises => 'Similar exercises';

  @override
  String createNamed({required String name}) {
    return 'Create \"$name\"';
  }

  @override
  String estimatedMaxValue({required int weight}) {
    return 'Est. max $weight kg';
  }

  @override
  String lastSetOn({required String date, required String set}) {
    return 'Last $date $set';
  }

  @override
  String get volumeTitle => 'Volume';

  @override
  String get notEnoughWorkouts => 'Not enough workouts.';

  @override
  String volumeOf({required String exercise}) {
    return '$exercise volume';
  }

  @override
  String insightWeeks({required int weeks}) {
    return 'Worth noting · last $weeks weeks';
  }

  @override
  String volumeSteady({required int sets, required String estimate}) {
    return 'Weekly working sets steady at $sets; estimated max $estimate.';
  }

  @override
  String get notYetEstimable => 'not yet estimable';

  @override
  String get basisSection => 'Basis';

  @override
  String weeklySetsFrom({required int count}) {
    return 'Weekly working sets from $count workouts.';
  }

  @override
  String get dataQualitySection => 'Data quality';

  @override
  String workoutsAllLogged({required int count}) {
    return '$count workouts logged';
  }

  @override
  String get weightRepsManual => 'Weights and reps entered by hand';

  @override
  String get timeRangeSection => 'Time range';

  @override
  String fullWeeks({required int count}) {
    return '$count full weeks';
  }

  @override
  String get actionsSection => 'What to do';

  @override
  String volumeDropped({required int sets}) {
    return 'Weekly sets are below where this period began. To keep progressing, return to about $sets.';
  }

  @override
  String get volumeStable =>
      'Sets are steady. To keep progressing, add a little weekly volume or weight.';

  @override
  String adjustRoutineSets({required String routine}) {
    return 'Adjust sets in \"$routine\"';
  }

  @override
  String get notMedicalAdvice =>
      'Describes training records; not medical advice.';

  @override
  String get viewRawEntries => 'View entries from this period';

  @override
  String get noWorkingSets => 'No working sets';

  @override
  String muscleWeeklySets({required String muscle, required int sets}) {
    return '$muscle $sets sets a week';
  }

  @override
  String muscleScaleLabel({required int top}) {
    return 'Scale from 0 to $top+ sets';
  }

  @override
  String get setsPerWeek => 'sets / week';

  @override
  String get muscleMapLabel =>
      'Body map of muscle volume; figures listed below';

  @override
  String get musclesTitle => 'Muscles';

  @override
  String get weeklySetsLast8 => 'Weekly working sets · last 8 weeks';

  @override
  String get setsThisWeekUnit => 'sets · this week';

  @override
  String priorWeeksSets({required int weeks, required String sets}) {
    return 'Prior $weeks weeks: $sets sets';
  }

  @override
  String muscleSetsChart({required String muscle, required String sets}) {
    return '$muscle weekly sets: $sets';
  }

  @override
  String heaviestSet({required String set, required String date}) {
    return 'Heaviest $set · $date';
  }

  @override
  String estimatedMaxOn({required int weight, required String date}) {
    return 'Est. max $weight kg · $date';
  }

  @override
  String get last4Weeks => 'Last 4 weeks';

  @override
  String monthsCount({required int count}) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get weeklySetsTitle => 'Weekly sets';

  @override
  String get last8Weeks => 'Last 8 weeks';

  @override
  String get weeklyWorkouts => 'Workouts per week';

  @override
  String get weeklyActivities => 'Activities per week';

  @override
  String get timesThisWeekUnit => 'this week';

  @override
  String get noActivityEntries => 'No activities';

  @override
  String minutesVersusUsual({required int minutes, required int usual}) {
    return '$minutes min · usually $usual min';
  }

  @override
  String get trendDomainBody => 'Body';

  @override
  String get trendDomainTraining => 'Training';

  @override
  String get trendDomainSleep => 'Sleep';

  @override
  String get trendDomainNutrition => 'Nutrition';

  @override
  String get trendDomainActivity => 'Activity';

  @override
  String areaTrend({required String area}) {
    return '$area trend';
  }

  @override
  String sleepTimesAverage({required String bedtime, required String wake}) {
    return 'Bed $bedtime · wake $wake';
  }

  @override
  String get last4WeeksAverage => 'Last 4 weeks\' average';

  @override
  String get weekdaySection => 'Day of week';

  @override
  String get otherAreasSection => 'Other areas, same period';

  @override
  String get dailyEntries => 'Daily entries';

  @override
  String perWeekTimes({required String count}) {
    return '$count a week';
  }

  @override
  String stepsValue({required String steps}) {
    return '$steps steps';
  }

  @override
  String timesValue({required String count}) {
    return '$count×';
  }

  @override
  String weekFrom({required String date}) {
    return 'Week of $date';
  }

  @override
  String get last13Weeks => 'Last 13 weeks';

  @override
  String get pastYear => 'Past year';

  @override
  String get prior12Weeks => 'Prior 12 weeks';

  @override
  String periodAverage({required String period}) {
    return '$period average';
  }

  @override
  String get weeklyCount => 'Per week';

  @override
  String get weeklyAverage => 'Weekly average';

  @override
  String get weeklyTotal => 'Weekly total';

  @override
  String daysLoggedPerWeek({required String days}) {
    return 'Last 4 weeks: $days days logged a week on average';
  }

  @override
  String get scaleWeight => 'Scale weight';

  @override
  String get weeklyVolume => 'Weekly volume';

  @override
  String get restingHeartRate => 'Resting heart rate';

  @override
  String get weightAndNutrition => 'Weight and nutrition';

  @override
  String get energyBalance => 'Energy balance';

  @override
  String energyNeeds({
    required int window,
    required int foodDays,
    required int weighings,
    required int currentFood,
    required int currentWeighings,
  }) {
    return 'Needs $foodDays complete food days and $weighings weigh-ins in the last $window days (now $currentFood and $currentWeighings)';
  }

  @override
  String proteinNeeds({required int window, required int days}) {
    return 'Needs $days complete food days with weight in the last $window days';
  }

  @override
  String get muscleSetsTitle => 'Sets per muscle';

  @override
  String muscleSetsNeeds({required int count}) {
    return 'Needs at least $count workouts in the last 4 weeks';
  }

  @override
  String get possibleRelations => 'Possible relations';

  @override
  String get longRunSection => 'Long run';

  @override
  String actualExpenditure({required String kcal}) {
    return 'Actual expenditure about $kcal kcal/day';
  }

  @override
  String intakeDeficit({
    required int window,
    required String intake,
    required String balance,
  }) {
    return 'Last $window days: $intake kcal in on average, $balance kcal deficit a day';
  }

  @override
  String intakeSurplus({
    required int window,
    required String intake,
    required String balance,
  }) {
    return 'Last $window days: $intake kcal in on average, $balance kcal surplus a day';
  }

  @override
  String weightForecast({
    required String change,
    required int weeks,
    required String forecast,
  }) {
    return 'Trend weight $change kg a week, about $forecast kg in $weeks weeks';
  }

  @override
  String foodDaysWeighings({required int foodDays, required int weighings}) {
    return '$foodDays complete food days · $weighings weigh-ins';
  }

  @override
  String get intakeUnderlogged =>
      'Estimated expenditure is below resting metabolism; logged intake may be short.';

  @override
  String get estimatedFromEntries => 'Estimated from entries';

  @override
  String weekendEatsMore({required String kcal}) {
    return '$kcal kcal more a day at weekends';
  }

  @override
  String weekendEatsLess({required String kcal}) {
    return '$kcal kcal less a day at weekends';
  }

  @override
  String weekdayWeekendKcal({
    required String weekday,
    required String weekend,
  }) {
    return 'Weekdays $weekday kcal · weekends $weekend kcal';
  }

  @override
  String get offsetsAllDeficit => 'Cancels the whole weekday deficit';

  @override
  String offsetsDeficitShare({required int percent}) {
    return 'Cancels about $percent% of the weekday deficit';
  }

  @override
  String weekdaysWeekends({
    required int window,
    required int weekdays,
    required int weekends,
  }) {
    return 'Last $window days: $weekdays weekdays, $weekends weekend days';
  }

  @override
  String proteinMet({required String target}) {
    return 'Protein reaches $target g/kg';
  }

  @override
  String proteinShort({required int grams}) {
    return 'Protein about $grams g short a day';
  }

  @override
  String trainingRestProtein({required String trained, required String rest}) {
    return 'Training days $trained · rest days $rest g/kg';
  }

  @override
  String proteinBasis({
    required String weight,
    required String target,
    required int days,
  }) {
    return 'At $weight kg, goal $target g/kg · $days complete food days';
  }

  @override
  String allMusclesEnough({required int target}) {
    return 'Every trained muscle gets $target+ sets a week';
  }

  @override
  String muscleOnlySets({required String muscle, required int sets}) {
    return '$muscle gets only $sets sets a week';
  }

  @override
  String underSets({required int target, required String muscles}) {
    return 'Under $target sets: $muscles';
  }

  @override
  String atLeastSets({required int target, required String muscles}) {
    return '$target+ sets: $muscles';
  }

  @override
  String pairRatio({
    required String first,
    required String second,
    required int firstSets,
    required int secondSets,
  }) {
    return '$first to $second $firstSets : $secondSets sets';
  }

  @override
  String get musclePush => 'Push';

  @override
  String get musclePull => 'Pull';

  @override
  String get muscleSetsBasis =>
      'Weekly sets over 4 weeks, primary muscles only';

  @override
  String weekendWakeLater({required String time}) {
    return 'Waking $time later at weekends';
  }

  @override
  String weekendWakeEarlier({required String time}) {
    return 'Waking $time earlier at weekends';
  }

  @override
  String weekdayWeekendWake({
    required String weekday,
    required String weekend,
  }) {
    return 'Weekdays $weekday · weekends $weekend wake';
  }

  @override
  String get correlationCaveat => 'Correlation, not causation';

  @override
  String get muscleFigureMale => 'Male';

  @override
  String get muscleFigureFemale => 'Female';

  @override
  String get workoutDiscarded => 'Workout discarded';

  @override
  String get endWorkout => 'End workout';

  @override
  String get addExercise => 'Add exercise';

  @override
  String get notFilled => 'Empty';

  @override
  String get startExercising => 'Start';

  @override
  String get finishWorkout => 'Finish workout';

  @override
  String personalRecordSet({required String set}) {
    return 'PR · $set';
  }

  @override
  String get totalShort => 'Total';

  @override
  String get notStarted => 'Not started';

  @override
  String get totalVolume => 'Total volume';

  @override
  String versusLastTime({required String change}) {
    return '$change vs last time';
  }

  @override
  String setsOfTotal({required int done, required int total}) {
    return '$done / $total sets';
  }

  @override
  String get restTitle => 'Rest';

  @override
  String get rest30More => 'Rest 30 s more';

  @override
  String get skipRest => 'Skip rest';

  @override
  String get elapsedTime => 'Time';

  @override
  String get workoutNotesTitle => 'Workout note';

  @override
  String get workoutNotesHint => 'E.g. slept badly, grip gave out first';

  @override
  String get addWarmupSets => 'Add warm-up sets';

  @override
  String get addDropSet => 'Add drop set';

  @override
  String get addFailureSet => 'Add failure set';

  @override
  String get replaceExercise => 'Replace this exercise';

  @override
  String get removeFromWorkout => 'Remove from workout';

  @override
  String get superset => 'Superset';

  @override
  String optionsFor({required String name}) {
    return 'Options for $name';
  }

  @override
  String volumeValue({required String volume}) {
    return 'Volume $volume kg';
  }

  @override
  String lastSetShort({required String date, required String set}) {
    return 'Last $date · $set';
  }

  @override
  String get loadPrevious => 'Load';

  @override
  String get loadPreviousLabel => 'Fill in last time\'s weights and reps';

  @override
  String get quickFill => 'Quick fill';

  @override
  String get quickFillLabel => 'Copy the first set to the others';

  @override
  String get setColumn => 'Set';

  @override
  String get repsColumn => 'Reps';

  @override
  String get removeSet => 'Remove set';

  @override
  String get addSet => 'Add set';

  @override
  String editItem({required String item}) {
    return 'Edit $item';
  }

  @override
  String setWeight({required String set}) {
    return '$set weight';
  }

  @override
  String setReps({required String set}) {
    return '$set reps';
  }

  @override
  String setDone({required String set}) {
    return '$set done';
  }

  @override
  String removedNamed({required String name}) {
    return 'Removed \"$name\"';
  }

  @override
  String get routineName => 'Routine name';

  @override
  String deleteNamedTitle({required String name}) {
    return 'Delete \"$name\"?';
  }

  @override
  String get routineDeleteKeeps => 'Finished workouts are kept.';

  @override
  String get deleteRoutine => 'Delete this routine';

  @override
  String deletedNamed({required String name}) {
    return 'Deleted \"$name\"';
  }

  @override
  String aboutMinutesShort({required int minutes}) {
    return 'About $minutes min';
  }

  @override
  String get startWorkout => 'Start workout';

  @override
  String get activityBlocksWorkout =>
      'An activity is running; end it before starting a workout';

  @override
  String get plannedExercises => 'Planned exercises';

  @override
  String get soreMusclesToday => 'Sore today';

  @override
  String get recentlyDone => 'Recently done';

  @override
  String setsAndMinutes({required int sets, required int minutes}) {
    return '$sets sets · $minutes min';
  }

  @override
  String get rename => 'Rename';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get joinSuperset => 'Superset with next';

  @override
  String get leaveSuperset => 'Remove from superset';

  @override
  String get removeAction => 'Remove';

  @override
  String get eachSide => 'Each side';

  @override
  String get oneSetLessToday => '1 set fewer today';

  @override
  String get loadPreviousFill => 'Fill with last time\'s weights and reps';

  @override
  String get myRoutines => 'My routines';

  @override
  String get loadFromHistory => 'From history';

  @override
  String startWorkoutCount({required int count}) {
    return 'Start workout ($count exercises)';
  }

  @override
  String get describeInWords => 'Describe';

  @override
  String get addExercisesByHand => 'Add exercises';

  @override
  String get deleteAction => 'Delete';

  @override
  String deleteNamed({required String name}) {
    return 'Delete \"$name\"';
  }

  @override
  String get newRoutine => 'New routine';

  @override
  String get noWorkouts => 'No workouts';

  @override
  String get selectAll => 'Select all';

  @override
  String pastSet({
    required int number,
    required String weight,
    required int reps,
  }) {
    return 'Set $number: $weight kg × $reps';
  }

  @override
  String routineSummary({required int exercises, required int sets}) {
    return '$exercises exercises · $sets sets';
  }

  @override
  String get saveAsRoutine => 'Save as routine';

  @override
  String get describeWorkoutHint =>
      'E.g.\nBarbell squat 4×8 60kg\nBench press 3 sets of 10 at 40 kg\nPull-up 3x8';

  @override
  String get noExercisesRead => 'No exercises found';

  @override
  String removeNamed({required String name}) {
    return 'Remove \"$name\"';
  }

  @override
  String get exerciseNotFound => 'Exercise not found';

  @override
  String setsTimesReps({
    required int sets,
    required int reps,
    required String weight,
  }) {
    return '$sets × $reps · $weight kg';
  }

  @override
  String setsSameWeight({
    required int sets,
    required String weight,
    required String reps,
  }) {
    return '$sets sets · $weight kg × $reps';
  }

  @override
  String get editWorkout => 'Edit workout';

  @override
  String get timeSection => 'Time';

  @override
  String get durationLabel => 'Duration';

  @override
  String savedAsRoutine({required String name}) {
    return 'Saved as routine \"$name\"';
  }

  @override
  String get keepAsIs => 'Keep as is';

  @override
  String get applyAction => 'Apply';

  @override
  String get progressionIncrease => 'Increase';

  @override
  String get progressionHold => 'Hold';

  @override
  String get progressionDeload => 'Deload';

  @override
  String get nextTimeSuggestions => 'Next time';

  @override
  String changedTo({required String name, required String weight}) {
    return '$name set to $weight kg';
  }

  @override
  String decreaseBy({required String amount}) {
    return 'Decrease by $amount';
  }

  @override
  String increaseBy({required String amount}) {
    return 'Increase by $amount';
  }

  @override
  String get oneRepLess => '1 rep fewer';

  @override
  String get oneRepMore => '1 rep more';

  @override
  String get notLogged => 'None';

  @override
  String get deleteThisSet => 'Delete this set';

  @override
  String get platesImpossible => 'Plates can\'t make this weight';

  @override
  String get emptyBar => 'Empty bar';

  @override
  String platesPerSide({required String plates}) {
    return 'Each side $plates';
  }

  @override
  String setNumberWeight({required int number}) {
    return 'Set $number weight';
  }

  @override
  String setNumberReps({required int number}) {
    return 'Set $number reps';
  }

  @override
  String get replaceTodayOnly => 'Today only';

  @override
  String get replaceTodayOnlyDetail => 'Use the new exercise this time only';

  @override
  String get replaceInRoutine => 'Update routine too';

  @override
  String get replaceInRoutineDetail => 'Use the new exercise from now on';

  @override
  String replacedToday({required String name}) {
    return 'Doing \"$name\" today';
  }

  @override
  String replacedInRoutine({required String routine, required String name}) {
    return '\"$routine\" now uses \"$name\", from today';
  }

  @override
  String replacePattern({required String pattern}) {
    return 'Replace $pattern';
  }

  @override
  String todaysExerciseNumber({required String routine, required int number}) {
    return 'Today\'s \"$routine\" · exercise $number';
  }

  @override
  String get replaceAction => 'Replace';

  @override
  String get candidateExercises => 'Candidates';

  @override
  String get chooseFromAll => 'Choose from all exercises';

  @override
  String get applyScope => 'Applies to';

  @override
  String equipmentChangeWarning({required String from, required String to}) {
    return 'No reliable weight conversion from $from to $to: sets, reps and RIR are kept; set the weight again.';
  }

  @override
  String get exerciseInfo => 'About exercise';

  @override
  String get noFinishedWorkout => 'No finished workout';

  @override
  String get totalAmount => 'Volume';

  @override
  String get workloadSection => 'How hard';

  @override
  String get trainedAreas => 'Trained areas';

  @override
  String get muscleSetsLast7 => 'Sets per muscle, last 7 days';

  @override
  String get editThisEntry => 'Edit this entry';

  @override
  String get volumeSame => 'Volume same as last time';

  @override
  String volumeChangePercent({required String change}) {
    return 'Volume $change% vs last time';
  }

  @override
  String setsAndVolume({required int sets, required String volume}) {
    return '$sets sets · $volume kg';
  }

  @override
  String get qualityConfirmed => 'Confirmed';

  @override
  String get qualityPortionEstimated => 'Portion estimated';

  @override
  String get qualityCustomFood => 'Custom food';

  @override
  String get qualityQuickLog => 'Quick log';

  @override
  String get qualityAiEstimate => 'AI estimate';

  @override
  String qualityAiEstimateBy({required String source}) {
    return '$source estimate';
  }

  @override
  String get nutritionLabel => 'Nutrition label';

  @override
  String photoItemsCount({required int count}) {
    return '$count items in the photo';
  }

  @override
  String get mergeIntoOneFood => 'Combine as one food';

  @override
  String get logEachItem => 'Log each item';

  @override
  String get nutrientNegative => 'Nutrients can\'t be negative.';

  @override
  String updatedNamed({required String name}) {
    return 'Updated \"$name\"';
  }

  @override
  String get editThisMeal => 'Edit meal';

  @override
  String get newFood => 'New food';

  @override
  String get editFood => 'Edit food';

  @override
  String get scanFoodOrLabel => 'Scan food or label';

  @override
  String get createOnly => 'Create only';

  @override
  String get createAndLog => 'Create and log';

  @override
  String labelReadBy({required String provider, required String model}) {
    return 'Figures read by $provider ($model); check them against the package.';
  }

  @override
  String photoEstimatedBy({required String provider, required String model}) {
    return 'Figures estimated from the photo by $provider ($model); check them.';
  }

  @override
  String get foodNameHint => 'E.g. Chicken breast';

  @override
  String get mealTypeOptional => 'Meal';

  @override
  String get saveToLibrary => 'Save to library';

  @override
  String get cupSize => 'Cup size';

  @override
  String get cupSizeHint => 'E.g. Tall';

  @override
  String get brandLabel => 'Brand';

  @override
  String get brandHint => 'E.g. Brand name';

  @override
  String get foodOrDrink => 'Food or drink';

  @override
  String get volumeLabel => 'Volume';

  @override
  String get portionSection => 'Portion';

  @override
  String get portionHint => 'E.g. one bowl';

  @override
  String get newCupSize => 'Add cup size';

  @override
  String get nutrientsSection => 'Nutrients';

  @override
  String per100Unit({required String unit}) {
    return 'Per 100 $unit';
  }

  @override
  String get perServingTotal => 'Per serving';

  @override
  String get abvLabel => 'ABV';

  @override
  String get deleteThisMeal => 'Delete this meal';

  @override
  String get countryTW => 'Taiwan';

  @override
  String get countryJP => 'Japan';

  @override
  String get countryUS => 'United States';

  @override
  String get countryEU => 'EU';

  @override
  String get countryAU => 'Australia';

  @override
  String get countryNZ => 'New Zealand';

  @override
  String get countryKR => 'South Korea';

  @override
  String get countryCN => 'China';

  @override
  String get countryCA => 'Canada';

  @override
  String brandInCountry({required String brand, required String country}) {
    return '$brand ($country)';
  }

  @override
  String get officialData => 'Official data';

  @override
  String updatedOn({required String date}) {
    return 'Updated $date';
  }

  @override
  String get foodScopeAll => 'All';

  @override
  String get foodScopeRecent => 'Recent';

  @override
  String get foodScopeStarred => 'Favorites';

  @override
  String get foodScopeOwn => 'Mine';

  @override
  String get foodScopeBrands => 'Brands';

  @override
  String loggedNamed({required String name}) {
    return 'Logged \"$name\"';
  }

  @override
  String get loggedToast => 'Logged';

  @override
  String mealTypeHeaderLabel({required String meal}) {
    return 'Meal, now $meal';
  }

  @override
  String get unspecified => 'None';

  @override
  String get searchFoodHint => 'Search foods or brands';

  @override
  String get takePhotoAction => 'Photo';

  @override
  String get recentMealsSection => 'Recent meals';

  @override
  String get noFoods => 'No foods';

  @override
  String get eatenFoods => 'Foods eaten';

  @override
  String get noRecentFoods => 'No recent foods.';

  @override
  String get starredFoods => 'Favorite foods';

  @override
  String get starredMeals => 'Favorite meals';

  @override
  String get noFavorites => 'No favorites.';

  @override
  String get noOwnFoods => 'No foods of your own';

  @override
  String get noBuiltInBrands => 'No built-in chains.';

  @override
  String viewFullMenu({required String brand}) {
    return '$brand · full menu';
  }

  @override
  String get noMatchingItems => 'No matches';

  @override
  String get notFoundQuestion => 'Not found?';

  @override
  String get purposeSection => 'Goal';

  @override
  String mergedCount({required int count}) {
    return 'Merged $count entries';
  }

  @override
  String removedWater({required int millilitres}) {
    return 'Removed $millilitres mL of water';
  }

  @override
  String get splitDone => 'Split into its own entry';

  @override
  String get mergeAction => 'Merge';

  @override
  String get mergeEntries => 'Merge entries';

  @override
  String get cancelMerge => 'Cancel merge';

  @override
  String get mergeIntoMeal => 'Merge into one meal';

  @override
  String mergeCountIntoMeal({required int count}) {
    return 'Merge $count into one meal';
  }

  @override
  String get setGoal => 'Set goal';

  @override
  String get changeAction => 'Change';

  @override
  String get dailyIndicators => 'Daily indicators';

  @override
  String get mealsSection => 'Meals';

  @override
  String get mealShare => 'Share';

  @override
  String get mealShareHide => 'Hide share';

  @override
  String get noMealsThisDay => 'No meals logged this day';

  @override
  String get waterSection => 'Water';

  @override
  String removeWaterAt({required String time}) {
    return 'Remove water at $time';
  }

  @override
  String get otherNutrients => 'Other nutrients';

  @override
  String itemsCountShort({required int count}) {
    return '$count items';
  }

  @override
  String get splitIntoEntry => 'Split into own entry';

  @override
  String entriesWithoutKcal({required int count}) {
    return '$count entries lack calories; actual is higher';
  }

  @override
  String eatenKcal({required String kcal}) {
    return '$kcal kcal eaten';
  }

  @override
  String eatenOfTarget({required String kcal, required String target}) {
    return '$kcal of $target kcal eaten';
  }

  @override
  String get eatenKcalTitle => 'kcal eaten';

  @override
  String get remainingKcalTitle => 'kcal left';

  @override
  String get overKcalTitle => 'kcal over';

  @override
  String get workedOut => 'Worked out';

  @override
  String get caffeineRemaining => 'Estimated caffeine left';

  @override
  String halfLifeBasis({required String hours}) {
    return 'From a $hours-hour half-life';
  }

  @override
  String caffeineReference({required String mg}) {
    return 'Bedtime reference $mg mg';
  }

  @override
  String get last24Hours => 'Last 24 hours';

  @override
  String workedOutValue({required String value}) {
    return '$value · worked out';
  }

  @override
  String caffeineValue({required String mg}) {
    return 'Caffeine $mg mg';
  }

  @override
  String oneServingIs({required String serving}) {
    return '1 serving = $serving';
  }

  @override
  String get starred => 'Saved';

  @override
  String get starAction => 'Save';

  @override
  String get starThisFood => 'Save this food';

  @override
  String get editThisFood => 'Edit this food';

  @override
  String addPortion({required String portion}) {
    return 'Add $portion';
  }

  @override
  String get servingsLabel => 'Servings';

  @override
  String get actualAmount => 'Amount';

  @override
  String get barcode => 'Barcode';

  @override
  String get allergens => 'Allergens';

  @override
  String get none => 'None';

  @override
  String get valueTypeMaxNote => 'Label shows a maximum; actual may be lower.';

  @override
  String dataSource({required String source}) {
    return 'Source: $source';
  }

  @override
  String get deleteThisFood => 'Delete this food';

  @override
  String itemsWithoutKcal({required int count}) {
    return '$count without calories';
  }

  @override
  String get thisMeal => 'This meal';

  @override
  String get finishEditing => 'Done editing';

  @override
  String logItemsCount({required int count}) {
    return 'Log $count items';
  }

  @override
  String get plateEmpty => 'This meal has no items.';

  @override
  String get photoEstimate => 'Photo estimate';

  @override
  String get retry => 'Retry';

  @override
  String get chooseAiFirst => 'Choose an AI to draft.';

  @override
  String get foodPhoto => 'Food photo';

  @override
  String get describeMealHint =>
      'E.g. breakfast: egg crepe and a large iced milk tea';

  @override
  String get draftSection => 'Draft';

  @override
  String openAiSettings({required String me}) {
    return 'Open $me > AI';
  }

  @override
  String get dailyKcalGoal => 'Daily calorie goal';

  @override
  String get kcalRangeError => 'Enter 800–6000 kcal.';

  @override
  String numberRangeError({required String min, required String max}) {
    return 'Enter $min–$max.';
  }

  @override
  String get weeklyChange => 'Weekly change';

  @override
  String get dailyTargets => 'Daily targets';

  @override
  String get kcalTarget => 'Calorie target';

  @override
  String get estimateFromBody => 'Estimate from body data';

  @override
  String get estimateFromBodyDetail => 'Weight, height, age, sex and activity';

  @override
  String get setMyself => 'Set my own';

  @override
  String get bodyData => 'Body data';

  @override
  String yearValue({required int year}) {
    return '$year';
  }

  @override
  String get activityLevelSection => 'Activity level';

  @override
  String get macroSplit => 'Macro split';

  @override
  String get byGoal => 'By goal';

  @override
  String perKgBodyWeight({required String grams}) {
    return '$grams g per kg body weight';
  }

  @override
  String get proteinPerKgTitle => 'Protein (per kg body weight)';

  @override
  String byGoalGrams({required String grams}) {
    return 'By goal $grams g';
  }

  @override
  String percentOfKcal({required int percent}) {
    return '$percent% of calories';
  }

  @override
  String get fatPercentTitle => 'Fat (% of calories)';

  @override
  String defaultPercent({required int percent}) {
    return 'Default $percent%';
  }

  @override
  String get restOfKcal => 'Remaining calories';

  @override
  String get resultSection => 'Result';

  @override
  String get restingMetabolism => 'Resting metabolism';

  @override
  String get maintenanceKcal => 'Maintenance';

  @override
  String get dailyKcal => 'Daily calories';

  @override
  String missingInputs({required String inputs}) {
    return 'Missing $inputs';
  }

  @override
  String limitValue({required String value}) {
    return 'Limit $value';
  }

  @override
  String fromRecentFoodAndWeight({required int days}) {
    return 'From the last $days days of food and weight';
  }

  @override
  String get mifflinEstimate => 'Mifflin-St Jeor estimate';

  @override
  String get noCamera => 'No camera available';

  @override
  String get pickFromLibrary => 'Choose from library';

  @override
  String servingAndKcal({required String serving, required String kcal}) {
    return '1 serving $serving · $kcal kcal';
  }

  @override
  String get foodLibrary => 'Food library';

  @override
  String get noOwnFoodsSentence => 'No foods of your own.';

  @override
  String get noMatchingFoods => 'No matching foods.';

  @override
  String get officialReadOnly => 'Official data, read-only';

  @override
  String splitIntoCount({required int count}) {
    return 'Split into $count entries';
  }

  @override
  String get splitThisMeal => 'Split this meal';

  @override
  String usualMealType({required String meal}) {
    return 'Usual: $meal';
  }

  @override
  String get whichMeal => 'Meal';

  @override
  String splitDishTitle({required int count}) {
    return 'Split this dish into $count entries?';
  }

  @override
  String splitDishMessage({required String dish}) {
    return 'Each component becomes its own entry to edit, move or delete; \"$dish\" itself goes away.';
  }

  @override
  String get nowLabel => 'Now';

  @override
  String get afterSplit => 'After';

  @override
  String componentsCount({required int count}) {
    return '$count components';
  }

  @override
  String otherCount({required int count}) {
    return '$count more';
  }

  @override
  String get undoWithin30s => 'Can be undone within 30 seconds.';

  @override
  String get waterGlass => 'Glass';

  @override
  String get waterLargeGlass => 'Large glass';

  @override
  String get waterBottle => 'Bottle';

  @override
  String get waterPerTap => 'Amount per tap';

  @override
  String get customAction => 'Custom';

  @override
  String get waterPerTapMl => 'Amount per tap (mL)';

  @override
  String waterPerTapLabel({required int millilitres}) {
    return 'Amount per tap, now $millilitres millilitres';
  }

  @override
  String waterTimesLast({required int count, required String time}) {
    return '$count times · last $time';
  }

  @override
  String allDrinksTotal({required int millilitres}) {
    return 'All drinks $millilitres mL (incl. coffee, tea)';
  }

  @override
  String todayAt({required String time}) {
    return 'Today $time';
  }

  @override
  String yesterdayAt({required String time}) {
    return 'Yesterday $time';
  }

  @override
  String addNamed({required String name}) {
    return 'Add $name';
  }

  @override
  String get contentsSection => 'Contents';

  @override
  String get muscleMapSetting => 'Body map';

  @override
  String get conventionMessage =>
      'Names, salt unit and limit for daily totals; a food shows its own label.';

  @override
  String get profileSection => 'Profile';

  @override
  String get goalsAndReminders => 'Goals and reminders';

  @override
  String get featuresSection => 'Features';

  @override
  String get exerciseLibraryDetail => 'Browse, search and create exercises';

  @override
  String modulesEnabled({required String modules}) {
    return '$modules on';
  }

  @override
  String get notEnabled => 'Off';

  @override
  String get dataSection => 'Data';

  @override
  String databaseRecovered({required String path}) {
    return 'The last data file couldn\'t be read; it was moved to $path and the app started empty. The old file was not deleted.';
  }

  @override
  String get localData => 'On-device data';

  @override
  String get dataSourcesDetail => 'Typed in, imported and built in';

  @override
  String get showDemoData => 'Show demo data';

  @override
  String get exportTitle => 'Export';

  @override
  String get exportDetail => 'Full archive JSON · CSV views';

  @override
  String get privacyDetail => 'Where data is kept, what is sent';

  @override
  String get aboutSection => 'About';

  @override
  String get versionLabel => 'Version';

  @override
  String get exerciseImages => 'Exercise images';

  @override
  String get referencesTitle => 'References';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get workoutsFigure => 'Workouts';

  @override
  String get activeDaysFigure => 'Active days';

  @override
  String get daysUnit => 'days';

  @override
  String get weeksUnit => 'weeks';

  @override
  String get startedLogging => 'Logging since';

  @override
  String goalSummaryText({required int target, required int active}) {
    return '$target active days a week · $active this week';
  }

  @override
  String proteinGrams({required String grams}) {
    return 'Protein $grams g';
  }

  @override
  String foodLibrarySummary({required int own, required int brands}) {
    return '$own of your own · $brands brands';
  }

  @override
  String get birthYearHint => 'E.g. 1995';

  @override
  String get birthYearError => 'Enter a four-digit birth year.';

  @override
  String get sexUseMessage => 'Used only to estimate daily calories.';

  @override
  String get fullArchiveJson => 'Full archive (JSON)';

  @override
  String get fullArchiveDetail => 'Restores everything';

  @override
  String get fullArchiveDone => 'Full archive created';

  @override
  String get csvViews => 'CSV views';

  @override
  String get csvViewsDetail => 'Easy to read, may lose detail';

  @override
  String get csvViewsDone => 'CSV views created';

  @override
  String get exportNotEncrypted => 'Exported files are not encrypted.';

  @override
  String exportDoneFile({required String done, required String file}) {
    return '$done: $file';
  }

  @override
  String exportFailed({required String error}) {
    return 'Export failed: $error';
  }

  @override
  String appliedTo({required String routine}) {
    return 'Applied to \"$routine\"';
  }

  @override
  String get aiProposalTitle => 'AI suggested changes';

  @override
  String aiProposalSubtitle({required String routine}) {
    return 'Routine \"$routine\" · not applied';
  }

  @override
  String get reject => 'Reject';

  @override
  String get acceptAndApply => 'Accept and apply';

  @override
  String get questionLabel => 'Question';

  @override
  String get proposalQuestion =>
      '\"Have my squat sets dropped too low lately? Add them back.\"';

  @override
  String changesCount({required int count}) {
    return '$count exercises changed';
  }

  @override
  String get reasonLabel => 'Reason';

  @override
  String get proposalReason =>
      'Weekly working sets fell from 12 to 8; for the strength-maintenance goal the engine suggests 10–12.';

  @override
  String get proposalDataSent => 'Data sent: last 4 weeks of workouts';

  @override
  String get proposalModel => 'Model: self-hosted endpoint';

  @override
  String get addedLabel => 'Added';

  @override
  String get unchangedLabel => 'Unchanged';

  @override
  String setsTimesRepsShort({required int sets, required int reps}) {
    return '$sets × $reps';
  }

  @override
  String get privacyStorage => 'Storage';

  @override
  String get privacyRecords => 'Records';

  @override
  String get privacyRecordsValue => 'Only on this device';

  @override
  String get privacyAccount => 'Account';

  @override
  String get privacyServer => 'Server';

  @override
  String get privacyDeleted => 'Deleted records';

  @override
  String get privacyDeletedValue => 'Recoverable';

  @override
  String get privacyUninstall => 'Uninstalling the app';

  @override
  String get privacyUninstallValue => 'Erases all records';

  @override
  String get privacyCameraSection => 'Camera and photos';

  @override
  String get privacyCamera => 'Camera';

  @override
  String get privacyCameraValue => 'Only on while scanning';

  @override
  String get privacyPhotos => 'Photo library';

  @override
  String get privacyPhotosValue =>
      'Reads the latest photo as the picker button\'s thumbnail';

  @override
  String get privacyScalePhotos => 'Scale and measurement photos';

  @override
  String get privacyScalePhotosValue => 'Read on the device, not sent';

  @override
  String privacyHealthSection({required String platform}) {
    return 'Health data ($platform)';
  }

  @override
  String get privacyPermission => 'Permission';

  @override
  String get privacyPermissionValue => 'Read and write';

  @override
  String get privacyReading => 'Reading';

  @override
  String get privacyReadingValue =>
      'All records the first time, then the last 30 days on each launch';

  @override
  String get privacyLeavesDevice => 'Leaves the device';

  @override
  String get privacyNo => 'No';

  @override
  String get privacyToAi => 'Given to AI';

  @override
  String get privacyAds => 'Used for ads';

  @override
  String get privacyDisconnect => 'After disconnecting';

  @override
  String get privacyDisconnectValue => 'Records already read are kept';

  @override
  String get privacyKinds => 'Kinds read';

  @override
  String get privacyDefault => 'Default';

  @override
  String get privacyNotUsed => 'Not used';

  @override
  String get privacyAppleIntelligence => 'Runs on the device';

  @override
  String get privacyCloudReceives => 'Cloud AI receives';

  @override
  String get privacyCloudReceivesValue =>
      'Typed text, text read from photos, food photos to estimate';

  @override
  String get privacyFoodPhotos => 'Food photos';

  @override
  String get privacyFoodPhotosValue =>
      'Location and camera data removed first; not kept';

  @override
  String get privacyOtherData => 'Other photos, other records, health data';

  @override
  String get privacyNotSent => 'Not sent';

  @override
  String get privacyFirstSend => 'Before first sending text or photos';

  @override
  String privacyFirstSendValue({required String me}) {
    return 'Asks for consent to each; withdraw in $me > AI';
  }

  @override
  String get privacyAiResults => 'AI results';

  @override
  String get privacyAiResultsValue => 'Drafts, logged only once confirmed';

  @override
  String get privacyGoogleFree => 'Google AI Studio free tier';

  @override
  String get privacyGoogleFreeValue =>
      'Content may be used to improve products and reviewed by people';

  @override
  String get privacyKeysSection => 'Keys and export';

  @override
  String get privacyApiKeys => 'API keys';

  @override
  String get privacyApiKeysValue =>
      'System secure storage, never in the database';

  @override
  String get privacyExportFiles => 'Export files';

  @override
  String privacyExportFilesValue({required String me}) {
    return 'Only made by hand in $me > Export';
  }

  @override
  String get privacyExportContents => 'Export contents';

  @override
  String get privacyExportContentsValue => 'No API keys';

  @override
  String get privacyUpload => 'Upload';

  @override
  String get refUse01 => 'Formula for resting metabolism';

  @override
  String get refUse02 =>
      'In healthy adults Mifflin-St Jeor comes closest to measured';

  @override
  String get refUse03 => 'Activity level grades';

  @override
  String get refUse04 =>
      'Protein to maintain or build: 1.6–1.8 g per kg (range 1.4–2.0 g)';

  @override
  String get refUse05 =>
      'Cutting: 0.5–1% of body weight a week, more protein, fat 15–30% of calories';

  @override
  String get refUse06 => 'Protein when cutting: 2.2 g per kg';

  @override
  String get refUse07 =>
      'Cutting defaults to 0.5% a week; slower keeps more lean mass';

  @override
  String get refUse08 =>
      'Gaining uses a small surplus, 0.25% a week by default';

  @override
  String get refUse09 => 'About 7,700 kcal per kg is only a rough start';

  @override
  String get refUse10 => 'Fiber 14 g per 1,000 kcal; fat 20–35% of calories';

  @override
  String get refUse11 => 'Taiwan: adults under 2,400 mg sodium a day';

  @override
  String get refUse12 =>
      'Japan: adults under 7.5 g (men) / 6.5 g (women) salt equivalent a day';

  @override
  String get refUse13 =>
      'Japanese labels: salt equivalent (g) = sodium (mg) × 2.54 ÷ 1,000';

  @override
  String get refUse14 => 'US and Canada: adults under 2,300 mg sodium a day';

  @override
  String get refUse15 => 'EU: adults 2.0 g sodium a day, i.e. 5 g salt';

  @override
  String get refUse16 =>
      'EU labels: carbohydrate excludes fiber; salt = sodium × 2.5';

  @override
  String get refUse17 =>
      'Australia and New Zealand: adults 2,000 mg sodium a day';

  @override
  String get refUse18 =>
      'Australian and NZ labels: carbohydrate excludes fiber; energy in kJ';

  @override
  String get refUse19 => 'Korea: adults under 2,300 mg sodium a day';

  @override
  String get refUse20 => 'China: adults under 5 g salt a day';

  @override
  String get refUse21 => 'Remaining caffeine from a 5-hour half-life';

  @override
  String get refUse22 =>
      'Half-life varies by person; the figure is not a measurement';

  @override
  String get refUse23 =>
      '100 mg 4 h before bed showed no effect; the reference is not a safe threshold';

  @override
  String get refUse46 =>
      '35 mg reference worked out from 107 mg 8.8 h and 217.5 mg 13.2 h before bed';

  @override
  String get refUse24 => 'Without a goal, 8 hours a night (consensus is 7+)';

  @override
  String get refUse25 => 'The effect of short sleep builds over 14 days';

  @override
  String get refUse26 => 'Extra sleep does not cancel short sleep one for one';

  @override
  String get refUse27 => 'Recovery has no agreed rate, so no decay';

  @override
  String get refUse28 => 'Formula for estimated max (1RM)';

  @override
  String get refUse29 => 'No estimate above 10 reps; most accurate at 5';

  @override
  String get refUse30 => 'Estimates at 7–10 reps remain accurate';

  @override
  String get refUse31 =>
      'More reps widen differences between people and exercises';

  @override
  String get refUse42 => 'Training load expressed as %1RM';

  @override
  String get refUse43 => 'Updated guidance using %1RM for load';

  @override
  String get refUse44 => 'Load and proximity to failure are distinct variables';

  @override
  String get refUse45 =>
      'Repetitions in reserve (RIR) measure proximity to failure';

  @override
  String get refUse32 => 'Dose response for 10+ weekly sets per muscle';

  @override
  String get refUse33 => 'Gains level off above 1.6 g protein per kg';

  @override
  String get refUse34 => 'Max heart rate estimated as 208 − 0.7 × age';

  @override
  String get refUse35 =>
      'With a resting heart rate, zones use heart-rate reserve';

  @override
  String get refUse36 => 'BMI grades: underweight, healthy, overweight, obese';

  @override
  String get refUse37 => 'Definition of fat-free mass index (FFMI)';

  @override
  String get refUse38 =>
      'Recomposition keeps the deficit small: at about 500 kcal a day lean mass stops increasing';

  @override
  String get refUse39 =>
      'Recomposition works in a small deficit or at maintenance, with high protein';

  @override
  String get refUse40 => 'Recomposition at maintenance: protein 2.0 g per kg';

  @override
  String get refUse41 =>
      'Recomposition protein uses at most the weight at BMI 30';

  @override
  String get refSectionTargets => 'Daily calorie and nutrient targets';

  @override
  String get refSectionLabels => 'Nutrition labels';

  @override
  String get refSectionCaffeine => 'Caffeine';

  @override
  String get refSectionSleepDebt => 'Sleep debt';

  @override
  String get refSectionTraining => 'Training and trends';

  @override
  String get refSectionHeartZones => 'Exercise heart-rate zones';

  @override
  String get refSectionBody => 'Body';

  @override
  String get openLink => 'Open link';

  @override
  String get openAction => 'Open';

  @override
  String get cannotOpenLink => 'Can\'t open link';

  @override
  String apiKeyTitle({required String provider}) {
    return '$provider API key';
  }

  @override
  String get apiKeyHint => 'Paste the key; leave empty to delete';

  @override
  String get apiEndpoint => 'API address';

  @override
  String get azureResourceUrl => 'Azure AI Foundry resource URL';

  @override
  String get modelLabel => 'Model';

  @override
  String get modelListUnavailable => 'Couldn\'t load models; type a name.';

  @override
  String get typeOwn => 'Type a name';

  @override
  String get deploymentName => 'Deployment name';

  @override
  String get modelHint => 'E.g. gemini-3.8-flash';

  @override
  String get signInInBrowser => 'Sign in in the browser';

  @override
  String signInInstructions({required String uri, required String code}) {
    return 'Go to $uri, enter code $code and sign in with a work or school account.';
  }

  @override
  String get copyCode => 'Copy code';

  @override
  String get okAction => 'OK';

  @override
  String get signedInCopilot => 'Signed in to Microsoft 365 Copilot';

  @override
  String get clientId => 'Client ID';

  @override
  String get clientIdHint =>
      'Application (client) ID of the Entra app registration';

  @override
  String get tenant => 'Tenant';

  @override
  String get tenantHint => 'Empty means organizations';

  @override
  String get revokeConsentTitle => 'Withdraw consent?';

  @override
  String get revokeConsentMessage =>
      'You\'ll be asked again before cloud AI is next used.';

  @override
  String get revokeConsent => 'Withdraw consent';

  @override
  String get serviceSection => 'Service';

  @override
  String get signedIn => 'Signed in';

  @override
  String get signIn => 'Sign in';

  @override
  String get waitingForBrowser => 'Waiting for browser sign-in…';

  @override
  String get signInAgain => 'Sign in again';

  @override
  String get apiKey => 'API key';

  @override
  String get isSet => 'Set';

  @override
  String get loadingModels => 'Loading models…';

  @override
  String get notChosen => 'Not chosen';

  @override
  String get consentTextAndPhotos => 'Consented to send text and photos';

  @override
  String get consentText => 'Consented to send text';

  @override
  String get consentPhotos => 'Consented to send photos';

  @override
  String get checkingEllipsis => 'Checking…';

  @override
  String get appleNotEligible =>
      'This device doesn\'t support Apple Intelligence';

  @override
  String get appleNotEnabled =>
      'Turn on in Settings > Apple Intelligence & Siri';

  @override
  String get appleModelNotReady => 'Model downloading';

  @override
  String get appleUnavailable =>
      'Needs iOS 26 or later with Apple Intelligence';

  @override
  String get azurePortal => 'Azure portal';

  @override
  String get copilotWarning =>
      'Beta API, not for production. Needs a work or school account, a Microsoft 365 Copilot license and an Entra app registration.';

  @override
  String get googleFreeWarning =>
      'On the free tier Google may use content to improve products and have people review it. Use a key with billing enabled.';

  @override
  String get cloudAi => 'cloud AI';

  @override
  String sendToProvider({required String provider}) {
    return 'Send to $provider?';
  }

  @override
  String cloudConsentMessage({required String me}) {
    return 'Only typed text or text read from photos is sent, never photos or other records. Withdraw in $me > AI.';
  }

  @override
  String get agreeAndSend => 'Agree and send';

  @override
  String sendPhotoToProvider({required String provider}) {
    return 'Send the food photo to $provider?';
  }

  @override
  String photoConsentMessage({required String me}) {
    return 'Only this photo and your note are sent, with location and camera data removed first; the photo isn\'t kept. Withdraw in $me > AI.';
  }

  @override
  String aiFailureUnavailable({required String me}) {
    return 'AI isn\'t set up; set it in $me > AI.';
  }

  @override
  String get aiFailureNeedsConsent => 'Sending text wasn\'t agreed to.';

  @override
  String aiFailureAuthentication({required String me}) {
    return 'Invalid key or no permission; set it again in $me > AI.';
  }

  @override
  String get aiFailureRateLimited =>
      'Too many requests or quota used up; try again later.';

  @override
  String get aiFailureNetwork => 'No connection; try again later.';

  @override
  String get aiFailureProvider =>
      'The AI service had a problem; try again later.';

  @override
  String get aiFailureUnreadable =>
      'Couldn\'t read the AI\'s reply; try again.';

  @override
  String get aiFailureNeedsPhotoConsent => 'Sending photos wasn\'t agreed to.';

  @override
  String aiFailurePhotoUnsupported({required String me}) {
    return 'The current AI can\'t read photos; choose another in $me > AI.';
  }

  @override
  String get aiFailureNoFood => 'No food or drink in the photo; try another.';

  @override
  String get aiFailurePhotoFormat =>
      'Can\'t read this photo\'s format; try another.';

  @override
  String get prior4Weeks => 'Prior 4 weeks';

  @override
  String againstBaseline({required String baseline}) {
    return 'vs $baseline';
  }

  @override
  String againstRecentBaseline({
    required String recent,
    required String baseline,
  }) {
    return '$recent vs $baseline';
  }

  @override
  String changeMore({required String against, required String amount}) {
    return '$against: $amount more';
  }

  @override
  String changeLess({required String against, required String amount}) {
    return '$against: $amount less';
  }

  @override
  String sleepLoadMore({required String percent}) {
    return 'Workouts after longer sleep moved $percent more load on average.';
  }

  @override
  String sleepLoadLess({required String percent}) {
    return 'Workouts after longer sleep moved $percent less load on average.';
  }

  @override
  String workoutsCount({required int count}) {
    return '$count workouts';
  }

  @override
  String sleepSplitAt({required String time}) {
    return 'Longer and shorter nights split at $time';
  }

  @override
  String get againstSameWorkout => 'Against the same workout\'s average';

  @override
  String weightChange4Weeks({required String change}) {
    return '4 weeks $change kg';
  }

  @override
  String baselineTimes({required String baseline, required String count}) {
    return '$baseline $count×';
  }

  @override
  String completeDays({required int complete, required int tracked}) {
    return '$complete/$tracked complete days';
  }

  @override
  String perDaySteps({required String steps}) {
    return '$steps steps a day';
  }

  @override
  String get weightSteady => 'Weight held about steady over this period.';

  @override
  String weightFalling({required String kg}) {
    return 'Weight is falling by about $kg kg a week.';
  }

  @override
  String weightRising({required String kg}) {
    return 'Weight is rising by about $kg kg a week.';
  }

  @override
  String basedOnWeights({required int count}) {
    return 'From $count weigh-ins';
  }

  @override
  String trainingGoalMet({required int count, required int goal}) {
    return 'Workout $count this week: the goal of $goal a week is met.';
  }

  @override
  String trainingGoalShort({
    required int count,
    required int goal,
    required int left,
  }) {
    return '$count workouts this week; $left to go for $goal a week.';
  }

  @override
  String get basedOnThisWeek => 'From this week\'s workouts';

  @override
  String weeklyGoalTimes({required int goal}) {
    return 'Goal $goal a week';
  }

  @override
  String volumeDropMaxHolding({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise weekly sets fell from $first to $last; the estimated max held.';
  }

  @override
  String volumeDropMaxFalling({
    required String exercise,
    required int first,
    required int last,
  }) {
    return '$exercise weekly sets fell from $first to $last; the estimated max fell too.';
  }

  @override
  String basedOnWorkouts({required int count}) {
    return 'From $count workouts';
  }

  @override
  String get excludesWarmups => 'Warm-ups excluded';

  @override
  String get dataComplete => 'Data complete';

  @override
  String dataIncomplete({required int points, required int days}) {
    return 'Data incomplete: $points / $days days logged';
  }

  @override
  String lastWeeksCount({required int count}) {
    return 'Last $count weeks';
  }

  @override
  String lastDaysCount({required int count}) {
    return 'Last $count days';
  }

  @override
  String progressionDeloadReason({required int count, required int reps}) {
    return 'Missed $reps reps $count times running; step back and complete the reps first.';
  }

  @override
  String progressionMissedReps({required String sets, required int reps}) {
    return 'Last time $sets, short of $reps reps; keep the weight.';
  }

  @override
  String progressionMissedSets({required int done, required int planned}) {
    return 'Only $done sets last time; complete $planned before adding weight.';
  }

  @override
  String get progressionTooHard =>
      'Completed last time, but that workout was rated too hard; keep the weight.';

  @override
  String progressionNearLimit({required String rir}) {
    return 'Completed last time, but the last set was near the limit (RIR $rir); keep the weight.';
  }

  @override
  String progressionIncreaseReason({
    required String done,
    required String planned,
    required String reserve,
    required String added,
  }) {
    return 'Last time $done completed $planned$reserve; add $added kg.';
  }

  @override
  String progressionReserve({required String rir}) {
    return ', $rir reps left in the last set';
  }

  @override
  String atLeastValue({required String value}) {
    return 'At least $value';
  }

  @override
  String get appleHealth => 'Apple Health';

  @override
  String get healthConnectName => 'Health Connect';

  @override
  String get healthDataGeneric => 'Health data';

  @override
  String get strongWorkoutName => 'Strong workout';

  @override
  String get afterMerge => 'After';

  @override
  String get splitAction => 'Split';

  @override
  String get aiDraftAction => 'AI draft';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get privacyWebSearch => 'Web search';

  @override
  String get privacyWebSearchValue =>
      'Anthropic and Google AI Studio look up published nutrition figures from what is sent';
}
