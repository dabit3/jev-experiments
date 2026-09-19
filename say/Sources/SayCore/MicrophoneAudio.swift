import AVFoundation
import Foundation

public struct MicrophonePacket: Sendable {
  public let pcm: Data
  public let level: Float
}

public final class MicrophoneAudio: @unchecked Sendable {
  public let stream: AsyncThrowingStream<MicrophonePacket, Error>
  private let continuation: AsyncThrowingStream<MicrophonePacket, Error>.Continuation
  private let converter: AVAudioConverter
  private let outputFormat: AVAudioFormat
  private let lock = NSLock()
  private var closed = false

  public init(format: AVAudioFormat) throws {
    guard format.sampleRate > 0, format.channelCount > 0,
      let output = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true),
      let converter = AVAudioConverter(from: format, to: output)
    else { throw SayError("The microphone audio format is unavailable.") }
    self.converter = converter
    outputFormat = output
    converter.primeMethod = .none
    let stream = AsyncThrowingStream<MicrophonePacket, Error>.makeStream(
      bufferingPolicy: .bufferingOldest(256))
    self.stream = stream.stream
    continuation = stream.continuation
  }

  public func append(_ buffer: AVAudioPCMBuffer) {
    lock.lock()
    defer { lock.unlock() }
    guard !closed else { return }
    let capacity =
      AVAudioFrameCount(
        ceil(Double(buffer.frameLength) * outputFormat.sampleRate / buffer.format.sampleRate)) + 64
    convert(buffer, capacity: capacity)
  }

  public func finish() {
    lock.lock()
    defer { lock.unlock() }
    guard !closed else { return }
    convert(nil, capacity: 4096)
    closed = true
    continuation.finish()
  }

  public func cancel() {
    lock.lock()
    defer { lock.unlock() }
    closed = true
    continuation.finish()
  }

  private func convert(_ input: AVAudioPCMBuffer?, capacity: AVAudioFrameCount) {
    guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
      fail("Could not prepare microphone audio.")
      return
    }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, state in
      guard let input else {
        state.pointee = .endOfStream
        return nil
      }
      guard !supplied else {
        state.pointee = .noDataNow
        return nil
      }
      supplied = true
      state.pointee = .haveData
      return input
    }
    guard status != .error, error == nil else {
      fail("Could not convert microphone audio for OpenAI.")
      return
    }
    let count = Int(output.frameLength)
    guard count > 0, let samples = output.int16ChannelData?[0] else { return }
    var sum: Float = 0
    for index in 0..<count {
      let sample = Float(samples[index]) / 32768
      sum += sample * sample
    }
    let packet = MicrophonePacket(
      pcm: Data(bytes: samples, count: count * MemoryLayout<Int16>.size),
      level: min(1, sqrt(sum / Float(count)) * 12))
    if case .dropped = continuation.yield(packet) {
      fail("Microphone audio could not be processed in time. Please try again.")
    }
  }

  private func fail(_ message: String) {
    closed = true
    continuation.finish(throwing: SayError(message))
  }
}
