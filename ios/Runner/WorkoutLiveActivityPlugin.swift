import Flutter
import Foundation

final class WorkoutLiveActivityPlugin: NSObject, FlutterPlugin {
  private static let channelName = "fitness_exercise_application/live_activity"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = WorkoutLiveActivityPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(
        FlutterError(
          code: "unsupported_version",
          message: WorkoutLiveActivityError.unavailable.localizedDescription,
          details: nil
        )
      )
      return
    }

    let payload = call.arguments as? [String: Any] ?? [:]

    switch call.method {
    case "syncWorkout":
      Task {
        do {
          try await WorkoutLiveActivityManager.shared.syncWorkout(payload: payload)
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "sync_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    case "endWorkout":
      Task {
        await WorkoutLiveActivityManager.shared.endWorkout(payload: payload)
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
