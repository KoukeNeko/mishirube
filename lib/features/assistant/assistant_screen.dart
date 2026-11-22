import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_store.dart';
import '../../app/navigation.dart';
import '../../app/theme.dart';
import '../../backend/application/assistant_tools.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/motion.dart';
import '../../shared/widgets/widgets.dart';
import '../me/ai_draft_parts.dart';
import '../me/ai_proposal_screen.dart';
import '../me/ai_settings_screen.dart';
import '../training/generate_routines_screen.dart';
import '../../l10n/l10n.dart';

/// A conversation with the AI chosen in 「我的 > AI」 about the records,
/// and about 課表: it reads the records through the app's tools, and a
/// program it drafts or a change it proposes shows as a card that is
/// kept only once saved or accepted here (research 100, D3).
///
/// The conversation lasts as long as the page: nothing of it is stored.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, this.aboutTemplates = false, this.workout});

  /// Opened from 課表, so an on-device model gets the tools for them.
  final bool aboutTemplates;

  /// Opened from a finished workout: the conversation is about it and
  /// starts by asking for its review.
  final WorkoutSession? workout;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

/// One line of the conversation, and what came with a reply: the tools
/// the model called on the way, and the drafts they made.
class _Entry {
  _Entry(
    this.speaker,
    this.text, {
    this.tools = const [],
    this.thinking = '',
    this.program,
    this.change,
  });

  final AiSpeaker speaker;
  final String text;
  final List<String> tools;

  /// The model's reasoning, where the provider streams it.
  final String thinking;
  ProgramDraft? program;
  RoutineChangeDraft? change;

  /// What became of the reply's draft once it was kept: 「已存成 2 份課表」.
  String? outcome;
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _text = TextEditingController();
  final _entries = <_Entry>[];

  /// On the newest line, which is scrolled to the top so a long reply
  /// and the card under it read from their start.
  final _latest = GlobalKey();

  /// The tools called so far for the reply being waited for; null while
  /// none is.
  List<String>? _pending;
  String _thinking = '';

  /// Counts the questions asked; 停止 and 新對話 count one more, so a
  /// reply to a question asked before is dropped when it comes.
  int _asked = 0;

  AiFailure? _failure;

  bool get _isAsking => _pending != null;

  @override
  void initState() {
    super.initState();
    if (widget.workout != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || AppStoreScope.read(context).aiProvider == null) return;
        _ask(context.l10n.workoutReviewAsk);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _scrollToLatest() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final latest = _latest.currentContext;
    if (latest == null || !latest.mounted) return;
    Scrollable.ensureVisible(
      latest,
      duration: chromeDuration(context, const Duration(milliseconds: 250)),
      curve: Curves.easeOutCubic,
    );
  });

  void _sendTyped() {
    final message = _text.text.trim();
    if (message.isEmpty) return;
    _text.clear();
    _ask(message);
  }

  Future<void> _ask(String message) async {
    if (_isAsking) return;
    final store = AppStoreScope.read(context);
    final history = [
      for (final entry in _entries) AiTurn(entry.speaker, entry.text),
    ];
    final asked = ++_asked;
    // A workout's records go with every question about it, read as the
    // model's own reads are.
    final tools = <String>[if (widget.workout != null) 'workouts'];
    setState(() {
      _entries.add(_Entry(AiSpeaker.user, message));
      _pending = tools;
      _thinking = '';
      _failure = null;
    });
    _scrollToLatest();
    try {
      final reply = await store.askAssistant(
        history,
        message,
        aboutTemplates: widget.aboutTemplates,
        workout: widget.workout,
        onTool: (tool) {
          if (mounted && asked == _asked) setState(() => tools.add(tool));
        },
        onThinking: (delta) {
          if (mounted && asked == _asked) setState(() => _thinking += delta);
        },
      );
      if (!mounted || asked != _asked) return;
      setState(() {
        _entries.add(
          _Entry(
            AiSpeaker.assistant,
            reply.text,
            tools: tools,
            thinking: _thinking,
            program: reply.program,
            change: reply.routineChange,
          ),
        );
        _pending = null;
      });
      _scrollToLatest();
    } on AiException catch (error) {
      if (!mounted || asked != _asked) return;
      // The question goes back in the field, to be sent again.
      setState(() {
        _entries.removeLast();
        _text.text = message;
        _pending = null;
        _failure = error.failure == AiFailure.needsConsent
            ? null
            : error.failure;
      });
      if (error.failure == AiFailure.needsConsent &&
          await askCloudConsent(context)) {
        _text.clear();
        return _ask(message);
      }
    }
  }

  /// Stops waiting and puts the question back in the field.
  // shortcut: the request is not cancelled, only its reply dropped; it
  // only reads, so letting it finish costs the provider's time alone.
  void _stop() => setState(() {
    _asked++;
    _pending = null;
    _text.text = _entries.removeLast().text;
  });

  void _newChat() => setState(() {
    _asked++;
    _pending = null;
    _entries.clear();
    _failure = null;
    _text.clear();
  });

  /// Asks the last question again, in place of its reply.
  void _regenerate() {
    final question = _entries[_entries.length - 2].text;
    setState(() => _entries.length -= 2);
    _ask(question);
  }

  void _shuffle(_Entry entry) {
    final draft = entry.program!;
    final request = draft.request.copyWith(variant: draft.request.variant + 1);
    setState(
      () => entry.program = ProgramDraft(
        request,
        AppStoreScope.read(context).buildProgram(request),
      ),
    );
  }

  Future<void> _edit(_Entry entry) async {
    final isKept = await pushPage<bool>(
      context,
      GenerateRoutinesScreen(initialRequest: entry.program!.request),
    );
    if (isKept == true && mounted) setState(() => entry.program = null);
  }

  void _saveProgram(_Entry entry) {
    final saved = AppStoreScope.read(context)
        .saveProgram(entry.program!.program);
    setState(() {
      entry.program = null;
      entry.outcome = context.l10n.savedRoutinesCount(count: saved.length);
    });
  }

  void _accept(_Entry entry) {
    final change = entry.change!;
    final applied = AppStoreScope.read(context).applyRoutineChange(change);
    setState(() {
      entry.change = null;
      entry.outcome = applied == null
          ? null
          : context.l10n.appliedTo(routine: applied.name);
    });
  }

  List<Widget> _entryWidgets(_Entry entry) {
    final isLast = identical(entry, _entries.last);
    return [
      if (entry.tools.isNotEmpty || entry.thinking.isNotEmpty)
        Gutter(
          child: _Thinking(tools: entry.tools, thinking: entry.thinking),
        ),
      Gutter(child: _Line(entry: entry)),
      if (entry.program case final draft?)
        Gutter(
          child: _ProgramCard(
            draft: draft,
            onShuffle: () => _shuffle(entry),
            onEdit: () => _edit(entry),
            onSave: () => _saveProgram(entry),
          ),
        ),
      if (entry.change case final change?)
        Gutter(
          child: _ChangeCard(
            change: change,
            onReject: () => setState(() => entry.change = null),
            onAccept: () => _accept(entry),
          ),
        ),
      if (entry.outcome case final outcome?)
        Gutter(child: Text(outcome, style: AppTextStyles.caption)),
      if (entry.speaker == AiSpeaker.assistant)
        Gutter(
          child: _ReplyActions(
            text: entry.text,
            onRegenerate: isLast && !_isAsking ? _regenerate : null,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final store = AppStoreScope.of(context);
    final isOff = store.aiProvider == null;
    final workout = widget.workout;
    return DetailPage(
      appBar: PageAppBar(
        title: l10n.assistantTitle,
        subtitle: currentAiLabel(l10n, store),
        actions: [
          if (!isOff)
            HeaderAction(
              icon: Icons.edit_square,
              semanticLabel: l10n.assistantNewChat,
              onTap: _entries.isEmpty && !_isAsking ? null : _newChat,
            ),
        ],
      ),
      footer: isOff
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: [
                if (_entries.isEmpty && !_isAsking && workout == null)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final question in [
                          l10n.assistantSuggestWeek,
                          l10n.assistantSuggestProtein,
                          l10n.assistantSuggestProgram,
                        ])
                          ChipButton(
                            label: question,
                            onTap: () => _ask(question),
                          ),
                      ],
                    ),
                  ),
                AppTextField(
                  controller: _text,
                  hint: l10n.assistantHint,
                  minLines: 1,
                  maxLines: 5,
                  trailing: _SendButton(
                    controller: _text,
                    isAsking: _isAsking,
                    onSend: _sendTyped,
                    onStop: _stop,
                  ),
                ),
              ],
            ),
      children: [
        if (isOff) ...[
          const Gutter(child: AiFailureBanner(failure: AiFailure.unavailable)),
          Gutter(
            child: LinkText(
              label: l10n.openAiSettings(me: l10n.tabMe),
              onTap: () => pushPage(context, const AiSettingsScreen()),
            ),
          ),
        ],
        if (workout != null) Gutter(child: _WorkoutContext(workout: workout)),
        for (final entry in _entries)
          for (final (index, widget) in _entryWidgets(entry).indexed)
            index == 0 && identical(entry, _entries.last)
                ? KeyedSubtree(key: _latest, child: widget)
                : widget,
        if (_pending case final tools?)
          Gutter(
            child: _Thinking(
              tools: tools,
              thinking: _thinking,
              isWorking: true,
            ),
          ),
        if (_failure case final failure?)
          Gutter(child: AiFailureBanner(failure: failure)),
      ],
    );
  }
}

/// What the model read and reasoned for a reply, one line until
/// opened: 「思考中」 while it works, then how many reads there were.
class _Thinking extends StatefulWidget {
  const _Thinking({
    required this.tools,
    required this.thinking,
    this.isWorking = false,
  });

  final List<String> tools;
  final String thinking;
  final bool isWorking;

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> {
  bool _isOpen = false;

  static String _stepOf(AppLocalizations l10n, String tool) => switch (tool) {
    'find_exercise' ||
    'exercise_history' ||
    'workouts' ||
    'routines' ||
    'weekly_goal' => l10n.assistantStepRead(area: l10n.moduleTraining),
    'nutrition_days' ||
    'meals' => l10n.assistantStepRead(area: l10n.moduleNutrition),
    'sleep_days' => l10n.assistantStepRead(area: l10n.moduleSleep),
    'body_records' => l10n.assistantStepRead(area: l10n.moduleWeight),
    'activities' => l10n.assistantStepRead(area: l10n.moduleActivity),
    'wellness' => l10n.assistantStepRead(area: l10n.moduleWellness),
    'draft_program' || 'propose_routine_change' => l10n.assistantStepDraft,
    _ => l10n.assistantStepRecords,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A tool called again in a row reads as one step.
    final steps = <String>[];
    for (final tool in widget.tools) {
      final step = _stepOf(l10n, tool);
      if (steps.isEmpty || steps.last != step) steps.add(step);
    }
    final muted = AppTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
    );
    const spinner = SizedBox.square(
      dimension: 14,
      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
    );
    final thinking = widget.thinking.trim();
    final canOpen = steps.isNotEmpty || thinking.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: canOpen,
          expanded: canOpen ? _isOpen : null,
          child: InkWell(
            onTap: canOpen ? () => setState(() => _isOpen = !_isOpen) : null,
            borderRadius: BorderRadius.circular(AppRadius.small),
            // The whole line takes the tap, at least a touch target tall.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                spacing: AppSpacing.xs,
                children: [
                  if (widget.isWorking) spinner,
                  Text(
                    widget.isWorking
                        ? l10n.assistantThinking
                        : steps.isEmpty
                        ? l10n.aiThinking
                        : l10n.assistantReadCount(count: widget.tools.length),
                    style: muted,
                  ),
                  if (canOpen)
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: chromeDuration(
                        context,
                        const Duration(milliseconds: 200),
                      ),
                      child: const Icon(
                        Icons.expand_more,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: chromeDuration(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: !_isOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xxs,
                    children: [
                      for (final (index, step) in steps.indexed)
                        Row(
                          spacing: AppSpacing.xs,
                          children: [
                            if (widget.isWorking && index == steps.length - 1)
                              spinner
                            else
                              const Icon(
                                Icons.check,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                            Expanded(
                              child: Text(
                                step,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (thinking.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          // Reversed so the newest reasoning stays in view
                          // while it streams.
                          child: SingleChildScrollView(
                            reverse: widget.isWorking,
                            child: Text(
                              thinking,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// The send button at the end of the field: quiet until there is
/// something to send, and a stop button while a reply is waited for.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.controller,
    required this.isAsking,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool isAsking;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final canSend = controller.text.trim().isNotEmpty;
        final isActive = isAsking || canSend;
        return SquareIconButton(
          icon: isAsking ? Icons.stop_rounded : Icons.arrow_upward,
          tooltip: isAsking
              ? context.l10n.assistantStop
              : context.l10n.assistantSend,
          size: 44,
          radius: 22,
          background: isActive
              ? AppColors.textPrimary
              : AppColors.surfaceRaised,
          color: isActive ? AppColors.background : AppColors.textTertiary,
          onPressed: isAsking ? onStop : (canSend ? onSend : null),
        );
      },
    );
  }
}

/// Copying a reply, and asking for the last one again.
class _ReplyActions extends StatefulWidget {
  const _ReplyActions({required this.text, required this.onRegenerate});

  final String text;
  final VoidCallback? onRegenerate;

  @override
  State<_ReplyActions> createState() => _ReplyActionsState();
}

class _ReplyActionsState extends State<_ReplyActions> {
  bool _isCopied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _isCopied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isCopied = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget action(IconData icon, String tooltip, VoidCallback onPressed) =>
        SquareIconButton(
          icon: icon,
          tooltip: tooltip,
          size: 44,
          radius: 22,
          background: Colors.transparent,
          color: AppColors.textSecondary,
          onPressed: onPressed,
        );
    return Transform.translate(
      // The icons line up with the text, not their touch targets.
      offset: const Offset(-AppSpacing.sm, -AppSpacing.xs),
      child: Row(
        children: [
          action(
            _isCopied ? Icons.check : Icons.copy_rounded,
            l10n.assistantCopy,
            _copy,
          ),
          if (widget.onRegenerate case final onRegenerate?)
            action(Icons.refresh, l10n.assistantRegenerate, onRegenerate),
        ],
      ),
    );
  }
}

/// The finished workout a conversation is about, above it.
class _WorkoutContext extends StatelessWidget {
  const _WorkoutContext({required this.workout});

  final WorkoutSession workout;

  @override
  Widget build(BuildContext context) {
    final review = AppStoreScope.read(context).workoutReview(workout);
    return NavCard(
      leading: const Icon(Icons.fitness_center, color: AppColors.training),
      title: workout.routineName,
      subtitle: [
        context.dates.monthDay(workout.startedAt),
        context.l10n.setsAndVolume(
          sets: review.sets,
          volume: formatKcal(review.volumeKg.round()),
        ),
      ].join(' · '),
      showChevron: false,
    );
  }
}

/// A line of the conversation: the user's on the trailing side in a
/// bubble, the reply as plain text across the page.
class _Line extends StatelessWidget {
  const _Line({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final text = SelectableText(entry.text, style: AppTextStyles.body);
    if (entry.speaker == AiSpeaker.assistant) return text;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        alignment: AlignmentDirectional.centerEnd,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: text,
            ),
          ),
        ),
      ),
    );
  }
}

/// A drafted program: its workouts as the generator built them, to be
/// shuffled, edited in the generator, or saved.
class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.draft,
    required this.onShuffle,
    required this.onEdit,
    required this.onSave,
  });

  final ProgramDraft draft;
  final VoidCallback onShuffle;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final program = draft.program;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Text(l10n.generatedProgramName, style: AppTextStyles.overline),
          for (final workout in program.workouts)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  [
                    program.nameOf(l10n, workout),
                    l10n.durationMinutes(minutes: workout.length.inMinutes),
                  ].join(' · '),
                  style: AppTextStyles.itemTitle,
                ),
                for (final planned in workout.exercises)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          planned.exercise.name,
                          style: AppTextStyles.caption,
                        ),
                      ),
                      Text(
                        plannedFigures(planned),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            spacing: AppSpacing.xs,
            children: [
              Expanded(
                child: SecondaryButton(
                  label: l10n.shuffleProgram,
                  onPressed: onShuffle,
                ),
              ),
              Expanded(
                child: SecondaryButton(
                  label: l10n.commonEdit,
                  onPressed: onEdit,
                ),
              ),
              Expanded(
                child: PrimaryButton(
                  label: l10n.commonSave,
                  onPressed: program.workouts.isEmpty ? null : onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A proposed change to one 課表: what goes and what is added, to be
/// rejected or accepted.
class _ChangeCard extends StatelessWidget {
  const _ChangeCard({
    required this.change,
    required this.onReject,
    required this.onAccept,
  });

  final RoutineChangeDraft change;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        SectionLabel('${l10n.aiProposalTitle} · ${change.routine.name}'),
        for (final planned in change.routine.exercises)
          if (change.removed.contains(planned.exercise.id))
            ChangeRow(
              kind: ChangeKind.removed,
              title: planned.exercise.name,
              subtitle: plannedFigures(planned),
            ),
        for (final planned in change.added)
          ChangeRow(
            kind: ChangeKind.added,
            title: planned.exercise.name,
            subtitle: plannedFigures(planned),
          ),
        ButtonPair(
          secondary: SecondaryButton(label: l10n.reject, onPressed: onReject),
          primaryFlex: 2,
          primary: PrimaryButton(
            label: l10n.acceptAndApply,
            onPressed: onAccept,
          ),
        ),
      ],
    );
  }
}
