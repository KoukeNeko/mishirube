import SwiftUI
import WidgetKit

/// 咖啡因: what is likely still in the body, read from the curve at the
/// time the widget is drawn, which is every half hour.
struct CaffeineWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "caffeine", provider: SnapshotProvider(step: 30 * 60)) { entry in
      CaffeineView(entry: entry).opens("caffeine").widgetFrame()
    }
    .configurationDisplayName(WidgetNames.name("caffeine"))
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
  }
}

private struct CaffeineView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, module: "nutrition", key: "caffeine", color: Palette.caffeine) {
      snapshot in
      if let curve = snapshot.caffeine, let mg = curve.value(at: entry.date) {
        switch family {
        case .accessoryCircular:
          Gauge(value: min(mg / max(curve.values.max() ?? 1, curve.reference), 1)) {
            Image(systemName: "cup.and.saucer.fill")
          } currentValueLabel: {
            Text(grouped(mg)).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.6)
          }
          .gaugeStyle(.accessoryCircularCapacity)
          .healthFigure()
        case .accessoryRectangular:
          VStack(alignment: .leading, spacing: 2) {
            HStack {
              Text(snapshot.words("caffeine")).font(.headline).widgetAccentable()
              Spacer()
              Text("\(grouped(mg)) mg").font(.system(size: 15, weight: .bold))
            }
            CurveChart(curve: curve, now: entry.date, showsReference: false, lineWidth: 2)
          }
          .healthFigure()
        case .systemMedium:
          VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
              Tag(title: snapshot.words("caffeine"), color: Palette.caffeine)
              Spacer()
              caption(curve.referenceText)
            }
            Figure(value: grouped(mg), unit: "mg", size: 28)
            CurveChart(curve: curve, now: entry.date)
            HStack {
              caption(clock(curve.startDate))
              Spacer()
              Text(clock(entry.date))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.primary)
              Spacer()
              caption(clock(curve.endDate))
            }
          }
          .healthFigure()
        default:
          VStack(alignment: .leading, spacing: 4) {
            Tag(title: snapshot.words("caffeine"), color: Palette.caffeine)
            Figure(value: grouped(mg), unit: "mg", size: 30)
            CurveChart(curve: curve, now: entry.date, showsReference: false, lineWidth: 2)
              .frame(maxHeight: .infinity)
            caption(curve.referenceText)
          }
          .healthFigure()
        }
      } else {
        ModuleOff(snapshot: snapshot, key: "caffeine", color: Palette.caffeine)
      }
    }
  }
}
