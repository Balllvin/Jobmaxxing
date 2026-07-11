import XCTest
@testable import Jobmaxxing

final class TextImproveSupportTests: XCTestCase {
  func testRewritePromptPrioritizesUserFeedback() {
    let prompt = TextImproveSupport.rewritePrompt(
      currentText: "I am interested in the role.",
      feedback: "sound less robotic and more humble",
      context: "Company: Lakera\nRole: Software Engineer",
      kind: "cover letter"
    )

    XCTAssertTrue(prompt.contains("USER FEEDBACK (highest priority"))
    XCTAssertTrue(prompt.contains("sound less robotic and more humble"))
    XCTAssertTrue(prompt.contains("I am interested in the role."))
    XCTAssertTrue(prompt.contains("Company: Lakera"))
    XCTAssertTrue(prompt.contains("Prioritize the user's feedback"))
    XCTAssertTrue(prompt.contains("Return only the rewritten cover letter"))
  }

  func testCleanOutputStripsFencesAndPreamble() {
    let fenced = """
    ```markdown
    Hello hiring team.
    ```
    """
    XCTAssertEqual(TextImproveSupport.cleanOutput(fenced), "Hello hiring team.")

    let preambled = """
    Here is the rewritten text:
    Softened cover letter body.
    """
    XCTAssertEqual(TextImproveSupport.cleanOutput(preambled), "Softened cover letter body.")
  }

  func testBulletsFromMultilineText() {
    let bullets = TextImproveSupport.bullets(from: """
    - Built Jobmaxxing
    • Shipped Smaug
    plain line
    """)
    XCTAssertEqual(bullets, ["Built Jobmaxxing", "Shipped Smaug", "plain line"])
  }
}
