import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // The app draws its own top bar: no title, and a see-through title bar
    // with the window controls over the app. Behind them is the app's
    // background (`AppColors.background`) rather than a light flash while
    // the first frame is drawn.
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    backgroundColor = NSColor(red: 0x0F / 255, green: 0x11 / 255, blue: 0x10 / 255, alpha: 1)

    RegisterGeneratedPlugins(registry: flutterViewController)
    WindowControls.register(
      with: flutterViewController.engine.binaryMessenger, window: self)

    super.awakeFromNib()
  }
}

/// How tall the see-through title bar is, for
/// `lib/shared/window_controls.dart`, which keeps the app's pages below it
/// as it would below a status bar. It is 0 in full screen, where the title
/// bar hides.
enum WindowControls {
  private static var channel: FlutterMethodChannel?
  private static weak var window: NSWindow?
  private static var topInset = 0.0

  static func register(with messenger: FlutterBinaryMessenger, window: NSWindow) {
    let channel = FlutterMethodChannel(
      name: "mishirube/window_controls", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "topInset":
        result(topInset)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
    self.window = window
    topInset = measure(window)
    for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification]
    {
      NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) {
        _ in update()
      }
    }
  }

  private static func measure(_ window: NSWindow) -> Double {
    if window.styleMask.contains(.fullScreen) { return 0 }
    return Double(window.frame.height - window.contentLayoutRect.height)
  }

  private static func update() {
    guard let window else { return }
    let inset = measure(window)
    guard inset != topInset else { return }
    topInset = inset
    channel?.invokeMethod("topInsetChanged", arguments: inset)
  }
}
