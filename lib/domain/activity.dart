import 'package:flutter/material.dart';

import '../shared/format.dart';

/// What a kind of exercise can be measured by. The form asks the type what
/// it supports instead of testing for particular sports.
enum ActivityCapability {
  /// A distance worth recording (running, cycling, swimming).
  distance,

  /// Distance over time is meaningful, so a pace can be shown.
  pace,

  /// Climbing is part of the effort.
  elevation,
}

/// How the picker groups the types.
enum ActivityGroup {
  walkRun('走路與跑步'),
  cycling('自行車'),
  water('水上運動'),
  ball('球類'),
  indoor('室內器材'),
  mindBody('身心與伸展'),
  other('其他');

  const ActivityGroup(this.label);

  final String label;
}

/// A kind of exercise. These are part of the app, not user data: the id is
/// what a record stores, so renaming a label never rewrites history.
class ActivityType {
  const ActivityType({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    this.capabilities = const {},
  });

  final String id;
  final String label;
  final IconData icon;
  final ActivityGroup group;
  final Set<ActivityCapability> capabilities;

  bool get tracksDistance => capabilities.contains(ActivityCapability.distance);

  bool get tracksPace => capabilities.contains(ActivityCapability.pace);

  @override
  bool operator ==(Object other) => other is ActivityType && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The types the app knows. Unknown ids (from an import) keep their
/// original name and fall back to [ActivityTypes.other].
abstract final class ActivityTypes {
  static const running = ActivityType(
    id: 'running',
    label: '跑步',
    icon: Icons.directions_run,
    group: ActivityGroup.walkRun,
    capabilities: {
      ActivityCapability.distance,
      ActivityCapability.pace,
      ActivityCapability.elevation,
    },
  );

  static const walking = ActivityType(
    id: 'walking',
    label: '健走',
    icon: Icons.directions_walk,
    group: ActivityGroup.walkRun,
    capabilities: {
      ActivityCapability.distance,
      ActivityCapability.pace,
      ActivityCapability.elevation,
    },
  );

  static const hiking = ActivityType(
    id: 'hiking',
    label: '健行',
    icon: Icons.terrain,
    group: ActivityGroup.walkRun,
    capabilities: {ActivityCapability.distance, ActivityCapability.elevation},
  );

  static const cycling = ActivityType(
    id: 'cycling',
    label: '騎自行車',
    icon: Icons.directions_bike,
    group: ActivityGroup.cycling,
    capabilities: {
      ActivityCapability.distance,
      ActivityCapability.pace,
      ActivityCapability.elevation,
    },
  );

  static const swimming = ActivityType(
    id: 'swimming',
    label: '游泳',
    icon: Icons.pool,
    group: ActivityGroup.water,
    capabilities: {ActivityCapability.distance, ActivityCapability.pace},
  );

  static const rowing = ActivityType(
    id: 'rowing',
    label: '划船機',
    icon: Icons.rowing,
    group: ActivityGroup.indoor,
    capabilities: {ActivityCapability.distance, ActivityCapability.pace},
  );

  static const elliptical = ActivityType(
    id: 'elliptical',
    label: '橢圓機',
    icon: Icons.fitness_center,
    group: ActivityGroup.indoor,
    capabilities: {ActivityCapability.distance},
  );

  static const stairs = ActivityType(
    id: 'stairs',
    label: '爬樓梯',
    icon: Icons.stairs,
    group: ActivityGroup.indoor,
    capabilities: {ActivityCapability.elevation},
  );

  static const basketball = ActivityType(
    id: 'basketball',
    label: '籃球',
    icon: Icons.sports_basketball,
    group: ActivityGroup.ball,
  );

  static const badminton = ActivityType(
    id: 'badminton',
    label: '羽球',
    icon: Icons.sports_tennis,
    group: ActivityGroup.ball,
  );

  static const yoga = ActivityType(
    id: 'yoga',
    label: '瑜伽',
    icon: Icons.self_improvement,
    group: ActivityGroup.mindBody,
  );

  static const other = ActivityType(
    id: 'other',
    label: '其他運動',
    icon: Icons.sports,
    group: ActivityGroup.other,
  );

  /// Offered first in the picker, before the full list.
  static const common = [running, walking, cycling, swimming, yoga, hiking];

  static const all = [
    running,
    walking,
    hiking,
    cycling,
    swimming,
    rowing,
    elliptical,
    stairs,
    basketball,
    badminton,
    yoga,
    other,
  ];

  static ActivityType byId(String id) =>
      all.firstWhere((type) => type.id == id, orElse: () => other);
}

/// One session of general exercise: a stretch of time doing something,
/// rather than sets of an exercise.
class ActivitySession {
  const ActivitySession({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.duration,
    this.distanceMeters,
    this.elevationGainMeters,
    this.effort,
    this.note = '',
    this.nativeType,
  });

  final String id;
  final ActivityType type;
  final DateTime startedAt;
  final Duration duration;
  final double? distanceMeters;
  final double? elevationGainMeters;

  /// How hard it felt, 1–10. Null when the user did not say.
  final int? effort;
  final String note;

  /// The source's own name for the type, kept when it is one we do not
  /// know, so a later mapping can reinterpret it.
  final String? nativeType;

  DateTime get endedAt => startedAt.add(duration);

  /// What the session reads as in a list: how long, and how far where
  /// that means something.
  String get description => [
    '${duration.inMinutes} 分',
    if (distanceMeters case final metres?) '${formatWeight(metres / 1000)} km',
  ].join(' · ');

  /// Seconds per kilometre, for types where that reads as a pace. Null
  /// without a distance to divide by.
  Duration? get pace {
    final metres = distanceMeters;
    if (!type.tracksPace || metres == null || metres <= 0) return null;
    return Duration(
      milliseconds: (duration.inMilliseconds * 1000 / metres).round(),
    );
  }
}
