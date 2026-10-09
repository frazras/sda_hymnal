import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var midiPlayerBridge: MidiPlayerBridge?
  private var appIconBridge: AppIconBridge?
  private var collationChannel: FlutterMethodChannel?
  private var analyticsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    collationChannel = FlutterMethodChannel(name: "sdahymnal/collation",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    collationChannel?.setMethodCallHandler { call, result in
      guard call.method == "sort" else { result(FlutterMethodNotImplemented); return }
      guard let arguments = call.arguments as? [String: Any],
        let titles = arguments["titles"] as? [String],
        let language = arguments["language"] as? String, !language.isEmpty else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected titles and language", details: nil))
        return
      }
      let locale = Locale(identifier: language)
      result(titles.indices.sorted { a, b in
        let comparison = titles[a].compare(titles[b], options: [.caseInsensitive], locale: locale)
        return comparison == .orderedSame ? a < b : comparison == .orderedAscending
      })
    }
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
