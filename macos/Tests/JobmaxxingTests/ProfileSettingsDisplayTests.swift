import XCTest
@testable import Jobmaxxing

@MainActor
final class ProfileStorySupportTests: XCTestCase {
  func testEmptyProfileUsesGenericIdentityAndHumanGuidance() {
    let profile = JobmaxxingStore.defaultState.profile

    XCTAssertEqual(ProfileStorySupport.displayName(for: profile), "Your profile")
    XCTAssertTrue(ProfileStorySupport.isEmpty(profile))
    XCTAssertFalse(ProfileStorySupport.hasStoryFacts(profile))
    XCTAssertTrue(ProfileStorySupport.suggestions(for: profile).allSatisfy { !$0.lowercased().contains("gap") })
  }

  func testRenderablePreferenceFieldsPreventTheEmptyState() {
    var profile = JobmaxxingStore.defaultState.profile
    profile.writingPreferences = ["Use direct language."]
    XCTAssertFalse(ProfileStorySupport.isEmpty(profile))

    profile.writingPreferences = []
    profile.certifications = ["Cloud architecture"]
    XCTAssertFalse(ProfileStorySupport.isEmpty(profile))

    profile.certifications = []
    profile.workAuthorization = "Eligible to work locally."
    XCTAssertFalse(ProfileStorySupport.isEmpty(profile))
  }

  func testStoryContextUsesWholeProfileWithoutLeakingSourceMetadata() {
    var profile = JobmaxxingStore.defaultState.profile
    profile.name = "Rae Okafor"
    profile.headline = "Builds operational software for complex teams."
    profile.about = "An old draft claim that the saved facts do not support."
    profile.targetRoles = ["Product engineer"]
    profile.locations = ["Remote"]
    profile.experience = [
      ProfileExperience(
        id: "experience-one",
        title: "Software engineer",
        organization: "Northstar Logistics",
        location: "Berlin",
        period: "Three years",
        summary: "Turned manual planning work into a reviewable workflow.",
        bullets: ["Worked with operators to replace repeated spreadsheet handoffs."],
        sourceURL: "/private/source/contract.pdf",
        projects: [
          ProfileExperienceProject(
            id: "project-one",
            name: "Review workspace",
            summary: "One place to review daily work.",
            detail: "Replaced repeated handoffs.",
            specificSample: "An operator reviewed the final state before publishing.",
            tools: ["Swift", "SQLite"],
            metrics: ["Four handoffs became one review"],
            tags: ["operations"],
            sourceURL: "/private/source/project-notes.md"
          )
        ]
      )
    ]
    profile.evidence = [
      EvidenceItem(
        id: "example-one",
        title: "Internal record label",
        proof: "Cut a weekly reconciliation from a full afternoon to one review pass.",
        sourceURL: "/private/source/contract.pdf",
        tags: ["operations"],
        strength: 5
      ),
      EvidenceItem(
        id: "source-only",
        title: "Internal contract record",
        proof: "",
        sourceURL: "/private/source/contract.pdf",
        tags: [],
        strength: 3
      )
    ]
    profile.skills = ["Workflow design"]
    profile.personalMemory = [
      ProfileMemory(id: "context-one", kind: "Preference", title: "Direct work", detail: "Prefers clear ownership and short feedback loops.", source: "User note", strength: 5)
    ]

    let context = ProfileStorySupport.storyFactsContext(for: profile)

    ["Rae Okafor", "Northstar Logistics", "weekly reconciliation", "Workflow design", "short feedback loops", "Swift", "Four handoffs became one review"].forEach {
      XCTAssertTrue(context.contains($0), "Missing story context for \($0)")
    }
    XCTAssertFalse(context.contains("/private/source"))
    XCTAssertFalse(context.contains("Internal record label"))
    XCTAssertFalse(context.contains("Internal contract record"))
    XCTAssertFalse(context.contains("old draft claim"))
    XCTAssertTrue(ProfileStorySupport.context(for: profile).contains("old draft claim"))
    XCTAssertEqual(ProfileStorySupport.evidenceText(profile.evidence[0]), "Cut a weekly reconciliation from a full afternoon to one review pass.")
  }

  func testSourceOnlyEvidenceDoesNotCountAsAStoryFact() {
    var profile = JobmaxxingStore.defaultState.profile
    profile.evidence = [
      EvidenceItem(
        id: "source-only",
        title: "Internal record",
        proof: "",
        sourceURL: "file:///private/profile/record.pdf",
        tags: [],
        strength: 3
      )
    ]

    XCTAssertTrue(ProfileStorySupport.narrativeEvidence(in: profile).isEmpty)
    XCTAssertFalse(ProfileStorySupport.hasStoryFacts(profile))
    XCTAssertTrue(ProfileStorySupport.suggestions(for: profile).contains { $0.contains("concrete outcomes") })
  }

  func testSourceOnlyAndBlankStructuredRowsStayOutOfTheStory() {
    var profile = JobmaxxingStore.defaultState.profile
    profile.experience = [
      ProfileExperience(
        id: "role-with-hidden-child",
        title: "Engineer",
        organization: "Northstar Labs",
        location: "",
        period: "",
        summary: "",
        bullets: [],
        sourceURL: "file:///private/profile/role.pdf",
        projects: [
          ProfileExperienceProject(
            id: "hidden-child",
            name: "",
            summary: "",
            detail: "",
            specificSample: "",
            tools: [],
            metrics: [],
            tags: [],
            sourceURL: "file:///private/profile/project.pdf"
          )
        ]
      )
    ]
    profile.profileProjects = [
      ProfileProject(id: "link-only-project", name: "", url: "https://example.com", summary: "", tags: [])
    ]
    profile.education = [
      ProfileEducation(id: "blank-education", school: "", credential: "", period: "", notes: "")
    ]

    XCTAssertEqual(ProfileStorySupport.narrativeExperience(in: profile).map(\.id), ["role-with-hidden-child"])
    XCTAssertTrue(ProfileStorySupport.narrativeExperienceProjects(in: profile.experience![0]).isEmpty)
    XCTAssertTrue(ProfileStorySupport.narrativeProjects(in: profile).isEmpty)
    XCTAssertTrue(ProfileStorySupport.narrativeEducation(in: profile).isEmpty)
    XCTAssertTrue(ProfileStorySupport.hasStoryFacts(profile))
    XCTAssertFalse(ProfileStorySupport.storyFactsContext(for: profile).contains("private/profile"))
  }

  func testAboutOnlyProfileCannotGroundAnAIDraftFromItself() {
    var profile = JobmaxxingStore.defaultState.profile
    profile.about = "I claim an outcome that has no supporting profile facts yet."

    XCTAssertTrue(ProfileStorySupport.hasStoryFacts(profile))
    XCTAssertFalse(ProfileStorySupport.hasStorySourceFacts(profile))
    XCTAssertEqual(ProfileStorySupport.storyFactsContext(for: profile), "No saved profile facts.")

    profile.skills = ["Workflow design"]
    profile.locations = ["Remote"]
    profile.workAuthorization = "Eligible to work locally."
    profile.personalMemory = [
      ProfileMemory(id: "title-only", kind: "Preference", title: "Direct work", detail: "", source: "User note", strength: 4)
    ]
    XCTAssertFalse(ProfileStorySupport.hasStorySourceFacts(profile))

    profile.evidence = [
      EvidenceItem(id: "grounded", title: "Outcome", proof: "Reduced a weekly review to one pass.", sourceURL: "", tags: [], strength: 5)
    ]
    XCTAssertTrue(ProfileStorySupport.hasStorySourceFacts(profile))
  }

  func testHeadlineIsVisibleButMetadataOnlyRowsCannotGroundAStory() {
    var profile = JobmaxxingStore.defaultState.profile
    profile.headline = "A concise professional introduction."
    profile.experience = [
      ProfileExperience(
        id: "metadata-role",
        title: "",
        organization: "",
        location: "Remote",
        period: "Two years",
        summary: "",
        bullets: [],
        sourceURL: ""
      )
    ]
    profile.profileProjects = [
      ProfileProject(id: "metadata-project", name: "", url: "", summary: "", tags: ["operations"])
    ]
    profile.education = [
      ProfileEducation(id: "metadata-education", school: "", credential: "", period: "Two years", notes: "")
    ]

    XCTAssertFalse(ProfileStorySupport.isEmpty(profile))
    XCTAssertFalse(ProfileStorySupport.hasStorySourceFacts(profile))
    XCTAssertTrue(ProfileStorySupport.narrativeExperience(in: profile).isEmpty)
    XCTAssertTrue(ProfileStorySupport.narrativeProjects(in: profile).isEmpty)
    XCTAssertTrue(ProfileStorySupport.narrativeEducation(in: profile).isEmpty)
  }

  func testSourcePresentationNeverPrintsLocalMetadata() {
    XCTAssertEqual(ProfileStorySupport.sourceLabel(for: "/private/source/contract.pdf"), "Saved source")
    XCTAssertEqual(ProfileStorySupport.sourceLabel(for: "https://www.example.org/work"), "example.org")
    XCTAssertNotNil(ProfileStorySupport.linkedInSource(from: "https://www.linkedin.com/in/candidate"))
    XCTAssertNil(ProfileStorySupport.linkedInSource(from: "https://example.org/in/candidate"))
    XCTAssertNil(ProfileStorySupport.linkedInSource(from: "https://www.linkedin.com/company/example"))
    XCTAssertNil(ProfileStorySupport.linkedInSource(from: "https://www.linkedin.com/jobs/view/example"))
  }
}
