import SwiftUI
import WidgetKit

/// 喝水: the day's water, as the level the water tile on Today fills to.
struct WaterWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "water", provider: SnapshotProvider()) { entry in
      WaterView(entry: entry)
        .opens("water")
        .widgetFrame(
          WaterLevel(
            value: progress(Double(entry.water?.ml ?? 0), of: entry.water?.reference.map(Double.init))))
    }
    .configurationDisplayName(WidgetNames.name("water"))
    .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
  }
}

private struct WaterView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, module: "water", key: "water", color: Palette.water) { snapshot in
      let water = entry.water ?? snapshot.water
      let level = progress(Double(water.ml), of: water.reference.map(Double.init))
      switch family {
      case .accessoryCircular:
        Gauge(value: level) {
          Image(systemName: "drop.fill")
        } currentValueLabel: {
          Text(grouped(water.ml)).font(.system(size: 13, weight: .bold)).minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .healthFigure()
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 2) {
          Text(snapshot.words("water")).font(.headline).widgetAccentable()
          Text(
            water.reference == nil
              ? "\(grouped(water.ml)) mL" : "\(grouped(water.ml)) / \(grouped(water.reference ?? 0)) mL"
          )
          .font(.system(size: 15, weight: .bold))
          if water.reference != nil {
            Gauge(value: level) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
          } else if let times = water.timesText {
            Text(times).font(.caption)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthFigure()
      default:
        VStack(alignment: .leading, spacing: 4) {
          Tag(title: snapshot.words("water"), color: Palette.water)
          Spacer(minLength: 0)
          if water.times == 0 {
            caption(snapshot.words("empty"))
          } else {
            Figure(value: grouped(water.ml), unit: "mL", size: 32)
            if let reference = water.reference {
              caption("/ \(grouped(reference)) mL")
            }
            if let times = water.timesText {
              caption([times, water.lastTime].compactMap { $0 }.joined(separator: " · "))
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .healthFigure()
      }
    }
  }
}
