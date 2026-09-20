/// The domain model: training, nutrition, body, wellness and the records
/// that tie them to a day. Domain types hold no storage, file or network
/// logic, so the layers above can depend on them without depending on
/// SQLite or the screens.
library;

export 'body.dart';
export 'exercise_filter.dart';
export 'history.dart';
export 'nutrition.dart';
export 'records.dart';
export 'training.dart';
export 'wellness.dart';
