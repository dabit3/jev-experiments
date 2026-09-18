import AVFoundation
import AppKit
import Carbon
import Speech
import TalkieCore

@MainActor
final class VoiceInput: ObservableObject {
  @Published private(set) var transcript = ""
  @Published private(set) var level: Float = 0
  @Published private(set) var active = false
  var onError: ((String) -> Void)?
  var onFinal: ((String) -> Void)?
  private var engine: AVAudioEngine?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var generation = UUID()
  private var tapInstalled = false
  private var finishing = false
  private var finishTask: Task<Void, Never>?

  func start() async {
    cancel()
    let token = UUID()
    generation = token
    transcript = ""
    active = true
    let granted = await AVCaptureDevice.requestAccess(for: .audio)
    guard generation == token else { return }
    guard granted else {
      fail("Microphone access is off. Enable it in System Settings → Privacy & Security.")
      return
    }
    let authorization = await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
    }
    guard generation == token else { return }
    guard authorization == .authorized else {
      fail("Allow Speech Recognition in System Settings, or import an audio file.")
      return
    }
    guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
      fail("Apple speech recognition is unavailable. Try again later or import an audio file.")
      return
    }
    guard recognizer.supportsOnDeviceRecognition else {
      fail(
        "On-device speech is unavailable for your system language. Enable Dictation in macOS Keyboard settings, or import audio."
      )
      return
    }
    let engine = AVAudioEngine()
    let format = engine.inputNode.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      fail("No microphone is connected. Connect one, type a request, or import an audio file.")
      return
    }
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.requiresOnDeviceRecognition = true
    self.engine = engine
    self.request = request
    engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) {
      [weak self] buffer, _ in
      request.append(buffer)
      guard let samples = buffer.floatChannelData?[0] else { return }
      let count = Int(buffer.frameLength)
      let sum = (0..<count).reduce(Float(0)) { $0 + samples[$1] * samples[$1] }
      let level = min(1, sqrt(sum / Float(max(1, count))) * 12)
      Task { @MainActor [weak self] in
        guard self?.generation == token else { return }
        self?.level = level
      }
    }
    tapInstalled = true
    task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      let text = result?.bestTranscription.formattedString
      let isFinal = result?.isFinal ?? false
      let errorDescription = error?.localizedDescription
      Task { @MainActor [weak self] in
        guard let self, self.generation == token else { return }
        if let text { self.transcript = text }
        if isFinal || (error != nil && self.finishing) {
          self.deliver()
        } else if let errorDescription {
          self.fail(errorDescription)
        }
      }
    }
    do {
      engine.prepare()
      try engine.start()
    } catch { fail("The microphone could not start: \(error.localizedDescription)") }
  }

  func finish() {
    guard active, !finishing else { return }
    finishing = true
    stopEngine()
    request?.endAudio()
    if request == nil {
      cancel()
      return
    }
    finishTask = Task {
      try? await Task.sleep(for: .milliseconds(1200))
      guard !Task.isCancelled else { return }
      deliver()
    }
  }

  func cancel() {
    generation = UUID()
    finishTask?.cancel()
    finishTask = nil
    stopEngine()
    task?.cancel()
    task = nil
    request = nil
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
  private func deliver() {
    let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    cancel()
    if !text.isEmpty {
      onFinal?(text)
    } else {
      onError?("I didn’t catch anything. Hold the shortcut while speaking and try again.")
    }
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
