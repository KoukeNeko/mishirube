// Shared by the iOS and macOS runners: the macOS project references
// this file where it lies.
#if os(macOS)
  import FlutterMacOS
#else
  import Flutter
#endif
import Foundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

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
      if #available(iOS 26.0, macOS 26.0, *) {
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
      if #available(iOS 26.0, macOS 26.0, *) {
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
    // Vision arrived with the iOS/macOS 27 SDK (Swift 6.4); an older
    // Xcode builds without it.
    #if canImport(FoundationModels) && compiler(>=6.4)
      if #available(iOS 27.0, macOS 27.0, *) {
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
    // Vision arrived with the iOS/macOS 27 SDK (Swift 6.4); an older
    // Xcode builds without it.
    #if canImport(FoundationModels) && compiler(>=6.4)
      if #available(iOS 27.0, macOS 27.0, *) {
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
      if #available(iOS 26.0, macOS 26.0, *),
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
      if #available(iOS 26.0, macOS 26.0, *) {
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
  @available(iOS 26.0, macOS 26.0, *)
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

  @available(iOS 26.0, macOS 26.0, *)
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

  @available(iOS 26.0, macOS 26.0, *)
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
