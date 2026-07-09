import SwiftUI

struct WritingView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var draftText = ""
  @State private var loadedJobID: String?
  @State private var memoryNote = "Use contact messages only after identifying the recruiter or hiring-team recipient."
  @State private var audit: WritingAuditResult?

  var body: some View {
    HSplitView {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if let job = store.selectedJob {
            VStack(alignment: .leading, spacing: 3) {
              Text(job.role)
                .font(.title3.weight(.semibold))
              Text(job.company)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
              HStack(alignment: .center, spacing: 8) {
                Text("DRAFT TO AUDIT")
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                ImproveTextControl(
                  currentText: draftText,
                  context: store.selectedJob.map { job in
                    [
                      "Company: \(job.company)",
                      "Role: \(job.role)",
                      "Description: \(job.description.bounded(to: 900))",
                      "Keywords: \(job.keywords.compactJoined)",
                      job.draft.map { "Saved cover letter: \($0.coverLetter.bounded(to: 700))" } ?? ""
                    ].filter { !$0.isEmpty }.joined(separator: "\n")
                  } ?? "",
                  kind: "cover letter or outreach draft",
                  onApply: { next in
                    draftText = next
                    if let jobID = store.selectedJob?.id {
                      store.updateDraftCoverLetter(jobID: jobID, coverLetter: next)
                    }
                    audit = nil
                  }
                )
              }
              TextEditor(text: $draftText)
                .font(.body)
                .frame(minHeight: 280)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            }
            Text("Paste or edit the cover letter, recruiter note, or answer set. Audit it before using it externally.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
              Button {
                audit = store.audit(text: draftText)
              } label: {
                Label("Audit draft", systemImage: "checkmark.seal")
              }
              .buttonStyle(.borderedProminent)
              .disabled(draftText.trimmed.isEmpty)

              if hasUnsavedDraftChanges {
                Button {
                  loadSelectedDraft()
                } label: {
                  Label("Revert to saved draft", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
              }
            }

            if let audit {
              WritingAuditSummary(audit: audit)
            }
          } else {
            EmptyPanel(title: "Select a role to write for", detail: "Choose an application before editing or auditing a draft.")
          }
        }
        .padding(18)
      }
      .frame(minWidth: 520)

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 10) {
            Text("Proof to cite")
              .font(.headline)
            if store.state.profile.evidence.isEmpty {
              EmptyPanel(title: "No proof yet", detail: "Import a document or save evidence before citing claims.")
            } else {
              LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(store.state.profile.evidence.prefix(6).enumerated()), id: \.element.id) { index, item in
                  WritingProofRow(item: item)
                  if index < store.state.profile.evidence.prefix(6).count - 1 {
                    Divider()
                  }
                }
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
                store.generateDraft(jobID: job.id)
                loadSelectedDraft()
              } label: {
                Label("Regenerate draft", systemImage: "wand.and.stars")
              }
              .buttonStyle(.borderedProminent)
            } else {
              EmptyPanel(title: "No job selected", detail: "Select a role in Applications.")
            }
          }

          DisclosureGroup("Remember writing rule") {
            VStack(alignment: .leading, spacing: 8) {
              TextField("Rule for future drafts", text: $memoryNote)
              Button {
                store.recordPromptMemory(memoryNote)
                memoryNote = ""
              } label: {
                Label("Save rule", systemImage: "plus")
              }
              .buttonStyle(.bordered)
            }
            .padding(.top, 8)
          }
        }
        .padding(18)
      }
      .frame(minWidth: 480)
    }
    .onAppear(perform: syncSelectedDraft)
    .onChange(of: store.selectedJobID) { _, _ in
      syncSelectedDraft()
    }
  }

  private func syncSelectedDraft() {
    guard loadedJobID != store.selectedJob?.id else { return }
    loadSelectedDraft()
  }

  private func loadSelectedDraft() {
    loadedJobID = store.selectedJob?.id
    draftText = store.selectedJob?.draft?.coverLetter ?? ""
    audit = nil
  }

  private var hasUnsavedDraftChanges: Bool {
    guard let savedDraft = store.selectedJob?.draft?.coverLetter else { return false }
    return draftText != savedDraft
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
