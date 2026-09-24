import CoreLocation
import Flutter
import HealthKit
import MapKit
import UIKit

/// Everything Apple Health recorded during one workout, read when its
/// page opens, for `lib/backend/health/health_source.dart`. Nothing here
/// is kept: the route in particular stays in Health, not in the app.
///
/// Summary figures come from the workout's own statistics, which Health
/// has already de-duplicated; time series are the samples themselves, as
/// offsets in milliseconds from the start.
enum WorkoutDetail {
  static let store = HealthKitBridge.store

  /// What a workout's page reads beyond the workout itself: asked for
  /// with workouts.
  static var readTypes: Set<HKObjectType> {
    var types: Set<HKObjectType> = [
      HKSeriesType.workoutRoute(),
      HKQuantityType(.heartRate),
      HKQuantityType(.activeEnergyBurned),
      HKQuantityType(.basalEnergyBurned),
      HKQuantityType(.stepCount),
      HKQuantityType(.swimmingStrokeCount),
      HKCharacteristicType(.dateOfBirth),
    ]
    for (type, _, _) in seriesTypes { types.insert(type) }
    if #available(iOS 18.0, *) {
      types.insert(HKQuantityType(.workoutEffortScore))
      types.insert(HKQuantityType(.estimatedWorkoutEffortScore))
    }
    return types
  }

  /// The series a workout's page draws, each in the app's unit.
  static var seriesTypes: [(type: HKQuantityType, series: String, unit: HKUnit)] {
    let metresPerSecond = HKUnit.meter().unitDivided(by: .second())
    let perMinute = HKUnit.count().unitDivided(by: .minute())
    var types: [(type: HKQuantityType, series: String, unit: HKUnit)] = []
    if #available(iOS 16.0, *) {
      types += [
        (HKQuantityType(.runningSpeed), "speed", metresPerSecond),
        (HKQuantityType(.runningPower), "power", .watt()),
        (HKQuantityType(.runningStrideLength), "strideLength", .meter()),
        (HKQuantityType(.runningGroundContactTime), "groundContactTime", .secondUnit(with: .milli)),
        (HKQuantityType(.runningVerticalOscillation), "verticalOscillation", .meterUnit(with: .centi)),
      ]
    }
    if #available(iOS 17.0, *) {
      types += [
        (HKQuantityType(.cyclingSpeed), "speed", metresPerSecond),
        (HKQuantityType(.cyclingPower), "power", .watt()),
        (HKQuantityType(.cyclingCadence), "cadence", perMinute),
      ]
    }
    return types
  }

  static func read(id: String, result: @escaping FlutterResult) {
    guard let uuid = UUID(uuidString: id) else {
      result(nil)
      return
    }
    let query = HKSampleQuery(
      sampleType: .workoutType(), predicate: HKQuery.predicateForObject(with: uuid),
      limit: 1, sortDescriptors: nil
    ) { _, samples, error in
      guard let workout = samples?.first as? HKWorkout else {
        DispatchQueue.main.async {
          if let error {
            result(FlutterError(code: "failed", message: "\(error)", details: nil))
          } else {
            result(nil)
          }
        }
        return
      }
      Task {
        let detail = await detail(of: workout)
        await MainActor.run { result(detail) }
      }
    }
    store.execute(query)
  }

  static func detail(of workout: HKWorkout) async -> [String: Any] {
    let start = workout.startDate
    var detail: [String: Any] = [
      "activeMs": Int(workout.duration * 1000),
      "device": workout.device?.name ?? workout.sourceRevision.source.name,
    ]
    let metadata = workout.metadata ?? [:]
    if let indoor = metadata[HKMetadataKeyIndoorWorkout] as? Bool {
      detail["indoor"] = indoor
    }
    if let temperature = metadata[HKMetadataKeyWeatherTemperature] as? HKQuantity {
      detail["temperature"] = temperature.doubleValue(for: .degreeCelsius())
    }
    if let humidity = metadata[HKMetadataKeyWeatherHumidity] as? HKQuantity {
      detail["humidity"] = humidity.doubleValue(for: .percent()) * 100
    }
    if let climb = metadata[HKMetadataKeyElevationAscended] as? HKQuantity {
      detail["elevationGain"] = climb.doubleValue(for: .meter())
    }
    if let lap = metadata[HKMetadataKeyLapLength] as? HKQuantity {
      detail["lapLength"] = lap.doubleValue(for: .meter())
    }

    var figures: [String: Double] = [:]
    let interval = HKQuery.predicateForSamples(
      withStart: start, end: workout.endDate, options: .strictStartDate)
    figures["activeEnergy"] = await sum(.activeEnergyBurned, .kilocalorie(), interval)
    if let active = figures["activeEnergy"],
      let basal = await sum(.basalEnergyBurned, .kilocalorie(), interval)
    {
      figures["totalEnergy"] = active + basal
    }
    for type in HealthKitBridge.distanceTypes {
      if let metres = await sum(type, .meter(), interval), metres > 0 {
        figures["distance"] = metres
        break
      }
    }
    figures["steps"] = await sum(HKQuantityType(.stepCount), .count(), interval)
    figures["swimmingStrokes"] = await sum(
      HKQuantityType(.swimmingStrokeCount), .count(), interval)
    detail["figures"] = figures.compactMapValues { $0 }

    let bpm = HKUnit.count().unitDivided(by: .minute())
    var series: [String: [[Double]]] = [:]
    series["heartRate"] = await samples(
      HKQuantityType(.heartRate), bpm, from: start, to: workout.endDate)
    for (type, name, unit) in seriesTypes where series[name]?.isEmpty ?? true {
      let found = await samples(type, unit, from: start, to: workout.endDate)
      if !found.isEmpty { series[name] = found }
    }
    // Apple Watch keeps reading the heart for about three minutes after
    // a workout ends; that is the recovery the page shows.
    series["recovery"] = await samples(
      HKQuantityType(.heartRate), bpm, from: workout.endDate,
      to: workout.endDate.addingTimeInterval(180), relativeTo: workout.endDate)
    detail["series"] = series.filter { !$0.value.isEmpty }

    let route = await routeOf(workout)
    if !route.isEmpty {
      detail["route"] = route.map { location in
        [
          location.coordinate.latitude, location.coordinate.longitude,
          location.altitude, location.timestamp.timeIntervalSince(start) * 1000,
          max(location.speed, 0),
        ]
      }
      if let place = await placeOf(route.first!) { detail["place"] = place }
    }

    detail["laps"] = (workout.workoutEvents ?? []).compactMap { event -> [Any]? in
      guard event.type == .lap || event.type == .segment else { return nil }
      return [
        event.type == .lap ? "lap" : "segment",
        event.dateInterval.start.timeIntervalSince(start) * 1000,
        event.dateInterval.end.timeIntervalSince(start) * 1000,
      ]
    }

    if #available(iOS 18.0, *) {
      if let effort = await effortOf(workout, .workoutEffortScore) {
        detail["effort"] = effort
      }
      if let effort = await effortOf(workout, .estimatedWorkoutEffortScore) {
        detail["estimatedEffort"] = effort
      }
    }
    if let birth = try? store.dateOfBirthComponents(),
      let years = Calendar.current.dateComponents(
        [.year], from: Calendar.current.date(from: birth) ?? start, to: start
      ).year
    {
      detail["age"] = years
    }
    return detail
  }

  static func sum(
    _ identifier: HKQuantityTypeIdentifier, _ unit: HKUnit, _ predicate: NSPredicate
  ) async -> Double? {
    await sum(HKQuantityType(identifier), unit, predicate)
  }

  /// The de-duplicated total of [type] over the workout.
  static func sum(_ type: HKQuantityType, _ unit: HKUnit, _ predicate: NSPredicate) async
    -> Double?
  {
    await withCheckedContinuation { continuation in
      let query = HKStatisticsQuery(
        quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum
      ) { _, statistics, _ in
        continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
      }
      store.execute(query)
    }
  }

  /// Every sample of [type] from [from] to [to], as offsets from
  /// [relativeTo] (the start, unless said) and values in [unit].
  static func samples(
    _ type: HKQuantityType, _ unit: HKUnit, from: Date, to: Date, relativeTo: Date? = nil
  ) async -> [[Double]] {
    let origin = relativeTo ?? from
    return await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: HKQuery.predicateForSamples(withStart: from, end: to),
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, samples, _ in
        let rows = (samples ?? []).compactMap { sample -> [Double]? in
          guard let sample = sample as? HKQuantitySample,
            sample.quantity.is(compatibleWith: unit)
          else { return nil }
          return [
            sample.startDate.timeIntervalSince(origin) * 1000,
            sample.quantity.doubleValue(for: unit),
          ]
        }
        continuation.resume(returning: rows)
      }
      store.execute(query)
    }
  }

  /// The workout's GPS route, in order; empty indoors or without one.
  static func routeOf(_ workout: HKWorkout) async -> [CLLocation] {
    let routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: HKSeriesType.workoutRoute(),
        predicate: HKQuery.predicateForObjects(from: workout),
        limit: HKObjectQueryNoLimit, sortDescriptors: nil
      ) { _, samples, _ in
        continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKWorkoutRoute })
      }
      store.execute(query)
    }
    var locations: [CLLocation] = []
    for route in routes {
      locations += await withCheckedContinuation { continuation in
        var found: [CLLocation] = []
        let query = HKWorkoutRouteQuery(route: route) { _, batch, done, _ in
          found += batch ?? []
          if done { continuation.resume(returning: found) }
        }
        store.execute(query)
      }
    }
    return locations.sorted { $0.timestamp < $1.timestamp }
  }

  /// The city the workout started in, and no more precise than that.
  static func placeOf(_ location: CLLocation) async -> String? {
    let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
    return placemark?.locality ?? placemark?.subAdministrativeArea
  }

  @available(iOS 18.0, *)
  static func effortOf(_ workout: HKWorkout, _ identifier: HKQuantityTypeIdentifier) async
    -> Double?
  {
    await withCheckedContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: HKQuantityType(identifier),
        predicate: HKQuery.predicateForWorkoutEffortSamplesRelated(
          workout: workout, activity: nil),
        limit: 1, sortDescriptors: nil
      ) { _, samples, _ in
        let score = (samples?.first as? HKQuantitySample)?.quantity
          .doubleValue(for: .appleEffortScore())
        continuation.resume(returning: score)
      }
      store.execute(query)
    }
  }
}

/// A workout's route on Apple's map, for
/// `lib/features/activity/route_map.dart`: dark, the line coloured by
/// speed from slow to fast, and a dot at the start and the end.
final class RouteMapFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier: Int64, arguments: Any?)
    -> FlutterPlatformView
  {
    RouteMapView(frame: frame, arguments: arguments as? [String: Any] ?? [:])
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class RouteMapView: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let map: MKMapView
  private var colors: [UIColor] = []
  private var stops: [CGFloat] = []

  init(frame: CGRect, arguments: [String: Any]) {
    map = MKMapView(frame: frame)
    super.init()
    map.delegate = self
    map.overrideUserInterfaceStyle = .dark
    if #available(iOS 16.0, *) {
      map.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
    }
    let interactive = arguments["interactive"] as? Bool ?? false
    map.isScrollEnabled = interactive
    map.isZoomEnabled = interactive
    map.isRotateEnabled = interactive
    map.isPitchEnabled = false
    map.showsCompass = interactive
    map.pointOfInterestFilter = .excludingAll

    let points = (arguments["points"] as? [[Double]] ?? []).filter { $0.count >= 3 }
    guard points.count >= 2 else { return }
    let coordinates = points.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    let line = MKPolyline(coordinates: coordinates, count: coordinates.count)
    let speeds = points.map { $0[2] }
    let slowest = speeds.min() ?? 0
    let range = max((speeds.max() ?? 0) - slowest, 0.1)
    colors = speeds.map { speed in
      // Red when slow, through yellow, to green when fast.
      UIColor(hue: CGFloat((speed - slowest) / range) * 0.33, saturation: 0.85,
        brightness: 0.95, alpha: 1)
    }
    stops = (0..<points.count).map { CGFloat($0) / CGFloat(points.count - 1) }
    map.addOverlay(line)
    map.addAnnotations([Endpoint(coordinates.first!, isStart: true),
      Endpoint(coordinates.last!, isStart: false)])
    map.setVisibleMapRect(
      line.boundingMapRect, edgePadding: UIEdgeInsets(top: 48, left: 32, bottom: 48, right: 32),
      animated: false)
  }

  func view() -> UIView { map }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
    let renderer = MKGradientPolylineRenderer(polyline: line)
    renderer.setColors(colors, locations: stops)
    renderer.lineWidth = 5
    renderer.lineCap = .round
    return renderer
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let endpoint = annotation as? Endpoint else { return nil }
    let view = MKAnnotationView(annotation: endpoint, reuseIdentifier: nil)
    let size: CGFloat = 16
    let dot = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
    dot.backgroundColor = endpoint.isStart ? .systemGreen : .systemRed
    dot.layer.cornerRadius = size / 2
    dot.layer.borderColor = UIColor.white.cgColor
    dot.layer.borderWidth = 2
    view.frame = dot.frame
    view.addSubview(dot)
    return view
  }

  final class Endpoint: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool

    init(_ coordinate: CLLocationCoordinate2D, isStart: Bool) {
      self.coordinate = coordinate
      self.isStart = isStart
    }
  }
}
