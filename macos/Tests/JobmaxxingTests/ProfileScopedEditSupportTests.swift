import XCTest
@testable import Jobmaxxing

final class ProfileScopedEditSupportTests: XCTestCase {
  func testIdentityAndStoryEditsPreserveUnrelatedRecords() throws {
    var latest = JobmaxxingStore.defaultState.profile
    latest.name = "Original name"
    latest.headline = "Original headline"
    latest.about = "Original story"
    latest.experience = [experience(id: "role", title: "Original role", source: "file:///fixture/role.txt")]
    latest.evidence = [
      EvidenceItem(
        id: "proof",
        title: "Original label",
        proof: "Original proof with  exact spacing.",
        sourceURL: "file:///fixture/proof.txt",
        tags: ["original"],
        strength: 4
      )
    ]

    var staleIdentityDraft = latest
    staleIdentityDraft.name = "  Updated name  "
    staleIdentityDraft.headline = "  Updated headline  "
    staleIdentityDraft.about = "Stale story"
    staleIdentityDraft.experience?[0].title = "Stale role"
    staleIdentityDraft.evidence[0].proof = "Stale proof"

    let identityResult = try XCTUnwrap(ProfileScopedEditSupport.merged(
      latest: latest,
      edited: staleIdentityDraft,
      scope: .identity
    ))

    XCTAssertEqual(identityResult.name, "Updated name")
    XCTAssertEqual(identityResult.headline, "Updated headline")
    XCTAssertEqual(identityResult.about, latest.about)
    XCTAssertEqual(identityResult.experience, latest.experience)
    XCTAssertEqual(identityResult.evidence, latest.evidence)

    var staleStoryDraft = staleIdentityDraft
    staleStoryDraft.about = "  First paragraph.\n\nSecond paragraph.  "
    let storyResult = try XCTUnwrap(ProfileScopedEditSupport.merged(
      latest: latest,
      edited: staleStoryDraft,
      scope: .story
    ))

    XCTAssertEqual(storyResult.about, "First paragraph.\n\nSecond paragraph.")
    XCTAssertEqual(storyResult.name, latest.name)
    XCTAssertEqual(storyResult.headline, latest.headline)
    XCTAssertEqual(storyResult.experience, latest.experience)
    XCTAssertEqual(storyResult.evidence, latest.evidence)
  }

  func testExperienceEditReplacesOnlyMatchingStableIDAndKeepsHiddenSources() throws {
    var latest = JobmaxxingStore.defaultState.profile
    latest.experience = [
      experience(id: "first", title: "First role", source: "file:///fixture/first.txt"),
      experience(
        id: "target",
        title: "Old role",
        source: "file:///fixture/target.txt",
        project: ProfileExperienceProject(
          id: "nested",
          name: "Old project",
          summary: "Old summary",
          detail: "Old detail",
          specificSample: "Old example",
          tools: [],
          metrics: [],
          tags: [],
          sourceURL: "file:///fixture/nested.txt"
        )
      )
    ]

    var edited = latest
    edited.experience?[0].title = "Stale first role"
    edited.experience?[1].title = "  Updated role  "
    edited.experience?[1].summary = "  Updated summary  "
    edited.experience?[1].sourceURL = "file:///different/local-source.txt"
    edited.experience?[1].projects?[0].name = "  Updated project  "
    edited.experience?[1].projects?[0].sourceURL = "file:///different/nested-source.txt"

    let result = try XCTUnwrap(ProfileScopedEditSupport.merged(
      latest: latest,
      edited: edited,
      scope: .experience("target")
    ))

    XCTAssertEqual(result.experience?[0], latest.experience?[0])
    XCTAssertEqual(result.experience?[1].title, "Updated role")
    XCTAssertEqual(result.experience?[1].summary, "Updated summary")
    XCTAssertEqual(result.experience?[1].sourceURL, "file:///fixture/target.txt")
    XCTAssertEqual(result.experience?[1].projects?.first?.name, "Updated project")
    XCTAssertEqual(result.experience?[1].projects?.first?.sourceURL, "file:///fixture/nested.txt")
  }

  func testWorkingStyleEditCleansVisibleMemoryAndPreservesHiddenMetadata() throws {
    var latest = JobmaxxingStore.defaultState.profile
    latest.skills = ["Old skill"]
    latest.writingPreferences = ["Old preference"]
    latest.personalMemory = [
      ProfileMemory(
        id: "memory",
        kind: "Private category",
        title: "Old title",
        detail: "Old detail",
        source: "file:///fixture/context.txt",
        strength: 4
      )
    ]
    latest.evidence = [
      EvidenceItem(id: "proof", title: "Proof", proof: "Keep me.", sourceURL: "", tags: [], strength: 3)
    ]

    var edited = latest
    edited.skills = ["  New skill  "]
    edited.writingPreferences = ["  New preference  "]
    edited.personalMemory?[0].title = "  New title  "
    edited.personalMemory?[0].detail = "  First line.\n\nSecond line.  "
    edited.personalMemory?[0].kind = "Changed hidden category"
    edited.personalMemory?[0].source = "Changed hidden source"
    edited.personalMemory?[0].strength = 1
    edited.evidence[0].proof = "Stale proof"

    let result = try XCTUnwrap(ProfileScopedEditSupport.merged(
      latest: latest,
      edited: edited,
      scope: .workingStyle
    ))
    let memory = try XCTUnwrap(result.personalMemory?.first)

    XCTAssertEqual(result.skills, ["New skill"])
    XCTAssertEqual(result.writingPreferences, ["New preference"])
    XCTAssertEqual(memory.title, "New title")
    XCTAssertEqual(memory.detail, "First line.\n\nSecond line.")
    XCTAssertEqual(memory.kind, "Private category")
    XCTAssertEqual(memory.source, "file:///fixture/context.txt")
    XCTAssertEqual(memory.strength, 4)
    XCTAssertEqual(result.evidence, latest.evidence)
  }

  func testEvidenceEditPreservesLatestHiddenStrengthAndLocalSource() throws {
    var latest = JobmaxxingStore.defaultState.profile
    latest.evidence = [
      EvidenceItem(
        id: "first",
        title: "First example",
        proof: "Keep this example unchanged.",
        sourceURL: "",
        tags: [],
        strength: 2
      ),
      EvidenceItem(
        id: "target",
        title: "Old label",
        proof: "Old proof.",
        sourceURL: "file:///fixture/proof.txt",
        tags: ["old"],
        strength: 5
      )
    ]

    var edited = latest
    edited.evidence[0].proof = "Stale first example."
    edited.evidence[1].title = "  Updated label  "
    edited.evidence[1].proof = "  Updated proof.  "
    edited.evidence[1].sourceURL = "file:///different/local-proof.txt"
    edited.evidence[1].strength = 1

    let result = try XCTUnwrap(ProfileScopedEditSupport.merged(
      latest: latest,
      edited: edited,
      scope: .evidence("target")
    ))

    XCTAssertEqual(result.evidence[0], latest.evidence[0])
    XCTAssertEqual(result.evidence[1].title, "Updated label")
    XCTAssertEqual(result.evidence[1].proof, "Updated proof.")
    XCTAssertEqual(result.evidence[1].sourceURL, "file:///fixture/proof.txt")
    XCTAssertEqual(result.evidence[1].strength, 5)

    edited.evidence[1].sourceURL = "https://example.com/public-proof"
    let replacedSource = try XCTUnwrap(ProfileScopedEditSupport.merged(
      latest: latest,
      edited: edited,
      scope: .evidence("target")
    ))
    XCTAssertEqual(replacedSource.evidence[1].sourceURL, "https://example.com/public-proof")
    XCTAssertEqual(replacedSource.evidence[1].strength, 5)
  }

  func testRemainingScopesUpdateOnlyTheirOwnedFields() throws {
    var latest = JobmaxxingStore.defaultState.profile
    latest.name = "Latest name"
    latest.profileProjects = [
      ProfileProject(id: "project", name: "Old project", url: "https://example.com/old", summary: "Old summary", tags: [])
    ]
    latest.education = [
      ProfileEducation(id: "education", school: "Old school", credential: "Old credential", period: "Old period", notes: "Old notes")
    ]
    latest.certifications = ["Old credential"]
    latest.targetRoles = ["Old role"]
    latest.locations = ["Old place"]
    latest.workAuthorization = "Old authorization"
    latest.compensationGoal = "Old preference"
    latest.linkedInURL = "https://www.linkedin.com/in/old-candidate"

    var edited = latest
    edited.name = "Stale name"
    edited.profileProjects?[0].name = "  Updated project  "
    edited.profileProjects?[0].url = "https://example.com/new"
    edited.education?[0].notes = "  Updated notes  "
    edited.certifications = ["  Updated credential  "]
    edited.targetRoles = ["  Updated role  "]
    edited.locations = ["  Updated place  "]
    edited.workAuthorization = "  Updated authorization  "
    edited.compensationGoal = "  Updated preference  "
    edited.linkedInURL = "  https://www.linkedin.com/in/new-candidate  "

    let project = try XCTUnwrap(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .selectedProject("project")))
    XCTAssertEqual(project.profileProjects?.first?.name, "Updated project")
    XCTAssertEqual(project.profileProjects?.first?.url, "https://example.com/new")
    XCTAssertEqual(project.name, latest.name)

    let education = try XCTUnwrap(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .education("education")))
    XCTAssertEqual(education.education?.first?.notes, "Updated notes")
    XCTAssertEqual(education.name, latest.name)

    let certifications = try XCTUnwrap(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .certifications))
    XCTAssertEqual(certifications.certifications, ["Updated credential"])
    XCTAssertEqual(certifications.name, latest.name)

    let direction = try XCTUnwrap(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .direction))
    XCTAssertEqual(direction.targetRoles, ["Updated role"])
    XCTAssertEqual(direction.locations, ["Updated place"])
    XCTAssertEqual(direction.workAuthorization, "Updated authorization")
    XCTAssertEqual(direction.compensationGoal, "Updated preference")
    XCTAssertEqual(direction.name, latest.name)

    let sources = try XCTUnwrap(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .sources))
    XCTAssertEqual(sources.linkedInURL, "https://www.linkedin.com/in/new-candidate")
    XCTAssertEqual(sources.name, latest.name)

    let all = try XCTUnwrap(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .all))
    XCTAssertEqual(all.name, "Stale name")
    XCTAssertEqual(all.profileProjects?.first?.name, "Updated project")

    XCTAssertNil(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .selectedProject("missing")))
    XCTAssertNil(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .education("missing")))
    XCTAssertNil(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .evidence("missing")))
    XCTAssertNil(ProfileScopedEditSupport.merged(latest: latest, edited: edited, scope: .experience("missing")))
  }

  private func experience(
    id: String,
    title: String,
    source: String,
    project: ProfileExperienceProject? = nil
  ) -> ProfileExperience {
    ProfileExperience(
      id: id,
      title: title,
      organization: "Organization",
      location: "Location",
      period: "Period",
      summary: "Summary",
      bullets: ["One result"],
      sourceURL: source,
      projects: project.map { [$0] } ?? []
    )
  }
}
