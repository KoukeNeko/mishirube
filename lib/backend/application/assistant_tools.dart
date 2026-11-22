import 'dart:convert';

import '../../domain/domain.dart';
import '../../l10n/l10n.dart';
import '../engines/program_generator.dart';
import 'catalog_service.dart';
import 'record_tools.dart';
import 'training_service.dart';

/// A program the model drafted from a request; nothing is kept until the
/// user saves it.
class ProgramDraft {
  const ProgramDraft(this.request, this.program);

  final ProgramRequest request;
  final GeneratedProgram program;
}

/// A change the model proposed to one template; nothing is kept until
/// the user accepts it.
class RoutineChangeDraft {
  const RoutineChangeDraft({
    required this.routine,
    required this.removed,
    required this.added,
  });

  /// The template as it was when the change was proposed.
  final Routine routine;

  /// The ids of the exercises taken out.
  final Set<String> removed;
  final List<PlannedExercise> added;
}

/// What the assistant answered: its reply, and the drafts its tools made
/// while it worked on it.
class AssistantReply {
  const AssistantReply({required this.text, this.program, this.routineChange});

  final String text;
  final ProgramDraft? program;
  final RoutineChangeDraft? routineChange;
}

/// How the assistant is told to work (research 100, D3): figures only
/// from the tools, records described rather than advice given, and a
/// change only ever a draft.
// l10n-ignore-start: the model's instructions, never shown.
String assistantInstructions(DateTime today) =>
    '''
你是健身與飲食紀錄 App 裡的助理，回答使用者關於自己紀錄的問題，並在使用者要求時草擬課表。
- 今天是 ${_date(today)}。給工具的日期用 YYYY-MM-DD；回覆裡的日期照使用者語言的寫法（中文寫 11 月 18 日）。單位用符號：重量 kg，營養素 g，熱量 kcal，水 mL，不寫公斤、克。四位數以上加千分位。
- 數字只用工具回答的；不自己估算或換算。工具沒有的，就說沒有紀錄。回覆裡不提工具、JSON 或欄位名稱。
- 只描述紀錄，不給醫療、飲食或訓練建議，不鼓勵，不說教。
- 使用者要新課表時用 draft_program。要改現有課表時，先用 routines 找到它，動作的 id 用 find_exercise 查，再用 propose_routine_change。
- 這兩個工具只產生草稿，畫面上會用卡片列出內容，使用者確認才會儲存。回覆一兩句說明草稿，不重列動作，不說已經儲存。
- 用使用者的語言，簡短回答；畫面只顯示純文字，不用 Markdown 或表格。''';

/// What the assistant is told when it is asked about one finished
/// workout: the workout itself, so the figures come from the app.
String workoutReviewInstructions(Map<String, Object?> facts) => '''
使用者正在看一次做完的訓練，要的是對這次訓練的評語。
- 把這次放在一直以來的紀錄裡看，不只說今天：各動作的 history 是這次之前的每一次（次數、從哪天開始、之前最好的一組、最近幾次），earlier_workouts 是之前做完的訓練。
- 說這次和過去比的變化：重量、次數或總量比之前高或低、追平或超過以前最好的一組、隔了多久沒練、這段時間練得多密。更早的紀錄用 exercise_history 或 workouts 查。
- 只說紀錄裡看得到的，不推測原因，不給下次的建議，不鼓勵，不說教。
- 四到六句。
這次訓練（JSON）：${jsonEncode(facts)}''';
// l10n-ignore-end

String _date(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The record tools, and the three that work on templates: reading them,
/// drafting a program, proposing a change to one.
///
/// One instance serves one reply: the drafts it holds are that reply's.
/// A draft goes no further than [program] and [routineChange]; writing
/// one is the training service's job once the user confirms it.
class AssistantTools {
  AssistantTools(this._records, this._training, this._catalog, this._l10n);

  final RecordTools _records;
  final TrainingService _training;
  final CatalogService _catalog;
  final AppLocalizations _l10n;

  ProgramDraft? program;
  RoutineChangeDraft? routineChange;

  static final List<AiTool> templateTools = [
    AiTool(
      name: 'routines',
      description:
          "The user's saved workout templates, each with its exercises "
          'and their planned sets, reps and weight.',
      parameters: RecordTools.strictObject({}),
    ),
    AiTool(
      name: 'draft_program',
      description:
          'Drafts a weekly program from the app\'s own rules, shown to the '
          'user to save. The sets, reps and loads come from the rules and '
          'the user\'s history; only these choices are yours.',
      parameters: RecordTools.strictObject({
        'goal': {
          'type': 'string',
          'enum': [for (final goal in ProgramGoal.values) goal.name],
        },
        'level': {
          'type': 'string',
          'enum': [for (final level in ProgramLevel.values) level.name],
        },
        'days': {
          'type': 'integer',
          'description':
              'Training days a week, $programMinDays to $programMaxDays.',
        },
        'minutes': {
          'type': 'integer',
          'description':
              'Minutes a workout, one of '
              '${programMinutes.join(', ')}.',
        },
        'place': {
          'type': 'string',
          'description':
              'gym: every machine; dumbbells: dumbbells and bands; '
              'bodyweight: nothing.',
          'enum': [for (final place in ProgramPlace.values) place.name],
        },
      }),
    ),
    AiTool(
      name: 'propose_routine_change',
      description:
          'Proposes taking exercises out of a template and adding others, '
          'shown to the user to accept. Added exercises are planned from '
          "the user's history.",
      parameters: RecordTools.strictObject({
        'routine_id': {'type': 'string'},
        'remove_exercise_ids': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'add_exercise_ids': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      }),
    ),
  ];

  /// Every tool, for a provider with room for them all.
  static List<AiTool> get all => [...RecordTools.tools, ...templateTools];

  /// The few an on-device model with a small context can take: about
  /// templates when the conversation is about one, else the main records.
  static List<AiTool> compact({required bool aboutTemplates}) {
    final names = aboutTemplates
        ? const {
            'routines',
            'find_exercise',
            'draft_program',
            'propose_routine_change',
          }
        : const {
            'workouts',
            'nutrition_days',
            'sleep_days',
            'body_records',
            'draft_program',
          };
    return [
      for (final tool in all)
        if (names.contains(tool.name)) tool,
    ];
  }

  /// What [name] answers for [arguments], as JSON.
  Map<String, Object?> call(String name, Map<String, Object?> arguments) {
    try {
      return switch (name) {
        'routines' => _routines(),
        'draft_program' => _draftProgram(arguments),
        'propose_routine_change' => _proposeChange(arguments),
        _ => _records.call(name, arguments),
      };
    } on ToolArgumentError catch (error) {
      return {'error': error.message};
    }
  }

  Map<String, ExerciseDefinition> get _byId => {
    for (final exercise in _catalog.all()) exercise.id: exercise,
  };

  Map<String, Object?> _routines() => {
    'routines': [
      for (final routine in _training.routines(_byId))
        {
          'id': routine.id,
          'name': routine.name,
          'exercises': [
            for (final planned in routine.exercises) _planned(planned),
          ],
        },
    ],
  };

  Map<String, Object?> _draftProgram(Map<String, Object?> arguments) {
    T choice<T extends Enum>(String key, List<T> values) {
      final value = arguments[key];
      return values.firstWhere(
        (item) => item.name == value,
        orElse: () => throw ToolArgumentError(
          '$key must be one of ${values.map((item) => item.name).join(', ')}',
        ),
      );
    }

    final days = arguments['days'];
    if (days is! int || days < programMinDays || days > programMaxDays) {
      throw ToolArgumentError(
        'days must be $programMinDays to $programMaxDays',
      );
    }
    final minutes = arguments['minutes'];
    if (!programMinutes.contains(minutes)) {
      throw ToolArgumentError(
        'minutes must be one of ${programMinutes.join(', ')}',
      );
    }
    final request = ProgramRequest(
      goal: choice('goal', ProgramGoal.values),
      level: choice('level', ProgramLevel.values),
      days: days,
      minutes: minutes! as int,
      equipment: choice('place', ProgramPlace.values).equipment,
    );
    final built = _training.buildProgram(request, library: _catalog.all());
    program = ProgramDraft(request, built);
    return {
      'shown_to_user': true,
      'workouts': [
        for (final workout in built.workouts)
          {
            'name': built.nameOf(_l10n, workout),
            'minutes': workout.length.inMinutes,
            'exercises': [
              for (final planned in workout.exercises) _planned(planned),
            ],
          },
      ],
      'weekly_sets': {
        for (final (muscle, sets) in built.weeklySets) muscle.name: sets,
      },
    };
  }

  Map<String, Object?> _proposeChange(Map<String, Object?> arguments) {
    final exercises = _byId;
    final id = arguments['routine_id'];
    final routine = id is String ? _training.routine(id, exercises) : null;
    if (routine == null) {
      throw ToolArgumentError('no routine $id; list them with routines');
    }
    List<String> ids(String key) => switch (arguments[key]) {
      final List<Object?> list => [for (final item in list) '$item'],
      _ => throw ToolArgumentError('$key must be a list of ids'),
    };
    final removed = ids('remove_exercise_ids').toSet();
    final inRoutine = {
      for (final planned in routine.exercises) planned.exercise.id,
    };
    for (final exerciseId in removed) {
      if (!inRoutine.contains(exerciseId)) {
        throw ToolArgumentError('$exerciseId is not in ${routine.name}');
      }
    }
    final added = [
      for (final exerciseId in ids('add_exercise_ids'))
        _training.planFor(
          exercises[exerciseId] ??
              (throw ToolArgumentError(
                'no exercise $exerciseId; find it with find_exercise',
              )),
        ),
    ];
    if (removed.isEmpty && added.isEmpty) {
      throw ToolArgumentError('nothing to change');
    }
    routineChange = RoutineChangeDraft(
      routine: routine,
      removed: removed,
      added: added,
    );
    return {
      'shown_to_user': true,
      'removed': [
        for (final planned in routine.exercises)
          if (removed.contains(planned.exercise.id)) planned.exercise.name,
      ],
      'added': [for (final planned in added) _planned(planned)],
    };
  }

  Map<String, Object?> _planned(PlannedExercise planned) => {
    'exercise_id': planned.exercise.id,
    'name': planned.exercise.name,
    'sets': planned.sets,
    if (planned.reps > 0) 'reps': planned.reps,
    if (planned.targetWeightKg > 0) 'weight_kg': planned.targetWeightKg,
    'seconds': ?planned.targetSeconds,
  };
}
