import Foundation

enum ProfileStorySupport {
  static let defaultRewriteFeedback = "Draft a clear introduction that sounds like me and connects the work I have saved."

  static func isStoryKind(_ kind: String) -> Bool {
    kind.trimmed.lowercased().contains("profile story")
  }

  static func displayName(for profile: CandidateProfile) -> String {
    let name = profile.name.trimmed
    return name.isEmpty ? "Your profile" : name
  }

  static func hasStoryFacts(_ profile: CandidateProfile) -> Bool {
    !(profile.headline ?? "").trimmed.isEmpty
      || !(profile.about ?? "").trimmed.isEmpty
      || hasStorySourceFacts(profile)
  }

  static func hasStorySourceFacts(_ profile: CandidateProfile) -> Bool {
    !narrativeExperience(in: profile).isEmpty
      || !narrativeEvidence(in: profile).isEmpty
      || !narrativeProjects(in: profile).isEmpty
      || !narrativeEducation(in: profile).isEmpty
  }

  static func isEmpty(_ profile: CandidateProfile) -> Bool {
    profile.name.trimmed.isEmpty
      && !hasStoryFacts(profile)
      && profile.targetRoles.isEmpty
      && profile.locations.isEmpty
      && (profile.skills ?? []).isEmpty
      && (profile.personalMemory ?? []).isEmpty
      && (profile.certifications ?? []).isEmpty
      && profile.writingPreferences.isEmpty
      && profile.workAuthorization.trimmed.isEmpty
      && profile.compensationGoal.trimmed.isEmpty
  }

  static func evidenceText(_ evidence: EvidenceItem) -> String {
    evidence.proof.trimmed
  }

  static func narrativeEvidence(in profile: CandidateProfile) -> [EvidenceItem] {
    profile.evidence.filter { !evidenceText($0).isEmpty }
  }

  static func narrativeExperience(in profile: CandidateProfile) -> [ProfileExperience] {
    (profile.experience ?? []).filter { item in
      ![item.title, item.organization, item.summary]
        .map(\.trimmed)
        .allSatisfy(\.isEmpty)
        || item.bullets.contains { !$0.trimmed.isEmpty }
        || !narrativeExperienceProjects(in: item).isEmpty
    }
  }

  static func narrativeExperienceProjects(in experience: ProfileExperience) -> [ProfileExperienceProject] {
    (experience.projects ?? []).filter { project in
      ![project.name, project.summary, project.detail, project.specificSample]
        .map(\.trimmed)
        .allSatisfy(\.isEmpty)
        || project.metrics.contains { !$0.trimmed.isEmpty }
    }
  }

  static func narrativeProjects(in profile: CandidateProfile) -> [ProfileProject] {
    (profile.profileProjects ?? []).filter { project in
      ![project.name, project.summary].map(\.trimmed).allSatisfy(\.isEmpty)
    }
  }

  static func narrativeEducation(in profile: CandidateProfile) -> [ProfileEducation] {
    (profile.education ?? []).filter { item in
      ![item.school, item.credential, item.notes].map(\.trimmed).allSatisfy(\.isEmpty)
    }
  }

  static func suggestions(for profile: CandidateProfile) -> [String] {
    var suggestions: [String] = []
    if profile.name.trimmed.isEmpty {
      suggestions.append("Add your name so this reads as your profile.")
    }
    if (profile.about ?? "").trimmed.isEmpty {
      suggestions.append("Write a short introduction that connects your work.")
    }
    if narrativeExperience(in: profile).isEmpty && narrativeProjects(in: profile).isEmpty {
      suggestions.append("Add the roles or projects that explain how your work developed.")
    }
    if narrativeEvidence(in: profile).isEmpty {
      suggestions.append("Add a few concrete outcomes or examples that support the story.")
    }
    if profile.targetRoles.isEmpty && profile.locations.isEmpty {
      suggestions.append("Add the work and locations you want next.")
    }
    return Array(suggestions.prefix(3))
  }

  static func webSource(from rawValue: String) -> URL? {
    let value = rawValue.trimmed
    guard let url = URL(string: value),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          url.host != nil else {
      return nil
    }
    return url
  }

  static func sourceLabel(for rawValue: String) -> String {
    guard let url = webSource(from: rawValue) else { return "Saved source" }
    return url.host?.replacingOccurrences(of: "www.", with: "") ?? "Web source"
  }

  static func linkedInSource(from rawValue: String) -> URL? {
    guard let url = webSource(from: rawValue), let host = url.host?.lowercased() else { return nil }
    guard host == "linkedin.com" || host.hasSuffix(".linkedin.com") else { return nil }
    let path = url.path.split(separator: "/", omittingEmptySubsequences: true)
    guard path.count >= 2, path[0].lowercased() == "in", !path[1].isEmpty else { return nil }
    return url
  }

  static func context(for profile: CandidateProfile) -> String {
    context(for: profile, includesSavedStory: true)
  }

  static func storyFactsContext(for profile: CandidateProfile) -> String {
    context(for: profile, includesSavedStory: false)
  }

  private static func context(for profile: CandidateProfile, includesSavedStory: Bool) -> String {
    var sections: [String] = []
    let identity = [profile.name, profile.headline ?? ""] + (includesSavedStory ? [profile.about ?? ""] : [])
    append("Identity", values: identity, to: &sections)
    append("Target roles", values: profile.targetRoles, to: &sections)
    append("Locations", values: profile.locations, to: &sections)
    append("Work authorization", values: [profile.workAuthorization], to: &sections)
    append("Compensation preferences", values: [profile.compensationGoal], to: &sections)

    let experience = narrativeExperience(in: profile).map { item in
      var parts = [
        [item.title, item.organization, item.location, item.period]
          .map(\.trimmed)
          .filter { !$0.isEmpty }
          .joined(separator: " | "),
        item.summary.trimmed
      ]
      parts.append(contentsOf: item.bullets.map(\.trimmed))
      parts.append(contentsOf: narrativeExperienceProjects(in: item).flatMap { project in
        [
          project.name,
          project.summary,
          project.detail,
          project.specificSample,
          project.tools.isEmpty ? "" : "Tools: \(project.tools.compactJoined)",
          project.metrics.isEmpty ? "" : "Outcomes: \(project.metrics.compactJoined)",
          project.tags.isEmpty ? "" : "Themes: \(project.tags.compactJoined)"
        ]
          .map(\.trimmed)
          .filter { !$0.isEmpty }
      })
      return parts.filter { !$0.isEmpty }.joined(separator: " — ")
    }
    append("Experience", values: experience, to: &sections)

    let education = narrativeEducation(in: profile).map { item in
      [item.school, item.credential, item.period, item.notes]
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: " — ")
    }
    append("Education", values: education, to: &sections)
    append("Skills", values: profile.skills ?? [], to: &sections)
    append("Certifications", values: profile.certifications ?? [], to: &sections)

    let projects = narrativeProjects(in: profile).map { project in
      [project.name, project.summary, project.tags.compactJoined]
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: " — ")
    }
    append("Selected work", values: projects, to: &sections)
    append("Concrete examples", values: narrativeEvidence(in: profile).map(evidenceText), to: &sections)
    append("Writing and working preferences", values: profile.writingPreferences, to: &sections)
    append("Personal context", values: (profile.personalMemory ?? []).map(\.detail), to: &sections)

    return sections.isEmpty ? "No saved profile facts." : sections.joined(separator: "\n\n")
  }

  private static func append(_ title: String, values: [String], to sections: inout [String]) {
    let cleanValues = values.map(\.trimmed).filter { !$0.isEmpty }
    guard !cleanValues.isEmpty else { return }
    sections.append("\(title):\n" + cleanValues.map { "- \($0)" }.joined(separator: "\n"))
  }
}
