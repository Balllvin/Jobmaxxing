import XCTest
@testable import Jobmaxxing

final class DashboardDisplayTests: XCTestCase {
  func testEvidenceGapRowsUseActionWithoutRepeatedPrefix() {
    let item = EvidenceItem(
      id: "proof-ai-equity",
      title: "AI equity research workflows",
      proof: "Built research workflow.",
      sourceURL: "",
      tags: ["proof"],
      strength: 4
    )

    XCTAssertEqual(dashboardEvidenceGapTitle(item), "AI equity research workflows")
    XCTAssertEqual(dashboardEvidenceGapActionTitle(item), "Link source")
    XCTAssertFalse(dashboardEvidenceGapTitle(item).contains("Add source:"))
  }

  func testCompanyRowsUseShortResearchStatus() {
    let researched = company(name: "Example Systems", researchStatus: "Researched from official and public sources")
    let missing = company(name: "Sample Labs", researchStatus: "Not researched")

    XCTAssertEqual(dashboardCompanyTitle(researched), "Example Systems")
    XCTAssertEqual(dashboardCompanyResearchStatus(researched), "Research ready")
    XCTAssertEqual(dashboardCompanyActionTitle(researched), "Map proof")
    XCTAssertEqual(dashboardCompanyResearchStatus(missing), "Research needed")
    XCTAssertEqual(dashboardCompanyActionTitle(missing), "Research")
  }

  func testActivityRowsSeparateSafetyStatusFromDetail() {
    let event = ActivityEvent(
      id: "event-application",
      sequence: 1,
      actor: "Jobmaxxing",
      jobID: "job-google",
      title: "Prepared application",
      detail: "Proof-linked draft for Example Systems. Not submitted.",
      approval: ""
    )

    XCTAssertEqual(dashboardActivityTitle(event), "Prepared application")
    XCTAssertEqual(dashboardActivityDetail(event), "Proof-linked draft for Google.")
    XCTAssertEqual(dashboardActivityActionTitle(event), "Not submitted")
  }

  func testActivityRowsNormalizeRawApprovalVocabulary() {
    let event = ActivityEvent(
      id: "event-interview",
      sequence: 2,
      actor: "Jobmaxxing",
      jobID: "job-example-systems",
      title: "Prepared interview",
      detail: "Text interview questions and scorecard for Example Systems.",
      approval: "not needed"
    )

    XCTAssertEqual(dashboardActivityActionTitle(event), "No approval")
  }

  private func company(name: String, researchStatus: String) -> CompanyProfile {
    CompanyProfile(
      id: name.lowercased(),
      name: name,
      website: "https://example.com",
      linkedInURL: "",
      category: "Target company",
      size: "Unknown",
      headquarters: "Unknown",
      publicStatus: "Unknown",
      summary: "",
      relationship: "Application target",
      applicationIDs: [],
      experienceIDs: [],
      submittedMaterials: [],
      people: [],
      research: CompanyResearch(
        status: researchStatus,
        confidence: 50,
        websitePages: [],
        products: [],
        businessModel: "",
        leadership: [],
        hiringSignals: [],
        risks: [],
        openQuestions: [],
        sourceURLs: [],
        agentPlan: []
      ),
      nextActions: ["Map saved roles to user evidence."],
      notes: ""
    )
  }
}
