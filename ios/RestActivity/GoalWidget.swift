import SwiftUI
import WidgetKit

/// 每週目標: the days of this week with something done, against the goal,
/// counted here from the days the app wrote so the week turns over on its
/// own.
struct GoalWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "goal", provider: SnapshotProvider()) { entry in
      GoalView(entry: entry).opens("goal").widgetFrame()
    }
    .configurationDisplayName(WidgetNames.name("goal"))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
  }
}

private struct GoalView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, key: "goal", color: Palette.training) { snapshot in
      if snapshot.goal.enabled, let target = snapshot.goal.target {
        let week = snapshot.week(at: entry.date)
        let done = progress(Double(week.active), of: Double(target))
        switch family {
        case .accessoryCircular:
          Gauge(value: done) {
            Image(systemName: "checkmark")
          } currentValueLabel: {
            Text("\(week.active)/\(target)").font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.6)
          }
          .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 3) {
            HStack {
              Text(snapshot.words("goal")).font(.headline).widgetAccentable()
              Spacer()
              Text("\(week.active) / \(target)").font(.system(size: 15, weight: .bold))
            }
            WeekDots(days: week.days, now: entry.date, diameter: 12)
          }
        case .systemMedium:
          VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
              Tag(title: snapshot.words("goal"), color: Palette.training)
              Spacer()
              if let streak = snapshot.goal.streakText { caption(streak) }
            }
            Figure(value: "\(week.active) / \(target)", size: 30)
            WeekDots(days: week.days, now: entry.date)
          }
        default:
          VStack(alignment: .leading, spacing: 6) {
            Tag(title: snapshot.words("goal"), color: Palette.training)
            Ring(value: done, color: Palette.training) {
              Figure(value: "\(week.active)/\(target)", size: 22)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            if let streak = snapshot.goal.streakText { caption(streak) }
          }
        }
      } else {
        ModuleOff(snapshot: snapshot, key: "goal", color: Palette.training)
      }
    }
  }
}
