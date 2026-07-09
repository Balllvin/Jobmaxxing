import XCTest
@testable import Jobmaxxing

final class ContactSourceLabelTests: XCTestCase {
  func testLinkedInPersonURLUsesProfileLabel() {
    let source = ContactSourceLabel(rawValue: "https://www.linkedin.com/in/riley-rivera-example")

    XCTAssertEqual(source.title, "LinkedIn profile")
    XCTAssertEqual(source.rowLabel, "LinkedIn profile")
  }

  func testWhatsAppSourceUsesThreadLabelWithoutURL() {
    let source = ContactSourceLabel(rawValue: "whatsapp:274504731345039@lid")

    XCTAssertEqual(source.title, "WhatsApp thread")
    XCTAssertEqual(source.rowLabel, "WhatsApp thread")
    XCTAssertNil(source.url)
  }

  func testExampleDeviceSourcesUseUsefulSourceLabels() {
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://www.example-devices.com/en/working-at-example-devices").title,
      "Company careers"
    )
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://www.example-devices.com/en/about-example-devices/example-devices-news").title,
      "Company news"
    )
  }
}
