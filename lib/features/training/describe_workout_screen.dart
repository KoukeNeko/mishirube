import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/engines/workout_text.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import '../me/ai_settings_screen.dart';
import 'active_workout_screen.dart';
import 'routine_detail_screen.dart';

/// A workout written out — typed, or pasted from a chat with a language
/// model — read into exercises with their sets, checked, then started or
/// kept as a 課表. Each line is matched to the library; a line that
/// matches nothing, or the wrong thing, is set right by picking.
///
/// Rules read it first, at once and on the device. What they cannot read
/// whole goes to the AI chosen in 「我的 > AI」, when there is one.
class DescribeWorkoutScreen extends StatefulWidget {
  const DescribeWorkoutScreen({super.key});

  @override
  State<DescribeWorkoutScreen> createState() => _DescribeWorkoutScreenState();
}

class _DescribeWorkoutScreenState extends State<DescribeWorkoutScreen> {
  final _text = TextEditingController();

  /// Each line read, with what it was matched to; null before reading.
  List<(WorkoutLine, PlannedExercise?)>? _draft;

  bool _isReading = false;

  /// Whether the AI read [_draft] rather than the rules.
  bool _isByAi = false;

  /// Why the AI could not read it, when the rules' reading is shown
  /// instead.
  AiFailure? _failure;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<PlannedExercise> get _planned => [
    for (final (_, planned)
        in _draft ?? const <(WorkoutLine, PlannedExercise?)>[])
      ?planned,
  ];

  Future<void> _read() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final store = AppStoreScope.read(context);
    final text = _text.text;
    final byRules = store.draftWorkout(text);
    void show(
      List<(WorkoutLine, PlannedExercise?)> draft, {
      bool isByAi = false,
      AiFailure? failure,
    }) => setState(() {
      _draft = draft;
      _isByAi = isByAi;
      _failure = failure;
      _isReading = false;
    });

    if ((byRules.isNotEmpty && byRules.every((entry) => entry.$2 != null)) ||
        store.aiProvider == null) {
      return show(byRules);
    }
    setState(() {
      _isReading = true;
      _failure = null;
    });
    try {
      final byAi = await store.draftWorkoutWithAi(text);
      if (!mounted) return;
      // The AI's reading unless it found fewer exercises than the rules.
      int found(List<(WorkoutLine, PlannedExercise?)> draft) =>
          draft.where((entry) => entry.$2 != null).length;
      found(byAi) >= found(byRules) ? show(byAi, isByAi: true) : show(byRules);
    } on AiException catch (error) {
      if (!mounted) return;
      if (error.failure == AiFailure.needsConsent) {
        setState(() => _isReading = false);
        if (await askCloudConsent(context)) return _read();
        if (mounted) show(byRules);
        return;
      }
      show(byRules, failure: error.failure);
    }
  }

  /// Another exercise for line [index], keeping the figures it gave.
  Future<void> _pick(int index) async {
    final picked = await pushModalPage<List<ExerciseDefinition>>(
      context,
      const ExercisePickerScreen(purpose: PickerPurpose.single),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    final store = AppStoreScope.read(context);
    setState(() {
      final line = _draft![index].$1;
      _draft![index] = (line, store.planLine(line, picked.first));
    });
  }

  void _remove(int index) => setState(() => _draft!.removeAt(index));

  void _start() {
    if (!AppStoreScope.read(context).startPlannedWorkout(_planned)) {
      showToast(context, '運動進行中，先結束運動才能開始訓練', kind: ToastKind.warning);
      return;
    }
    replaceWithPage(context, const ActiveWorkoutScreen());
  }

  void _save() {
    AppStoreScope.read(context).createRoutineOf(_planned);
    replaceWithPage(context, const RoutineDetailScreen());
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final planned = _planned;
    return DetailPage(
      appBar: const PageAppBar(title: '一句話'),
      footer: draft == null
          ? PrimaryButton(
              label: _isReading ? '產生中…' : '產生',
              onPressed: _isReading || _text.text.trim().isEmpty ? null : _read,
            )
          : ButtonPair(
              secondary: SecondaryButton(
                label: '存成課表',
                onPressed: planned.isEmpty ? null : _save,
              ),
              primary: PrimaryButton(
                label: '開始訓練',
                onPressed: planned.isEmpty ? null : _start,
              ),
            ),
      children: [
        if (draft == null)
          Gutter(
            child: AppTextField(
              controller: _text,
              hint: '例如：\n槓鈴深蹲 4×8 60kg\n臥推 3 組 10 下 40 公斤\n引體向上 3x8',
              maxLines: 10,
            ),
          )
        else ...[
          if (_failure case final failure?)
            Gutter(
              child: InfoBanner(
                tone: CardTone.warning,
                message: aiFailureMessage(failure),
              ),
            ),
          if (draft.isEmpty)
            Gutter(
              child: const EmptyStateCard(
                icon: Icons.search_off,
                title: '沒有讀到動作',
              ),
            ),
          for (final (index, (line, plan)) in draft.indexed)
            Gutter(
              child: SwipeAction(
                key: ObjectKey(line),
                label: '移除',
                semanticLabel: '移除「${line.name}」',
                onAction: () => _remove(index),
                child: NavCard(
                  tone: plan == null ? CardTone.warning : CardTone.neutral,
                  title: plan?.exercise.name ?? line.name,
                  subtitle: switch (plan) {
                    final plan? => _figuresOf(plan),
                    null => '找不到這個動作',
                  },
                  detail: line.text,
                  onTap: () => _pick(index),
                ),
              ),
            ),
          if (_isByAi)
            if (AppStoreScope.of(context).aiProvider case final provider?)
              Gutter(
                child: Text(
                  '${provider.label} 判讀',
                  style: AppTextStyles.caption,
                ),
              ),
          Gutter(
            child: Center(
              child: LinkText(
                label: '重新輸入',
                onTap: () => setState(() => _draft = null),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// `3 組 × 10 下 · 12 kg`; sets that differ are each written out:
/// `3 組 · 9 kg × 10、10、7 下`, or `12 kg × 10、10 kg × 8`.
String _figuresOf(PlannedExercise plan) => switch (plan.setLoads) {
  null =>
    '${plan.sets} 組 × ${plan.reps} 下 · '
        '${formatWeight(plan.targetWeightKg)} kg',
  final loads
      when loads.every((load) => load.weightKg == loads.first.weightKg) =>
    '${loads.length} 組 · ${formatWeight(loads.first.weightKg)} kg × '
        '${loads.map((load) => load.reps).join('、')} 下',
  final loads =>
    loads
        .map((load) => '${formatWeight(load.weightKg)} kg × ${load.reps}')
        .join('、'),
};
