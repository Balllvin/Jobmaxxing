import SwiftUI

struct ApplicationsView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let openCompany: (String) -> Void
  @State private var company = ""
  @State private var role = ""
  @State private var sourceURL = ""
  @State private var description = ""

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
            Button {
              store.selectedJobID = job.id
            } label: {
              ApplicationListRow(job: job, isSelected: store.selectedJobID == job.id)
            }
            .buttonStyle(.plain)
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
    DisclosureGroup("Add role") {
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
      .padding(.top, 8)
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
  @State private var openStatus = ""

  var body: some View {
    if let job = store.selectedJob {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
              VStack(alignment: .leading, spacing: 6) {
                Text(job.role)
                  .font((compact ? Font.title : Font.largeTitle).weight(.bold))
                  .fixedSize(horizontal: false, vertical: true)
                Text(job.company)
                  .font(.title3)
                  .foregroundStyle(.secondary)
              }
              Spacer(minLength: 12)
              TagText(text: job.stage.label)
            }

            ViewThatFits(in: .horizontal) {
              HStack(spacing: 12) {
                stagePicker(for: job)
                draftButton(for: job)
              }
              VStack(alignment: .leading, spacing: 8) {
                stagePicker(for: job)
                draftButton(for: job)
              }
            }

            ViewThatFits(in: .horizontal) {
              HStack(spacing: 10) {
                jobPostButton(for: job)
                hiringPeopleButton(for: job)
              }
              VStack(alignment: .leading, spacing: 8) {
                jobPostButton(for: job)
                hiringPeopleButton(for: job)
              }
            }
            if !openStatus.trimmed.isEmpty {
              Text(openStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ApplicationMetaRow(label: "Job post") {
              if let source = ExternalURL.normalizedWebURL(job.sourceURL) {
                Link(applicationSourceLabel(for: job.sourceURL), destination: source)
                  .help(source.absoluteString)
              } else {
                Text("No job post")
                  .foregroundStyle(.secondary)
              }
            }
            ApplicationMetaRow(label: "Score") {
              Text("\(job.score)")
                .font(.body.monospaced().weight(.semibold))
            }

            if !job.risks.isEmpty {
              ApplicationMetaRow(label: "Check") {
                Text(job.risks.joined(separator: "; "))
                  .foregroundStyle(.secondary)
              }
            }

            if !job.nextActions.isEmpty {
              Divider()
              Text("Next")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
              CompactList(items: job.nextActions)
            }

            if !job.description.trimmed.isEmpty {
              Divider()
              Text(job.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !job.keywords.isEmpty {
              FlowTags(items: job.keywords)
            }
          }

          ApplicationCompanyPanel(job: job, openCompany: openCompany)

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

          if let draft = job.draft {
            DraftView(job: job, draft: draft)
          } else {
            EmptyApplicationState(title: "Draft application after source review.")
          }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    } else {
      EmptyApplicationState(title: "Select a role.")
        .padding(18)
    }
  }

  private func stagePicker(for job: JobRecord) -> some View {
    Picker("Stage", selection: Binding(
      get: { job.stage },
      set: { store.updateStage(jobID: job.id, stage: $0) }
    )) {
      ForEach(JobStage.allCases) { stage in
        Text(stage.label).tag(stage)
      }
    }
    .frame(maxWidth: compact ? .infinity : 280, alignment: .leading)
  }

  private func draftButton(for job: JobRecord) -> some View {
    Button {
      store.generateDraft(jobID: job.id)
    } label: {
      Label("Draft application", systemImage: "wand.and.stars")
    }
    .buttonStyle(.borderedProminent)
  }

  private func jobPostButton(for job: JobRecord) -> some View {
    Button {
      openStatus = openApplicationURL(job.sourceURL, label: "Job post")
    } label: {
      Label("Open job post", systemImage: "safari")
    }
    .disabled(job.sourceURL.trimmed.isEmpty)
  }

  private func hiringPeopleButton(for job: JobRecord) -> some View {
    Button {
      openStatus = openApplicationURL(linkedInPeopleSearch(company: job.company, role: job.role), label: "Hiring people")
    } label: {
      Label("Find hiring people", systemImage: "person.text.rectangle")
    }
  }
}

private struct ApplicationCompanyPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let job: JobRecord
  let openCompany: (String) -> Void

  private var company: CompanyProfile? {
    store.companyProfiles.first { $0.applicationIDs.contains(job.id) || $0.name.caseInsensitiveCompare(job.company) == .orderedSame }
  }

  var body: some View {
    ApplicationFlatSection(title: "Company") {
      if let company {
        VStack(alignment: .leading, spacing: 10) {
          Text(company.name)
            .font(.headline)
          Text(company.research.status)
            .font(.caption)
            .foregroundStyle(.secondary)
          if !company.summary.trimmed.isEmpty {
            Text(company.summary)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Button {
            store.selectedCompanyID = company.id
            store.prepareCompanyResearch(companyID: company.id)
            openCompany(company.id)
          } label: {
            Label("Open company", systemImage: "building.2")
          }
          .buttonStyle(.borderedProminent)
        }
      } else {
        EmptyApplicationState(title: "Company profile appears after saving.")
      }
    }
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
    ApplicationFlatSection(title: "Documents") {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Text("Proof files for this role. Nothing sends here.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
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
            Button {
              store.selectedDocumentID = document.id
              proofMetadata = defaultProofMetadata(document: document, job: job)
              taskStatus = ""
            } label: {
              ApplicationDocumentRow(document: document, isSelected: store.selectedDocumentID == document.id)
            }
            .buttonStyle(.plain)
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
  @State private var openStatus = ""

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
        ViewThatFits(in: .horizontal) {
          HStack {
            draftHiringPeopleButton
            draftJobPostButton
          }
          VStack(alignment: .leading, spacing: 8) {
            draftHiringPeopleButton
            draftJobPostButton
          }
        }
        if !openStatus.trimmed.isEmpty {
          Text(openStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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

  private var draftHiringPeopleButton: some View {
    Button {
      openStatus = openApplicationURL(linkedInPeopleSearch(company: job.company, role: job.role), label: "Hiring people")
    } label: {
      Label("Find hiring people", systemImage: "person.text.rectangle")
    }
  }

  private var draftJobPostButton: some View {
    Button {
      openStatus = openApplicationURL(job.sourceURL, label: "Job post")
    } label: {
      Label("Open job post", systemImage: "safari")
    }
    .disabled(job.sourceURL.trimmed.isEmpty)
  }
}

private struct ApplicationFlatSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Divider()
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
