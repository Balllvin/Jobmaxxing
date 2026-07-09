import SwiftUI

struct ApplicationsView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let openCompany: (String) -> Void
  @State private var company = ""
  @State private var role = ""
  @State private var sourceURL = ""
  @State private var description = ""
  @State private var isAddingRole = false

  var body: some View {
    GeometryReader { proxy in
      if proxy.size.width < 760 {
        VStack(spacing: 0) {
          rolePane(compact: true)
          Divider()
          ApplicationDetailView(openCompany: openCompany, compact: true)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
      } else {
        HSplitView {
          rolePane(compact: false)

          ApplicationDetailView(openCompany: openCompany, compact: false)
            .padding(16)
            .frame(minWidth: 360)
            .frame(maxHeight: .infinity, alignment: .top)
        }
      }
    }
  }

  private func rolePane(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Roles")
        .font(.title3.weight(.semibold))

      ScrollView {
        LazyVStack(spacing: 4) {
          if store.state.jobs.isEmpty {
            EmptyApplicationState(title: "Add a role.")
          }
          ForEach(store.state.jobs) { job in
            ApplicationListRow(job: job, isSelected: store.selectedJobID == job.id)
              .onTapGesture {
                store.selectedJobID = job.id
              }
              .accessibilityAddTraits(.isButton)
              .accessibilityLabel("\(job.role), \(job.company)")
          }
        }
      }
      .frame(minHeight: compact ? 150 : 360, maxHeight: compact ? 210 : .infinity)

      Divider()
      addRoleForm
    }
    .padding(16)
    .frame(minWidth: compact ? 0 : 260, idealWidth: compact ? nil : 340, maxWidth: compact ? .infinity : 430)
    .frame(maxHeight: compact ? nil : .infinity, alignment: .top)
  }

  private var addRoleForm: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: isAddingRole ? "chevron.down" : "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 10)
        Text("Add role")
          .font(.body.weight(.medium))
          .foregroundStyle(.primary)
        Spacer(minLength: 0)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        withAnimation(.easeInOut(duration: 0.14)) {
          isAddingRole.toggle()
        }
      }
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel(isAddingRole ? "Collapse add role" : "Expand add role")

      if isAddingRole {
        VStack(alignment: .leading, spacing: 8) {
          TextField("Company", text: $company)
          TextField("Role", text: $role)
          TextField("Job post URL", text: $sourceURL)
          MultilineInput(
            title: "Role details, requirements, and notes",
            text: $description,
            minHeight: 130,
            improveContext: "Company: \(company)\nRole: \(role)\nSource: \(sourceURL)",
            improveKind: "role details"
          )
          Button {
            saveRole()
          } label: {
            Label("Save role", systemImage: "briefcase")
          }
          .buttonStyle(.borderedProminent)
          .disabled(company.trimmed.isEmpty || role.trimmed.isEmpty || description.trimmed.isEmpty)
        }
        .padding(.leading, 16)
      }
    }
  }

  private func saveRole() {
    store.addJob(company: company, role: role, sourceURL: sourceURL, description: description, notes: "")
    company = ""
    role = ""
    sourceURL = ""
    description = ""
  }
}

private struct ApplicationListRow: View {
  let job: JobRecord
  let isSelected: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(job.role)
          .font(.headline)
          .lineLimit(1)
        Text(job.company)
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(spacing: 6) {
          TagText(text: job.stage.label)
          if job.draft != nil {
            TagText(text: "Draft")
          }
        }
      }
      Spacer()
      Text("\(job.score)")
        .font(.caption.monospaced().weight(.bold))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .padding(10)
    .modifier(SelectedRowSurface(isSelected: isSelected))
  }
}

private struct ApplicationDetailView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let openCompany: (String) -> Void
  let compact: Bool
  @State private var localNotes = ""

  private var selectedCompany: CompanyProfile? {
    guard let job = store.selectedJob else { return nil }
    return store.companyProfiles.first { $0.applicationIDs.contains(job.id) || $0.name.caseInsensitiveCompare(job.company) == .orderedSame }
  }

  var body: some View {
    if let job = store.selectedJob {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 14) {
            ApplicationHeader(job: job, compact: compact) {
              stageMenu(for: job)
            }

            if !job.description.trimmed.isEmpty {
              Text(job.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }

            ApplicationSourceStrip(
              job: job,
              company: selectedCompany,
              openCompany: openApplicationCompany
            )

            primaryDraftButton(for: job)

            let toDoItems = applicationToDoItems(for: job)
            if !toDoItems.isEmpty {
              Divider()
              ApplicationSectionHeader("To do")
              CompactList(items: toDoItems)
            }

            if !job.keywords.isEmpty {
              ApplicationInlineTags(items: Array(job.keywords.prefix(5)))
            }
          }

          if let draft = job.draft {
            DraftView(job: job, draft: draft)
          } else {
            ApplicationFlatSection(title: "Draft") {
              EmptyApplicationState(title: "No draft yet.")
            }
          }

          ApplicationDocumentsPanel(job: job)

          ApplicationFlatSection(title: "Notes") {
            HStack {
              Spacer()
              ImproveTextControl(
                currentText: localNotes,
                context: "Company: \(job.company)\nRole: \(job.role)\nDescription: \(job.description.bounded(to: 600))",
                kind: "application notes",
                onApply: { localNotes = $0 }
              )
            }
            TextEditor(text: $localNotes)
              .frame(minHeight: 90)
              .onAppear { localNotes = job.notes }
              .onChange(of: job.id) { _, _ in localNotes = job.notes }
            Button("Save notes") {
              store.updateNotes(jobID: job.id, notes: localNotes)
            }
          }

        }
        .frame(maxWidth: 840, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    } else {
      EmptyApplicationState(title: "Select a role.")
        .padding(18)
    }
  }

  private func stageMenu(for job: JobRecord) -> some View {
    Menu {
      ForEach(JobStage.allCases) { stage in
        Button(stage.label) {
          store.updateStage(jobID: job.id, stage: stage)
        }
      }
    } label: {
      HStack(spacing: 4) {
        Text(job.stage.label)
          .font(.caption.weight(.semibold))
        Image(systemName: "chevron.down")
          .font(.caption2.weight(.semibold))
      }
      .foregroundStyle(.secondary)
    }
    .menuStyle(.borderlessButton)
    .buttonStyle(.plain)
    .controlSize(.small)
    .focusable(false)
  }

  @ViewBuilder
  private func primaryDraftButton(for job: JobRecord) -> some View {
    if applicationDraftActionIsPrimary(hasDraft: job.draft != nil) {
      Button {
        store.generateDraft(jobID: job.id)
      } label: {
        Label(applicationDraftActionTitle(hasDraft: false), systemImage: "wand.and.stars")
      }
      .buttonStyle(.borderedProminent)
      .focusable(false)
    }
  }

  private func openApplicationCompany(_ company: CompanyProfile) {
    store.selectedCompanyID = company.id
    store.prepareCompanyResearch(companyID: company.id)
    openCompany(company.id)
  }
}

private struct ApplicationHeader<StageControl: View>: View {
  let job: JobRecord
  let compact: Bool
  @ViewBuilder var stageControl: StageControl

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(job.role)
          .font((compact ? Font.title2 : Font.title).weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 12)
        Text("\(job.score)")
          .font(.body.monospaced().weight(.semibold))
          .foregroundStyle(.secondary)
      }

      ViewThatFits(in: .horizontal) {
        HStack(alignment: .center, spacing: 10) {
          Text(job.company)
            .font(.headline.weight(.medium))
          if job.draft != nil {
            Text("Draft ready")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 8)
          stageControl
        }
        VStack(alignment: .leading, spacing: 8) {
          Text(job.company)
            .font(.headline.weight(.medium))
          stageControl
        }
      }
    }
  }
}

private struct ApplicationSourceStrip: View {
  let job: JobRecord
  let company: CompanyProfile?
  let openCompany: (CompanyProfile) -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        sourceLabel
        sourceLinks
      }
      VStack(alignment: .leading, spacing: 6) {
        sourceLabel
        sourceLinks
      }
    }
    .font(.subheadline)
  }

  private var sourceLabel: some View {
    Text("Links")
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
  }

  private var sourceLinks: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      if let source = ExternalURL.normalizedWebURL(job.sourceURL) {
        Link("Job post", destination: source)
          .help(source.absoluteString)
          .focusable(false)
      } else {
        Text("No job post")
          .foregroundStyle(.secondary)
      }

      if let company {
        ApplicationTextAction("Company") {
          openCompany(company)
        }
      }

      if let hiringURL = ExternalURL.normalizedWebURL(linkedInPeopleSearch(company: job.company, role: job.role)) {
        Link("Hiring people", destination: hiringURL)
          .help(hiringURL.absoluteString)
          .focusable(false)
      }
    }
  }
}

private struct ApplicationTextAction: View {
  let title: String
  let action: () -> Void

  init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Text(title)
        .foregroundStyle(Color.accentColor)
    }
    .buttonStyle(.plain)
    .focusable(false)
  }
}

private struct ApplicationInlineTags: View {
  let items: [String]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(items, id: \.self) { item in
        Text(item)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .lineLimit(1)
  }
}

private struct ApplicationDocumentsPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let job: JobRecord
  @State private var importing = false
  @State private var importError = ""
  @State private var proofMetadata = ""
  @State private var taskStatus = ""

  private var selectedDocument: CandidateDocument? {
    store.selectedDocument ?? store.state.documents.first
  }

  var body: some View {
    ApplicationFlatSection(title: "Proof") {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Spacer(minLength: 0)
        Button {
          importing = true
        } label: {
          Label("Import files", systemImage: "plus")
        }
      }

      if !importError.trimmed.isEmpty {
        Text(importError)
          .font(.caption)
          .foregroundStyle(.red)
      }

      if store.state.documents.isEmpty {
        EmptyApplicationState(title: "Import a CV, letter, transcript, or proof file.")
      } else {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(store.state.documents.prefix(4)) { document in
            ApplicationDocumentRow(document: document, isSelected: store.selectedDocumentID == document.id)
              .onTapGesture {
                store.selectedDocumentID = document.id
                proofMetadata = defaultProofMetadata(document: document, job: job)
                taskStatus = ""
              }
              .accessibilityAddTraits(.isButton)
              .accessibilityLabel(document.title)
          }

          if store.state.documents.count > 4 {
            Text("\(store.state.documents.count - 4) more file(s) in the document library.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          if let selectedDocument {
            ApplicationSelectedDocument(
              document: selectedDocument,
              job: job,
              proofMetadata: $proofMetadata,
              taskStatus: $taskStatus
            )
          }
        }
      }
    }
    .onAppear {
      if let selectedDocument, proofMetadata.trimmed.isEmpty {
        proofMetadata = defaultProofMetadata(document: selectedDocument, job: job)
      }
    }
    .onChange(of: store.selectedDocumentID) { _, _ in
      if let selectedDocument {
        proofMetadata = defaultProofMetadata(document: selectedDocument, job: job)
      }
    }
    .fileImporter(
      isPresented: $importing,
      allowedContentTypes: DocumentImportTypes.allowed,
      allowsMultipleSelection: true
    ) { result in
      do {
        let urls = try result.get()
        try store.importDocuments(from: urls)
        proofMetadata = store.selectedDocument.map { defaultProofMetadata(document: $0, job: job) } ?? ""
        importError = ""
      } catch {
        importError = error.localizedDescription
      }
    }
  }
}

private struct ApplicationDocumentRow: View {
  let document: CandidateDocument
  let isSelected: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(document.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(document.summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      Spacer()
      Text(document.kind.uppercased())
        .font(.caption2.monospaced().weight(.bold))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .padding(.horizontal, 8)
    .padding(.vertical, 7)
    .modifier(SelectedRowSurface(isSelected: isSelected))
  }
}

private struct ApplicationSelectedDocument: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let document: CandidateDocument
  let job: JobRecord
  @Binding var proofMetadata: String
  @Binding var taskStatus: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Divider()
      Text(document.fileName)
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .lineLimit(1)

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 8) {
          documentActions
        }
        VStack(alignment: .leading, spacing: 8) {
          documentActions
        }
      }

      DisclosureGroup("Save as proof") {
        VStack(alignment: .leading, spacing: 8) {
          TextField("Proof title. Add tags after #", text: $proofMetadata, axis: .vertical)
            .lineLimit(2...4)
          Button {
            store.promoteDocumentToEvidence(
              documentID: document.id,
              title: proofTitle(from: proofMetadata, document: document),
              tags: proofTags(from: proofMetadata, job: job)
            )
            taskStatus = "Saved as proof. Review before citing it externally."
          } label: {
            Label("Save proof", systemImage: "checkmark.seal")
          }
          .disabled(proofMetadata.trimmed.isEmpty)
        }
        .padding(.top, 6)
      }

      if !taskStatus.trimmed.isEmpty {
        Text(taskStatus)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var documentActions: some View {
    Group {
      Button {
        NSWorkspace.shared.open(URL(fileURLWithPath: document.filePath))
      } label: {
        Label("Open file", systemImage: "arrow.up.right.square")
      }

      Button {
        copyEditBrief()
      } label: {
        Label("Copy edit brief", systemImage: "doc.on.doc")
      }
    }
  }

  private func copyEditBrief() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(applicationEditBrief(document: document, job: job), forType: .string)
    taskStatus = "Edit brief copied. Review before using externally."
  }
}

private struct DraftView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let job: JobRecord
  let draft: ApplicationDraft

  private var draftContext: String {
    [
      "Company: \(job.company)",
      "Role: \(job.role)",
      "Stage: \(job.stage.label)",
      "Source: \(job.sourceURL)",
      "Keywords: \(job.keywords.compactJoined)",
      "Description: \(job.description.bounded(to: 900))",
      "Headline: \(draft.headline)",
      "Cover letter: \(draft.coverLetter.bounded(to: 900))",
      "Contact message: \(draft.recruiterMessage.bounded(to: 600))",
      "Resume bullets: \(draft.resumeBullets.joined(separator: " | ").bounded(to: 600))"
    ].joined(separator: "\n")
  }

  var body: some View {
    ApplicationFlatSection(title: "Draft") {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(draft.headline)
          .font(.headline)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        Button {
          store.generateDraft(jobID: job.id)
        } label: {
          Text("Regenerate")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .focusable(false)
        ImproveTextControl(
          currentText: draft.headline,
          context: draftContext,
          kind: "headline",
          onApply: { store.updateDraftHeadline(jobID: job.id, headline: $0) }
        )
      }
      Divider()
      VStack(alignment: .leading, spacing: 10) {
        ImproveSectionHeader(
          title: "Resume bullets",
          currentText: draft.resumeBullets.joined(separator: "\n"),
          context: draftContext,
          kind: "resume bullets",
          onApply: { store.updateDraftResumeBullets(jobID: job.id, bullets: TextImproveSupport.bullets(from: $0)) }
        )
        CompactList(items: draft.resumeBullets)
      }
      Divider()
      VStack(alignment: .leading, spacing: 10) {
        ImproveSectionHeader(
          title: "Cover letter",
          currentText: draft.coverLetter,
          context: draftContext,
          kind: "cover letter",
          onApply: { store.updateDraftCoverLetter(jobID: job.id, coverLetter: $0) }
        )
        Text(draft.coverLetter)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
      Divider()
      VStack(alignment: .leading, spacing: 10) {
        ImproveSectionHeader(
          title: "Contact message",
          currentText: draft.recruiterMessage,
          context: draftContext,
          kind: "contact message",
          onApply: { store.updateDraftRecruiterMessage(jobID: job.id, message: $0) }
        )
        Text(draft.recruiterMessage)
          .textSelection(.enabled)
      }
      if !draft.evidenceLinks.isEmpty {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          Text("Evidence links".uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
          ForEach(draft.evidenceLinks, id: \.self) { link in
            if let destination = ExternalURL.normalizedWebURL(link) {
              Link(applicationSourceLabel(for: link), destination: destination)
                .help(destination.absoluteString)
            } else {
              Text("Invalid link: \(link)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

}

private struct ApplicationFlatSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Divider()
      ApplicationSectionHeader(title)
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ApplicationSectionHeader: View {
  let title: String

  init(_ title: String) {
    self.title = title
  }

  var body: some View {
    Text(title.uppercased())
      .font(.caption.weight(.bold))
      .foregroundStyle(.secondary)
  }
}

private struct ApplicationMetaRow<Content: View>: View {
  let label: String
  @ViewBuilder var content: Content

  var body: some View {
    LabeledContent(label) {
      content
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .font(.subheadline)
  }
}

private struct EmptyApplicationState: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
  }
}

func applicationSourceLabel(for urlString: String) -> String {
  guard let url = ExternalURL.normalizedWebURL(urlString) else {
    return urlString.trimmed.isEmpty ? "No job post" : "Invalid job post"
  }

  let host = (url.host(percentEncoded: false) ?? url.absoluteString)
    .replacingOccurrences(of: "www.", with: "")
  let pathParts = url.pathComponents
    .filter { $0 != "/" }
    .map { $0.removingPercentEncoding ?? $0 }
    .map { $0.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").trimmed }
    .filter { !$0.isEmpty }

  guard let detail = pathParts.last else { return host }
  let shortDetail = detail.count > 42 ? String(detail.prefix(42)).trimmed + "..." : detail
  return "\(host) - \(shortDetail)"
}

func linkedInPeopleSearch(company: String, role: String) -> String {
  var components = URLComponents(string: "https://www.linkedin.com/search/results/people/")!
  components.queryItems = [
    URLQueryItem(name: "keywords", value: "\(company) recruiter hiring \(role)")
  ]
  return components.string ?? "https://www.linkedin.com"
}

func openApplicationURL(_ urlString: String, label: String) -> String {
  ExternalURL.openWebURL(urlString, label: label).message
}

func applicationDraftActionTitle(hasDraft: Bool) -> String {
  hasDraft ? "Regenerate draft" : "Draft application"
}

func applicationDraftActionIsPrimary(hasDraft: Bool) -> Bool {
  !hasDraft
}

func applicationToDoItems(for job: JobRecord) -> [String] {
  let risks = job.risks.map { risk in
    risk.hasPrefix("Before submitting:") ? risk : "Before submitting: \(risk)"
  }
  var items: [String] = []
  for item in risks + job.nextActions {
    let cleanItem = item.trimmed
    guard !cleanItem.isEmpty else { continue }
    if !items.contains(where: { $0.caseInsensitiveCompare(cleanItem) == .orderedSame }) {
      items.append(cleanItem)
    }
  }
  return items
}

func applicationDocumentTitle(_ document: CandidateDocument) -> String {
  if !document.title.trimmed.isEmpty {
    return document.title
  }
  return document.fileName
}

func defaultProofMetadata(document: CandidateDocument, job: JobRecord) -> String {
  [
    applicationDocumentTitle(document),
    "# proof, application, \(job.company), \(job.role)"
  ]
  .joined(separator: " ")
}

func proofTitle(from metadata: String, document: CandidateDocument) -> String {
  let title = metadata
    .components(separatedBy: "#")
    .first?
    .split(separator: "\n")
    .first
    .map(String.init)?
    .trimmed ?? ""
  return title.isEmpty ? applicationDocumentTitle(document) : title
}

func proofTags(from metadata: String, job: JobRecord) -> String {
  let explicitTags = metadata
    .components(separatedBy: "#")
    .dropFirst()
    .joined(separator: ",")
    .split(separator: ",")
    .map { String($0).trimmed }
    .filter { !$0.isEmpty }

  var tags: [String] = ["proof", "application", job.company, job.role]
  for tag in explicitTags where !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
    tags.append(tag)
  }
  return tags.joined(separator: ", ")
}

func applicationEditBrief(document: CandidateDocument, job: JobRecord) -> String {
  """
  Edit this proof file for the role.

  Role: \(job.role)
  Company: \(job.company)
  File: \(document.fileName)
  Current title: \(applicationDocumentTitle(document))
  Current summary: \(document.summary)

  Keep claims factual. Use evidence from the file. Do not submit or send anything externally.
  """
}
