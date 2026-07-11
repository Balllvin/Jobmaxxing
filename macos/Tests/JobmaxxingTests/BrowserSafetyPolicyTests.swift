import XCTest
@testable import Jobmaxxing

final class BrowserSafetyPolicyTests: XCTestCase {
  func testEnforcedBrowserPolicyKeepsProtectedSitesManualAndFinalSubmitHuman() {
    let unsafePolicy = BrowserPolicy(
      permissionMode: .assistFill,
      allowLinkedInAutomation: true,
      allowExternalSubmission: true,
      requireFinalHumanSubmit: false
    )

    let policy = enforcedBrowserPolicy(unsafePolicy)

    XCTAssertEqual(policy.permissionMode, .assistFill)
    XCTAssertFalse(policy.allowLinkedInAutomation)
    XCTAssertFalse(policy.allowExternalSubmission)
    XCTAssertTrue(policy.requireFinalHumanSubmit)
  }

  func testEveryBrowserModeMakesFinalSubmitOwnershipExplicit() {
    for mode in PermissionMode.allCases {
      let rule = browserSafetyRule(for: mode)
      XCTAssertTrue(rule.contains("User"), "Missing human owner for \(mode.rawValue)")
      XCTAssertTrue(
        rule.localizedCaseInsensitiveContains("submit") || rule.localizedCaseInsensitiveContains("final control"),
        "Missing final-submit gate for \(mode.rawValue)"
      )
    }
  }

  func testPreparationModesKeepProtectedSitesOrActionsBounded() {
    XCTAssertTrue(browserSafetyRule(for: .assistFill).localizedCaseInsensitiveContains("Protected sites stay manual"))
    XCTAssertTrue(browserSafetyRule(for: .autonomousPrepare).localizedCaseInsensitiveContains("does not operate protected sites"))
  }
}
