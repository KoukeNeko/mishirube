import ActivityKit
import Flutter
import HealthKit
import Photos
import ImageIO
import UIKit
import UserNotifications
import Vision
import WatchConnectivity

#if canImport(FoundationModels)
  import FoundationModels
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppleIntelligence") {
      AppleIntelligence.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HealthKitBridge") {
      HealthKitBridge.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RouteMap") {
      registrar.register(RouteMapFactory(), withId: "mishirube/route_map")
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RouteSnapshot") {
      RouteSnapshot.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LabelReader") {
      LabelReader.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PhotoLibrary") {
      PhotoLibrary.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchBridge") {
      WatchBridge.shared.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BedtimeReminder") {
      BedtimeReminder.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RestNotice") {
      RestNotice.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CaffeineActivity") {
      CaffeineActivity.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenAwake") {
      ScreenAwake.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SystemCalendar") {
      SystemCalendar.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppInfo") {
      AppInfo.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WindowControls") {
      WindowControls.register(with: registrar.messenger())
    }
  }
}

/// Apple Health, read only, for `lib/backend/health/health_source.dart`.
///
/// Three calls, the same ones Health Connect answers on Android:
/// whether Health is here, a request to read, and one kind's records in
/// a window. Swift only fetches and names things in the app's terms;
/// turning sleep samples into nights is `nightsOf` in Dart, where it can
/// be tested.
enum HealthKitBridge {
  static let store = HKHealthStore()

  static func type(of kind: String) -> HKSampleType? {
    switch kind {
    case "sleep": return HKCategoryType(.sleepAnalysis)
    case "weight": return HKQuantityType(.bodyMass)
    case "waist": return HKQuantityType(.waistCircumference)
    case "workouts": return HKWorkoutType.workoutType()
    case "water": return HKQuantityType(.dietaryWater)
    default: return nil
    }
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mishirube/healthkit", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "isAvailable":
        result(HKHealthStore.isHealthDataAvailable())
      case "grantedKinds":
        // HealthKit does not tell an app whether reading was allowed, so
        // "not allowed" and "nothing recorded" look the same. Say so.
        result(nil)
      case "takePrivacyRequest":
        result(false)
      case "requestAccess":
        let kinds = arguments["kinds"] as? [String] ?? []
        var types = Set<HKObjectType>(kinds.compactMap(type(of:)))
        // A workout's distance lives in these.
        if kinds.contains("workouts") {
          types.formUnion(distanceTypes)
          types.formUnion(WorkoutDetail.readTypes)
        }
        if kinds.contains("overnight") {
          types.formUnion(overnightTypes.map(\.type))
        }
        if kinds.contains("body") {
          types.formUnion(bodyTypes.map(\.type))
        }
        if kinds.contains("activity") {
          types.formUnion(activityTypes.map(\.type))
          types.insert(HKCategoryType(.mindfulSession))
        }
        if kinds.contains("nutrition") {
          types.formUnion(dietaryTypes.map(\.type))
        }
        if kinds.contains("mood"), #available(iOS 18.0, *) {
          types.insert(HKObjectType.stateOfMindType())
        }
        store.requestAuthorization(toShare: HealthKitWriter.shareTypes(for: kinds), read: types) {
          success, error in
          DispatchQueue.main.async {
            if let error {
              result(FlutterError(code: "failed", message: "\(error)", details: nil))
            } else {
              result(success)
            }
          }
        }
      case "write":
        let writes = arguments["writes"] as? [[String: Any]] ?? []
        Task {
          do {
            try await HealthKitWriter.write(writes)
            await MainActor.run { result(nil) }
          } catch {
            await MainActor.run {
              result(FlutterError(code: "failed", message: "\(error)", details: nil))
            }
          }
        }
      case "workoutDetail":
        guard let id = arguments["id"] as? String else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        WorkoutDetail.read(id: id, result: result)
      case "read" where arguments["kind"] as? String == "activity":
        guard let from = arguments["from"] as? Int, let to = arguments["to"] as? Int else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        readActivity(
          from: Date(timeIntervalSince1970: Double(from) / 1000),
          to: Date(timeIntervalSince1970: Double(to) / 1000),
          daily: arguments["daily"] as? Bool ?? false,
          result: result)
      case "read" where arguments["kind"] as? String == "nutrition":
        guard let from = arguments["from"] as? Int, let to = arguments["to"] as? Int else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        readFoods(
          from: Date(timeIntervalSince1970: Double(from) / 1000),
          to: Date(timeIntervalSince1970: Double(to) / 1000),
          result: result)
      case "read" where arguments["kind"] as? String == "mood":
        guard let from = arguments["from"] as? Int, let to = arguments["to"] as? Int else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        readMoods(
          from: Date(timeIntervalSince1970: Double(from) / 1000),
          to: Date(timeIntervalSince1970: Double(to) / 1000),
          result: result)
      case "read" where arguments["kind"] as? String == "body":
        guard let from = arguments["from"] as? Int, let to = arguments["to"] as? Int else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        readBody(
          from: Date(timeIntervalSince1970: Double(from) / 1000),
          to: Date(timeIntervalSince1970: Double(to) / 1000),
          result: result)
      case "read":
        guard let kind = arguments["kind"] as? String,
          let sampleType = type(of: kind),
          let from = arguments["from"] as? Int,
          let to = arguments["to"] as? Int
        else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        read(
          kind: kind, type: sampleType,
          from: Date(timeIntervalSince1970: Double(from) / 1000),
          to: Date(timeIntervalSince1970: Double(to) / 1000),
          result: result)
      case "overnight":
        let windows = (arguments["windows"] as? [[Int]] ?? []).compactMap { pair in
          pair.count == 2
            ? DateInterval(
              start: Date(timeIntervalSince1970: Double(pair[0]) / 1000),
              end: Date(timeIntervalSince1970: Double(max(pair[0], pair[1])) / 1000))
            : nil
        }
        overnight(windows: windows, result: result)
      case "overnightSeries":
        guard let from = arguments["from"] as? Int, let to = arguments["to"] as? Int else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        overnightSeries(
          from: Date(timeIntervalSince1970: Double(from) / 1000),
          to: Date(timeIntervalSince1970: Double(to) / 1000),
          result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// The body figures Health keeps, each as the app's metric, in the
  /// app's unit: body fat is a 0–1 fraction in Health and a percentage
  /// in the app.
  static let bodyTypes: [(type: HKQuantityType, metric: String, unit: HKUnit, scale: Double)] = [
    (HKQuantityType(.height), "height", .meterUnit(with: .centi), 1),
    (HKQuantityType(.bodyFatPercentage), "bodyFat", .percent(), 100),
    (HKQuantityType(.leanBodyMass), "leanMass", .gramUnit(with: .kilo), 1),
  ]

  /// Every body figure in the window, all types together.
  static func readBody(from: Date, to: Date, result: @escaping FlutterResult) {
    let group = DispatchGroup()
    let lock = NSLock()
    var rows: [[String: Any]] = []
    var failure: Error?
    for body in bodyTypes {
      group.enter()
      let query = HKSampleQuery(
        sampleType: body.type, predicate: HKQuery.predicateForSamples(withStart: from, end: to),
        limit: HKObjectQueryNoLimit, sortDescriptors: nil
      ) { _, samples, error in
        lock.lock()
        if let error { failure = error }
        for case let sample as HKQuantitySample in samples ?? [] where !isOurs(sample) {
          rows.append([
            "id": sample.uuid.uuidString, "at": milliseconds(sample.startDate),
            "metric": body.metric,
            "value": sample.quantity.doubleValue(for: body.unit) * body.scale,
          ])
        }
        lock.unlock()
        group.leave()
      }
      store.execute(query)
    }
    group.notify(queue: .main) {
      // One type Health refuses to read is that type missing, not the
      // whole read failing; only when nothing came back is it an error.
      if let failure, rows.isEmpty {
        result(FlutterError(code: "failed", message: "\(failure)", details: nil))
      } else {
        result(rows)
      }
    }
  }

  /// What a food entry's figures are called in the app, in the app's
  /// unit: energy and the four figures every meal has by field, the rest
  /// by `Nutrient` name. Water is read under its own kind.
  static let dietaryTypes: [(type: HKQuantityType, field: String, unit: HKUnit)] = {
    let milligram = HKUnit.gramUnit(with: .milli)
    let microgram = HKUnit.gramUnit(with: .micro)
    return [
      (HKQuantityType(.dietaryEnergyConsumed), "kcal", .kilocalorie()),
      (HKQuantityType(.dietaryProtein), "protein", .gram()),
      (HKQuantityType(.dietaryCarbohydrates), "carb", .gram()),
      (HKQuantityType(.dietaryFatTotal), "fat", .gram()),
      (HKQuantityType(.dietaryFiber), "fibre", .gram()),
      (HKQuantityType(.dietaryFatSaturated), "saturatedFat", .gram()),
      (HKQuantityType(.dietaryFatMonounsaturated), "monounsaturatedFat", .gram()),
      (HKQuantityType(.dietaryFatPolyunsaturated), "polyunsaturatedFat", .gram()),
      (HKQuantityType(.dietarySugar), "sugar", .gram()),
      (HKQuantityType(.dietarySodium), "sodium", milligram),
      (HKQuantityType(.dietaryCholesterol), "cholesterol", milligram),
      (HKQuantityType(.dietaryCaffeine), "caffeine", milligram),
      (HKQuantityType(.dietaryCalcium), "calcium", milligram),
      (HKQuantityType(.dietaryPhosphorus), "phosphorus", milligram),
      (HKQuantityType(.dietaryMagnesium), "magnesium", milligram),
      (HKQuantityType(.dietaryIron), "iron", milligram),
      (HKQuantityType(.dietaryZinc), "zinc", milligram),
      (HKQuantityType(.dietaryPotassium), "potassium", milligram),
      (HKQuantityType(.dietaryIodine), "iodine", microgram),
      (HKQuantityType(.dietarySelenium), "selenium", microgram),
      (HKQuantityType(.dietaryCopper), "copper", milligram),
      (HKQuantityType(.dietaryManganese), "manganese", milligram),
      (HKQuantityType(.dietaryChromium), "chromium", microgram),
      (HKQuantityType(.dietaryMolybdenum), "molybdenum", microgram),
      (HKQuantityType(.dietaryChloride), "chloride", milligram),
      (HKQuantityType(.dietaryVitaminA), "vitaminA", microgram),
      (HKQuantityType(.dietaryVitaminD), "vitaminD", microgram),
      (HKQuantityType(.dietaryVitaminE), "vitaminE", milligram),
      (HKQuantityType(.dietaryVitaminK), "vitaminK", microgram),
      (HKQuantityType(.dietaryVitaminC), "vitaminC", milligram),
      (HKQuantityType(.dietaryThiamin), "vitaminB1", milligram),
      (HKQuantityType(.dietaryRiboflavin), "vitaminB2", milligram),
      (HKQuantityType(.dietaryNiacin), "niacin", milligram),
      (HKQuantityType(.dietaryVitaminB6), "vitaminB6", milligram),
      (HKQuantityType(.dietaryVitaminB12), "vitaminB12", microgram),
      (HKQuantityType(.dietaryFolate), "folate", microgram),
      (HKQuantityType(.dietaryPantothenicAcid), "pantothenicAcid", milligram),
      (HKQuantityType(.dietaryBiotin), "biotin", microgram),
    ]
  }()

  /// The fields a meal keeps outside its nutrients.
  static let mealFields: Set<String> = ["kcal", "protein", "carb", "fat", "fibre"]

  /// Every food entry in the window, one row each. An app that logs a
  /// food writes a food correlation holding one sample per figure; one
  /// that writes the samples alone is grouped by app, time and food
  /// name, so each entry comes in once with all its figures.
  static func readFoods(from: Date, to: Date, result: @escaping FlutterResult) {
    let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
    let fieldOf = Dictionary(
      uniqueKeysWithValues: dietaryTypes.map { ($0.type, ($0.field, $0.unit)) })

    struct Entry {
      var id: String
      var at: Date
      var name: String?
      var source: String
      var values: [String: Double] = [:]
    }
    func add(_ sample: HKQuantitySample, to entry: inout Entry) {
      guard let (field, unit) = fieldOf[sample.quantityType] else { return }
      entry.values[field, default: 0] += sample.quantity.doubleValue(for: unit)
    }
    func row(_ entry: Entry) -> [String: Any]? {
      guard !entry.values.isEmpty else { return nil }
      var row: [String: Any] = [
        "id": entry.id, "at": milliseconds(entry.at), "source": entry.source,
      ]
      if let name = entry.name { row["name"] = name }
      var nutrients: [String: Double] = [:]
      for (field, value) in entry.values {
        if mealFields.contains(field) { row[field] = value } else { nutrients[field] = value }
      }
      row["nutrients"] = nutrients
      return row
    }

    let foods = HKSampleQuery(
      sampleType: HKCorrelationType(.food), predicate: predicate,
      limit: HKObjectQueryNoLimit, sortDescriptors: nil
    ) { _, correlations, correlationError in
      var entries: [Entry] = []
      var inFoods = Set<UUID>()
      for case let food as HKCorrelation in correlations ?? [] where !isOurs(food) {
        var entry = Entry(
          id: food.uuid.uuidString, at: food.startDate,
          name: food.metadata?[HKMetadataKeyFoodType] as? String,
          source: food.sourceRevision.source.name)
        for case let sample as HKQuantitySample in food.objects {
          inFoods.insert(sample.uuid)
          add(sample, to: &entry)
        }
        entries.append(entry)
      }

      let group = DispatchGroup()
      let lock = NSLock()
      var loose: [String: Entry] = [:]
      var failure: Error? = correlationError
      for dietary in dietaryTypes {
        group.enter()
        let query = HKSampleQuery(
          sampleType: dietary.type, predicate: predicate,
          limit: HKObjectQueryNoLimit, sortDescriptors: nil
        ) { _, samples, error in
          lock.lock()
          if let error { failure = error }
          for case let sample as HKQuantitySample in samples ?? []
          where !inFoods.contains(sample.uuid) && !isOurs(sample) {
            let source = sample.sourceRevision.source
            let name = sample.metadata?[HKMetadataKeyFoodType] as? String
            let key = "\(source.bundleIdentifier)|\(milliseconds(sample.startDate))|\(name ?? "")"
            var entry =
              loose[key]
              ?? Entry(
                id: sample.uuid.uuidString, at: sample.startDate, name: name, source: source.name)
            // Named by its smallest sample id, so a re-read finds the same one.
            entry.id = min(entry.id, sample.uuid.uuidString)
            add(sample, to: &entry)
            loose[key] = entry
          }
          lock.unlock()
          group.leave()
        }
        store.execute(query)
      }
      group.notify(queue: .main) {
        let rows = (entries + loose.values).compactMap(row)
        if let failure, rows.isEmpty {
          result(FlutterError(code: "failed", message: "\(failure)", details: nil))
        } else {
          result(rows)
        }
      }
    }
    store.execute(foods)
  }

  /// Every mood logged in the window (State of Mind, from iOS 18): how
  /// pleasant it felt, −1 to 1.
  static func readMoods(from: Date, to: Date, result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *) else {
      result([])
      return
    }
    let query = HKSampleQuery(
      sampleType: HKObjectType.stateOfMindType(),
      predicate: HKQuery.predicateForSamples(withStart: from, end: to),
      limit: HKObjectQueryNoLimit, sortDescriptors: nil
    ) { _, samples, error in
      let rows: [[String: Any]] = (samples ?? []).compactMap { sample in
        guard let mood = sample as? HKStateOfMind, !isOurs(mood) else { return nil }
        return [
          "id": mood.uuid.uuidString, "at": milliseconds(mood.startDate),
          "valence": mood.valence,
        ]
      }
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "failed", message: "\(error)", details: nil))
        } else {
          result(rows)
        }
      }
    }
    store.execute(query)
  }

  /// Everyday movement and the fitness figures measured through the day,
  /// each as the app's metric in the app's stored unit. Counted ones are
  /// summed per hour and measured ones averaged per day by Health's own
  /// statistics, which count a phone and a watch once, by the source
  /// order the user set.
  static let activityTypes:
    [(type: HKQuantityType, metric: String, unit: HKUnit, isCumulative: Bool)] = {
      let bpm = HKUnit.count().unitDivided(by: .minute())
      let metresPerSecond = HKUnit.meter().unitDivided(by: .second())
      var types: [(type: HKQuantityType, metric: String, unit: HKUnit, isCumulative: Bool)] = [
        (HKQuantityType(.stepCount), "steps", .count(), true),
        (HKQuantityType(.distanceWalkingRunning), "distance", .meter(), true),
        (HKQuantityType(.activeEnergyBurned), "activeEnergy", .kilocalorie(), true),
        (HKQuantityType(.basalEnergyBurned), "basalEnergy", .kilocalorie(), true),
        (HKQuantityType(.appleExerciseTime), "exerciseTime", .minute(), true),
        (HKQuantityType(.appleStandTime), "standTime", .minute(), true),
        (HKQuantityType(.appleMoveTime), "moveTime", .minute(), true),
        (HKQuantityType(.flightsClimbed), "floors", .count(), true),
        (HKQuantityType(.heartRate), "heartRate", bpm, false),
        (HKQuantityType(.restingHeartRate), "restingHeartRate", bpm, false),
        (HKQuantityType(.walkingHeartRateAverage), "walkingHeartRate", bpm, false),
        (HKQuantityType(.heartRateVariabilitySDNN), "hrvSdnn", .secondUnit(with: .milli), false),
        (HKQuantityType(.vo2Max), "vo2Max", HKUnit(from: "ml/kg*min"), false),
        (HKQuantityType(.bodyTemperature), "bodyTemperature", .degreeCelsius(), false),
        (
          HKQuantityType(.bloodPressureSystolic), "bloodPressureSystolic",
          .millimeterOfMercury(), false
        ),
        (
          HKQuantityType(.bloodPressureDiastolic), "bloodPressureDiastolic",
          .millimeterOfMercury(), false
        ),
        (HKQuantityType(.respiratoryRate), "respiratoryRate", bpm, false),
        (HKQuantityType(.oxygenSaturation), "oxygenSaturation", .percent(), false),
        (HKQuantityType(.walkingSpeed), "walkingSpeed", metresPerSecond, false),
        (HKQuantityType(.walkingStepLength), "walkingStepLength", .meter(), false),
        (HKQuantityType(.walkingAsymmetryPercentage), "walkingAsymmetry", .percent(), false),
        (HKQuantityType(.walkingDoubleSupportPercentage), "doubleSupport", .percent(), false),
        (HKQuantityType(.appleWalkingSteadiness), "walkingSteadiness", .percent(), false),
        (HKQuantityType(.stairAscentSpeed), "stairAscentSpeed", metresPerSecond, false),
        (HKQuantityType(.stairDescentSpeed), "stairDescentSpeed", metresPerSecond, false),
        (HKQuantityType(.sixMinuteWalkTestDistance), "sixMinuteWalk", .meter(), false),
        (HKQuantityType(.distanceCycling), "cyclingDistance", .meter(), true),
        (HKQuantityType(.distanceSwimming), "swimmingDistance", .meter(), true),
        (HKQuantityType(.swimmingStrokeCount), "swimmingStrokes", .count(), true),
        (HKQuantityType(.pushCount), "wheelchairPushes", .count(), true),
        (HKQuantityType(.distanceWheelchair), "wheelchairDistance", .meter(), true),
      ]
      if #available(iOS 16.0, *) {
        types += [
          (HKQuantityType(.heartRateRecoveryOneMinute), "heartRateRecovery", bpm, false),
          (HKQuantityType(.runningSpeed), "runningSpeed", metresPerSecond, false),
          (HKQuantityType(.runningPower), "runningPower", .watt(), false),
          (HKQuantityType(.runningStrideLength), "runningStrideLength", .meter(), false),
          (
            HKQuantityType(.runningGroundContactTime), "groundContactTime",
            .secondUnit(with: .milli), false
          ),
          (
            HKQuantityType(.runningVerticalOscillation), "verticalOscillation",
            .meterUnit(with: .centi), false
          ),
        ]
      }
      if #available(iOS 17.0, *) {
        types += [
          (HKQuantityType(.cyclingSpeed), "cyclingSpeed", metresPerSecond, false),
          (HKQuantityType(.cyclingPower), "cyclingPower", .watt(), false),
          (HKQuantityType(.cyclingCadence), "cyclingCadence", bpm, false),
          (
            HKQuantityType(.cyclingFunctionalThresholdPower), "functionalThresholdPower",
            .watt(), false
          ),
          (
            HKQuantityType(.physicalEffort), "physicalEffort",
            HKUnit.kilocalorie().unitDivided(
              by: HKUnit.hour().unitMultiplied(by: .gramUnit(with: .kilo))),
            false
          ),
          (HKQuantityType(.timeInDaylight), "timeInDaylight", .minute(), true),
        ]
      }
      if #available(iOS 27.0, *) {
        types.append(
          (
            HKQuantityType(.heartRateVariabilityRMSSD), "hrvRmssd",
            .secondUnit(with: .milli), false
          ))
      }
      return types
    }()

  /// Every activity metric from the start of [from]'s day to [to].
  static func readActivity(from: Date, to: Date, daily: Bool, result: @escaping FlutterResult) {
    let anchor = Calendar.current.startOfDay(for: from)
    let group = DispatchGroup()
    let lock = NSLock()
    var rows: [[String: Any]] = []
    var failure: Error?
    for activity in activityTypes {
      group.enter()
      let isLatest = latestMetrics.contains(activity.metric)
      let query = HKStatisticsCollectionQuery(
        quantityType: activity.type,
        quantitySamplePredicate: HKQuery.predicateForSamples(withStart: anchor, end: to),
        options: activity.isCumulative
          ? .cumulativeSum : isLatest ? .mostRecent : .discreteAverage,
        anchorDate: anchor,
        // Counted ones by the hour, or by the day for years long past.
        intervalComponents: activity.isCumulative && !daily
          ? DateComponents(hour: 1) : DateComponents(day: 1))
      query.initialResultsHandler = { _, collection, error in
        lock.lock()
        if let error { failure = error }
        collection?.enumerateStatistics(from: anchor, to: to) { statistics, _ in
          let quantity =
            activity.isCumulative
            ? statistics.sumQuantity()
            : isLatest ? statistics.mostRecentQuantity() : statistics.averageQuantity()
          guard let quantity else { return }
          rows.append([
            "metric": activity.metric,
            "start": milliseconds(statistics.startDate),
            "end": milliseconds(statistics.endDate),
            "value": quantity.doubleValue(for: activity.unit),
          ])
        }
        lock.unlock()
        group.leave()
      }
      store.execute(query)
    }
    group.enter()
    readMindfulMinutes(from: anchor, to: to, daily: daily) { minutes, error in
      lock.lock()
      if let error { failure = error }
      rows += minutes
      lock.unlock()
      group.leave()
    }
    group.notify(queue: .main) {
      // A type never allowed reads as nothing; only when nothing came
      // back at all is an error the answer.
      if let failure, rows.isEmpty {
        result(FlutterError(code: "failed", message: "\(failure)", details: nil))
      } else {
        result(rows)
      }
    }
  }

  /// Minutes of mindfulness in each hour, or each day for years long
  /// past. A category type has no statistics query, so the sessions are
  /// read and a phone's and a watch's overlapping ones counted once.
  static func readMindfulMinutes(
    from: Date, to: Date, daily: Bool,
    completion: @escaping ([[String: Any]], Error?) -> Void
  ) {
    let query = HKSampleQuery(
      sampleType: HKCategoryType(.mindfulSession),
      predicate: HKQuery.predicateForSamples(withStart: from, end: to),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    ) { _, samples, error in
      var spans: [(start: Date, end: Date)] = []
      for sample in (samples ?? []) where !isOurs(sample) {
        if let last = spans.last, sample.startDate <= last.end {
          spans[spans.count - 1].end = max(last.end, sample.endDate)
        } else {
          spans.append((sample.startDate, sample.endDate))
        }
      }
      let calendar = Calendar.current
      var minutes: [Date: Double] = [:]
      for span in spans {
        var cursor = span.start
        while cursor < span.end {
          let bucket = daily
            ? calendar.startOfDay(for: cursor)
            : calendar.dateInterval(of: .hour, for: cursor)!.start
          let next = daily
            ? calendar.date(byAdding: .day, value: 1, to: bucket)!
            : calendar.date(byAdding: .hour, value: 1, to: bucket)!
          let stop = min(span.end, next)
          minutes[bucket, default: 0] += stop.timeIntervalSince(cursor) / 60
          cursor = stop
        }
      }
      let rows: [[String: Any]] = minutes.map { bucket, value in
        [
          "metric": "mindfulTime",
          "start": milliseconds(bucket),
          "end": milliseconds(
            daily
              ? calendar.date(byAdding: .day, value: 1, to: bucket)!
              : calendar.date(byAdding: .hour, value: 1, to: bucket)!),
          "value": value,
        ]
      }
      completion(rows, error)
    }
    store.execute(query)
  }

  /// Vitals whose day is its last reading, not an average of them
  /// (`ActivityMetric.isLatest`).
  static let latestMetrics: Set<String> = [
    "bodyTemperature", "bloodPressureSystolic", "bloodPressureDiastolic", "oxygenSaturation",
  ]

  static let distanceTypes: [HKQuantityType] = [
    HKQuantityType(.distanceWalkingRunning),
    HKQuantityType(.distanceCycling),
    HKQuantityType(.distanceSwimming),
  ]

  static func read(
    kind: String, type: HKSampleType, from: Date, to: Date, result: @escaping FlutterResult
  ) {
    let query = HKSampleQuery(
      sampleType: type, predicate: HKQuery.predicateForSamples(withStart: from, end: to),
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    ) { _, samples, error in
      // Turned into rows here, on HealthKit's own queue: a month of sleep
      // stages is thousands of samples, and the main thread, which also
      // takes the touches, only needs to hand the rows over.
      let rows = (samples ?? []).filter { !isOurs($0) }.compactMap { row(kind: kind, sample: $0) }
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "failed", message: "\(error)", details: nil))
          return
        }
        result(rows)
      }
    }
    store.execute(query)
  }

  static func milliseconds(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1000) }

  /// Whether this app wrote [sample]: what it wrote is already in its
  /// own records, and reading it back would count it twice.
  static func isOurs(_ sample: HKObject) -> Bool {
    sample.sourceRevision.source.bundleIdentifier == HKSource.default().bundleIdentifier
  }

  static func row(kind: String, sample: HKSample) -> [String: Any]? {
    let id = sample.uuid.uuidString
    switch (kind, sample) {
    case ("sleep", let sample as HKCategorySample):
      guard let (stage, native) = stage(of: sample.value) else { return nil }
      let source = sample.sourceRevision.source
      return [
        "start": milliseconds(sample.startDate), "end": milliseconds(sample.endDate),
        "stage": stage, "native": native,
        "source": source.bundleIdentifier,
        // The watch or ring when Health knows it; the app otherwise.
        "sourceName": sample.device?.name ?? source.name,
        "manual": sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool ?? false,
      ]
    case ("weight", let sample as HKQuantitySample):
      return [
        "id": id, "at": milliseconds(sample.startDate),
        "kg": sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
      ]
    case ("waist", let sample as HKQuantitySample):
      return [
        "id": id, "at": milliseconds(sample.startDate),
        "cm": sample.quantity.doubleValue(for: .meterUnit(with: .centi)),
      ]
    case ("water", let sample as HKQuantitySample):
      return [
        "id": id, "at": milliseconds(sample.startDate),
        "ml": sample.quantity.doubleValue(for: .literUnit(with: .milli)),
      ]
    case ("workouts", let workout as HKWorkout):
      var row: [String: Any] = [
        "id": id, "start": milliseconds(workout.startDate), "end": milliseconds(workout.endDate),
        "activity": activity(of: workout.workoutActivityType),
        "native": "HKWorkoutActivityType.\(workout.workoutActivityType.rawValue)",
      ]
      if let metres = distance(of: workout) {
        row["distance"] = metres
      }
      return row
    default:
      return nil
    }
  }

  static func distance(of workout: HKWorkout) -> Double? {
    if #available(iOS 16.0, *) {
      return distanceTypes.lazy
        .compactMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) }
        .first
    }
    return workout.totalDistance?.doubleValue(for: .meter())
  }

  /// The app's name for a stage, and HealthKit's own. Core is shown
  /// beside Health Connect's light sleep but keeps its name here.
  static func stage(of value: Int) -> (String, String)? {
    switch HKCategoryValueSleepAnalysis(rawValue: value) {
    case .inBed: return ("inBed", "HKCategoryValueSleepAnalysis.inBed")
    case .awake: return ("awake", "HKCategoryValueSleepAnalysis.awake")
    case .asleepUnspecified:
      return ("asleep", "HKCategoryValueSleepAnalysis.asleepUnspecified")
    case .asleepCore: return ("core", "HKCategoryValueSleepAnalysis.asleepCore")
    case .asleepDeep: return ("deep", "HKCategoryValueSleepAnalysis.asleepDeep")
    case .asleepREM: return ("rem", "HKCategoryValueSleepAnalysis.asleepREM")
    default: return nil
    }
  }

  /// What is read over a sleep, the app's name for each, and the unit
  /// the platform reports it in. Heart rate variability is SDNN here;
  /// it is not converted to anything else.
  static var overnightTypes: [(name: String, type: HKQuantityType, unit: HKUnit, scale: Double)] {
    let perMinute = HKUnit.count().unitDivided(by: .minute())
    var types: [(name: String, type: HKQuantityType, unit: HKUnit, scale: Double)] = [
      ("heartRate", HKQuantityType(.heartRate), perMinute, 1),
      ("respiratoryRate", HKQuantityType(.respiratoryRate), perMinute, 1),
      ("oxygenSaturation", HKQuantityType(.oxygenSaturation), .percent(), 100),
      ("hrvSdnn", HKQuantityType(.heartRateVariabilitySDNN), .secondUnit(with: .milli), 1),
    ]
    if #available(iOS 16.0, *) {
      types.append(
        ("wristTemperature", HKQuantityType(.appleSleepingWristTemperature), .degreeCelsius(), 1))
    }
    if #available(iOS 18.0, *) {
      types.append(
        ("breathingDisturbances", HKQuantityType(.appleSleepingBreathingDisturbances), .count(), 1))
    }
    return types
  }

  /// Heart rate and respiratory rate through one night, sample by sample
  /// as [time, value] pairs keyed by measure, for the night's charts.
  /// Read when the night is opened, not stored.
  static func overnightSeries(from: Date, to: Date, result: @escaping FlutterResult) {
    let measures = overnightTypes.filter { ["heartRate", "respiratoryRate"].contains($0.name) }
    let predicate = HKQuery.predicateForSamples(withStart: from, end: to)
    let group = DispatchGroup()
    let lock = NSLock()
    var series: [String: [[Double]]] = [:]
    for measure in measures {
      group.enter()
      let query = HKSampleQuery(
        sampleType: measure.type, predicate: predicate, limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, samples, _ in
        // A measure not allowed or not recorded reads as no samples.
        let points: [[Double]] = (samples ?? []).compactMap { sample in
          guard let sample = sample as? HKQuantitySample,
            sample.quantity.is(compatibleWith: measure.unit)
          else { return nil }
          return [
            Double(milliseconds(sample.startDate)),
            sample.quantity.doubleValue(for: measure.unit) * measure.scale,
          ]
        }
        lock.lock()
        series[measure.name] = points
        lock.unlock()
        group.leave()
      }
      store.execute(query)
    }
    group.notify(queue: .main) { result(series) }
  }

  /// Each measure's range over each window, as rows the Dart side reads:
  /// the window's index, the measure, its minimum, maximum and average,
  /// and how many samples fell in it.
  static func overnight(windows: [DateInterval], result: @escaping FlutterResult) {
    guard !windows.isEmpty else {
      result([])
      return
    }
    let predicate = NSCompoundPredicate(
      orPredicateWithSubpredicates: windows.map {
        HKQuery.predicateForSamples(withStart: $0.start, end: $0.end)
      })
    let group = DispatchGroup()
    let lock = NSLock()
    var rows: [[String: Any]] = []
    for measure in overnightTypes {
      group.enter()
      let query = HKSampleQuery(
        sampleType: measure.type, predicate: predicate, limit: HKObjectQueryNoLimit,
        sortDescriptors: nil
      ) { _, samples, _ in
        // A measure not allowed or not recorded reads as no samples;
        // Health does not say which.
        var values = Array(repeating: [Double](), count: windows.count)
        var elevated = Array(repeating: Bool?.none, count: windows.count)
        for case let sample as HKQuantitySample in samples ?? [] {
          guard sample.quantity.is(compatibleWith: measure.unit),
            let index = windows.firstIndex(where: { $0.contains(sample.startDate) })
          else { continue }
          values[index].append(sample.quantity.doubleValue(for: measure.unit) * measure.scale)
          if #available(iOS 18.0, *), measure.name == "breathingDisturbances",
            let reading = HKAppleSleepingBreathingDisturbancesClassification(
              classifying: sample.quantity)
          {
            elevated[index] = reading == .elevated
          }
        }
        lock.lock()
        for (index, found) in values.enumerated() where !found.isEmpty {
          var row: [String: Any] = [
            "window": index, "measure": measure.name,
            "min": found.min()!, "max": found.max()!,
            "avg": found.reduce(0, +) / Double(found.count), "count": found.count,
          ]
          if let value = elevated[index] {
            row["elevated"] = value
          }
          rows.append(row)
        }
        lock.unlock()
        group.leave()
      }
      store.execute(query)
    }
    group.notify(queue: .main) { result(rows) }
  }

  /// The app's activity type ids; anything else is `other`.
  static func activity(of type: HKWorkoutActivityType) -> String {
    switch type {
    case .running: return "running"
    case .walking: return "walking"
    case .hiking: return "hiking"
    case .cycling: return "cycling"
    case .swimming: return "swimming"
    case .rowing: return "rowing"
    case .elliptical: return "elliptical"
    case .stairClimbing, .stairs: return "stairs"
    case .basketball: return "basketball"
    case .badminton: return "badminton"
    case .yoga: return "yoga"
    default: return "other"
    }
  }
}

/// Reads the text in a photo on the phone, for
/// `lib/backend/ai/label_reader.dart`. Vision runs entirely on device;
/// the photo never leaves it.
///
/// From iOS 26 a nutrition label is read as a document, which keeps the
/// table's rows: every cell of a row comes back on the same line, so
/// 「蛋白質」 cannot drift onto the next row's numbers. Before that, lines
/// come back with their positions and Dart puts the rows back together.
/// Chinese recognition does not support language correction, so it is
/// off.
enum LabelReader {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mishirube/ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognizeText" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterError(code: "badArguments", message: nil, details: nil))
        return
      }
      let url = URL(fileURLWithPath: path)
      Task {
        do {
          let lines = try await read(url, orientation: orientation(of: url))
          await MainActor.run { result(lines) }
        } catch {
          await MainActor.run {
            result(FlutterError(code: "failed", message: "\(error)", details: nil))
          }
        }
      }
    }
  }

  /// The photo's EXIF orientation: a portrait shot is usually stored
  /// sideways with a note saying so.
  static func orientation(of url: URL) -> CGImagePropertyOrientation {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let raw = properties[kCGImagePropertyOrientation] as? UInt32,
      let orientation = CGImagePropertyOrientation(rawValue: raw)
    else { return .up }
    return orientation
  }

  static func read(_ url: URL, orientation: CGImagePropertyOrientation) async throws
    -> [[String: Any]]
  {
    if #available(iOS 26.0, *) {
      let lines = try await readDocument(url, orientation: orientation)
      if !lines.isEmpty { return lines }
    }
    return try await readLines(url, orientation: orientation)
  }

  /// Vision's rects start at the bottom left; Dart's at the top left.
  static func line(_ text: String, _ box: CGRect, top: CGFloat? = nil, height: CGFloat? = nil)
    -> [String: Any]
  {
    [
      "text": text,
      "left": Double(box.minX),
      "top": Double(top ?? (1 - box.maxY)),
      "width": Double(box.width),
      "height": Double(height ?? box.height),
    ]
  }

  @available(iOS 26.0, *)
  static func readDocument(_ url: URL, orientation: CGImagePropertyOrientation) async throws
    -> [[String: Any]]
  {
    var request = RecognizeDocumentsRequest()
    let wanted = [Locale.Language(identifier: "zh-Hant"), Locale.Language(identifier: "en")]
    let supported = request.supportedRecognitionLanguages
    var options = request.textRecognitionOptions
    options.recognitionLanguages = wanted.filter { language in
      supported.contains { $0.isEquivalent(to: language) }
    }
    options.automaticallyDetectLanguage = false
    options.useLanguageCorrection = false
    request.textRecognitionOptions = options

    let observations = try await request.perform(on: url, orientation: orientation)
    guard let document = observations.first?.document else { return [] }

    var lines: [[String: Any]] = []
    var tableAreas: [CGRect] = []
    for table in document.tables {
      tableAreas.append(rect(table.boundingRegion.boundingBox))
      for row in table.rows {
        let boxes = row.map { rect($0.content.text.boundingRegion.boundingBox) }
        // One top and one height for the whole row, so the row stays a row.
        guard let top = boxes.map({ 1 - $0.maxY }).min(),
          let height = boxes.map(\.height).max()
        else { continue }
        for (cell, box) in zip(row, boxes) {
          let text = cell.content.text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
          if !text.isEmpty { lines.append(line(text, box, top: top, height: height)) }
        }
      }
    }
    // The text around the table: 每一份量, 本包裝含, the product's name.
    for observation in document.text.lines {
      let box = rect(observation.boundingBox)
      if tableAreas.contains(where: { $0.contains(CGPoint(x: box.midX, y: box.midY)) }) {
        continue
      }
      if let text = observation.topCandidates(1).first?.string, !text.isEmpty {
        lines.append(line(text, box))
      }
    }
    return lines
  }

  @available(iOS 26.0, *)
  static func rect(_ box: NormalizedRect) -> CGRect {
    CGRect(origin: box.origin, size: CGSize(width: box.width, height: box.height))
  }

  static func readLines(_ url: URL, orientation: CGImagePropertyOrientation) async throws
    -> [[String: Any]]
  {
    try await withCheckedThrowingContinuation { continuation in
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.recognitionLanguages = ["zh-Hant", "en-US"]
      request.usesLanguageCorrection = false
      let handler = VNImageRequestHandler(url: url, orientation: orientation, options: [:])
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try handler.perform([request])
          let observations = request.results ?? []
          continuation.resume(
            returning: observations.compactMap { observation in
              guard let text = observation.topCandidates(1).first?.string else { return nil }
              return line(text, observation.boundingBox)
            })
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}

/// The running workout on a paired Apple Watch (`lib/app/watch_sync.dart`,
/// the app in `MishirubeWatch/`): the phone sends what to show, and the
/// watch asks the phone to log the next set.
final class WatchBridge: NSObject, WCSessionDelegate {
  static let shared = WatchBridge()
  private var channel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mishirube/watch", binaryMessenger: messenger)
    self.channel = channel
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
    channel.setMethodCallHandler { call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // The context holds property-list values only: nulls are left out.
      let state = (call.arguments as? [String: Any] ?? [:]).filter { !($0.value is NSNull) }
      let session = WCSession.default
      if WCSession.isSupported(), session.activationState == .activated, session.isPaired,
        session.isWatchAppInstalled
      {
        try? session.updateApplicationContext(state)
      }
      result(nil)
    }
  }

  func session(
    _ session: WCSession, didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    guard message["action"] as? String == "logNextSet" else { return replyHandler([:]) }
    DispatchQueue.main.async {
      self.channel?.invokeMethod("logNextSet", arguments: nil)
      replyHandler([:])
    }
  }

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

/// A daily reminder before the suggested bedtime (`lib/app/bedtime_reminder.dart`).
/// Permission is asked when it is first turned on.
enum BedtimeReminder {
  static let identifier = "bedtime"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mishirube/bedtime", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "schedule":
        guard let arguments = call.arguments as? [String: Any],
          let hour = arguments["hour"] as? Int, let minute = arguments["minute"] as? Int
        else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        let content = UNMutableNotificationContent()
        content.title = arguments["title"] as? String ?? ""
        content.body = arguments["body"] as? String ?? ""
        content.sound = .default
        var time = DateComponents()
        time.hour = hour
        time.minute = minute
        let request = UNNotificationRequest(
          identifier: identifier, content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true))
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
          guard granted else { return }
          center.removePendingNotificationRequests(withIdentifiers: [identifier])
          center.add(request)
        }
        result(nil)
      case "cancel":
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// The end of the rest between sets as a notification
/// (`lib/app/rest_notice.dart`), so it is heard with the device locked.
/// Permission is asked the first time a rest starts; declining leaves
/// the rest shown in the app only.
enum RestNotice {
  static let identifier = "rest"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/rest_notice", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "schedule":
        guard let arguments = call.arguments as? [String: Any],
          let endsAt = arguments["endsAt"] as? Double
        else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        let content = UNMutableNotificationContent()
        content.title = arguments["endedTitle"] as? String ?? ""
        content.body = arguments["body"] as? String ?? ""
        content.sound = .default
        let seconds = max(1, endsAt / 1000 - Date().timeIntervalSince1970)
        let request = UNNotificationRequest(
          identifier: identifier, content: content,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
          guard granted else { return }
          center.removePendingNotificationRequests(withIdentifiers: [identifier])
          center.add(request)
        }
        if #available(iOS 16.2, *) {
          showActivity(
            endsAt: Date(timeIntervalSince1970: endsAt / 1000),
            title: arguments["restingTitle"] as? String ?? "",
            body: content.body)
        }
        result(nil)
      case "cancel":
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        if #available(iOS 16.2, *) { endActivities() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

@available(iOS 16.2, *)
extension RestNotice {
  /// The rest on the lock screen and in the Dynamic Island, counting
  /// down: one activity, updated when the rest is lengthened.
  static func showActivity(endsAt: Date, title: String, body: String) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let state = RestAttributes.ContentState(
      endsAt: endsAt, startedAt: Date(), title: title, body: body)
    // Over the caffeine activity (`CaffeineActivity.relevance`) in the
    // Dynamic Island: the rest is what the workout is waiting on.
    let content = ActivityContent(state: state, staleDate: endsAt, relevanceScore: 100)
    if let running = Activity<RestAttributes>.activities.first {
      Task { await running.update(content) }
    } else {
      _ = try? Activity.request(attributes: RestAttributes(), content: content)
    }
  }

  static func endActivities() {
    for activity in Activity<RestAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}

/// Caffeine over the bedtime reference on the lock screen and in the
/// Dynamic Island (`lib/app/caffeine_activity.dart`), with the time it
/// falls under it: one activity, moved by another cup.
enum CaffeineActivity {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/caffeine_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.2, *) else {
        result(nil)
        return
      }
      switch call.method {
      case "show":
        guard let arguments = call.arguments as? [String: Any],
          let state = contentState(from: arguments)
        else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        result(show(state))
      case "end":
        end()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

@available(iOS 16.2, *)
extension CaffeineActivity {
  /// Under the rest timer (`RestNotice`) when both run: the Dynamic Island
  /// shows the app's activity that scores higher.
  static let relevance = 10.0

  static func contentState(from arguments: [String: Any]) -> CaffeineAttributes.ContentState? {
    func date(_ key: String) -> Date? {
      (arguments[key] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
    }
    func text(_ key: String) -> String { arguments[key] as? String ?? "" }
    guard let cupAt = date("cupAt"), let belowAt = date("belowAt"), cupAt < belowAt else {
      return nil
    }
    return CaffeineAttributes.ContentState(
      cupAt: cupAt, belowAt: belowAt, bedtimeAt: date("bedtimeAt"),
      title: text("title"), cup: text("cup"), cupTime: text("cupTime"),
      belowLabel: text("belowLabel"), belowDoneLabel: text("belowDoneLabel"),
      belowTime: text("belowTime"), bedtime: arguments["bedtime"] as? String,
      basis: text("basis"))
  }

  /// How long the system lets a Live Activity run before it ends it.
  static let systemLimit: TimeInterval = 8 * 60 * 60

  /// The cup the running activity is for, and when it was started.
  private static let cupKey = "caffeineActivity.cupAt"
  private static let startedKey = "caffeineActivity.startedAt"

  /// Shows `state`, and whether the system now does: not one swiped
  /// away, nor with Live Activities turned off in Settings.
  static func show(_ state: CaffeineAttributes.ContentState) -> Bool {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
    let content = ActivityContent(
      state: state, staleDate: state.belowAt, relevanceScore: relevance)
    let defaults = UserDefaults.standard
    let activities = Activity<CaffeineAttributes>.activities
    if let running = activities.first(where: {
      $0.activityState == .active || $0.activityState == .stale
    }) {
      Task { await running.update(content) }
      defaults.set(state.cupAt, forKey: cupKey)
      return true
    }
    // Gone before the system's limit for the cup it was started for: it
    // was swiped away, and stays away until a later cup. Gone after the
    // limit, a new one takes its place on the lock screen.
    if let cupAt = defaults.object(forKey: cupKey) as? Date,
      abs(cupAt.timeIntervalSince(state.cupAt)) < 1,
      let startedAt = defaults.object(forKey: startedKey) as? Date,
      Date().timeIntervalSince(startedAt) < systemLimit
    {
      return false
    }
    endAll()
    guard (try? Activity.request(attributes: CaffeineAttributes(), content: content)) != nil
    else { return false }
    defaults.set(state.cupAt, forKey: cupKey)
    defaults.set(Date(), forKey: startedKey)
    return true
  }

  /// Ended by the app: under the reference, or turned off. What it was
  /// started for is forgotten, so turning it on again shows it.
  static func end() {
    endAll()
    UserDefaults.standard.removeObject(forKey: cupKey)
    UserDefaults.standard.removeObject(forKey: startedKey)
  }

  static func endAll() {
    for activity in Activity<CaffeineAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}

/// Keeps the screen on while a workout page is open
/// (`lib/shared/screen_awake.dart`): the set being logged should still be
/// there between sets.
enum ScreenAwake {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/screen_awake", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "keepOn", let isOn = call.arguments as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIApplication.shared.isIdleTimerDisabled = isOn
      result(nil)
    }
  }
}

/// The app's own version, for 我的 > 關於 (`lib/shared/app_info.dart`).
enum AppInfo {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/app_info", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "version" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let info = Bundle.main.infoDictionary
      result([
        "version": info?["CFBundleShortVersionString"] as? String ?? "",
        "build": info?["CFBundleVersion"] as? String ?? "",
      ])
    }
  }
}

/// How the user's calendar is set up (`lib/shared/system_calendar.dart`):
/// the day a week starts on, as Settings has it.
enum SystemCalendar {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/system_calendar", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "firstWeekday" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // 1 is Sunday, as Foundation counts.
      result(Calendar.autoupdatingCurrent.firstWeekday)
    }
  }
}

/// The newest photo in the library, as a small JPEG for the camera's
/// library button (`lib/shared/photo_library.dart`). Read only once the
/// user allows it; with limited access it is the newest of the photos
/// they chose. Nothing is sent anywhere.
enum PhotoLibrary {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/photo_library", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "latestThumbnail" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let pixels = (call.arguments as? [String: Any])?["pixels"] as? Double ?? 160
      latestThumbnail(pixels: CGFloat(pixels), result: result)
    }
  }

  static func latestThumbnail(pixels: CGFloat, result: @escaping FlutterResult) {
    func fetch() {
      let options = PHFetchOptions()
      options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      options.fetchLimit = 1
      guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else {
        result(nil)
        return
      }
      let request = PHImageRequestOptions()
      // One callback, the finished image: no blurry first pass.
      request.deliveryMode = .highQualityFormat
      request.resizeMode = .fast
      request.isNetworkAccessAllowed = true
      PHImageManager.default().requestImage(
        for: asset, targetSize: CGSize(width: pixels, height: pixels),
        contentMode: .aspectFill, options: request
      ) { image, _ in
        let data = image?.jpegData(compressionQuality: 0.8)
        DispatchQueue.main.async {
          result(data.map { FlutterStandardTypedData(bytes: $0) })
        }
      }
    }
    switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
    case .authorized, .limited:
      fetch()
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        DispatchQueue.main.async {
          if status == .authorized || status == .limited { fetch() } else { result(nil) }
        }
      }
    default:
      result(nil)
    }
  }
}

/// What the user logs in the app, written to Apple Health, for
/// `HealthSource.write` in `lib/backend/health/health_source.dart`.
///
/// Every sample carries the app's own id as its sync identifier and the
/// time the record last changed as its version, so Health replaces what
/// it holds when a record is written again after an edit, and a deleted
/// record is found by the same id. A type the user did not allow writing
/// is passed over rather than failing the rest.
enum HealthKitWriter {
  static var store: HKHealthStore { HealthKitBridge.store }

  /// What each kind asks to write, by the kinds the app reads.
  static func shareTypes(for kinds: [String]) -> Set<HKSampleType> {
    var types = Set<HKSampleType>()
    for kind in kinds {
      switch kind {
      case "weight": types.insert(HKQuantityType(.bodyMass))
      case "waist": types.insert(HKQuantityType(.waistCircumference))
      case "body": types.formUnion(bodyTypes.values.map(\.type))
      case "sleep": types.insert(HKCategoryType(.sleepAnalysis))
      case "workouts": types.insert(HKWorkoutType.workoutType())
      case "water": types.insert(HKQuantityType(.dietaryWater))
      case "nutrition": types.formUnion(HealthKitBridge.dietaryTypes.map(\.type))
      case "mood":
        if #available(iOS 18.0, *) { types.insert(HKObjectType.stateOfMindType()) }
      default: break
      }
    }
    return types
  }

  /// The body figures Health has a type for, in the app's unit: body fat
  /// is a percentage here and a fraction there.
  static let bodyTypes: [String: (type: HKQuantityType, unit: HKUnit, scale: Double)] = [
    "height": (HKQuantityType(.height), .meterUnit(with: .centi), 1),
    "bodyFat": (HKQuantityType(.bodyFatPercentage), .percent(), 0.01),
    "leanMass": (HKQuantityType(.leanBodyMass), .gramUnit(with: .kilo), 1),
  ]

  static func canWrite(_ type: HKObjectType) -> Bool {
    store.authorizationStatus(for: type) == .sharingAuthorized
  }

  static func write(_ writes: [[String: Any]]) async throws {
    var saves: [HKObject] = []
    var deletes: [HKObjectType: [String]] = [:]
    var workouts: [(HKWorkoutActivityType, Date, Date, [String: Any])] = []

    for write in writes {
      guard let kind = write["kind"] as? String, let id = write["id"] as? String,
        let version = write["version"] as? Int
      else { continue }
      let isDelete = write["delete"] as? Bool ?? false
      func date(_ key: String) -> Date? {
        (write[key] as? Int).map { Date(timeIntervalSince1970: Double($0) / 1000) }
      }
      func number(_ key: String) -> Double? { (write[key] as? NSNumber)?.doubleValue }
      func metadata(_ syncId: String = id) -> [String: Any] {
        [
          HKMetadataKeySyncIdentifier: syncId,
          HKMetadataKeySyncVersion: version,
          HKMetadataKeyWasUserEntered: true,
        ]
      }
      func remove(_ type: HKObjectType, _ syncIds: [String] = [id]) {
        if canWrite(type) { deletes[type, default: []].append(contentsOf: syncIds) }
      }
      func quantity(_ type: HKQuantityType, _ value: Double?, _ unit: HKUnit, at: Date?) {
        guard canWrite(type), let value, let at else { return }
        saves.append(
          HKQuantitySample(
            type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
            start: at, end: at, metadata: metadata()))
      }

      switch kind {
      case "weight":
        let type = HKQuantityType(.bodyMass)
        if isDelete { remove(type) } else {
          quantity(type, number("kg"), .gramUnit(with: .kilo), at: date("at"))
        }
      case "waist":
        let type = HKQuantityType(.waistCircumference)
        if isDelete { remove(type) } else {
          quantity(type, number("cm"), .meterUnit(with: .centi), at: date("at"))
        }
      case "body":
        if isDelete {
          for body in bodyTypes.values { remove(body.type) }
        } else if let metric = write["metric"] as? String, let body = bodyTypes[metric] {
          quantity(body.type, number("value").map { $0 * body.scale }, body.unit, at: date("at"))
        }
      case "sleep":
        let type = HKCategoryType(.sleepAnalysis)
        if isDelete {
          remove(type)
        } else if canWrite(type), let start = date("start"), let end = date("end"), end > start {
          let asleep: HKCategoryValueSleepAnalysis
          if #available(iOS 16.0, *) { asleep = .asleepUnspecified } else { asleep = .asleep }
          let value = write["measure"] as? String == "inBed" ? .inBed : asleep
          saves.append(
            HKCategorySample(
              type: type, value: value.rawValue, start: start, end: end, metadata: metadata()))
        }
      case "water":
        let type = HKQuantityType(.dietaryWater)
        if isDelete { remove(type) } else {
          quantity(type, number("ml"), .literUnit(with: .milli), at: date("at"))
        }
      case "food":
        // One sample per figure, each under the meal's id and the figure's
        // name; a figure the meal no longer has is removed.
        let nutrients = write["nutrients"] as? [String: Any] ?? [:]
        for dietary in HealthKitBridge.dietaryTypes {
          let syncId = "\(id)/\(dietary.field)"
          let value =
            HealthKitBridge.mealFields.contains(dietary.field)
            ? number(dietary.field) : (nutrients[dietary.field] as? NSNumber)?.doubleValue
          guard !isDelete, let value, canWrite(dietary.type), let at = date("at") else {
            remove(dietary.type, [syncId])
            continue
          }
          var meta = metadata(syncId)
          if let name = write["name"] as? String { meta[HKMetadataKeyFoodType] = name }
          saves.append(
            HKQuantitySample(
              type: dietary.type, quantity: HKQuantity(unit: dietary.unit, doubleValue: value),
              start: at, end: at, metadata: meta))
        }
      case "mood":
        guard #available(iOS 18.0, *) else { continue }
        let type = HKObjectType.stateOfMindType()
        if isDelete {
          remove(type)
        } else if canWrite(type), let at = date("at"), let valence = number("valence") {
          saves.append(
            HKStateOfMind(
              date: at, kind: .momentaryEmotion, valence: valence, labels: [],
              associations: [], metadata: metadata()))
        }
      case "workout":
        let type = HKWorkoutType.workoutType()
        if isDelete {
          remove(type)
        } else if canWrite(type), let start = date("start"), let end = date("end"), end > start {
          workouts.append((activityType(of: write["activity"] as? String), start, end, metadata()))
        }
      default:
        continue
      }
    }

    for (type, syncIds) in deletes {
      _ = try await store.deleteObjects(
        of: type,
        predicate: HKQuery.predicateForObjects(
          withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: syncIds))
    }
    if !saves.isEmpty {
      try await store.save(saves)
    }
    for (activity, start, end, metadata) in workouts {
      let configuration = HKWorkoutConfiguration()
      configuration.activityType = activity
      let builder = HKWorkoutBuilder(
        healthStore: store, configuration: configuration, device: .local())
      try await builder.beginCollection(at: start)
      try await builder.addMetadata(metadata)
      try await builder.endCollection(at: end)
      _ = try await builder.finishWorkout()
    }
  }

  /// Health's type for one of the app's activity ids; the other way from
  /// `HealthKitBridge.activity(of:)`.
  static func activityType(of activity: String?) -> HKWorkoutActivityType {
    switch activity {
    case "strength": return .traditionalStrengthTraining
    case "running": return .running
    case "walking": return .walking
    case "hiking": return .hiking
    case "cycling": return .cycling
    case "swimming": return .swimming
    case "rowing": return .rowing
    case "elliptical": return .elliptical
    case "stairs": return .stairClimbing
    case "basketball": return .basketball
    case "badminton": return .badminton
    case "yoga": return .yoga
    default: return .other
    }
  }
}
