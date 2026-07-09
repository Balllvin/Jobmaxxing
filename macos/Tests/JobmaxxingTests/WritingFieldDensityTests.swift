import XCTest
@testable import Jobmaxxing

final class WritingFieldDensityTests: XCTestCase {
  func testProofDocumentTaskKeepsMetadataInGeneratedChecklistDefaults() {
    XCTAssertEqual(DocumentWorkflowTask.proof.label, "Proof")
    XCTAssertEqual(DocumentWorkflowTask.proof.defaultInput, "Claim, source, tags, and where it can be cited")
    XCTAssertFalse(DocumentWorkflowTask.proof.needsRecipient)
  }

  func testDocumentTasksKeepOneGuidedNotesFieldPerAction() {
    XCTAssertEqual(DocumentWorkflowTask.attach.defaultInput, "CV, cover letter, contact, work authorization, availability, and manual checkpoint")
    XCTAssertEqual(DocumentWorkflowTask.tailor.defaultInput, "Target role requirements, proof to keep, tone, and edits to make")
    XCTAssertEqual(DocumentWorkflowTask.companyAnalysis.defaultInput, "Business, role context, people, risks, and open questions")
    XCTAssertEqual(DocumentWorkflowTask.fields.defaultInput, "ATS, email, or LinkedIn fields that need manual review")
  }
}
