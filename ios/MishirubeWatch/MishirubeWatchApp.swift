import SwiftUI
import WatchConnectivity

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
final class WorkoutLink: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var state: [String: Any] = [:]
  @Published private(set) var isSending = false

  override init() {
    super.init()
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
    DispatchQueue.main.async { self.state = context }
  }

  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    DispatchQueue.main.async { self.state = context }
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
