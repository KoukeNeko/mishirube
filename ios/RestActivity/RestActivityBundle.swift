import ActivityKit
import SwiftUI
import WidgetKit

@main
struct RestActivityBundle: WidgetBundle {
  var body: some Widget {
    RestActivityWidget()
  }
}

/// The app's green, as `AppColors.training` in `lib/app/theme.dart`.
private let training = Color(red: 0x2E / 255, green: 0xE0 / 255, blue: 0x9A / 255)

struct RestActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestAttributes.self) { context in
      HStack(alignment: .center, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Text(context.state.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(training)
          Text(context.state.body)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .monospacedDigit()
          .multilineTextAlignment(.trailing)
          .frame(width: 120, alignment: .trailing)
      }
      .padding(16)
      .activityBackgroundTint(Color.black.opacity(0.8))
      .activitySystemActionForegroundColor(training)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Text(context.state.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(training)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
            .font(.title2.weight(.bold))
            .monospacedDigit()
            .frame(width: 80, alignment: .trailing)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(context.state.body)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      } compactLeading: {
        Image(systemName: "timer").foregroundStyle(training)
      } compactTrailing: {
        Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
          .monospacedDigit()
          .frame(width: 44)
      } minimal: {
        Image(systemName: "timer").foregroundStyle(training)
      }
    }
  }
}
