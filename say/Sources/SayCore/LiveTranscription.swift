import Foundation

@MainActor
protocol TranscriptionSocket: AnyObject {
  func resume()
  func send(_ text: String) async throws
  func receive() async throws -> String
  func cancel()
}

@MainActor
private final class OpenAITranscriptionSocket: TranscriptionSocket {
  private let task: URLSessionWebSocketTask

  init(request: URLRequest) { task = URLSession.shared.webSocketTask(with: request) }
  func resume() { task.resume() }
  func send(_ text: String) async throws { try await task.send(.string(text)) }
  func receive() async throws -> String {
    switch try await task.receive() {
    case .string(let text): return text
    case .data(let data): return String(decoding: data, as: UTF8.self)
    @unknown default: throw SayError("Unexpected transcription response.")
    }
  }
  func cancel() { task.cancel(with: .goingAway, reason: nil) }
}

@MainActor
public final class LiveTranscriptionClient {
  public var onTranscript: ((String) -> Void)?
  public var onFinal: ((String) -> Void)?
  public var onError: ((String) -> Void)?
  public var onNothingHeard: (() -> Void)?
  private let makeSocket: (URLRequest) -> any TranscriptionSocket
  private let timeout: Duration
  private var socket: (any TranscriptionSocket)?
  private var receiver: Task<Void, Never>?
  private var sender: Task<Void, Never>?
  private var deadline: Task<Void, Never>?
  private var audio: AsyncThrowingStream<Data, Error>.Continuation?
  private var generation = UUID()
  private var ready = false
  private var finishing = false
  private var commitSent = false
  private var queuedBytes = 0
  private var partialID: String?
  private var committedID: String?
  private var transcript = ""

  public convenience init() {
    self.init { OpenAITranscriptionSocket(request: $0) }
  }

  init(
    timeout: Duration = .seconds(30),
    makeSocket: @escaping (URLRequest) -> any TranscriptionSocket
  ) {
    self.timeout = timeout
    self.makeSocket = makeSocket
  }

  public func start(key: String) throws {
    cancel()
    let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else {
      throw SayError("Add an OpenAI API key in Settings to use voice input.")
    }
    var request = URLRequest(
      url: URL(string: "wss://api.openai.com/v1/realtime?intent=transcription")!)
    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30
    let socket = makeSocket(request)
    self.socket = socket
    let token = generation
    let stream = AsyncThrowingStream<Data, Error>.makeStream()
    audio = stream.continuation
    socket.resume()
    setDeadline("Could not connect to OpenAI transcription. Check your connection and try again.")
    receiver = Task { [weak self] in
      guard let self else { return }
      do {
        try await socket.send(Self.configuration())
        while !Task.isCancelled {
          let text = try await socket.receive()
          guard generation == token else { return }
          let event = try JSONDecoder().decode(Event.self, from: Data(text.utf8))
          if event.type == "session.updated", !ready {
            ready = true
            if !finishing { deadline?.cancel() }
            sender = Task { [weak self] in
              guard let self else { return }
              do {
                var sentBytes = 0
                for try await chunk in stream.stream {
                  try Task.checkCancellation()
                  guard generation == token else { return }
                  try await socket.send(
                    Self.message([
                      "type": "input_audio_buffer.append", "audio": chunk.base64EncodedString(),
                    ]))
                  guard generation == token else { return }
                  queuedBytes -= chunk.count
                  sentBytes += chunk.count
                }
                try Task.checkCancellation()
                guard generation == token else { return }
                guard sentBytes >= 4800 else {
                  nothingHeard()
                  return
                }
                commitSent = true
                try await socket.send(Self.message(["type": "input_audio_buffer.commit"]))
              } catch {
                guard generation == token else { return }
                fail("Audio could not reach OpenAI. Check your connection and try again.")
              }
            }
          } else {
            handle(event)
          }
        }
      } catch {
        guard generation == token else { return }
        fail("OpenAI transcription disconnected. Check your API key, model access, and connection.")
      }
    }
  }

  public func append(_ pcm: Data) {
    guard socket != nil, !finishing, !pcm.isEmpty else { return }
    guard queuedBytes + pcm.count <= 480_000 else {
      fail("The connection cannot keep up with your audio. Please try again.")
      return
    }
    queuedBytes += pcm.count
    audio?.yield(pcm)
  }

  public func finish() {
    guard socket != nil, !finishing else { return }
    finishing = true
    audio?.finish()
    setDeadline("OpenAI did not finish the transcript. Please try again.")
  }

  public func cancel() {
    generation = UUID()
    deadline?.cancel()
    deadline = nil
    receiver?.cancel()
    receiver = nil
    sender?.cancel()
    sender = nil
    audio?.finish()
    audio = nil
    socket?.cancel()
    socket = nil
    ready = false
    finishing = false
    commitSent = false
    queuedBytes = 0
    partialID = nil
    committedID = nil
    transcript = ""
  }

  static func configuration() throws -> String {
    try message([
      "type": "session.update",
      "session": [
        "type": "transcription",
        "audio": [
          "input": [
            "format": ["type": "audio/pcm", "rate": 24000],
            "transcription": ["model": "gpt-live-transcribe", "delay": "low"],
            "turn_detection": NSNull(),
          ]
        ],
      ],
    ])
  }

  private static func message(_ object: [String: Any]) throws -> String {
    String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
  }

  private struct Event: Decodable {
    struct Failure: Decodable { var code: String? }
    var type: String
    var itemID: String?
    var delta: String?
    var transcript: String?
    var error: Failure?
    enum CodingKeys: String, CodingKey {
      case type, delta, transcript, error
      case itemID = "item_id"
    }
  }

  private func handle(_ event: Event) {
    switch event.type {
    case "input_audio_buffer.committed":
      if commitSent { committedID = event.itemID }
    case "conversation.item.input_audio_transcription.delta":
      guard let id = event.itemID else { return }
      if partialID == nil { partialID = id }
      guard partialID == id else { return }
      transcript += event.delta ?? ""
      onTranscript?(transcript)
    case "conversation.item.input_audio_transcription.completed":
      guard finishing, commitSent, let id = committedID, event.itemID == id else { return }
      let text = (event.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else {
        nothingHeard()
        return
      }
      cancel()
      onFinal?(text)
    case "error", "conversation.item.input_audio_transcription.failed":
      let message: String
      switch event.error?.code {
      case "invalid_api_key", "invalid_authentication", "insufficient_permissions":
        message = "OpenAI rejected this API key. Check it in Settings."
      case "rate_limit_exceeded", "insufficient_quota":
        message = "OpenAI transcription is rate limited or out of quota. Check your OpenAI usage."
      default:
        message =
          "OpenAI could not transcribe your audio. Check your key and access to gpt-live-transcribe in Settings."
      }
      fail(message)
    default: break
    }
  }

  private func setDeadline(_ message: String) {
    deadline?.cancel()
    let token = generation
    deadline = Task { [weak self, timeout] in
      do { try await Task.sleep(for: timeout) } catch { return }
      guard let self, generation == token else { return }
      fail(message)
    }
  }

  private func fail(_ message: String) {
    cancel()
    onError?(message)
  }

  private func nothingHeard() {
    cancel()
    if let onNothingHeard {
      onNothingHeard()
    } else {
      onError?("I did not catch anything. Hold the shortcut while speaking and try again.")
    }
  }
}
