import XCTest
@testable import Jobmaxxing

final class ProfileSettingsDisplayTests: XCTestCase {
  func testProfileBriefGuidanceCapturesApplicationContext() {
    let guidance = profileBriefGuidanceText().lowercased()

    [
      "experience",
      "target roles",
      "location or remote constraints",
      "strengths",
      "proof",
      "companies",
      "communication style",
      "working preferences",
      "red flags",
      "applications"
    ].forEach { expected in
      XCTAssertTrue(guidance.contains(expected), "Missing guidance for \(expected)")
    }
  }
}
