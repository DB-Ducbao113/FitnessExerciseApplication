import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
      WorkoutLiveActivityLockScreenView(context: context)
        .activityBackgroundTint(Color.black.opacity(0.88))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 4) {
            Text(context.attributes.workoutName.uppercased())
              .font(.caption2.weight(.bold))
              .foregroundStyle(.cyan)
            Text(_statusTitle(context.state.status))
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 6) {
            _AppLogoBadge()
            Text("PACE")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white.opacity(0.55))
            Text(_paceText(context.state.avgSpeedKmh))
              .font(.caption.monospacedDigit().weight(.semibold))
              .foregroundStyle(.white)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 16) {
            _MetricChip(title: "TIME", value: _durationText(context.state.durationSeconds))
            _MetricChip(title: "DIST", value: _distanceCompactText(context.state.distanceMeters))
            _MetricChip(title: "CAL", value: "\(context.state.caloriesBurned)")
          }
        }
      } compactLeading: {
        _AppLogoBadge(size: 18, cornerRadius: 5)
      } compactTrailing: {
        Text(_distanceCompactText(context.state.distanceMeters))
          .font(.caption2.monospacedDigit().weight(.bold))
          .foregroundStyle(.white)
      } minimal: {
        _AppLogoBadge(size: 20, cornerRadius: 6)
      }
    }
  }
}

private struct WorkoutLiveActivityLockScreenView: View {
  let context: ActivityViewContext<WorkoutLiveActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(context.attributes.workoutName.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.cyan)
          Text(_statusTitle(context.state.status))
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 8) {
          _AppLogoBadge(size: 34, cornerRadius: 10)
          Text(_distanceText(context.state.distanceMeters))
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
        }
      }

      HStack(spacing: 10) {
        _MetricCard(title: "Time", value: _durationText(context.state.durationSeconds))
        _MetricCard(title: "Pace", value: _paceText(context.state.avgSpeedKmh))
        _MetricCard(title: "Distance", value: _distanceText(context.state.distanceMeters))
        _MetricCard(title: "Calories", value: "\(context.state.caloriesBurned)")
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
  }
}

private struct _MetricCard: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white.opacity(0.55))
      Text(value)
        .font(.subheadline.monospacedDigit().weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
  }
}

private struct _MetricChip: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white.opacity(0.6))
      Text(value)
        .font(.footnote.monospacedDigit().weight(.semibold))
        .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct _AppLogoBadge: View {
  var size: CGFloat = 24
  var cornerRadius: CGFloat = 8

  var body: some View {
    Image("LiveActivityLogo")
      .resizable()
      .scaledToFill()
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color.white.opacity(0.12), lineWidth: 1)
      )
  }
}

private func _statusTitle(_ status: String) -> String {
  switch status.lowercased() {
  case "paused":
    return "Paused"
  case "ended":
    return "Finished"
  default:
    return "Recording"
  }
}

private func _statusSymbol(_ status: String) -> String {
  switch status.lowercased() {
  case "paused":
    return "pause.circle.fill"
  case "ended":
    return "checkmark.circle.fill"
  default:
    return "figure.run.circle.fill"
  }
}

private func _durationText(_ seconds: Int) -> String {
  let hours = seconds / 3600
  let minutes = (seconds % 3600) / 60
  let remainingSeconds = seconds % 60
  if hours > 0 {
    return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
  }
  return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private func _distanceText(_ meters: Double) -> String {
  let distanceKm = meters / 1000.0
  return String(format: "%.2f km", distanceKm)
}

private func _distanceCompactText(_ meters: Double) -> String {
  let distanceKm = meters / 1000.0
  return String(format: "%.1fkm", distanceKm)
}

private func _paceText(_ kmh: Double) -> String {
  if kmh <= 0.05 {
    return "--"
  }
  let totalSeconds = Int((3600.0 / kmh).rounded())
  let minutes = totalSeconds / 60
  let seconds = totalSeconds % 60
  return String(format: "%d:%02d/km", minutes, seconds)
}
