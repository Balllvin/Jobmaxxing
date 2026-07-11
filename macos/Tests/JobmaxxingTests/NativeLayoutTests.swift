import XCTest
@testable import Jobmaxxing

final class NativeLayoutTests: XCTestCase {
  func testMinimumWindowSupportsNarrowDesktopLayout() {
    XCTAssertLessThanOrEqual(JobmaxxingWindowLayout.minimumSize.width, 820)
    XCTAssertLessThanOrEqual(JobmaxxingWindowLayout.minimumSize.height, 620)
  }
}
