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
