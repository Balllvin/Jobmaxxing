import XCTest
@testable import Jobmaxxing

final class ContactSourceLabelTests: XCTestCase {
  func testLinkedInPersonURLUsesProfileLabel() {
    let source = ContactSourceLabel(rawValue: "https://ch.linkedin.com/in/example-candidate")

    XCTAssertEqual(source.title, "LinkedIn profile")
    XCTAssertEqual(source.rowLabel, "LinkedIn profile")
  }

  func testWhatsAppSourceUsesThreadLabelWithoutURL() {
    let source = ContactSourceLabel(rawValue: "whatsapp:274504731345039@lid")

    XCTAssertEqual(source.title, "WhatsApp thread")
    XCTAssertEqual(source.rowLabel, "WhatsApp thread")
    XCTAssertNil(source.url)
  }

  func testGenericCompanyURLUsesDomainLabel() {
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://careers.example.com/open-roles").title,
      "careers.example.com"
    )
  }
}
