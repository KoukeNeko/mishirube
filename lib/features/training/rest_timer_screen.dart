import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../app/theme.dart';
import '../../domain/domain.dart';
import '../../shared/format.dart';
import '../../shared/haptics.dart';
import '../../shared/widgets/content/elapsed_clock.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/window_layout.dart';

const _restExtension = Duration(seconds: 30);
const _tick = Duration(seconds: 1);

/// The rest between sets, counted down from the store's end time: it
/// keeps running when this page is left, and the workout page shows it.
class RestTimerScreen extends StatefulWidget {
  const RestTimerScreen({
    super.key,
    required this.exerciseName,
    required this.completedSet,
    required this.isPersonalRecord,
  });

  final String exerciseName;
  final WorkoutSet completedSet;
  final bool isPersonalRecord;

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick() {
    final store = AppStoreScope.read(context);
    if (store.settleRest()) AppHaptics.alert();
    if (store.restEndsAt == null) {
      _close();
    } else {
      setState(() {});
    }
  }

  void _skip() {
    AppStoreScope.read(context).skipRest();
    _close();
  }

  void _close() {
    _timer?.cancel();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStoreScope.of(context);
    final workout = store.activeWorkout;
    final endsAt = store.restEndsAt;
    final remaining = endsAt == null
        ? Duration.zero
        : endsAt.difference(store.now());
    final total = store.restLength;
    final elapsedFraction = total == Duration.zero
        ? 1.0
        : (1 - remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: contentColumnInsets(
            context,
            constraints.maxWidth,
            maxWidth: readableMaxWidth,
          ),
          child: SafeArea(
            // A phone on its side is too short for the countdown and the
            // set it follows, so there it scrolls; anywhere taller the
            // spacers spread it out as before.
            child: LayoutBuilder(
              builder: (context, safe) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: safe.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _RestHeader(workout: workout),
                        const Spacer(),
                        const Text(
                          '休息中',
                          style: TextStyle(
                            color: AppColors.training,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          formatClock(
                            remaining.isNegative ? Duration.zero : remaining,
                          ),
                          style: AppTextStyles.hugeNumber.copyWith(
                            fontSize: 112,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenGutter,
                          ),
                          child: ProgressLine(progress: elapsedFraction),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          child: _JustCompletedCard(
                            set: widget.completedSet,
                            isPersonalRecord: widget.isPersonalRecord,
                            nextLabel: _nextSetLabel(workout),
                          ),
                        ),
                        const Spacer(flex: 2),
                        Padding(
                          padding: const EdgeInsets.all(
                            AppSpacing.screenGutter,
                          ),
                          child: ButtonPair(
                            secondary: SecondaryButton(
                              label: '+30 秒',
                              onPressed: () => store.extendRest(_restExtension),
                            ),
                            primary: PrimaryButton(
                              label: '跳過休息',
                              onPressed: _skip,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _nextSetLabel(WorkoutSession? workout) {
    if (workout == null) return '訓練已結束';
    final exercise = workout.currentExercise;
    final nextIndex = exercise.nextSetIndex;
    if (nextIndex == null) return '所有組數已完成';
    final nextSet = exercise.sets[nextIndex];
    return '${exercise.exercise.name} · 第 ${nextIndex + 1} 組 · '
        '建議 ${formatWeight(nextSet.weightKg)} kg × ${nextSet.reps}';
  }
}

class _RestHeader extends StatelessWidget {
  const _RestHeader({required this.workout});

  final WorkoutSession? workout;

  @override
  Widget build(BuildContext context) {
    final session = workout;
    return Row(
      children: [
        const AppBarBackButton(),
        Expanded(
          child: Center(
            child: session == null
                ? const SizedBox.shrink()
                : ElapsedClock(
                    session: ActiveWorkout(session),
                    builder: (_, elapsed) => Text(
                      '${session.routineName} · $elapsed',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _JustCompletedCard extends StatelessWidget {
  const _JustCompletedCard({
    required this.set,
    required this.isPersonalRecord,
    required this.nextLabel,
  });

  final WorkoutSet set;
  final bool isPersonalRecord;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('剛完成', style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${formatWeight(set.weightKg)} kg × ${set.reps}',
                    style: AppTextStyles.bigNumber,
                  ),
                ),
              ),
              if (isPersonalRecord) ...[
                const SizedBox(width: AppSpacing.sm),
                const TagChip(label: '個人紀錄', tone: TagTone.solidTraining),
              ],
            ],
          ),
          const Divider(height: AppSpacing.xl),
          const Text('下一組', style: AppTextStyles.overline),
          const SizedBox(height: AppSpacing.xs),
          Text(nextLabel, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
