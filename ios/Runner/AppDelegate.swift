import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var midiPlayerBridge: MidiPlayerBridge?
  private var appIconBridge: AppIconBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    midiPlayerBridge = MidiPlayerBridge(
      messenger: engineBridge.applicationRegistrar.messenger())
    appIconBridge = AppIconBridge(
      messenger: engineBridge.applicationRegistrar.messenger())
  }
}
