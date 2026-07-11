import XCTest
@testable import Jobmaxxing

final class ApplicationsViewHelperTests: XCTestCase {
  func testApplicationSourceLabelUsesReadableDomainAndSlug() {
    let label = applicationSourceLabel(for: "https://www.greenhouse.io/jobs/senior-supply-chain-manager?gh_src=feed")

    XCTAssertEqual(label, "greenhouse.io - senior supply chain manager")
    XCTAssertFalse(label.contains("https://"))
    XCTAssertFalse(label.contains("gh_src"))
  }

  func testApplicationSourceLabelRejectsUnsafeSchemes() {
    XCTAssertEqual(applicationSourceLabel(for: "file:///Users/example/private.pdf"), "Invalid job post")
    XCTAssertEqual(applicationSourceLabel(for: ""), "No job post")
  }

  func testLinkedInPeopleSearchKeepsCompanyAndRoleInQuery() throws {
    let rawURL = linkedInPeopleSearch(company: "ExampleCo", role: "Supply Chain Analyst")
    let components = try XCTUnwrap(URLComponents(string: rawURL))
    let keywords = try XCTUnwrap(components.queryItems?.first(where: { $0.name == "keywords" })?.value)

    XCTAssertEqual(components.scheme, "https")
    XCTAssertEqual(components.host, "www.linkedin.com")
    XCTAssertTrue(keywords.contains("ExampleCo"))
    XCTAssertTrue(keywords.contains("Supply Chain Analyst"))
  }

  func testDraftActionIsPrimaryOnlyWhenNoDraftExists() {
    XCTAssertEqual(applicationDraftActionTitle(hasDraft: false), "Draft application")
    XCTAssertTrue(applicationDraftActionIsPrimary(hasDraft: false))

    XCTAssertEqual(applicationDraftActionTitle(hasDraft: true), "Regenerate draft")
    XCTAssertFalse(applicationDraftActionIsPrimary(hasDraft: true))
  }

  func testApplicationToDoItemsMergeRisksBeforeNextActions() {
    var record = job(company: "Lakera", role: "Software Engineer")
    record.risks = ["AI security domain depth may be a gap"]
    record.nextActions = ["Review application pack.", "Verify posting in browser."]

    XCTAssertEqual(
      applicationToDoItems(for: record),
      [
        "Before submitting: AI security domain depth may be a gap",
        "Review application pack.",
        "Verify posting in browser."
      ]
    )
  }

  func testApplicationToDoItemsDeduplicateCaseInsensitiveItems() {
    var record = job(company: "Lakera", role: "Software Engineer")
    record.risks = ["Verify posting in browser."]
    record.nextActions = ["before submitting: verify posting in browser."]

    XCTAssertEqual(applicationToDoItems(for: record), ["Before submitting: Verify posting in browser."])
  }

  func testProofMetadataParsesOneGuidedFieldIntoTitleAndTags() {
    let document = document(title: "Operations case study")
    let job = job(company: "ExampleCo", role: "Supply Chain Analyst")
    let metadata = "Supplier resilience story # manufacturing, interview"

    XCTAssertEqual(proofTitle(from: metadata, document: document), "Supplier resilience story")
    XCTAssertEqual(
      proofTags(from: metadata, job: job),
      "proof, application, ExampleCo, Supply Chain Analyst, manufacturing, interview"
    )
  }

  func testDefaultProofMetadataKeepsGeneratedTitleAndContextTags() {
    let document = document(title: "CV proof")
    let job = job(company: "ExampleCo", role: "Planning Manager")

    XCTAssertEqual(defaultProofMetadata(document: document, job: job), "CV proof # proof, application, ExampleCo, Planning Manager")
  }

  private func document(title: String) -> CandidateDocument {
    CandidateDocument(
      id: "doc-1",
      title: title,
      fileName: "proof.pdf",
      filePath: "/tmp/proof.pdf",
      kind: "pdf",
      summary: "Evidence summary.",
      extractedText: "Evidence summary.",
      linkedEvidenceIDs: []
    )
  }

  private func job(company: String, role: String) -> JobRecord {
    JobRecord(
      id: "job-1",
      company: company,
      role: role,
      sourceURL: "https://jobs.example.com/apply",
      description: "Role details.",
      stage: .saved,
      score: 82,
      keywords: [],
      risks: [],
      nextActions: [],
      notes: "",
      draft: nil
    )
  }
}
