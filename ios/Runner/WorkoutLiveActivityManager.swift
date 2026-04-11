import ActivityKit
import Foundation

enum WorkoutLiveActivityError: LocalizedError {
  case unavailable
  case disabled

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "Live Activities require iOS 16.1 or later."
    case .disabled:
      return "Live Activities are disabled on this device."
    }
  }
}

@available(iOS 16.1, *)
final class WorkoutLiveActivityManager {
  static let shared = WorkoutLiveActivityManager()

  private var activity: Activity<WorkoutLiveActivityAttributes>?

  private init() {}

  func syncWorkout(payload: [String: Any]) async throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      throw WorkoutLiveActivityError.disabled
    }

    let attributes = WorkoutLiveActivityAttributes(
      workoutName: stringValue(payload["activityType"], fallback: "Workout")
    )
    let contentState = contentState(from: payload)

    if let activity {
      try await update(activity: activity, state: contentState)
      return
    }

    if #available(iOS 16.2, *) {
      activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: contentState, staleDate: nil),
        pushType: nil
      )
    } else {
      activity = try Activity.request(
        attributes: attributes,
        contentState: contentState,
        pushType: nil
      )
    }
  }

  func endWorkout(payload: [String: Any]) async {
    guard let activity else { return }
    let contentState = contentState(from: payload)

    if #available(iOS 16.2, *) {
      await activity.end(
        ActivityContent(state: contentState, staleDate: Date()),
        dismissalPolicy: .immediate
      )
    } else {
      await activity.end(using: contentState, dismissalPolicy: .immediate)
    }
    self.activity = nil
  }

  private func update(
    activity: Activity<WorkoutLiveActivityAttributes>,
    state: WorkoutLiveActivityAttributes.ContentState
  ) async throws {
    if #available(iOS 16.2, *) {
      await activity.update(ActivityContent(state: state, staleDate: nil))
    } else {
      await activity.update(using: state)
    }
  }

  private func contentState(
    from payload: [String: Any]
  ) -> WorkoutLiveActivityAttributes.ContentState {
    WorkoutLiveActivityAttributes.ContentState(
      activityType: stringValue(payload["activityType"], fallback: "Workout"),
      trackingMode: stringValue(payload["trackingMode"], fallback: "tracking"),
      status: stringValue(payload["status"], fallback: "active"),
      durationSeconds: intValue(payload["durationSeconds"]),
      distanceMeters: doubleValue(payload["distanceMeters"]),
      avgSpeedKmh: doubleValue(payload["avgSpeedKmh"]),
      caloriesBurned: intValue(payload["caloriesBurned"]),
      updatedAt: Date()
    )
  }

  private func stringValue(_ value: Any?, fallback: String) -> String {
    let trimmed = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (trimmed?.isEmpty == false ? trimmed : nil) ?? fallback
  }

  private func doubleValue(_ value: Any?) -> Double {
    if let number = value as? NSNumber { return number.doubleValue }
    if let string = value as? String, let parsed = Double(string) { return parsed }
    return 0
  }

  private func intValue(_ value: Any?) -> Int {
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String, let parsed = Int(string) { return parsed }
    return 0
  }
}
