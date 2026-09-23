import '../../app/view_model.dart';
import '../../backend/application/goal_service.dart';

/// The weekly goal: how many days a week, the weeks measured against it,
/// the run of weeks met, and pausing or turning it off.
class GoalViewModel extends ViewModel {
  GoalViewModel(super.backend);

  GoalOverview get overview => backend.goal.overview();

  bool get isEnabled => backend.goal.isEnabled;

  /// From next week unless [applyThisWeek]; earlier weeks keep their own
  /// goal.
  void setGoal(int days, {bool applyThisWeek = false}) =>
      backend.goal.setGoal(days, applyThisWeek: applyThisWeek);

  /// Stops the goal applying until [until], or until resumed.
  void pause({DateTime? until}) => backend.goal.pause(until: until);

  void resume() => backend.goal.resume();

  /// Off hides the goal; the records and the trends stay.
  void setEnabled(bool value) => backend.goal.setEnabled(value);
}
