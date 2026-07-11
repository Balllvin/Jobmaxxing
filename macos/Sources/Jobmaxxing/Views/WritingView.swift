import SwiftUI

struct WritingView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var draftText = ""
  @Binding var draftBuffers: [String: String]
  @Binding var freeformDraft: String
  @State private var loadedJobID: String?
  @State private var memoryNote = "Use contact messages only after identifying the recruiter or hiring-team recipient."
  @State private var audit: WritingAuditResult?
  @State private var confirmsRevert = false
  @State private var confirmsRegeneration = false
  @State private var pendingRegenerationJobID: String?
  @State private var isRegeneratingDraft = false
  @State private var evidenceSearch = ""
  @State private var showsAllEvidence = false

  private let compactBreakpoint: CGFloat = 900

  var body: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < compactBreakpoint
      let layout = compact
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 24))
        : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
      ScrollView {
        layout {
          editorContent
            .padding(compact ? 16 : 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
          Divider()
          supportContent
            .padding(compact ? 16 : 18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .onAppear(perform: syncSelectedDraft)
    .onChange(of: store.selectedJobID) { _, _ in
      syncSelectedDraft()
    }
    .onDisappear(perform: saveCurrentBuffer)
    .confirmationDialog(
      "Discard unsaved edits?",
      isPresented: $confirmsRevert,
      titleVisibility: .visible
    ) {
      Button("Revert to saved draft", role: .destructive) {
        revertSelectedDraft()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This replaces the text in the editor with the last saved draft.")
    }
    .confirmationDialog(
      "Replace unsaved edits with a regenerated draft?",
      isPresented: $confirmsRegeneration,
      titleVisibility: .visible
    ) {
      Button("Regenerate and replace", role: .destructive) {
        if let jobID = pendingRegenerationJobID {
          regenerateDraft(jobID: jobID)
        }
        pendingRegenerationJobID = nil
      }
      Button("Cancel", role: .cancel) {
        pendingRegenerationJobID = nil
      }
    } message: {
      Text("Your current edits remain available unless you confirm replacement.")
    }
  }

  @ViewBuilder
  private var editorContent: some View {
    VStack(alignment: .leading, spacing: 18) {
      if let job = store.selectedJob {
        VStack(alignment: .leading, spacing: 3) {
          Text(job.role)
            .font(.title3.weight(.semibold))
          Text(job.company)
            .foregroundStyle(.secondary)
        }

      } else {
        VStack(alignment: .leading, spacing: 3) {
          Text("Freeform writing audit")
            .font(.title3.weight(.semibold))
          Text("Audit writing before you attach it to a role.")
            .foregroundStyle(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .center, spacing: 8) {
          Text("DRAFT TO AUDIT")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer(minLength: 8)
          ImproveTextControl(
            currentText: draftText,
            context: selectedWritingContext,
            kind: "cover letter or outreach draft",
            onApply: applyImprovedDraft
          )
        }
        TextEditor(text: $draftText)
          .font(.body)
          .frame(minHeight: 280)
          .scrollContentBackground(.hidden)
          .padding(10)
          .liquidGlassSurface(.strong, cornerRadius: AppTheme.radiusSmall, isInteractive: true)
          .accessibilityLabel("Draft to audit")
      }
      Text("Paste or edit the cover letter, recruiter note, or answer set. Audit it before using it externally.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 10) {
          writingActions
        }
        VStack(alignment: .leading, spacing: 8) {
          writingActions
        }
      }

      if let audit {
        WritingAuditSummary(audit: audit)
      }
    }
  }

  @ViewBuilder
  private var writingActions: some View {
    Button {
      audit = store.audit(text: draftText)
    } label: {
      Label("Audit draft", systemImage: "checkmark.seal")
    }
    .buttonStyle(.borderedProminent)
    .disabled(draftText.trimmed.isEmpty)

    if hasUnsavedDraftChanges {
      Button {
        confirmsRevert = true
      } label: {
        Label("Revert to saved draft", systemImage: "arrow.uturn.backward")
      }
      .buttonStyle(.bordered)
    }
  }

  private var supportContent: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Proof to cite")
          .font(.headline)
        if store.state.profile.evidence.isEmpty {
          EmptyPanel(title: "No proof yet", detail: "Import a document or save evidence before citing claims.")
        } else {
          TextField("Find saved proof", text: $evidenceSearch)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("Find saved proof")
          LazyVStack(alignment: .leading, spacing: 0) {
            if visibleEvidence.isEmpty {
              Text("No saved proof matches this search.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
            }
            ForEach(Array(visibleEvidence.enumerated()), id: \.element.id) { index, item in
              WritingProofRow(item: item)
              if index < visibleEvidence.count - 1 {
                Divider()
              }
            }
          }
          if evidenceSearch.trimmed.isEmpty && filteredEvidence.count > 6 {
            Button(showsAllEvidence ? "Show fewer" : "Show all \(filteredEvidence.count) proof items") {
              showsAllEvidence.toggle()
            }
            .buttonStyle(LiquidPressButtonStyle())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(minHeight: 44)
          }
        }
      }

      DocumentProofPanel(
        title: "Add proof from a document",
        detail: "Import a file, select it, then save its summary as traceable proof.",
        limit: 3,
        defaultTask: .proof,
        availableTasks: [.proof]
      )

      VStack(alignment: .leading, spacing: 10) {
        if let job = store.selectedJob {
          VStack(alignment: .leading, spacing: 3) {
            Text(job.role)
              .font(.headline)
            Text(job.company)
              .foregroundStyle(.secondary)
          }
          if let draft = job.draft, let missing = draft.missingEvidence, !missing.isEmpty {
            Divider()
            Text("Missing proof")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
            CompactList(items: missing)
          }
          if let draft = job.draft, let trace = draft.claimTrace, !trace.isEmpty {
            Divider()
            Text("Claim trace")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
            CompactList(items: trace.prefix(6).map { "\($0.location): \($0.evidenceLabel)" })
          }
          Button {
            requestRegeneration(jobID: job.id)
          } label: {
            HStack(spacing: 7) {
              if isRegeneratingDraft {
                ProgressView()
                  .controlSize(.small)
              } else {
                Image(systemName: "wand.and.stars")
              }
              Text(isRegeneratingDraft ? "Regenerating…" : "Regenerate draft")
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(isRegeneratingDraft)
        } else {
          EmptyPanel(title: "No job selected", detail: "Select a role in Applications.")
        }
      }

      DisclosureGroup("Remember writing rule for audits and improve") {
        VStack(alignment: .leading, spacing: 8) {
          TextField("Rule for audits and Improve", text: $memoryNote)
          Button {
            store.recordPromptMemory(memoryNote)
            memoryNote = ""
          } label: {
            Label("Save rule", systemImage: "plus")
          }
          .buttonStyle(.bordered)
          .disabled(memoryNote.trimmed.isEmpty)
        }
        .padding(.top, 8)
      }

      if !store.state.promptMemory.isEmpty {
        DisclosureGroup("Saved writing rules (\(store.state.promptMemory.count))") {
          CompactList(items: store.state.promptMemory)
            .padding(.top, 8)
        }
      }
    }
  }

  private var selectedWritingContext: String {
    guard let job = store.selectedJob else {
      return "Freeform application writing. Keep every claim grounded in saved evidence."
    }
    return [
      "Company: \(job.company)",
      "Role: \(job.role)",
      "Description: \(job.description.bounded(to: 900))",
      "Keywords: \(job.keywords.compactJoined)",
      job.draft.map { "Saved cover letter: \($0.coverLetter.bounded(to: 700))" } ?? ""
    ].filter { !$0.isEmpty }.joined(separator: "\n")
  }

  private var filteredEvidence: [EvidenceItem] {
    let query = evidenceSearch.trimmed
    guard !query.isEmpty else { return store.state.profile.evidence }
    return store.state.profile.evidence.filter { item in
      [item.title, item.proof, item.sourceURL, item.tags.joined(separator: " ")]
        .joined(separator: " ")
        .localizedCaseInsensitiveContains(query)
    }
  }

  private var visibleEvidence: [EvidenceItem] {
    guard evidenceSearch.trimmed.isEmpty, !showsAllEvidence else { return filteredEvidence }
    return Array(filteredEvidence.prefix(6))
  }

  private func applyImprovedDraft(_ next: String) {
    draftText = next
    if let job = store.selectedJob {
      draftBuffers[job.id] = next
      store.updateDraftCoverLetter(jobID: job.id, coverLetter: next)
    } else {
      freeformDraft = next
    }
    audit = nil
  }

  private func requestRegeneration(jobID: String) {
    if hasUnsavedDraftChanges {
      pendingRegenerationJobID = jobID
      confirmsRegeneration = true
    } else {
      regenerateDraft(jobID: jobID)
    }
  }

  private func regenerateDraft(jobID: String) {
    guard !isRegeneratingDraft else { return }
    isRegeneratingDraft = true
    Task { @MainActor in
      await Task.yield()
      store.generateDraft(jobID: jobID)
      revertSelectedDraft()
      isRegeneratingDraft = false
    }
  }

  private func syncSelectedDraft() {
    let nextJobID = store.selectedJob?.id
    guard loadedJobID != nextJobID else { return }
    if let loadedJobID {
      draftBuffers[loadedJobID] = draftText
    } else {
      freeformDraft = draftText
    }
    loadedJobID = nextJobID
    if let job = store.selectedJob {
      draftText = draftBuffers[job.id] ?? job.draft?.coverLetter ?? ""
    } else {
      draftText = freeformDraft
    }
    audit = nil
  }

  private func saveCurrentBuffer() {
    if let loadedJobID {
      draftBuffers[loadedJobID] = draftText
    } else {
      freeformDraft = draftText
    }
  }

  private func revertSelectedDraft() {
    guard let job = store.selectedJob else { return }
    loadedJobID = job.id
    draftText = job.draft?.coverLetter ?? ""
    draftBuffers[job.id] = draftText
    audit = nil
  }

  private var hasUnsavedDraftChanges: Bool {
    guard let job = store.selectedJob else { return false }
    return draftText != (job.draft?.coverLetter ?? "")
  }
}

private struct WritingAuditSummary: View {
  let audit: WritingAuditResult

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text("\(audit.score)")
          .font(.system(.largeTitle, design: .monospaced).weight(.bold))
          .foregroundStyle(audit.ready ? .green : .orange)
        Text(audit.ready ? "Ready to use" : "Needs fixes")
          .font(.headline)
          .foregroundStyle(audit.ready ? .green : .red)
      }

      if !audit.flags.isEmpty {
        CompactList(items: audit.flags)
      }
      if !audit.unsupportedClaims.isEmpty {
        LabeledAuditList(title: "Unsupported claims", items: audit.unsupportedClaims)
      }
      if !audit.evidenceReferences.isEmpty {
        LabeledAuditList(title: "Evidence used", items: audit.evidenceReferences)
      }
      if !audit.rewriteRules.isEmpty {
        LabeledAuditList(title: "Rewrite", items: audit.rewriteRules)
      }
    }
    .padding(.top, 2)
  }
}

private struct LabeledAuditList<Items: RandomAccessCollection>: View where Items.Element == String {
  let title: String
  let items: Items

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Divider()
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
      CompactList(items: items)
    }
  }
}

private struct WritingProofRow: View {
  let item: EvidenceItem

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(item.title)
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text("Strength \(item.strength)")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Text(item.proof)
        .font(.subheadline)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        if let url = ExternalURL.normalizedWebURL(item.sourceURL) {
          Link("Source", destination: url)
        } else if !item.sourceURL.trimmed.isEmpty {
          Text("Invalid source")
        }
        if !tagSummary.isEmpty {
          Text(tagSummary)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .lineLimit(1)
    }
    .padding(.vertical, 10)
  }

  private var tagSummary: String {
    let visibleTags = item.tags.prefix(3)
    guard !visibleTags.isEmpty else { return "" }
    let suffix = item.tags.count > visibleTags.count ? " +\(item.tags.count - visibleTags.count)" : ""
    return "Tags: \(visibleTags.joined(separator: ", "))\(suffix)"
  }
}
