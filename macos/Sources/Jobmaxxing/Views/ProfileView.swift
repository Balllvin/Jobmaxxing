import SwiftUI

struct ProfileView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var showsEditor = false
  @State private var isShapingStory = false
  @State private var storyStatus = ""
  @State private var proposedStory = ""
  @State private var storyDraftFactsContext = ""
  @State private var storyTask: Task<Void, Never>?

  private var profile: CandidateProfile { store.state.profile }
  private var currentStoryFactsContext: String { ProfileStorySupport.storyFactsContext(for: profile) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ProfileIdentityHeader(
          profile: profile,
          onEdit: { showsEditor = true },
          onInlineSave: { saveInlineProfile($0, scope: .identity) }
        )

        if ProfileStorySupport.isEmpty(profile) {
          ProfileEmptyState(onStart: { showsEditor = true })
        } else {
          storySection
          experienceSection
          selectedWorkSection
          examplesSection
          educationSection
          directionSection
          workingStyleSection
          additionsSection
        }

        sourcesSection
      }
      .frame(maxWidth: 940, alignment: .leading)
      .padding(.horizontal, 36)
      .padding(.vertical, 32)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .navigationTitle("Profile")
    .onChange(of: currentStoryFactsContext) { _, newContext in
      guard (isShapingStory || !proposedStory.isEmpty),
            !storyDraftFactsContext.isEmpty,
            storyDraftFactsContext != newContext else { return }
      clearStaleStoryDraft()
      storyStatus = "Profile details changed. Draft a new introduction from the latest version."
    }
    .onDisappear {
      storyTask?.cancel()
      storyTask = nil
      isShapingStory = false
    }
    .sheet(isPresented: $showsEditor) {
      ProfileEditorView(
        profile: profile,
        onCancel: { showsEditor = false },
        onSave: { updatedProfile in
          guard saveInlineProfile(updatedProfile, scope: .all) else { return false }
          showsEditor = false
          return true
        }
      )
      .frame(minWidth: 620, idealWidth: 720, minHeight: 560, idealHeight: 680)
    }
  }

  private var storySection: some View {
    ProfileSection(title: "Your story", editButton: inlineEditButton(.story)) {
      let story = (profile.about ?? "").trimmed
      if story.isEmpty {
        Text(ProfileStorySupport.hasStorySourceFacts(profile)
          ? "Your profile has enough detail for a short introduction, or you can write one in your own words."
          : "Add a role, project, or concrete example before drafting your introduction.")
          .font(.title3)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        Text(story)
          .font(.system(size: 17, weight: .regular))
          .lineSpacing(6)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !proposedStory.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          Text("Draft story")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          TextField("Edit the draft before using it", text: $proposedStory, axis: .vertical)
            .lineLimit(5...12)
            .textFieldStyle(.roundedBorder)
          HStack(spacing: 8) {
            Button("Use this story") {
              saveProposedStory()
            }
            .buttonStyle(.borderedProminent)
            Button("Discard") {
              clearStaleStoryDraft()
            }
            .buttonStyle(.bordered)
          }
        }
        .padding(14)
        .liquidGlassSurface(.strong, cornerRadius: AppTheme.radiusSmall)
      }

      HStack(spacing: 8) {
        Button {
          shapeStory()
        } label: {
          if isShapingStory {
            ProgressView()
              .controlSize(.small)
              .accessibilityLabel("Drafting profile story")
          } else {
            Label(story.isEmpty ? "Draft from my profile" : "Draft a new version", systemImage: "text.quote")
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isShapingStory || !ProfileStorySupport.hasStorySourceFacts(profile))
        .help("Draft an introduction from the facts saved below")

        if ProfileStorySupport.hasStorySourceFacts(profile) {
          ImproveTextControl(
            currentText: story,
            context: currentStoryFactsContext,
            kind: "professional profile story",
            onApply: reviewImprovedStory
          )
        }

        Spacer(minLength: 0)
      }

      if !storyStatus.isEmpty {
        Text(storyStatus)
          .font(.caption)
          .foregroundStyle(storyStatus.hasPrefix("Could not") ? .red : .secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  @ViewBuilder
  private var experienceSection: some View {
    let experience = ProfileStorySupport.narrativeExperience(in: profile)
    if !experience.isEmpty {
      ProfileSection(title: "Experience") {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(experience.enumerated()), id: \.element.id) { index, item in
            ProfileExperienceView(item: item)
              .padding(.trailing, 36)
              .overlay(alignment: .topTrailing) {
                inlineEditButton(.experience(item.id))
              }
            if index < experience.count - 1 {
              Divider().padding(.vertical, 20)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var selectedWorkSection: some View {
    let projects = ProfileStorySupport.narrativeProjects(in: profile)
    if !projects.isEmpty {
      ProfileSection(title: "Selected work") {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
            ProfileProjectView(project: project)
              .padding(.trailing, 36)
              .overlay(alignment: .topTrailing) {
                inlineEditButton(.selectedProject(project.id))
              }
            if index < projects.count - 1 {
              Divider().padding(.vertical, 16)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var examplesSection: some View {
    let examples = ProfileStorySupport.narrativeEvidence(in: profile)
    if !examples.isEmpty {
      ProfileSection(title: "Examples and outcomes") {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(examples.enumerated()), id: \.element.id) { index, item in
            VStack(alignment: .leading, spacing: 8) {
              Text(ProfileStorySupport.evidenceText(item))
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
              if !item.tags.isEmpty {
                Text(item.tags.joined(separator: " · "))
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
              ProfileSourceLink(rawValue: item.sourceURL)
            }
            .padding(.trailing, 36)
            .overlay(alignment: .topTrailing) {
              inlineEditButton(.evidence(item.id))
            }
            if index < examples.count - 1 {
              Divider().padding(.vertical, 16)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var educationSection: some View {
    let education = ProfileStorySupport.narrativeEducation(in: profile)
    let certifications = profile.certifications ?? []
    if !education.isEmpty || !certifications.isEmpty {
      ProfileSection(title: "Education and credentials") {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(education) { item in
            VStack(alignment: .leading, spacing: 3) {
              let primary = item.credential.trimmed.isEmpty ? item.school.trimmed : item.credential.trimmed
              if !primary.isEmpty {
                Text(primary)
                  .font(.headline)
              }
              let secondary = (item.credential.trimmed.isEmpty ? [item.period] : [item.school, item.period])
                .map(\.trimmed)
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
              if !secondary.isEmpty {
                Text(secondary)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              if !item.notes.trimmed.isEmpty {
                Text(item.notes)
                  .font(.subheadline)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(.trailing, 36)
            .overlay(alignment: .topTrailing) {
              inlineEditButton(.education(item.id))
            }
          }
          if !certifications.isEmpty {
            HStack(alignment: .top, spacing: 10) {
              Text(certifications.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 0)
              inlineEditButton(.certifications)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var directionSection: some View {
    let hasDirection = !profile.targetRoles.isEmpty
      || !profile.locations.isEmpty
      || !profile.workAuthorization.trimmed.isEmpty
      || !profile.compensationGoal.trimmed.isEmpty
    if hasDirection {
      ProfileSection(title: "What you want next", editButton: inlineEditButton(.direction)) {
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 44) {
            directionContent
          }
          VStack(alignment: .leading, spacing: 20) {
            directionContent
          }
        }
      }
    }
  }

  @ViewBuilder
  private var directionContent: some View {
    if !profile.targetRoles.isEmpty {
      ProfileFactGroup(title: "Work", values: profile.targetRoles)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    if !profile.locations.isEmpty {
      ProfileFactGroup(title: "Place", values: profile.locations)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    let constraints = [profile.workAuthorization, profile.compensationGoal]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
    if !constraints.isEmpty {
      ProfileFactGroup(title: "Practical details", values: constraints)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var workingStyleSection: some View {
    let skills = profile.skills ?? []
    let memories = profile.personalMemory ?? []
    if !skills.isEmpty || !profile.writingPreferences.isEmpty || !memories.isEmpty {
      ProfileSection(title: "Skills and how you work", editButton: inlineEditButton(.workingStyle)) {
        if !skills.isEmpty {
          Text(skills.joined(separator: " · "))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !profile.writingPreferences.isEmpty {
          CompactList(items: profile.writingPreferences)
        }
        ForEach(memories) { memory in
          VStack(alignment: .leading, spacing: 4) {
            if !memory.title.trimmed.isEmpty {
              Text(memory.title)
                .font(.subheadline.weight(.semibold))
            }
            Text(memory.detail)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var additionsSection: some View {
    let suggestions = ProfileStorySupport.suggestions(for: profile)
    if !suggestions.isEmpty {
      ProfileSection(title: "Worth adding") {
        CompactList(items: suggestions)
      }
    }
  }

  private var sourcesSection: some View {
    ProfileSection(title: "Sources", editButton: inlineEditButton(.sources)) {
      let savedLinkedInURL = profile.linkedInURL ?? ""
      Text("Sources support the story. They do not define it, and nothing leaves this app from here.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      VStack(alignment: .leading, spacing: 8) {
        Text("LinkedIn profile")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        if let url = ProfileStorySupport.linkedInSource(from: savedLinkedInURL) {
          HStack(spacing: 10) {
            Link("Open LinkedIn profile", destination: url)
            Button {
              store.prepareLinkedInImport(sourceURL: savedLinkedInURL)
            } label: {
              Label("Review LinkedIn import", systemImage: "safari")
            }
            .buttonStyle(.bordered)
          }
        } else if savedLinkedInURL.trimmed.isEmpty {
          Text("No LinkedIn profile saved. Use the pencil to add one if it helps complete your profile.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else {
          Text("The saved LinkedIn link needs review. Use the pencil to correct it.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      if let savedSource = ProfileStorySupport.linkedInSource(from: savedLinkedInURL),
         let plan = profile.linkedInImportPlan,
         ProfileStorySupport.linkedInSource(from: plan.sourceURL) == savedSource {
        DisclosureGroup("What the LinkedIn review would do") {
          VStack(alignment: .leading, spacing: 10) {
            Text(plan.checkpoint)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Text("You approve anything before it is added. Jobmaxxing will not message people, edit LinkedIn, or submit an application.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 8)
        }
      }
    }
  }

  private func inlineEditButton(_ scope: ProfileEditorScope) -> ProfileInlineEditButton {
    ProfileInlineEditButton(
      profile: profile,
      scope: scope,
      onSave: { saveInlineProfile($0, scope: scope) }
    )
  }

  private func saveInlineProfile(
    _ editedProfile: CandidateProfile,
    scope: ProfileEditorScope
  ) -> Bool {
    guard let updatedProfile = ProfileScopedEditSupport.merged(
      latest: store.state.profile,
      edited: editedProfile,
      scope: scope
    ) else { return false }
    guard store.updateProfile(updatedProfile) else { return false }
    clearStaleStoryDraft()
    return true
  }

  private func clearStaleStoryDraft() {
    storyTask?.cancel()
    storyTask = nil
    isShapingStory = false
    proposedStory = ""
    storyDraftFactsContext = ""
    storyStatus = ""
  }

  private func saveProposedStory() {
    guard storyDraftFactsContext == currentStoryFactsContext else {
      clearStaleStoryDraft()
      storyStatus = "Profile details changed. Draft a new introduction from the latest version."
      return
    }
    saveStory(proposedStory)
  }

  private func reviewImprovedStory(_ story: String) {
    let reviewedStory = story.trimmed
    guard !reviewedStory.isEmpty else { return }
    proposedStory = reviewedStory
    storyDraftFactsContext = currentStoryFactsContext
    storyStatus = "Review this draft before replacing your saved story."
  }

  private func shapeStory() {
    guard ProfileStorySupport.hasStorySourceFacts(profile), !isShapingStory else { return }
    storyTask?.cancel()
    isShapingStory = true
    storyStatus = ""
    let currentProfile = profile
    let factsContext = ProfileStorySupport.storyFactsContext(for: currentProfile)
    storyDraftFactsContext = factsContext
    storyTask = Task {
      let result = await store.rewriteTextWithFeedback(
        currentText: currentProfile.about ?? "",
        feedback: ProfileStorySupport.defaultRewriteFeedback,
        context: "",
        kind: "professional profile story"
      )
      guard !Task.isCancelled else { return }
      await MainActor.run {
        guard factsContext == currentStoryFactsContext else {
          clearStaleStoryDraft()
          storyStatus = "Profile details changed. Draft a new introduction from the latest version."
          return
        }
        storyTask = nil
        isShapingStory = false
        if result.hasPrefix("ERROR:") {
          storyStatus = "Could not draft the introduction. \(String(result.dropFirst("ERROR:".count)).trimmed)"
          return
        }
        proposedStory = result.trimmed
        storyStatus = "Review this draft before replacing your saved story."
      }
    }
  }

  private func saveStory(_ story: String) {
    var updatedProfile = store.state.profile
    updatedProfile.about = story.trimmed.isEmpty ? nil : story.trimmed
    guard store.updateProfile(updatedProfile) else {
      storyStatus = "Could not save the story. Your reviewed draft is still here."
      return
    }
    clearStaleStoryDraft()
    storyStatus = "Story updated. Review it before using it in an application."
  }
}

private struct ProfileIdentityHeader: View {
  let profile: CandidateProfile
  let onEdit: () -> Void
  let onInlineSave: (CandidateProfile) -> Bool

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 36) {
        identity
        Spacer(minLength: 24)
        editControls
      }
      VStack(alignment: .leading, spacing: 18) {
        identity
        editControls
      }
    }
    .padding(.bottom, 28)
  }

  private var editControls: some View {
    HStack(spacing: 8) {
      ProfileInlineEditButton(
        profile: profile,
        scope: .identity,
        onSave: onInlineSave
      )
      Button("Edit profile", action: onEdit)
        .buttonStyle(.bordered)
    }
  }

  private var identity: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(ProfileStorySupport.displayName(for: profile))
        .font(.system(size: 34, weight: .semibold))
        .tracking(-0.8)
        .textSelection(.enabled)
      if let headline = profile.headline?.trimmed, !headline.isEmpty {
        Text(headline)
          .font(.title3)
          .foregroundStyle(.secondary)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      } else if profile.name.trimmed.isEmpty {
        Text("Tell the story of your work in your own words.")
          .font(.title3)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: 680, alignment: .leading)
  }
}

private struct ProfileEmptyState: View {
  let onStart: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Divider()
      Text("Start with the work you have done.")
        .font(.title2.weight(.semibold))
      Text("Add your name, the work you have done, and what you want next. Jobmaxxing will use only those facts when it helps with applications.")
        .font(.body)
        .foregroundStyle(.secondary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
      Button("Create your profile", action: onStart)
        .buttonStyle(.borderedProminent)
    }
    .padding(.vertical, 28)
  }
}

private struct ProfileSection<Content: View>: View {
  let title: String
  var editButton: ProfileInlineEditButton? = nil
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Divider()
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(title)
          .font(.title3.weight(.semibold))
        Spacer(minLength: 0)
        if let editButton {
          editButton
        }
      }
      content
    }
    .padding(.vertical, 26)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ProfileExperienceView: View {
  let item: ProfileExperience

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
          title
          Spacer(minLength: 12)
          period
        }
        VStack(alignment: .leading, spacing: 4) {
          title
          period
        }
      }
      if !item.summary.trimmed.isEmpty {
        Text(item.summary)
          .font(.body)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      if !item.bullets.isEmpty {
        CompactList(items: item.bullets)
      }
      ForEach(ProfileStorySupport.narrativeExperienceProjects(in: item)) { project in
        VStack(alignment: .leading, spacing: 6) {
          if !project.name.trimmed.isEmpty {
            Text(project.name)
              .font(.subheadline.weight(.semibold))
          }
          let narrative = [project.summary, project.detail, project.specificSample]
            .map(\.trimmed)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
          if !narrative.isEmpty {
            Text(narrative)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineSpacing(3)
              .fixedSize(horizontal: false, vertical: true)
          }
          if !project.metrics.isEmpty {
            Text(project.metrics.joined(separator: " · "))
              .font(.subheadline)
              .fixedSize(horizontal: false, vertical: true)
          }
          let context = project.tools + project.tags
          if !context.isEmpty {
            Text(context.joined(separator: " · "))
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          ProfileSourceLink(rawValue: project.sourceURL)
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
          Rectangle()
            .fill(AppTheme.border)
            .frame(width: 1)
        }
      }
      ProfileSourceLink(rawValue: item.sourceURL)
    }
  }

  private var title: some View {
    VStack(alignment: .leading, spacing: 3) {
      let primary = item.title.trimmed.isEmpty ? item.organization : item.title
      if !primary.trimmed.isEmpty {
        Text(primary)
          .font(.headline)
      }
      let secondary = (item.title.trimmed.isEmpty ? [item.location] : [item.organization, item.location])
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
      if !secondary.isEmpty {
        Text(secondary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var period: some View {
    if !item.period.trimmed.isEmpty {
      Text(item.period)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

private struct ProfileProjectView: View {
  let project: ProfileProject

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      if !project.name.trimmed.isEmpty {
        Text(project.name)
          .font(.headline)
      }
      if !project.summary.trimmed.isEmpty {
        Text(project.summary)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }
      if !project.tags.isEmpty {
        Text(project.tags.joined(separator: " · "))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      ProfileSourceLink(rawValue: project.url)
    }
  }
}

private struct ProfileFactGroup: View {
  let title: String
  let values: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title.uppercased())
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      ForEach(Array(values.enumerated()), id: \.offset) { _, value in
        Text(value)
          .font(.subheadline)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

private struct ProfileSourceLink: View {
  let rawValue: String

  @ViewBuilder
  var body: some View {
    if !rawValue.trimmed.isEmpty {
      if let url = ProfileStorySupport.webSource(from: rawValue) {
        Link(destination: url) {
          Label(ProfileStorySupport.sourceLabel(for: rawValue), systemImage: "arrow.up.right")
        }
        .font(.caption)
      }
    }
  }
}
