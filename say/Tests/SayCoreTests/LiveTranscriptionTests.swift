import Foundation
import XCTest

@testable import SayCore

@MainActor
final class LiveTranscriptionTests: XCTestCase {
  func testSessionUsesLiveModelAndManualCommit() throws {
    let message = try object(LiveTranscriptionClient.configuration())
    XCTAssertEqual(message["type"] as? String, "session.update")
    let session = try XCTUnwrap(message["session"] as? [String: Any])
    XCTAssertEqual(session["type"] as? String, "transcription")
    let audio = try XCTUnwrap(session["audio"] as? [String: Any])
    let input = try XCTUnwrap(audio["input"] as? [String: Any])
    let format = try XCTUnwrap(input["format"] as? [String: Any])
    XCTAssertEqual(format["type"] as? String, "audio/pcm")
    XCTAssertEqual(format["rate"] as? Int, 24000)
    XCTAssertTrue(input["turn_detection"] is NSNull)
    let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])
    XCTAssertEqual(transcription["model"] as? String, "gpt-live-transcribe")
    XCTAssertNil(transcription["language"])
  }

  func testAudioWaitsForSessionAndCommitFollowsEveryChunk() async throws {
    let socket = MockTranscriptionSocket()
    var request: URLRequest?
    let client = LiveTranscriptionClient {
      request = $0
      return socket
    }
    var partial = ""
    var finals: [String] = []
    client.onTranscript = { partial = $0 }
    client.onFinal = { finals.append($0) }
    try client.start(key: "test-key")
    XCTAssertEqual(
      request?.url?.absoluteString, "wss://api.openai.com/v1/realtime?intent=transcription")
    XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
    client.append(Data(repeating: 1, count: 4800))
    client.append(Data(repeating: 2, count: 4800))
    await waitUntil { socket.sent.count == 1 }
    socket.emit(#"{"type":"session.created"}"#)
    socket.emit(#"{"type":"session.updated"}"#)
    await waitUntil { socket.sent.count == 3 }
    socket.emit(
      #"{"type":"conversation.item.input_audio_transcription.delta","item_id":"a","delta":"Open "}"#
    )
    socket.emit(
      #"{"type":"conversation.item.input_audio_transcription.delta","item_id":"a","delta":"calculator"}"#
    )
    await waitUntil { partial == "Open calculator" }
    XCTAssertTrue(finals.isEmpty)
    client.finish()
    client.finish()
    await waitUntil { socket.sent.count == 4 }
    XCTAssertEqual(
      try object(socket.sent[1])["audio"] as? String,
      Data(repeating: 1, count: 4800).base64EncodedString())
    XCTAssertEqual(
      try object(socket.sent[2])["audio"] as? String,
      Data(repeating: 2, count: 4800).base64EncodedString())
    XCTAssertEqual(try object(socket.sent[3])["type"] as? String, "input_audio_buffer.commit")
    socket.emit(#"{"type":"input_audio_buffer.committed","item_id":"a"}"#)
    socket.emit(
      #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"other","transcript":"Wrong command"}"#
    )
    socket.emit(
      #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"a","transcript":" Open Calculator. "}"#
    )
    await waitUntil { finals.count == 1 }
    XCTAssertEqual(finals, ["Open Calculator."])
    XCTAssertTrue(socket.cancelled)
  }

  func testReleaseWhileConnectingStillDrainsAudio() async throws {
    let socket = MockTranscriptionSocket()
    let client = LiveTranscriptionClient { _ in socket }
    try client.start(key: "test-key")
    client.append(Data(repeating: 0, count: 4800))
    client.finish()
    socket.emit(#"{"type":"session.updated"}"#)
    await waitUntil { socket.sent.count == 3 }
    XCTAssertEqual(try object(socket.sent.last!)["type"] as? String, "input_audio_buffer.commit")
    client.cancel()
  }

  func testCancelAndRestartIgnoreOldResults() async throws {
    let old = MockTranscriptionSocket()
    let current = MockTranscriptionSocket()
    var sockets = [old, current]
    let client = LiveTranscriptionClient { _ in sockets.removeFirst() }
    var finals: [String] = []
    var errors: [String] = []
    client.onFinal = { finals.append($0) }
    client.onError = { errors.append($0) }
    try client.start(key: "test-key")
    client.cancel()
    try client.start(key: "test-key")
    old.emit(
      #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"old","transcript":"Stale command"}"#
    )
    current.emit(#"{"type":"session.updated"}"#)
    client.append(Data(repeating: 0, count: 4800))
    client.finish()
    await waitUntil { current.sent.count == 3 }
    current.emit(#"{"type":"input_audio_buffer.committed","item_id":"new"}"#)
    current.emit(
      #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"new","transcript":"New command"}"#
    )
    await waitUntil { finals.count == 1 }
    XCTAssertEqual(finals, ["New command"])
    XCTAssertTrue(errors.isEmpty)
  }

  func testMissingKeyDoesNotCreateConnection() throws {
    let client = LiveTranscriptionClient { _ in
      XCTFail("Must not connect without a key")
      return MockTranscriptionSocket()
    }
    XCTAssertThrowsError(try client.start(key: " \n")) {
      XCTAssertTrue($0.localizedDescription.contains("OpenAI"))
    }
  }

  func testErrorsDoNotEchoProviderMessages() async throws {
    for type in ["error", "conversation.item.input_audio_transcription.failed"] {
      let socket = MockTranscriptionSocket()
      let client = LiveTranscriptionClient { _ in socket }
      var error: String?
      client.onError = { error = $0 }
      try client.start(key: "test-key")
      socket.emit(
        "{\"type\":\"\(type)\",\"error\":{\"code\":\"invalid_api_key\",\"message\":\"secret-key\"}}"
      )
      await waitUntil { error != nil }
      XCTAssertFalse(error?.contains("secret-key") ?? true)
      XCTAssertTrue(error?.contains("Settings") ?? false)
      XCTAssertTrue(socket.cancelled)
    }
  }

  func testShortRecordingDoesNotCommit() async throws {
    let socket = MockTranscriptionSocket()
    let client = LiveTranscriptionClient { _ in socket }
    var error: String?
    client.onError = { error = $0 }
    try client.start(key: "test-key")
    socket.emit(#"{"type":"session.updated"}"#)
    client.append(Data(repeating: 0, count: 100))
    client.finish()
    await waitUntil { error != nil }
    XCTAssertFalse(socket.sent.contains { $0.contains("input_audio_buffer.commit") })
    XCTAssertTrue(socket.cancelled)
  }

  func testBackpressureStopsRatherThanDroppingAudio() throws {
    let socket = MockTranscriptionSocket()
    let client = LiveTranscriptionClient { _ in socket }
    var error: String?
    client.onError = { error = $0 }
    try client.start(key: "test-key")
    client.append(Data(repeating: 0, count: 480_002))
    XCTAssertNotNil(error)
    XCTAssertTrue(socket.cancelled)
  }

  func testTimeoutNeverSubmitsPartialTranscript() async throws {
    let socket = MockTranscriptionSocket()
    let client = LiveTranscriptionClient(timeout: .milliseconds(30)) { _ in socket }
    var error: String?
    var finals: [String] = []
    client.onError = { error = $0 }
    client.onFinal = { finals.append($0) }
    try client.start(key: "test-key")
    socket.emit(#"{"type":"session.updated"}"#)
    client.append(Data(repeating: 0, count: 4800))
    socket.emit(
      #"{"type":"conversation.item.input_audio_transcription.delta","item_id":"a","delta":"Delete"}"#
    )
    client.finish()
    await waitUntil { error != nil }
    XCTAssertTrue(finals.isEmpty)
    XCTAssertTrue(socket.cancelled)
  }

  func testConnectionTimeoutClosesSession() async throws {
    let socket = MockTranscriptionSocket()
    let client = LiveTranscriptionClient(timeout: .milliseconds(30)) { _ in socket }
    var error: String?
    client.onError = { error = $0 }
    try client.start(key: "test-key")
    await waitUntil { error != nil }
    XCTAssertTrue(error?.contains("connect") ?? false)
    XCTAssertTrue(socket.cancelled)
  }

  func testSendFailuresNeverSubmitACommand() async throws {
    for type in ["session.update", "input_audio_buffer.append", "input_audio_buffer.commit"] {
      let socket = MockTranscriptionSocket()
      socket.failOnSendType = type
      let client = LiveTranscriptionClient { _ in socket }
      var error: String?
      var finals: [String] = []
      client.onError = { error = $0 }
      client.onFinal = { finals.append($0) }
      try client.start(key: "test-key")
      socket.emit(#"{"type":"session.updated"}"#)
      client.append(Data(repeating: 0, count: 4800))
      client.finish()
      await waitUntil { error != nil }
      XCTAssertTrue(finals.isEmpty)
      XCTAssertTrue(socket.cancelled)
    }
  }

  func testDisconnectNeverSubmitsPartialText() async throws {
    let socket = MockTranscriptionSocket()
    let client = LiveTranscriptionClient { _ in socket }
    var partial = ""
    var error: String?
    var finals: [String] = []
    client.onTranscript = { partial = $0 }
    client.onError = { error = $0 }
    client.onFinal = { finals.append($0) }
    try client.start(key: "test-key")
    socket.emit(#"{"type":"session.updated"}"#)
    socket.emit(
      #"{"type":"conversation.item.input_audio_transcription.delta","item_id":"a","delta":"Delete"}"#
    )
    await waitUntil { partial == "Delete" }
    socket.disconnect()
    await waitUntil { error != nil }
    XCTAssertTrue(finals.isEmpty)
    XCTAssertTrue(socket.cancelled)
  }

  func testEmptyFinalTranscriptDoesNotSubmit() async throws {
    let socket = MockTranscriptionSocket()
    let client = LiveTranscriptionClient { _ in socket }
    var error: String?
    var finals: [String] = []
    client.onError = { error = $0 }
    client.onFinal = { finals.append($0) }
    try client.start(key: "test-key")
    socket.emit(#"{"type":"session.updated"}"#)
    client.append(Data(repeating: 0, count: 4800))
    client.finish()
    await waitUntil { socket.sent.count == 3 }
    socket.emit(#"{"type":"input_audio_buffer.committed","item_id":"a"}"#)
    socket.emit(
      #"{"type":"conversation.item.input_audio_transcription.completed","item_id":"a","transcript":" "}"#
    )
    await waitUntil { error != nil }
    XCTAssertTrue(finals.isEmpty)
    XCTAssertTrue(socket.cancelled)
  }

  private func object(_ text: String) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
  }

  private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<200 {
      if condition() { return }
      try? await Task.sleep(for: .milliseconds(5))
    }
    XCTFail("Timed out waiting for transcription state")
  }
}

@MainActor
private final class MockTranscriptionSocket: TranscriptionSocket {
  var sent: [String] = []
  var cancelled = false
  var failOnSendType: String?
  private let events = AsyncThrowingStream<String, Error>.makeStream()

  func resume() {}
  func send(_ text: String) async throws {
    if let failOnSendType, text.contains(failOnSendType) {
      throw URLError(.networkConnectionLost)
    }
    sent.append(text)
  }
  func disconnect() { events.continuation.finish(throwing: URLError(.networkConnectionLost)) }
  func receive() async throws -> String {
    for try await event in events.stream { return event }
    throw CancellationError()
  }
  func emit(_ text: String) { events.continuation.yield(text) }
  func cancel() {
    cancelled = true
    events.continuation.finish()
  }
}
