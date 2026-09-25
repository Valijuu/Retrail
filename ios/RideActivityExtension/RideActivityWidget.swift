import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Lock screen + Dynamic Island presentation of the active ride (Spec 6 §D).
/// Text and accent colors all arrive from Dart; system semantic colors do the
/// rest so both appearances stay legible.
struct RideActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RideActivityAttributes.self) { context in
      LockScreenView(context: context)
        .widgetURL(RideDeepLink.url)
    } dynamicIsland: { context in
      // The island is always dark, so it always takes the dark accent.
      let accent = Color(argb: context.attributes.accentDark)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: Layout.markSpacing) {
            RetrailMark()
            Text(context.state.title)
              .font(.caption)
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.distanceText)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(accent)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            ElapsedText(state: context.state, frozen: context.isShowingStale)
              .font(.title2.weight(.semibold))
            Spacer()
            RideControls(context: context, accent: accent)
          }
        }
      } compactLeading: {
        RetrailMark()
      } compactTrailing: {
        ElapsedText(state: context.state, frozen: context.isShowingStale)
          .font(.caption.weight(.semibold))
          .frame(maxWidth: Layout.compactTimerWidth)
          .foregroundStyle(accent)
      } minimal: {
        RetrailMark()
      }
      .widgetURL(RideDeepLink.url)
      .keylineTint(accent)
    }
  }
}

private enum Layout {
  static let markSize: CGFloat = 24
  static let markSpacing: CGFloat = 6
  static let compactTimerWidth: CGFloat = 52
  static let lockScreenPadding: CGFloat = 16
  static let controlSpacing: CGFloat = 8
  static let staleOpacity: Double = 0.5
}

extension ActivityViewContext {
  /// iOS marks the activity stale once its staleDate passes without an update
  /// — which only happens when the recording app is gone (Dart keeps a live
  /// ride fresh with a keep-alive push well inside that window).
  var isShowingStale: Bool {
    if #available(iOS 16.2, *) { return isStale }
    return false
  }
}

/// Lock screen / banner: mark + title, big timer + distance, controls.
private struct LockScreenView: View {
  let context: ActivityViewContext<RideActivityAttributes>
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let accent = Color(
      argb: colorScheme == .dark
        ? context.attributes.accentDark : context.attributes.accentLight)
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: Layout.markSpacing) {
          RetrailMark()
          Text(context.state.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
        }
        ElapsedText(state: context.state, frozen: context.isShowingStale)
          .font(.system(.largeTitle, design: .rounded).weight(.bold))
        Text(context.state.distanceText)
          .font(.headline)
          .monospacedDigit()
          .foregroundStyle(accent)
      }
      Spacer()
      RideControls(context: context, accent: accent)
    }
    .padding(Layout.lockScreenPadding)
    .opacity(context.isShowingStale ? Layout.staleOpacity : 1)
    .activityBackgroundTint(nil)
  }
}

/// Elapsed ride time. Running: iOS ticks it natively from the snapshot, so
/// Dart doesn't push every second. Paused or stale: frozen at the snapshot's
/// value (a stale activity must not pretend the ride is still counting).
private struct ElapsedText: View {
  let state: RideActivityAttributes.ContentState
  var frozen = false

  var body: some View {
    Group {
      if state.isPaused || frozen {
        Text(Self.format(seconds: state.elapsedSeconds))
      } else {
        Text(timerInterval: state.timerStart...Date.distantFuture, countsDown: false)
      }
    }
    .monospacedDigit()
  }

  private static let secondsPerHour = 3600

  /// `M:SS` / `H:MM:SS`, matching the running timer's own format.
  private static func format(seconds: Int) -> String {
    Duration.seconds(seconds).formatted(
      .time(pattern: seconds >= secondsPerHour ? .hourMinuteSecond : .minuteSecond))
  }
}

/// Pause/Resume + Stop. Interactive buttons need iOS 17 (App Intents); on
/// 16.x the activity is display-only and a tap opens the ride.
private struct RideControls: View {
  let context: ActivityViewContext<RideActivityAttributes>
  let accent: Color

  var body: some View {
    if #available(iOS 17.0, *) {
      let paused = context.state.isPaused
      HStack(spacing: Layout.controlSpacing) {
        Button(
          intent: RideControlIntent(
            control: paused ? RideControlId.resume : RideControlId.pause)
        ) {
          Label(
            paused ? context.attributes.resumeLabel : context.attributes.pauseLabel,
            systemImage: paused ? "play.fill" : "pause.fill")
        }
        Button(intent: RideControlIntent(control: RideControlId.stop)) {
          Label(context.attributes.stopLabel, systemImage: "stop.fill")
        }
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.bordered)
      .buttonBorderShape(.circle)
      .tint(accent)
    }
  }
}

/// The Retrail pin, from the extension's asset catalog.
private struct RetrailMark: View {
  var body: some View {
    Image("RetrailMark")
      .resizable()
      .scaledToFit()
      .frame(width: Layout.markSize, height: Layout.markSize)
      .accessibilityHidden(true)
  }
}
