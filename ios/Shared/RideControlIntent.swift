// Shared by the Runner app and the RideActivityExtension — member of both
// targets. The extension needs the type to build `Button(intent:)`; iOS runs
// `perform()` in the APP's process (a LiveActivityIntent), where the app is
// alive because it is recording with background location (Spec 6 §D).

import ActivityKit
import AppIntents
import Foundation

@available(iOS 17.0, *)
struct RideControlIntent: LiveActivityIntent {
  // Not user-visible (hidden from Shortcuts/Spotlight via isDiscoverable), so
  // these two literals are exempt from the "all copy comes from ARB" rule.
  static let title: LocalizedStringResource = "Retrail ride control"
  static let isDiscoverable = false

  @Parameter(title: "Control")
  var control: String

  init() {}

  init(control: String) {
    self.control = control
  }

  func perform() async throws -> some IntentResult {
    let id = control
    let attached = await MainActor.run { RideControlSink.isAttached }
    guard attached else {
      // Orphaned activity (the recording process was killed): no ride can be
      // controlled any more, so any button just clears it. The unfinished
      // ride itself is finalized on the next app start.
      for activity in Activity<RideActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      return .result()
    }
    await MainActor.run {
      NotificationCenter.default.post(name: .rideControl, object: id)
    }
    return .result()
  }
}
