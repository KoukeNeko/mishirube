import SwiftUI
import WidgetKit

/// The names in the widget gallery: the app's own words once it has
/// written them, the English ones before.
enum WidgetNames {
  static func name(_ key: String) -> String {
    (WidgetSnapshot.load()?.text[key]) ?? WidgetSnapshot.fallbackText[key] ?? key
  }
}

/// What every widget shows before the app has run.
struct NeedsApp: View {
  var body: some View {
    Text("MISHIRUBE")
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(Palette.secondary)
  }
}

/// A widget of a module that is turned off.
struct ModuleOff: View {
  @Environment(\.widgetFamily) private var family
  let snapshot: WidgetSnapshot
  let key: String
  let color: Color

  var body: some View {
    if family.isAccessory {
      Text(snapshot.words(key)).font(.caption)
    } else {
      VStack(alignment: .leading, spacing: 6) {
        Tag(title: snapshot.words(key), color: color)
        caption(snapshot.words("empty"))
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// A widget's content once there is a snapshot, and its module is on.
struct SnapshotContent<Content: View>: View {
  let entry: SnapshotEntry
  var module: String? = nil
  let key: String
  let color: Color
  @ViewBuilder var content: (WidgetSnapshot) -> Content

  var body: some View {
    if let snapshot = entry.snapshot {
      if let module, !snapshot.has(module) {
        ModuleOff(snapshot: snapshot, key: key, color: color)
      } else {
        content(snapshot)
      }
    } else {
      NeedsApp()
    }
  }
}
