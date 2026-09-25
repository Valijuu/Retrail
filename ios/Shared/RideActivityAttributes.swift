// Shared by the Runner app (starts/updates the activity) and the
// RideActivityExtension (renders it) — member of both targets (Spec 6 §D).

import ActivityKit
import SwiftUI

/// The active ride as an ActivityKit Live Activity. Every user-facing string
/// and both accent colors come from Dart (ARB copy + `AppColors.primary`) via
/// the `retrail/live_activity` channel — nothing is hard-coded here.
@available(iOS 16.1, *)
struct RideActivityAttributes: ActivityAttributes {
  /// Mirrors `LiveActivityContent.toMap()` in
  /// `lib/domain/live_activity_snapshot.dart`.
  struct ContentState: Codable, Hashable {
    var title: String
    var distanceText: String
    var isPaused: Bool
    var elapsedSeconds: Int
    var snapshotEpochMs: Int

    /// When a running timer that shows [elapsedSeconds] at the snapshot
    /// started — lets the widget tick natively without a push per second.
    var timerStart: Date {
      Date(timeIntervalSince1970: TimeInterval(snapshotEpochMs) / 1000)
        .addingTimeInterval(-TimeInterval(elapsedSeconds))
    }
  }

  var pauseLabel: String
  var resumeLabel: String
  var stopLabel: String
  /// ARGB ints (`Color.toARGB32()` on the Dart side).
  var accentLight: Int
  var accentDark: Int
}

/// Control ids — the same strings as `RideNotificationIds` in
/// `lib/tracking/ride_notification.dart`, so Dart's shared relay handles them.
enum RideControlId {
  static let pause = "ride_pause"
  static let resume = "ride_resume"
  static let stop = "ride_stop"
  static let open = "ride_open"
}

/// Tapping the activity opens this URL; the Runner maps it to `ride_open`.
enum RideDeepLink {
  static let scheme = "retrail"
  static let host = "ride"
  static var url: URL {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    return components.url!
  }
}

/// Posted in the app process by `RideControlIntent`, observed by
/// `LiveActivityBridge`, which forwards the id to Dart.
extension Notification.Name {
  static let rideControl = Notification.Name("com.retrail.rideControl")
}

/// Whether a Flutter engine is listening for ride controls in this process.
/// False when iOS relaunched a killed app in the background just to run a
/// button's intent: no scene, no engine, no ride — the activity is an orphan.
enum RideControlSink {
  static var isAttached = false
}

extension Color {
  /// A color from an ARGB int as produced by Flutter's `Color.toARGB32()`.
  init(argb: Int) {
    func channel(_ shift: Int) -> Double { Double((argb >> shift) & 0xFF) / 255 }
    self.init(
      .sRGB, red: channel(16), green: channel(8), blue: channel(0),
      opacity: channel(24))
  }
}
