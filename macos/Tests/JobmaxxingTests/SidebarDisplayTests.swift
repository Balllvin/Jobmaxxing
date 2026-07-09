import XCTest
@testable import Jobmaxxing

final class SidebarDisplayTests: XCTestCase {
  func testSidebarUsesTrimmedProfileName() {
    XCTAssertEqual(SidebarDisplayName.userName(from: "  Local Candidate  "), "Local Candidate")
  }

  func testSidebarFallsBackToFullUserName() {
    XCTAssertEqual(SidebarDisplayName.userName(from: " \n "), "Local Candidate")
  }
}
