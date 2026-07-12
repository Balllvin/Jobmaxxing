import Foundation

enum ProfileEditorScope: Equatable {
  case all
  case identity
  case story
  case experience(String)
  case selectedProject(String)
  case evidence(String)
  case education(String)
  case certifications
  case direction
  case workingStyle
  case sources

  var title: String {
    switch self {
    case .all: "Edit profile"
    case .identity: "Edit identity"
    case .story: "Edit your story"
    case .experience: "Edit experience"
    case .selectedProject: "Edit selected work"
    case .evidence: "Edit example"
    case .education: "Edit education"
    case .certifications: "Edit credentials"
    case .direction: "Edit what you want next"
    case .workingStyle: "Edit skills and working style"
    case .sources: "Edit sources"
    }
  }

  var accessibilityName: String {
    switch self {
    case .all: "profile"
    case .identity: "identity"
    case .story: "profile story"
    case .experience: "experience"
    case .selectedProject: "selected work"
    case .evidence: "example and outcome"
    case .education: "education"
    case .certifications: "credentials"
    case .direction: "next role preferences"
    case .workingStyle: "skills and working style"
    case .sources: "profile sources"
    }
  }

  var isFullProfile: Bool { self == .all }
}

enum ProfileScopedEditSupport {
  static func merged(
    latest: CandidateProfile,
    edited: CandidateProfile,
    scope: ProfileEditorScope
  ) -> CandidateProfile? {
    let prepared = ProfileEditorSupport.preparedForSave(edited)
    guard !scope.isFullProfile else { return prepared }

    var result = latest
    switch scope {
    case .all:
      return prepared
    case .identity:
      result.name = prepared.name
      result.headline = prepared.headline
    case .story:
      result.about = prepared.about
    case .experience(let id):
      guard
        let editedItem = prepared.experience?.first(where: { $0.id == id }),
        let latestItem = latest.experience?.first(where: { $0.id == id }),
        var items = latest.experience,
        let index = items.firstIndex(where: { $0.id == id })
      else { return nil }
      items[index] = experience(editedItem, preservingHiddenSourcesFrom: latestItem)
      result.experience = items
    case .selectedProject(let id):
      guard
        var editedItem = prepared.profileProjects?.first(where: { $0.id == id }),
        let latestItem = latest.profileProjects?.first(where: { $0.id == id }),
        var items = latest.profileProjects,
        let index = items.firstIndex(where: { $0.id == id })
      else { return nil }
      editedItem.url = editableWebSource(editedItem.url, preservingHiddenValue: latestItem.url)
      items[index] = editedItem
      result.profileProjects = items
    case .evidence(let id):
      guard
        var editedItem = prepared.evidence.first(where: { $0.id == id }),
        let latestItem = latest.evidence.first(where: { $0.id == id }),
        let index = latest.evidence.firstIndex(where: { $0.id == id })
      else { return nil }
      editedItem.sourceURL = editableWebSource(editedItem.sourceURL, preservingHiddenValue: latestItem.sourceURL)
      editedItem.strength = latestItem.strength
      result.evidence[index] = editedItem
    case .education(let id):
      guard
        let editedItem = prepared.education?.first(where: { $0.id == id }),
        var items = latest.education,
        let index = items.firstIndex(where: { $0.id == id })
      else { return nil }
      items[index] = editedItem
      result.education = items
    case .certifications:
      result.certifications = prepared.certifications
    case .direction:
      result.targetRoles = prepared.targetRoles
      result.locations = prepared.locations
      result.workAuthorization = prepared.workAuthorization
      result.compensationGoal = prepared.compensationGoal
    case .workingStyle:
      result.skills = prepared.skills
      result.writingPreferences = prepared.writingPreferences
      result.personalMemory = prepared.personalMemory?.map { cleanedMemory in
        let hiddenMemory = latest.personalMemory?.first(where: { $0.id == cleanedMemory.id })
          ?? edited.personalMemory?.first(where: { $0.id == cleanedMemory.id })
        guard let hiddenMemory else { return cleanedMemory }
        var mergedMemory = cleanedMemory
        mergedMemory.kind = hiddenMemory.kind
        mergedMemory.source = hiddenMemory.source
        mergedMemory.strength = hiddenMemory.strength
        return mergedMemory
      }
    case .sources:
      result.linkedInURL = prepared.linkedInURL
    }
    return result
  }

  private static func experience(
    _ edited: ProfileExperience,
    preservingHiddenSourcesFrom latest: ProfileExperience
  ) -> ProfileExperience {
    var result = edited
    result.sourceURL = editableWebSource(edited.sourceURL, preservingHiddenValue: latest.sourceURL)
    result.projects = edited.projects?.map { editedProject in
      guard let latestProject = latest.projects?.first(where: { $0.id == editedProject.id }) else {
        return editedProject
      }
      var mergedProject = editedProject
      mergedProject.sourceURL = editableWebSource(
        editedProject.sourceURL,
        preservingHiddenValue: latestProject.sourceURL
      )
      return mergedProject
    }
    return result
  }

  private static func editableWebSource(_ edited: String, preservingHiddenValue latest: String) -> String {
    let latestIsVisible = latest.trimmed.isEmpty || ProfileStorySupport.webSource(from: latest) != nil
    if latestIsVisible { return edited }
    let replacement = edited.trimmed
    if replacement != latest.trimmed, ProfileStorySupport.webSource(from: replacement) != nil {
      return replacement
    }
    return latest
  }
}
