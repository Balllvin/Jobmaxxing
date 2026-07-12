import Foundation

enum ProfileEditorSupport {
  static func validationMessage(
    original: CandidateProfile,
    edited: CandidateProfile,
    scope: ProfileEditorScope
  ) -> String? {
    let validatesAll = scope.isFullProfile
    if validatesAll || scope == .sources {
      let linkedIn = edited.linkedInURL?.trimmed ?? ""
      if !linkedIn.isEmpty, ProfileStorySupport.linkedInSource(from: linkedIn) == nil {
        return "Use a full LinkedIn profile URL before saving."
      }
    }

    if validatesAll {
      for item in edited.experience ?? [] {
        if let message = experienceSourceValidation(original: original, edited: item) { return message }
      }
      for item in edited.profileProjects ?? [] {
        if changedWebSourceIsInvalid(original.profileProjects?.first(where: { $0.id == item.id })?.url ?? "", item.url) {
          return "Use a full http or https link for selected work before saving."
        }
      }
      for item in edited.evidence {
        if changedWebSourceIsInvalid(original.evidence.first(where: { $0.id == item.id })?.sourceURL ?? "", item.sourceURL) {
          return "Use a full http or https link for the example before saving."
        }
      }
    } else {
      switch scope {
      case .experience(let id):
        if let item = edited.experience?.first(where: { $0.id == id }),
           let message = experienceSourceValidation(original: original, edited: item) {
          return message
        }
      case .selectedProject(let id):
        if let item = edited.profileProjects?.first(where: { $0.id == id }),
           changedWebSourceIsInvalid(original.profileProjects?.first(where: { $0.id == id })?.url ?? "", item.url) {
          return "Use a full http or https link for selected work before saving."
        }
      case .evidence(let id):
        if let item = edited.evidence.first(where: { $0.id == id }),
           changedWebSourceIsInvalid(original.evidence.first(where: { $0.id == id })?.sourceURL ?? "", item.sourceURL) {
          return "Use a full http or https link for the example before saving."
        }
      default:
        break
      }
    }
    return nil
  }

  static func preparedForSave(_ draft: CandidateProfile) -> CandidateProfile {
    var profile = draft
    profile.name = profile.name.trimmed
    profile.headline = optional(profile.headline)
    profile.linkedInURL = optional(profile.linkedInURL)
    profile.about = optional(profile.about)
    profile.targetRoles = clean(profile.targetRoles)
    profile.locations = clean(profile.locations)
    profile.workAuthorization = profile.workAuthorization.trimmed
    profile.compensationGoal = profile.compensationGoal.trimmed
    profile.writingPreferences = clean(profile.writingPreferences)
    profile.experience = profile.experience.map { items in
      items.map(cleanExperience).filter(hasContent)
    }
    profile.evidence = profile.evidence.map(cleanEvidence).filter(hasContent)
    profile.profileProjects = profile.profileProjects.map { projects in
      projects.map(cleanProject).filter(hasContent)
    }
    profile.education = profile.education.map { items in
      items.map(cleanEducation).filter(hasContent)
    }
    profile.skills = profile.skills.map(clean)
    profile.certifications = profile.certifications.map(clean)
    profile.personalMemory = profile.personalMemory.map { notes in
      notes.map(cleanMemory).filter(hasContent)
    }
    return profile
  }

  private static func cleanExperience(_ item: ProfileExperience) -> ProfileExperience {
    var next = item
    next.title = item.title.trimmed
    next.organization = item.organization.trimmed
    next.location = item.location.trimmed
    next.period = item.period.trimmed
    next.summary = item.summary.trimmed
    next.bullets = clean(item.bullets)
    next.sourceURL = cleanSource(item.sourceURL)
    next.projects = item.projects.map { projects in
      projects.map(cleanExperienceProject).filter(hasContent)
    }
    return next
  }

  private static func cleanExperienceProject(_ project: ProfileExperienceProject) -> ProfileExperienceProject {
    var next = project
    next.name = project.name.trimmed
    next.summary = project.summary.trimmed
    next.detail = project.detail.trimmed
    next.specificSample = project.specificSample.trimmed
    next.tools = clean(project.tools)
    next.metrics = clean(project.metrics)
    next.tags = clean(project.tags)
    next.sourceURL = cleanSource(project.sourceURL)
    return next
  }

  private static func cleanEvidence(_ item: EvidenceItem) -> EvidenceItem {
    var next = item
    next.title = item.title.trimmed
    next.proof = item.proof.trimmed
    next.tags = clean(item.tags)
    next.sourceURL = cleanSource(item.sourceURL)
    return next
  }

  private static func cleanProject(_ project: ProfileProject) -> ProfileProject {
    var next = project
    next.name = project.name.trimmed
    next.summary = project.summary.trimmed
    next.tags = clean(project.tags)
    next.url = cleanSource(project.url)
    return next
  }

  private static func cleanEducation(_ item: ProfileEducation) -> ProfileEducation {
    var next = item
    next.school = item.school.trimmed
    next.credential = item.credential.trimmed
    next.period = item.period.trimmed
    next.notes = item.notes.trimmed
    return next
  }

  private static func cleanMemory(_ note: ProfileMemory) -> ProfileMemory {
    var next = note
    next.kind = note.kind.trimmed.isEmpty ? "Preference" : note.kind.trimmed
    next.title = note.title.trimmed
    next.detail = note.detail.trimmed
    next.source = note.source.trimmed.isEmpty ? "User note" : note.source.trimmed
    return next
  }

  private static func hasContent(_ item: ProfileExperience) -> Bool {
    !item.title.isEmpty
      || !item.organization.isEmpty
      || !item.location.isEmpty
      || !item.period.isEmpty
      || !item.summary.isEmpty
      || !item.bullets.isEmpty
      || !(item.projects ?? []).isEmpty
      || !item.sourceURL.trimmed.isEmpty
  }

  private static func hasContent(_ project: ProfileExperienceProject) -> Bool {
    !project.name.isEmpty
      || !project.summary.isEmpty
      || !project.detail.isEmpty
      || !project.specificSample.isEmpty
      || !project.tools.isEmpty
      || !project.metrics.isEmpty
      || !project.tags.isEmpty
      || !project.sourceURL.trimmed.isEmpty
  }

  private static func hasContent(_ item: EvidenceItem) -> Bool {
    !item.title.isEmpty || !item.proof.isEmpty || !item.sourceURL.trimmed.isEmpty || !item.tags.isEmpty
  }

  private static func hasContent(_ project: ProfileProject) -> Bool {
    !project.name.isEmpty || !project.summary.isEmpty || !project.url.trimmed.isEmpty || !project.tags.isEmpty
  }

  private static func hasContent(_ item: ProfileEducation) -> Bool {
    !item.school.isEmpty || !item.credential.isEmpty || !item.period.isEmpty || !item.notes.isEmpty
  }

  private static func hasContent(_ note: ProfileMemory) -> Bool {
    !note.title.isEmpty || !note.detail.isEmpty
  }

  private static func optional(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmed
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func clean(_ values: [String]) -> [String] {
    TextImproveSupport.bullets(from: values.joined(separator: "\n"))
  }

  private static func cleanSource(_ value: String) -> String {
    let trimmed = value.trimmed
    return ProfileStorySupport.webSource(from: trimmed) == nil ? value : trimmed
  }

  private static func experienceSourceValidation(
    original: CandidateProfile,
    edited: ProfileExperience
  ) -> String? {
    let originalItem = original.experience?.first(where: { $0.id == edited.id })
    if changedWebSourceIsInvalid(originalItem?.sourceURL ?? "", edited.sourceURL) {
      return "Use a full http or https link for the experience before saving."
    }
    for project in edited.projects ?? [] {
      let originalSource = originalItem?.projects?.first(where: { $0.id == project.id })?.sourceURL ?? ""
      if changedWebSourceIsInvalid(originalSource, project.sourceURL) {
        return "Use a full http or https link for work within this role before saving."
      }
    }
    return nil
  }

  private static func changedWebSourceIsInvalid(_ original: String, _ edited: String) -> Bool {
    let oldValue = original.trimmed
    let newValue = edited.trimmed
    return newValue != oldValue && !newValue.isEmpty && ProfileStorySupport.webSource(from: newValue) == nil
  }
}
