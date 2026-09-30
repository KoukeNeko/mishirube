import 'dart:ui';

import 'package:sensors_plus/sensors_plus.dart';

/// How the device is held and moved, for what on screen answers to it,
/// such as the water on Today settling level as the device tilts.
abstract interface class DeviceMotion {
  /// Acceleration across the screen, gravity included, in m/s²: x to
  /// the right, y towards the top edge. Held upright and still it reads
  /// about (0, 9.8).
  Stream<Offset> get acceleration;
}

/// No motion at all: tests, and devices without the sensor.
class NoDeviceMotion implements DeviceMotion {
  const NoDeviceMotion();

  @override
  Stream<Offset> get acceleration => const Stream.empty();
}

/// The accelerometer, read at the rate a user interface updates. One
/// stream is shared by whatever listens, and the sensor pauses while
/// nothing does.
class SensorDeviceMotion implements DeviceMotion {
  SensorDeviceMotion()
    : acceleration =
          accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
              .map((event) => Offset(event.x, event.y))
              // A device without the sensor has nothing to answer to.
              .handleError((Object _) {})
              .asBroadcastStream(
                onListen: (subscription) => subscription.resume(),
                onCancel: (subscription) => subscription.pause(),
              );

  @override
  final Stream<Offset> acceleration;
}
