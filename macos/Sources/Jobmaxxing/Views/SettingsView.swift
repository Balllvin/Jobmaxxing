import SwiftUI

private let modelTierIDs = ["cheap-drafts", "standard-writing", "final-review"]

private func modelTierTitle(for id: String) -> String {
  switch id {
  case "cheap-drafts": "Light"
  case "standard-writing": "Medium"
  case "final-review": "High"
  default: "Model"
  }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
  case account
  case providers
  case runtime
  case connections
  case permissions
  case profile

  var id: String { rawValue }

  var title: String {
    switch self {
    case .account: "Account"
    case .providers: "Models"
    case .runtime: "Runtime"
    case .connections: "Connections"
    case .permissions: "Permissions"
    case .profile: "Profile"
    }
  }

  var systemImage: String {
    switch self {
    case .account: "person.crop.circle"
    case .providers: "cpu"
    case .runtime: "point.3.connected.trianglepath.dotted"
    case .connections: "link"
    case .permissions: "lock.shield"
    case .profile: "person.text.rectangle"
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let onBack: (() -> Void)?
  @State private var selectedPage: SettingsPage = .account
  @State private var focusedConnectorID: String?
  @State private var installerStatus = ""
  @State private var hermesStatus = ""

  init(onBack: (() -> Void)? = nil) {
    self.onBack = onBack
  }

  var body: some View {
    HStack(spacing: 0) {
      SettingsSidebar(selectedPage: $selectedPage, onBack: onBack)
        .frame(width: 220)
        .frame(maxHeight: .infinity, alignment: .top)

      Divider()

      if selectedPage == .connections {
        selectedContent
          .padding(.horizontal, 28)
          .padding(.vertical, 24)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            selectedContent
          }
          .padding(.horizontal, 28)
          .padding(.vertical, 24)
          .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(AppTheme.canvas)
  }

  @ViewBuilder
  private var selectedContent: some View {
    switch selectedPage {
    case .account:
      AccountSettingsPage()
    case .providers:
      ModelProvidersSettingsPage(onOpenProviderConnection: openProviderConnection)
    case .runtime:
      AgentRuntimeSettingsPage(installerStatus: $installerStatus, hermesStatus: $hermesStatus)
    case .connections:
      ConnectionsSettingsPage(focusedConnectorID: $focusedConnectorID)
    case .permissions:
      PermissionsSettingsPage()
    case .profile:
      ProfileSettings()
    }
  }

  private func openProviderConnection(providerID: String) {
    focusedConnectorID = providerID
    selectedPage = .connections
  }
}

private struct SettingsSidebar: View {
  @Binding var selectedPage: SettingsPage
  let onBack: (() -> Void)?
  @State private var hoveringBack = false

  var body: some View {
    VStack(spacing: 0) {
      if let onBack {
        Button(action: onBack) {
          HStack(spacing: 10) {
            Image(systemName: "chevron.left")
              .font(.system(size: 14, weight: .semibold))
              .frame(width: 20)
            Text("Back")
              .font(.system(size: 15, weight: .semibold))
            Spacer()
          }
          .foregroundStyle(Color.primary)
          .padding(.horizontal, 10)
          .frame(height: 38)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(hoveringBack ? AppTheme.hoverFill : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hoveringBack = $0 }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 10)

        Divider()
      }

      ScrollView {
        VStack(spacing: 4) {
          ForEach(SettingsPage.allCases) { page in
            SettingsSidebarButton(
              page: page,
              isSelected: selectedPage == page
            ) {
              selectedPage = page
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
      }
    }
    .background(AppTheme.canvas)
  }
}

private struct SettingsSidebarButton: View {
  let page: SettingsPage
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    HStack(alignment: .center, spacing: 11) {
      Image(systemName: page.systemImage)
        .font(.system(size: 15, weight: .medium))
        .frame(width: 20)
      Text(page.title)
        .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
        .lineLimit(1)
      Spacer(minLength: 0)
    }
    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
    .padding(.horizontal, 10)
    .frame(height: 36)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isHovering && !isSelected ? AppTheme.hoverFill : Color.clear)
    .modifier(SelectedRowSurface(isSelected: isSelected))
    .contentShape(RoundedRectangle(cornerRadius: 6))
    .onTapGesture(perform: action)
    .onHover { isHovering = $0 }
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(page.title)
  }
}

private struct AccountSettingsPage: View {
  @EnvironmentObject private var store: JobmaxxingStore

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SettingsFlatSection(title: "Account") {
        VStack(alignment: .leading, spacing: 4) {
          Text(store.state.profile.name)
            .font(.title3.weight(.semibold))
          Text(accountSubtitle)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      SettingsFlatSection(title: "Local files") {
        DisclosureGroup("Show paths agents use") {
          VStack(alignment: .leading, spacing: 8) {
            SettingsPathRow(label: "Agent layer", value: store.hermesSettings.layerPath)
            SettingsPathRow(label: "Agent checkout", value: store.hermesSettings.installPath)
            Text("Local by default. Agents use this context only after approval.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 6)
        }
      }
    }
  }

  private var accountSubtitle: String {
    if let headline = store.state.profile.headline, !headline.trimmed.isEmpty {
      return headline
    }
    if !store.state.profile.targetRoles.isEmpty {
      return store.state.profile.targetRoles.compactJoined
    }
    return "Profile is ready for local job-search work."
  }
}

private struct ModelProvidersSettingsPage: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let onOpenProviderConnection: (String) -> Void

  private var tierRoutes: [ModelRoute] {
    modelTierIDs.compactMap { id in store.state.modelRoutes.first(where: { $0.id == id }) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Model tiers")
        .font(.title3.weight(.semibold))

      // Column headers for the rails
      HStack(spacing: 12) {
        Text("Tier")
          .frame(width: 100, alignment: .leading)
        Text("Provider")
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Model")
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Effort")
          .frame(width: 120, alignment: .leading)
        Text("Status")
          .frame(width: 56, alignment: .center)
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 14)

      VStack(spacing: 10) {
        ForEach(tierRoutes) { route in
          ModelTierRail(
            route: routeBinding(route),
            connectors: store.integrationConnectors,
            onOpenProviderConnection: onOpenProviderConnection
          )
        }
      }
    }
    .frame(maxWidth: 960, alignment: .topLeading)
  }

  private func routeBinding(_ route: ModelRoute) -> Binding<ModelRoute> {
    Binding(
      get: { store.state.modelRoutes.first(where: { $0.id == route.id }) ?? route },
      set: { store.updateModelRoute($0) }
    )
  }
}

/// One horizontal rail: provider → model → effort for a single difficulty tier.
private struct ModelTierRail: View {
  @Binding var route: ModelRoute
  let connectors: [IntegrationConnector]
  let onOpenProviderConnection: (String) -> Void

  private var currentProvider: ModelProviderChoice {
    ModelCatalog.provider(for: route)
  }

  private var detection: RouteDetection {
    RouteDetector.status(for: route, connectors: connectors)
  }

  private var modelChoices: [ModelChoice] {
    currentProvider.models
  }

  private var reasoningChoices: [ReasoningChoice] {
    ModelCatalog.model(for: route)?.reasoningLevels ?? []
  }

  private var providerID: Binding<String> {
    Binding(
      get: { currentProvider.id },
      set: { nextID in
        guard let provider = ModelCatalog.provider(id: nextID) else { return }
        route.provider = provider.name
        route.baseURL = provider.baseURL
        route.keyReference = provider.keyReference
        if let model = provider.models.first {
          route.model = model.id
          route.reasoningEffort = defaultReasoning(for: model, existing: route.reasoningEffort)
        }
      }
    )
  }

  private var modelID: Binding<String> {
    Binding(
      get: {
        if modelChoices.contains(where: { $0.id == route.model }) {
          return route.model
        }
        return modelChoices.first?.id ?? route.model
      },
      set: { nextID in
        guard let model = currentProvider.models.first(where: { $0.id == nextID }) else { return }
        route.model = model.id
        route.reasoningEffort = defaultReasoning(for: model, existing: route.reasoningEffort)
      }
    )
  }

  private var reasoningID: Binding<String> {
    Binding(
      get: {
        if let effort = route.reasoningEffort, reasoningChoices.contains(where: { $0.id == effort }) {
          return effort
        }
        return reasoningChoices.first?.id ?? ""
      },
      set: { nextID in
        guard reasoningChoices.contains(where: { $0.id == nextID }) else { return }
        route.reasoningEffort = nextID
      }
    )
  }

  private var statusHelp: String {
    switch detection.state {
    case .configured:
      return "\(currentProvider.name) is ready. Press to open Connections."
    case .needsSetup:
      return "\(currentProvider.name) needs setup. Press to connect."
    case .disabled:
      return "\(currentProvider.name) is disabled. Press to open Connections."
    }
  }

  /// Hover copy for this tier only. Facts only. Short sentences.
  private var tierUsageHelp: String {
    switch route.id {
    case "cheap-drafts":
      return "Light handles low-cost work. Jobmaxxing uses it for keyword extraction, short summaries, and first-pass drafts."
    case "standard-writing":
      return "Medium handles ordinary writing. Jobmaxxing uses it for cover letters, screening answers, company research notes, and most contact research."
    case "final-review":
      return "High handles high-stakes work. Jobmaxxing uses it for final application packs, interview stories, claim audits, and Hermes agent replies."
    default:
      return route.purpose
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      HStack(spacing: 5) {
        Text(modelTierTitle(for: route.id))
          .font(.headline)
        Image(systemName: "info.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
          .help(tierUsageHelp)
          .accessibilityLabel("What \(modelTierTitle(for: route.id)) is used for")
          .accessibilityHint(tierUsageHelp)
      }
      .frame(width: 100, alignment: .leading)

      Picker("Provider", selection: providerID) {
        ForEach(ModelCatalog.providers) { provider in
          Text(providerDisplayName(provider)).tag(provider.id)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)

      Picker("Model", selection: modelID) {
        ForEach(modelChoices) { model in
          Text(model.label).tag(model.id)
        }
      }
      .labelsHidden()
      .pickerStyle(.menu)
      .frame(maxWidth: .infinity, alignment: .leading)
      .disabled(modelChoices.isEmpty)

      Group {
        if reasoningChoices.isEmpty {
          Text("—")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          Picker("Effort", selection: reasoningID) {
            ForEach(reasoningChoices) { effort in
              Text(effort.label).tag(effort.id)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .frame(width: 120, alignment: .leading)

      Button {
        onOpenProviderConnection(currentProvider.id)
      } label: {
        Image(systemName: detection.systemImage)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(detection.tint)
          .frame(width: 28, height: 28)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help(statusHelp)
      .accessibilityLabel(detection.title)
      .accessibilityHint("Opens \(currentProvider.name) in Connections")
      .frame(width: 56, alignment: .center)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(AppTheme.panel)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(.separator, lineWidth: 1)
    )
  }

  private func providerDisplayName(_ provider: ModelProviderChoice) -> String {
    let connected = connectors.first(where: { $0.id == provider.id }).map { $0.isEnabled && $0.isConnected } ?? false
    return connected ? provider.name : "\(provider.name) · setup"
  }

  private func defaultReasoning(for model: ModelChoice, existing: String?) -> String? {
    guard !model.reasoningLevels.isEmpty else { return nil }
    if let existing, model.reasoningLevels.contains(where: { $0.id == existing }) {
      return existing
    }
    return model.reasoningLevels.first?.id
  }
}

private struct RouteDetection: Hashable {
  enum State: Hashable {
    case configured
    case needsSetup
    case disabled
  }

  let state: State
  let title: String
  let detail: String

  var tint: Color {
    switch state {
    case .configured: .green
    case .needsSetup: .orange
    case .disabled: .secondary
    }
  }

  var systemImage: String {
    switch state {
    case .configured: "checkmark.circle.fill"
    case .needsSetup: "exclamationmark.circle.fill"
    case .disabled: "pause.circle.fill"
    }
  }
}

private struct DetectionIcon: View {
  let detection: RouteDetection

  var body: some View {
    Image(systemName: detection.systemImage)
      .foregroundStyle(detection.tint)
      .accessibilityLabel(detection.title)
  }
}

private enum RouteDetector {
  static func status(for route: ModelRoute, connectors: [IntegrationConnector]) -> RouteDetection {
    if !route.isEnabled {
      return RouteDetection(
        state: .disabled,
        title: "Disabled",
        detail: "This route is available but not used by Jobmaxxing until enabled."
      )
    }

    let provider = ModelCatalog.provider(for: route)
    guard let connector = connectors.first(where: { $0.id == provider.id }) else {
      return RouteDetection(
        state: .needsSetup,
        title: "Provider not connected",
        detail: "Connect \(provider.name) before this route can be selected or used."
      )
    }

    if !connector.isEnabled {
      return RouteDetection(
        state: .disabled,
        title: "Provider disabled",
        detail: "Enable \(connector.label) in Connections before this route can be used."
      )
    }

    if !connector.isConnected {
      return RouteDetection(
        state: .needsSetup,
        title: "\(connector.label) not connected",
        detail: connectionDetail(for: connector)
      )
    }

    return RouteDetection(
      state: .configured,
      title: "\(connector.label) tested",
      detail: "\(connector.label) passed its local readiness check for \(modelTierTitle(for: route.id))."
    )
  }

  private static func connectionDetail(for connector: IntegrationConnector) -> String {
    JobmaxxingStore.connectorSetupGuidance(for: connector)
  }
}

private struct AgentRuntimeSettingsPage: View {
  @Binding var installerStatus: String
  @Binding var hermesStatus: String

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      CodexConnectionPanel(installerStatus: $installerStatus)
      HermesConnectionPanel(status: $hermesStatus)
    }
  }
}

private struct ConnectionsSettingsPage: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var focusedConnectorID: String?
  @State private var selectedConnectorID = ""

  private var visibleConnectors: [IntegrationConnector] {
    store.integrationConnectors.filter { !($0.isHidden ?? false) }
  }

  private var hiddenConnectors: [IntegrationConnector] {
    store.integrationConnectors.filter { $0.isHidden ?? false }
  }

  private var readyConnectors: [IntegrationConnector] {
    visibleConnectors.filter { connectorState($0) == .ready }
  }

  private var setupConnectors: [IntegrationConnector] {
    visibleConnectors.filter { connectorState($0) == .setupRequired }
  }

  private var offConnectors: [IntegrationConnector] {
    visibleConnectors.filter { connectorState($0) == .off }
  }

  private var orderedVisibleConnectors: [IntegrationConnector] {
    readyConnectors + setupConnectors + offConnectors
  }

  private var firstVisibleConnectorID: String {
    orderedVisibleConnectors.first?.id ?? ""
  }

  private var visibleConnectorSignature: String {
    orderedVisibleConnectors
      .map { connector in
        "\(connector.id):\(connector.isEnabled):\(connector.isConnected):\(connector.isHidden ?? false)"
      }
      .joined(separator: "|")
  }

  private var selectedConnector: IntegrationConnector? {
    visibleConnectors.first(where: { $0.id == selectedConnectorID })
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 12) {
        Text(connectionSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 16) {
            ConnectorGroup(
              state: .ready,
              connectors: readyConnectors,
              selectedConnectorID: selectedConnectorID,
              onSelect: { selectedConnectorID = $0 }
            )
            ConnectorGroup(
              state: .setupRequired,
              connectors: setupConnectors,
              selectedConnectorID: selectedConnectorID,
              onSelect: { selectedConnectorID = $0 }
            )
            ConnectorGroup(
              state: .off,
              connectors: offConnectors,
              selectedConnectorID: selectedConnectorID,
              onSelect: { selectedConnectorID = $0 }
            )
            if !hiddenConnectors.isEmpty {
              HiddenConnectorList(connectors: hiddenConnectors) { connectorID in
                store.setConnectorHidden(id: connectorID, isHidden: false)
                selectedConnectorID = connectorID
              }
            }
          }
          .padding(.trailing, 4)
        }
        .scrollIndicators(.visible)
      }
      .frame(width: 380, alignment: .topLeading)
      .frame(maxHeight: .infinity, alignment: .topLeading)

      if let selectedConnector {
        ConnectorDetailPanel(connector: selectedConnector)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      } else {
        EmptyPanel(title: "No connections", detail: "Add the connectors you use for models, documents, mail, proof, and local context.")
          .frame(maxWidth: .infinity, alignment: .topLeading)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear {
      applyFocusedConnectorIfNeeded()
      reconcileSelection()
    }
    .onChange(of: focusedConnectorID) { _, _ in
      applyFocusedConnectorIfNeeded()
    }
    .onChange(of: visibleConnectorSignature) { _, _ in
      applyFocusedConnectorIfNeeded()
      reconcileSelection()
    }
  }

  private func applyFocusedConnectorIfNeeded() {
    guard let focusedConnectorID, !focusedConnectorID.isEmpty else { return }
    // Unhide if the Models page deep-linked a hidden connector.
    if store.integrationConnectors.first(where: { $0.id == focusedConnectorID })?.isHidden == true {
      store.setConnectorHidden(id: focusedConnectorID, isHidden: false)
    }
    let visibleIDs = Set(visibleConnectors.map(\.id))
    let allIDs = Set(store.integrationConnectors.map(\.id))
    if visibleIDs.contains(focusedConnectorID) || allIDs.contains(focusedConnectorID) {
      selectedConnectorID = focusedConnectorID
    }
  }

  private func reconcileSelection() {
    let visibleIDs = Set(visibleConnectors.map(\.id))
    guard selectedConnectorID.isEmpty || !visibleIDs.contains(selectedConnectorID) else { return }
    selectedConnectorID = firstVisibleConnectorID
  }

  private var connectionSummary: String {
    "\(readyConnectors.count) ready, \(setupConnectors.count) need setup, \(offConnectors.count) off."
  }
}

enum ConnectorDisplayState: CaseIterable, Equatable {
  case ready
  case setupRequired
  case off

  var title: String {
    switch self {
    case .ready: "Ready"
    case .setupRequired: "Set up"
    case .off: "Off"
    }
  }

  var color: Color {
    switch self {
    case .ready: .green
    case .setupRequired: .orange
    case .off: .secondary
    }
  }

  var systemImage: String {
    switch self {
    case .ready: "checkmark.circle.fill"
    case .setupRequired: "exclamationmark.circle.fill"
    case .off: "circle.fill"
    }
  }

  var emptyText: String {
    switch self {
    case .ready: "No connectors are ready yet."
    case .setupRequired: "No connectors need setup."
    case .off: "No connectors are off."
    }
  }
}

func connectorState(_ connector: IntegrationConnector) -> ConnectorDisplayState {
  if !connector.isEnabled {
    return .off
  }
  return connector.isConnected ? .ready : .setupRequired
}

func profileBriefGuidanceText() -> String {
  "Write one useful brief. Include experience, target roles, location or remote constraints, strengths, proof, companies, communication style, working preferences, red flags, and anything Jobmaxxing needs for applications."
}

private struct ConnectorGroup: View {
  let state: ConnectorDisplayState
  let connectors: [IntegrationConnector]
  let selectedConnectorID: String
  let onSelect: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 8) {
        ConnectorStatusGlyph(state: state)
        Text(state.title)
          .font(.caption.weight(.semibold))
        Text("\(connectors.count)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.secondary)

      if connectors.isEmpty {
        Text(state.emptyText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
      } else {
        VStack(spacing: 0) {
          ForEach(connectors) { connector in
            ConnectorRow(
              connector: connector,
              isSelected: selectedConnectorID == connector.id,
              onSelect: { onSelect(connector.id) }
            )
            if connector.id != connectors.last?.id {
              Divider()
            }
          }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(.separator, lineWidth: 1)
        )
      }
    }
  }
}

private struct HiddenConnectorList: View {
  let connectors: [IntegrationConnector]
  let onShow: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Hidden")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6)], alignment: .leading, spacing: 6) {
        ForEach(connectors) { connector in
          Button(connector.label) {
            onShow(connector.id)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }
}

private struct PermissionsSettingsPage: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SettingsFlatSection(title: "Browser permissions") {
        Text("You control protected sites, messages, and final submits.")
          .font(.subheadline)
        Text("Jobmaxxing can prepare browser work. It cannot bypass captchas, hidden pages, login rules, or submit without the policy below.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      SettingsFlatSection(title: "Policy") {
        BrowserPolicyEditor()
      }
    }
  }
}

private struct ProfileSettings: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var linkedInURL = ""
  @State private var memoryKind = "Preference"
  @State private var memoryTitle = ""
  @State private var memoryDetail = ""
  @State private var memorySource = "User note"
  @State private var memoryStrength = 4.0
  @State private var showsStructuredFields = false
  @State private var showsNoteDetails = false
  @State private var showsExperienceEditor = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      SettingsFlatSection(title: "LinkedIn") {
        TextField("Paste your LinkedIn profile URL", text: $linkedInURL)
        HStack {
          Button {
            store.prepareLinkedInImport(sourceURL: linkedInURL)
          } label: {
            Label("Prepare import plan", systemImage: "safari")
          }
          .buttonStyle(.borderedProminent)

          Text("Nothing opens or sends here.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if let plan = store.state.profile.linkedInImportPlan {
          Divider()
          DisclosureGroup(plan.checkpoint) {
            VStack(alignment: .leading, spacing: 10) {
              SettingsGrid(label: "Fields", values: plan.fields)
              SettingsGrid(label: "Blocked", values: plan.blocked)
            }
            .padding(.top, 6)
          }
        }
      }

      SettingsFlatSection(title: "Profile") {
        HStack {
          Spacer()
          ImproveTextControl(
            currentText: store.state.profile.about ?? "",
            context: [
              "Name: \(store.state.profile.name)",
              "Headline: \(store.state.profile.headline ?? "")",
              "Targets: \(store.state.profile.targetRoles.compactJoined)",
              "Locations: \(store.state.profile.locations.compactJoined)",
              "Authorization: \(store.state.profile.workAuthorization)",
              "Compensation: \(store.state.profile.compensationGoal)"
            ].joined(separator: "\n"),
            kind: "about me profile",
            onApply: { value in
              var profile = store.state.profile
              profile.about = value.trimmed.isEmpty ? nil : value
              store.updateProfile(profile)
            }
          )
        }
        TextField("About me", text: optionalProfileStringBinding(\.about), axis: .vertical)
          .lineLimit(5...9)
        if (store.state.profile.about ?? "").trimmed.isEmpty {
          Text(profileBriefGuidance)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        DisclosureGroup("Exact profile fields", isExpanded: $showsStructuredFields) {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(profileSummaryRows, id: \.label) { row in
              LabeledContent(row.label) {
                Text(row.value.trimmed.isEmpty ? "Not set" : row.value)
                  .foregroundStyle(row.value.trimmed.isEmpty ? .secondary : .primary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }

            Divider()

            TextField("Your name", text: profileStringBinding(\.name))
            TextField("One-line positioning", text: optionalProfileStringBinding(\.headline))
            TextField("Target roles, comma-separated", text: stringArrayBinding(\.targetRoles))
            TextField("Target locations, comma-separated", text: stringArrayBinding(\.locations))
            TextField("Work authorization rule", text: profileStringBinding(\.workAuthorization))
            TextField("Compensation rule", text: profileStringBinding(\.compensationGoal))
          }
          .padding(.top, 6)
        }
      }

      SettingsFlatSection(title: "Experience writeups") {
        VStack(alignment: .leading, spacing: 10) {
          Text("CV bullets stay short. Add full project explanations here for applications and interview prep.")
            .font(.caption)
            .foregroundStyle(.secondary)
          ForEach(store.profileExperience) { item in
            ProfileExperienceRow(item: item)
          }
          DisclosureGroup("Add experience or project detail", isExpanded: $showsExperienceEditor) {
            ExperienceEditorForm()
              .padding(.top, 8)
          }
        }
      }

      SettingsFlatSection(title: "Projects and proof") {
        VStack(spacing: 10) {
          ForEach(store.profileProjects) { project in
            ProjectRow(project: project)
          }
        }
      }

      SettingsFlatSection(title: "Skills") {
        SettingsFlowTags(values: store.profileSkills)
      }

      SettingsFlatSection(title: "Saved notes") {
        DisclosureGroup("Add detailed note", isExpanded: $showsNoteDetails) {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              TextField("Type of note", text: $memoryKind)
                .frame(width: 150)
              TextField("Short title", text: $memoryTitle)
            }
            HStack {
              Spacer()
              ImproveTextControl(
                currentText: memoryDetail,
                context: "Kind: \(memoryKind)\nTitle: \(memoryTitle)\nSource: \(memorySource)",
                kind: "profile memory note",
                onApply: { memoryDetail = $0 }
              )
            }
            TextField("Fact, preference, or warning to remember", text: $memoryDetail, axis: .vertical)
              .lineLimit(2...4)
            HStack {
              TextField("Where this came from", text: $memorySource)
              Slider(value: $memoryStrength, in: 1...5, step: 1) {
                Text("Strength")
              } minimumValueLabel: {
                Text("1")
              } maximumValueLabel: {
                Text("5")
              }
              .frame(width: 160)
              Button {
                store.addProfileMemory(
                  kind: memoryKind,
                  title: memoryTitle,
                  detail: memoryDetail,
                  source: memorySource,
                  strength: Int(memoryStrength)
                )
                memoryTitle = ""
                memoryDetail = ""
              } label: {
                Label("Save", systemImage: "plus")
              }
              .buttonStyle(.borderedProminent)
              .disabled(memoryTitle.trimmed.isEmpty || memoryDetail.trimmed.isEmpty)
            }
          }
          .padding(.top, 6)
        }

        Divider()

        VStack(alignment: .leading, spacing: 8) {
          ForEach(store.profileMemory) { memory in
            ProfileMemoryRow(memory: memory)
          }
        }
      }
    }
    .onAppear {
      linkedInURL = store.state.profile.linkedInURL ?? ""
    }
  }

  private var profileBriefGuidance: String {
    profileBriefGuidanceText()
  }

  private var profileSummaryRows: [(label: String, value: String)] {
    let profile = store.state.profile
    return [
      ("Name", profile.name),
      ("Positioning", profile.headline ?? ""),
      ("Targets", profile.targetRoles.compactJoined),
      ("Locations", profile.locations.compactJoined),
      ("Authorization", profile.workAuthorization),
      ("Compensation", profile.compensationGoal)
    ]
  }

  private func profileStringBinding(_ keyPath: WritableKeyPath<CandidateProfile, String>) -> Binding<String> {
    Binding(
      get: { store.state.profile[keyPath: keyPath] },
      set: { value in
        var profile = store.state.profile
        profile[keyPath: keyPath] = value
        store.updateProfile(profile)
      }
    )
  }

  private func optionalProfileStringBinding(_ keyPath: WritableKeyPath<CandidateProfile, String?>) -> Binding<String> {
    Binding(
      get: { store.state.profile[keyPath: keyPath] ?? "" },
      set: { value in
        var profile = store.state.profile
        profile[keyPath: keyPath] = value.trimmed.isEmpty ? nil : value
        store.updateProfile(profile)
      }
    )
  }

  private func stringArrayBinding(_ keyPath: WritableKeyPath<CandidateProfile, [String]>) -> Binding<String> {
    Binding(
      get: { store.state.profile[keyPath: keyPath].joined(separator: ", ") },
      set: { value in
        var profile = store.state.profile
        profile[keyPath: keyPath] = value
          .split(separator: ",")
          .map { String($0).trimmed }
          .filter { !$0.isEmpty }
        store.updateProfile(profile)
      }
    )
  }
}

private struct CodexConnectionPanel: View {
  @Binding var installerStatus: String
  @State private var connected = Self.codexConfigContainsJobmaxxing()
  @State private var isRunning = false
  @State private var installerTask: Task<Void, Never>?

  var body: some View {
    SettingsFlatSection(title: "Codex MCP") {
      HStack(alignment: .top) {
        StatusDot(isOn: connected)
        VStack(alignment: .leading, spacing: 4) {
          Text(connected ? "Configured" : "Not configured")
            .font(.headline)
          Text("Gives Codex local tools for jobs, documents, profile memory, and browser plans.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          if connected {
            refreshStatus()
          } else {
            installerTask = Task {
              await runInstaller()
            }
          }
        } label: {
          Label(connected ? "Refresh status" : "Install MCP", systemImage: connected ? "arrow.clockwise" : "link")
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRunning)
        if connected {
          Button {
            installerTask = Task {
              await runInstaller()
            }
          } label: {
            Label("Reinstall MCP", systemImage: "link")
          }
          .buttonStyle(.bordered)
          .help("Reinstall only if the MCP entry is broken")
          .disabled(isRunning)
        }
        if isRunning {
          Button("Cancel install") {
            installerTask?.cancel()
          }
          .buttonStyle(.bordered)
        }
      }
      if !installerStatus.isEmpty {
        Text(installerStatus)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }
    }
  }

  private func refreshStatus() {
    connected = Self.codexConfigContainsJobmaxxing()
    installerStatus = connected ? "Codex MCP is configured." : "Codex MCP is not configured."
  }

  private func runInstaller() async {
    isRunning = true
    installerStatus = "Running MCP installer..."
    installerStatus = await LocalScriptRunner.runAsync(repoRelativePath: "scripts/install_codex_mcp.sh", timeout: 120).displayText
    connected = Self.codexConfigContainsJobmaxxing()
    isRunning = false
    installerTask = nil
  }

  private static func codexConfigContainsJobmaxxing() -> Bool {
    let configURL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".codex")
      .appendingPathComponent("config.toml")
    guard let content = try? String(contentsOf: configURL, encoding: .utf8) else {
      return false
    }
    return content.contains("[mcp_servers.jobmaxxing]")
  }
}

private struct HermesConnectionPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var status: String
  @State private var isRunning = false
  @State private var hermesTask: Task<Void, Never>?

  var settings: HermesSettings {
    store.hermesSettings
  }

  var highRoute: ModelRoute? {
    store.state.modelRoutes.first(where: { $0.id == settings.defaultModelRouteID })
  }

  var layerInstalled: Bool {
    FileManager.default.fileExists(atPath: "\(settings.layerPath)/jobmaxxing.hermes.json")
      || settings.isLayerInstalled
  }

  var body: some View {
    SettingsFlatSection(title: "Hermes layer") {
      HStack(alignment: .top) {
        StatusDot(isOn: layerInstalled)
        VStack(alignment: .leading, spacing: 5) {
          Text(layerInstalled ? "Installed" : "Not installed")
            .font(.headline)
          if let highRoute {
            Text("High route: \(highRoute.provider) \(highRoute.model)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(settings.updateCommand)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        Spacer()
        HStack(spacing: 8) {
          Button {
            hermesTask = Task {
              await runHermes(["--doctor"])
            }
          } label: {
            Label(layerInstalled ? "Run doctor" : "Check setup", systemImage: "stethoscope")
          }
          .buttonStyle(.borderedProminent)
          .help("Check the Hermes layer before reinstalling")
          .disabled(isRunning)
          Button {
            hermesTask = Task {
              await runHermes([], script: "scripts/hermes_update.sh")
            }
          } label: {
            Label("Update commands", systemImage: "arrow.triangle.2.circlepath")
          }
          .buttonStyle(.bordered)
          .help("Run the official Hermes update, then refresh Jobmaxxing commands")
          .disabled(isRunning)
          Button {
            hermesTask = Task {
              await runHermes(["--install"])
            }
          } label: {
            Label(layerInstalled ? "Reinstall" : "Install", systemImage: "square.and.arrow.down")
          }
          .buttonStyle(.bordered)
          .help(layerInstalled ? "Reinstall only when doctor or update cannot repair the layer" : "Install the Hermes Jobmaxxing layer")
          .disabled(isRunning)
          if isRunning {
            Button("Cancel run") {
              hermesTask?.cancel()
            }
            .buttonStyle(.bordered)
          }
        }
      }

      SettingsPathRow(label: "Agent checkout", value: settings.installPath)
      SettingsPathRow(label: "Layer files", value: settings.layerPath)

      if !status.isEmpty {
        Text(status)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func runHermes(_ arguments: [String], script: String = "scripts/install_hermes_layer.sh") async {
    isRunning = true
    status = "Running \(script)..."
    status = await LocalScriptRunner.runAsync(repoRelativePath: script, arguments: arguments, timeout: 180).displayText
    var next = settings
    next.isLayerInstalled = FileManager.default.fileExists(atPath: "\(next.layerPath)/jobmaxxing.hermes.json")
    store.updateHermesSettings(next)

    if var hermes = store.integrationConnectors.first(where: { $0.id == "hermes" }) {
      hermes.isConnected = next.isLayerInstalled
      store.updateIntegrationConnector(hermes)
    }
    isRunning = false
    hermesTask = nil
  }
}

private struct ConnectorRow: View {
  let connector: IntegrationConnector
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      ConnectorStatusGlyph(state: connectorState(connector))
      VStack(alignment: .leading, spacing: 5) {
        Text(connector.label)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(connectorRowSentence(connector))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 9)
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
    .contentShape(RoundedRectangle(cornerRadius: 6))
    .modifier(SelectedRowSurface(isSelected: isSelected))
    .onTapGesture(perform: onSelect)
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel(connector.label)
  }
}

private struct ConnectorDetailPanel: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let connector: IntegrationConnector

  private var liveConnector: IntegrationConnector {
    store.integrationConnectors.first(where: { $0.id == connector.id }) ?? connector
  }

  private var state: ConnectorDisplayState {
    connectorState(liveConnector)
  }

  private var lastCheck: ConnectorCheckResult? {
    store.lastConnectorCheck(for: liveConnector.id)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text(liveConnector.label)
              .font(.title3.weight(.semibold))
              .lineLimit(1)
            HStack(spacing: 7) {
              ConnectorStatusGlyph(state: state)
              Text(state.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state.color)
            }
          }
          Spacer()
        }

        Text(liveConnector.purpose)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        Text(connectorStateDetail(liveConnector, lastCheck: lastCheck))
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if state == .setupRequired {
          Text(JobmaxxingStore.connectorSetupGuidance(for: liveConnector))
            .font(.caption)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }

        if let lastCheck {
          ConnectorCheckResultBanner(result: lastCheck)
        }

        ConnectorActionButtons(connector: liveConnector)

        if let fields = liveConnector.configFields, !fields.isEmpty {
          Divider()
          VStack(alignment: .leading, spacing: 10) {
            Text(state == .setupRequired ? "Setup" : "Connection fields")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            ForEach(fields) { field in
              ConnectorFieldEditor(connectorID: liveConnector.id, field: field)
            }
          }
        }

        if liveConnector.id == "whatsapp" {
          Divider()
          Text("Search reads WhatsApp contact metadata. Importing a linked thread stores readable message text locally on that contact, plus relationship/style summaries and draft text. Nothing is sent.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Divider()
        Button("Hide from list") {
          store.setConnectorHidden(id: liveConnector.id, isHidden: true)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
      }
      .padding(16)
    }
    .background(AppTheme.panel)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(.separator, lineWidth: 1)
    )
  }
}

private struct ConnectorCheckResultBanner: View {
  let result: ConnectorCheckResult

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Image(systemName: result.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
          .foregroundStyle(result.isConnected ? Color.green : Color.orange)
        Text(result.summary)
          .font(.caption.weight(.semibold))
        Spacer()
        Text(result.checkedAt, style: .time)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Text(result.detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(result.isConnected ? Color.green.opacity(0.08) : Color.secondary.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}

private struct ConnectorActionButtons: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let connector: IntegrationConnector
  @State private var isChecking = false

  private var liveConnector: IntegrationConnector {
    store.integrationConnectors.first(where: { $0.id == connector.id }) ?? connector
  }

  private var state: ConnectorDisplayState {
    connectorState(liveConnector)
  }

  var body: some View {
    HStack(spacing: 8) {
      Button {
        performPrimaryAction()
      } label: {
        if isChecking {
          HStack(spacing: 6) {
            ProgressView()
              .controlSize(.small)
            Text("Checking…")
          }
        } else {
          Text(connectorPrimaryActionTitle(liveConnector))
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isChecking)

      if let secondaryTitle = connectorSecondaryActionTitle(liveConnector) {
        Button(secondaryTitle) {
          turnOff()
        }
        .buttonStyle(.bordered)
        .disabled(isChecking)
      }

      if connectorCanForgetCredentials(liveConnector) {
        Button("Forget saved credentials", role: .destructive) {
          store.disconnectConnector(id: liveConnector.id)
        }
        .buttonStyle(.bordered)
        .disabled(isChecking)
      }
    }
  }

  private func performPrimaryAction() {
    switch state {
    case .ready, .setupRequired:
      runCheck()
    case .off:
      var next = liveConnector
      next.isEnabled = true
      store.updateIntegrationConnector(next)
      runCheck()
    }
  }

  private func turnOff() {
    var next = liveConnector
    next.isEnabled = false
    store.updateIntegrationConnector(next)
    _ = store.refreshIntegrationConnector(id: liveConnector.id)
  }

  private func runCheck() {
    let connectorID = liveConnector.id
    isChecking = true
    Task { @MainActor in
      // Yield so the Checking… label paints before slower probes (OpenCode/Cursor).
      await Task.yield()
      _ = store.refreshIntegrationConnector(id: connectorID)
      isChecking = false
    }
  }
}

func connectorRowSentence(_ connector: IntegrationConnector) -> String {
  connector.purpose
}

func connectorStateDetail(_ connector: IntegrationConnector, lastCheck: ConnectorCheckResult? = nil) -> String {
  if let lastCheck {
    return "Last check: \(lastCheck.summary). \(lastCheck.detail)"
  }
  switch connectorState(connector) {
  case .ready:
    return "Last local check found the needed file, auth, environment variable, or local service."
  case .setupRequired:
    return "Not configured or reachable yet. Finish setup or auth, then press Check setup."
  case .off:
    return "Jobmaxxing will not use or poll this connector."
  }
}

func connectorPrimaryActionTitle(_ connector: IntegrationConnector) -> String {
  switch connectorState(connector) {
  case .ready:
    return "Check connection"
  case .setupRequired:
    return "Check setup"
  case .off:
    return "Activate"
  }
}

func connectorSecondaryActionTitle(_ connector: IntegrationConnector) -> String? {
  switch connectorState(connector) {
  case .ready, .setupRequired:
    return "Turn off"
  case .off:
    return nil
  }
}

func connectorCanForgetCredentials(_ connector: IntegrationConnector) -> Bool {
  (connector.configFields ?? []).contains { field in
    let sensitiveField = field.isSecret || field.id.contains("token") || field.id.contains("key")
    return sensitiveField && !field.value.trimmed.isEmpty
  }
}

private struct ConnectorFieldEditor: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let connectorID: String
  let field: ConnectorConfigField

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(field.label.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      if field.isSecret {
        SecureField(field.placeholder, text: valueBinding)
          .textFieldStyle(.roundedBorder)
      } else {
        TextField(field.placeholder, text: valueBinding)
          .textFieldStyle(.roundedBorder)
      }
    }
  }

  private var valueBinding: Binding<String> {
    Binding(
      get: {
        store.integrationConnectors
          .first(where: { $0.id == connectorID })?
          .configFields?
          .first(where: { $0.id == field.id })?
          .value ?? field.value
      },
      set: { value in
        store.updateConnectorConfig(connectorID: connectorID, fieldID: field.id, value: value)
      }
    )
  }
}

private struct ConnectorStatusGlyph: View {
  let state: ConnectorDisplayState

  var body: some View {
    Image(systemName: systemImage)
      .foregroundStyle(color)
      .accessibilityLabel(label)
  }

  private var systemImage: String {
    state.systemImage
  }

  private var color: Color {
    state.color
  }

  private var label: String {
    state.title
  }
}

private struct SettingsFlatSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 11) {
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 12)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

private struct SettingsPathRow: View {
  let label: String
  let value: String

  var body: some View {
    LabeledContent(label) {
      Text(value)
        .font(.caption.monospaced())
        .textSelection(.enabled)
    }
  }
}

private struct SettingsGrid: View {
  let label: String
  let values: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      SettingsFlowTags(values: values)
    }
  }
}

private struct SettingsFlowTags: View {
  let values: [String]

  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
      ForEach(values, id: \.self) { value in
        TagText(text: value)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

private struct ProfileExperienceRow: View {
  let item: ProfileExperience

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(item.title)
          .font(.headline)
        Spacer()
        Text(item.period)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      Text([item.organization, item.location].filter { !$0.trimmed.isEmpty }.joined(separator: " - "))
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(item.summary)
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
      CompactList(items: item.bullets)
      if let projects = item.projects, !projects.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(projects) { project in
            VStack(alignment: .leading, spacing: 4) {
              Text(project.name)
                .font(.subheadline.weight(.semibold))
              if !project.summary.trimmed.isEmpty {
                labeledBlock("Summary", project.summary)
              }
              if !project.detail.trimmed.isEmpty {
                labeledBlock("Detail", project.detail)
              }
              if !project.specificSample.trimmed.isEmpty {
                labeledBlock("Specific sample", project.specificSample)
              }
              let tags = project.tools + project.metrics + project.tags
              if !tags.isEmpty {
                SettingsFlowTags(values: Array(tags.prefix(8)))
              }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
          }
        }
        .padding(.top, 4)
      } else {
        Text("No project writeups under this role yet.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if !item.sourceURL.trimmed.isEmpty {
        Text(item.sourceURL)
          .font(.caption.monospaced())
          .foregroundStyle(.blue)
          .textSelection(.enabled)
      }
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func labeledBlock(_ label: String, _ value: String) -> some View {
    Text("\(label): \(value)")
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

private struct ExperienceEditorForm: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @State private var title = ""
  @State private var organization = ""
  @State private var location = ""
  @State private var period = ""
  @State private var summary = ""
  @State private var bullets = ""
  @State private var projectName = ""
  @State private var projectSummary = ""
  @State private var projectDetail = ""
  @State private var projectSample = ""
  @State private var projectTools = ""
  @State private var projectMetrics = ""
  @State private var projectTags = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        TextField("Role title", text: $title)
        TextField("Organization / company", text: $organization)
      }
      HStack {
        TextField("Location", text: $location)
        TextField("Period", text: $period)
      }
      improveableField("role overview", text: $summary, context: experienceContext) {
        TextField("Broad overview of this role", text: $summary, axis: .vertical)
          .lineLimit(2...4)
      }
      improveableField("cv bullets", text: $bullets, context: experienceContext) {
        TextField("CV bullets, comma-separated", text: $bullets, axis: .vertical)
          .lineLimit(2...3)
      }
      Text("Optional project under this role")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      TextField("Project name", text: $projectName)
      improveableField("project summary", text: $projectSummary, context: experienceContext) {
        TextField("Project summary (CV-level)", text: $projectSummary, axis: .vertical)
          .lineLimit(2...3)
      }
      improveableField("project detail", text: $projectDetail, context: experienceContext) {
        TextField("Project detail (full writeup)", text: $projectDetail, axis: .vertical)
          .lineLimit(3...6)
      }
      improveableField("project sample", text: $projectSample, context: experienceContext) {
        TextField("Specific sample (one concrete walkthrough)", text: $projectSample, axis: .vertical)
          .lineLimit(2...4)
      }
      HStack {
        TextField("Tools", text: $projectTools)
        TextField("Metrics", text: $projectMetrics)
        TextField("Tags", text: $projectTags)
      }
      Button {
        saveExperience()
      } label: {
        Label("Save experience writeup", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
      .disabled(title.trimmed.isEmpty || organization.trimmed.isEmpty)
    }
  }

  private var experienceContext: String {
    [
      "Role: \(title)",
      "Organization: \(organization)",
      "Location: \(location)",
      "Period: \(period)",
      "Summary: \(summary)",
      "Project: \(projectName)",
      "Project summary: \(projectSummary)"
    ].joined(separator: "\n")
  }

  @ViewBuilder
  private func improveableField<Content: View>(
    _ kind: String,
    text: Binding<String>,
    context: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Spacer()
        ImproveTextControl(
          currentText: text.wrappedValue,
          context: context,
          kind: kind,
          onApply: { text.wrappedValue = $0 }
        )
      }
      content()
    }
  }

  private func saveExperience() {
    var profile = store.state.profile
    var experience = profile.experience ?? store.profileExperience
    let splitList: (String) -> [String] = { value in
      value
        .split(whereSeparator: { $0 == "," || $0.isNewline })
        .map { String($0).trimmed }
        .filter { !$0.isEmpty }
    }
    let project: ProfileExperienceProject? = {
      guard !projectName.trimmed.isEmpty else { return nil }
      return ProfileExperienceProject(
        id: "proj-\(UUID().uuidString.lowercased())",
        name: projectName.trimmed,
        summary: projectSummary.trimmed,
        detail: projectDetail.trimmed,
        specificSample: projectSample.trimmed,
        tools: splitList(projectTools),
        metrics: splitList(projectMetrics),
        tags: splitList(projectTags),
        sourceURL: ""
      )
    }()
    if let index = experience.firstIndex(where: {
      $0.organization.caseInsensitiveCompare(organization.trimmed) == .orderedSame &&
        $0.title.caseInsensitiveCompare(title.trimmed) == .orderedSame
    }) {
      var current = experience[index]
      if !location.trimmed.isEmpty { current.location = location.trimmed }
      if !period.trimmed.isEmpty { current.period = period.trimmed }
      if !summary.trimmed.isEmpty { current.summary = summary.trimmed }
      let nextBullets = splitList(bullets)
      if !nextBullets.isEmpty { current.bullets = nextBullets }
      if let project {
        current.projects = [project] + (current.projects ?? [])
      }
      experience[index] = current
    } else {
      experience.insert(
        ProfileExperience(
          id: "exp-\(UUID().uuidString.lowercased())",
          title: title.trimmed,
          organization: organization.trimmed,
          location: location.trimmed,
          period: period.trimmed,
          summary: summary.trimmed,
          bullets: splitList(bullets),
          sourceURL: "",
          projects: project.map { [$0] }
        ),
        at: 0
      )
    }
    profile.experience = experience
    store.updateProfile(profile)
    title = ""
    organization = ""
    location = ""
    period = ""
    summary = ""
    bullets = ""
    projectName = ""
    projectSummary = ""
    projectDetail = ""
    projectSample = ""
    projectTools = ""
    projectMetrics = ""
    projectTags = ""
  }
}

private struct ProjectRow: View {
  let project: ProfileProject

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(project.name)
          .font(.headline)
        Spacer()
        Text(project.url)
          .font(.caption.monospaced())
          .foregroundStyle(.blue)
          .textSelection(.enabled)
      }
      Text(project.summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      SettingsFlowTags(values: project.tags)
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct ProfileMemoryRow: View {
  let memory: ProfileMemory

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(memory.kind)
        .font(.caption.weight(.bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 4))
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(memory.title)
            .font(.headline)
          Spacer()
          Text("S\(memory.strength)")
            .font(.caption.monospaced().weight(.bold))
            .foregroundStyle(.secondary)
        }
        Text(memory.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text(memory.source)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
