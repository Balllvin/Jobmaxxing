import SwiftUI

struct ProfileEditorView: View {
  @State private var draft: CandidateProfile
  @State private var saveError = ""
  private let originalProfile: CandidateProfile
  let scope: ProfileEditorScope
  let onCancel: () -> Void
  let onSave: (CandidateProfile) -> Bool

  init(
    profile: CandidateProfile,
    scope: ProfileEditorScope = .all,
    onCancel: @escaping () -> Void,
    onSave: @escaping (CandidateProfile) -> Bool
  ) {
    var editableProfile = profile
    editableProfile.experience = (profile.experience ?? []).map { item in
      var editableItem = item
      editableItem.projects = item.projects ?? []
      return editableItem
    }
    editableProfile.education = profile.education ?? []
    editableProfile.skills = profile.skills ?? []
    editableProfile.certifications = profile.certifications ?? []
    editableProfile.profileProjects = profile.profileProjects ?? []
    editableProfile.personalMemory = profile.personalMemory ?? []
    _draft = State(initialValue: editableProfile)
    originalProfile = profile
    self.scope = scope
    self.onCancel = onCancel
    self.onSave = onSave
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(scope.title)
            .font(scope.isFullProfile ? .title2.weight(.semibold) : .headline)
          if scope.isFullProfile {
            Text("Keep the facts true to your work. You can draft the introduction from them after you save.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Spacer(minLength: 12)
        Button("Cancel", action: onCancel)
          .keyboardShortcut(.cancelAction)
        Button("Save") {
          let profileToSave = scope.isFullProfile
            ? ProfileEditorSupport.preparedForSave(draft)
            : draft
          if let message = ProfileEditorSupport.validationMessage(
            original: originalProfile,
            edited: profileToSave,
            scope: scope
          ) {
            saveError = message
            return
          }
          if !onSave(profileToSave) {
            saveError = "Could not save these changes. Your edits are still here."
          }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.return, modifiers: .command)
      }
      .padding(scope.isFullProfile ? 20 : 16)

      if !saveError.isEmpty {
        Text(saveError)
          .font(.caption)
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, scope.isFullProfile ? 20 : 16)
          .padding(.bottom, 10)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: scope.isFullProfile ? 28 : 14) {
          editorContent
        }
        .padding(scope.isFullProfile ? 24 : 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .background(AppBackdrop())
  }

  @ViewBuilder
  private var editorContent: some View {
    switch scope {
    case .all:
      identitySection
      directionSection
      experienceSection
      projectSection
      examplesSection
      educationSection
      workingStyleSection
      personalContextSection
      sourceSection
    case .identity:
      identityFields
    case .story:
      storyField
    case .experience(let id):
      if let item = (draft.experience ?? []).first(where: { $0.id == id }) {
        ProfileExperienceEditor(item: experienceBinding(for: item))
      }
    case .selectedProject(let id):
      if let project = (draft.profileProjects ?? []).first(where: { $0.id == id }) {
        ProfileProjectEditor(project: projectBinding(for: project))
      }
    case .evidence(let id):
      if let item = draft.evidence.first(where: { $0.id == id }) {
        ProfileExampleEditor(item: evidenceBinding(for: item))
      }
    case .education(let id):
      if let item = (draft.education ?? []).first(where: { $0.id == id }) {
        ProfileEducationEditor(item: educationBinding(for: item))
      }
    case .certifications:
      certificationsField
    case .direction:
      directionFields
    case .workingStyle:
      workingStyleFields
      Divider()
      personalContextFields
    case .sources:
      sourceFields
    }
  }

  private var identitySection: some View {
    ProfileEditorSection(title: "Identity and story") {
      identityFields
      storyField
    }
  }

  @ViewBuilder
  private var identityFields: some View {
    ProfileEditorField(label: "Name") {
      TextField("Your name", text: $draft.name)
    }
    ProfileEditorField(label: "Short introduction") {
      TextField("What you do and the work that connects it", text: optionalBinding(\.headline), axis: .vertical)
        .lineLimit(2...4)
    }
  }

  private var storyField: some View {
    ProfileEditorField(label: "Your story", helper: "Paragraph breaks are kept when you save.") {
      TextField("A few sentences that connect your work", text: optionalBinding(\.about), axis: .vertical)
        .lineLimit(5...10)
    }
  }

  private var directionSection: some View {
    ProfileEditorSection(title: "What you want next") {
      directionFields
    }
  }

  @ViewBuilder
  private var directionFields: some View {
    ProfileEditorField(label: "Target roles", helper: "One role per line") {
      TextField("Role titles", text: listBinding(\.targetRoles), axis: .vertical)
        .lineLimit(2...5)
    }
    ProfileEditorField(label: "Locations", helper: "One place or remote preference per line") {
      TextField("Locations", text: listBinding(\.locations), axis: .vertical)
        .lineLimit(2...5)
    }
    ProfileEditorField(label: "Work authorization") {
      TextField("What an employer needs to know", text: $draft.workAuthorization, axis: .vertical)
        .lineLimit(2...4)
    }
    ProfileEditorField(label: "Compensation preference") {
      TextField("Optional practical guidance", text: $draft.compensationGoal, axis: .vertical)
        .lineLimit(2...4)
    }
  }

  private var experienceSection: some View {
    ProfileEditorSection(title: "Experience") {
      let experience = draft.experience ?? []
      ForEach(experience) { item in
        DisclosureGroup(experienceTitle(item)) {
          ProfileExperienceEditor(item: experienceBinding(for: item))
          Button("Remove experience", role: .destructive) {
            draft.experience?.removeAll { $0.id == item.id }
          }
          .buttonStyle(.borderless)
        }
      }
      Button {
        var experience = draft.experience ?? []
        experience.append(ProfileExperience(
          id: UUID().uuidString,
          title: "",
          organization: "",
          location: "",
          period: "",
          summary: "",
          bullets: [],
          sourceURL: "",
          projects: []
        ))
        draft.experience = experience
      } label: {
        Label("Add experience", systemImage: "plus")
      }
    }
  }

  private var projectSection: some View {
    ProfileEditorSection(title: "Selected work") {
      let projects = draft.profileProjects ?? []
      ForEach(projects) { project in
        DisclosureGroup(project.name.trimmed.isEmpty ? "New project" : project.name) {
          ProfileProjectEditor(project: projectBinding(for: project))
          Button("Remove project", role: .destructive) {
            draft.profileProjects?.removeAll { $0.id == project.id }
          }
          .buttonStyle(.borderless)
        }
      }
      Button {
        var projects = draft.profileProjects ?? []
        projects.append(ProfileProject(id: UUID().uuidString, name: "", url: "", summary: "", tags: []))
        draft.profileProjects = projects
      } label: {
        Label("Add project", systemImage: "plus")
      }
    }
  }

  private var examplesSection: some View {
    ProfileEditorSection(title: "Examples and outcomes") {
      ForEach(draft.evidence) { item in
        DisclosureGroup(exampleTitle(item)) {
          ProfileExampleEditor(item: evidenceBinding(for: item))
          Button("Remove example", role: .destructive) {
            draft.evidence.removeAll { $0.id == item.id }
          }
          .buttonStyle(.borderless)
        }
      }
      Button {
        draft.evidence.append(EvidenceItem(
          id: UUID().uuidString,
          title: "",
          proof: "",
          sourceURL: "",
          tags: [],
          strength: 3
        ))
      } label: {
        Label("Add example", systemImage: "plus")
      }
    }
  }

  private var educationSection: some View {
    ProfileEditorSection(title: "Education and credentials") {
      let education = draft.education ?? []
      ForEach(education) { item in
        DisclosureGroup(educationTitle(item)) {
          ProfileEducationEditor(item: educationBinding(for: item))
          Button("Remove education", role: .destructive) {
            draft.education?.removeAll { $0.id == item.id }
          }
          .buttonStyle(.borderless)
        }
      }
      Button {
        var education = draft.education ?? []
        education.append(ProfileEducation(id: UUID().uuidString, school: "", credential: "", period: "", notes: ""))
        draft.education = education
      } label: {
        Label("Add education", systemImage: "plus")
      }
      certificationsField
    }
  }

  private var certificationsField: some View {
    ProfileEditorField(label: "Certifications", helper: "One credential per line") {
      TextField("Certifications", text: optionalListBinding(\.certifications), axis: .vertical)
        .lineLimit(2...5)
    }
  }

  private var workingStyleSection: some View {
    ProfileEditorSection(title: "Skills and how you work") {
      workingStyleFields
    }
  }

  @ViewBuilder
  private var workingStyleFields: some View {
    ProfileEditorField(label: "Skills", helper: "One skill per line") {
      TextField("Skills", text: optionalListBinding(\.skills), axis: .vertical)
        .lineLimit(3...7)
    }
    ProfileEditorField(label: "Writing and working preferences", helper: "One preference per line") {
      TextField("What good work sounds and feels like to you", text: listBinding(\.writingPreferences), axis: .vertical)
        .lineLimit(3...7)
    }
  }

  private var personalContextSection: some View {
    ProfileEditorSection(title: "Personal context") {
      personalContextFields
    }
  }

  @ViewBuilder
  private var personalContextFields: some View {
    let notes = draft.personalMemory ?? []
    ForEach(notes) { note in
      DisclosureGroup(note.title.trimmed.isEmpty ? "New note" : note.title) {
        ProfileContextEditor(item: contextBinding(for: note))
        Button("Remove note", role: .destructive) {
          draft.personalMemory?.removeAll { $0.id == note.id }
        }
        .buttonStyle(.borderless)
      }
    }
    Button {
      var notes = draft.personalMemory ?? []
      notes.append(ProfileMemory(
        id: UUID().uuidString,
        kind: "Preference",
        title: "",
        detail: "",
        source: "User note",
        strength: 5
      ))
      draft.personalMemory = notes
    } label: {
      Label("Add context", systemImage: "plus")
    }
  }

  private var sourceSection: some View {
    ProfileEditorSection(title: "Sources") {
      sourceFields
    }
  }

  @ViewBuilder
  private var sourceFields: some View {
    ProfileEditorField(label: "LinkedIn profile") {
      TextField("https://www.linkedin.com/in/your-profile", text: optionalBinding(\.linkedInURL))
    }
    Text("Other saved sources stay attached to their facts but are not shown as profile prose.")
      .font(.caption)
      .foregroundStyle(.secondary)
  }

  private func optionalBinding(_ keyPath: WritableKeyPath<CandidateProfile, String?>) -> Binding<String> {
    Binding(
      get: { draft[keyPath: keyPath] ?? "" },
      set: { draft[keyPath: keyPath] = $0 }
    )
  }

  private func listBinding(_ keyPath: WritableKeyPath<CandidateProfile, [String]>) -> Binding<String> {
    Binding(
      get: { draft[keyPath: keyPath].joined(separator: "\n") },
      set: { draft[keyPath: keyPath] = TextImproveSupport.editableLines(from: $0) }
    )
  }

  private func optionalListBinding(_ keyPath: WritableKeyPath<CandidateProfile, [String]?>) -> Binding<String> {
    Binding(
      get: { (draft[keyPath: keyPath] ?? []).joined(separator: "\n") },
      set: { draft[keyPath: keyPath] = TextImproveSupport.editableLines(from: $0) }
    )
  }

  private func experienceBinding(for item: ProfileExperience) -> Binding<ProfileExperience> {
    Binding(
      get: { draft.experience?.first(where: { $0.id == item.id }) ?? item },
      set: { value in
        guard let index = draft.experience?.firstIndex(where: { $0.id == item.id }) else { return }
        draft.experience?[index] = value
      }
    )
  }

  private func projectBinding(for project: ProfileProject) -> Binding<ProfileProject> {
    Binding(
      get: { draft.profileProjects?.first(where: { $0.id == project.id }) ?? project },
      set: { value in
        guard let index = draft.profileProjects?.firstIndex(where: { $0.id == project.id }) else { return }
        draft.profileProjects?[index] = value
      }
    )
  }

  private func evidenceBinding(for item: EvidenceItem) -> Binding<EvidenceItem> {
    Binding(
      get: { draft.evidence.first(where: { $0.id == item.id }) ?? item },
      set: { value in
        guard let index = draft.evidence.firstIndex(where: { $0.id == item.id }) else { return }
        draft.evidence[index] = value
      }
    )
  }

  private func educationBinding(for item: ProfileEducation) -> Binding<ProfileEducation> {
    Binding(
      get: { draft.education?.first(where: { $0.id == item.id }) ?? item },
      set: { value in
        guard let index = draft.education?.firstIndex(where: { $0.id == item.id }) else { return }
        draft.education?[index] = value
      }
    )
  }

  private func contextBinding(for note: ProfileMemory) -> Binding<ProfileMemory> {
    Binding(
      get: { draft.personalMemory?.first(where: { $0.id == note.id }) ?? note },
      set: { value in
        guard let index = draft.personalMemory?.firstIndex(where: { $0.id == note.id }) else { return }
        draft.personalMemory?[index] = value
      }
    )
  }

  private func experienceTitle(_ item: ProfileExperience) -> String {
    [item.title, item.organization].map(\.trimmed).filter { !$0.isEmpty }.joined(separator: " at ").nonEmpty ?? "New experience"
  }

  private func exampleTitle(_ item: EvidenceItem) -> String {
    let text = ProfileStorySupport.evidenceText(item)
    return text.isEmpty ? "New example" : String(text.prefix(72))
  }

  private func educationTitle(_ item: ProfileEducation) -> String {
    [item.credential, item.school].map(\.trimmed).first(where: { !$0.isEmpty }) ?? "New education"
  }
}

private struct ProfileEditorSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title)
        .font(.title3.weight(.semibold))
      content
    }
    .padding(.bottom, 24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

private struct ProfileEditorField<Content: View>: View {
  let label: String
  var helper: String = ""
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      content
        .textFieldStyle(.roundedBorder)
      if !helper.isEmpty {
        Text(helper)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ProfileWebSourceEditor: View {
  @Binding var value: String
  @State private var hiddenInitialValue: String?
  @State private var replacementValue = ""
  let label: String

  init(label: String, value: Binding<String>) {
    self.label = label
    _value = value
    let initialValue = value.wrappedValue
    _hiddenInitialValue = State(initialValue: !initialValue.trimmed.isEmpty && ProfileStorySupport.webSource(from: initialValue) == nil ? initialValue : nil)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ProfileEditorField(label: hiddenInitialValue == nil ? label : "Replace web link") {
        TextField("https://", text: editableValue)
      }
      let visibleValue = hiddenInitialValue == nil ? value : replacementValue
      if !visibleValue.trimmed.isEmpty, ProfileStorySupport.webSource(from: visibleValue) == nil {
        Text("Use a full http or https link.")
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }

  private var editableValue: Binding<String> {
    Binding(
      get: { hiddenInitialValue == nil ? value : replacementValue },
      set: { nextValue in
        guard let hiddenInitialValue else {
          value = nextValue
          return
        }
        replacementValue = nextValue
        value = nextValue.trimmed.isEmpty ? hiddenInitialValue : nextValue
      }
    )
  }
}

private struct ProfileExperienceEditor: View {
  @Binding var item: ProfileExperience

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ProfileEditorField(label: "Role") { TextField("Role title", text: $item.title) }
      ProfileEditorField(label: "Organization") { TextField("Organization", text: $item.organization) }
      ProfileEditorField(label: "Location") { TextField("Location", text: $item.location) }
      ProfileEditorField(label: "Period") { TextField("Period", text: $item.period) }
      ProfileEditorField(label: "Role overview") {
        TextField("What this work involved", text: $item.summary, axis: .vertical).lineLimit(2...5)
      }
      ProfileEditorField(label: "Concrete work", helper: "One item per line; commas stay inside the sentence") {
        TextField("What you did or changed", text: bulletsBinding, axis: .vertical).lineLimit(3...8)
      }
      let projects = item.projects ?? []
      ForEach(projects) { project in
        DisclosureGroup(project.name.trimmed.isEmpty ? "New role project" : project.name) {
          ProfileExperienceProjectEditor(project: projectBinding(for: project))
          Button("Remove role project", role: .destructive) {
            item.projects?.removeAll { $0.id == project.id }
          }
          .buttonStyle(.borderless)
        }
      }
      Button {
        var projects = item.projects ?? []
        projects.append(ProfileExperienceProject(
          id: UUID().uuidString,
          name: "",
          summary: "",
          detail: "",
          specificSample: "",
          tools: [],
          metrics: [],
          tags: [],
          sourceURL: ""
        ))
        item.projects = projects
      } label: {
        Label("Add project under this role", systemImage: "plus")
      }
      ProfileWebSourceEditor(label: "Source link", value: $item.sourceURL)
    }
    .padding(.vertical, 8)
  }

  private var bulletsBinding: Binding<String> {
    Binding(
      get: { item.bullets.joined(separator: "\n") },
      set: { item.bullets = TextImproveSupport.editableLines(from: $0) }
    )
  }

  private func projectBinding(for project: ProfileExperienceProject) -> Binding<ProfileExperienceProject> {
    Binding(
      get: { item.projects?.first(where: { $0.id == project.id }) ?? project },
      set: { value in
        guard let index = item.projects?.firstIndex(where: { $0.id == project.id }) else { return }
        item.projects?[index] = value
      }
    )
  }
}

private struct ProfileExperienceProjectEditor: View {
  @Binding var project: ProfileExperienceProject

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ProfileEditorField(label: "Project name") { TextField("Project", text: $project.name) }
      ProfileEditorField(label: "Short summary") {
        TextField("The broad result", text: $project.summary, axis: .vertical).lineLimit(2...4)
      }
      ProfileEditorField(label: "Full explanation") {
        TextField("How the work happened", text: $project.detail, axis: .vertical).lineLimit(3...7)
      }
      ProfileEditorField(label: "One concrete example") {
        TextField("A specific walkthrough", text: $project.specificSample, axis: .vertical).lineLimit(3...6)
      }
      ProfileEditorField(label: "Tools", helper: "One per line") {
        TextField("Tools", text: listBinding(\.tools), axis: .vertical).lineLimit(2...5)
      }
      ProfileEditorField(label: "Outcomes", helper: "One per line") {
        TextField("Outcomes or measures", text: listBinding(\.metrics), axis: .vertical).lineLimit(2...5)
      }
      ProfileEditorField(label: "Themes", helper: "One per line") {
        TextField("Themes", text: listBinding(\.tags), axis: .vertical).lineLimit(2...5)
      }
      ProfileWebSourceEditor(label: "Source link", value: $project.sourceURL)
    }
    .padding(.vertical, 8)
  }

  private func listBinding(_ keyPath: WritableKeyPath<ProfileExperienceProject, [String]>) -> Binding<String> {
    Binding(
      get: { project[keyPath: keyPath].joined(separator: "\n") },
      set: { project[keyPath: keyPath] = TextImproveSupport.editableLines(from: $0) }
    )
  }
}

private struct ProfileProjectEditor: View {
  @Binding var project: ProfileProject

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ProfileEditorField(label: "Project name") { TextField("Project", text: $project.name) }
      ProfileEditorField(label: "Summary") {
        TextField("What it is and why it matters", text: $project.summary, axis: .vertical).lineLimit(2...5)
      }
      ProfileWebSourceEditor(label: "Web link", value: $project.url)
      ProfileEditorField(label: "Themes", helper: "One per line") {
        TextField("Themes", text: tagsBinding, axis: .vertical).lineLimit(2...5)
      }
    }
    .padding(.vertical, 8)
  }

  private var tagsBinding: Binding<String> {
    Binding(
      get: { project.tags.joined(separator: "\n") },
      set: { project.tags = TextImproveSupport.editableLines(from: $0) }
    )
  }
}

private struct ProfileExampleEditor: View {
  @Binding var item: EvidenceItem

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ProfileEditorField(label: "Short label") { TextField("What this example is", text: $item.title) }
      ProfileEditorField(label: "What happened") {
        TextField("The concrete work or outcome", text: $item.proof, axis: .vertical).lineLimit(3...7)
      }
      ProfileEditorField(label: "Themes", helper: "One per line") {
        TextField("Themes", text: tagsBinding, axis: .vertical).lineLimit(2...5)
      }
      ProfileWebSourceEditor(label: "Source link", value: $item.sourceURL)
      Text("Any attached source stays saved without becoming profile prose.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 8)
  }

  private var tagsBinding: Binding<String> {
    Binding(
      get: { item.tags.joined(separator: "\n") },
      set: { item.tags = TextImproveSupport.editableLines(from: $0) }
    )
  }
}

private struct ProfileEducationEditor: View {
  @Binding var item: ProfileEducation

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ProfileEditorField(label: "School") { TextField("School", text: $item.school) }
      ProfileEditorField(label: "Credential") { TextField("Degree or credential", text: $item.credential) }
      ProfileEditorField(label: "Period") { TextField("Period", text: $item.period) }
      ProfileEditorField(label: "Notes") {
        TextField("Relevant context", text: $item.notes, axis: .vertical).lineLimit(2...5)
      }
    }
    .padding(.vertical, 8)
  }
}

private struct ProfileContextEditor: View {
  @Binding var item: ProfileMemory

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ProfileEditorField(label: "Title") { TextField("Short title", text: $item.title) }
      ProfileEditorField(label: "Context") {
        TextField("A preference, constraint, or fact worth remembering", text: $item.detail, axis: .vertical)
          .lineLimit(3...7)
      }
    }
    .padding(.vertical, 8)
  }
}

private extension String {
  var nonEmpty: String? {
    let value = trimmed
    return value.isEmpty ? nil : value
  }
}
