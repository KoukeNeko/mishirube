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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScreenAwake") {
      ScreenAwake.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WindowControls") {
      WindowControls.register(with: registrar.messenger())
    }
  }
}

/// Apple's on-device model for `lib/backend/ai/apple_meal_drafter.dart`.
///
/// Two calls: whether the model can run, and a meal draft from a
/// sentence. The draft's shape is enforced here by guided generation and
/// handed back as the same JSON every provider returns, so Dart reads
/// one format.
enum AppleIntelligence {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/apple_intelligence", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "availability":
        result(availability())
      case "draftMeal":
        guard let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          let instructions = arguments["instructions"] as? String
        else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        draftMeal(text: text, instructions: instructions, result: result)
      case "draftFoodLabel":
        guard let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          let instructions = arguments["instructions"] as? String
        else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        draftFoodLabel(text: text, instructions: instructions, result: result)
      case "readsPhotos":
        result(readsPhotos())
      case "draftMealPhoto":
        guard let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          let instructions = arguments["instructions"] as? String,
          let path = arguments["path"] as? String
        else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        draftMealPhoto(
          path: path, text: text, instructions: instructions, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func availability() -> String {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        switch SystemLanguageModel.default.availability {
        case .available:
          return "available"
        case .unavailable(.deviceNotEligible):
          return "deviceNotEligible"
        case .unavailable(.appleIntelligenceNotEnabled):
          return "appleIntelligenceNotEnabled"
        case .unavailable(.modelNotReady):
          return "modelNotReady"
        case .unavailable:
          return "unavailable"
        }
      }
    #endif
    return "unavailable"
  }

  static func draftMeal(
    text: String, instructions: String, result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        Task { @MainActor in
          do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
              to: text, generating: MealDraftOutput.self)
            result(try response.content.json())
          } catch {
            report(error, to: result)
          }
        }
        return
      }
    #endif
    result(FlutterError(code: "unavailable", message: nil, details: nil))
  }

  /// Whether the on-device model can look at a photo: from iOS 27, on a
  /// device whose model has vision.
  static func readsPhotos() -> Bool {
    #if canImport(FoundationModels)
      if #available(iOS 27.0, *) {
        let model = SystemLanguageModel.default
        return model.isAvailable && model.capabilities.contains(.vision)
      }
    #endif
    return false
  }

  /// A food photo, read on the device, into items with estimated figures.
  /// The photo is never sent anywhere.
  static func draftMealPhoto(
    path: String, text: String, instructions: String, result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
      if #available(iOS 27.0, *) {
        Task { @MainActor in
          do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(generating: MealPhotoOutput.self) {
              text
              Attachment(imageURL: URL(fileURLWithPath: path))
            }
            result(try response.content.json())
          } catch {
            report(error, to: result)
          }
        }
        return
      }
    #endif
    result(FlutterError(code: "unsupported", message: nil, details: nil))
  }

  /// A generation's failure, in the codes the Dart side reads.
  static func report(_ error: Error, to result: @escaping FlutterResult) {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *),
        let error = error as? LanguageModelSession.GenerationError
      {
        switch error {
        case .rateLimited, .concurrentRequests:
          result(FlutterError(code: "rateLimited", message: "\(error)", details: nil))
        case .assetsUnavailable:
          result(FlutterError(code: "unavailable", message: "\(error)", details: nil))
        default:
          result(FlutterError(code: "failed", message: "\(error)", details: nil))
        }
        return
      }
    #endif
    result(FlutterError(code: "failed", message: "\(error)", details: nil))
  }

  /// A label's text, already read on the phone, into the food form's
  /// fields. Greedy sampling: this is copying numbers, not writing.
  static func draftFoodLabel(
    text: String, instructions: String, result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        Task { @MainActor in
          do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
              to: text, generating: FoodLabelOutput.self,
              options: GenerationOptions(sampling: .greedy))
            result(try response.content.json())
          } catch {
            report(error, to: result)
          }
        }
        return
      }
    #endif
    result(FlutterError(code: "unavailable", message: nil, details: nil))
  }
}

#if canImport(FoundationModels)
  /// One serving's figures off a Taiwanese nutrition label. Every field
  /// may be empty: a blank asks the user to look, a guess does not.
  @available(iOS 26.0, *)
  @Generable
  struct FoodLabelOutput {
    @Guide(description: "品名；標示上沒有就留空")
    var name: String?
    @Guide(description: "品牌；標示上沒有就留空")
    var brand: String?
    @Guide(description: "每一份量的數字")
    var servingAmount: Double?
    @Guide(description: "每一份量的單位：g 或 ml")
    var servingUnit: String?
    @Guide(description: "「每份」那一欄的熱量，單位大卡")
    var kcal: Double?
    @Guide(description: "「每100公克或毫升」那一欄的熱量，只用來核對；沒有那一欄就留空")
    var kcalPer100: Double?
    @Guide(description: "「每份」那一欄的蛋白質，公克")
    var proteinGrams: Double?
    @Guide(description: "「每份」那一欄的脂肪，公克")
    var fatGrams: Double?
    @Guide(description: "「每份」那一欄的飽和脂肪，公克")
    var saturatedFatGrams: Double?
    @Guide(description: "「每份」那一欄的反式脂肪，公克")
    var transFatGrams: Double?
    @Guide(description: "「每份」那一欄的碳水化合物，公克")
    var carbGrams: Double?
    @Guide(description: "「每份」那一欄的糖，公克")
    var sugarGrams: Double?
    @Guide(description: "「每份」那一欄的鈉，毫克")
    var sodiumMilligrams: Double?
    @Guide(description: "「每份」那一欄的膳食纖維，公克；沒有就留空")
    var fibreGrams: Double?
    @Guide(description: "每份的咖啡因，毫克；沒有就留空")
    var caffeineMilligrams: Double?

    /// The JSON `parseFoodLabel` reads, with the keys every provider uses.
    func json() throws -> String {
      func value(_ number: Double?) -> Any { number as Any? ?? NSNull() }
      func value(_ text: String?) -> Any { text as Any? ?? NSNull() }
      let fields: [String: Any] = [
        "name": value(name), "brand": value(brand),
        "serving_amount": value(servingAmount), "serving_unit": value(servingUnit),
        "kcal": value(kcal), "kcal_per_100": value(kcalPer100),
        "protein_g": value(proteinGrams), "fat_g": value(fatGrams),
        "saturated_fat_g": value(saturatedFatGrams), "trans_fat_g": value(transFatGrams),
        "carb_g": value(carbGrams), "sugar_g": value(sugarGrams),
        "sodium_mg": value(sodiumMilligrams), "fibre_g": value(fibreGrams),
        "caffeine_mg": value(caffeineMilligrams),
      ]
      let data = try JSONSerialization.data(withJSONObject: fields)
      return String(decoding: data, as: UTF8.self)
    }
  }

  @available(iOS 26.0, *)
  @Generable
  struct MealDraftOutput {
    @Guide(description: "使用者提到的每一項食物或飲料")
    var items: [Item]

    @Generable
    struct Item {
      @Guide(description: "品名，用使用者的說法，繁體中文")
      var name: String
      @Guide(description: "份量，照使用者說的；沒說就寫「一份」")
      var amount: String
      @Guide(description: "這個份量的熱量估計，單位大卡；不確定就留空")
      var kcal: Int?
      @Guide(description: "蛋白質估計，單位公克；不確定就留空")
      var proteinGrams: Int?
      @Guide(description: "碳水化合物估計，單位公克；不確定就留空")
      var carbGrams: Int?
      @Guide(description: "脂肪估計，單位公克；不確定就留空")
      var fatGrams: Int?
      @Guide(description: "是飲料就是 true")
      var isDrink: Bool
    }

    /// The JSON `parseMealDraft` reads, with the keys every provider uses.
    func json() throws -> String {
      let list: [[String: Any]] = items.map { item in
        [
          "name": item.name,
          "amount": item.amount,
          "kcal": item.kcal as Any? ?? NSNull(),
          "protein_g": item.proteinGrams as Any? ?? NSNull(),
          "carb_g": item.carbGrams as Any? ?? NSNull(),
          "fat_g": item.fatGrams as Any? ?? NSNull(),
          "is_drink": item.isDrink,
        ]
      }
      let data = try JSONSerialization.data(withJSONObject: ["items": list])
      return String(decoding: data, as: UTF8.self)
    }
  }

  @available(iOS 26.0, *)
  @Generable
  struct MealPhotoOutput {
    @Guide(description: "照片裡看得到的每一項食物或飲料；沒有食物就是空的")
    var items: [Item]
    @Guide(description: "照片看不出來、但會影響數字的油、醬汁或糖，一句一件事，最多三句")
    var notes: [String]

    @Generable
    struct Item {
      @Guide(description: "品名，台灣常用的說法，繁體中文")
      var name: String
      @Guide(description: "估計的重量或容量與範圍，例如「約 180 g（150–220 g）」")
      var amount: String
      @Guide(description: "這個份量的熱量估計，單位大卡；不確定就留空")
      var kcal: Int?
      @Guide(description: "蛋白質估計，單位公克；不確定就留空")
      var proteinGrams: Int?
      @Guide(description: "碳水化合物估計，單位公克；不確定就留空")
      var carbGrams: Int?
      @Guide(description: "脂肪估計，單位公克；不確定就留空")
      var fatGrams: Int?
      @Guide(description: "是飲料就是 true")
      var isDrink: Bool
    }

    /// The JSON `parseMealPhoto` reads, with the keys every provider uses.
    func json() throws -> String {
      let list: [[String: Any]] = items.map { item in
        [
          "name": item.name,
          "amount": item.amount,
          "kcal": item.kcal as Any? ?? NSNull(),
          "protein_g": item.proteinGrams as Any? ?? NSNull(),
          "carb_g": item.carbGrams as Any? ?? NSNull(),
          "fat_g": item.fatGrams as Any? ?? NSNull(),
          "is_drink": item.isDrink,
        ]
      }
      let data = try JSONSerialization.data(
        withJSONObject: ["items": list, "notes": notes])
      return String(decoding: data, as: UTF8.self)
    }
  }
#endif

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
        }
        if kinds.contains("overnight") {
          types.formUnion(overnightTypes.map(\.type))
        }
        if kinds.contains("body") {
          types.formUnion(bodyTypes.map(\.type))
        }
        if kinds.contains("activity") {
          types.formUnion(activityTypes.map(\.type))
        }
        store.requestAuthorization(toShare: [], read: types) { success, error in
          DispatchQueue.main.async {
            if let error {
              result(FlutterError(code: "failed", message: "\(error)", details: nil))
            } else {
              result(success)
            }
          }
        }
      case "read" where arguments["kind"] as? String == "activity":
        guard let from = arguments["from"] as? Int, let to = arguments["to"] as? Int else {
          result(FlutterError(code: "badArguments", message: nil, details: nil))
          return
        }
        readActivity(
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
        for case let sample as HKQuantitySample in samples ?? [] {
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
        (HKQuantityType(.flightsClimbed), "floors", .count(), true),
        (HKQuantityType(.heartRate), "heartRate", bpm, false),
        (HKQuantityType(.restingHeartRate), "restingHeartRate", bpm, false),
        (HKQuantityType(.walkingHeartRateAverage), "walkingHeartRate", bpm, false),
        (HKQuantityType(.heartRateVariabilitySDNN), "hrvSdnn", .secondUnit(with: .milli), false),
        (HKQuantityType(.vo2Max), "vo2Max", HKUnit(from: "ml/kg*min"), false),
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
  static func readActivity(from: Date, to: Date, result: @escaping FlutterResult) {
    let anchor = Calendar.current.startOfDay(for: from)
    let group = DispatchGroup()
    let lock = NSLock()
    var rows: [[String: Any]] = []
    var failure: Error?
    for activity in activityTypes {
      group.enter()
      let query = HKStatisticsCollectionQuery(
        quantityType: activity.type,
        quantitySamplePredicate: HKQuery.predicateForSamples(withStart: anchor, end: to),
        options: activity.isCumulative ? .cumulativeSum : .discreteAverage,
        anchorDate: anchor,
        intervalComponents: activity.isCumulative ? DateComponents(hour: 1) : DateComponents(day: 1))
      query.initialResultsHandler = { _, collection, error in
        lock.lock()
        if let error { failure = error }
        collection?.enumerateStatistics(from: anchor, to: to) { statistics, _ in
          let quantity =
            activity.isCumulative ? statistics.sumQuantity() : statistics.averageQuantity()
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
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "failed", message: "\(error)", details: nil))
          return
        }
        result((samples ?? []).compactMap { row(kind: kind, sample: $0) })
      }
    }
    store.execute(query)
  }

  static func milliseconds(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1000) }

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
    let content = ActivityContent(state: state, staleDate: endsAt)
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
