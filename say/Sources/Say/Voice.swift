import AVFoundation
import AppKit
import Carbon
import SayCore

@MainActor
final class VoiceInput: ObservableObject {
  @Published private(set) var transcript = ""
  @Published private(set) var level: Float = 0
  @Published private(set) var active = false
  @Published private(set) var finishing = false
  var onError: ((String) -> Void)?
  var onFinal: ((String) -> Void)?
  private let client = LiveTranscriptionClient()
  private var engine: AVAudioEngine?
  private var audio: MicrophoneAudio?
  private var audioTask: Task<Void, Never>?
  private var startTask: Task<Void, Never>?
  private var generation = UUID()
  private var tapInstalled = false

  func start(key: String) {
    cancel()
    transcript = ""
    guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      fail("Add an OpenAI API key in Settings to use voice input.")
      return
    }
    guard AVCaptureDevice.default(for: .audio) != nil else {
      fail("No microphone is connected. Connect one, then try speaking again.")
      return
    }
    let token = generation
    active = true
    startTask = Task { [weak self] in
      let granted = await AVCaptureDevice.requestAccess(for: .audio)
      guard let self, generation == token, !Task.isCancelled else { return }
      guard granted else {
        fail("Microphone access is off. Enable it in System Settings → Privacy & Security.")
        return
      }
      startCapture(key: key, token: token)
    }
  }

  private func startCapture(key: String, token: UUID) {
    let engine = AVAudioEngine()
    let format = engine.inputNode.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      fail("No microphone is connected. Connect one, then try speaking again.")
      return
    }
    do {
      let audio = try MicrophoneAudio(format: format)
      self.engine = engine
      self.audio = audio
      client.onTranscript = { [weak self] text in
        guard let self, generation == token else { return }
        transcript = text
      }
      client.onFinal = { [weak self] text in
        guard let self, generation == token else { return }
        transcript = text
        cancel()
        onFinal?(text)
      }
      client.onError = { [weak self] message in
        guard let self, generation == token else { return }
        fail(message)
      }
      try client.start(key: key)
      engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        audio.append(buffer)
      }
      tapInstalled = true
      engine.prepare()
      try engine.start()
      audioTask = Task { [weak self] in
        do {
          for try await packet in audio.stream {
            guard let self, generation == token, !Task.isCancelled else { return }
            level = finishing ? 0 : packet.level
            client.append(packet.pcm)
          }
          guard let self, generation == token, !Task.isCancelled else { return }
          client.finish()
        } catch {
          guard let self, generation == token else { return }
          fail(error.localizedDescription)
        }
      }
    } catch { fail("The microphone could not start: \(error.localizedDescription)") }
  }

  func finish() {
    guard active, !finishing else { return }
    guard let audio else {
      cancel()
      return
    }
    finishing = true
    stopEngine()
    level = 0
    audio.finish()
  }

  func cancel() {
    generation = UUID()
    startTask?.cancel()
    startTask = nil
    stopEngine()
    audio?.cancel()
    audio = nil
    audioTask?.cancel()
    audioTask = nil
    client.cancel()
    active = false
    finishing = false
    level = 0
  }

  private func stopEngine() {
    if tapInstalled {
      engine?.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    engine?.stop()
    engine = nil
  }

  private func fail(_ message: String) {
    cancel()
    onError?(message)
  }
}

@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
  @Published private(set) var speaking = false
  private let synthesizer = AVSpeechSynthesizer()
  override init() {
    super.init()
    synthesizer.delegate = self
  }
  func say(_ text: String) {
    stop()
    let utterance = AVSpeechUtterance(string: String(text.prefix(1800)))
    utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
    utterance.rate = 0.49
    speaking = true
    synthesizer.speak(utterance)
  }
  func stop() {
    synthesizer.stopSpeaking(at: .immediate)
    speaking = false
  }
  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in self.speaking = false }
  }
  nonisolated func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
  ) {
    Task { @MainActor in self.speaking = false }
  }
}

@MainActor
final class GlobalShortcut {
  var onDown: (() -> Void)?
  var onUp: (() -> Void)?
  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private var escapeMonitor: NSObjectProtocol?
  var onEscape: (() -> Void)?

  func install() -> Bool {
    let pointer = Unmanaged.passUnretained(self).toOpaque()
    var types = [
      EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, pointer in
        guard let event, let pointer else { return OSStatus(eventNotHandledErr) }
        let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue()
        let down = GetEventKind(event) == UInt32(kEventHotKeyPressed)
        MainActor.assumeIsolated { if down { shortcut.onDown?() } else { shortcut.onUp?() } }
        return noErr
      }, 2, &types, pointer, &handler)
    let status = RegisterEventHotKey(
      49, UInt32(controlKey | optionKey),
      EventHotKeyID(signature: 0x5441_4C4B, id: 1),
      GetApplicationEventTarget(), 0, &hotKey)
    escapeMonitor =
      NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
        if event.keyCode == 53 { MainActor.assumeIsolated { self?.onEscape?() } }
      } as? NSObjectProtocol
    return status == noErr
  }
}
