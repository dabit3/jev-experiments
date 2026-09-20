import Foundation
import XCTest

@testable import SayCore

final class RecoveryActionTests: XCTestCase {
  func testAccessibilityErrorOffersTheExactSystemSettingsPane() {
    let message = Message(error: SayError.accessibilityRequired)
    XCTAssertTrue(message.isError)
    XCTAssertEqual(message.role, "assistant")
    XCTAssertEqual(message.recovery, .accessibilitySettings)
    XCTAssertEqual(message.recovery?.title, "Open Accessibility Settings")
    XCTAssertEqual(
      message.recovery?.systemSettingsURL.absoluteString,
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
  }

  func testUnrelatedErrorsDoNotOfferPermissionRecovery() {
    let message = Message(error: SayError("An unrelated failure"))
    XCTAssertNil(message.recovery)
  }

  func testRecoverySurvivesSavedHistory() throws {
    let message = Message(error: SayError.accessibilityRequired)
    let decoded = try JSONDecoder().decode(Message.self, from: JSONEncoder().encode(message))
    XCTAssertEqual(decoded.recovery, .accessibilitySettings)
    XCTAssertEqual(decoded.text, message.text)
  }

  func testOlderMessagesWithoutRecoveryStillDecode() throws {
    let message = Message(role: "assistant", text: "Earlier conversation", isError: true)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any])
    object.removeValue(forKey: "recovery")
    let decoded = try JSONDecoder().decode(
      Message.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(decoded.recovery)
    XCTAssertEqual(decoded.text, message.text)
  }
}
