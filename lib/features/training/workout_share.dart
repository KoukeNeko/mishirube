import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../backend/engines/workout_review.dart';
import '../../domain/domain.dart';
import '../../app/navigation.dart';
import '../../shared/format.dart';
import '../../shared/widgets/widgets.dart';
import '../../l10n/l10n.dart';

/// The width a shared picture is laid out at, in logical pixels; it is
/// drawn at three times that.
const _cardWidth = 360.0;
const _pixelRatio = 3.0;

/// Opens the page that shares [workout] as a picture of its card or as
/// text, through the system's share sheet.
Future<void> showWorkoutShare(
  BuildContext context, {
  required WorkoutSession workout,
  required WorkoutReview review,
}) => pushModalPage<void>(
  context,
  WorkoutSharePage(workout: workout, review: review),
);

/// [workout] as text: its name and when, its totals, then each exercise
/// with its sets, a record marked PR.
String workoutShareText(
  AppLocalizations l10n,
  AppDates dates,
  WorkoutSession workout,
  WorkoutReview review,
) {
  return [
    workout.routineName,
    _when(dates, workout),
    _totals(l10n, workout, review).join(' · '),
    for (final item in review.exercises) ...[
      '',
      [item.exercise.name, if (item.record != null) 'PR'].join(' · '),
      for (final (index, set) in item.done.indexed)
        '${index + 1}. ${set.figuresIn(l10n, item.exercise.trackingType)}',
    ],
  ].join('\n');
}

String _when(AppDates dates, WorkoutSession workout) =>
    '${dates.dayWithWeekday(workout.startedAt)} · '
    '${formatTimeOfDay(workout.startedAt)}–'
    '${formatTimeOfDay(workout.finishedAt ?? workout.startedAt)}';

/// The figures the summary page leads with, each as `label value`.
List<String> _totals(
  AppLocalizations l10n,
  WorkoutSession workout,
  WorkoutReview review,
) => [
  '${l10n.durationLabel} '
      '${formatClock(workout.elapsedAt(workout.finishedAt ?? workout.startedAt))}',
  '${l10n.totalSets} ${review.sets}',
  if (review.volumeKg > 0)
    '${l10n.totalAmount} ${formatKcal(review.volumeKg.round())} kg',
  if (review.seconds > 0)
    '${l10n.totalTime} ${formatClock(Duration(seconds: review.seconds))}',
  if (review.meters > 0)
    '${l10n.totalDistance} ${formatKilometers(review.meters)} km',
];

/// A finished workout's card as it will be shared, with sharing it as a
/// picture or as text at the foot.
class WorkoutSharePage extends StatefulWidget {
  const WorkoutSharePage({
    super.key,
    required this.workout,
    required this.review,
  });

  final WorkoutSession workout;
  final WorkoutReview review;

  @override
  State<WorkoutSharePage> createState() => _WorkoutSharePageState();
}

class _WorkoutSharePageState extends State<WorkoutSharePage> {
  final _card = GlobalKey();
  bool _isSharing = false;

  /// Where the system's sheet points from on a tablet: the button tapped.
  Rect? _originOf(BuildContext button) {
    final box = button.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(
    BuildContext button,
    ShareParams Function() params,
  ) async {
    setState(() => _isSharing = true);
    try {
      await SharePlus.instance.share(params());
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _shareImage(BuildContext button) async {
    final boundary =
        _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null || !mounted || !button.mounted) return;
    final origin = _originOf(button);
    await _share(
      button,
      () => ShareParams(
        files: [
          XFile.fromData(
            bytes.buffer.asUint8List(),
            mimeType: 'image/png',
            name: 'workout.png',
          ),
        ],
        sharePositionOrigin: origin,
      ),
    );
  }

  Future<void> _shareText(BuildContext button) {
    final text = workoutShareText(
      context.l10n,
      context.dates,
      widget.workout,
      widget.review,
    );
    final origin = _originOf(button);
    return _share(
      button,
      () => ShareParams(text: text, sharePositionOrigin: origin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DetailPage(
      appBar: PageAppBar(title: l10n.shareAction),
      footer: BottomActionBar(
        child: Row(
          spacing: AppSpacing.sm,
          children: [
            Expanded(
              child: Builder(
                builder: (button) => SecondaryButton(
                  label: l10n.shareAsText,
                  icon: Icons.notes_rounded,
                  onPressed: _isSharing ? null : () => _shareText(button),
                ),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (button) => PrimaryButton(
                  label: l10n.shareAsImage,
                  icon: Icons.image_outlined,
                  onPressed: _isSharing ? null : () => _shareImage(button),
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        Gutter(
          // The picture as it will be shared, scaled to the room.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: RepaintBoundary(
              key: _card,
              child: WorkoutShareCard(
                workout: widget.workout,
                review: widget.review,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A finished workout as a picture: its name and when, its totals, each
/// exercise with its sets, a record marked PR, and the app's name at the
/// foot. Laid out at a fixed width so it reads the same wherever it is
/// shared.
class WorkoutShareCard extends StatelessWidget {
  const WorkoutShareCard({
    super.key,
    required this.workout,
    required this.review,
  });

  final WorkoutSession workout;
  final WorkoutReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const figures = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    return Container(
      width: _cardWidth,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.trainingOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryLabel(label: l10n.moduleTraining, color: AppColors.training),
          const SizedBox(height: AppSpacing.xs),
          Text(workout.routineName, style: AppTextStyles.pageTitle),
          Text(_when(context.dates, workout), style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final total in _totals(l10n, workout, review))
                TagChip(label: total, tone: TagTone.training),
            ],
          ),
          for (final item in review.exercises) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.exercise.name,
                    style: AppTextStyles.itemTitle,
                  ),
                ),
                if (item.record != null)
                  const TagChip(label: 'PR', tone: TagTone.solidTraining),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              [
                for (final set in item.done)
                  set.figuresIn(l10n, item.exercise.trackingType),
              ].join('　'),
              style: AppTextStyles.body.merge(figures),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'MISHIRUBE',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
