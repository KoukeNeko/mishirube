import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// The storyboard's Flutter view controller, measuring the window controls
/// on every layout pass: moving between full screen and a window resizes
/// the view, which lays it out again.
class RunnerViewController: FlutterViewController {
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    WindowControls.measure(in: view)
  }
}

/// How far into the top bar a windowed iPad app's window controls (the
/// close, minimise and tile buttons in the top-leading corner) reach, for
/// `lib/shared/window_controls.dart`.
///
/// UIKit bars move their leading buttons clear of them; a Flutter view is
/// one surface to UIKit, and the controls are not part of the safe area
/// Flutter sees, so this measures what UIKit would have moved them by: the
/// corner-adapted margin past the plain one. It is 0 in full screen, on
/// iPhone and before iPadOS 26.
enum WindowControls {
  private static var channel: FlutterMethodChannel?
  private static var leadingInset = 0.0

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "mishirube/window_controls", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "leadingInset":
        result(leadingInset)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  static func measure(in view: UIView) {
    var inset = 0.0
    if #available(iOS 26.0, *) {
      let plain = view.directionalEdgeInsets(for: .margins())
      let adapted = view.directionalEdgeInsets(for: .margins(cornerAdaptation: .horizontal))
      inset = max(0, Double(adapted.leading - plain.leading))
    }
    guard inset != leadingInset else { return }
    leadingInset = inset
    channel?.invokeMethod("leadingInsetChanged", arguments: inset)
  }
}
