import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var selection: AppSection = .dashboard
  @State private var lastPrimarySelection: AppSection = .dashboard
  @State private var importingDocuments = false
  @State private var isSidebarCollapsed = false
  @State private var contactsCompanyFilterID = ""
  @AppStorage("jobmaxxing.selectedSection") private var savedSectionID = AppSection.dashboard.rawValue
  @AppStorage("jobmaxxing.selectedJobID") private var savedJobID = ""
  @AppStorage("jobmaxxing.selectedCompanyID") private var savedCompanyID = ""

  var body: some View {
    Group {
      if selection == .settings {
        SettingsView {
          selection = lastPrimarySelection
        }
      } else {
        HStack(spacing: 0) {
          SidebarView(selection: $selection, isCollapsed: $isSidebarCollapsed)
            .frame(width: isSidebarCollapsed ? 64 : 240)

          Divider()

          detailView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.18), value: isSidebarCollapsed)
      }
    }
    .background(AppTheme.canvas)
    .background(FocusRingSuppressor().allowsHitTesting(false))
    .tint(Color.secondary)
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
      do {
        try store.importDocuments(from: try result.get())
      } catch {
        store.reportStorageIssue(
          title: "Could not import documents",
          message: "Jobmaxxing could not copy the selected file into local storage. Check file permissions and try again. Error: \(error.localizedDescription)"
        )
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
    case .chat:
      HermesChatView()
    case .applications:
      ApplicationsView { companyID in
        store.selectedCompanyID = companyID
        selection = .companies
      }
    case .companies:
      CompaniesView(
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
      ContactsView(initialCompanyID: contactsCompanyFilterID) { companyID in
        store.selectedCompanyID = companyID
        selection = .companies
      }
    case .writing:
      WritingView()
    case .interviews:
      InterviewsView()
    case .browser:
      BrowserPlanView()
    case .settings:
      SettingsView {
        selection = lastPrimarySelection
      }
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
    case .dashboard, .applications, .companies, .contacts, .writing, .interviews:
      true
    case .chat, .browser, .settings:
      false
    }
  }
}
