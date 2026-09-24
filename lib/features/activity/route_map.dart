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
  const RouteMap({
    super.key,
    required this.route,
    this.isInteractive = false,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final List<RoutePoint> route;

  /// Whether it pans and zooms; a map inside a scrolling page does not,
  /// so the page still scrolls over it.
  final bool isInteractive;

  /// What lies over the map at its top and bottom edges, in logical
  /// pixels, so the route is fitted into the part that shows.
  final double topInset;
  final double bottomInset;

  /// Whether this device can draw one.
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  @override
  Widget build(BuildContext context) {
    if (!isSupported || route.length < 2) return const SizedBox.shrink();
    final points = _sampled(route);
    final params = {
      'points': points,
      'interactive': isInteractive,
      'insets': [topInset, bottomInset],
    };
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

const _snapshots = MethodChannel('mishirube/route_map');

/// A session's route as a still picture of the same map (MapKit's
/// snapshotter on iOS, MapLibre's on Android), the route drawn on it.
/// Being a picture Flutter draws, it can be blurred and seen through the
/// bar's glass, which a live native map cannot. Until it arrives, or if
/// it cannot be made, the page's background shows instead.
class RouteSnapshot extends StatefulWidget {
  const RouteSnapshot({
    super.key,
    required this.route,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final List<RoutePoint> route;

  /// See [RouteMap.topInset].
  final double topInset;
  final double bottomInset;

  @override
  State<RouteSnapshot> createState() => _RouteSnapshotState();
}

class _RouteSnapshotState extends State<RouteSnapshot> {
  Size? _asked;
  Future<Uint8List?>? _picture;

  /// Asks for a picture of [size], once per size: the page lays out
  /// before the size is known, so the request waits for that frame.
  void _askFor(Size size, double scale) {
    if (_asked == size) return;
    _asked = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _picture = _snapshots.invokeMethod<Uint8List>('snapshot', {
          'points': _sampled(widget.route),
          'width': size.width,
          'height': size.height,
          'scale': scale,
          'insets': [widget.topInset, widget.bottomInset],
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!RouteMap.isSupported || widget.route.length < 2) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _askFor(constraints.biggest, MediaQuery.devicePixelRatioOf(context));
        return FutureBuilder(
          future: _picture,
          // A failed snapshot leaves the page's background: the route is
          // still a tap away on the live map.
          builder: (context, snapshot) => switch (snapshot.data) {
            final png? => Image.memory(
              png,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            null => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

/// At most [_maxPoints] of [route], its last point kept.
List<List<double>> _sampled(List<RoutePoint> route) {
  final step = (route.length / _maxPoints).ceil();
  return [
    for (var i = 0; i < route.length; i += step)
      [route[i].latitude, route[i].longitude, route[i].speed],
    if ((route.length - 1) % step != 0)
      [route.last.latitude, route.last.longitude, route.last.speed],
  ];
}
