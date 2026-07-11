import XCTest
@testable import Jobmaxxing

final class ConnectionSettingsDisplayTests: XCTestCase {
  func testReadyConnectorUsesHumanReadyLanguage() {
    let connector = connector(isEnabled: true, isConnected: true)

    XCTAssertEqual(connectorState(connector), .ready)
    XCTAssertEqual(connectorState(connector).title, "Ready")
    XCTAssertEqual(connectorPrimaryActionTitle(connector), "Check connection")
    XCTAssertEqual(connectorSecondaryActionTitle(connector), "Turn off")
    XCTAssertEqual(connectorRowSentence(connector), "Medium and High model routes.")
  }

  func testSetupConnectorUsesHonestConfigurationLanguage() {
    let connector = connector(isEnabled: true, isConnected: false)
    let detail = connectorStateDetail(connector)

    XCTAssertEqual(connectorState(connector), .setupRequired)
    XCTAssertEqual(connectorState(connector).title, "Set up")
    XCTAssertEqual(connectorPrimaryActionTitle(connector), "Check setup")
    XCTAssertTrue(detail.contains("Not configured or reachable yet"))
    XCTAssertTrue(detail.contains("Finish setup or auth"))
    XCTAssertTrue(detail.contains("Check setup"))
    XCTAssertFalse(detail.contains("Enabled, but Jobmaxxing cannot prove it is usable yet"))
    XCTAssertFalse(detail.contains("press Test"))
  }

  func testConnectorStateDetailPrefersLastCheckResult() {
    let connector = connector(isEnabled: true, isConnected: false)
    let lastCheck = ConnectorCheckResult(
      connectorID: connector.id,
      isConnected: false,
      summary: "Still needs setup",
      detail: "Set OPENAI_API_KEY, then press Check setup again.",
      checkedAt: Date()
    )

    let detail = connectorStateDetail(connector, lastCheck: lastCheck)

    XCTAssertTrue(detail.contains("Last check: Still needs setup"))
    XCTAssertTrue(detail.contains("Set OPENAI_API_KEY"))
  }

  func testSetupGuidanceCoversCoreModelConnectors() {
    let openai = connector(id: "openai", label: "OpenAI", isEnabled: true, isConnected: false)
    let xai = connector(id: "xai", label: "Grok", isEnabled: true, isConnected: false)
    let go = connector(id: "opencode-go", label: "OpenCode Go", isEnabled: true, isConnected: false)
    let zen = connector(id: "opencode-zen", label: "OpenCode Zen", isEnabled: true, isConnected: false)

    XCTAssertTrue(JobmaxxingStore.connectorSetupGuidance(for: openai).contains("OPENAI_API_KEY"))
    XCTAssertTrue(JobmaxxingStore.connectorSetupGuidance(for: xai).contains("XAI_API_KEY"))
    XCTAssertTrue(JobmaxxingStore.connectorSetupGuidance(for: go).contains("OpenCode Go"))
    XCTAssertTrue(JobmaxxingStore.connectorSetupGuidance(for: zen).contains("OpenCode Zen"))
  }

  func testOpenCodeGoAndZenHaveIndependentCatalogs() {
    let go = try! XCTUnwrap(ModelCatalog.provider(id: "opencode-go"))
    let zen = try! XCTUnwrap(ModelCatalog.provider(id: "opencode-zen"))

    XCTAssertNotEqual(go.id, zen.id)
    XCTAssertTrue(go.models.contains(where: { $0.id == "deepseek-v4-flash" }))
    XCTAssertTrue(go.models.contains(where: { $0.id == "qwen3.7-plus" }))
    XCTAssertTrue(zen.models.contains(where: { $0.id == "gpt-5.5" }))
    XCTAssertTrue(zen.models.contains(where: { $0.id == "claude-opus-4-8" }))
  }

  func testDiscoveredModelRemainsSelectableOutsideFallbackCatalog() {
    let provider = try! XCTUnwrap(ModelCatalog.provider(id: "xai"))
    let inventory = ModelInventory(providerID: "xai", modelIDs: ["grok-future-model"])

    let choices = ModelCatalog.models(for: provider, inventory: inventory, retaining: "grok-future-model")

    XCTAssertTrue(choices.contains(where: { $0.id == "grok-future-model" }))
  }

  func testOpenCodeModelDiscoveryParsesProviderScopedIDs() {
    let output = "opencode-go/deepseek-v4-flash\nopencode-go/kimi-k2.7-code\nopencode/gpt-5.5"

    XCTAssertEqual(
      ModelInventoryService.modelIDs(fromOpenCodeOutput: output, providerID: "opencode-go"),
      ["deepseek-v4-flash", "kimi-k2.7-code"]
    )
  }

  @MainActor
  func testProviderKeyReferencePropagatesToExistingRoute() {
    let stateURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: stateURL.deletingLastPathComponent()) }
    let store = JobmaxxingStore(stateURL: stateURL)
    var route = store.state.modelRoutes.first(where: { $0.id == "standard-writing" })!
    route.provider = "xAI"
    route.model = "grok-4.5"
    route.baseURL = "https://api.x.ai/v1"
    route.keyReference = "XAI_API_KEY"
    store.updateModelRoute(route)

    store.updateConnectorConfig(connectorID: "xai", fieldID: "api-key-ref", value: "XAI_API_KEY")

    XCTAssertEqual(
      store.state.modelRoutes.first(where: { $0.id == "standard-writing" })?.keyReference,
      "XAI_API_KEY"
    )
  }

  func testConnectorAvailabilitySummaryUsesCurrentStateVocabulary() {
    let ready = connector(id: "openai", label: "OpenAI", isEnabled: true, isConnected: true)
    let setup = connector(id: "gmail", label: "Gmail", isEnabled: true, isConnected: false)
    let off = connector(id: "linear", label: "Linear", isEnabled: false, isConnected: false)
    let hidden = connector(id: "notion", label: "Notion", isEnabled: true, isConnected: false, isHidden: true)

    let summary = connectorAvailabilitySummary(for: [setup, hidden, off, ready])

    XCTAssertEqual(summary, "Ready: OpenAI. Set up: Gmail. Off: Linear.")
    XCTAssertFalse(summary.contains("Available"))
    XCTAssertFalse(summary.contains("Needs setup"))
    XCTAssertFalse(summary.contains("Notion"))
  }

  func testStatusDotAccessibilityUsesCurrentStateVocabulary() {
    XCTAssertEqual(StatusDot(isOn: true).stateLabel, "Ready")
    XCTAssertEqual(StatusDot(isOn: false).stateLabel, "Set up")
  }

  func testOffConnectorUsesActivateAsOnlyPrimaryAction() {
    let connector = connector(isEnabled: false, isConnected: false)

    XCTAssertEqual(connectorState(connector), .off)
    XCTAssertEqual(connectorState(connector).title, "Off")
    XCTAssertEqual(connectorPrimaryActionTitle(connector), "Activate")
    XCTAssertNil(connectorSecondaryActionTitle(connector))
  }

  func testDefaultConnectorsIncludeGrokAsModelProvider() {
    let connectors = JobmaxxingStore.defaultIntegrationConnectors
    let grok = connectors.first { $0.id == "xai" }

    XCTAssertEqual(grok?.label, "Grok")
    XCTAssertEqual(grok?.provider, "xAI")
    XCTAssertEqual(grok?.category, "Models")
    XCTAssertTrue(grok?.isEnabled == true)

    let provider = ModelCatalog.provider(id: "xai")
    XCTAssertEqual(provider?.name, "xAI")
    XCTAssertTrue(provider?.models.contains(where: { $0.id == "grok-4.5" }) == true)
    XCTAssertTrue(provider?.aliases.contains("grok") == true)
  }

  func testModelProviderKeyReferencesAreSensitiveFields() {
    let providerIDs = ["openai", "xai", "opencode-go", "opencode-zen", "cursor"]
    for providerID in providerIDs {
      let connector = JobmaxxingStore.defaultIntegrationConnectors.first { $0.id == providerID }
      let keyField = connector?.configFields?.first { $0.id == "api-key-ref" }
      XCTAssertTrue(keyField?.isSecret == true, "\(providerID) must reject raw credentials")
    }
  }

  @MainActor
  func testRawModelProviderCredentialIsRejectedWithoutPersistence() {
    let stateURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: stateURL.deletingLastPathComponent()) }
    let store = JobmaxxingStore(stateURL: stateURL)

    XCTAssertFalse(store.updateConnectorConfig(connectorID: "xai", fieldID: "api-key-ref", value: "raw-secret-value"))
    XCTAssertFalse(store.updateConnectorConfig(
      connectorID: "xai",
      fieldID: "api-key-ref",
      value: "ghp_abcdefghijklmnopqrstuvwxyz1234567890"
    ))
    let savedValue = store.integrationConnectors
      .first(where: { $0.id == "xai" })?
      .configFields?
      .first(where: { $0.id == "api-key-ref" })?
      .value
    XCTAssertEqual(savedValue, "")
    XCTAssertEqual(store.lastConnectorCheck(for: "xai")?.summary, "Use an environment variable reference")

    var route = store.state.modelRoutes.first(where: { $0.id == "standard-writing" })!
    route.provider = "xAI"
    route.model = "grok-4.5"
    route.baseURL = "https://api.x.ai/v1"
    route.keyReference = "ghp_abcdefghijklmnopqrstuvwxyz1234567890"
    XCTAssertFalse(store.updateModelRoute(route))
  }

  @MainActor
  func testForgetCredentialsClearsConnectorRouteAndTelegramCopies() {
    let stateURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: stateURL.deletingLastPathComponent()) }
    let store = JobmaxxingStore(stateURL: stateURL)

    var route = store.state.modelRoutes.first(where: { $0.id == "standard-writing" })!
    route.provider = "xAI"
    route.model = "grok-4.5"
    route.baseURL = "https://api.x.ai/v1"
    route.keyReference = "XAI_API_KEY"
    XCTAssertTrue(store.updateModelRoute(route))
    XCTAssertTrue(store.updateConnectorConfig(connectorID: "xai", fieldID: "api-key-ref", value: "XAI_API_KEY"))
    XCTAssertTrue(store.hasSavedCredentialReference(for: "xai"))
    store.disconnectConnector(id: "xai")
    XCTAssertTrue(store.state.modelRoutes
      .filter { ModelCatalog.provider(for: $0).id == "xai" }
      .allSatisfy { $0.keyReference.isEmpty })
    XCTAssertFalse(store.hasSavedCredentialReference(for: "xai"))

    XCTAssertTrue(store.updateConnectorConfig(
      connectorID: "telegram",
      fieldID: "bot-token-ref",
      value: "TELEGRAM_BOT_TOKEN"
    ))
    XCTAssertEqual(store.hermesChatState.settings.telegramBotTokenReference, "TELEGRAM_BOT_TOKEN")
    XCTAssertTrue(store.hasSavedCredentialReference(for: "telegram"))
    store.disconnectConnector(id: "telegram")
    XCTAssertEqual(store.hermesChatState.settings.telegramBotTokenReference, "")
    XCTAssertEqual(
      store.integrationConnectors
        .first(where: { $0.id == "telegram" })?
        .configFields?
        .first(where: { $0.id == "bot-token-ref" })?
        .value,
      ""
    )
    XCTAssertFalse(store.hasSavedCredentialReference(for: "telegram"))
  }

  @MainActor
  func testLegacyTelegramSettingsCannotRepopulateRawCredential() {
    let stateURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("state.json")
    defer { try? FileManager.default.removeItem(at: stateURL.deletingLastPathComponent()) }
    let store = JobmaxxingStore(stateURL: stateURL)
    var settings = store.hermesChatState.settings
    settings.telegramBotTokenReference = "ghp_abcdefghijklmnopqrstuvwxyz1234567890"

    XCTAssertFalse(store.updateHermesChatSettings(settings))
    XCTAssertNotEqual(
      store.integrationConnectors
        .first(where: { $0.id == "telegram" })?
        .configFields?
        .first(where: { $0.id == "bot-token-ref" })?
        .value,
      settings.telegramBotTokenReference
    )
  }

  func testGrokProviderMatchesCommonRouteAliases() {
    let route = ModelRoute(
      id: "standard-writing",
      label: "Medium",
      provider: "Grok",
      model: "grok-4.5",
      reasoningEffort: "medium",
      purpose: "Grok writing route.",
      baseURL: "https://api.x.ai/v1",
      keyReference: "XAI_API_KEY",
      isEnabled: true,
      isConnected: false
    )

    let provider = ModelCatalog.provider(for: route)
    XCTAssertEqual(provider.id, "xai")
    XCTAssertEqual(ModelCatalog.model(for: route)?.id, "grok-4.5")
  }

  private func connector(
    id: String = "openai",
    label: String = "OpenAI",
    isEnabled: Bool,
    isConnected: Bool,
    fields: [ConnectorConfigField]? = nil,
    isHidden: Bool? = nil
  ) -> IntegrationConnector {
    IntegrationConnector(
      id: id,
      label: label,
      provider: label,
      purpose: "Medium and High model routes.",
      isEnabled: isEnabled,
      isConnected: isConnected,
      category: "Models",
      capabilities: ["Medium", "High"],
      configFields: fields,
      isHidden: isHidden
    )
  }
}
