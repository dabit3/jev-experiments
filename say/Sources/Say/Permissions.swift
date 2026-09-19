import AVFoundation
import AppKit

struct PermissionSnapshot {
  var microphone: AVAuthorizationStatus
  var accessibility: Bool
  var screenRecording: Bool

  @MainActor static func current() -> Self {
    Self(
      microphone: AVCaptureDevice.authorizationStatus(for: .audio),
      accessibility: DesktopAccess.trusted,
      screenRecording: CGPreflightScreenCaptureAccess())
  }
}
