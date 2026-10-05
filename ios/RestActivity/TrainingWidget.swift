import SwiftUI
import WidgetKit

/// 訓練: the last workout and how the week has gone.
struct TrainingWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "training", provider: SnapshotProvider()) { entry in
      TrainingView(entry: entry).opens("training").widgetFrame()
    }
    .configurationDisplayName(WidgetNames.name("training"))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

private struct TrainingView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, module: "training", key: "training", color: Palette.training) {
      snapshot in
      if let workout = snapshot.training {
        let when = day(workout.date)
        switch family {
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.words("training")).font(.headline).widgetAccentable()
            Text(workout.name).font(.system(size: 15, weight: .bold)).lineLimit(1)
            Text("\(when) · \(workout.detail)").font(.caption).lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
          HStack(alignment: .top, spacing: 18) {
            last(snapshot, workout, when: when)
            if snapshot.goal.enabled, let target = snapshot.goal.target {
              let week = snapshot.week(at: entry.date)
              VStack(alignment: .leading, spacing: 8) {
                caption(snapshot.words("goal"))
                Figure(value: "\(week.active) / \(target)", size: 24)
                WeekDots(days: week.days, now: entry.date, diameter: 16)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        default:
          last(snapshot, workout, when: when)
        }
      } else {
        ModuleOff(snapshot: snapshot, key: "training", color: Palette.training)
      }
    }
  }

  private func last(_ snapshot: WidgetSnapshot, _ workout: WidgetSnapshot.Training, when: String)
    -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      Tag(title: snapshot.words("training"), color: Palette.training)
      Spacer(minLength: 0)
      Text(workout.name)
        .font(.system(size: 19, weight: .heavy))
        .foregroundStyle(Palette.primary)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      caption(workout.detail)
      caption(when)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  /// How long ago a workout was, in days, the way the system says it:
  /// today, yesterday, 2 days ago. Counted from the day the widget is
  /// drawn for, not the day it was made on.
  private func day(_ date: Date) -> String {
    let calendar = Calendar.current
    let days =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: entry.date)
      ).day ?? 0
    return RelativeDateTimeFormatter().localizedString(from: DateComponents(day: -max(days, 0)))
  }
}
