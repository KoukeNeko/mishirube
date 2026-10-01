import ActivityKit
import Foundation

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

