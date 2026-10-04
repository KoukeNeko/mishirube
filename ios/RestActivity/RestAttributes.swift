import ActivityKit
import AppIntents
import Foundation
import UserNotifications

/// The rest between sets as a Live Activity: shared by the app, which
/// starts and ends it (`RestNotice` in `Runner/AppDelegate.swift`), and
/// the widget extension, which draws it on the lock screen and in the
/// Dynamic Island.
@available(iOS 16.2, *)
struct RestAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// When the rest ends; the countdown is drawn by the system from it.
    var endsAt: Date
    var startedAt: Date
    /// `休息中`, and what comes next: `下一組 · 槓鈴深蹲`.
    var title: String
    var body: String
    /// The label of the button that ends the rest (iOS 17 and later); none
    /// shows no button.
    var skipLabel: String?
  }
}

/// 跳過休息 on the lock screen. A Live Activity intent runs in the app's
/// process, not the extension's: it ends the activity and takes the
/// notification away, then tells the app (`onSkip`, set by `RestNotice` in
/// `Runner/AppDelegate.swift`) to end the rest. The extension compiles it
/// to draw the button and never runs it.
@available(iOS 17.0, *)
struct SkipRestIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Skip rest"

  static var onSkip: (() -> Void)?

  func perform() async throws -> some IntentResult {
    for activity in Activity<RestAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["rest"])
    center.removeDeliveredNotifications(withIdentifiers: ["rest"])
    SkipRestIntent.onSkip?()
    return .result()
  }
}

/// Caffeine over the bedtime reference as a Live Activity: started, moved
/// and ended by the app (`CaffeineActivity` in `Runner/AppDelegate.swift`,
/// fed by `lib/app/caffeine_activity.dart`), drawn by
/// `CaffeineActivityWidget` in the widget extension. Every word and time
/// comes from the app, in its language and its clock.
@available(iOS 16.2, *)
struct CaffeineAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// The last cup, where the time track starts.
    var cupAt: Date
    /// When the estimate falls under the reference, on the next ten
    /// minutes; the content is stale from then.
    var belowAt: Date
    /// The suggested bedtime, only when it comes between the two.
    var bedtimeAt: Date?
    /// `咖啡因`; the last cup, `美式咖啡 · 120 mg`, and its time.
    var title: String
    var cup: String
    var cupTime: String
    /// `低於就寢參考` over `22:00`, and `已低於就寢參考` once it has.
    var belowLabel: String
    var belowDoneLabel: String
    var belowTime: String
    /// `建議就寢 23:30`, with `bedtimeAt`.
    var bedtime: String?
    /// `依半衰期 5 小時推算`.
    var basis: String
  }
}

