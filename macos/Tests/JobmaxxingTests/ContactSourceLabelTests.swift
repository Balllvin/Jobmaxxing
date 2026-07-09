import XCTest
@testable import Jobmaxxing

final class ContactSourceLabelTests: XCTestCase {
  func testLinkedInPersonURLUsesProfileLabel() {
    let source = ContactSourceLabel(rawValue: "https://ch.linkedin.com/in/rodolphe-dehin-60b513129")

    XCTAssertEqual(source.title, "LinkedIn profile")
    XCTAssertEqual(source.rowLabel, "LinkedIn profile")
  }

  func testWhatsAppSourceUsesThreadLabelWithoutURL() {
    let source = ContactSourceLabel(rawValue: "whatsapp:274504731345039@lid")

    XCTAssertEqual(source.title, "WhatsApp thread")
    XCTAssertEqual(source.rowLabel, "WhatsApp thread")
    XCTAssertNil(source.url)
  }

  func testExample RoboticsSourcesUseUsefulSourceLabels() {
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://www.medela.com/en/working-at-medela").title,
      "Example Robotics careers"
    )
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://www.medela.com/en/about-medela/medela-news").title,
      "Example Robotics news"
    )
  }
}
