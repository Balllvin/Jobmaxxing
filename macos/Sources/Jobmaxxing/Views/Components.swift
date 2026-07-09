import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum AppTheme {
  static let canvas = Color(nsColor: .windowBackgroundColor)
  static let panel = Color(nsColor: .controlBackgroundColor)
  static let selectedFill = Color.primary.opacity(0.08)
  static let selectedStroke = Color.primary.opacity(0.18)
  static let hoverFill = Color.primary.opacity(0.045)
}

struct SelectedRowSurface: ViewModifier {
  let isSelected: Bool
  var cornerRadius: CGFloat = 6

  func body(content: Content) -> some View {
    content
      .background(isSelected ? AppTheme.selectedFill : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(isSelected ? AppTheme.selectedStroke : Color.clear, lineWidth: 1)
      )
  }
}

struct FocusRingSuppressor: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView {
    FocusRingSuppressingView()
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    (nsView as? FocusRingSuppressingView)?.suppressSoon()
  }
}

private final class FocusRingSuppressingView: NSView {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    suppressSoon()
  }

  override func layout() {
    super.layout()
    suppressSoon()
  }

  func suppressSoon() {
    DispatchQueue.main.async { [weak self] in
      self?.window?.contentView?.suppressFocusRingsRecursively()
    }
  }
}

private extension NSView {
  func suppressFocusRingsRecursively() {
    focusRingType = .none
    subviews.forEach { $0.suppressFocusRingsRecursively() }
  }
}

struct MetricCell: View {
  let label: String
  let value: String
  var tone: Color = .primary

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label.uppercased())
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.system(.title2, design: .monospaced).weight(.bold))
        .foregroundStyle(tone)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(.background)
    .overlay(Rectangle().stroke(.separator, lineWidth: 1))
  }
}

struct SectionBox<Content: View>: View {
  let title: String
  let systemImage: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
        Text(title.uppercased())
          .font(.caption.weight(.bold))
        Spacer()
      }
      .foregroundStyle(.secondary)
      content
    }
    .padding(14)
    .background(AppTheme.panel)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(.separator, lineWidth: 1)
    )
  }
}

struct StatusDot: View {
  let isOn: Bool

  var stateLabel: String {
    isOn ? "Ready" : "Set up"
  }

  var body: some View {
    Image(systemName: isOn ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
      .foregroundStyle(isOn ? .green : .orange)
      .accessibilityLabel(stateLabel)
  }
}

struct TagText: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .lineLimit(1)
      .truncationMode(.tail)
      .allowsTightening(false)
      .padding(.horizontal, 7)
      .padding(.vertical, 4)
      .background(.quaternary)
      .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}

struct FlowTags: View {
  let items: [String]

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], alignment: .leading, spacing: 6) {
      ForEach(items, id: \.self) { item in
        TagText(text: item)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

struct EmptyPanel: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
      Text(detail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(.background)
    .overlay(Rectangle().stroke(.separator, lineWidth: 1))
  }
}

struct CompactList<Items: RandomAccessCollection>: View where Items.Element == String {
  let items: Items

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "minus")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
          Text(item)
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}

struct MultilineInput: View {
  let title: String
  @Binding var text: String
  var minHeight: CGFloat = 120
  /// Extra context for the improve-with-feedback rewrite (job, company, etc.).
  var improveContext: String = ""
  var improveKind: String = ""
  var showsImprove: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .center, spacing: 8) {
        Text(title.uppercased())
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer(minLength: 8)
        if showsImprove {
          ImproveTextControl(
            currentText: text,
            context: improveContext,
            kind: improveKind.trimmed.isEmpty ? title : improveKind,
            onApply: { text = $0 }
          )
        }
      }
      TextEditor(text: $text)
        .font(.body)
        .frame(minHeight: minHeight)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(.background)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
    }
  }
}

enum DocumentImportTypes {
  static var allowed: [UTType] {
    var types: [UTType] = [.pdf, .plainText, .text, .rtf, .commaSeparatedText, .json, .html, .image, .audio, .movie, .data]
    if let docx = UTType(filenameExtension: "docx") {
      types.append(docx)
    }
    if let markdown = UTType(filenameExtension: "md") {
      types.append(markdown)
    }
    return types
  }
}

struct DocumentProofPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let title: String
  let detail: String
  var limit: Int = 4
  var contextCompany: String = ""
  var contextRole: String = ""
  var defaultTask: DocumentWorkflowTask = .attach
  var availableTasks: [DocumentWorkflowTask] = DocumentWorkflowTask.allCases

  @State private var importing = false
  @State private var importError = ""
  @State private var selectedTask: DocumentWorkflowTask = .attach
  @State private var documentTitle = ""
  @State private var recipient = ""
  @State private var taskNotes = ""
  @State private var taskStatus = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Button {
          importing = true
        } label: {
          Label("Import files", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
      }

      if !importError.isEmpty {
        Text(importError)
          .font(.caption)
          .foregroundStyle(.red)
      }

      if store.state.documents.isEmpty {
        Divider()
        Text("Import the CV, cover letter, transcript, project brief, or company research file you plan to use.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        Divider()
        if availableTasks.count > 1 {
          Picker("Task", selection: $selectedTask) {
            ForEach(availableTasks) { task in
              Text(task.label).tag(task)
            }
          }
          .pickerStyle(.segmented)
        }

        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Documents")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
            ScrollView {
              LazyVStack(spacing: 6) {
                ForEach(store.state.documents) { document in
                  Button {
                    store.selectedDocumentID = document.id
                    documentTitle = cleanTitle(for: document)
                  } label: {
                    DocumentProofRow(document: document, isSelected: store.selectedDocumentID == document.id)
                  }
                  .buttonStyle(.plain)
                }
              }
            }
            .frame(minHeight: 170, maxHeight: 250)
          }
          .frame(minWidth: 260, idealWidth: 320)

          if let document = store.selectedDocument {
            selectedDocumentView(document)
          } else {
            Text(availableTasks.count == 1 ? "Select a document to save as proof." : "Select a document to attach, edit, research, checklist, or save as proof.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }
    .onAppear {
      selectedTask = availableTasks.contains(defaultTask) ? defaultTask : availableTasks.first ?? .attach
      if let document = store.selectedDocument, documentTitle.trimmed.isEmpty {
        documentTitle = cleanTitle(for: document)
      }
    }
    .onChange(of: selectedTask) { _, _ in
      taskStatus = ""
      taskNotes = ""
    }
    .fileImporter(
      isPresented: $importing,
      allowedContentTypes: DocumentImportTypes.allowed,
      allowsMultipleSelection: true
    ) { result in
      do {
        let urls = try result.get()
        try store.importDocuments(from: urls)
        documentTitle = store.selectedDocument.map(cleanTitle) ?? ""
        importError = ""
      } catch {
        importError = error.localizedDescription
      }
    }
  }

  @ViewBuilder
  private func selectedDocumentView(_ document: CandidateDocument) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(document.title)
            .font(.headline)
          Text(document.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Text(document.fileName)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Button {
          NSWorkspace.shared.open(URL(fileURLWithPath: document.filePath))
        } label: {
          Label("Open file", systemImage: "arrow.up.right.square")
        }
      }

      Text(selectedTask.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if selectedTask == .proof {
        LabeledContent("Proof title") {
          HStack {
            TextField("Evidence title shown beside this proof", text: $documentTitle)
            Button {
              store.promoteDocumentToEvidence(documentID: document.id, title: documentTitle, tags: inferredEvidenceTags(for: document))
              taskStatus = "Proof saved. Its source file stays linked."
            } label: {
              Label("Save as proof", systemImage: "checkmark.seal")
            }
            .buttonStyle(.bordered)
            .disabled(documentTitle.trimmed.isEmpty)
          }
        }
      } else {
        renameDocumentDisclosure(for: document)

        if selectedTask.needsRecipient {
          LabeledContent("Recipient") {
            TextField("Recruiter, hiring manager, or application portal", text: $recipient)
          }
        }

        HStack(alignment: .top, spacing: 8) {
          LabeledContent(selectedTask.inputLabel) {
            TextField(selectedTask.inputPlaceholder, text: $taskNotes, axis: .vertical)
              .lineLimit(2...4)
          }
          ImproveTextControl(
            currentText: taskNotes,
            context: [
              "Task: \(selectedTask.label)",
              "Document: \(document.title)",
              "Summary: \(document.summary.bounded(to: 500))",
              "Company: \(contextCompany)",
              "Role: \(contextRole)"
            ].joined(separator: "\n"),
            kind: selectedTask.inputLabel.lowercased(),
            onApply: { taskNotes = $0 }
          )
        }

        Button {
          copyTaskChecklist(for: document)
        } label: {
          Label(selectedTask.actionTitle, systemImage: "doc.on.doc")
        }
        .buttonStyle(.bordered)
      }

      if !taskStatus.trimmed.isEmpty {
        Text(taskStatus)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .onChange(of: document.id) { _, _ in
      documentTitle = cleanTitle(for: document)
    }
  }

  private func renameDocumentDisclosure(for document: CandidateDocument) -> some View {
    DisclosureGroup("Rename document") {
      HStack {
        TextField("Document title", text: $documentTitle)
        Button("Suggest") {
          documentTitle = suggestedTitle(for: document)
        }
        Button("Save name") {
          store.updateDocumentTitle(documentID: document.id, title: documentTitle)
        }
        .disabled(documentTitle.trimmed.isEmpty)
      }
      .padding(.top, 6)
    }
  }

  private func cleanTitle(for document: CandidateDocument) -> String {
    let title = document.title
      .replacingOccurrences(of: "update", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "copy", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .split(separator: " ")
      .joined(separator: " ")
      .trimmed
    return title.isEmpty ? document.title : title
  }

  private func suggestedTitle(for document: CandidateDocument) -> String {
    let base: String
    if document.kind.lowercased() == "pdf" && document.title.localizedCaseInsensitiveContains("cv") {
      base = "Local Candidate - CV"
    } else {
      base = cleanTitle(for: document)
    }
    let company = contextCompany.trimmed
    let role = contextRole.trimmed
    switch selectedTask {
    case .attach:
      return [base, company, role].filter { !$0.isEmpty }.joined(separator: " - ")
    case .tailor:
      return [base, company, role, "Tailored"].filter { !$0.isEmpty }.joined(separator: " - ")
    case .proof:
      return [base, "Proof"].filter { !$0.isEmpty }.joined(separator: " - ")
    case .companyAnalysis:
      return ["Company analysis", company.isEmpty ? base : company].joined(separator: " - ")
    case .fields:
      return ["Application fields", company, role].filter { !$0.isEmpty }.joined(separator: " - ")
    }
  }

  private func copyTaskChecklist(for document: CandidateDocument) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(taskChecklist(for: document), forType: .string)
    taskStatus = "\(selectedTask.copiedStatus) copied. Review before using externally."
  }

  private func inferredEvidenceTags(for document: CandidateDocument) -> String {
    ["proof", "application", document.kind, contextCompany, contextRole]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }

  private func taskChecklist(for document: CandidateDocument) -> String {
    [
      "Task: \(selectedTask.label)",
      "Document: \(documentTitle.trimmed.isEmpty ? document.title : documentTitle.trimmed)",
      contextCompany.trimmed.isEmpty ? "" : "Company: \(contextCompany.trimmed)",
      contextRole.trimmed.isEmpty ? "" : "Role: \(contextRole.trimmed)",
      recipient.trimmed.isEmpty ? "" : "Recipient: \(recipient.trimmed)",
      "\(selectedTask.inputLabel): \(taskNotes.trimmed.isEmpty ? selectedTask.defaultInput : taskNotes.trimmed)",
      "Safety: review content before sending, uploading, or using in an external form.",
      "Source: \(document.filePath)"
    ]
    .filter { !$0.trimmed.isEmpty }
    .joined(separator: "\n")
  }
}

enum DocumentWorkflowTask: String, CaseIterable, Identifiable {
  case attach
  case tailor
  case proof
  case companyAnalysis
  case fields

  var id: String { rawValue }

  var label: String {
    switch self {
    case .attach: "Attach"
    case .tailor: "Edit"
    case .proof: "Proof"
    case .companyAnalysis: "Research"
    case .fields: "Checklist"
    }
  }

  var detail: String {
    switch self {
    case .attach: "Copy the file and recipient checklist. Nothing is sent here."
    case .tailor: "Copy an edit brief for a company-specific CV, letter, or answer set."
    case .proof: "Save this document as evidence for later claims."
    case .companyAnalysis: "Copy a research brief from this source."
    case .fields: "Copy the fields for ATS, email, or LinkedIn."
    }
  }

  var needsRecipient: Bool {
    self == .attach || self == .tailor || self == .fields
  }

  var inputLabel: String {
    switch self {
    case .attach: "Checklist"
    case .tailor: "Edit notes"
    case .proof: "Proof notes"
    case .companyAnalysis: "Research focus"
    case .fields: "Fields needed"
    }
  }

  var inputPlaceholder: String {
    switch self {
    case .attach: "File, recipient, required attachments, and manual checkpoint"
    case .tailor: "Target tone, role requirements, proof to keep, and edits"
    case .proof: "Claim, source, tags, and where it can be cited"
    case .companyAnalysis: "Business, role context, people, risks, and open questions"
    case .fields: "ATS, email, or LinkedIn fields that need manual review"
    }
  }

  var defaultInput: String {
    switch self {
    case .attach: "CV, cover letter, contact, work authorization, availability, and manual checkpoint"
    case .tailor: "Target role requirements, proof to keep, tone, and edits to make"
    case .proof: "Claim, source, tags, and where it can be cited"
    case .companyAnalysis: "Business, role context, people, risks, and open questions"
    case .fields: "ATS, email, or LinkedIn fields that need manual review"
    }
  }

  var actionTitle: String {
    switch self {
    case .attach: "Copy attachment checklist"
    case .tailor: "Copy edit brief"
    case .proof: "Save as proof"
    case .companyAnalysis: "Copy research brief"
    case .fields: "Copy field checklist"
    }
  }

  var copiedStatus: String {
    switch self {
    case .attach: "Attachment checklist"
    case .tailor: "Edit brief"
    case .proof: "Proof"
    case .companyAnalysis: "Research brief"
    case .fields: "Field checklist"
    }
  }
}

private struct DocumentProofRow: View {
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
    .padding(.horizontal, 8)
    .padding(.vertical, 7)
    .modifier(SelectedRowSurface(isSelected: isSelected))
  }
}
