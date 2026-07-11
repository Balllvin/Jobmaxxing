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

  func testLegacyOpenCodeStateMigratesToGoWithoutDroppingTheRoute() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    var state = JobmaxxingStore.defaultState
    state.integrationConnectors = [
      IntegrationConnector(
        id: "opencode",
        label: "OpenCode Go",
        provider: "OpenCode",
        purpose: "Legacy bridge.",
        isEnabled: false,
        isConnected: false,
        category: "Models",
        capabilities: ["Light"],
        configFields: [ConnectorConfigField(id: "base-url", label: "Base URL", value: "http://127.0.0.1:8787", placeholder: "", isSecret: false)],
        isHidden: true
      )
    ]
    state.modelRoutes[0].provider = "OpenCode"
    state.modelRoutes[0].model = "deepseek-v4-flash"
    try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic])

    let store = JobmaxxingStore(stateURL: stateURL)
    let connectors = store.state.integrationConnectors ?? []

    XCTAssertFalse(connectors.contains(where: { $0.id == "opencode" }))
    XCTAssertEqual(connectors.filter { $0.id == "opencode-go" }.count, 1)
    XCTAssertTrue(connectors.contains(where: { $0.id == "opencode-zen" }))
    XCTAssertEqual(store.state.modelRoutes.first?.provider, "OpenCode Go")
    XCTAssertEqual(store.state.modelRoutes.first?.model, "deepseek-v4-flash")
  }

  func testNativeLoadNormalizesUserVisibleLanguageDriftIdempotently() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    var state = JobmaxxingStore.defaultState
    state.profile.evidence = [
      EvidenceItem(
        id: "fact-contract",
        title: "OPEKTUM / PEKTOPROP data tooling contract",
        proof: "Contracted as Werkstudent at PEKTOPROP AG / OPEKTUM AG to support reporting.",
        sourceURL: "Apple Mail contract evidence: Example User Vertrag.pdf",
        tags: ["Werkstudent"],
        strength: 5
      )
    ]
    state.profile.experience = [
      ProfileExperience(
        id: "exp-contract",
        title: "Werkstudent",
        organization: "PEKTOPROP AG / OPEKTUM AG",
        location: "Zurich",
        period: "Contract",
        summary: "Contracted as Werkstudent at PEKTOPROP AG / OPEKTUM AG.",
        bullets: ["Supported reporting."],
        sourceURL: "Apple Mail contract evidence: Example User Vertrag.pdf"
      )
    ]
    state.jobs = [
      JobRecord(
        id: "job-drift",
        company: "V-ZUG",
        role: "Intern Applied AI &amp; AI-Platform",
        sourceURL: "https://example.com",
        description: "Work on AIML and RAG.",
        stage: .ready,
        score: 91,
        keywords: ["AIML", "Data / ML / AI Intern"],
        risks: [],
        nextActions: ["Review Finance trifft auf Engineering: Trainee-Programm beim VZ, 80-100%"],
        notes: "Source title: Finance trifft auf Engineering: Trainee-Programm beim VZ, 80-100%",
        draft: ApplicationDraft(
          headline: "Intern Applied AI &amp; AI-Platform candidate",
          resumeBullets: ["Evidence for Data / ML / AI Intern."],
          coverLetter: "Sehr geehrte Frau Malcolm,\n\nIch bewerbe mich für das Trainee-Programm Finance trifft auf Engineering.",
          recruiterMessage: "Hi, I found the Data / ML / AI Intern role.",
          screeningAnswers: ["Warum VZ?: Finance trifft auf Engineering."],
          evidenceLinks: ["Apple Mail contract evidence: Example User Vertrag.pdf"],
          claimTrace: nil,
          assumptions: ["Role priorities include AIML."],
          missingEvidence: nil
        )
      )
    ]
    state.companyProfiles = [
      CompanyProfile(
        id: "v-zug",
        name: "V-ZUG",
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
            title: "Finance trifft auf Engineering: Trainee-Programm beim VZ, 80-100% application pack",
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
              title: "V-ZUG Intern Applied AI &amp; AI-Platform",
              url: "https://example.com",
              summary: "Source page for Finance trifft auf Engineering: Trainee-Programm beim VZ, 80-100%."
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
        id: "example-contact-live",
        name: "Example Contact",
        role: "Supply Chain internship contact",
        jobDescription: "",
        linkedInURL: "https://example.com/profiles/example-contact",
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
            id: "example-contact-exampleco",
            companyID: "exampleco",
            companyName: "ExampleCo",
            role: "Supply Chain internship contact",
            relationship: "Hiring contact",
            notes: "",
            sourceURL: ""
          )
        ],
        research: ContactResearchProfile(
          status: "Enhanced",
          summary: "LinkedIn public search identifies him as Example Contact.",
          publicFacts: ["LinkedIn public search identifies him as Example Contact."],
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
    XCTAssertTrue(store.state.jobs[0].draft?.coverLetter.contains("Sehr geehrte Frau Malcolm") == true)
    XCTAssertEqual(store.state.contacts?.first?.name, "Example Contact")
    XCTAssertEqual(store.state.profile.experience?.first?.title, "Working Student")
    XCTAssertTrue(store.state.profile.evidence[0].proof.contains("source role title: Werkstudent"))
    XCTAssertTrue(store.state.profile.evidence[0].sourceURL.contains("original German filename: Example User Vertrag.pdf"))
    XCTAssertTrue(store.state.companyProfiles?.first?.submittedMaterials.first?.title.contains("Finance and Engineering Trainee Program at VZ, 80-100%") == true)
    XCTAssertEqual(afterSecondLoad, afterFirstLoad)
  }

  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
