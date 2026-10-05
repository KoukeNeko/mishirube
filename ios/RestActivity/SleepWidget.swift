import SwiftUI
import WidgetKit

/// 睡眠: last night against the night the person aims for, and the week's.
struct SleepWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "sleep", provider: SnapshotProvider()) { entry in
      SleepView(entry: entry).opens("sleep").widgetFrame()
    }
    .configurationDisplayName(WidgetNames.name("sleep"))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
  }
}

private struct SleepView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, module: "sleep", key: "sleep", color: Palette.sleep) { snapshot in
      let sleep = snapshot.sleep
      if let minutes = sleep.asleepMinutes, let text = sleep.asleepText {
        let goal = sleep.goalMinutes.map(Double.init)
        let done = progress(Double(minutes), of: goal ?? 480)
        switch family {
        case .accessoryCircular:
          Gauge(value: done) {
            Image(systemName: "bed.double.fill")
          } currentValueLabel: {
            Text(text).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.6)
          }
          .gaugeStyle(.accessoryCircularCapacity)
          .healthFigure()
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.words("sleep")).font(.headline).widgetAccentable()
            Text(text).font(.system(size: 16, weight: .bold))
            Gauge(value: done) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .healthFigure()
        case .systemMedium:
          HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
              Tag(title: snapshot.words("sleep"), color: Palette.sleep)
              Figure(value: text, size: 34)
              if goal != nil { Bar(value: done, color: Palette.sleep, height: 4) }
              if let goalText = sleep.goalText { caption(goalText) }
            }
            nights(sleep, now: entry.date)
          }
          .healthFigure()
        default:
          VStack(alignment: .leading, spacing: 6) {
            Tag(title: snapshot.words("sleep"), color: Palette.sleep)
            Spacer(minLength: 0)
            Figure(value: text, size: 36)
            if goal != nil { Bar(value: done, color: Palette.sleep, height: 4) }
            if let goalText = sleep.goalText { caption(goalText) }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .healthFigure()
        }
      } else {
        ModuleOff(snapshot: snapshot, key: "sleep", color: Palette.sleep)
      }
    }
  }

  /// The last seven nights as bars against the night aimed for.
  private func nights(_ sleep: WidgetSnapshot.Sleep, now: Date) -> some View {
    let need = Double(sleep.goalMinutes ?? 480)
    let top = max(need * 1.25, Double(sleep.nights.compactMap(\.minutes).max() ?? 0))
    let calendar = Calendar.current
    return HStack(alignment: .bottom, spacing: 5) {
      ForEach(sleep.nights.indices, id: \.self) { index in
        let night = sleep.nights[index]
        VStack(spacing: 3) {
          ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3).fill(Palette.sleep.opacity(0.18))
            if let minutes = night.minutes {
              GeometryReader { space in
                RoundedRectangle(cornerRadius: 3)
                  .fill(Palette.sleep.opacity(Double(minutes) >= need ? 1 : 0.6))
                  .frame(height: space.size.height * CGFloat(Double(minutes) / top))
                  .frame(maxHeight: .infinity, alignment: .bottom)
              }
            }
          }
          .frame(maxHeight: .infinity)
          Text(letter(night.day, calendar: calendar))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func letter(_ day: String, calendar: Calendar) -> String {
    let parts = day.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
      let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    else { return "" }
    return calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
  }
}
