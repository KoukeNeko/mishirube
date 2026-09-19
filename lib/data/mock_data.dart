import 'models.dart';

/// Fixed "now" used by the mock so every screen matches the design (2026/9/19).
final mockToday = DateTime(2026, 9, 19);

/// First month the log can be browsed back to.
final mockEarliestMonth = DateTime(2025);

abstract final class MockExercises {
  static const backSquat = ExerciseDefinition(
    id: 'back-squat',
    name: '槓鈴深蹲',
    aliases: ['深蹲', 'Back Squat', 'Squat'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
    secondaryMuscles: [MuscleGroup.spinalErectors, MuscleGroup.core],
    pattern: MovementPattern.squat,
    isFavorite: true,
    lastPerformance: '上次 80 kg × 5',
    lastUsedDaysAgo: 3,
    recordCount: 24,
    cues: ['站距與肩同寬，腳尖略外開。', '下蹲時膝蓋跟著腳尖方向走。', '維持軀幹張力，不要讓下背先鬆掉。'],
  );

  static const frontSquat = ExerciseDefinition(
    id: 'front-squat',
    name: '前蹲',
    aliases: ['Front Squat'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.quads],
    pattern: MovementPattern.squat,
    lastPerformance: '上次 60 kg × 6',
    lastUsedDaysAgo: 14,
    recordCount: 9,
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
    lastPerformance: '上次 24 kg × 12',
    lastUsedDaysAgo: 6,
    recordCount: 5,
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
    lastPerformance: '上次 80 kg × 8',
    lastUsedDaysAgo: 3,
    recordCount: 18,
  );

  static const bulgarianSplitSquat = ExerciseDefinition(
    id: 'bulgarian-split-squat',
    name: '保加利亞分腿蹲',
    aliases: ['Bulgarian Split Squat', 'BSS'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.quads, MuscleGroup.glutes],
    pattern: MovementPattern.unilateral,
    lastPerformance: '上次 20 kg × 10',
    lastUsedDaysAgo: 3,
    recordCount: 12,
  );

  static const legCurl = ExerciseDefinition(
    id: 'leg-curl',
    name: '腿彎舉',
    aliases: ['Leg Curl'],
    equipment: Equipment.machine,
    primaryMuscles: [MuscleGroup.hamstrings],
    pattern: MovementPattern.isolation,
    lastPerformance: '上次 45 kg × 12',
    lastUsedDaysAgo: 3,
    recordCount: 15,
  );

  static const standingCalfRaise = ExerciseDefinition(
    id: 'standing-calf-raise',
    name: '站姿提踵',
    aliases: ['Calf Raise'],
    equipment: Equipment.machine,
    primaryMuscles: [MuscleGroup.calves],
    pattern: MovementPattern.isolation,
    lastPerformance: '上次 60 kg × 15',
    lastUsedDaysAgo: 3,
    recordCount: 15,
  );

  static const dumbbellBenchPress = ExerciseDefinition(
    id: 'db-bench',
    name: '啞鈴臥推',
    aliases: ['Dumbbell Bench', 'DB Bench'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
    recordCount: 24,
  );

  static const importedDumbbellBench = ExerciseDefinition(
    id: 'db-bench-strong',
    name: 'Dumbbell Bench',
    aliases: ['啞鈴臥推'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
    source: ExerciseSource.imported,
    recordCount: 8,
  );

  static const customDbBench = ExerciseDefinition(
    id: 'db-bench-custom',
    name: 'DB Bench',
    aliases: ['啞鈴臥推'],
    equipment: Equipment.dumbbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
    source: ExerciseSource.custom,
    recordCount: 3,
  );

  static const benchPress = ExerciseDefinition(
    id: 'bench-press',
    name: '槓鈴臥推',
    aliases: ['Bench Press'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.chest],
    pattern: MovementPattern.horizontalPush,
    recordCount: 30,
  );

  static const barbellRow = ExerciseDefinition(
    id: 'barbell-row',
    name: '槓鈴划船',
    aliases: ['Barbell Row'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.back],
    pattern: MovementPattern.horizontalPull,
    recordCount: 20,
  );

  static const overheadPress = ExerciseDefinition(
    id: 'ohp',
    name: '站姿肩推',
    aliases: ['Overhead Press', 'OHP'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.shoulders],
    pattern: MovementPattern.verticalPush,
    recordCount: 16,
  );

  static const latPulldown = ExerciseDefinition(
    id: 'lat-pulldown',
    name: '滑輪下拉',
    aliases: ['Lat Pulldown'],
    equipment: Equipment.cable,
    primaryMuscles: [MuscleGroup.back],
    pattern: MovementPattern.verticalPull,
    recordCount: 14,
  );

  static const hipThrust = ExerciseDefinition(
    id: 'hip-thrust',
    name: '槓鈴臀推',
    aliases: ['Hip Thrust'],
    equipment: Equipment.barbell,
    primaryMuscles: [MuscleGroup.glutes],
    pattern: MovementPattern.hinge,
    recordCount: 6,
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
    recordCount: 10,
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

  static const recentHistory = [
    ('9 / 16', '80 kg × 5 · RIR 2'),
    ('9 / 12', '77.5 kg × 5 · RIR 2'),
    ('9 / 9', '77.5 kg × 5 · RIR 3'),
  ];
}

abstract final class MockRoutines {
  static const lowerBodyA = Routine(
    id: 'lower-a',
    name: '下肢 A',
    programName: '12 週肌力計畫',
    estimatedMinutes: 52,
    lastCompletedLabel: '上次 9/16 完成',
    exercises: [
      PlannedExercise(
        exercise: MockExercises.backSquat,
        sets: 4,
        reps: 5,
        rir: 2,
        targetWeightKg: 100,
        progressionLabel: '達標後 +2.5 kg',
      ),
      PlannedExercise(
        exercise: MockExercises.romanianDeadlift,
        sets: 3,
        reps: 8,
        rir: 2,
        targetWeightKg: 80,
        progressionLabel: '達標後 +2.5 kg',
      ),
      PlannedExercise(
        exercise: MockExercises.bulgarianSplitSquat,
        sets: 3,
        reps: 10,
        targetWeightKg: 20,
        progressionLabel: '達標後 +2 次',
        isUnilateral: true,
      ),
      PlannedExercise(
        exercise: MockExercises.legCurl,
        sets: 3,
        reps: 12,
        targetWeightKg: 45,
        progressionLabel: '達標後 +2.5 kg',
      ),
      PlannedExercise(
        exercise: MockExercises.standingCalfRaise,
        sets: 3,
        reps: 15,
        targetWeightKg: 60,
        progressionLabel: '維持',
      ),
    ],
  );
}

abstract final class MockPreviousPerformance {
  static const _byExerciseId = {
    'back-squat': (95.0, 5),
    'rdl': (77.5, 8),
    'bulgarian-split-squat': (20.0, 8),
    'leg-curl': (42.5, 12),
    'standing-calf-raise': (60.0, 12),
  };

  static (double, int) of(PlannedExercise planned) =>
      _byExerciseId[planned.exercise.id] ??
      (planned.targetWeightKg, planned.reps);
}

abstract final class MockNutrition {
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

abstract final class MockTimeline {
  static const days = [
    TimelineDay(
      label: '今天 · 9 月 19 日（週六）',
      entries: [
        TimelineEntry(
          timeLabel: '20:41',
          category: RecordCategory.training,
          title: '下肢 A',
          detail: '16 組 · 58 分 · 槓鈴深蹲 100 kg × 5 為新紀錄',
        ),
        TimelineEntry(
          timeLabel: '19:05',
          category: RecordCategory.nutrition,
          title: '晚餐',
          detail: '牛肉麵、燙青菜',
          tags: ['~780 kcal', '已確認'],
        ),
        TimelineEntry(
          timeLabel: '12:35',
          category: RecordCategory.nutrition,
          title: '午餐',
          detail: '雞肉照燒蛋全麥三明治、香蕉、紅茶',
          tags: ['~620 kcal', '份量為估計'],
        ),
        TimelineEntry(
          timeLabel: '07:12',
          category: RecordCategory.body,
          title: '體重 72.4 kg',
          detail: '早晨空腹 · 手動輸入',
        ),
      ],
    ),
    TimelineDay(
      label: '9 月 18 日（週五）',
      warning: '飲食紀錄不完整',
      entries: [
        TimelineEntry(
          timeLabel: '22:10',
          category: RecordCategory.wellness,
          title: '精力 3 / 5',
          detail: '備註：久坐一整天，下背有點緊',
        ),
        TimelineEntry(
          timeLabel: '12:20',
          category: RecordCategory.nutrition,
          title: '午餐',
          detail: '雞肉照燒蛋全麥三明治',
          tags: ['~480 kcal'],
        ),
        TimelineEntry(
          timeLabel: '07:05',
          category: RecordCategory.body,
          title: '體重 72.6 kg',
          detail: '早晨空腹 · 手動輸入',
        ),
      ],
    ),
  ];

  /// The only month with mock records; [days] and [septemberDots] are in it.
  static final recordMonth = DateTime(2026, 9);

  /// Calendar dots for the month starting at [month].
  static Map<int, List<RecordCategory>> dotsIn(DateTime month) =>
      month == recordMonth ? septemberDots : const {};

  /// Categories recorded on each day of September 2026 (calendar dots).
  static const septemberDots = <int, List<RecordCategory>>{
    1: [RecordCategory.nutrition],
    2: [RecordCategory.training, RecordCategory.nutrition],
    3: [RecordCategory.nutrition, RecordCategory.body],
    4: [RecordCategory.nutrition],
    5: [RecordCategory.training, RecordCategory.nutrition, RecordCategory.body],
    6: [RecordCategory.nutrition],
    8: [RecordCategory.nutrition, RecordCategory.body],
    9: [RecordCategory.training, RecordCategory.nutrition],
    10: [RecordCategory.nutrition],
    11: [
      RecordCategory.training,
      RecordCategory.nutrition,
      RecordCategory.body,
    ],
    12: [RecordCategory.training, RecordCategory.nutrition],
    13: [RecordCategory.nutrition],
    15: [
      RecordCategory.training,
      RecordCategory.nutrition,
      RecordCategory.body,
    ],
    16: [RecordCategory.training, RecordCategory.nutrition],
    17: [RecordCategory.nutrition],
    18: [RecordCategory.nutrition],
    19: [
      RecordCategory.training,
      RecordCategory.nutrition,
      RecordCategory.body,
    ],
  };
}

abstract final class MockInsights {
  static const squatVolume = Insight(
    statement: '深蹲的每週組數在近 4 週從 12 組掉到 8 組，估計最大重量沒有跟著掉。',
    evidence: ['依據 24 筆訓練紀錄', '資料完整', '近 4 週'],
  );

  static const weeklyGoalReached = Insight(
    statement: '這是本週第 3 次訓練，達成你設定的每週 3 次。',
    evidence: ['依據 本週訓練紀錄', '9/15 – 9/19'],
  );

  static const weightTrend = Insight(
    statement: '體重以每週約 0.3 公斤的速度下降，速度穩定，沒有停滯。',
    evidence: ['依據 26 天體重紀錄', '資料完整', '近 4 週'],
  );

  static const squatVolumeShort = Insight(
    statement: '深蹲的每週組數掉了三分之一，估計最大重量還沒有跟著掉。',
    evidence: ['依據 12 次訓練紀錄', '資料完整', '近 4 週'],
  );

  static const weeklySquatSets = [
    ('8/24', 12),
    ('8/31', 11),
    ('9/7', 9),
    ('9/14', 8),
  ];

  static const weightSeries = [
    73.6,
    73.5,
    73.5,
    73.3,
    73.2,
    73.2,
    73.0,
    72.9,
    72.8,
    72.8,
    72.6,
    72.4,
  ];

  static const weeklyWorkouts = [('W1', 3), ('W2', 3), ('W3', 2), ('本週', 3)];
}

abstract final class MockSubstitutions {
  static const _maxCandidates = 3;

  static const _curated = {
    'back-squat': [
      SubstitutionOption(
        exercise: MockExercises.gobletSquat,
        reasons: ['同為深蹲模式', '啞鈴可用', '保留 5 × 5'],
      ),
      SubstitutionOption(
        exercise: MockExercises.hackSquat,
        reasons: ['同為深蹲模式', '穩定性需求較低'],
      ),
      SubstitutionOption(
        exercise: MockExercises.bulgarianSplitSquat,
        reasons: ['單側，次數請重新設定'],
      ),
    ],
  };

  static List<SubstitutionOption> forExercise(ExerciseDefinition exercise) {
    final curated = _curated[exercise.id];
    if (curated != null) return curated;
    return MockExercises.catalog
        .where(
          (candidate) =>
              candidate.id != exercise.id &&
              candidate.pattern == exercise.pattern,
        )
        .take(_maxCandidates)
        .map(
          (candidate) => SubstitutionOption(
            exercise: candidate,
            reasons: ['同為${exercise.pattern.label}模式'],
          ),
        )
        .toList();
  }
}
