import XCTest
@testable import Jobmaxxing

@MainActor
final class NativeStorageIntegrityTests: XCTestCase {
  func testMissingNativeStateDoesNotWriteDuringLoad() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")

    let store = JobmaxxingStore(stateURL: stateURL)

    XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))
    XCTAssertNil(store.storageAlert)
    XCTAssertEqual(store.state.profile.name, JobmaxxingStore.defaultState.profile.name)
  }

  func testCorruptNativeStateIsBackedUpAndNotOverwritten() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    try "{not json".write(to: stateURL, atomically: true, encoding: .utf8)

    let store = JobmaxxingStore(stateURL: stateURL)
    let backupFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)
      .filter { $0.hasPrefix("state.json.corrupt-") && $0.hasSuffix(".backup") }

    XCTAssertEqual(String(contentsOf: stateURL), "{not json")
    XCTAssertEqual(backupFiles.count, 1)
    XCTAssertEqual(store.storageAlert?.title, "Recovered from corrupt Jobmaxxing state")
    XCTAssertTrue(store.storageAlert?.message.contains("temporary default state") == true)
  }

  func testNativeSaveFailureReachesStorageAlert() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let parentFile = directory.appendingPathComponent("not-a-directory")
    try "blocking parent".write(to: parentFile, atomically: true, encoding: .utf8)
    let stateURL = parentFile.appendingPathComponent("state.json")
    let store = JobmaxxingStore(stateURL: stateURL)

    store.updateProfile(store.state.profile)

    XCTAssertEqual(store.storageAlert?.title, "Could not save Jobmaxxing state")
    XCTAssertTrue(store.storageAlert?.message.contains("not written") == true)
  }

  func testUnknownNativeConnectorsSurviveMigrationAndSave() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    let unknown = IntegrationConnector(
      id: "future-connector",
      label: "Future Connector",
      provider: "Local",
      purpose: "Regression test connector.",
      isEnabled: true,
      isConnected: false,
      category: "Local",
      capabilities: ["test"],
      configFields: nil,
      isHidden: nil
    )
    var state = JobmaxxingStore.defaultState
    state.integrationConnectors = [unknown] + (state.integrationConnectors ?? [])
    try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic])

    let store = JobmaxxingStore(stateURL: stateURL)
    let migrated = try JSONDecoder().decode(JobmaxxingState.self, from: Data(contentsOf: stateURL))

    XCTAssertTrue((store.state.integrationConnectors ?? []).contains(unknown))
    XCTAssertTrue((migrated.integrationConnectors ?? []).contains(unknown))
  }

  func testNativeLoadNormalizesUserVisibleLanguageDriftIdempotently() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    var state = JobmaxxingStore.defaultState
    state.profile.evidence = [
      EvidenceItem(
        id: "fact-contract",
        title: "ExampleOps / ExampleData data tooling contract",
        proof: "Contracted as working student at ExampleData AG / ExampleOps AG to support reporting.",
        sourceURL: "Apple Mail contract evidence: Local Candidate Vertrag.pdf",
        tags: ["working student"],
        strength: 5
      )
    ]
    state.profile.experience = [
      ProfileExperience(
        id: "exp-contract",
        title: "working student",
        organization: "ExampleData AG / ExampleOps AG",
        location: "Zurich",
        period: "Contract",
        summary: "Contracted as working student at ExampleData AG / ExampleOps AG.",
        bullets: ["Supported reporting."],
        sourceURL: "Apple Mail contract evidence: Local Candidate Vertrag.pdf"
      )
    ]
    state.jobs = [
      JobRecord(
        id: "job-drift",
        company: "Example Manufacturing",
        role: "Intern Applied AI &amp; AI-Platform",
        sourceURL: "https://example.com",
        description: "Work on AIML and RAG.",
        stage: .ready,
        score: 91,
        keywords: ["AIML", "Data / ML / AI Intern"],
        risks: [],
        nextActions: ["Review Daten trifft auf Systeme: Trainee-Programm, 80-100%"],
        notes: "Source title: Daten trifft auf Systeme: Trainee-Programm, 80-100%",
        draft: ApplicationDraft(
          headline: "Intern Applied AI &amp; AI-Platform candidate",
          resumeBullets: ["Evidence for Data / ML / AI Intern."],
          coverLetter: "Sehr geehrte Frau Beispiel,\n\nIch bewerbe mich für das Trainee-Programm Daten trifft auf Systeme.",
          recruiterMessage: "Hi, I found the Data / ML / AI Intern role.",
          screeningAnswers: ["Warum Example?: Daten trifft auf Systeme."],
          evidenceLinks: ["Apple Mail contract evidence: Local Candidate Vertrag.pdf"],
          claimTrace: nil,
          assumptions: ["Role priorities include AIML."],
          missingEvidence: nil
        )
      )
    ]
    state.companyProfiles = [
      CompanyProfile(
        id: "example-manufacturing",
        name: "Example Manufacturing",
        website: "https://example.com",
        linkedInURL: "",
        category: "Applied AI",
        size: "Unknown",
        headquarters: "Zug",
        publicStatus: "Public job posting reviewed",
        summary: "Intern Applied AI &amp; AI-Platform role.",
        relationship: "Application target",
        applicationIDs: ["job-drift"],
        experienceIDs: [],
        submittedMaterials: [
          CompanySubmission(
            id: "submission-drift",
            jobID: "job-drift",
            materialType: "Application draft",
            title: "Daten trifft auf Systeme: Trainee-Programm, 80-100% application pack",
            summary: "Drafted for Intern Applied AI &amp; AI-Platform.",
            sourceURL: "https://example.com",
            status: "Proposed"
          )
        ],
        people: [],
        research: CompanyResearch(
          status: "Source reviewed",
          confidence: 90,
          websitePages: [
            CompanyResearchPage(
              id: "page-drift",
              title: "Example Manufacturing Intern Applied AI &amp; AI-Platform",
              url: "https://example.com",
              summary: "Source page for Daten trifft auf Systeme: Trainee-Programm, 80-100%."
            )
          ],
          products: [],
          businessModel: "",
          leadership: [],
          hiringSignals: ["AIML"],
          risks: [],
          openQuestions: [],
          sourceURLs: ["https://example.com"],
          agentPlan: []
        ),
        nextActions: [],
        notes: ""
      )
    ]
    state.contacts = [
      ContactRecord(
        id: "riley-live",
        name: "Riley",
        role: "Supply Chain internship contact",
        jobDescription: "",
        linkedInURL: "https://www.linkedin.com/in/riley-rivera-example",
        phone: "",
        email: "",
        location: "",
        sourceURL: "",
        relationship: "Hiring contact",
        howMet: "WhatsApp",
        notes: "",
        personalNotes: "",
        projectNotes: "",
        companyLinks: [
          ContactCompanyLink(
            id: "riley-example-devices",
            companyID: "example-devices",
            companyName: "Example Devices",
            role: "Supply Chain internship contact",
            relationship: "Hiring contact",
            notes: "",
            sourceURL: ""
          )
        ],
        research: ContactResearchProfile(
          status: "Enhanced",
          summary: "LinkedIn public search identifies him as Riley Rivera.",
          publicFacts: ["LinkedIn public search identifies him as Riley Rivera."],
          sourceURLs: [],
          openQuestions: [],
          proposedAdditions: []
        )
      )
    ]
    try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic])

    let store = JobmaxxingStore(stateURL: stateURL)
    let afterFirstLoad = try Data(contentsOf: stateURL)
    _ = JobmaxxingStore(stateURL: stateURL)
    let afterSecondLoad = try Data(contentsOf: stateURL)

    XCTAssertEqual(store.state.jobs[0].role, "Applied AI and AI Platform Intern")
    XCTAssertEqual(store.state.jobs[0].keywords, ["AI and ML", "Data, ML, and AI Intern"])
    XCTAssertEqual(store.state.jobs[0].draft?.headline, "Applied AI and AI Platform Intern candidate")
    XCTAssertTrue(store.state.jobs[0].draft?.coverLetter.contains("Sehr geehrte Frau Beispiel") == true)
    XCTAssertEqual(store.state.contacts?.first?.name, "Riley Rivera")
    XCTAssertEqual(store.state.profile.experience?.first?.title, "Working Student")
    XCTAssertTrue(store.state.profile.evidence[0].proof.contains("source role title: working student"))
    XCTAssertTrue(store.state.profile.evidence[0].sourceURL.contains("original German filename: Local Candidate Vertrag.pdf"))
    XCTAssertTrue(store.state.companyProfiles?.first?.submittedMaterials.first?.title.contains("Data and Systems Trainee Program, 80-100%") == true)
    XCTAssertEqual(afterSecondLoad, afterFirstLoad)
  }

  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
