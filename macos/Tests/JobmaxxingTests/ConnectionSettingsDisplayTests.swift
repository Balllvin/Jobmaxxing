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
    let opencode = connector(id: "opencode", label: "OpenCode", isEnabled: true, isConnected: false)

    XCTAssertTrue(JobmaxxingStore.connectorSetupGuidance(for: openai).contains("OPENAI_API_KEY"))
    XCTAssertTrue(JobmaxxingStore.connectorSetupGuidance(for: xai).contains("XAI_API_KEY"))
    XCTAssertTrue(JobmaxxingStore.connectorSetupGuidance(for: opencode).contains("8787"))
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

  func testForgetCredentialsOnlyAppearsForStoredSensitiveValues() {
    let emptyKeyConnector = connector(
      isEnabled: true,
      isConnected: false,
      fields: [
        ConnectorConfigField(id: "api-key-ref", label: "Key ref", value: "", placeholder: "OPENAI_API_KEY", isSecret: false)
      ]
    )
    let storedTokenConnector = connector(
      isEnabled: true,
      isConnected: false,
      fields: [
        ConnectorConfigField(id: "bot-token-ref", label: "Bot token ref", value: "TELEGRAM_BOT_TOKEN", placeholder: "", isSecret: true)
      ]
    )

    XCTAssertFalse(connectorCanForgetCredentials(emptyKeyConnector))
    XCTAssertTrue(connectorCanForgetCredentials(storedTokenConnector))
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
