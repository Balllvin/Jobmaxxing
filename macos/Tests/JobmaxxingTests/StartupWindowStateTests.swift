import AppKit
import XCTest
@testable import Jobmaxxing

final class StartupWindowStateTests: XCTestCase {
  func testLaunchResetsUnsafeSavedRoutesToDashboard() {
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: AppSection.chat.rawValue), .dashboard)
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: AppSection.browser.rawValue), .dashboard)
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: AppSection.settings.rawValue), .dashboard)
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: "missing-route"), .dashboard)
  }

  func testLaunchRestoresCoherentWorkRoutes() {
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: AppSection.profile.rawValue), .profile)
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: AppSection.applications.rawValue), .applications)
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: AppSection.companies.rawValue), .companies)
    XCTAssertEqual(LaunchRoutePolicy.restoredSection(from: AppSection.interviews.rawValue), .interviews)
  }

  func testWindowRepairPreservesOnScreenUserFrame() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    // Near-edge is fine — do not shrink or force-center healthy frames.
    let edgePinnedFrame = NSRect(x: 40, y: 68, width: 1180, height: 792)

    XCTAssertEqual(
      JobmaxxingWindowLayout.repairedFrame(currentFrame: edgePinnedFrame, visibleFrame: visibleFrame),
      edgePinnedFrame
    )
  }

  func testWindowRepairPreservesComfortableLaunchFrame() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let comfortableFrame = NSRect(x: 130, y: 54, width: 1180, height: 792)

    XCTAssertEqual(
      JobmaxxingWindowLayout.repairedFrame(currentFrame: comfortableFrame, visibleFrame: visibleFrame),
      comfortableFrame
    )
  }

  func testWindowRepairPreservesMaximizedFrameThatFitsScreen() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let maximizedFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)

    XCTAssertEqual(
      JobmaxxingWindowLayout.repairedFrame(currentFrame: maximizedFrame, visibleFrame: visibleFrame),
      maximizedFrame
    )
  }

  func testWindowRepairDoesNotShrinkLargeHealthyFrame() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1728, height: 1080)
    let largeFrame = NSRect(x: 40, y: 40, width: 1600, height: 980)

    let repaired = JobmaxxingWindowLayout.repairedFrame(currentFrame: largeFrame, visibleFrame: visibleFrame)
    XCTAssertEqual(repaired.size.width, 1600)
    XCTAssertEqual(repaired.size.height, 980)
  }

  func testWindowRepairRecentersFullyOffscreenFrame() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let offscreenFrame = NSRect(x: -2000, y: -2000, width: 1180, height: 792)

    let repaired = JobmaxxingWindowLayout.repairedFrame(currentFrame: offscreenFrame, visibleFrame: visibleFrame)
    XCTAssertEqual(repaired.origin.x, visibleFrame.midX - 590, accuracy: 0.5)
    XCTAssertEqual(repaired.origin.y, visibleFrame.midY - 396, accuracy: 0.5)
    XCTAssertEqual(repaired.size.width, 1180)
    XCTAssertEqual(repaired.size.height, 792)
  }

  func testWindowRepairEnforcesMinimumSize() {
    let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    let tinyFrame = NSRect(x: 200, y: 200, width: 400, height: 300)

    let repaired = JobmaxxingWindowLayout.repairedFrame(currentFrame: tinyFrame, visibleFrame: visibleFrame)
    XCTAssertEqual(repaired.size.width, JobmaxxingWindowLayout.minimumSize.width)
    XCTAssertEqual(repaired.size.height, JobmaxxingWindowLayout.minimumSize.height)
  }
}
