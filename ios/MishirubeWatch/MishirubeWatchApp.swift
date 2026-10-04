import HealthKit
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
  let heart = HeartMonitor()

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
    if !isRunning { heart.stop() }
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
/// is locked. Local notifications also cover the case where no heart-rate
/// session runs (see `HeartMonitor`): they tap with the app in front
/// (`willPresent` above) and with it behind, so a session adds no second
/// tap of its own.
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

/// Heart rate while the workout runs, from a workout session the user
/// starts here. watchOS runs one session at a time, so starting it ends
/// one running in the Workout app: it begins only from a tap, never by
/// itself. The workout is not saved: the phone records it and writes it to
/// Health, so the builder is discarded, which keeps the heart-rate samples
/// it collected (`HKWorkoutBuilder.discardWorkout`: "Samples that were
/// added to the workout will not be deleted") and leaves no second workout.
final class HeartMonitor: NSObject, ObservableObject, HKWorkoutSessionDelegate,
  HKLiveWorkoutBuilderDelegate
{
  /// How often the phone is sent a value; it is live, not a record.
  private static let sendInterval: TimeInterval = 5

  @Published private(set) var isRunning = false
  @Published private(set) var bpm: Int?

  private let store = HKHealthStore()
  private let heartRate = HKQuantityType(.heartRate)
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var lastSent = Date.distantPast

  func start() {
    guard !isRunning, HKHealthStore.isHealthDataAvailable() else { return }
    isRunning = true
    Task { @MainActor in
      do {
        try await store.requestAuthorization(
          toShare: [HKObjectType.workoutType()], read: [heartRate])
        guard isRunning else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
          healthStore: store, workoutConfiguration: configuration)
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
        let start = Date()
        session.startActivity(with: start)
        try await builder.beginCollection(at: start)
      } catch {
        stop()
      }
    }
  }

  /// Ends the session and drops the workout; safe to call when none runs.
  func stop() {
    isRunning = false
    bpm = nil
    lastSent = .distantPast
    session?.end()
  }

  func workoutSession(
    _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState, date: Date
  ) {
    guard toState == .ended else { return }
    let builder = self.builder
    self.session = nil
    self.builder = nil
    builder?.endCollection(withEnd: date) { _, _ in builder?.discardWorkout() }
    DispatchQueue.main.async {
      self.isRunning = false
      self.bpm = nil
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    DispatchQueue.main.async { self.stop() }
  }

  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

  func workoutBuilder(
    _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
  ) {
    guard collectedTypes.contains(heartRate),
      let quantity = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity()
    else { return }
    let value = Int(quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
    DispatchQueue.main.async {
      guard self.isRunning else { return }
      self.bpm = value
      self.send(value)
    }
  }

  private func send(_ value: Int) {
    let now = Date()
    guard now.timeIntervalSince(lastSent) >= Self.sendInterval,
      WCSession.default.isReachable
    else { return }
    lastSent = now
    WCSession.default.sendMessage(
      ["action": "heartRate", "bpm": value, "time": now.timeIntervalSince1970 * 1000],
      replyHandler: { _ in }, errorHandler: { _ in })
  }
}

/// The 心率 control and, once started, the live value with 停止.
struct HeartRow: View {
  @ObservedObject var heart: HeartMonitor

  var body: some View {
    if heart.isRunning {
      HStack {
        Image(systemName: "heart.fill")
          .foregroundStyle(heartColor)
        Text(heart.bpm.map(String.init) ?? "—")
          .font(.title3.weight(.semibold))
          .monospacedDigit()
        Spacer()
        Button("停止", action: heart.stop)
          .buttonStyle(.bordered)
          .fixedSize()
      }
    } else {
      Button(action: heart.start) {
        Label("心率", systemImage: "heart")
          .frame(maxWidth: .infinity)
      }
      .tint(heartColor)
    }
  }
}

/// `AppColors.heart` in `lib/app/theme.dart`.
let heartColor = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x83 / 255)

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
          HeartRow(heart: workout.heart)
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
