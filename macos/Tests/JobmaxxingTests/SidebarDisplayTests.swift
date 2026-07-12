import XCTest
import SwiftUI
@testable import Jobmaxxing

final class SidebarDisplayTests: XCTestCase {
  func testProfileSitsBetweenDashboardAndChat() {
    XCTAssertEqual(Array(AppSection.primarySections.prefix(3)), [.dashboard, .profile, .chat])
  }

  func testSidebarKeyboardMovesBetweenAdjacentWorkflows() {
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .dashboard, moving: .down), .profile)
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .profile, moving: .down), .chat)
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .chat, moving: .up), .profile)
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .writing, moving: .down), .interviews)
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .writing, moving: .up), .contacts)
  }

  func testSidebarKeyboardStopsAtWorkflowBoundaries() {
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .dashboard, moving: .up), .dashboard)
    XCTAssertEqual(SidebarKeyboardNavigation.destination(from: .browser, moving: .down), .browser)
    XCTAssertNil(SidebarKeyboardNavigation.destination(from: .writing, moving: .left))
  }
}
