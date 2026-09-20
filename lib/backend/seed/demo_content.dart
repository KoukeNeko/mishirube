import '../../domain/domain.dart';

abstract final class DemoExercises {
  static const backSquat = ExerciseDefinition(
    id: 'back-squat',
    name: '槓鈴深蹲',
    aliases: ['深蹲', 'Back Squat', 'Squat'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
    secondaryMuscles: [MuscleGroup.spinalErectors, MuscleGroup.core],
    pattern: MovementPattern.squat,
    isFavorite: true,
    cues: ['站距與肩同寬，腳尖略外開。', '下蹲時膝蓋跟著腳尖方向走。', '維持軀幹張力，不要讓下背先鬆掉。'],
  );

  static const frontSquat = ExerciseDefinition(
    id: 'front-squat',
    name: '前蹲',
    aliases: ['Front Squat'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.quads],
    pattern: MovementPattern.squat,
  );

  static const hackSquat = ExerciseDefinition(
    id: 'hack-squat',
    name: '哈克深蹲',
    aliases: ['Hack Squat'],
    equipment: Equipment.machine,
    primaryMuscles: [MuscleGroup.quads],
    pattern: MovementPattern.squat,
  );

  static const gobletSquat = ExerciseDefinition(
    id: 'goblet-squat',
    name: '高腳杯深蹲',
    aliases: ['Goblet Squat'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
    pattern: MovementPattern.squat,
    isFavorite: true,
  );

  static const smithSquat = ExerciseDefinition(
    id: 'smith-squat',
    name: '史密斯機深蹲',
    aliases: ['Smith Squat', '史密斯深蹲'],
    equipment: Equipment.smithMachine,
    primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
    pattern: MovementPattern.squat,
    isInHomeGym: false,
  );

  static const romanianDeadlift = ExerciseDefinition(
    id: 'rdl',
    name: '羅馬尼亞硬舉',
    aliases: ['RDL', 'Romanian Deadlift'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.hamstrings, MuscleGroup.glutes],
    pattern: MovementPattern.hinge,
  );

  static const bulgarianSplitSquat = ExerciseDefinition(
    id: 'bulgarian-split-squat',
    name: '保加利亞分腿蹲',
    aliases: ['Bulgarian Split Squat', 'BSS'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
    pattern: MovementPattern.unilateral,
  );

  static const legCurl = ExerciseDefinition(
    id: 'leg-curl',
    name: '腿彎舉',
    aliases: ['Leg Curl'],
    equipment: Equipment.machine,
    primaryMuscles: [MuscleGroup.hamstrings],
    pattern: MovementPattern.isolation,
  );

  static const standingCalfRaise = ExerciseDefinition(
    id: 'standing-calf-raise',
    name: '站姿提踵',
    aliases: ['Calf Raise'],
    equipment: Equipment.machine,
    primaryMuscles: [MuscleGroup.calves],
    pattern: MovementPattern.isolation,
  );

  static const dumbbellBenchPress = ExerciseDefinition(
    id: 'db-bench',
    name: '啞鈴臥推',
    aliases: ['Dumbbell Bench', 'DB Bench'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
  );

  static const importedDumbbellBench = ExerciseDefinition(
    id: 'db-bench-strong',
    name: 'Dumbbell Bench',
    aliases: ['啞鈴臥推'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
    source: ExerciseSource.imported,
  );

  static const customDbBench = ExerciseDefinition(
    id: 'db-bench-custom',
    name: 'DB Bench',
    aliases: ['啞鈴臥推'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
    source: ExerciseSource.custom,
  );

  static const benchPress = ExerciseDefinition(
    id: 'bench-press',
    name: '槓鈴臥推',
    aliases: ['Bench Press'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
  );

  static const barbellRow = ExerciseDefinition(
    id: 'barbell-row',
    name: '槓鈴划船',
    aliases: ['Barbell Row'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.back],
    pattern: MovementPattern.horizontalPull,
  );

  static const overheadPress = ExerciseDefinition(
    id: 'ohp',
    name: '站姿肩推',
    aliases: ['Overhead Press', 'OHP'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.shoulders],
    pattern: MovementPattern.verticalPush,
  );

  static const latPulldown = ExerciseDefinition(
    id: 'lat-pulldown',
    name: '滑輪下拉',
    aliases: ['Lat Pulldown'],
    equipment: Equipment.cable,
    primaryMuscles: [MuscleGroup.back],
    pattern: MovementPattern.verticalPull,
  );

  static const hipThrust = ExerciseDefinition(
    id: 'hip-thrust',
    name: '槓鈴臀推',
    aliases: ['Hip Thrust'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.glutes],
    pattern: MovementPattern.hinge,
  );

  static const kettlebellSwing = ExerciseDefinition(
    id: 'kb-swing',
    name: '壺鈴擺盪',
    aliases: ['Kettlebell Swing'],
    equipment: Equipment.kettlebell,
    primaryMuscles: [MuscleGroup.glutes, MuscleGroup.hamstrings],
    pattern: MovementPattern.hinge,
  );

  static const plank = ExerciseDefinition(
    id: 'plank',
    name: '棒式',
    aliases: ['Plank'],
    equipment: Equipment.bodyweight,
    primaryMuscles: [MuscleGroup.core],
    pattern: MovementPattern.isolation,
    trackingType: TrackingType.duration,
  );

  static const catalog = [
    backSquat,
    frontSquat,
    hackSquat,
    gobletSquat,
    smithSquat,
    romanianDeadlift,
    bulgarianSplitSquat,
    legCurl,
    standingCalfRaise,
    dumbbellBenchPress,
    importedDumbbellBench,
    customDbBench,
    benchPress,
    barbellRow,
    overheadPress,
    latPulldown,
    hipThrust,
    kettlebellSwing,
    plank,
  ];
}

abstract final class DemoRoutines {
  static const lowerBodyA = Routine(
    id: 'lower-a',
    name: '下肢 A',
    programName: '12 週肌力計畫',
    estimatedMinutes: 52,
    lastCompletedLabel: '上次 9/16 完成',
    exercises: [
      PlannedExercise(
        exercise: DemoExercises.backSquat,
        sets: 4,
        reps: 5,
        rir: 2,
        targetWeightKg: 100,
        progressionLabel: '達標後 +2.5 kg',
      ),
      PlannedExercise(
        exercise: DemoExercises.romanianDeadlift,
        sets: 3,
        reps: 8,
        rir: 2,
        targetWeightKg: 80,
        progressionLabel: '達標後 +2.5 kg',
      ),
      PlannedExercise(
        exercise: DemoExercises.bulgarianSplitSquat,
        sets: 3,
        reps: 10,
        targetWeightKg: 20,
        progressionLabel: '達標後 +2 次',
        isUnilateral: true,
      ),
      PlannedExercise(
        exercise: DemoExercises.legCurl,
        sets: 3,
        reps: 12,
        targetWeightKg: 45,
        progressionLabel: '達標後 +2.5 kg',
      ),
      PlannedExercise(
        exercise: DemoExercises.standingCalfRaise,
        sets: 3,
        reps: 15,
        targetWeightKg: 60,
        progressionLabel: '維持',
      ),
    ],
  );
}

abstract final class DemoNutrition {
  static const breakfast = MealEvent(
    id: 'breakfast',
    name: '早餐',
    timeLabel: '08:10',
    kcal: 560,
    qualityTag: '已確認',
    proteinGrams: 28,
    carbGrams: 62,
    fatGrams: 18,
    dishes: [
      DishEntry(name: '無糖豆漿', quantityLabel: '450 ml', subtitle: '包裝飲品 · 條碼'),
      DishEntry(name: '蛋餅', quantityLabel: '1 份', subtitle: '自訂食物'),
    ],
  );

  static const sandwichComponents = [
    FoodComponent(name: '全麥吐司 2 片', amountLabel: '~60 g', source: 'TFDA'),
    FoodComponent(name: '照燒雞腿肉', amountLabel: '~85 – 110 g', source: 'TFDA'),
    FoodComponent(name: '荷包蛋', amountLabel: '1 顆', source: 'USDA'),
    FoodComponent(name: '生菜', amountLabel: '~20 g', source: 'USDA'),
    FoodComponent(name: '美乃滋', amountLabel: '~8 – 15 g', source: '品牌標籤'),
  ];

  static const sandwich = DishEntry(
    name: '雞肉照燒蛋全麥三明治',
    quantityLabel: '1 份',
    subtitle: '一道料理 · 5 項成分',
    components: [
      FoodComponent(name: '全麥吐司 2 片', amountLabel: '~60 g', source: 'TFDA'),
      FoodComponent(name: '照燒雞腿肉', amountLabel: '~95 g', source: 'TFDA'),
      FoodComponent(name: '荷包蛋', amountLabel: '1 顆', source: 'USDA'),
      FoodComponent(name: '生菜', amountLabel: '~20 g', source: 'USDA'),
      FoodComponent(name: '美乃滋', amountLabel: '~12 g', source: '品牌標籤'),
    ],
  );

  static const lunch = MealEvent(
    id: 'lunch',
    name: '午餐',
    timeLabel: '12:35',
    kcal: 620,
    qualityTag: '份量為估計',
    proteinGrams: 36,
    carbGrams: 68,
    fatGrams: 21,
    dishes: [
      sandwich,
      DishEntry(name: '香蕉', quantityLabel: '1 根', subtitle: 'TFDA'),
      DishEntry(name: '紅茶', quantityLabel: '1 杯', subtitle: '無糖'),
    ],
  );

  static const recentFoods = [
    ('雞肉照燒蛋全麥三明治', '昨天 12:40', '~480'),
    ('牛肉麵（大碗）', '9/17 19:20', '~780'),
    ('無糖豆漿 450 ml', '9/17 08:05', '140'),
  ];
}
