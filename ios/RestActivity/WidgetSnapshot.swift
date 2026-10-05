import Foundation

/// What the home-screen widgets draw, as `widgetSnapshot` in
/// `lib/app/widget_snapshot.dart` writes it: figures the app works out and
/// the words in the app's own language. The app hands it to `WidgetBridge`
/// (`ios/Runner/WidgetBridge.swift`), which keeps it in the app group's
/// shared defaults; a widget reads it here, whenever the system draws it.
struct WidgetSnapshot: Codable {
  static let version = 1
  static let groupIdentifier = "group.dev.koukeneko.mishirube"
  static let key = "widgetSnapshot"

  var version: Int
  var generatedAt: Double
  /// The day (`2026-09-19`) the figures that depend on the day are for.
  var day: String
  var modules: [String]
  var text: [String: String]
  var nutrition: Nutrition
  var water: Water
  var caffeine: Caffeine?
  var goal: Goal
  var sleep: Sleep
  var weight: Weight
  var training: Training?
  var activity: Activity

  struct Nutrition: Codable {
    var kcal: Double
    var kcalTarget: Double?
    var meals: Int
    var protein: Double
    var proteinTarget: Double?
    var carb: Double
    var carbTarget: Double?
    var fat: Double
    var fatTarget: Double?

    /// A new day: the targets stay, nothing is eaten yet.
    var startedOver: Nutrition {
      Nutrition(
        kcal: 0, kcalTarget: kcalTarget, meals: 0, protein: 0, proteinTarget: proteinTarget,
        carb: 0, carbTarget: carbTarget, fat: 0, fatTarget: fatTarget)
    }
  }

  struct Water: Codable {
    var ml: Int
    var reference: Int?
    var times: Int
    var timesText: String?
    var lastTime: String?

    var startedOver: Water {
      Water(ml: 0, reference: reference, times: 0, timesText: nil, lastTime: nil)
    }
  }

  /// The curve of caffeine left in the body, every `stepMinutes` from
  /// `start`, given whole so a widget reads it at its own time.
  struct Caffeine: Codable {
    var start: Double
    var stepMinutes: Int
    var values: [Double]
    var reference: Double
    var referenceText: String

    var startDate: Date { Date(timeIntervalSince1970: start / 1000) }
    var endDate: Date {
      startDate.addingTimeInterval(Double((values.count - 1) * stepMinutes * 60))
    }

    /// The milligrams at `date`, between the two points either side; nil
    /// outside the curve.
    func value(at date: Date) -> Double? {
      let position = date.timeIntervalSince(startDate) / Double(stepMinutes * 60)
      guard position >= 0, position <= Double(values.count - 1) else { return nil }
      let low = Int(position.rounded(.down))
      let high = min(low + 1, values.count - 1)
      return values[low] + (values[high] - values[low]) * (position - Double(low))
    }

    /// When the curve next falls to the reference, from `date`; nil when
    /// it is already under it or never gets there.
    func fallsBelowReference(after date: Date) -> Date? {
      guard let now = value(at: date), now >= reference else { return nil }
      let first = max(0, Int((date.timeIntervalSince(startDate) / Double(stepMinutes * 60)).rounded(.up)))
      for index in first..<values.count where values[index] < reference {
        return startDate.addingTimeInterval(Double(index * stepMinutes * 60))
      }
      return nil
    }
  }

  struct Goal: Codable {
    var enabled: Bool
    var target: Int?
    var activeDays: [String]
    var streak: Int
    var streakText: String?
    var isPaused: Bool
  }

  struct Sleep: Codable {
    var asleepMinutes: Int?
    var wokeAt: Double?
    var asleepText: String?
    var goalMinutes: Int?
    var goalText: String?
    var nights: [Night]
    var shortMinutes: Int

    struct Night: Codable {
      var day: String
      var minutes: Int?
    }
  }

  struct Weight: Codable {
    var kg: Double?
    var measuredAt: Double?
    var changeText: String?
    var trend: [Point]

    struct Point: Codable {
      var at: Double
      var weight: Double
      var trend: Double
    }
  }

  struct Training: Codable {
    var name: String
    var at: Double
    var detail: String

    var date: Date { Date(timeIntervalSince1970: at / 1000) }
  }

  struct Activity: Codable {
    var steps: Double?
    var activeKcal: Double?
  }
}

extension WidgetSnapshot {
  /// The snapshot the app last wrote; nil before the app has run, or when
  /// it was written for another version.
  static func load() -> WidgetSnapshot? {
    guard
      let json = UserDefaults(suiteName: groupIdentifier)?.string(forKey: key),
      let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: Data(json.utf8)),
      snapshot.version == version
    else { return nil }
    return snapshot
  }

  func has(_ module: String) -> Bool { modules.contains(module) }

  func words(_ key: String) -> String { text[key] ?? Self.fallbackText[key] ?? key }

  /// The names before the app has run and written its own.
  static let fallbackText = [
    "today": "Today", "nutrition": "Nutrition", "water": "Water",
    "caffeine": "Caffeine", "goal": "Weekly goal", "sleep": "Sleep",
    "weight": "Weight", "training": "Training", "activity": "Steps",
    "protein": "Protein", "carb": "Carbs", "fat": "Fat",
    "remainingKcal": "kcal left", "empty": "—",
  ]

  /// The day a date falls on, written as the snapshot writes days.
  static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  /// Whether what depends on the day is still for the day `date` falls on:
  /// drawn the next day with the app closed, it is not, and reads as a
  /// new day with nothing in it yet.
  func isCurrent(at date: Date) -> Bool { day == Self.dayKey(date) }

  /// Days this week with something done, and this week's days Monday
  /// first, at `date`: counted here so the week turns over on its own.
  func week(at date: Date) -> (days: [(date: Date, isActive: Bool)], active: Int) {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    let active = Set(goal.activeDays)
    let days = (0..<7).map { offset -> (date: Date, isActive: Bool) in
      let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
      return (day, active.contains(Self.dayKey(day, calendar: calendar)))
    }
    return (days, days.filter(\.isActive).count)
  }
}
