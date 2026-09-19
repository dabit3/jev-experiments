import AVFoundation
import XCTest

@testable import SayCore

final class MicrophoneAudioTests: XCTestCase {
  func testResamplesCommonMicrophoneFormatsToMonoPCM16() async throws {
    for rate in [16000.0, 44100.0, 48000.0] {
      for channels: AVAudioChannelCount in [1, 2] {
        let format = try XCTUnwrap(
          AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels))
        let audio = try MicrophoneAudio(format: format)
        let frames = AVAudioFrameCount(rate / 10)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let samples = try XCTUnwrap(buffer.floatChannelData)
        for channel in 0..<Int(channels) {
          for index in 0..<Int(frames) { samples[channel][index] = 0.25 }
        }
        for _ in 0..<3 { audio.append(buffer) }
        audio.finish()
        var pcm = Data()
        for try await packet in audio.stream {
          XCTAssertEqual(packet.pcm.count % 2, 0)
          XCTAssertGreaterThan(packet.level, 0)
          pcm.append(packet.pcm)
        }
        XCTAssertEqual(
          Double(pcm.count / 2), 7200, accuracy: 64, "\(rate) Hz, \(channels) channels")
        let midpoint = (pcm.count / 4) * 2
        let sample = Int16(bitPattern: UInt16(pcm[midpoint]) | UInt16(pcm[midpoint + 1]) << 8)
        XCTAssertEqual(Double(sample), 8192, accuracy: 4)
      }
    }
  }

  func testCancelWithoutAudioClosesStream() async throws {
    let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
    let audio = try MicrophoneAudio(format: format)
    audio.cancel()
    audio.finish()
    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024))
    buffer.frameLength = 1024
    audio.append(buffer)
    var count = 0
    for try await _ in audio.stream { count += 1 }
    XCTAssertEqual(count, 0)
  }
}
