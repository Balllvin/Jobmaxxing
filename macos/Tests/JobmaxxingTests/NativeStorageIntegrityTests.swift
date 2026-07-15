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

  func testFreshNativeStateDoesNotInventAUserStory() {
    let profile = JobmaxxingStore.defaultState.profile

    XCTAssertTrue(profile.name.isEmpty)
    XCTAssertNil(profile.headline)
    XCTAssertNil(profile.about)
    XCTAssertTrue(profile.targetRoles.isEmpty)
    XCTAssertTrue(profile.locations.isEmpty)
    XCTAssertTrue(profile.evidence.isEmpty)
    XCTAssertEqual(profile.experience, [])
    XCTAssertEqual(profile.profileProjects, [])
    XCTAssertEqual(profile.personalMemory, [])
    XCTAssertTrue(JobmaxxingStore.defaultCompanyProfiles.isEmpty)
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

  func testNativeLoadPreservesProfileTextAndSourcesExactly() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    var state = JobmaxxingStore.defaultState
    var profile = state.profile
    profile.name = "Rae Okafor"
    profile.headline = "Builds calm tools for complex work."
    profile.about = "I started close to operations.\n\nNow I build software that makes review and ownership clear."
    profile.experience = [
      ProfileExperience(
        id: "experience-one",
        title: "Product engineer",
        organization: "Northstar Labs",
        location: "Remote",
        period: "Three years",
        summary: "Worked beside operators.\n\nTurned repeated handoffs into one reviewable workflow.",
        bullets: ["Reduced duplicate handoffs.", "Kept final approval with the operator."],
        sourceURL: "file:///fixture/profile/employment-record.pdf",
        projects: [
          ProfileExperienceProject(
            id: "experience-project-one",
            name: "Planning workspace",
            summary: "A shared view of daily work.",
            detail: "Mapped the manual process.\n\nShipped the smallest useful workflow.",
            specificSample: "One team replaced three handoff sheets with a single review.",
            tools: ["Swift", "SQLite"],
            metrics: ["Three handoffs became one review"],
            tags: ["operations"],
            sourceURL: "file:///fixture/profile/project-notes.md"
          )
        ]
      )
    ]
    profile.evidence = [
      EvidenceItem(
        id: "evidence-one",
        title: "Planning outcome",
        proof: "A weekly reconciliation went from a full afternoon to one review pass.\n\nThe operator kept final approval.",
        sourceURL: "file:///fixture/profile/outcome-note.md",
        tags: ["workflow"],
        strength: 5
      )
    ]
    profile.personalMemory = [
      ProfileMemory(
        id: "memory-one",
        kind: "Working preference",
        title: "Clear ownership",
        detail: "I prefer short feedback loops.\n\nI write down who makes the final call.",
        source: "User note",
        strength: 5
      )
    ]
    state.profile = profile
    state.companyProfiles = []
    try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic])

    let store = JobmaxxingStore(stateURL: stateURL)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    XCTAssertEqual(try encoder.encode(store.state.profile), try encoder.encode(profile))
    XCTAssertEqual(store.state.profile.about, profile.about)
    XCTAssertEqual(store.state.profile.experience?.first?.projects?.first?.detail, profile.experience?.first?.projects?.first?.detail)
    XCTAssertEqual(store.state.profile.evidence.first?.proof, profile.evidence.first?.proof)
    XCTAssertEqual(store.state.profile.evidence.first?.sourceURL, profile.evidence.first?.sourceURL)
    XCTAssertEqual(store.state.profile.personalMemory?.first?.detail, profile.personalMemory?.first?.detail)
  }

  func testExplicitEmptyCompanyProfilesRemainEmptyWhenJobsAndExperienceExist() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    var state = JobmaxxingStore.defaultState
    state.profile.experience = [
      ProfileExperience(
        id: "experience-company",
        title: "Engineer",
        organization: "Northstar Labs",
        location: "Remote",
        period: "Two years",
        summary: "Built internal tools.",
        bullets: [],
        sourceURL: "https://example.com/work"
      )
    ]
    state.jobs = [
      JobRecord(
        id: "job-company",
        company: "Cedar Systems",
        role: "Product engineer",
        sourceURL: "https://example.com/job",
        description: "Build tools for operational teams.",
        stage: .saved,
        score: 0,
        keywords: [],
        risks: [],
        nextActions: [],
        notes: "",
        draft: nil
      )
    ]
    state.companyProfiles = []
    try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic])

    let store = JobmaxxingStore(stateURL: stateURL)

    XCTAssertEqual(store.state.companyProfiles, [])
  }

  func testProfileSaveFailureRollsBackInMemoryState() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let parentFile = directory.appendingPathComponent("not-a-directory")
    try "blocking parent".write(to: parentFile, atomically: true, encoding: .utf8)
    let store = JobmaxxingStore(stateURL: parentFile.appendingPathComponent("state.json"))
    let previous = store.state.profile
    var edited = previous
    edited.name = "Unsaved name"

    XCTAssertFalse(store.updateProfile(edited))
    XCTAssertEqual(store.state.profile.name, previous.name)
    XCTAssertEqual(store.state.profile.about, previous.about)
  }

  func testLinkedInPlanSurvivesUnrelatedEditsAndClearsWhenURLChanges() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let stateURL = directory.appendingPathComponent("state.json")
    var state = JobmaxxingStore.defaultState
    state.profile.linkedInURL = "https://www.linkedin.com/in/candidate"
    state.profile.linkedInImportPlan = ProfileImportPlan(
      sourceURL: "https://www.linkedin.com/in/candidate",
      status: "Ready for review",
      checkpoint: "Review before import",
      steps: ["Open the public profile"],
      fields: ["Experience"]
    )
    try JSONEncoder().encode(state).write(to: stateURL, options: [.atomic])
    let store = JobmaxxingStore(stateURL: stateURL)

    var unrelatedEdit = store.state.profile
    unrelatedEdit.name = "Rae Okafor"
    XCTAssertTrue(store.updateProfile(unrelatedEdit))
    XCTAssertNotNil(store.state.profile.linkedInImportPlan)

    var changedLink = store.state.profile
    changedLink.linkedInURL = "https://www.linkedin.com/in/updated-candidate"
    XCTAssertTrue(store.updateProfile(changedLink))
    XCTAssertNil(store.state.profile.linkedInImportPlan)
  }

  private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }
}
