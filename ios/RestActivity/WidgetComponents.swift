import SwiftUI
import WidgetKit

/// The app's colours, as `AppColors` in `lib/app/theme.dart` has them: a
/// widget is the app's dark, in whatever appearance the home screen is.
enum Palette {
  static let background = Color(hex: 0x0F1110)
  static let surface = Color(hex: 0x1A1C1B)
  static let primary = Color(hex: 0xF2F3F1)
  static let secondary = Color(hex: 0xA3A7A5)
  static let tertiary = Color(hex: 0x6E7371)
  static let outline = Color(hex: 0x2C302E)

  static let training = Color(hex: 0x2EE09A)
  static let nutrition = Color(hex: 0xE5672B)
  static let body = Color(hex: 0x5B8DEF)
  static let water = Color(hex: 0x2FA8E6)
  static let caffeine = Color(hex: 0xA58566)
  static let sleep = Color(hex: 0x8C7CF4)
  static let activity = Color(hex: 0x3FD0D6)
  static let protein = Color(hex: 0xEF7B5C)
  static let carb = Color(hex: 0xF2C66D)
  static let fat = Color(hex: 0x7BD6A0)
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// A figure as the app writes one: grouped, no decimals.
func grouped(_ value: Double) -> String { Int(value.rounded()).formatted() }

func grouped(_ value: Int) -> String { value.formatted() }

/// Minutes as `7:10`, as `formatHoursMinutes` in `lib/shared/format.dart`.
func hoursMinutes(_ minutes: Int) -> String {
  String(format: "%d:%02d", minutes / 60, minutes % 60)
}

func progress(_ value: Double, of total: Double?) -> Double {
  guard let total, total > 0 else { return 0 }
  return min(max(value / total, 0), 1)
}

// MARK: - Frame

extension WidgetFamily {
  var isAccessory: Bool {
    switch self {
    case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
    default: return false
    }
  }
}

/// The widget's background, which the system takes away where the widget
/// has none (StandBy, the Lock Screen, a tinted home screen). Before
/// iOS 17, which has no such thing, it is drawn behind a padded widget.
struct WidgetFrame<Background: View>: ViewModifier {
  @Environment(\.widgetFamily) private var family
  let background: Background

  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) { background }
    } else if family.isAccessory {
      content
    } else {
      content.padding().background(background)
    }
  }
}

extension View {
  func widgetFrame<Background: View>(_ background: Background) -> some View {
    modifier(WidgetFrame(background: background))
  }

  func widgetFrame() -> some View { widgetFrame(Palette.background) }

  /// What the Lock Screen hides while the device is locked, when the
  /// person has asked it to: a health figure is theirs to show.
  func healthFigure() -> some View { self.privacySensitive() }

  /// Opens the app on the page the widget is about.
  func opens(_ page: String) -> some View {
    self.widgetURL(URL(string: "mishirube://\(page)"))
  }
}

// MARK: - Pieces

/// A category's name over its colour, as `CategoryLabel` is in the app.
struct Tag: View {
  let title: String
  let color: Color

  var body: some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 7, height: 7).widgetAccentable()
      Text(title)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(Palette.primary)
        .lineLimit(1)
    }
  }
}

/// A big figure and its unit, as `ValueWithUnit` is.
struct Figure: View {
  let value: String
  var unit: String? = nil
  var size: CGFloat = 30

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: 3) {
      Text(value)
        .font(.system(size: size, weight: .heavy))
        .monospacedDigit()
        .foregroundStyle(Palette.primary)
        .minimumScaleFactor(0.5)
        .lineLimit(1)
      if let unit {
        Text(unit)
          .font(.system(size: max(11, size * 0.45), weight: .semibold))
          .foregroundStyle(Palette.secondary)
          .lineLimit(1)
      }
    }
  }
}

func caption(_ text: String) -> some View {
  Text(text)
    .font(.system(size: 12, weight: .medium))
    .foregroundStyle(Palette.secondary)
    .lineLimit(1)
    .minimumScaleFactor(0.8)
}

/// A ring filling to `value` of 1, with whatever sits inside it.
struct Ring<Content: View>: View {
  let value: Double
  let color: Color
  var lineWidth: CGFloat = 9
  @ViewBuilder var content: () -> Content

  var body: some View {
    ZStack {
      Circle().stroke(color.opacity(0.22), lineWidth: lineWidth)
      Circle()
        .trim(from: 0, to: min(max(value, 0.001), 1))
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .opacity(value > 0 ? 1 : 0)
        .widgetAccentable()
      content()
    }
  }
}

/// A line filling to `value` of 1.
struct Bar: View {
  let value: Double
  let color: Color
  var height: CGFloat = 5

  var body: some View {
    GeometryReader { space in
      ZStack(alignment: .leading) {
        Capsule().fill(color.opacity(0.22))
        Capsule().fill(color)
          .frame(width: max(value > 0 ? height : 0, space.size.width * min(max(value, 0), 1)))
          .widgetAccentable()
      }
    }
    .frame(height: height)
  }
}

/// A week, Monday first, each day a circle filled when something was
/// done on it and ringed when it is today.
struct WeekDots: View {
  let days: [(date: Date, isActive: Bool)]
  let now: Date
  var color: Color = Palette.training
  var diameter: CGFloat = 22

  var body: some View {
    let calendar = Calendar.current
    HStack(spacing: 0) {
      ForEach(days.indices, id: \.self) { index in
        let day = days[index]
        let isToday = calendar.isDate(day.date, inSameDayAs: now)
        VStack(spacing: 4) {
          Text(letter(of: day.date, calendar: calendar))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isToday ? Palette.primary : Palette.secondary)
          ZStack {
            Circle()
              .fill(day.isActive ? color : color.opacity(0.18))
              .widgetAccentable(day.isActive)
            if isToday {
              Circle().stroke(Palette.primary, lineWidth: 1.5).padding(-3)
            }
          }
          .frame(width: diameter, height: diameter)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  private func letter(of date: Date, calendar: Calendar) -> String {
    calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
  }
}

// MARK: - Charts

/// The caffeine left in the body from `curve`: what has happened drawn
/// strong, what is still to come faint, both dashed as an estimate is,
/// the reference a thin level and a dot on now.
struct CurveChart: View {
  let curve: WidgetSnapshot.Caffeine
  let now: Date
  var color: Color = Palette.caffeine
  var showsReference = true
  var lineWidth: CGFloat = 2.5

  var body: some View {
    GeometryReader { space in
      let values = curve.values
      let peak = max(values.max() ?? 1, 1)
      let top: CGFloat = 5
      let width = space.size.width
      let height = space.size.height
      let step = width / CGFloat(max(values.count - 1, 1))
      let point = { (index: Int) -> CGPoint in
        CGPoint(x: CGFloat(index) * step, y: height - CGFloat(values[index] / peak) * (height - top))
      }
      let position = min(
        max(now.timeIntervalSince(curve.startDate) / Double(curve.stepMinutes * 60), 0),
        Double(values.count - 1))
      let nowX = CGFloat(position) * step
      let nowY = height - CGFloat((curve.value(at: now) ?? 0) / peak) * (height - top)
      let dash = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: [5, 5])

      ZStack {
        Path { path in
          path.move(to: CGPoint(x: 0, y: height))
          for index in values.indices { path.addLine(to: point(index)) }
          path.addLine(to: CGPoint(x: width, y: height))
          path.closeSubpath()
        }
        .fill(LinearGradient(
          colors: [color.opacity(0.32), color.opacity(0)], startPoint: .top, endPoint: .bottom))

        Path { path in
          path.move(to: point(0))
          for index in values.indices.dropFirst() { path.addLine(to: point(index)) }
        }
        .stroke(color.opacity(0.45), style: dash)

        Path { path in
          path.move(to: point(0))
          for index in values.indices.dropFirst() where CGFloat(index) * step <= nowX {
            path.addLine(to: point(index))
          }
          path.addLine(to: CGPoint(x: nowX, y: nowY))
        }
        .stroke(color, style: dash)

        if showsReference, curve.reference <= peak {
          let y = height - CGFloat(curve.reference / peak) * (height - top)
          Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
          }
          .stroke(Palette.secondary, lineWidth: 1)
        }

        Path { path in
          path.move(to: CGPoint(x: nowX, y: 0))
          path.addLine(to: CGPoint(x: nowX, y: height))
        }
        .stroke(Palette.secondary.opacity(0.5), lineWidth: 1)

        Circle().fill(Palette.surface).frame(width: 13, height: 13).position(x: nowX, y: nowY)
        Circle().fill(color).frame(width: 9, height: 9).position(x: nowX, y: nowY)
          .widgetAccentable()
      }
    }
  }
}

/// Each weighing a faint dot and the trend through them the line, as
/// `WeightTrendChart` draws them in the app.
struct TrendChart: View {
  let points: [WidgetSnapshot.Weight.Point]
  var color: Color = Palette.body
  var showsDots = true

  var body: some View {
    GeometryReader { space in
      let inset: CGFloat = 6
      let values = points.flatMap { [$0.weight, $0.trend] }
      let low = values.min() ?? 0
      let high = values.max() ?? 1
      let range = abs(high - low) < 0.1 ? 1 : high - low
      let x = { (index: Int) -> CGFloat in
        points.count < 2
          ? space.size.width / 2
          : inset + CGFloat(index) * (space.size.width - inset * 2) / CGFloat(points.count - 1)
      }
      let y = { (value: Double) -> CGFloat in
        inset + CGFloat((high - value) / range) * (space.size.height - inset * 2)
      }
      ZStack {
        if showsDots {
          ForEach(points.indices, id: \.self) { index in
            Circle().fill(color.opacity(0.35)).frame(width: 5, height: 5)
              .position(x: x(index), y: y(points[index].weight))
          }
        }
        Path { path in
          for index in points.indices {
            let at = CGPoint(x: x(index), y: y(points[index].trend))
            index == 0 ? path.move(to: at) : path.addLine(to: at)
          }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        .widgetAccentable()
        if let last = points.indices.last {
          Circle().fill(color).frame(width: 9, height: 9)
            .position(x: x(last), y: y(points[last].trend))
            .widgetAccentable()
        }
      }
    }
  }
}

/// A level rising from the bottom to `value` of the height with a still
/// surface, as the water tile on Today draws its water.
struct WaterLevel: View {
  let value: Double
  var color: Color = Palette.water

  var body: some View {
    GeometryReader { space in
      let level = space.size.height * CGFloat(min(max(value, 0), 1))
      let surface = space.size.height - level
      ZStack(alignment: .bottom) {
        Palette.background
        if level > 0 {
          Path { path in
            path.move(to: CGPoint(x: 0, y: surface + 3))
            path.addCurve(
              to: CGPoint(x: space.size.width, y: surface + 3),
              control1: CGPoint(x: space.size.width * 0.3, y: surface - 3),
              control2: CGPoint(x: space.size.width * 0.7, y: surface + 9))
            path.addLine(to: CGPoint(x: space.size.width, y: space.size.height))
            path.addLine(to: CGPoint(x: 0, y: space.size.height))
            path.closeSubpath()
          }
          .fill(LinearGradient(
            colors: [color.opacity(0.42), color.opacity(0.18)], startPoint: .top, endPoint: .bottom))
        }
      }
    }
  }
}

/// The time of a date, written as the app writes one: 24 hours, `01:40`.
func clock(_ date: Date) -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm"
  return formatter.string(from: date)
}
