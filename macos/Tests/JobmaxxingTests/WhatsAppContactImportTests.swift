import XCTest
@testable import Jobmaxxing

final class WhatsAppContactImportTests: XCTestCase {
  func testPhoneNumberFromWhatsAppJIDUsesDialableIdentifier() {
    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppJID: "12025550100@s.whatsapp.net"), "+12025550100")
  }

  func testPhoneNumberFromGroupJIDIsEmpty() {
    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppJID: "123-456@g.us"), "")
  }

  func testPhoneNumberFromOpaqueLIDIsEmpty() {
    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppJID: "999@lid"), "")
  }

  func testPhoneNumberFromCandidateFallsBackToPhoneLikeDisplayName() {
    let candidate = WhatsAppThreadCandidate(
      id: "348",
      chatSessionID: 348,
      displayName: "+1 202 555 0100",
      jid: "999@lid",
      messageCount: 4,
      lastMessagePreview: "",
      databasePath: "/tmp/whatsapp.sqlite"
    )

    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppCandidate: candidate), "+12025550100")
  }

  func testContactNamePrefersReadableDisplayName() {
    let candidate = WhatsAppThreadCandidate(
      id: "1",
      chatSessionID: 1,
      displayName: "Example Contact",
      jid: "12025550100@s.whatsapp.net",
      messageCount: 1,
      lastMessagePreview: "",
      databasePath: "/tmp/whatsapp.sqlite"
    )

    XCTAssertEqual(JobmaxxingStore.whatsAppContactName(candidate: candidate, fallbackName: ""), "Example Contact")
  }

  func testContactNameFallsBackWhenDisplayNameIsOnlyPhoneMetadata() {
    let candidate = WhatsAppThreadCandidate(
      id: "1",
      chatSessionID: 1,
      displayName: "12025550100",
      jid: "12025550100@s.whatsapp.net",
      messageCount: 1,
      lastMessagePreview: "",
      databasePath: "/tmp/whatsapp.sqlite"
    )

    XCTAssertEqual(JobmaxxingStore.whatsAppContactName(candidate: candidate, fallbackName: "Recruiter from WhatsApp"), "Recruiter from WhatsApp")
  }
}
