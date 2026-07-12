import XCTest
@testable import Jobmaxxing

final class ProfileEditorSupportTests: XCTestCase {
  func testPreparedProfileKeepsEveryMeaningfulStructuredField() {
    var draft = JobmaxxingStore.defaultState.profile
    draft.about = "  I started close to operations.\n\nNow I build calm software.  "
    draft.experience = [
      ProfileExperience(
        id: "nested-project-role",
        title: "",
        organization: "",
        location: "",
        period: "",
        summary: "",
        bullets: [],
        sourceURL: "",
        projects: [
          ProfileExperienceProject(
            id: "sample-only",
            name: "",
            summary: "",
            detail: "",
            specificSample: "  Walked an operator through the final review.  ",
            tools: [],
            metrics: [],
            tags: [],
            sourceURL: ""
          ),
          ProfileExperienceProject(
            id: "details-only",
            name: "",
            summary: "",
            detail: "",
            specificSample: "",
            tools: [" Swift "],
            metrics: [" One review pass "],
            tags: [" workflow "],
            sourceURL: ""
          )
        ]
      ),
      ProfileExperience(
        id: "bullets-only-role",
        title: "",
        organization: "",
        location: "",
        period: "",
        summary: "",
        bullets: ["  Kept final approval with the user.  "],
        sourceURL: ""
      )
    ]
    draft.profileProjects = [
      ProfileProject(id: "url-only", name: "", url: "https://example.com/work", summary: "", tags: [])
    ]
    draft.education = [
      ProfileEducation(id: "notes-only", school: "", credential: "", period: "", notes: "  Coursework in systems design.  ")
    ]
    draft.evidence = [
      EvidenceItem(id: "source-only", title: "", proof: "", sourceURL: "file:///private/proof.pdf", tags: [], strength: 3)
    ]

    let prepared = ProfileEditorSupport.preparedForSave(draft)

    XCTAssertEqual(prepared.about, "I started close to operations.\n\nNow I build calm software.")
    XCTAssertEqual(prepared.experience?.count, 2)
    XCTAssertEqual(prepared.experience?.first?.projects?.count, 2)
    XCTAssertEqual(prepared.experience?.first?.projects?.first?.specificSample, "Walked an operator through the final review.")
    XCTAssertEqual(prepared.experience?.first?.projects?[1].tools, ["Swift"])
    XCTAssertEqual(prepared.experience?.first?.projects?[1].metrics, ["One review pass"])
    XCTAssertEqual(prepared.experience?.first?.projects?[1].tags, ["workflow"])
    XCTAssertEqual(prepared.experience?[1].bullets, ["Kept final approval with the user."])
    XCTAssertEqual(prepared.profileProjects?.first?.url, "https://example.com/work")
    XCTAssertEqual(prepared.education?.first?.notes, "Coursework in systems design.")
    XCTAssertEqual(prepared.evidence.first?.sourceURL, "file:///private/proof.pdf")
  }

  func testPreparedProfileRemovesOnlyCompletelyEmptyRows() {
    var draft = JobmaxxingStore.defaultState.profile
    draft.experience = [
      ProfileExperience(
        id: "empty-role",
        title: "  ",
        organization: "",
        location: "",
        period: "",
        summary: "",
        bullets: ["  "],
        sourceURL: "",
        projects: []
      )
    ]
    draft.profileProjects = [ProfileProject(id: "empty-project", name: "", url: "", summary: "", tags: [])]
    draft.education = [ProfileEducation(id: "empty-education", school: "", credential: "", period: "", notes: "")]
    draft.evidence = [EvidenceItem(id: "empty-evidence", title: "", proof: "", sourceURL: "", tags: [], strength: 1)]

    let prepared = ProfileEditorSupport.preparedForSave(draft)

    XCTAssertEqual(prepared.experience, [])
    XCTAssertEqual(prepared.profileProjects, [])
    XCTAssertEqual(prepared.education, [])
    XCTAssertTrue(prepared.evidence.isEmpty)
  }

  func testWebLinkValidationIsScopedAndKeepsMalformedEditsVisible() {
    var original = JobmaxxingStore.defaultState.profile
    original.profileProjects = [
      ProfileProject(id: "project", name: "Project", url: "", summary: "Summary", tags: [])
    ]
    var edited = original
    edited.profileProjects?[0].url = "https://"

    XCTAssertNotNil(ProfileEditorSupport.validationMessage(original: original, edited: edited, scope: .selectedProject("project")))
    XCTAssertNil(ProfileEditorSupport.validationMessage(original: original, edited: edited, scope: .identity))

    edited.profileProjects?[0].url = "https://example.com/work"
    XCTAssertNil(ProfileEditorSupport.validationMessage(original: original, edited: edited, scope: .selectedProject("project")))

    edited.linkedInURL = "https://www.linkedin.com/company/example"
    XCTAssertNotNil(ProfileEditorSupport.validationMessage(original: original, edited: edited, scope: .sources))
  }
}
