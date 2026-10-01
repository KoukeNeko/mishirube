import ActivityKit
import SwiftUI
import WidgetKit

/// The app's colours this activity draws in, as `AppColors` in
/// `lib/app/theme.dart`: always its dark, on the activity's own dark tint.
private enum Colors {
  static let caffeine = Color(red: 0xA5 / 255, green: 0x85 / 255, blue: 0x66 / 255)
  static let primary = Color(red: 0xF2 / 255, green: 0xF3 / 255, blue: 0xF1 / 255)
  static let secondary = Color(red: 0xA3 / 255, green: 0xA7 / 255, blue: 0xA5 / 255)
}

private let cupSymbol = "cup.and.saucer.fill"

/// Caffeine over the bedtime reference as a Live Activity: the time it
/// falls under it, the time since the last cup running towards then, and
/// the suggested bedtime marked when it comes first. Once that time has
/// passed the content is stale and folds to one line until the app ends
/// it. The lock screen and the expanded Dynamic Island hold the same
/// things in the same places: what and which cup on the left, the time on
/// the right, the track across the bottom.
struct CaffeineActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CaffeineAttributes.self) { context in
      CaffeineLockScreen(state: context.state, isStale: context.isStale)
        .activityBackgroundTint(Color.black.opacity(0.8))
        .activitySystemActionForegroundColor(Colors.caffeine)
        .widgetURL(URL(string: "mishirube://caffeine"))
    } dynamicIsland: { context in
      let state = context.state
      let isStale = context.isStale
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 3) {
            Label(state.title, systemImage: cupSymbol)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(isStale ? Colors.secondary : Colors.caffeine)
            Text(state.cup)
              .font(.caption)
              .foregroundStyle(Colors.secondary)
          }
          .lineLimit(1)
          .padding(.leading, 6)
          .frame(maxHeight: .infinity, alignment: .top)
        }
        DynamicIslandExpandedRegion(.trailing) {
          BelowColumn(state: state, isStale: isStale, size: 30)
            .padding(.trailing, 6)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if !isStale {
            // In from the sides: the island's bottom corners are round
            // enough to cut into text that runs to its edges.
            TrackWithCaption(state: state)
              .padding(.horizontal, 12)
              .padding(.top, 8)
          }
        }
      } compactLeading: {
        Image(systemName: cupSymbol)
          .foregroundStyle(isStale ? Colors.secondary : Colors.caffeine)
      } compactTrailing: {
        Text(state.belowTime)
          .font(.system(.body, design: .rounded).weight(.bold))
          .monospacedDigit()
          .foregroundStyle(isStale ? Colors.secondary : Colors.caffeine)
      } minimal: {
        if isStale {
          Image(systemName: cupSymbol).foregroundStyle(Colors.secondary)
        } else {
          ProgressView(timerInterval: state.cupAt...state.belowAt, countsDown: false) {
            EmptyView()
          } currentValueLabel: {
            Image(systemName: cupSymbol).font(.system(size: 9))
          }
          .progressViewStyle(.circular)
          .tint(Colors.caffeine)
        }
      }
      .keylineTint(Colors.caffeine)
      .widgetURL(URL(string: "mishirube://caffeine"))
    }
  }
}

private struct CaffeineLockScreen: View {
  let state: CaffeineAttributes.ContentState
  let isStale: Bool

  var body: some View {
    if isStale {
      HStack(spacing: 10) {
        CupDisc(size: 28, color: Colors.secondary)
        HStack(spacing: 0) {
          Text(state.title).foregroundStyle(Colors.primary)
          Text(verbatim: " · \(state.belowDoneLabel)").foregroundStyle(Colors.secondary)
        }
        .font(.subheadline)
        .lineLimit(1)
        Spacer(minLength: 8)
        BelowTime(text: state.belowTime, size: 17, isStale: true)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
    } else {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .center, spacing: 10) {
          CupDisc(size: 36, color: Colors.caffeine)
          VStack(alignment: .leading, spacing: 2) {
            Text(state.title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Colors.caffeine)
            Text(state.cup)
              .font(.footnote)
              .foregroundStyle(Colors.secondary)
              .lineLimit(1)
          }
          Spacer(minLength: 8)
          BelowColumn(state: state, isStale: false, size: 34)
        }
        .accessibilityElement(children: .combine)
        TrackWithCaption(state: state)
      }
      .padding(14)
    }
  }
}

/// `低於就寢參考` over the time, or `已低於就寢參考` once it has.
private struct BelowColumn: View {
  let state: CaffeineAttributes.ContentState
  let isStale: Bool
  let size: CGFloat

  var body: some View {
    VStack(alignment: .trailing, spacing: 0) {
      Text(isStale ? state.belowDoneLabel : state.belowLabel)
        .font(.caption)
        .foregroundStyle(Colors.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      BelowTime(text: state.belowTime, size: size, isStale: isStale)
    }
  }
}

/// The time the estimate falls under the reference: the figure the
/// activity is for, fixed rather than counting, as the estimate is no
/// finer than ten minutes.
private struct BelowTime: View {
  let text: String
  let size: CGFloat
  let isStale: Bool

  var body: some View {
    Text(text)
      .font(.system(size: size, weight: isStale ? .bold : .heavy, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(isStale ? Colors.secondary : Colors.primary)
      .lineLimit(1)
  }
}

private struct CupDisc: View {
  let size: CGFloat
  let color: Color

  var body: some View {
    Image(systemName: cupSymbol)
      .font(.system(size: size * 0.5))
      .foregroundStyle(color)
      .frame(width: size, height: size)
      .background(color.opacity(0.2), in: Circle())
  }
}

/// The track, with the cup's time under where it starts and the basis of
/// the estimate under where it ends.
private struct TrackWithCaption: View {
  let state: CaffeineAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      TimeTrack(state: state)
      HStack {
        Text(state.cupTime).monospacedDigit()
        Spacer(minLength: 8)
        Text(state.basis).minimumScaleFactor(0.8)
      }
      .font(.caption2)
      .foregroundStyle(Colors.secondary)
      .lineLimit(1)
    }
  }
}

/// The time since the last cup, running towards when the estimate falls
/// under the reference: drawn by the system, so it moves with the app
/// closed. The suggested bedtime is a tick on it, labelled from the side
/// with room.
private struct TimeTrack: View {
  let state: CaffeineAttributes.ContentState
  @Environment(\.isLuminanceReduced) private var isLuminanceReduced

  private var bedtimeFraction: CGFloat? {
    guard let at = state.bedtimeAt else { return nil }
    let whole = state.belowAt.timeIntervalSince(state.cupAt)
    return CGFloat(min(max(at.timeIntervalSince(state.cupAt) / whole, 0), 1))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      if let fraction = bedtimeFraction, let bedtime = state.bedtime {
        GeometryReader { space in
          let x = space.size.width * fraction
          Text(bedtime)
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(Colors.secondary)
            .lineLimit(1)
            .fixedSize()
            .padding(fraction < 0.5 ? .leading : .trailing, fraction < 0.5 ? x : space.size.width - x)
            .frame(width: space.size.width, alignment: fraction < 0.5 ? .leading : .trailing)
        }
        .frame(height: 13)
      }
      ProgressView(timerInterval: state.cupAt...state.belowAt, countsDown: false) {
        EmptyView()
      } currentValueLabel: {
        EmptyView()
      }
      .progressViewStyle(.linear)
      .tint(isLuminanceReduced ? Colors.caffeine.opacity(0.6) : Colors.caffeine)
      .overlay {
        if let fraction = bedtimeFraction {
          GeometryReader { space in
            Capsule()
              .fill(Colors.primary.opacity(0.75))
              .frame(width: 2, height: 10)
              .position(x: space.size.width * fraction, y: space.size.height / 2)
          }
        }
      }
    }
  }
}
