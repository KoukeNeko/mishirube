import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../domain/domain.dart';

/// Points the map is handed at most: a long ride has thousands, and the
/// line looks the same with fewer.
const _maxPoints = 1500;

const _viewType = 'mishirube/route_map';

/// A session's route on a native map: Apple's MapKit on iOS
/// (`RouteMapView` in `ios/Runner/WorkoutDetail.swift`), MapLibre with
/// OpenFreeMap's tiles on Android (`RouteMap.kt`). Dark, the line
/// coloured by speed, with the start and the end marked.
class RouteMap extends StatelessWidget {
  const RouteMap({super.key, required this.route, this.isInteractive = false});

  final List<RoutePoint> route;

  /// Whether it pans and zooms; a map inside a scrolling page does not,
  /// so the page still scrolls over it.
  final bool isInteractive;

  /// Whether this device can draw one.
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  @override
  Widget build(BuildContext context) {
    if (!isSupported || route.length < 2) return const SizedBox.shrink();
    final step = (route.length / _maxPoints).ceil();
    final points = [
      for (var i = 0; i < route.length; i += step)
        [route[i].latitude, route[i].longitude, route[i].speed],
      if ((route.length - 1) % step != 0)
        [route.last.latitude, route.last.longitude, route.last.speed],
    ];
    final params = {'points': points, 'interactive': isInteractive};
    final gestures = isInteractive
        ? {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)}
        : <Factory<OneSequenceGestureRecognizer>>{};
    return Platform.isIOS
        ? UiKitView(
            viewType: _viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            gestureRecognizers: gestures,
          )
        : AndroidView(
            viewType: _viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            gestureRecognizers: gestures,
          );
  }
}
