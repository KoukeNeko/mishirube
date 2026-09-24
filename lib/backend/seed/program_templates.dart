import '../../domain/domain.dart';

/// The common splits, to start a program from instead of an empty one.
/// Exercises missing from the catalogue are left out when one is used.
const programTemplates = [
  ProgramTemplate(
    name: '全身訓練',
    workouts: [
      TemplateWorkout('全身 A', [
        ('back-squat', 3, 8),
        ('bench-press', 3, 8),
        ('barbell-row', 3, 8),
        ('leg-curl', 3, 12),
      ]),
      TemplateWorkout('全身 B', [
        ('deadlift', 3, 5),
        ('ohp', 3, 8),
        ('lat-pulldown', 3, 10),
        ('bulgarian-split-squat', 3, 10),
      ]),
      TemplateWorkout('全身 C', [
        ('front-squat', 3, 8),
        ('db-bench', 3, 10),
        ('seated-row', 3, 10),
        ('hip-thrust', 3, 10),
      ]),
    ],
  ),
  ProgramTemplate(
    name: '上下肢分化',
    workouts: [
      TemplateWorkout('上肢 A', [
        ('bench-press', 4, 6),
        ('barbell-row', 4, 8),
        ('ohp', 3, 8),
        ('lat-pulldown', 3, 10),
        ('bicep-curl', 3, 12),
      ]),
      TemplateWorkout('下肢 A', [
        ('back-squat', 4, 6),
        ('rdl', 3, 8),
        ('leg-curl', 3, 12),
        ('standing-calf-raise', 3, 12),
      ]),
      TemplateWorkout('上肢 B', [
        ('db-bench', 3, 10),
        ('pull-up', 3, 8),
        ('lateral-raise', 3, 15),
        ('seated-row', 3, 10),
        ('tricep-pushdown', 3, 12),
      ]),
      TemplateWorkout('下肢 B', [
        ('deadlift', 3, 5),
        ('bulgarian-split-squat', 3, 10),
        ('hip-thrust', 3, 10),
        ('leg-press', 3, 12),
      ]),
    ],
  ),
  ProgramTemplate(
    name: '推／拉／腿',
    workouts: [
      TemplateWorkout('推', [
        ('bench-press', 4, 8),
        ('ohp', 3, 8),
        ('incline-dumbbell-press', 3, 10),
        ('lateral-raise', 3, 15),
        ('tricep-pushdown', 3, 12),
      ]),
      TemplateWorkout('拉', [
        ('pull-up', 4, 8),
        ('barbell-row', 3, 8),
        ('lat-pulldown', 3, 10),
        ('face-pull', 3, 15),
        ('bicep-curl', 3, 12),
      ]),
      TemplateWorkout('腿', [
        ('back-squat', 4, 8),
        ('rdl', 3, 8),
        ('leg-press', 3, 12),
        ('leg-curl', 3, 12),
        ('standing-calf-raise', 3, 15),
      ]),
    ],
  ),
  ProgramTemplate(
    name: '5×5',
    workouts: [
      TemplateWorkout('A', [
        ('back-squat', 5, 5),
        ('bench-press', 5, 5),
        ('barbell-row', 5, 5),
      ]),
      TemplateWorkout('B', [
        ('back-squat', 5, 5),
        ('ohp', 5, 5),
        ('deadlift', 1, 5),
      ]),
    ],
  ),
];
