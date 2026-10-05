import SwiftUI
import WidgetKit

/// One drawing of a widget: the snapshot and the moment it is drawn for.
/// What depends on the day reads as a new day from midnight on, however
/// long ago the app wrote the snapshot.
struct SnapshotEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?

  /// What a widget reads its day's figures from, nil when they are not
  /// for the day it is drawn on.
  var today: WidgetSnapshot? {
    guard let snapshot, snapshot.isCurrent(at: date) else { return nil }
    return snapshot
  }

  /// The figures of the day being drawn: what the snapshot has for it,
  /// or a day with nothing in it yet once that day is over.
  var nutrition: WidgetSnapshot.Nutrition? {
    guard let snapshot else { return nil }
    return snapshot.isCurrent(at: date) ? snapshot.nutrition : snapshot.nutrition.startedOver
  }

  var water: WidgetSnapshot.Water? {
    guard let snapshot else { return nil }
    return snapshot.isCurrent(at: date) ? snapshot.water : snapshot.water.startedOver
  }

  /// A health platform's figures are not known for a day the app has not
  /// seen.
  var activity: WidgetSnapshot.Activity? {
    guard let snapshot else { return nil }
    return snapshot.isCurrent(at: date) ? snapshot.activity : .init(steps: nil, activeKcal: nil)
  }
}

/// Gives a widget its timeline: the snapshot drawn now and again at
/// every `step` for a few hours, for what moves with the clock, and at
/// midnight, when a day's figures start over. Nothing else changes
/// without the app writing a new snapshot, which reloads every widget.
struct SnapshotProvider: TimelineProvider {
  /// How often to draw again; nil for midnight only.
  var step: TimeInterval? = nil
  /// How far ahead the steps run.
  var horizon: TimeInterval = 6 * 3600

  func placeholder(in context: Context) -> SnapshotEntry {
    SnapshotEntry(date: .now, snapshot: .sample(text: WidgetSnapshot.load()?.text))
  }

  func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
    let snapshot = WidgetSnapshot.load()
    completion(
      SnapshotEntry(
        date: .now,
        snapshot: context.isPreview || snapshot == nil ? .sample(text: snapshot?.text) : snapshot))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
    let snapshot = WidgetSnapshot.load()
    let now = Date()
    let calendar = Calendar.current
    let midnight =
      calendar.nextDate(
        after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
      ?? now.addingTimeInterval(24 * 3600)

    var dates = [now]
    if let step {
      var next = now.addingTimeInterval(step)
      while next < now.addingTimeInterval(horizon) {
        dates.append(next)
        next = next.addingTimeInterval(step)
      }
    }
    dates.append(midnight)
    // The day after, so a widget drawn for two days with the app closed
    // still turns over once more before it is asked again.
    dates.append(midnight.addingTimeInterval(24 * 3600))

    let entries = dates.sorted().map { SnapshotEntry(date: $0, snapshot: snapshot) }
    completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(24 * 3600))))
  }
}

extension WidgetSnapshot {
  /// Realistic figures for the widget gallery and for a widget before it
  /// has anything, in the words the app last wrote when it has.
  static func sample(text: [String: String]?) -> WidgetSnapshot {
    let now = Date()
    let millis = now.timeIntervalSince1970 * 1000
    let day: TimeInterval = 24 * 3600

    // A 200 mg cup drunk five hours ago, falling by half every five.
    var values: [Double] = []
    for index in 0...144 {
      let hours = Double(index) / 6 - 8
      values.append(hours < -5 ? 0 : 200 * pow(0.5, (hours + 5) / 5))
    }
    let caffeine = Caffeine(
      start: now.addingTimeInterval(-8 * 3600).timeIntervalSince1970 * 1000, stepMinutes: 10,
      values: values, reference: 35, referenceText: "35 mg")

    var days: [String] = []
    for back in 0..<14 { days.append(dayKey(now.addingTimeInterval(-Double(back) * day))) }
    let goal = Goal(
      enabled: true, target: 4, activeDays: [days[0], days[1], days[3], days[5]], streak: 3,
      streakText: nil, isPaused: false)

    let minutes = [400, 455, 380, 470, 430, 500, 432]
    var nights: [Sleep.Night] = []
    for index in 0..<7 { nights.append(Sleep.Night(day: days[6 - index], minutes: minutes[index])) }
    let sleep = Sleep(
      asleepMinutes: 432, wokeAt: millis, asleepText: "7:12", goalMinutes: 480, goalText: nil,
      nights: nights, shortMinutes: 150)

    var trend: [Weight.Point] = []
    for index in 0..<7 {
      let wobble = index % 2 == 0 ? 0.2 : -0.2
      trend.append(
        Weight.Point(
          at: now.addingTimeInterval(-Double(6 - index) * day).timeIntervalSince1970 * 1000,
          weight: 72.9 - Double(index) * 0.08 + wobble, trend: 72.8 - Double(index) * 0.07))
    }
    let weight = Weight(kg: 72.4, measuredAt: millis, changeText: "−0.3", trend: trend)

    let nutrition = Nutrition(
      kcal: 1240, kcalTarget: 2100, meals: 3, protein: 78, proteinTarget: 130, carb: 140,
      carbTarget: 230, fat: 42, fatTarget: 70)
    let water = Water(ml: 1200, reference: 2000, times: 5, timesText: nil, lastTime: nil)
    let training = Training(
      name: "Push", at: now.addingTimeInterval(-26 * 3600).timeIntervalSince1970 * 1000,
      detail: "17 sets · 88 min")
    let modules = ["nutrition", "water", "weight", "training", "activity", "sleep"]

    return WidgetSnapshot(
      version: version, generatedAt: millis, day: dayKey(now), modules: modules,
      text: text ?? fallbackText, nutrition: nutrition, water: water, caffeine: caffeine,
      goal: goal, sleep: sleep, weight: weight, training: training,
      activity: Activity(steps: 6420, activeKcal: 310))
  }
}
