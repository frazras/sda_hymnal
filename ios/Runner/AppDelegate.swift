import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var midiPlayerBridge: MidiPlayerBridge?
  private var appIconBridge: AppIconBridge?
  private var analyticsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    analyticsChannel = FlutterMethodChannel(name: "sdahymnal/analytics_storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    analyticsChannel?.setMethodCallHandler { call, result in
      guard call.method == "directory" else { result(FlutterMethodNotImplemented); return }
      do {
        var directory = try FileManager.default.url(for: .applicationSupportDirectory,
          in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("analytics", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        result(directory.path)
      } catch {
        result(FlutterError(code: "STORAGE", message: "Analytics storage unavailable", details: nil))
      }
    }
    midiPlayerBridge = MidiPlayerBridge(
      messenger: engineBridge.applicationRegistrar.messenger())
    appIconBridge = AppIconBridge(
      messenger: engineBridge.applicationRegistrar.messenger())
  }
}
