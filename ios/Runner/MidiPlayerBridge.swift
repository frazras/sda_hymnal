import AVFoundation
import Flutter

/// Native MIDI playback bridge backed by AVMIDIPlayer.
///
/// Implements the Dart <-> iOS platform-channel contract on 'sdahymnal/midi'.
/// AVMIDIPlayer cannot switch files, so load() recreates the player with the
/// bundled GeneralUser-GS soundbank, re-applying the stored playback rate.
final class MidiPlayerBridge: NSObject {
  private static let channelName = "sdahymnal/midi"
  private static let completionCallback = "onComplete"
  private static let soundbankName = "GeneralUser-GS"

  private let channel: FlutterMethodChannel
  private var player: AVMIDIPlayer?
  /// Playback rate multiplier; persists across load()/play() per the contract.
  private var rate: Double = 1.0
  /// Set before any intentional stop (pause/stop/load) so the AVMIDIPlayer
  /// completion handler does not report a natural end back to Dart.
  private var suppressCompletion = false
  private var audioSessionConfigured = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  // MARK: - Method dispatch

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "load":
      guard let path = Self.stringArgument(call, key: "path") else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "load expects an absolute file path string",
          details: nil))
        return
      }
      load(path: path, result: result)
    case "play":
      play(result: result)
    case "pause":
      pause(result: result)
    case "stop":
      stop(result: result)
    case "seek":
      guard let seconds = Self.doubleArgument(call, key: "seconds") else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "seek expects seconds as a number",
          details: nil))
        return
      }
      seek(seconds: seconds, result: result)
    case "setRate":
      guard let newRate = Self.doubleArgument(call, key: "rate") else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "setRate expects a rate multiplier as a number",
          details: nil))
        return
      }
      setRate(newRate, result: result)
    case "getPosition":
      result(player?.currentPosition ?? 0.0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Contract methods

  private func load(path: String, result: FlutterResult) {
    guard let soundbankURL = Bundle.main.url(
      forResource: Self.soundbankName, withExtension: "sf2")
    else {
      result(FlutterError(
        code: "SOUNDBANK_MISSING",
        message: "\(Self.soundbankName).sf2 is not bundled with the app",
        details: nil))
      return
    }
    let midiURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: midiURL.path) else {
      result(FlutterError(
        code: "FILE_NOT_FOUND",
        message: "No MIDI file at \(path)",
        details: nil))
      return
    }

    configureAudioSessionIfNeeded()
    disposeCurrentPlayer()

    do {
      let newPlayer = try AVMIDIPlayer(contentsOf: midiURL, soundBankURL: soundbankURL)
      newPlayer.prepareToPlay()
      newPlayer.rate = Float(rate)
      player = newPlayer
      result(newPlayer.duration)
    } catch {
      result(FlutterError(
        code: "LOAD_FAILED",
        message: "Could not create MIDI player for \(path): \(error.localizedDescription)",
        details: nil))
    }
  }

  private func play(result: FlutterResult) {
    guard let player = player else {
      result(FlutterError(
        code: "NOT_LOADED",
        message: "Call load() before play()",
        details: nil))
      return
    }
    suppressCompletion = false
    player.play { [weak self] in
      // AVMIDIPlayer may invoke this off the main thread; channel callbacks
      // must run on the main thread.
      DispatchQueue.main.async { self?.playbackDidFinish() }
    }
    // AVMIDIPlayer only honors rate reliably while playback is running, so
    // re-apply the stored multiplier after starting as well.
    player.rate = Float(rate)
    result(nil)
  }

  private func pause(result: FlutterResult) {
    guard let player = player else {
      // Nothing loaded; pausing is a harmless no-op.
      result(nil)
      return
    }
    let position = player.currentPosition
    suppressCompletion = true
    if player.isPlaying {
      player.stop()
    }
    // AVMIDIPlayer.stop() preserves currentPosition, but restore it explicitly
    // so pause-then-play resumes at the same spot regardless of OS behavior.
    player.currentPosition = position
    result(nil)
  }

  private func stop(result: FlutterResult) {
    guard let player = player else {
      result(nil)
      return
    }
    suppressCompletion = true
    if player.isPlaying {
      player.stop()
    }
    player.currentPosition = 0
    result(nil)
  }

  private func seek(seconds: Double, result: FlutterResult) {
    guard let player = player else {
      result(nil)
      return
    }
    player.currentPosition = min(max(seconds, 0), player.duration)
    result(nil)
  }

  private func setRate(_ newRate: Double, result: FlutterResult) {
    guard newRate > 0 else {
      result(FlutterError(
        code: "INVALID_RATE",
        message: "Playback rate must be greater than 0 (got \(newRate))",
        details: nil))
      return
    }
    rate = newRate
    player?.rate = Float(newRate)
    result(nil)
  }

  // MARK: - Helpers

  /// Fires 'onComplete' into Dart only when playback reached the natural end.
  /// The play() completion handler also runs after stop()/pause()/load(),
  /// which set suppressCompletion; the position check is a second guard.
  private func playbackDidFinish() {
    guard !suppressCompletion, let player = player else { return }
    guard player.currentPosition >= player.duration - 0.05 else { return }
    channel.invokeMethod(Self.completionCallback, arguments: nil)
  }

  private func disposeCurrentPlayer() {
    guard let current = player else { return }
    suppressCompletion = true
    if current.isPlaying {
      current.stop()
    }
    player = nil
  }

  private func configureAudioSessionIfNeeded() {
    guard !audioSessionConfigured else { return }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default)
      try session.setActive(true)
      audioSessionConfigured = true
    } catch {
      // Playback can still work with the default session; log and continue.
      NSLog("MidiPlayerBridge: failed to configure audio session: %@",
            error.localizedDescription)
    }
  }

  /// Accepts either a bare string argument or a map containing `key`.
  private static func stringArgument(_ call: FlutterMethodCall, key: String) -> String? {
    if let value = call.arguments as? String { return value }
    if let map = call.arguments as? [String: Any] { return map[key] as? String }
    return nil
  }

  /// Accepts either a bare numeric argument or a map containing `key`.
  private static func doubleArgument(_ call: FlutterMethodCall, key: String) -> Double? {
    if let value = call.arguments as? NSNumber { return value.doubleValue }
    if let map = call.arguments as? [String: Any] {
      return (map[key] as? NSNumber)?.doubleValue
    }
    return nil
  }
}
