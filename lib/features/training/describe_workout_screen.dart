import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../backend/engines/workout_text.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../exercise/exercise_picker_screen.dart';
import '../me/ai_draft_parts.dart';
import '../me/ai_settings_screen.dart';
import 'active_workout_screen.dart';
import 'new_routine_screen.dart';
import '../../l10n/l10n.dart';

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

  /// The AI that read [_draft], `Ollama Cloud / gemma4:31b`; null when the
  /// rules read it.
  String? _readBy;

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
      String? readBy,
      AiFailure? failure,
    }) => setState(() {
      _draft = draft;
      _readBy = readBy;
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
    // Named as it is asked, so a setting changed meanwhile does not rename
    // what already answered.
    final readBy = currentAiLabel(context.l10n, store);
    try {
      final byAi = await store.draftWorkoutWithAi(text);
      if (!mounted) return;
      // The AI's reading unless it found fewer exercises than the rules.
      int found(List<(WorkoutLine, PlannedExercise?)> draft) =>
          draft.where((entry) => entry.$2 != null).length;
      found(byAi) >= found(byRules)
          ? show(byAi, readBy: readBy)
          : show(byRules);
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
      showToast(
        context,
        context.l10n.activityBlocksWorkout,
        kind: ToastKind.warning,
      );
      return;
    }
    replaceWithPage(context, const ActiveWorkoutScreen());
  }

  /// Looked over and named first; once kept, back to where 課表 are
  /// listed, the new one among them.
  Future<void> _save() async {
    final isKept = await pushPage<bool>(
      context,
      NewRoutineScreen(planned: _planned),
    );
    if (isKept == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final planned = _planned;
    return DetailPage(
      appBar: PageAppBar(
        title: context.l10n.describeInWords,
        subtitle: currentAiLabel(context.l10n, AppStoreScope.of(context)),
      ),
      footer: draft == null
          ? DraftButton(
              isDrafting: _isReading,
              onPressed: _text.text.trim().isEmpty ? null : _read,
            )
          : ButtonPair(
              secondary: SecondaryButton(
                label: context.l10n.saveAsRoutine,
                onPressed: planned.isEmpty ? null : _save,
              ),
              primary: PrimaryButton(
                label: context.l10n.startWorkout,
                onPressed: planned.isEmpty ? null : _start,
              ),
            ),
      children: [
        if (draft == null)
          Gutter(
            child: DescribeField(
              controller: _text,
              hint: context.l10n.describeWorkoutHint,
            ),
          )
        else ...[
          if (_failure case final failure?)
            Gutter(child: AiFailureBanner(failure: failure)),
          if (draft.isEmpty)
            Gutter(
              child: EmptyStateCard(
                icon: Icons.search_off,
                title: context.l10n.noExercisesRead,
              ),
            ),
          for (final (index, (line, plan)) in draft.indexed)
            Gutter(
              child: SwipeAction(
                key: ObjectKey(line),
                label: context.l10n.removeAction,
                semanticLabel: context.l10n.removeNamed(name: line.name),
                onAction: () => _remove(index),
                child: NavCard(
                  tone: plan == null ? CardTone.warning : CardTone.neutral,
                  title: plan?.exercise.name ?? line.name,
                  subtitle: switch (plan) {
                    final plan? => _figuresOf(context.l10n, plan),
                    null => context.l10n.exerciseNotFound,
                  },
                  detail: line.text,
                  onTap: () => _pick(index),
                ),
              ),
            ),
          if (_readBy case final readBy?)
            Gutter(child: DraftAttribution(label: readBy)),
          Gutter(
            child: RewriteLink(onTap: () => setState(() => _draft = null)),
          ),
        ],
      ],
    );
  }
}

/// `3 組 × 10 下 · 12 kg`; sets that differ are each written out:
/// `3 組 · 9 kg × 10、10、7 下`, or `12 kg × 10、10 kg × 8`.
String _figuresOf(AppLocalizations l10n, PlannedExercise plan) =>
    switch (plan.setLoads) {
      null => l10n.setsTimesReps(
        sets: plan.sets,
        reps: plan.reps,
        weight: formatWeight(plan.targetWeightKg),
      ),
      final loads
          when loads.every((load) => load.weightKg == loads.first.weightKg) =>
        l10n.setsSameWeight(
          sets: loads.length,
          weight: formatWeight(loads.first.weightKg),
          reps: joinList(l10n, loads.map((load) => '${load.reps}')),
        ),
      final loads => joinList(
        l10n,
        loads.map((load) => '${formatWeight(load.weightKg)} kg × ${load.reps}'),
      ),
    };
