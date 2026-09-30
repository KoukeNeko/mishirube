import '../../app/view_model.dart';
import '../../backend/application/activity_service.dart';
import '../../backend/application/goal_service.dart';
import '../../backend/application/insights_service.dart';
import '../../backend/engines/period_stats.dart';
import '../../backend/engines/trend_findings.dart';
import '../../backend/engines/trend_engine.dart';
import '../../backend/engines/workout_review.dart';
import '../../domain/domain.dart';
import '../../l10n/l10n.dart';

/// Which body the muscle map is drawn on. It is a choice of drawing,
/// not a statement about the user: the same records are shaded either
/// way, and nothing else in the app reads it.
enum MuscleFigure {
  male,
  female;

  String labelIn(AppLocalizations l10n) => switch (this) {
    male => l10n.muscleFigureMale,
    female => l10n.muscleFigureFemale,
  };
}

/// Trends and the insight behind them: every figure is derived from the
/// records over a window, nothing is stored.
class TrendsViewModel extends ViewModel {
  TrendsViewModel(super.backend);

  static const _muscleFigureKey = 'muscle_figure';

  /// What changed over the last weeks, across every area.
  TrendsReport get report => backend.insights.report();

  /// One area week by week over the last [weeks] weeks, or all of it.
  AreaTrend areaTrend(TrendDomain domain, {int? weeks}) =>
      backend.insights.areaTrend(domain, weeks: weeks);

  /// What [trend]'s days come to; null without any.
  PeriodStats? statsOf(AreaTrend trend) => periodStats(trend.days);

  /// The night asleep the sleep figures are held against; null unset.
  Duration? get sleepGoal => backend.sleep.goal;

  /// The weekly goal and the weeks measured against it; null while it is
  /// off or not set, since a week cannot meet a goal nobody set.
  GoalOverview? get weeklyGoal => switch (backend.goal.overview()) {
    final overview when overview.isEnabled && overview.hasGoal => overview,
    _ => null,
  };

  /// What the training over [window] adds up to.
  ({
    int workouts,
    int sets,
    double volume,
    Duration time,
    Duration? averageLength,
    int records,
  })
  trainingTotals(Duration window) =>
      backend.insights.trainingTotals(window: window);

  /// Training figures over [window].
  TrendsOverview overview(Duration window) =>
      backend.insights.trends(window: window);

  /// Training volume for one exercise, or for the most trained one.
  VolumeReport? volumeReport({
    String? exerciseId,
    Duration window = const Duration(days: 28),
  }) => backend.insights.volumeReport(exerciseId: exerciseId, window: window);

  /// Working sets per muscle in each of the last eight weeks.
  List<(MuscleGroup, List<WeeklyBar>)> muscleWeeks() =>
      backend.insights.muscleWeeks();

  /// Every trained exercise with its history, most recent first.
  List<(ExerciseDefinition, ExerciseHistory)> exerciseHistories() =>
      backend.insights.exerciseHistories();

  /// Each exercise's heaviest set and best estimated max.
  List<ExerciseBests> personalRecords() => backend.insights.personalRecords();

  /// Exercise other than training over [window].
  ActivitySummary activity(Duration window) =>
      backend.activity.summary(window: window);

  /// Working sets per muscle per week, for seeing what is being trained
  /// and what is being left out.
  List<(MuscleGroup, int)> muscleLoad(Duration window) =>
      backend.insights.muscleLoad(window: window);

  /// Defaults to the male figure only because one of the two has to be
  /// first.
  MuscleFigure get muscleFigure => MuscleFigure.values.firstWhere(
    (figure) => figure.name == backend.db.setting(_muscleFigureKey),
    orElse: () => MuscleFigure.male,
  );

  void setMuscleFigure(MuscleFigure figure) =>
      backend.db.setSetting(_muscleFigureKey, figure.name);
}
