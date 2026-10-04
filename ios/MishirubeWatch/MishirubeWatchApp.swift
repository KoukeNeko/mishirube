import SwiftUI
import UserNotifications
import WatchConnectivity
import WatchKit

/// The running workout on the wrist: what to lift next, the rest, and
/// logging the set without reaching for the phone. The phone keeps the
/// records; the watch only shows them and asks it to log.
@main
struct MishirubeWatchApp: App {
  @StateObject private var workout = WorkoutLink()

  var body: some Scene {
    WindowGroup {
      WorkoutView(workout: workout)
    }
  }
}

/// The app's green, as `AppColors.training` in `lib/app/theme.dart`.
let training = Color(red: 0x2E / 255, green: 0xE0 / 255, blue: 0x9A / 255)

/// What the phone last sent: empty when no workout runs.
final class WorkoutLink: NSObject, ObservableObject, WCSessionDelegate,
  UNUserNotificationCenterDelegate
{
  @Published private(set) var state: [String: Any] = [:]
  @Published private(set) var isSending = false

  override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  var isRunning: Bool { state["exercise"] != nil }

  var restEndsAt: Date? {
    (state["restEndsAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
  }

  func logNextSet() {
    guard WCSession.default.isReachable else { return }
    isSending = true
    WCSession.default.sendMessage(["action": "logNextSet"]) { _ in
      DispatchQueue.main.async { self.isSending = false }
    } errorHandler: { _ in
      DispatchQueue.main.async { self.isSending = false }
    }
  }

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let context = session.receivedApplicationContext
    DispatchQueue.main.async { self.take(context) }
  }

  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    DispatchQueue.main.async { self.take(context) }
  }

  private func take(_ context: [String: Any]) {
    WristAlert.update(context, after: state)
    state = context
  }

  /// With the app in front the countdown is on screen: a tap, no banner.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    WKInterfaceDevice.current().play(.stop)
    completionHandler([])
  }
}

/// The end of the rest and of a timed set on the wrist, scheduled here
/// from the times the phone sends, so it taps whether or not the phone
/// is locked. Without a workout session of its own, which would end one
/// running in the Workout app.
enum WristAlert {
  static func update(_ state: [String: Any], after old: [String: Any]) {
    let exercise = state["exercise"] as? String ?? ""
    let next = state["hasNext"] as? Bool == true ? state["set"] as? String : nil
    schedule(
      "rest", at: date(state["restEndsAt"]), was: date(old["restEndsAt"]),
      title: "休息結束", body: next.map { "\(exercise) · \($0)" } ?? exercise)
    schedule(
      "set", at: date(state["setEndsAt"]), was: date(old["setEndsAt"]),
      title: exercise, body: "完成")
  }

  private static func date(_ value: Any?) -> Date? {
    (value as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
  }

  private static func schedule(
    _ identifier: String, at endsAt: Date?, was scheduled: Date?, title: String, body: String
  ) {
    let center = UNUserNotificationCenter.current()
    guard let endsAt, endsAt > Date() else {
      // The phone lets go of a rest the moment it runs out, which can
      // come a moment before this alert: only one cut short is taken back.
      if let scheduled, scheduled.timeIntervalSinceNow > 1 {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
      }
      return
    }
    if endsAt == scheduled { return }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: identifier, content: content,
      trigger: UNTimeIntervalNotificationTrigger(
        timeInterval: max(1, endsAt.timeIntervalSinceNow), repeats: false))
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      if granted { center.add(request) }
    }
  }
}

struct WorkoutView: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    if !workout.isRunning {
      Text("沒有進行中的訓練")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 6) {
          Text(workout.state["exercise"] as? String ?? "")
            .font(.headline)
            .lineLimit(2)
          Text(workout.state["set"] as? String ?? "")
            .font(.title3.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(training)
          Text(workout.state["progress"] as? String ?? "")
            .font(.footnote)
            .foregroundStyle(.secondary)
          if let endsAt = workout.restEndsAt, endsAt > Date() {
            HStack {
              Text("休息")
                .foregroundStyle(.secondary)
              Spacer()
              Text(timerInterval: Date()...endsAt, countsDown: true)
                .monospacedDigit()
                .font(.title3.weight(.semibold))
            }
            .padding(.vertical, 4)
          }
          if workout.state["hasNext"] as? Bool == true {
            Button(action: workout.logNextSet) {
              Text("完成這一組")
                .frame(maxWidth: .infinity)
            }
            .tint(training)
            .disabled(workout.isSending)
          }
        }
      }
      .navigationTitle(workout.state["workout"] as? String ?? "")
    }
  }
}
