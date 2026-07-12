import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var selection: AppSection = .dashboard
  @State private var lastPrimarySelection: AppSection = .dashboard
  @State private var importingDocuments = false
  @State private var isProcessingDocumentImport = false
  @State private var documentImportStatus = ""
  @State private var documentImportSucceeded = true
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  @State private var contactsCompanyFilterID = ""
  @State private var applicationNoteDrafts: [String: String] = [:]
  @State private var applicationIntakeDraft = ApplicationIntakeDraft()
  @State private var interviewNoteDrafts: [String: String] = [:]
  @State private var writingDrafts: [String: String] = [:]
  @State private var freeformWritingDraft = ""
  @State private var browserDrafts: [String: BrowserWorkspaceDraft] = [:]
  @State private var companyDrafts: [String: CompanyWorkspaceDraft] = [:]
  @State private var companyDirectoryDraft = CompanyDirectoryDraft()
  @State private var contactWorkspaceDraft = ContactWorkspaceDraft()
  @State private var hermesDraft = ""
  @State private var hermesAttachmentIDs: [String] = []
  @AppStorage("jobmaxxing.selectedSection") private var savedSectionID = AppSection.dashboard.rawValue
  @AppStorage("jobmaxxing.selectedJobID") private var savedJobID = ""
  @AppStorage("jobmaxxing.selectedCompanyID") private var savedCompanyID = ""

  var body: some View {
    Group {
      if selection == .settings {
        SettingsView(
          onBack: { selection = lastPrimarySelection }
        )
      } else {
        NavigationSplitView(columnVisibility: $columnVisibility) {
          SidebarView(selection: $selection)
            .navigationSplitViewColumnWidth(min: 184, ideal: 224, max: 260)
            .toolbar(removing: .sidebarToggle)
        } detail: {
          detailView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackdrop())
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
          ToolbarItem(placement: .navigation) {
            Button {
              columnVisibility = columnVisibility == .all ? .detailOnly : .all
            } label: {
              Image(systemName: "sidebar.left")
            }
            .focusEffectDisabled()
            .accessibilityLabel(columnVisibility == .all ? "Hide Sidebar" : "Show Sidebar")
            .help(columnVisibility == .all ? "Hide Sidebar" : "Show Sidebar")
          }
        }
      }
    }
    .tint(AppTheme.accent)
    .overlay(alignment: .topTrailing) {
      if isProcessingDocumentImport || !documentImportStatus.isEmpty {
        HStack(spacing: 8) {
          if isProcessingDocumentImport {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: documentImportSucceeded ? "checkmark.circle" : "exclamationmark.triangle")
              .foregroundStyle(documentImportSucceeded ? Color.secondary : Color.red)
          }
          Text(isProcessingDocumentImport ? "Importing documents…" : documentImportStatus)
            .font(.caption)
            .lineLimit(3)
          if !isProcessingDocumentImport {
            Button {
              documentImportStatus = ""
            } label: {
              Image(systemName: "xmark")
                .frame(width: 44, height: 44)
            }
            .buttonStyle(LiquidPressButtonStyle())
            .accessibilityLabel("Dismiss import status")
          }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: 420, alignment: .leading)
        .liquidGlassSurface(.strong, cornerRadius: AppTheme.radiusMedium)
        .padding(12)
      }
    }
    .onAppear {
      restoreSavedSelection()
    }
    .onChange(of: selection) { _, nextSelection in
      if nextSelection != .settings {
        lastPrimarySelection = nextSelection
        savedSectionID = nextSelection.rawValue
      }
    }
    .onChange(of: store.selectedJobID) { _, nextID in
      savedJobID = nextID ?? ""
    }
    .onChange(of: store.selectedCompanyID) { _, nextID in
      savedCompanyID = nextID ?? ""
    }
    .onReceive(NotificationCenter.default.publisher(for: .openDocumentImporter)) { _ in
      importingDocuments = true
    }
    .alert(
      item: Binding(
        get: { store.storageAlert },
        set: { _ in store.clearStorageAlert() }
      )
    ) { alert in
      Alert(
        title: Text(alert.title),
        message: Text(alert.message),
        dismissButton: .default(Text("OK")) {
          store.clearStorageAlert()
        }
      )
    }
    .fileImporter(
      isPresented: $importingDocuments,
      allowedContentTypes: DocumentImportTypes.allowed,
      allowsMultipleSelection: true
    ) { result in
      Task { @MainActor in
        isProcessingDocumentImport = true
        documentImportStatus = ""
        documentImportSucceeded = true
        defer { isProcessingDocumentImport = false }
        do {
          let outcome = try await store.importDocuments(from: try result.get())
          documentImportStatus = store.state.documentIndexStatus?.message ?? outcome.summary
          documentImportSucceeded = outcome.failures.isEmpty
            && (store.state.documentIndexStatus?.succeeded ?? true)
          if !outcome.failures.isEmpty {
            store.reportStorageIssue(
              title: "Some documents could not be imported",
              message: outcome.summary
            )
          } else if let indexStatus = store.state.documentIndexStatus, !indexStatus.succeeded {
            store.reportStorageIssue(
              title: "Document imported without search indexing",
              message: indexStatus.message
            )
          }
        } catch {
          documentImportStatus = ""
          documentImportSucceeded = false
          store.reportStorageIssue(
            title: "Could not import documents",
            message: "Jobmaxxing could not copy the selected file into local storage. Check file permissions and try again. Error: \(error.localizedDescription)"
          )
        }
      }
    }
  }

  private func restoreSavedSelection() {
    let launchSection = LaunchRoutePolicy.restoredSection(from: savedSectionID)
    selection = launchSection
    lastPrimarySelection = launchSection
    if savedSectionID != launchSection.rawValue {
      savedSectionID = launchSection.rawValue
    }
    if !savedJobID.isEmpty, store.state.jobs.contains(where: { $0.id == savedJobID }) {
      store.selectedJobID = savedJobID
    }
    if !savedCompanyID.isEmpty, store.companyProfiles.contains(where: { $0.id == savedCompanyID }) {
      store.selectedCompanyID = savedCompanyID
    }
  }

  @ViewBuilder
  private var detailView: some View {
    switch selection {
    case .dashboard:
      DashboardView { jobID in
        store.selectedJobID = jobID
        selection = .applications
      }
    case .profile:
      ProfileView()
    case .chat:
      HermesChatView(draft: $hermesDraft, attachmentIDs: $hermesAttachmentIDs)
    case .applications:
      ApplicationsView(
        openCompany: { companyID in
          store.selectedCompanyID = companyID
          selection = .companies
        },
        intakeDraft: $applicationIntakeDraft,
        noteDrafts: $applicationNoteDrafts
      )
    case .companies:
      CompaniesView(
        workspaceDrafts: $companyDrafts,
        directoryDraft: $companyDirectoryDraft,
        openApplication: { jobID in
          store.selectedJobID = jobID
          selection = .applications
        },
        openContacts: { companyID in
          store.selectedCompanyID = companyID
          contactsCompanyFilterID = companyID
          selection = .contacts
        }
      )
    case .contacts:
      ContactsView(
        workspaceDraft: $contactWorkspaceDraft,
        initialCompanyID: contactsCompanyFilterID,
        openCompany: { companyID in
          store.selectedCompanyID = companyID
          selection = .companies
        }
      )
    case .writing:
      WritingView(draftBuffers: $writingDrafts, freeformDraft: $freeformWritingDraft)
    case .interviews:
      InterviewsView(noteDrafts: $interviewNoteDrafts)
    case .browser:
      BrowserPlanView(drafts: $browserDrafts)
    case .settings:
      SettingsView(onBack: { selection = lastPrimarySelection })
    }
  }
}

enum LaunchRoutePolicy {
  static func restoredSection(from savedSectionID: String) -> AppSection {
    guard let savedSection = AppSection(rawValue: savedSectionID), isRestorable(savedSection) else {
      return .dashboard
    }
    return savedSection
  }

  private static func isRestorable(_ section: AppSection) -> Bool {
    switch section {
    case .dashboard, .profile, .applications, .companies, .contacts, .writing, .interviews:
      true
    case .chat, .browser, .settings:
      false
    }
  }
}
