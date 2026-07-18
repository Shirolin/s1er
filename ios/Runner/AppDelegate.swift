import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.stage1st.s1er/app_icon"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getIcon":
      if let name = UIApplication.shared.alternateIconName, !name.isEmpty {
        result(name)
      } else {
        result("black")
      }
    case "setIcon":
      guard let args = call.arguments as? [String: Any],
            let id = args["id"] as? String else {
        result(
          FlutterError(code: "invalid_args", message: "Missing id", details: nil)
        )
        return
      }
      let targetName: String? = (id == "black") ? nil : id
      if !UIApplication.shared.supportsAlternateIcons {
        result(
          FlutterError(
            code: "unsupported",
            message: "Alternate icons not supported",
            details: nil
          )
        )
        return
      }
      let current = UIApplication.shared.alternateIconName
      if current == targetName || (current == nil && targetName == nil) {
        result(nil)
        return
      }
      UIApplication.shared.setAlternateIconName(targetName) { error in
        if let error = error {
          result(
            FlutterError(
              code: "set_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          result(nil)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
