import XCTest
@testable import Jobmaxxing

final class ContactSourceLabelTests: XCTestCase {
  func testLinkedInPersonURLUsesProfileLabel() {
    let source = ContactSourceLabel(rawValue: "https://ch.linkedin.com/in/example-contact-60b513129")

    XCTAssertEqual(source.title, "LinkedIn profile")
    XCTAssertEqual(source.rowLabel, "LinkedIn profile")
  }

  func testWhatsAppSourceUsesThreadLabelWithoutURL() {
    let source = ContactSourceLabel(rawValue: "whatsapp:274504731345039@lid")

    XCTAssertEqual(source.title, "WhatsApp thread")
    XCTAssertEqual(source.rowLabel, "WhatsApp thread")
    XCTAssertNil(source.url)
  }

  func testExample CompanySourcesUseUsefulSourceLabels() {
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://www.example-company.com/en/working-at-example-company").title,
      "Example Company careers"
    )
    XCTAssertEqual(
      ContactSourceLabel(rawValue: "https://www.example-company.com/en/about-example-company/example-company-news").title,
      "Example Company news"
    )
  }
}
