import Flutter
import UIKit

protocol AppIconApplication: AnyObject {
  var supportsAlternateIcons: Bool { get }
  var alternateIconName: String? { get }
  var applicationState: UIApplication.State { get }
  func setAlternateIconName(_ alternateIconName: String?, completionHandler: ((Error?) -> Void)?)
}

extension UIApplication: AppIconApplication {}

/// Use the public UIKit API, including its normal system confirmation.
/// nil restores the primary (Modern) AppIcon; ClassicIcon is compiled by actool.
final class AppIconBridge {
  private let channel: FlutterMethodChannel
  private let application: AppIconApplication
  private var changing = false

  init(messenger: FlutterBinaryMessenger, application: AppIconApplication = UIApplication.shared) {
    self.application = application
    channel = FlutterMethodChannel(name: "sdahymnal/app_icon", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setDesign" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let design = call.arguments as? String, ["modern", "classic"].contains(design) else {
      result(FlutterError(code: "INVALID_DESIGN", message: "Expected modern or classic", details: nil))
      return
    }
    let name = design == "classic" ? "ClassicIcon" : nil
    guard !changing else {
      result(FlutterError(code: "BUSY", message: "An icon change is already in progress", details: nil))
      return
    }
    // No alerts or unnecessary work on ordinary launches/resumes.
    guard application.alternateIconName != name else { result(nil); return }
    guard application.supportsAlternateIcons else {
      result(FlutterError(code: "UNSUPPORTED", message: "Alternate icons are unavailable", details: nil))
      return
    }
    guard application.applicationState == .active else {
      result(FlutterError(code: "NOT_ACTIVE", message: "Keep the app in the foreground", details: nil))
      return
    }
    changing = true
    application.setAlternateIconName(name) { [weak self] error in
      // UIKit may invoke the completion off the main queue.
      DispatchQueue.main.async {
        self?.changing = false
        if let error = error {
          result(FlutterError(code: "ICON_CHANGE_FAILED", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    }
  }
}
