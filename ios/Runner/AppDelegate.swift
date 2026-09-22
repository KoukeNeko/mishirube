import Flutter
import HealthKit
import ImageIO
import UIKit
import Vision

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
          } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .rateLimited, .concurrentRequests:
              result(FlutterError(code: "rateLimited", message: "\(error)", details: nil))
            case .assetsUnavailable:
              result(FlutterError(code: "unavailable", message: "\(error)", details: nil))
            default:
              result(FlutterError(code: "failed", message: "\(error)", details: nil))
            }
          } catch {
            result(FlutterError(code: "failed", message: "\(error)", details: nil))
          }
        }
        return
      }
    #endif
    result(FlutterError(code: "unavailable", message: nil, details: nil))
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
          } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .rateLimited, .concurrentRequests:
              result(FlutterError(code: "rateLimited", message: "\(error)", details: nil))
            case .assetsUnavailable:
              result(FlutterError(code: "unavailable", message: "\(error)", details: nil))
            default:
              result(FlutterError(code: "failed", message: "\(error)", details: nil))
            }
          } catch {
            result(FlutterError(code: "failed", message: "\(error)", details: nil))
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
        store.requestAuthorization(toShare: [], read: types) { success, error in
          DispatchQueue.main.async {
            if let error {
              result(FlutterError(code: "failed", message: "\(error)", details: nil))
            } else {
              result(success)
            }
          }
        }
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
      default:
        result(FlutterMethodNotImplemented)
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
      guard let stage = stage(of: sample.value) else { return nil }
      return [
        "start": milliseconds(sample.startDate), "end": milliseconds(sample.endDate),
        "stage": stage,
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

  /// The three stages the app keeps; core, deep and REM are all asleep.
  static func stage(of value: Int) -> String? {
    switch HKCategoryValueSleepAnalysis(rawValue: value) {
    case .inBed: return "inBed"
    case .awake: return "awake"
    case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return "asleep"
    default: return nil
    }
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
