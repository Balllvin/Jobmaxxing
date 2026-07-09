import XCTest
@testable import Jobmaxxing

final class WhatsAppContactImportTests: XCTestCase {
  func testPhoneNumberFromWhatsAppJIDUsesDialableIdentifier() {
    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppJID: "41791234567@s.whatsapp.net"), "+41791234567")
  }

  func testPhoneNumberFromGroupJIDIsEmpty() {
    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppJID: "1234567890-987654321@g.us"), "")
  }

  func testPhoneNumberFromOpaqueLIDIsEmpty() {
    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppJID: "274504731345039@lid"), "")
  }

  func testPhoneNumberFromCandidateFallsBackToPhoneLikeDisplayName() {
    let candidate = WhatsAppThreadCandidate(
      id: "348",
      chatSessionID: 348,
      displayName: "+41 76 739 35 58",
      jid: "274504731345039@lid",
      messageCount: 4,
      lastMessagePreview: "",
      databasePath: "/tmp/whatsapp.sqlite"
    )

    XCTAssertEqual(JobmaxxingStore.phoneNumber(fromWhatsAppCandidate: candidate), "+41767393558")
  }

  func testContactNamePrefersReadableDisplayName() {
    let candidate = WhatsAppThreadCandidate(
      id: "1",
      chatSessionID: 1,
      displayName: "Daniel Meier",
      jid: "41791234567@s.whatsapp.net",
      messageCount: 1,
      lastMessagePreview: "",
      databasePath: "/tmp/whatsapp.sqlite"
    )

    XCTAssertEqual(JobmaxxingStore.whatsAppContactName(candidate: candidate, fallbackName: ""), "Daniel Meier")
  }

  func testContactNameFallsBackWhenDisplayNameIsOnlyPhoneMetadata() {
    let candidate = WhatsAppThreadCandidate(
      id: "1",
      chatSessionID: 1,
      displayName: "41791234567",
      jid: "41791234567@s.whatsapp.net",
      messageCount: 1,
      lastMessagePreview: "",
      databasePath: "/tmp/whatsapp.sqlite"
    )

    XCTAssertEqual(JobmaxxingStore.whatsAppContactName(candidate: candidate, fallbackName: "Recruiter from WhatsApp"), "Recruiter from WhatsApp")
  }
}
