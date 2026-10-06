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

/// `AppColors.heart` in `lib/app/theme.dart`.
let heartColor = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x83 / 255)

// MARK: - Look

/// The rest of `AppColors` the wrist uses (`lib/app/theme.dart`): the dark
/// text on the green, the raised surface, and the pause amber.
let onTraining = Color(red: 0x06 / 255, green: 0x14 / 255, blue: 0x0E / 255)
let surfaceRaised = Color(red: 0x24 / 255, green: 0x27 / 255, blue: 0x26 / 255)
let warning = Color(red: 0xE8 / 255, green: 0xB9 / 255, blue: 0x4A / 255)

/// Figures are rounded and a fixed size: they read at a glance, and the
/// page does not grow into a scroll with the text size.
func figure(_ size: CGFloat) -> Font {
  .system(size: size, weight: .bold, design: .rounded)
}

/// A tint washing down from the top of a page: the app's green while the
/// workout runs, amber while it is paused.
func wash(_ color: Color) -> LinearGradient {
  LinearGradient(
    colors: [color.opacity(0.32), color.opacity(0)], startPoint: .top, endPoint: .center)
}

/// The one thing to do on a page: a capsule across it.
struct PrimaryButtonStyle: ButtonStyle {
  var tint: Color = training
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 16, weight: .bold))
      .foregroundStyle(isEnabled ? onTraining : Color.secondary)
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(Capsule().fill(isEnabled ? tint : surfaceRaised))
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

/// A short action beside others, in the raised surface colour.
struct ChipButtonStyle: ButtonStyle {
  var tint: Color = .white

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(tint)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity, minHeight: 30)
      .background(Capsule().fill(surfaceRaised))
      .opacity(configuration.isPressed ? 0.6 : 1)
  }
}

/// A step up or down of a figure.
struct StepButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 15, weight: .bold))
      .foregroundStyle(isEnabled ? Color.white : Color.secondary.opacity(0.5))
      .frame(width: 36, height: 36)
      .background(Circle().fill(surfaceRaised))
      .opacity(configuration.isPressed ? 0.6 : 1)
  }
}

/// A ring that is full at 1 and empty at 0.
struct Ring: View {
  let progress: Double
  let color: Color
  var lineWidth: CGFloat = 7

  var body: some View {
    ZStack {
      Circle().stroke(color.opacity(0.22), lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: max(0, min(1, progress)))
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

/// A finish that asks first: the workout is saved on the phone for good.
extension View {
  func confirmingFinish(_ workout: WorkoutLink, isPresented: Binding<Bool>) -> some View {
    confirmationDialog(
      workout.label("confirmTitle", "結束這次訓練？"), isPresented: isPresented
    ) {
      Button(workout.label("confirmSave", "結束並儲存")) { workout.request("finishWorkout") }
      Button(workout.label("confirmKeep", "繼續訓練"), role: .cancel) {}
    }
  }
}

extension WorkoutLink {
  /// A number the phone sent, whatever kind of number it travelled as.
  func number(_ key: String) -> Double? {
    (state[key] as? NSNumber)?.doubleValue
  }

  /// The sets done and in all of the exercise under way.
  var current: (done: Int, total: Int) {
    guard exercises.indices.contains(currentIndex) else { return (0, 0) }
    let item = exercises[currentIndex]
    return (item["done"] as? Int ?? 0, item["total"] as? Int ?? 0)
  }

  var setsDone: Int { exercises.reduce(0) { $0 + ($1["done"] as? Int ?? 0) } }
  var setsTotal: Int { exercises.reduce(0) { $0 + ($1["total"] as? Int ?? 0) } }
  var isAllDone: Bool { setsTotal > 0 && setsDone == setsTotal }
}

// MARK: - Screens

struct RootView: View {
  @ObservedObject var workout: WorkoutLink

  var body: some View {
    NavigationStack {
      switch workout.phase {
      case "running", "paused":
        RunningView(workout: workout)
      case "ready":
        StartView(
          workout: workout, title: workout.state["workout"] as? String ?? "",
          detail: workout.state["exercise"] as? String, isEnabled: true,
          action: "beginWorkout")
      case "idle":
        StartView(
          workout: workout, title: workout.state["routine"] as? String ?? "",
          detail: (workout.state["routineSets"] as? Int).map {
            workout.label("sets", "{} 組", filling: "\($0)")
          },
          isEnabled: workout.state["canStart"] as? Bool == true, action: "startWorkout")
      default:
        VStack(spacing: 8) {
          Image(systemName: "figure.strengthtraining.traditional")
            .font(.system(size: 28))
            .foregroundStyle(.tertiary)
          Text(workout.label("noWorkout", "沒有進行中的訓練"))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      }
    }
    .tint(training)
  }
}

/// A workout to start from the wrist: today's, or one arranged on the
/// phone and not yet under way.
struct StartView: View {
  @ObservedObject var workout: WorkoutLink
  let title: String
  let detail: String?
  let isEnabled: Bool
  let action: String

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "figure.strengthtraining.traditional")
        .font(.system(size: 28))
        .foregroundStyle(training)
      VStack(spacing: 2) {
        Text(title)
          .font(.system(size: 18, weight: .bold))
          .lineLimit(2)
          .minimumScaleFactor(0.8)
          .multilineTextAlignment(.center)
        if let detail {
          Text(detail)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
      }
      if workout.isReachable {
        Button {
          workout.request(action)
        } label: {
          Label(workout.label("start", "開始運動"), systemImage: "play.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!isEnabled)
      } else {
        Button {
        } label: {
          Label(workout.label("notConnected", "未連線"), systemImage: "iphone.slash")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(true)
      }
    }
    .padding(.horizontal, 4)
    .containerBackground(wash(training), for: .navigation)
  }
}

/// The workout under way, in three pages: this set, the exercises, the
/// controls.
struct RunningView: View {
  @ObservedObject var workout: WorkoutLink
  @State private var page = Page.now

  enum Page { case now, exercises, controls }

  var body: some View {
    TabView(selection: $page) {
      NowView(workout: workout).tag(Page.now)
      ExercisesView(workout: workout) { page = .now }.tag(Page.exercises)
      ControlsView(workout: workout).tag(Page.controls)
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
        .foregroundStyle(warning)
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

/// The heart rate the watch is reading, while it reads it.
struct HeartReadout: View {
  @ObservedObject var heart: HeartMonitor

  var body: some View {
    if heart.isRunning {
      HStack(spacing: 2) {
        Image(systemName: "heart.fill")
          .font(.system(size: 11))
        Text(heart.bpm.map(String.init) ?? "—")
          .monospacedDigit()
      }
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(heartColor)
    }
  }
}

/// The sets of one exercise as dots: done ones filled, the next ringed.
struct SetDots: View {
  let done: Int
  let total: Int

  var body: some View {
    if total > 0 && total <= 6 {
      HStack(spacing: 6) {
        ForEach(0..<total, id: \.self) { index in
          Circle()
            .fill(index < done ? training : Color.white.opacity(0.25))
            .frame(width: 7, height: 7)
            .overlay {
              if index == done {
                Circle().stroke(training, lineWidth: 1.5).padding(-3)
              }
            }
        }
      }
      .padding(.horizontal, 3)
    } else {
      Text("\(done) / \(total)")
        .font(.system(size: 13, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
  }
}

/// A figure of the next set, to step up or down.
struct AdjustRow: View {
  let value: String
  let unit: String
  let canDecrease: Bool
  let decrease: () -> Void
  let increase: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Button(action: decrease) { Image(systemName: "minus") }
        .buttonStyle(StepButtonStyle())
        .disabled(!canDecrease)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value)
          .font(figure(26))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(unit)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      Button(action: increase) { Image(systemName: "plus") }
        .buttonStyle(StepButtonStyle())
    }
  }
}

/// What is left of the rest, over the page while it runs: a ring that
/// empties, to lengthen, cut or skip.
struct RestHero: View {
  @ObservedObject var workout: WorkoutLink
  let endsAt: Date

  /// The rest as long as it was set for; a phone before it said so sends
  /// none, and three minutes stands in.
  private var length: TimeInterval {
    max(1, (workout.number("restLength") ?? 180_000) / 1000)
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      if endsAt > context.date {
        VStack(spacing: 6) {
          ZStack {
            Ring(
              progress: endsAt.timeIntervalSince(context.date) / length,
              color: training,
              lineWidth: 6
            )
            .animation(.linear(duration: 1), value: context.date)
            VStack(spacing: -1) {
              Text(timerInterval: context.date...endsAt, countsDown: true)
                .font(figure(21))
                .monospacedDigit()
              Text(workout.label("rest", "休息"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
          }
          .frame(width: 70, height: 70)
          HStack(spacing: 4) {
            Button("−15") { workout.request("extendRest", ["seconds": -15]) }
            Button("+15") { workout.request("extendRest", ["seconds": 15]) }
            Button(workout.label("skip", "跳過")) { workout.request("skipRest") }
              .foregroundStyle(training)
          }
          .buttonStyle(ChipButtonStyle())
        }
        .padding(.bottom, 8)
      }
    }
  }
}

/// The set to do next, with its weight and reps to change; the rest over
/// it while one runs, and the one thing to do pinned under it.
struct NowView: View {
  @ObservedObject var workout: WorkoutLink
  @State private var weightKg = 0.0
  @State private var reps = 0
  @State private var isConfirmingFinish = false

  /// Changes when the set to do next does, so the figures start from it.
  private var setKey: String {
    "\(workout.currentIndex)|\(workout.state["set"] as? String ?? "")"
  }

  private var weightStep: Double { workout.number("weightStep") ?? 2.5 }
  private var hasWeight: Bool { workout.number("weightKg") != nil }
  private var hasReps: Bool { workout.number("reps") != nil }
  private var hasNext: Bool { workout.state["hasNext"] as? Bool == true }
  private var isPaused: Bool { workout.phase == "paused" }

  /// What follows the number of reps: the phone's word for them, with the
  /// number taken out.
  private var repsUnit: String {
    workout.label("reps", "{} 次").replacingOccurrences(of: "{}", with: "")
      .trimmingCharacters(in: .whitespaces)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if let endsAt = workout.restEndsAt, endsAt > Date() {
          RestHero(workout: workout, endsAt: endsAt)
        }
        header
        figures
      }
      .padding(.horizontal, 8)
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) { status }
      ToolbarItemGroup(placement: .bottomBar) { action }
    }
    .containerBackground(wash(isPaused ? warning : training), for: .tabView)
    .onAppear(perform: reset)
    .onChange(of: setKey) { _, _ in reset() }
    .confirmingFinish(workout, isPresented: $isConfirmingFinish)
  }

  /// Beside the system clock: the sets of this exercise, the heart rate
  /// and the time the workout has taken.
  private var status: some View {
    HStack(spacing: 8) {
      SetDots(done: workout.current.done, total: workout.current.total)
      HeartReadout(heart: workout.heart)
      WorkoutClock(workout: workout)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .lineLimit(1)
    .fixedSize()
  }

  private var header: some View {
    Text(workout.state["exercise"] as? String ?? "")
      .font(.system(size: 17, weight: .bold))
      .lineLimit(2)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, 8)
  }

  @ViewBuilder private var figures: some View {
    if hasNext {
      VStack(spacing: 6) {
        if hasWeight {
          AdjustRow(
            value: Self.weightText(weightKg), unit: "kg", canDecrease: weightKg > 0,
            decrease: { weightKg = max(0, weightKg - weightStep) },
            increase: { weightKg = min(1000, weightKg + weightStep) })
        }
        if hasReps {
          AdjustRow(
            value: "\(reps)", unit: repsUnit, canDecrease: reps > 0,
            decrease: { reps = max(0, reps - 1) },
            increase: { reps = min(999, reps + 1) })
        }
        if !hasWeight && !hasReps {
          Text(workout.state["set"] as? String ?? "")
            .font(figure(24))
            .monospacedDigit()
            .foregroundStyle(training)
            .frame(maxWidth: .infinity)
        }
      }
    } else {
      Label(workout.state["set"] as? String ?? "", systemImage: "checkmark.circle.fill")
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(training)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// What a tap does here: logs the set, or ends the workout once every
  /// set is done, or takes it up again while it is paused.
  private var action: some View {
    Group {
      if !workout.isReachable {
        Button {
        } label: {
          Label(workout.label("notConnected", "未連線"), systemImage: "iphone.slash")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(true)
      } else if isPaused {
        Button {
          workout.request("togglePause")
        } label: {
          Label(workout.label("resume", "繼續"), systemImage: "play.fill")
        }
        .buttonStyle(PrimaryButtonStyle(tint: warning))
      } else if hasNext {
        Button {
          workout.logNextSet(
            weightKg: hasWeight ? weightKg : nil, reps: hasReps ? reps : nil)
        } label: {
          Label(workout.label("logSet", "完成這一組"), systemImage: "checkmark")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(workout.isSending || workout.isLogging)
      } else if workout.isAllDone {
        Button {
          isConfirmingFinish = true
        } label: {
          Label(workout.label("finish", "完成訓練"), systemImage: "flag.checkered")
        }
        .buttonStyle(PrimaryButtonStyle())
      }
    }
  }

  private func reset() {
    weightKg = workout.number("weightKg") ?? 0
    reps = Int(workout.number("reps") ?? 0)
  }

  /// `62.5`, and `60` for a whole number.
  private static func weightText(_ kg: Double) -> String {
    String(format: "%g", kg)
  }
}

/// The exercises of the workout, to switch between; the one chosen is the
/// one the page then shows.
struct ExercisesView: View {
  @ObservedObject var workout: WorkoutLink
  let showNow: () -> Void

  var body: some View {
    List {
      VStack(alignment: .leading, spacing: 6) {
        Text(workout.state["progress"] as? String ?? "")
          .font(figure(20))
          .monospacedDigit()
        ProgressView(value: Double(workout.setsDone), total: Double(max(1, workout.setsTotal)))
          .tint(training)
      }
      .listRowBackground(Color.clear)
      ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, item in
        ExerciseRow(item: item, isCurrent: index == workout.currentIndex) {
          workout.request("selectExercise", ["index": index])
          showNow()
        }
      }
    }
    .listStyle(.carousel)
    .containerBackground(wash(training), for: .tabView)
    .navigationTitle(workout.label("exercises", "動作"))
  }
}

/// One exercise: where it stands, and its sets done in all.
struct ExerciseRow: View {
  let item: [String: Any]
  let isCurrent: Bool
  let select: () -> Void

  private var done: Int { item["done"] as? Int ?? 0 }
  private var total: Int { item["total"] as? Int ?? 0 }
  private var isDone: Bool { total > 0 && done == total }
  private var symbol: String {
    if isDone { return "checkmark.circle.fill" }
    return isCurrent ? "circle.inset.filled" : "circle"
  }

  var body: some View {
    Button(action: select) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: 16))
          .foregroundStyle(isDone || isCurrent ? training : Color.secondary)
        VStack(alignment: .leading, spacing: 1) {
          Text(item["name"] as? String ?? "")
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(2)
          Text("\(done) / \(total)")
            .font(.system(size: 12))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
    }
    .listRowBackground(
      RoundedRectangle(cornerRadius: 14)
        .fill(isCurrent ? training.opacity(0.22) : surfaceRaised))
  }
}

/// Pausing, finishing and the heart rate, as tiles.
struct ControlsView: View {
  @ObservedObject var workout: WorkoutLink
  @State private var isConfirmingFinish = false

  private var isPaused: Bool { workout.phase == "paused" }

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          ControlTile(
            icon: isPaused ? "play.fill" : "pause.fill",
            title: isPaused ? workout.label("resume", "繼續") : workout.label("pause", "暫停"),
            tint: isPaused ? training : warning
          ) { workout.request("togglePause") }
          ControlTile(icon: "checkmark", title: workout.label("finish", "完成訓練"), tint: training) {
            isConfirmingFinish = true
          }
        }
        .disabled(!workout.isReachable)
        HeartTile(
          heart: workout.heart, title: workout.label("heartRate", "心率"),
          stop: workout.label("stop", "停止"))
      }
      .padding(.horizontal, 6)
    }
    .containerBackground(wash(isPaused ? warning : training), for: .tabView)
    .navigationTitle(workout.label("controls", "控制"))
    .confirmingFinish(workout, isPresented: $isConfirmingFinish)
  }
}

/// A square control: its picture over its name.
struct ControlTile: View {
  let icon: String
  let title: String
  let tint: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(tint)
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(2)
          .minimumScaleFactor(0.8)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, minHeight: 76)
      .background(RoundedRectangle(cornerRadius: 18).fill(tint.opacity(0.2)))
    }
    .buttonStyle(.plain)
  }
}

/// The 心率 control and, once started, the live value with 停止.
struct HeartTile: View {
  @ObservedObject var heart: HeartMonitor
  let title: String
  let stop: String

  var body: some View {
    if heart.isRunning {
      HStack(spacing: 6) {
        Image(systemName: "heart.fill")
          .font(.system(size: 18))
        Text(heart.bpm.map(String.init) ?? "—")
          .font(figure(26))
          .monospacedDigit()
        Spacer(minLength: 0)
        Button(stop, action: heart.stop)
          .buttonStyle(ChipButtonStyle())
          .fixedSize()
      }
      .foregroundStyle(heartColor)
      .padding(.horizontal, 12)
      .frame(maxWidth: .infinity, minHeight: 56)
      .background(RoundedRectangle(cornerRadius: 18).fill(heartColor.opacity(0.2)))
    } else {
      Button(action: heart.start) {
        Label(title, systemImage: "heart")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(heartColor)
          .frame(maxWidth: .infinity, minHeight: 56)
          .background(RoundedRectangle(cornerRadius: 18).fill(heartColor.opacity(0.2)))
      }
      .buttonStyle(.plain)
    }
  }
}
