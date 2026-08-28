import Flutter
import CryptoKit
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  private var messenger: MidiBridgeTestMessenger!
  private var bridge: MidiPlayerBridge?
  private var input: URL!
  private var bank: URL?
  private var created: [StubMidiPlayback] = []
  private var activationCount = 0
  private var failActivation = false
  private var failCreation = false

  override func setUpWithError() throws {
    try super.setUpWithError()
    input = FileManager.default.temporaryDirectory
      .appendingPathComponent("hymnal-midi-test-\(UUID().uuidString).mid")
    try Data([0]).write(to: input, options: .withoutOverwriting)
    bank = Bundle.main.url(forResource: "GeneralUser-GS", withExtension: "sf2")
    onMain {
      messenger = MidiBridgeTestMessenger()
      bridge = MidiPlayerBridge(messenger: messenger, makePlayer: { [unowned self] _, _ in
        if self.failCreation { throw NSError(domain: "MIDI test", code: 1) }
        let player = StubMidiPlayback()
        self.created.append(player)
        return player
      }, soundbankURL: { [unowned self] in self.bank }, activateAudioSession: { [unowned self] in
        self.activationCount += 1
        if self.failActivation { throw NSError(domain: "MIDI test", code: 2) }
      })
    }
  }

  override func tearDownWithError() throws {
    _ = try? invoke("dispose")
    onMain { bridge = nil; messenger = nil }
    if let input = input { try FileManager.default.removeItem(at: input) }
    try super.tearDownWithError()
  }

  func testBundledBankIsTheVerifiedCompatibleDerivative() throws {
    let data = try Data(contentsOf: XCTUnwrap(bank))
    XCTAssertEqual(data.count, 32_331_172)
    let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    XCTAssertEqual(hash, "4a51f4cb5919ed9f552d9cb2c6f6b925bf8dcefc07828323ea2f5bf17fb4bc99")
    XCTAssertNotNil(Bundle.main.url(forResource: "GeneralUser-GS-LICENSE", withExtension: "txt"))
  }

  func testPauseSeekResumeStopRateAndDispose() throws {
    _ = try invoke("setRate", 1.5)
    XCTAssertEqual(try invoke("load", input.path) as? Double, 12)
    let player = try XCTUnwrap(created.last)
    XCTAssertTrue(player.prepared)
    XCTAssertEqual(player.rate, 1.5)
    _ = try invoke("play")
    _ = try invoke("play")
    XCTAssertEqual(player.callbacks.count, 1, "Repeated play must not register another completion")
    player.currentPosition = 3
    _ = try invoke("pause")
    XCTAssertFalse(player.isPlaying)
    XCTAssertEqual(try position(), 3)
    _ = try invoke("seek", ["seconds": 4.25])
    XCTAssertFalse(player.isPlaying, "Seeking a paused hymn must keep it paused")
    _ = try invoke("play")
    XCTAssertEqual(try position(), 4.25)
    XCTAssertTrue(player.isPlaying)
    XCTAssertEqual(activationCount, 3, "Load, start and resume each activate audio")
    _ = try invoke("seek", 999.0)
    XCTAssertEqual(try position(), 12)
    _ = try invoke("stop")
    XCTAssertEqual(try position(), 0)
    XCTAssertFalse(player.isPlaying)
    _ = try invoke("load", input.path)
    XCTAssertEqual(created.last?.rate, 1.5, "Speed survives replacement")
    _ = try invoke("dispose")
    XCTAssertEqual(try position(), 0)
    XCTAssertEqual((try invoke("getDiagnostics") as? [String: Any])?["loaded"] as? Bool, false)
    assertError("NOT_LOADED") { _ = try invoke("play") }
  }

  func testLatePauseCallbackCannotFinishResumedPlaybackAndCompletionIsOnceOnly() throws {
    _ = try invoke("load", input.path)
    _ = try invoke("play")
    let player = try XCTUnwrap(created.last)
    let oldCallback = try XCTUnwrap(player.callbacks.first)
    _ = try invoke("pause")
    _ = try invoke("play")
    player.currentPosition = player.duration
    oldCallback()
    drainCallbacks()
    XCTAssertTrue(messenger.outgoing.isEmpty)
    player.isPlaying = false
    let currentCallback = try XCTUnwrap(player.callbacks.last)
    currentCallback()
    currentCallback()
    drainCallbacks()
    XCTAssertEqual(messenger.outgoing.map(\.method), ["onComplete"])
    _ = try invoke("play")
    XCTAssertEqual(try position(), 0, "A naturally finished hymn can replay")
  }

  func testReplacementAndStopInvalidatePreviousCompletions() throws {
    _ = try invoke("load", input.path)
    _ = try invoke("play")
    let oldPlayer = try XCTUnwrap(created.last)
    let oldCallback = try XCTUnwrap(oldPlayer.callbacks.last)
    _ = try invoke("load", input.path)
    _ = try invoke("play")
    let replacement = try XCTUnwrap(created.last)
    replacement.currentPosition = replacement.duration
    oldCallback()
    drainCallbacks()
    XCTAssertTrue(messenger.outgoing.isEmpty)
    XCTAssertFalse(oldPlayer.isPlaying)
    let replacedCallback = try XCTUnwrap(replacement.callbacks.last)
    _ = try invoke("stop")
    _ = try invoke("play")
    replacement.currentPosition = replacement.duration
    replacedCallback()
    drainCallbacks()
    XCTAssertTrue(messenger.outgoing.isEmpty)
  }

  func testFailedReplacementPreservesThePlayableHymn() throws {
    _ = try invoke("load", input.path)
    _ = try invoke("play")
    let original = try XCTUnwrap(created.last)
    original.currentPosition = 5
    failCreation = true
    assertError("LOAD_FAILED") { _ = try invoke("load", input.path) }
    XCTAssertTrue(original.isPlaying)
    XCTAssertEqual(try position(), 5)
    XCTAssertEqual(original.stops, 0)
    XCTAssertEqual(created.count, 1)
  }

  func testAudioActivationFailureDoesNotPretendToPlay() throws {
    _ = try invoke("load", input.path)
    failActivation = true
    assertError("AUDIO_SESSION") { _ = try invoke("play") }
    XCTAssertFalse(try XCTUnwrap(created.last).isPlaying)
    XCTAssertEqual(created.last?.callbacks.count, 0)
    failActivation = false
    _ = try invoke("play")
    XCTAssertTrue(try XCTUnwrap(created.last).isPlaying)
  }

  func testInvalidInputsAndMissingSoundbankAreReported() throws {
    assertError("INVALID_ARGUMENT") { _ = try invoke("load", "relative.mid") }
    assertError("FILE_NOT_FOUND") { _ = try invoke("load", input.path + ".missing") }
    assertError("INVALID_ARGUMENT") { _ = try invoke("seek", Double.nan) }
    for rate in [Double.nan, Double.infinity, 0, -1, Double.greatestFiniteMagnitude] {
      assertError("INVALID_RATE") { _ = try invoke("setRate", rate) }
    }
    bank = nil
    assertError("SOUNDBANK_MISSING") { _ = try invoke("load", input.path) }
    XCTAssertTrue(created.isEmpty)
  }

  private func invoke(_ method: String, _ arguments: Any? = nil) throws -> Any? {
    try onMain { try messenger.invoke(method, arguments: arguments) }
  }

  private func position() throws -> Double {
    try XCTUnwrap(try invoke("getPosition") as? NSNumber).doubleValue
  }

  private func assertError(_ code: String, action: () throws -> Void,
                           file: StaticString = #filePath, line: UInt = #line) {
    do { try action(); XCTFail("Expected \(code)", file: file, line: line) }
    catch let error as MidiBridgeTestError { XCTAssertEqual(error.code, code, file: file, line: line) }
    catch { XCTFail("Unexpected \(error)", file: file, line: line) }
  }

  private func drainCallbacks() {
    let drained = expectation(description: "main-thread completion delivery")
    DispatchQueue.main.async { drained.fulfill() }
    wait(for: [drained], timeout: 2)
  }

  private func onMain<T>(_ operation: () throws -> T) rethrows -> T {
    if Thread.isMainThread { return try operation() }
    return try DispatchQueue.main.sync(execute: operation)
  }
}

private final class StubMidiPlayback: MidiPlayback {
  let duration: TimeInterval = 12
  var currentPosition: TimeInterval = 0
  var isPlaying = false
  var rate: Float = 1
  var prepared = false
  var stops = 0
  var callbacks: [() -> Void] = []
  func prepareToPlay() { prepared = true }
  func play(_ completion: @escaping () -> Void) {
    isPlaying = true
    callbacks.append(completion)
  }
  func stop() { stops += 1; isPlaying = false; currentPosition = 0 }
}

private struct MidiBridgeTestError: Error, CustomStringConvertible {
  let code: String
  let message: String
  var description: String { "\(code): \(message)" }
}

/// A real FlutterMethodChannel still performs both directions of encoding. This
/// messenger replaces only the Dart transport, not the bridge or audio backend.
private final class MidiBridgeTestMessenger: NSObject, FlutterBinaryMessenger {
  private static let channelName = "sdahymnal/midi"
  private let codec = FlutterStandardMethodCodec.sharedInstance()
  private var connections: [String: (id: FlutterBinaryMessengerConnection,
                                      handler: FlutterBinaryMessageHandler)] = [:]
  private var nextConnection: FlutterBinaryMessengerConnection = 0
  private(set) var outgoing: [FlutterMethodCall] = []
  var observer: ((FlutterMethodCall) -> Void)?

  func send(onChannel channel: String, message: Data?) {
    send(onChannel: channel, message: message, binaryReply: nil)
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    if channel == Self.channelName, let message = message {
      let call = codec.decodeMethodCall(message)
      outgoing.append(call)
      observer?(call)
    }
    callback?(codec.encodeSuccessEnvelope(nil))
  }

  func setMessageHandlerOnChannel(_ channel: String,
                                 binaryMessageHandler handler: FlutterBinaryMessageHandler?)
    -> FlutterBinaryMessengerConnection {
    nextConnection += 1
    if let handler = handler {
      connections[channel] = (nextConnection, handler)
    } else {
      connections.removeValue(forKey: channel)
    }
    return nextConnection
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {
    if let channel = connections.first(where: { $0.value.id == connection })?.key {
      connections.removeValue(forKey: channel)
    }
  }

  func invoke(_ method: String, arguments: Any?) throws -> Any? {
    guard let connection = connections[Self.channelName] else {
      throw MidiBridgeTestError(code: "NO_HANDLER", message: "Native channel is not registered")
    }
    let request = codec.encode(FlutterMethodCall(methodName: method, arguments: arguments))
    var replied = false
    var envelope: Data?
    connection.handler(request) { response in
      replied = true
      envelope = response
    }
    // Production bridge control methods respond synchronously. A missing reply
    // is reported directly instead of waiting for a nonexistent Dart VM.
    guard replied else {
      throw MidiBridgeTestError(code: "NO_REPLY", message: "\(method) did not reply")
    }
    guard let envelope = envelope else {
      throw MidiBridgeTestError(code: "NOT_IMPLEMENTED", message: method)
    }
    let result = codec.decodeEnvelope(envelope)
    if let error = result as? FlutterError {
      throw MidiBridgeTestError(code: error.code, message: error.message ?? method)
    }
    return result
  }
}
