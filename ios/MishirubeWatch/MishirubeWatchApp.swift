import HealthKit
import SwiftUI
import UserNotifications
import WatchConnectivity
import WatchKit

/// The workout on the wrist: what to lift next, with its weight and reps
/// to change, the rest, the clock, the exercises, today's workout to
/// start, and the way to finish. The phone keeps the records; the watch
/// shows them and asks it to do what the workout page does
/// (`lib/app/watch_sync.dart`).
@main
struct MishirubeWatchApp: App {
  @StateObject private var workout = WorkoutLink()

  var body: some Scene {
    WindowGroup {
      RootView(workout: workout)
    }
  }
}

/// The app's green, as `AppColors.training` in `lib/app/theme.dart`.
let training = Color(red: 0x2E / 255, green: 0xE0 / 255, blue: 0x9A / 255)

/// What the phone last sent: empty when it has nothing to show.
final class WorkoutLink: NSObject, ObservableObject, WCSessionDelegate,
  UNUserNotificationCenterDelegate
{
  @Published private(set) var state: [String: Any] = [:]
  @Published private(set) var isSending = false
  @Published private(set) var pendingKey: String?
  @Published private(set) var isReachable = WCSession.default.isReachable
  let heart = HeartMonitor()

  override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  /// `idle` (today's workout to start), `ready`, `running`, `paused`, or
  /// `none`. A phone from before the phases sends a workout and nothing
  /// else, which is a running one.
  var phase: String {
    if let phase = state["phase"] as? String { return phase }
    return state["exercise"] != nil ? "running" : "none"
  }

  var isRunning: Bool { phase == "running" || phase == "paused" }

  var restEndsAt: Date? {
    (state["restEndsAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
  }

  /// When the running clock would have started, or the time it stopped at.
  var clockStart: Date? {
    (state["clockAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
  }

  var elapsedHeld: TimeInterval? {
    (state["elapsedMs"] as? Double).map { $0 / 1000 }
      ?? (state["elapsedMs"] as? Int).map { Double($0) / 1000 }
  }

  var exercises: [[String: Any]] { state["exercises"] as? [[String: Any]] ?? [] }

  /// The words the phone sends, in the app's language; the Chinese ones
  /// stand in until the first state arrives.
  func label(_ key: String, _ fallback: String) -> String {
    (state["labels"] as? [String: String])?[key] ?? fallback
  }

  /// A label with `{}` where [text] goes.
  func label(_ key: String, _ fallback: String, filling text: String) -> String {
    label(key, fallback).replacingOccurrences(of: "{}", with: text)
  }
  var currentIndex: Int { state["index"] as? Int ?? 0 }

  /// Asks the phone to do what the workout page does. [completion] hears
  /// whether the phone took it.
  func request(
    _ action: String, _ arguments: [String: Any] = [:], completion: ((Bool) -> Void)? = nil
  ) {
    guard WCSession.default.isReachable else { return }
    isSending = true
    var message = arguments
    message["action"] = action
    WCSession.default.sendMessage(message) { _ in
      DispatchQueue.main.async {
        self.isSending = false
        completion?(true)
      }
    } errorHandler: { _ in
      DispatchQueue.main.async {
        self.isSending = false
        completion?(false)
      }
    }
  }

  /// Which set the phone says is next, sent back with the request to log
  /// it, so a tap that comes twice or late is not a second set.
  var setKey: String? { state["setKey"] as? String }

  /// The set to do next was asked for and the phone has not moved on yet.
  var isLogging: Bool { pendingKey != nil && pendingKey == setKey }

  /// Logs the set to do next, at the weight and reps the steppers show.
  func logNextSet(weightKg: Double?, reps: Int?) {
    guard isReachable, !isLogging else { return }
    var arguments: [String: Any] = [:]
    if let weightKg { arguments["weightKg"] = weightKg }
    if let reps { arguments["reps"] = reps }
    if let setKey {
      arguments["setKey"] = setKey
      pendingKey = setKey
    }
    request("logNextSet", arguments) { isTaken in
      // A phone that never answers with a new state must not leave the
      // button off for good.
      let wait: TimeInterval = isTaken ? 4 : 0
      DispatchQueue.main.asyncAfter(deadline: .now() + wait) { self.pendingKey = nil }
    }
  }

  func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    let context = session.receivedApplicationContext
    DispatchQueue.main.async {
      self.isReachable = session.isReachable
      self.take(context)
    }
  }

  func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
    DispatchQueue.main.async { self.take(context) }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { self.isReachable = session.isReachable }
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
    let labels = state["labels"] as? [String: String] ?? [:]
    schedule(
      "rest", at: date(state["restEndsAt"]), was: date(old["restEndsAt"]),
      title: labels["restEnded"] ?? "休息結束",
      body: next.map { "\(exercise) · \($0)" } ?? exercise)
    schedule(
      "set", at: date(state["setEndsAt"]), was: date(old["setEndsAt"]),
      title: exercise, body: labels["done"] ?? "完成")
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
  let title: String
  let stop: String

  var body: some View {
    if heart.isRunning {
      HStack {
        Image(systemName: "heart.fill")
          .foregroundStyle(heartColor)
        Text(heart.bpm.map(String.init) ?? "—")
          .font(.title3.weight(.semibold))
          .monospacedDigit()
        Spacer()
        Button(stop, action: heart.stop)
          .buttonStyle(.bordered)
          .fixedSize()
      }
    } else {
      Button(action: heart.start) {
        Label(title, systemImage: "heart")
          .frame(maxWidth: .infinity)
      }
      .tint(heartColor)
    }
  }
}

/// `AppColors.heart` in `lib/app/theme.dart`.
let heartColor = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x83 / 255)


// MARK: - Screens

struct RootView: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    switch workout.phase {
    case "running", "paused":
      RunningView(workout: workout)
    case "ready":
      ReadyView(workout: workout)
    case "idle":
      IdleView(workout: workout)
    default:
      Text(workout.label("noWorkout", "沒有進行中的訓練"))
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }
}

/// Today's workout, to start from the wrist.
struct IdleView: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    VStack(spacing: 8) {
      Text(workout.state["routine"] as? String ?? "")
        .font(.headline)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      if let sets = workout.state["routineSets"] as? Int {
        Text(workout.label("sets", "{} 組", filling: "\(sets)"))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Button {
        workout.request("startWorkout")
      } label: {
        Label(workout.label("start", "開始運動"), systemImage: "play.fill")
          .frame(maxWidth: .infinity)
      }
      .tint(training)
      .disabled(workout.state["canStart"] as? Bool != true || !workout.isReachable)
      if !workout.isReachable {
        Text(workout.label("notConnected", "未連線"))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }
}

/// A workout arranged on the phone, not yet under way.
struct ReadyView: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    VStack(spacing: 8) {
      Text(workout.state["workout"] as? String ?? "")
        .font(.headline)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      Text(workout.state["exercise"] as? String ?? "")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(2)
      Button {
        workout.request("beginWorkout")
      } label: {
        Label(workout.label("start", "開始運動"), systemImage: "play.fill")
          .frame(maxWidth: .infinity)
      }
      .tint(training)
      .disabled(!workout.isReachable)
    }
  }
}

/// The workout under way, in three pages: this set, the exercises, the
/// controls.
struct RunningView: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    TabView {
      NowView(workout: workout)
      ExercisesView(workout: workout)
      ControlsView(workout: workout)
    }
    .tabViewStyle(.verticalPage)
  }
}

/// The time the workout has taken: counting while it runs, held while it
/// is paused (in the warning colour, as on the phone).
struct WorkoutClock: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    if let start = workout.clockStart {
      Text(start, style: .timer)
        .monospacedDigit()
    } else if let held = workout.elapsedHeld {
      Text(Self.format(held))
        .monospacedDigit()
        .foregroundStyle(.orange)
    }
  }

  private static func format(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let hours = total / 3600
    let minutes = total % 3600 / 60
    let rest = total % 60
    return hours > 0
      ? String(format: "%d:%02d:%02d", hours, minutes, rest)
      : String(format: "%d:%02d", minutes, rest)
  }
}

/// The set to do next, with its weight and reps to change, and the rest.
struct NowView: View {
  @ObservedObject var workout: WorkoutLink
  @State private var weightKg = 0.0
  @State private var reps = 0

  /// Changes when the set to do next does, so the steppers start from it.
  private var setKey: String {
    "\(workout.currentIndex)|\(workout.state["set"] as? String ?? "")"
  }

  private var weightStep: Double { workout.state["weightStep"] as? Double ?? 2.5 }
  private var hasWeight: Bool { workout.state["weightKg"] as? Double != nil }
  private var hasReps: Bool { workout.state["reps"] as? Int != nil }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        Text(workout.state["exercise"] as? String ?? "")
          .font(.headline)
          .lineLimit(2)
        HStack {
          Text(workout.state["progress"] as? String ?? "")
          Spacer()
          WorkoutClock(workout: workout)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        if workout.state["hasNext"] as? Bool == true {
          if hasWeight {
            Stepper(value: $weightKg, in: 0...1000, step: weightStep) {
              Text("\(Self.weightText(weightKg)) kg")
                .monospacedDigit()
            }
          }
          if hasReps {
            Stepper(value: $reps, in: 0...999) {
              Text(workout.label("reps", "{} 次", filling: "\(reps)"))
                .monospacedDigit()
            }
          }
          if !hasWeight && !hasReps {
            Text(workout.state["set"] as? String ?? "")
              .font(.title3.weight(.bold))
              .monospacedDigit()
              .foregroundStyle(training)
          }
          Button {
            workout.logNextSet(
              weightKg: hasWeight ? weightKg : nil, reps: hasReps ? reps : nil)
          } label: {
            Text(workout.label("logSet", "完成這一組"))
              .frame(maxWidth: .infinity)
          }
          .tint(training)
          .disabled(
            workout.isSending || workout.isLogging || !workout.isReachable
              || workout.phase == "paused")
          if !workout.isReachable {
            Text(workout.label("notConnected", "未連線"))
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        } else {
          Text(workout.state["set"] as? String ?? "")
            .font(.title3.weight(.bold))
            .foregroundStyle(training)
        }
        if let endsAt = workout.restEndsAt, endsAt > Date() {
          RestCard(workout: workout, endsAt: endsAt)
        }
      }
    }
    .onAppear(perform: reset)
    .onChange(of: setKey) { _, _ in reset() }
    .navigationTitle(workout.state["workout"] as? String ?? "")
  }

  private func reset() {
    weightKg = workout.state["weightKg"] as? Double ?? 0
    reps = workout.state["reps"] as? Int ?? 0
  }

  /// `62.5`, and `60` for a whole number.
  private static func weightText(_ kg: Double) -> String {
    String(format: "%g", kg)
  }
}

/// What is left of the rest, to lengthen, cut or skip.
struct RestCard: View {
  @ObservedObject var workout: WorkoutLink
  let endsAt: Date

  var body: some View {
    VStack(spacing: 4) {
      HStack {
        Text(workout.label("rest", "休息"))
          .foregroundStyle(.secondary)
        Spacer()
        Text(timerInterval: Date()...endsAt, countsDown: true)
          .monospacedDigit()
          .font(.title3.weight(.semibold))
      }
      HStack(spacing: 4) {
        Button("−15") { workout.request("extendRest", ["seconds": -15]) }
        Button("+15") { workout.request("extendRest", ["seconds": 15]) }
        Button(workout.label("skip", "跳過")) { workout.request("skipRest") }
      }
      .buttonStyle(.bordered)
      .font(.footnote)
    }
    .padding(.vertical, 4)
  }
}

/// The exercises of the workout, to switch between.
struct ExercisesView: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    List {
      ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, item in
        Button {
          workout.request("selectExercise", ["index": index])
        } label: {
          HStack {
            VStack(alignment: .leading) {
              Text(item["name"] as? String ?? "")
                .lineLimit(2)
              Text(
                workout.label(
                  "sets", "{} 組",
                  filling: "\(item["done"] as? Int ?? 0) / \(item["total"] as? Int ?? 0)")
              )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if index == workout.currentIndex {
              Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(training)
            }
          }
        }
      }
    }
    .navigationTitle(workout.label("exercises", "動作"))
  }
}

/// Pausing, finishing and the heart rate.
struct ControlsView: View {
  @ObservedObject var workout: WorkoutLink
  @State private var isConfirmingFinish = false

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        Button {
          workout.request("togglePause")
        } label: {
          Label(
            workout.phase == "paused"
              ? workout.label("resume", "繼續") : workout.label("pause", "暫停"),
            systemImage: workout.phase == "paused" ? "play.fill" : "pause.fill"
          )
          .frame(maxWidth: .infinity)
        }
        .disabled(!workout.isReachable)
        HeartRow(
          heart: workout.heart, title: workout.label("heartRate", "心率"),
          stop: workout.label("stop", "停止"))
        Button(role: .destructive) {
          isConfirmingFinish = true
        } label: {
          Label(workout.label("finish", "完成訓練"), systemImage: "checkmark")
            .frame(maxWidth: .infinity)
        }
        .disabled(!workout.isReachable)
        .confirmationDialog(
          workout.label("confirmTitle", "結束這次訓練？"), isPresented: $isConfirmingFinish
        ) {
          Button(workout.label("confirmSave", "結束並儲存")) { workout.request("finishWorkout") }
          Button(workout.label("confirmKeep", "繼續訓練"), role: .cancel) {}
        }
      }
    }
    .navigationTitle(workout.label("controls", "控制"))
  }
}
