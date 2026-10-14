import '../../domain/domain.dart';

/// What a slot in a workout is for. It decides the sets and reps the
/// slot gets, and what is dropped first when a workout runs long.
enum SlotRole {
  /// The heavy multi-joint lift the workout is built around.
  main,

  /// A second multi-joint lift, or a variation of the main one.
  secondary,

  /// Single-joint or smaller work for a muscle the lifts leave short.
  accessory,

  /// Trunk work, kept to the end.
  core,
}

/// One exercise to find: the movement it should be, who it is for, and
/// the library exercises that suit it, best first.
///
/// The pools hold ids of the built-in library, which the generator takes
/// from before looking anywhere else. A pool is a list of what an
/// experienced coach would reach for first, then what a lifter with less
/// equipment can do instead, so one list serves a gym, a home with
/// dumbbells and a room with nothing in it.
class Slot {
  const Slot(
    this.role,
    this.pattern,
    this.muscles,
    this.pool, {
    this.beginnerPool,
  });

  final SlotRole role;
  final MovementPattern pattern;

  /// The muscles a library exercise has to train as a primary one to be
  /// found by pattern when the pool has nothing that fits.
  final List<MuscleGroup> muscles;
  final List<String> pool;

  /// A different order for someone new to lifting, who is better served by
  /// a machine or a dumbbell than by a barbell. Null keeps [pool].
  final List<String>? beginnerPool;
}

const _squat = Slot(
  SlotRole.main,
  MovementPattern.squat,
  [MuscleGroup.quads],
  [
    'back-squat',
    'goblet-squat',
    'leg-press',
    'hack-squat',
    'smith-squat',
    'front-squat',
    'bodyweight-squat',
  ],
  beginnerPool: [
    'goblet-squat',
    'leg-press',
    'smith-squat',
    'back-squat',
    'bodyweight-squat',
  ],
);

const _hinge = Slot(
  SlotRole.main,
  MovementPattern.hinge,
  [MuscleGroup.hamstrings, MuscleGroup.glutes],
  [
    'deadlift',
    'dumbbell-romanian-deadlift',
    'hip-thrust',
    'trap-bar-deadlift',
    'kb-swing',
    'glute-bridge',
    'back-extension',
  ],
  beginnerPool: [
    'dumbbell-romanian-deadlift',
    'hip-thrust',
    'glute-bridge',
    'trap-bar-deadlift',
    'back-extension',
  ],
);

const _lunge = Slot(
  SlotRole.secondary,
  MovementPattern.lunge,
  [MuscleGroup.quads, MuscleGroup.glutes],
  [
    'bulgarian-split-squat',
    'reverse-lunge',
    'walking-lunge',
    'step-up',
    'split-squat',
    'bodyweight-reverse-lunge',
    'bodyweight-step-up',
  ],
);

const _horizontalPush = Slot(
  SlotRole.main,
  MovementPattern.horizontalPush,
  [MuscleGroup.chest],
  [
    'bench-press',
    'incline-dumbbell-press',
    'machine-chest-press',
    'push-up',
    'incline-push-up',
    'knee-push-up',
  ],
  beginnerPool: [
    'machine-chest-press',
    'incline-dumbbell-press',
    'bench-press',
    'incline-push-up',
    'push-up',
    'knee-push-up',
  ],
);

const _verticalPush = Slot(
  SlotRole.secondary,
  MovementPattern.verticalPush,
  [MuscleGroup.frontDelts, MuscleGroup.sideDelts],
  [
    'ohp',
    'seated-dumbbell-press',
    'standing-dumbbell-press',
    'machine-shoulder-press',
    'landmine-press',
    'pike-push-up',
  ],
  beginnerPool: [
    'machine-shoulder-press',
    'seated-dumbbell-press',
    'ohp',
    'landmine-press',
    'pike-push-up',
  ],
);

const _horizontalPull = Slot(
  SlotRole.main,
  MovementPattern.horizontalPull,
  [MuscleGroup.lats, MuscleGroup.upperBack],
  [
    'barbell-row',
    'dumbbell-bent-over-row',
    'chest-supported-row',
    'seated-row',
    'one-arm-dumbbell-row',
    'machine-row',
    'inverted-row',
    'banded-row',
  ],
  beginnerPool: [
    'seated-row',
    'chest-supported-row',
    'machine-row',
    'one-arm-dumbbell-row',
    'dumbbell-bent-over-row',
    'inverted-row',
    'banded-row',
  ],
);

const _verticalPull = Slot(
  SlotRole.secondary,
  MovementPattern.verticalPull,
  [MuscleGroup.lats],
  [
    'lat-pulldown',
    'pull-up',
    'chin-up',
    'assisted-pull-up',
    'neutral-grip-pull-up',
    'banded-lat-pulldown',
  ],
  beginnerPool: [
    'lat-pulldown',
    'assisted-pull-up',
    'banded-lat-pulldown',
    'pull-up',
    'chin-up',
  ],
);

const _legCurl = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.hamstrings],
  [
    'lying-leg-curl',
    'seated-leg-curl',
    'stability-ball-hamstring-curl',
    'nordic-hamstring-curl',
  ],
);

const _legExtension = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.quads],
  ['leg-extension', 'bulgarian-split-squat', 'bodyweight-squat'],
);

const _calves = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.calves],
  [
    'standing-calf-raise',
    'seated-calf-raise',
    'dumbbell-calf-raise',
    'calf-raise',
  ],
);

const _chestFly = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.chest],
  ['cable-fly', 'pec-deck', 'dumbbell-fly', 'push-up'],
);

const _sideDelts = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.sideDelts],
  [
    'lateral-raise',
    'cable-lateral-raise',
    'machine-lateral-raise',
    'pike-push-up',
  ],
);

const _rearDelts = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.rearDelts],
  [
    'face-pull',
    'reverse-pec-deck',
    'rear-delt-fly',
    'cable-rear-delt-fly',
    'banded-row',
  ],
);

const _triceps = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.triceps],
  [
    'tricep-pushdown',
    'rope-tricep-pushdown',
    'overhead-tricep-extension',
    'dumbbell-overhead-tricep-extension',
    'skull-crusher',
    'dip',
    'bench-dip',
    'diamond-push-up',
  ],
);

const _biceps = Slot(
  SlotRole.accessory,
  MovementPattern.isolation,
  [MuscleGroup.biceps],
  [
    'bicep-curl',
    'hammer-curl',
    'cable-curl',
    'ez-bar-curl',
    'preacher-curl',
    'incline-dumbbell-curl',
    'chin-up',
  ],
);

const _core = Slot(
  SlotRole.core,
  MovementPattern.core,
  [MuscleGroup.abs],
  [
    'plank',
    'cable-crunch',
    'hanging-leg-raise',
    'dead-bug',
    'ab-wheel',
    'crunch',
  ],
);

/// A day's work as slots, most important first: what is left out when a
/// workout has to be shorter is taken from the end.
enum WorkoutKind {
  fullBody,
  upper,
  lower,
  push,
  pull,
  legs;

  /// The slots of the [index]th workout of this kind in a program. A
  /// second full-body day leads with a different lift from the first, so
  /// a muscle gets its own variations through the week.
  List<Slot> slots(int index) => switch (this) {
    fullBody when index % 3 == 0 => const [
      _squat,
      _horizontalPush,
      _horizontalPull,
      _hinge,
      _verticalPush,
      _core,
    ],
    fullBody when index % 3 == 1 => const [
      _hinge,
      _verticalPush,
      _verticalPull,
      _squat,
      _horizontalPush,
      _core,
    ],
    fullBody => const [
      _squat,
      _verticalPull,
      _horizontalPush,
      _legCurl,
      _horizontalPull,
      _core,
    ],
    upper => const [
      _horizontalPush,
      _horizontalPull,
      _verticalPush,
      _verticalPull,
      _triceps,
      _biceps,
      _sideDelts,
      _rearDelts,
    ],
    lower => const [
      _squat,
      _hinge,
      _lunge,
      _legCurl,
      _calves,
      _core,
      _legExtension,
    ],
    push => const [
      _horizontalPush,
      _verticalPush,
      _chestFly,
      _sideDelts,
      _triceps,
    ],
    pull => const [_verticalPull, _horizontalPull, _rearDelts, _biceps, _core],
    legs => const [_squat, _hinge, _lunge, _legCurl, _calves, _core],
  };
}
