import Flutter
import UIKit

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
}

#if canImport(FoundationModels)
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
