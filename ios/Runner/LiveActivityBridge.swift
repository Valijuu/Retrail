import ActivityKit
import Flutter
import UIKit

/// Native side of the `retrail/live_activity` channel (Spec 6 §A/§D): starts,
/// updates and ends the ride's Live Activity for `LiveActivityService`, and
/// sends the activity's controls back to Dart as `action` calls.
///
/// Registered like a plugin so it receives the app/scene lifecycle through
/// Flutter's own delegates (URL opens, termination) without overriding
/// `FlutterSceneDelegate`.
final class LiveActivityBridge: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private static let channelName = "retrail/live_activity"

  /// An orphaned activity (process killed without `end`) visibly goes stale
  /// instead of pretending to record.
  private static let staleAfter: TimeInterval = 15 * 60

  private let channel: FlutterMethodChannel
  private var controlObserver: NSObjectProtocol?

  /// The previous ActivityKit operation. Each call awaits it first, so e.g. an
  /// `end` can never slip in while a `start` is suspended and leave an orphan.
  /// Only touched on the main thread (channel calls arrive there).
  private var pending: Task<Void, Never>?

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    let bridge = LiveActivityBridge(channel: channel)
    registrar.addMethodCallDelegate(bridge, channel: channel)
    registrar.addApplicationDelegate(bridge)
    registrar.addSceneDelegate(bridge)
    bridge.controlObserver = NotificationCenter.default.addObserver(
      forName: .rideControl, object: nil, queue: .main
    ) { [weak bridge] note in
      if let id = note.object as? String { bridge?.sendAction(id) }
    }
    RideControlSink.isAttached = true
    // A fresh process can't be recording yet: anything still showing was left
    // behind by a killed process (pairs with finalizeUnfinishedRides()).
    bridge.enqueue { await bridge.endAll() }
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    if let controlObserver { NotificationCenter.default.removeObserver(controlObserver) }
    controlObserver = nil
    RideControlSink.isAttached = false
  }

  /// Runs [work] after every previously enqueued operation has finished.
  private func enqueue(_ work: @escaping @MainActor () async -> Void) {
    let previous = pending
    pending = Task { @MainActor in
      await previous?.value
      await work()
    }
  }

  private func sendAction(_ id: String) {
    channel.invokeMethod("action", arguments: id)
  }

  // MARK: - Dart → Swift

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(call.method == "isSupported" ? false : nil)
      return
    }
    switch call.method {
    case "isSupported":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    case "start":
      guard let args = call.arguments as? [String: Any],
        let attributes = Self.attributes(args["attributes"]),
        let state = Self.state(args["content"])
      else { return result(Self.badArguments(call)) }
      enqueue {
        do {
          try await self.start(attributes: attributes, state: state)
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "start_failed", message: error.localizedDescription, details: nil))
        }
      }
    case "update":
      guard let state = Self.state(call.arguments) else {
        return result(Self.badArguments(call))
      }
      enqueue {
        await self.update(state: state)
        result(nil)
      }
    case "end":
      enqueue {
        await self.endAll()
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - ActivityKit

  @available(iOS 16.1, *)
  private func start(
    attributes: RideActivityAttributes, state: RideActivityAttributes.ContentState
  ) async throws {
    await endAll()
    if #available(iOS 16.2, *) {
      _ = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state, staleDate: Self.staleDate()),
        pushType: nil)
    } else {
      _ = try Activity.request(
        attributes: attributes, contentState: state, pushType: nil)
    }
  }

  @available(iOS 16.1, *)
  private func update(state: RideActivityAttributes.ContentState) async {
    for activity in Activity<RideActivityAttributes>.activities {
      if #available(iOS 16.2, *) {
        await activity.update(ActivityContent(state: state, staleDate: Self.staleDate()))
      } else {
        await activity.update(using: state)
      }
    }
  }

  private func endAll() async {
    guard #available(iOS 16.1, *) else { return }
    for activity in Activity<RideActivityAttributes>.activities {
      if #available(iOS 16.2, *) {
        await activity.end(nil, dismissalPolicy: .immediate)
      } else {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
  }

  private static func staleDate() -> Date {
    Date().addingTimeInterval(staleAfter)
  }

  // MARK: - Lifecycle

  /// Best-effort: the app gets only a moment here, so wait briefly for the
  /// async end; the stale date and the next launch's cleanup cover the rest.
  func applicationWillTerminate(_ application: UIApplication) {
    let done = DispatchSemaphore(value: 0)
    Task.detached {
      await self.endAll()
      done.signal()
    }
    _ = done.wait(timeout: .now() + 1)
  }

  /// Tap on the activity (`retrail://ride`) → open the active ride.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    let isRideLink = URLContexts.contains {
      $0.url.scheme == RideDeepLink.scheme && $0.url.host == RideDeepLink.host
    }
    if isRideLink { sendAction(RideControlId.open) }
    return isRideLink
  }

  // MARK: - Argument decoding

  @available(iOS 16.1, *)
  private static func attributes(_ raw: Any?) -> RideActivityAttributes? {
    guard let map = raw as? [String: Any],
      let pauseLabel = map["pauseLabel"] as? String,
      let resumeLabel = map["resumeLabel"] as? String,
      let stopLabel = map["stopLabel"] as? String,
      let accentLight = (map["accentLight"] as? NSNumber)?.intValue,
      let accentDark = (map["accentDark"] as? NSNumber)?.intValue
    else { return nil }
    return RideActivityAttributes(
      pauseLabel: pauseLabel, resumeLabel: resumeLabel, stopLabel: stopLabel,
      accentLight: accentLight, accentDark: accentDark)
  }

  @available(iOS 16.1, *)
  private static func state(_ raw: Any?) -> RideActivityAttributes.ContentState? {
    guard let map = raw as? [String: Any],
      let title = map["title"] as? String,
      let distanceText = map["distanceText"] as? String,
      let isPaused = (map["isPaused"] as? NSNumber)?.boolValue,
      let elapsedSeconds = (map["elapsedSeconds"] as? NSNumber)?.intValue,
      let snapshotEpochMs = (map["snapshotEpochMs"] as? NSNumber)?.intValue
    else { return nil }
    return RideActivityAttributes.ContentState(
      title: title, distanceText: distanceText, isPaused: isPaused,
      elapsedSeconds: elapsedSeconds, snapshotEpochMs: snapshotEpochMs)
  }

  private static func badArguments(_ call: FlutterMethodCall) -> FlutterError {
    FlutterError(code: "bad_arguments", message: call.method, details: nil)
  }
}
