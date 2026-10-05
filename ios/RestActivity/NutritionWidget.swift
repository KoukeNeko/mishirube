import SwiftUI
import WidgetKit

/// 飲食: the day's energy against its target, and the three macronutrients.
struct NutritionWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "nutrition", provider: SnapshotProvider()) { entry in
      NutritionView(entry: entry).opens("nutrition").widgetFrame()
    }
    .configurationDisplayName(WidgetNames.name("nutrition"))
    .supportedFamilies([
      .systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline,
    ])
  }
}

private struct NutritionView: View {
  let entry: SnapshotEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    SnapshotContent(entry: entry, module: "nutrition", key: "nutrition", color: Palette.nutrition) {
      snapshot in
      let n = entry.nutrition ?? snapshot.nutrition
      switch family {
      case .accessoryCircular:
        Gauge(value: progress(n.kcal, of: n.kcalTarget)) {
          Image(systemName: "flame.fill")
        } currentValueLabel: {
          Text(grouped(n.kcal)).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .healthFigure()
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 2) {
          Text(snapshot.words("nutrition")).font(.headline).widgetAccentable()
          Text("\(grouped(n.kcal)) kcal").font(.system(size: 16, weight: .bold))
          if n.kcalTarget != nil {
            Gauge(value: progress(n.kcal, of: n.kcalTarget)) { EmptyView() }
              .gaugeStyle(.accessoryLinearCapacity)
          } else {
            Text("\(snapshot.words("protein")) \(grouped(n.protein)) g").font(.caption)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .healthFigure()
      case .accessoryInline:
        Text("\(snapshot.words("nutrition")) \(grouped(n.kcal)) kcal").healthFigure()
      case .systemMedium:
        HStack(spacing: 18) {
          energy(snapshot, n).frame(width: 104, height: 104)
          VStack(alignment: .leading, spacing: 9) {
            Tag(title: snapshot.words("nutrition"), color: Palette.nutrition)
            macro(snapshot.words("protein"), n.protein, n.proteinTarget, Palette.protein)
            macro(snapshot.words("carb"), n.carb, n.carbTarget, Palette.carb)
            macro(snapshot.words("fat"), n.fat, n.fatTarget, Palette.fat)
          }
        }
        .healthFigure()
      default:
        VStack(alignment: .leading, spacing: 6) {
          Tag(title: snapshot.words("nutrition"), color: Palette.nutrition)
          energy(snapshot, n).frame(maxWidth: .infinity)
        }
        .healthFigure()
      }
    }
  }

  /// The ring: what is left of the target, or what has been eaten while
  /// there is none.
  private func energy(_ snapshot: WidgetSnapshot, _ n: WidgetSnapshot.Nutrition) -> some View {
    let left = max((n.kcalTarget ?? 0) - n.kcal, 0)
    return Ring(value: progress(n.kcal, of: n.kcalTarget), color: Palette.nutrition) {
      VStack(spacing: 0) {
        Figure(value: grouped(n.kcalTarget == nil ? n.kcal : left), size: 22)
        caption(n.kcalTarget == nil ? "kcal" : snapshot.words("remainingKcal"))
      }
      .padding(.horizontal, 10)
    }
  }

  private func macro(_ label: String, _ grams: Double, _ target: Double?, _ color: Color) -> some View {
    VStack(spacing: 3) {
      HStack {
        caption(label)
        Spacer(minLength: 4)
        Text(target == nil ? "\(grouped(grams)) g" : "\(grouped(grams)) / \(grouped(target ?? 0)) g")
          .font(.system(size: 12, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(Palette.primary)
      }
      Bar(value: progress(grams, of: target), color: color, height: 4)
    }
  }
}
