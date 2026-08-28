import AVFoundation
import Flutter

/// Small injectable surface for deterministic lifecycle tests. Production
/// playback remains AVMIDIPlayer, including its tempo/rate behavior.
protocol MidiPlayback: AnyObject {
  var duration: TimeInterval { get }
  var currentPosition: TimeInterval { get set }
  var isPlaying: Bool { get }
  var rate: Float { get set }
  func prepareToPlay()
  func play(_ completion: @escaping () -> Void)
  func stop()
}

final class SystemMidiPlayback: MidiPlayback {
  private let player: AVMIDIPlayer
  init(midiURL: URL, soundbankURL: URL) throws {
    player = try AVMIDIPlayer(contentsOf: midiURL, soundBankURL: soundbankURL)
  }
  var duration: TimeInterval { player.duration }
  var currentPosition: TimeInterval {
    get { player.currentPosition }
    set { player.currentPosition = newValue }
  }
  var isPlaying: Bool { player.isPlaying }
  var rate: Float {
    get { player.rate }
    set { player.rate = newValue }
  }
  func prepareToPlay() { player.prepareToPlay() }
  func play(_ completion: @escaping () -> Void) { player.play(completion) }
  func stop() { player.stop() }
}

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
  private var player: MidiPlayback?
  private let makePlayer: (URL, URL) throws -> MidiPlayback
  private let soundbankURL: () -> URL?
  private let activateAudioSession: () throws -> Void
  /// Playback rate multiplier; persists across load()/play() per the contract.
  private var rate: Double = 1.0
  /// A boolean alone is insufficient: pause then resume can re-enable a late
  /// callback from the previous play. Every play/stop/load gets a new token.
  private var playbackGeneration = 0
  private var playbackActive = false

  init(messenger: FlutterBinaryMessenger,
       makePlayer: @escaping (URL, URL) throws -> MidiPlayback = {
         try SystemMidiPlayback(midiURL: $0, soundbankURL: $1)
       },
       soundbankURL: @escaping () -> URL? = {
         Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")
       },
       activateAudioSession: @escaping () throws -> Void = {
         let session = AVAudioSession.sharedInstance()
         try session.setCategory(.playback, mode: .default)
         try session.setActive(true)
       }) {
    self.makePlayer = makePlayer
    self.soundbankURL = soundbankURL
    self.activateAudioSession = activateAudioSession
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit { disposeCurrentPlayer() }

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
      guard let seconds = Self.doubleArgument(call, key: "seconds"), seconds.isFinite else {
        result(FlutterError(
          code: "INVALID_ARGUMENT",
          message: "seek expects finite seconds as a number",
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
    case "getDiagnostics":
      let bank = soundbankURL()
      result([
        "soundBankBundled": bank != nil,
        "soundBankBytes": bank.flatMap {
          (try? $0.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        } ?? 0,
        "loaded": player != nil,
        "isPlaying": player?.isPlaying ?? false,
        "rate": rate,
      ])
    case "reset", "dispose":
      disposeCurrentPlayer()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Contract methods

  private func load(path: String, result: FlutterResult) {
    guard let soundbankURL = soundbankURL() else {
      result(FlutterError(
        code: "SOUNDBANK_MISSING",
        message: "\(Self.soundbankName).sf2 is not bundled with the app",
        details: nil))
      return
    }
    guard (path as NSString).isAbsolutePath else {
      result(FlutterError(code: "INVALID_ARGUMENT",
        message: "load expects an absolute file path", details: nil))
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

    do {
      try activateAudioSession()
      let newPlayer = try makePlayer(midiURL, soundbankURL)
      newPlayer.prepareToPlay()
      newPlayer.rate = Float(rate)
      // Prepare first: a malformed replacement must not destroy the current
      // playable hymn. Only the accepted player invalidates its callbacks.
      disposeCurrentPlayer()
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
    if playbackActive && player.isPlaying {
      result(nil)
      return
    }
    do {
      // Other apps/interruption handling may deactivate an already-configured
      // session. Re-activate on every start/resume; do not report false success.
      try activateAudioSession()
    } catch {
      result(FlutterError(code: "AUDIO_SESSION",
        message: "Could not activate MIDI audio: \(error.localizedDescription)", details: nil))
      return
    }
    invalidatePlayback()
    if player.currentPosition >= player.duration { player.currentPosition = 0 }
    let generation = playbackGeneration
    playbackActive = true
    player.play { [weak self] in
      // AVMIDIPlayer may invoke this off the main thread; channel callbacks
      // must run on the main thread.
      DispatchQueue.main.async { self?.playbackDidFinish(generation: generation) }
    }
    // AVMIDIPlayer only honors rate reliably while playback is running, so
    // re-apply the stored multiplier after starting as well.
    player.rate = Float(rate)
    result(nil)
  }

  private func pause(result: FlutterResult) {
    invalidatePlayback()
    guard let player = player else {
      // Nothing loaded; pausing is a harmless no-op.
      result(nil)
      return
    }
    let position = player.currentPosition
    if player.isPlaying {
      player.stop()
    }
    // AVMIDIPlayer.stop() preserves currentPosition, but restore it explicitly
    // so pause-then-play resumes at the same spot regardless of OS behavior.
    player.currentPosition = position
    result(nil)
  }

  private func stop(result: FlutterResult) {
    invalidatePlayback()
    guard let player = player else {
      result(nil)
      return
    }
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
    guard newRate.isFinite, Float(newRate).isFinite, Float(newRate) > 0 else {
      result(FlutterError(
        code: "INVALID_RATE",
        message: "Playback rate must be finite and greater than 0 (got \(newRate))",
        details: nil))
      return
    }
    rate = newRate
    player?.rate = Float(newRate)
    result(nil)
  }

  // MARK: - Helpers

  /// Fires 'onComplete' into Dart only when playback reached the natural end.
  /// Late callbacks cannot finish a resumed or replaced hymn. The position
  /// check is a second guard; invalidation also makes completion one-shot.
  private func playbackDidFinish(generation: Int) {
    guard generation == playbackGeneration, playbackActive,
          let player = player else { return }
    guard player.currentPosition >= player.duration - 0.05 else { return }
    invalidatePlayback()
    channel.invokeMethod(Self.completionCallback, arguments: nil)
  }

  private func invalidatePlayback() {
    playbackGeneration += 1
    playbackActive = false
  }

  private func disposeCurrentPlayer() {
    invalidatePlayback()
    guard let current = player else { return }
    if current.isPlaying {
      current.stop()
    }
    player = nil
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
