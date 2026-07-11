import XCTest
@testable import Jobmaxxing

final class ContactSourceLabelTests: XCTestCase {
  func testLinkedInPersonURLUsesProfileLabel() {
    let source = ContactSourceLabel(rawValue: "https://example.com/profiles/example-contact")

    XCTAssertEqual(source.title, "LinkedIn profile")
    XCTAssertEqual(source.rowLabel, "LinkedIn profile")
  }

  func testWhatsAppSourceUsesThreadLabelWithoutURL() {
    let source = ContactSourceLabel(rawValue: "whatsapp:274504731345039@lid")

    XCTAssertEqual(source.title, "WhatsApp thread")
    XCTAssertEqual(source.rowLabel, "WhatsApp thread")
    XCTAssertNil(source.url)
  }

  func testExampleCoSourcesUseUsefulSourceLabels() {
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://example.com").title,
      "ExampleCo careers"
    )
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://example.com").title,
      "ExampleCo news"
    )
  }
}
