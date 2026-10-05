import SwiftUI
import WidgetKit

/// 今天: the day at a glance — what was eaten and drunk, the steps, last
/// night — and in the large one the caffeine and the week.
struct TodayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "today", provider: SnapshotProvider(step: 30 * 60)) { entry in
      TodayView(entry: entry).widgetFrame()
    }
    .configurationDisplayName(WidgetNames.name("today"))
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular,
      .accessoryInline,
    ])
  }
}

/// One figure of the day: what it is, and how far along.
private struct Reading: Identifiable {
  let id: String
  let label: String
  let value: String
  let unit: String?
  let color: Color
  let progress: Double?
}

private struct TodayView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, key: "today", color: Palette.training) { snapshot in
      let readings = readings(snapshot)
      switch family {
      case .accessoryCircular:
        let n = entry.nutrition ?? snapshot.nutrition
        Gauge(value: progress(n.kcal, of: n.kcalTarget)) {
          Image(systemName: "flame.fill")
        } currentValueLabel: {
          Text(grouped(n.kcal)).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .healthFigure()
        .opens("today")
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 1) {
          ForEach(readings.prefix(3)) { reading in
            HStack {
              Text(reading.label).font(.caption).widgetAccentable()
              Spacer()
              Text([reading.value, reading.unit].compactMap { $0 }.joined(separator: " "))
                .font(.system(size: 13, weight: .bold))
            }
          }
        }
        .healthFigure()
        .opens("today")
      case .accessoryInline:
        Text(readings.prefix(2).map { "\($0.value)" + ($0.unit.map { " \($0)" } ?? "") }.joined(separator: " · "))
          .healthFigure()
          .opens("today")
      case .systemMedium:
        tiles(snapshot, readings).healthFigure().opens("today")
      case .systemLarge:
        VStack(alignment: .leading, spacing: 14) {
          tiles(snapshot, readings)
          if let curve = snapshot.caffeine, curve.value(at: entry.date) != nil {
            VStack(alignment: .leading, spacing: 4) {
              Tag(title: snapshot.words("caffeine"), color: Palette.caffeine)
              CurveChart(curve: curve, now: entry.date).frame(height: 70)
            }
          }
          if snapshot.goal.enabled, let target = snapshot.goal.target {
            let week = snapshot.week(at: entry.date)
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Tag(title: snapshot.words("goal"), color: Palette.training)
                Spacer()
                Text("\(week.active) / \(target)")
                  .font(.system(size: 13, weight: .bold))
                  .foregroundStyle(Palette.primary)
              }
              WeekDots(days: week.days, now: entry.date)
            }
          }
        }
        .healthFigure()
        .opens("today")
      default:
        VStack(alignment: .leading, spacing: 7) {
          Tag(title: snapshot.words("today"), color: Palette.training)
          Spacer(minLength: 0)
          ForEach(readings) { reading in
            HStack(spacing: 5) {
              Circle().fill(reading.color).frame(width: 6, height: 6).widgetAccentable()
              caption(reading.label)
              Spacer(minLength: 4)
              Text([reading.value, reading.unit].compactMap { $0 }.joined(separator: " "))
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .healthFigure()
        .opens("today")
      }
    }
  }

  /// Each module that is on, with its figure for the day being drawn.
  private func readings(_ snapshot: WidgetSnapshot) -> [Reading] {
    var readings: [Reading] = []
    if snapshot.has("nutrition"), let n = entry.nutrition {
      readings.append(
        Reading(
          id: "nutrition", label: snapshot.words("nutrition"), value: grouped(n.kcal), unit: "kcal",
          color: Palette.nutrition, progress: n.kcalTarget == nil ? nil : progress(n.kcal, of: n.kcalTarget)))
    }
    if snapshot.has("water"), let water = entry.water {
      readings.append(
        Reading(
          id: "water", label: snapshot.words("water"), value: grouped(water.ml), unit: "mL",
          color: Palette.water,
          progress: water.reference == nil ? nil : progress(Double(water.ml), of: water.reference.map(Double.init))))
    }
    if snapshot.has("activity"), let steps = entry.activity?.steps {
      readings.append(
        Reading(
          id: "activity", label: snapshot.words("activity"), value: grouped(steps), unit: nil,
          color: Palette.activity, progress: nil))
    }
    if snapshot.has("sleep"), let text = snapshot.sleep.asleepText {
      readings.append(
        Reading(
          id: "sleep", label: snapshot.words("sleep"), value: text, unit: nil,
          color: Palette.sleep,
          progress: snapshot.sleep.goalMinutes == nil
            ? nil : progress(Double(snapshot.sleep.asleepMinutes ?? 0), of: snapshot.sleep.goalMinutes.map(Double.init))))
    }
    return readings
  }

  /// The day's figures two by two, each over a line of how far along.
  private func tiles(_ snapshot: WidgetSnapshot, _ readings: [Reading]) -> some View {
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
      ForEach(readings) { reading in
        VStack(alignment: .leading, spacing: 4) {
          Tag(title: reading.label, color: reading.color)
          Figure(value: reading.value, unit: reading.unit, size: 22)
          if let value = reading.progress {
            Bar(value: value, color: reading.color, height: 4)
          } else {
            Bar(value: 0, color: reading.color, height: 4).opacity(0)
          }
        }
      }
    }
  }
}
