/// The domain model: training, nutrition, body, wellness and the records
/// that tie them to a day. Domain types hold no storage, file or network
/// logic, so the layers above can depend on them without depending on
/// SQLite or the screens.
library;

export 'activity.dart';
export 'ai.dart';
export 'body.dart';
export 'exercise_filter.dart';
export 'goal.dart';
export 'health.dart';
export 'history.dart';
export 'note.dart';
export 'nutrition.dart';
export 'records.dart';
export 'session.dart';
export 'time.dart';
export 'training.dart';
export 'wellness.dart';
