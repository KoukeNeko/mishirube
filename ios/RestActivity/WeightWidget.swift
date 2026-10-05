import SwiftUI
import WidgetKit

/// 體重: the latest weighing and the week's trend through them.
struct WeightWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "weight", provider: SnapshotProvider()) { entry in
      WeightView(entry: entry).opens("weight").widgetFrame()
    }
    .configurationDisplayName(WidgetNames.name("weight"))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  }
}

private struct WeightView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, module: "weight", key: "weight", color: Palette.body) { snapshot in
      let weight = snapshot.weight
      if let kg = weight.kg {
        let text = kg.formatted(.number.precision(.fractionLength(0...1)))
        switch family {
        case .accessoryInline:
          Text("\(snapshot.words("weight")) \(text) kg").healthFigure()
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.words("weight")).font(.headline).widgetAccentable()
            Text("\(text) kg").font(.system(size: 16, weight: .bold))
            if let change = weight.changeText { Text(change).font(.caption) }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .healthFigure()
        case .systemMedium:
          HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
              Tag(title: snapshot.words("weight"), color: Palette.body)
              Spacer(minLength: 0)
              Figure(value: text, unit: "kg", size: 34)
              if let change = weight.changeText { caption(change) }
            }
            .frame(width: 110, alignment: .leading)
            if weight.trend.count >= 2 { TrendChart(points: weight.trend) }
          }
          .healthFigure()
        default:
          VStack(alignment: .leading, spacing: 4) {
            Tag(title: snapshot.words("weight"), color: Palette.body)
            Figure(value: text, unit: "kg", size: 30)
            if let change = weight.changeText { caption(change) }
            if weight.trend.count >= 2 {
              TrendChart(points: weight.trend, showsDots: false).frame(maxHeight: .infinity)
            } else {
              Spacer(minLength: 0)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .healthFigure()
        }
      } else {
        ModuleOff(snapshot: snapshot, key: "weight", color: Palette.body)
      }
    }
  }
}
