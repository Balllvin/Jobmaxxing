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
  case setup
  case codeHelp
  case providers
  case runtime
  case connections
  case permissions

  var id: String { rawValue }

  var title: String {
    switch self {
    case .setup: "Setup"
    case .codeHelp: "Code Help"
    case .providers: "Models"
    case .runtime: "Runtime"
    case .connections: "Connections"
    case .permissions: "Permissions"
    }
  }

  var systemImage: String {
    switch self {
    case .setup: "list.number"
    case .codeHelp: "questionmark.bubble"
    case .providers: "cpu"
    case .runtime: "point.3.connected.trianglepath.dotted"
    case .connections: "link"
    case .permissions: "lock.shield"
    }
  }
}

struct SettingsView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let onBack: (() -> Void)?
  @State private var selectedPage: SettingsPage = .setup
  @State private var focusedConnectorID: String?
  @State private var installerStatus = ""
  @State private var hermesStatus = ""

  init(onBack: (() -> Void)? = nil) {
    self.onBack = onBack
  }

  var body: some View {
    GeometryReader { proxy in
      if proxy.size.width < 760 {
        VStack(spacing: 0) {
          SettingsCompactHeader(selectedPage: $selectedPage, onBack: onBack)
          Divider()
          detailSurface(compact: true)
        }
      } else {
        HStack(spacing: 0) {
          SettingsSidebar(selectedPage: $selectedPage, onBack: onBack)
            .frame(width: 220)
            .frame(maxHeight: .infinity, alignment: .top)

          Divider()
          detailSurface(compact: false)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(AppBackdrop())
  }

  @ViewBuilder
  private func detailSurface(compact: Bool) -> some View {
    let horizontalPadding: CGFloat = compact ? 16 : 28
    let verticalPadding: CGFloat = compact ? 16 : 24
    if selectedPage == .connections || selectedPage == .codeHelp {
      selectedContent
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          selectedContent
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  @ViewBuilder
  private var selectedContent: some View {
    switch selectedPage {
    case .setup:
      SetupSettingsPage(
        openConnections: { selectedPage = .connections },
        openModels: { selectedPage = .providers },
        openRuntime: { selectedPage = .runtime }
      )
    case .codeHelp:
      CodeHelpSettingsPage()
    case .providers:
      ModelProvidersSettingsPage(onOpenProviderConnection: openProviderConnection)
    case .runtime:
      AgentRuntimeSettingsPage(installerStatus: $installerStatus, hermesStatus: $hermesStatus)
    case .connections:
      ConnectionsSettingsPage(focusedConnectorID: $focusedConnectorID)
    case .permissions:
      PermissionsSettingsPage()
    }
  }

  private func openProviderConnection(providerID: String) {
    focusedConnectorID = providerID
    selectedPage = .connections
  }
}

private struct SettingsCompactHeader: View {
  @Binding var selectedPage: SettingsPage
  let onBack: (() -> Void)?

  var body: some View {
    HStack(spacing: 10) {
      if let onBack {
        Button(action: onBack) {
          Image(systemName: "chevron.left")
            .frame(width: 44, height: 44)
        }
        .buttonStyle(LiquidPressButtonStyle())
        .accessibilityLabel("Back")
      }

      Picker("Settings page", selection: $selectedPage) {
        ForEach(SettingsPage.allCases) { page in
          Label(page.title, systemImage: page.systemImage).tag(page)
        }
      }
      .pickerStyle(.menu)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 52)
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
          .frame(minHeight: 44)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(hoveringBack ? AppTheme.hoverFill : Color.clear)
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(LiquidPressButtonStyle())
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
    .background(.bar)
  }
}

private struct SettingsSidebarButton: View {
  let page: SettingsPage
  let isSelected: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
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
      .frame(minHeight: 44)
      .frame(maxWidth: .infinity, alignment: .leading)
      .modifier(SelectedRowSurface(isSelected: isSelected))
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(LiquidPressButtonStyle())
    .accessibilityLabel(page.title)
    .accessibilityValue(isSelected ? "Selected" : "")
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

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          Text("Tier")
            .frame(width: 100, alignment: .leading)
          Text("Provider")
            .frame(maxWidth: .infinity, alignment: .leading)
          Text("Model")
            .frame(maxWidth: .infinity, alignment: .leading)
          Text("Effort")
            .frame(width: 120, alignment: .leading)
          Text("On")
            .frame(width: 52, alignment: .center)
          Text("Status")
            .frame(width: 56, alignment: .center)
        }
        .frame(minWidth: 760)

        Text("Choose the provider, model, and effort for each workload.")
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 14)

      LiquidGlassContainer(spacing: 10) {
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
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var route: ModelRoute
  let connectors: [IntegrationConnector]
  let onOpenProviderConnection: (String) -> Void
  @State private var isRefreshing = false

  private var currentProvider: ModelProviderChoice {
    ModelCatalog.provider(for: route)
  }

  private var detection: RouteDetection {
    RouteDetector.status(for: route, connectors: connectors)
  }

  private var modelChoices: [ModelChoice] {
    store.modelChoices(for: currentProvider, retaining: route.model)
  }

  private var reasoningChoices: [ReasoningChoice] {
    modelChoices.first(where: { $0.id == route.model })?.reasoningLevels ?? []
  }

  private var selectableProviders: [ModelProviderChoice] {
    let readyIDs = Set(connectors.filter { $0.isEnabled && $0.isConnected }.map(\.id))
    return ModelCatalog.providers.filter { $0.id == currentProvider.id || readyIDs.contains($0.id) }
  }

  private var providerID: Binding<String> {
    Binding(
      get: { currentProvider.id },
      set: { nextID in
        guard let provider = ModelCatalog.provider(id: nextID) else { return }
        route.provider = provider.name
        route.baseURL = provider.baseURL
        route.keyReference = store.modelKeyReference(for: provider)
        if let model = store.modelChoices(for: provider).first {
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
        guard let model = modelChoices.first(where: { $0.id == nextID }) else { return }
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
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 12) {
        tierLabel
          .frame(width: 100, alignment: .leading)
        providerPicker
        modelPicker
        refreshButton
        reasoningControl
          .frame(width: 120, alignment: .leading)
        enableToggle
          .frame(width: 52, alignment: .center)
        statusButton
          .frame(width: 56, alignment: .center)
      }
      .frame(minWidth: 760)

      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          tierLabel
          Spacer(minLength: 8)
          enableToggle
          statusButton
        }
        LabeledContent("Provider") {
          providerPicker
        }
        LabeledContent("Model") {
          HStack(spacing: 6) {
            modelPicker
            refreshButton
          }
        }
        if !reasoningChoices.isEmpty {
          LabeledContent("Effort") {
            reasoningControl
          }
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .liquidGlassSurface(.regular, cornerRadius: AppTheme.radiusMedium, isInteractive: true)
  }

  private var tierLabel: some View {
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
  }

  private var providerPicker: some View {
    Picker("Provider", selection: providerID) {
      ForEach(selectableProviders) { provider in
        Text(providerDisplayName(provider)).tag(provider.id)
      }
    }
    .labelsHidden()
    .pickerStyle(.menu)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var modelPicker: some View {
    Picker("Model", selection: modelID) {
      ForEach(modelChoices) { model in
        Text(model.label).tag(model.id)
      }
    }
    .labelsHidden()
    .pickerStyle(.menu)
    .frame(maxWidth: .infinity, alignment: .leading)
    .disabled(modelChoices.isEmpty)
  }

  private var refreshButton: some View {
    Button {
      guard !isRefreshing else { return }
      isRefreshing = true
      Task { @MainActor in
        await store.refreshModelInventory(for: currentProvider)
        isRefreshing = false
      }
    } label: {
      if isRefreshing {
        ProgressView()
          .controlSize(.small)
          .frame(width: 44, height: 44)
      } else {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 44, height: 44)
      }
    }
    .buttonStyle(LiquidPressButtonStyle())
    .disabled(isRefreshing)
    .help(store.modelInventoryMessage(for: currentProvider.id) ?? "Refresh models from \(currentProvider.name)")
    .accessibilityLabel(isRefreshing ? "Refreshing \(currentProvider.name) models" : "Refresh \(currentProvider.name) models")
  }

  @ViewBuilder
  private var reasoningControl: some View {
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

  private var statusButton: some View {
    Button {
      onOpenProviderConnection(currentProvider.id)
    } label: {
      Image(systemName: detection.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(detection.tint)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(LiquidPressButtonStyle())
    .help(statusHelp)
    .accessibilityLabel(detection.title)
    .accessibilityHint("Opens \(currentProvider.name) in Connections")
  }

  private var enableToggle: some View {
    Toggle("Enable \(modelTierTitle(for: route.id))", isOn: $route.isEnabled)
      .labelsHidden()
      .toggleStyle(.switch)
      .controlSize(.small)
      .help(route.isEnabled ? "Turn off this route" : "Enable this route")
      .accessibilityLabel("Enable \(modelTierTitle(for: route.id)) route")
  }

  private func providerDisplayName(_ provider: ModelProviderChoice) -> String {
    provider.name
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
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: 16) {
        connectorList
          .frame(width: 380, alignment: .topLeading)
        connectorDetail
      }
      .frame(minWidth: 780)

      VStack(alignment: .leading, spacing: 12) {
        connectorList
          .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 260, alignment: .topLeading)
        Divider()
        connectorDetail
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

  private var connectorList: some View {
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
    .frame(maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private var connectorDetail: some View {
    if let selectedConnector {
      ConnectorDetailPanel(connector: selectedConnector)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    } else {
      EmptyPanel(title: "No connections", detail: "Add the connectors you use for models, documents, mail, proof, and local context.")
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }

  private func applyFocusedConnectorIfNeeded() {
    guard let focusedConnectorID, !focusedConnectorID.isEmpty else { return }
    defer { self.focusedConnectorID = nil }
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
        .liquidGlassSurface(.strong, cornerRadius: AppTheme.radiusSmall)
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
    Button(action: onSelect) {
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
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .modifier(SelectedRowSurface(isSelected: isSelected))
    }
    .buttonStyle(LiquidPressButtonStyle())
    .accessibilityLabel(connector.label)
    .accessibilityValue(isSelected ? "Selected" : connectorState(connector).title)
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
    .liquidGlassSurface(.regular, cornerRadius: AppTheme.radiusMedium)
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
  @State private var isConfirmingCredentialForget = false

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

      if store.hasSavedCredentialReference(for: liveConnector.id) {
        Button("Forget saved credentials", role: .destructive) {
          isConfirmingCredentialForget = true
        }
        .buttonStyle(.bordered)
        .disabled(isChecking)
      }
    }
    .confirmationDialog(
      "Forget saved credentials?",
      isPresented: $isConfirmingCredentialForget,
      titleVisibility: .visible
    ) {
      Button("Forget credentials", role: .destructive) {
        store.disconnectConnector(id: liveConnector.id)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Jobmaxxing will remove the locally saved credential reference for \(liveConnector.label). This does not revoke credentials at the provider.")
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
  }

  private func runCheck() {
    let connectorID = liveConnector.id
    isChecking = true
    Task { @MainActor in
      // Yield so the Checking… label paints before slower probes (OpenCode/Cursor).
      await Task.yield()
      _ = await store.refreshIntegrationConnector(id: connectorID)
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

private struct ConnectorFieldEditor: View {
  @EnvironmentObject private var store: JobmaxxingStore
  let connectorID: String
  let field: ConnectorConfigField
  @State private var draftValue = ""
  @State private var isDirty = false
  @State private var status = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(field.label.uppercased())
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        TextField(field.placeholder, text: draftBinding)
          .textFieldStyle(.roundedBorder)
          .onSubmit(save)
        Button("Save") {
          save()
        }
        .buttonStyle(.bordered)
        .disabled(!isDirty)
        .frame(minHeight: 44)
      }
      if isSensitiveField {
        Text("Use the variable name shown, or another environment variable available to this app. Raw tokens and API keys are not saved.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if !status.isEmpty {
        Text(status)
          .font(.caption)
          .foregroundStyle(status.hasPrefix("Saved") ? Color.secondary : Color.red)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .onAppear(perform: loadValue)
    .onChange(of: field.value) { _, _ in
      if !isDirty {
        loadValue()
      }
    }
    .onDisappear {
      if isDirty,
         isValidCredentialReference(draftValue, expectedReference: expectedCredentialReference)
           || !isSensitiveField {
        save()
      }
    }
  }

  private var draftBinding: Binding<String> {
    Binding(
      get: { draftValue },
      set: { value in
        draftValue = value
        isDirty = true
        status = ""
      }
    )
  }

  private func loadValue() {
    let stored = store.integrationConnectors
      .first(where: { $0.id == connectorID })?
      .configFields?
      .first(where: { $0.id == field.id })?
      .value ?? field.value
    if isSensitiveField,
       !isValidCredentialReference(stored, expectedReference: expectedCredentialReference) {
      draftValue = ""
      status = "This saved value is not the expected variable name and is not available in this app's environment. It was not deleted. Replace it, or use Forget credentials."
    } else {
      draftValue = stored
      status = ""
    }
    isDirty = false
  }

  private func save() {
    if isSensitiveField,
       !isValidCredentialReference(draftValue, expectedReference: expectedCredentialReference) {
      let expected = expectedCredentialReference ?? "an available environment variable"
      status = "Use \(expected), or another variable already available to Jobmaxxing. Raw values are rejected."
      return
    }
    if store.updateConnectorConfig(connectorID: connectorID, fieldID: field.id, value: draftValue) {
      isDirty = false
      status = "Saved."
    } else {
      status = "Could not save this field."
    }
  }

  private var isSensitiveField: Bool {
    field.isSecret || field.id.contains("token") || field.id.contains("key")
  }

  private var expectedCredentialReference: String? {
    canonicalCredentialReference(from: field.placeholder)
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
