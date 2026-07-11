import XCTest
@testable import Jobmaxxing

final class CredentialReferenceTests: XCTestCase {
  func testExpectedAndAvailableEnvironmentVariableReferencesAreAccepted() {
    XCTAssertTrue(isValidCredentialReference(
      "TELEGRAM_BOT_TOKEN",
      expectedReference: "TELEGRAM_BOT_TOKEN",
      environment: [:]
    ))
    XCTAssertTrue(isValidCredentialReference(
      "_PRIVATE_TOKEN_2",
      environment: ["_PRIVATE_TOKEN_2": "configured"]
    ))
    XCTAssertTrue(isValidCredentialReference("", environment: [:]))
  }

  func testRawSecretsAndShellExpressionsAreRejected() {
    let environment: [String: String] = [:]
    XCTAssertFalse(isValidCredentialReference("123456:raw-bot-token", environment: environment))
    XCTAssertFalse(isValidCredentialReference("not-a-credential-reference", environment: environment))
    XCTAssertFalse(isValidCredentialReference("hf_abcdefghijklmnopqrstuvwxyz1234567890", environment: environment))
    XCTAssertFalse(isValidCredentialReference("UNRECOGNIZED_IDENTIFIER_TOKEN", environment: environment))
    XCTAssertFalse(isValidCredentialReference("TOKEN-NAME", environment: environment))
    XCTAssertFalse(isValidCredentialReference("$TOKEN", environment: environment))
    XCTAssertFalse(isValidCredentialReference("TOKEN NAME", environment: environment))
  }

  func testCredentialReferenceSyntaxIsUppercaseASCIIAndBounded() {
    XCTAssertNil(canonicalCredentialReference(from: "token_name"))
    XCTAssertNil(canonicalCredentialReference(from: "TØKEN_NAME"))
    XCTAssertNil(canonicalCredentialReference(from: String(repeating: "A", count: 129)))
    XCTAssertEqual(canonicalCredentialReference(from: "XAI_API_KEY or provider login"), "XAI_API_KEY")
  }
}
