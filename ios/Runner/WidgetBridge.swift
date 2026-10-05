import Flutter
import UIKit
import WidgetKit

/// Hands the home-screen widgets what they draw, and brings a tap on one
/// back as a link. `lib/app/home_widgets.dart` works the figures out and
/// sends them here as JSON; they are kept in the app group's shared
/// defaults, where the widget extension (`ios/RestActivity/`) reads them
/// whenever the system draws a widget, with the app closed.
final class WidgetBridge: NSObject, FlutterSceneLifeCycleDelegate {
  static let shared = WidgetBridge()

  private static let group = "group.dev.koukeneko.mishirube"
  private static let key = "widgetSnapshot"
  private static let scheme = "mishirube"

  private var channel: FlutterMethodChannel?

  /// A link that arrived before the app could act on it: the tap that
  /// started the app. Dart asks for it once it is up.
  private var pendingLink: String?

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "mishirube/widgets", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "update":
        guard let json = call.arguments as? String else {
          result(FlutterError(code: "bad-arguments", message: "A snapshot is JSON.", details: nil))
          return
        }
        UserDefaults(suiteName: Self.group)?.set(json, forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      case "takeLaunchLink":
        result(self?.pendingLink)
        self?.pendingLink = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    registrar.addSceneDelegate(self)
  }

  private func open(_ url: URL) {
    guard url.scheme == Self.scheme else { return }
    let link = url.absoluteString
    pendingLink = link
    // Acted on when the app is already up; kept for `takeLaunchLink`
    // when it is not.
    channel?.invokeMethod("open", arguments: link) { [weak self] reply in
      if !(reply is FlutterError), !(reply is NSObject && "\(reply)" == "FlutterMethodNotImplemented") {
        self?.pendingLink = nil
      }
    }
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let url = connectionOptions?.urlContexts.first?.url { open(url) }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = URLContexts.first?.url, url.scheme == Self.scheme else { return false }
    open(url)
    return true
  }
}
