import SwiftUI
import WidgetKit

/// Entry point of the RideActivityExtension (Spec 6 §D): only the ride's
/// Live Activity, no home-screen widgets.
@main
struct RideActivityBundle: WidgetBundle {
  var body: some Widget {
    RideActivityWidget()
  }
}
