import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_store.dart';
import '../../data/models.dart';
import '../format.dart';

const _tickInterval = Duration(seconds: 1);

/// Rebuilds every second with the active time of [workout].
class ElapsedClock extends StatefulWidget {
  const ElapsedClock({super.key, required this.workout, required this.builder});

  final WorkoutSession workout;
  final Widget Function(BuildContext context, String label) builder;

  @override
  State<ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<ElapsedClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tickInterval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = AppStoreScope.read(context).now();
    return widget.builder(context, formatClock(widget.workout.elapsedAt(now)));
  }
}
