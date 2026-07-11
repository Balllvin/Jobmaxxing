import XCTest
import SwiftUI
@testable import Jobmaxxing

final class SidebarDisplayTests: XCTestCase {
  func testSidebarUsesTrimmedProfileName() {
    XCTAssertEqual(SidebarDisplayName.userName(from: "  Example User  "), "Example User")
  }

  func testSidebarFallsBackToFullUserName() {
    XCTAssertEqual(SidebarDisplayName.userName(from: " \n "), "Example User")
  }

  func testSidebarKeyboardMovesBetweenAdjacentWorkflows() {
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .writing, moving: .down), .interviews)
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .writing, moving: .up), .contacts)
  }

  func testSidebarKeyboardStopsAtWorkflowBoundaries() {
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .dashboard, moving: .up), .dashboard)
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .browser, moving: .down), .browser)
    XCTAssertNil(SidebarKeyboardNavigation.destination(from: .writing, moving: .left))
  }
}
