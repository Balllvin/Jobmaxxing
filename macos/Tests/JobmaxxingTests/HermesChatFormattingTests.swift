import XCTest
@testable import Jobmaxxing

@MainActor
final class HermesChatFormattingTests: XCTestCase {
  func testCommandDisplayTitleUsesReadableRouteName() {
    XCTAssertEqual(JobmaxxingStore.displayTitle(forHermesCommandID: "goal"), "Goal")
    XCTAssertEqual(JobmaxxingStore.displayTitle(forHermesCommandID: "plugins"), "Connections")
    XCTAssertEqual(JobmaxxingStore.displayTitle(forHermesCommandID: "company-research"), "Company Research")
  }

  func testVisibleUserTextKeepsSlashCommandInline() {
    let text = JobmaxxingStore.visibleHermesUserText(
      "/goal find 10 Zurich AI jobs",
      commandID: "goal",
      attachments: []
    )

    XCTAssertEqual(text, "/goal find 10 Zurich AI jobs")
  }

  func testVisibleUserTextShowsCommandOnlyTurnsAsReadableTag() {
    let text = JobmaxxingStore.visibleHermesUserText(
      "",
      commandID: "goal",
      attachments: []
    )

    XCTAssertEqual(text, "Goal")
  }

  func testVisibleUserTextKeepsTypedTextForSelectedRoute() {
    let text = JobmaxxingStore.visibleHermesUserText(
      "link across devices",
      commandID: "goal",
      attachments: []
    )

    XCTAssertEqual(text, "link across devices")
  }

  func testVisibleUserTextKeepsSlashOnlyCommandAsTag() {
    let text = JobmaxxingStore.visibleHermesUserText(
      "/goal",
      commandID: "goal",
      attachments: []
    )

    XCTAssertEqual(text, "/goal")
  }

  func testVisibleUserTextKeepsCommittedSkillAndPluginNames() {
    let text = JobmaxxingStore.visibleHermesUserText(
      "use Company and Document to build a profile",
      commandID: "company",
      attachments: []
    )

    XCTAssertEqual(text, "use Company and Document to build a profile")
  }

  func testHermesCommandParserFindsSplitTriggerTags() {
    let commandIDs = JobmaxxingStore.hermesCommandIDs(from: "use $company with @gmail after /goal")

    XCTAssertEqual(commandIDs, ["company", "gmail", "goal"])
  }

  func testUnknownSlashCommandPassesThroughForDynamicHermesSkills() {
    XCTAssertEqual(HermesNativeCommandCatalog.commandID(from: "/jobmaxxing-orchestrator review ExampleCo"), "jobmaxxing-orchestrator")
    XCTAssertEqual(
      HermesNativeCommandCatalog.commandText(
        commandID: "jobmaxxing-orchestrator",
        rawText: "/jobmaxxing-orchestrator review ExampleCo",
        visibleText: "/jobmaxxing-orchestrator review ExampleCo"
      ),
      "/jobmaxxing-orchestrator review ExampleCo"
    )
  }

  func testHermesCommandParserFindsCommittedVisibleTags() {
    let commandIDs = JobmaxxingStore.hermesCommandIDs(from: "use Company and Document to build a profile")

    XCTAssertEqual(commandIDs, ["company", "document"])
  }

  func testTranscriptRepairRestoresMissingUserTurnBeforeAssistantCommandResponse() {
    let assistant = HermesChatMessage(
      id: "assistant-1",
      role: "assistant",
      text: "Source roles, save evidence, draft packs, prepare interviews, then validate.",
      status: "complete",
      commandID: "goal",
      traces: [
        HermesTraceStep(id: "trace-1", label: "Set goal", status: "complete", toolName: "jobmaxxing_command", detail: "Find local roles")
      ],
      attachments: []
    )

    let repaired = JobmaxxingStore.repairedHermesTranscript([assistant])

    XCTAssertEqual(repaired.count, 2)
    XCTAssertEqual(repaired[0].role, "user")
    XCTAssertEqual(repaired[0].text, "Goal")
    XCTAssertEqual(repaired[0].commandID, "goal")
    XCTAssertEqual(repaired[1].id, "assistant-1")
  }

  func testMarkdownParserRecognizesCommonChatBlocks() {
    let blocks = HermesMarkdownParser.blocks(in: """
    ## Briefing
    - First point
    1. Ordered point
    > quoted source

    | System | Note |
    | --- | --- |
    | SAP | ERP |

    ```swift
    let value = 1
    ```
    """)

    XCTAssertEqual(blocks.map(\.kind), [
      .heading(level: 2, "Briefing"),
      .bullet("First point"),
      .numbered(marker: "1.", "Ordered point"),
      .quote("quoted source"),
      .table(headers: ["System", "Note"], rows: [["SAP", "ERP"]]),
      .code("let value = 1")
    ])
  }

  func testMarkdownParserKeepsPlainMessagesReadable() {
    let blocks = HermesMarkdownParser.blocks(in: "Plain **markdown** response.")

    XCTAssertEqual(blocks.map(\.kind), [
      .paragraph("Plain **markdown** response.")
    ])
  }

  func testPersistentHermesSessionCommandsAreNotDisposableNativeCommands() {
    XCTAssertTrue(HermesNativeCommandCatalog.requiresPersistentSession("queue"))
    XCTAssertTrue(HermesNativeCommandCatalog.requiresPersistentSession("yolo"))
    XCTAssertTrue(HermesNativeCommandCatalog.requiresPersistentSession("copy"))
    XCTAssertFalse(HermesNativeCommandCatalog.requiresPersistentSession("status"))
  }

  func testNativeComposerLoadsCurrentHermesCommands() {
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "codex-runtime"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "timestamps"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "memory"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "bundles"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "pet"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "hatch"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "learn"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "suggestions"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "blueprint"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "credits"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "billing"))
    XCTAssertNotNil(HermesNativeCommandCatalog.command(id: "version"))
  }

  func testTypedHermesSlashCommandsPassThroughExactly() {
    XCTAssertEqual(HermesNativeCommandCatalog.commandID(from: "/version"), "version")
    XCTAssertEqual(
      HermesNativeCommandCatalog.commandText(commandID: "version", rawText: "/version", visibleText: "/version"),
      "/version"
    )

    XCTAssertEqual(HermesNativeCommandCatalog.commandID(from: "/codex_runtime auto"), "codex-runtime")
    XCTAssertEqual(
      HermesNativeCommandCatalog.commandText(
        commandID: "codex-runtime",
        rawText: "/codex_runtime auto",
        visibleText: "/codex_runtime auto"
      ),
      "/codex_runtime auto"
    )
  }

  func testUnknownSlashCommandsArePassedToHermesInsteadOfBlocked() {
    XCTAssertEqual(HermesNativeCommandCatalog.commandID(from: "/future-command alpha beta"), "future-command")
    XCTAssertEqual(
      HermesNativeCommandCatalog.commandText(
        commandID: "future-command",
        rawText: "/future-command alpha beta",
        visibleText: "/future-command alpha beta"
      ),
      "/future-command alpha beta"
    )
  }

  func testGatewayOnlyCommandsStillResolveWhenTyped() {
    XCTAssertEqual(HermesNativeCommandCatalog.commandID(from: "/topic help"), "topic")
    XCTAssertEqual(
      HermesNativeCommandCatalog.commandText(commandID: "topic", rawText: "/topic help", visibleText: "/topic help"),
      "/topic help"
    )
  }

  func testMultilineSlashCommandsKeepTheTypedPayload() {
    let text = """
    /goal draft
    Find roles in Zurich.
    Keep claims traceable.
    """

    XCTAssertEqual(HermesNativeCommandCatalog.commandID(from: text), "goal")
    XCTAssertEqual(HermesNativeCommandCatalog.commandText(commandID: "goal", rawText: text, visibleText: text), text)
  }

  func testHermesSlashOutputCleanerRemovesCliFrameNoise() {
    let output = """
    Hermes Agent v1
    ❯ /status
    Session: abc
    Available Tools
    Final **answer**
    /quit
    Goodbye
    """

    XCTAssertEqual(
      HermesHighAgentRunner.usefulSlashOutput(output, commandText: "/status"),
      "Final **answer**"
    )
  }

  func testLegacyYoloSuccessIsRepairedAsBlockedSessionCommand() {
    let cleaned = JobmaxxingStore.cleanedLegacyHermesCommandText(
      "YOLO mode ON - all commands auto-approved. Use with caution.",
      commandID: "yolo"
    )

    XCTAssertTrue(cleaned.contains("/yolo needs a live Hermes session"))
    XCTAssertTrue(cleaned.contains("did not run it as prompt text"))
  }

  func testTranscriptPresentationHidesMaintenanceRowsFromDefaultChat() {
    let messages = [
      hermesMessage(id: "update-user", role: "user", text: "Update", commandID: "update"),
      hermesMessage(
        id: "update-assistant",
        role: "assistant",
        text: "Checking Hermes checkout state: ~/.hermes/hermes-agent",
        commandID: "update",
        traces: [
          HermesTraceStep(
            id: "trace-update",
            label: "Terminal",
            status: "complete",
            toolName: "scripts/hermes_update.sh",
            detail: "Timed out running git status --porcelain"
          )
        ]
      ),
      hermesMessage(id: "exampleco-user", role: "user", text: "I interviewed at ExampleCo with Example Contact."),
      hermesMessage(
        id: "exampleco-assistant",
        role: "assistant",
        text: "Done. I saved the debrief into ~/Library/Application Support/Jobmaxxing/jobmaxxing.json."
      ),
      hermesMessage(id: "status-user", role: "user", text: "Status", commandID: "status")
    ]

    let sections = HermesTranscriptPresentation.sections(for: messages)

    XCTAssertEqual(sections.visibleMessages.map(\.id), ["exampleco-user", "exampleco-assistant"])
    XCTAssertEqual(sections.diagnosticMessages.map(\.id), ["update-user", "update-assistant", "status-user"])
    XCTAssertEqual(
      HermesTranscriptPresentation.latestSummary(from: sections.latestUsefulAssistant),
      "Done. I saved the debrief into the local Jobmaxxing data file."
    )
  }

  func testTranscriptPresentationCollapsesLongUserDictation() {
    let longText = String(repeating: "ExampleCo interview detail. ", count: 80)
    let message = hermesMessage(id: "long-user", role: "user", text: longText)

    XCTAssertTrue(
      HermesTranscriptPresentation.shouldCollapseDefaultText(
        for: message,
        displayText: longText,
        showsDiagnosticContent: false
      )
    )
    XCTAssertFalse(
      HermesTranscriptPresentation.shouldCollapseDefaultText(
        for: message,
        displayText: longText,
        showsDiagnosticContent: true
      )
    )
    XCTAssertLessThan(HermesTranscriptPresentation.preview(longText).count, longText.count)
  }

  func testTranscriptPresentationHidesVerificationTailFromDefaultMessage() {
    let message = hermesMessage(
      id: "assistant",
      role: "assistant",
      text: """
      Done. I saved the ExampleCo debrief into ~/Library/Application Support/Jobmaxxing/jobmaxxing.json.
      Verification:
      - Ran npm run test; one unrelated failure from ~/.hermes/Hermes Agent.
      """
    )

    XCTAssertEqual(
      HermesTranscriptPresentation.displayText(for: message, showsDiagnosticContent: false),
      "Done. I saved the ExampleCo debrief into the local Jobmaxxing data file."
    )
    XCTAssertTrue(HermesTranscriptPresentation.hiddenDefaultDetails(for: message)?.contains("npm run test") ?? false)
    XCTAssertTrue(HermesTranscriptPresentation.hiddenDefaultDetails(for: message)?.contains("~/.hermes") ?? false)
  }

  private func hermesMessage(
    id: String,
    role: String,
    text: String,
    commandID: String? = nil,
    traces: [HermesTraceStep] = []
  ) -> HermesChatMessage {
    HermesChatMessage(
      id: id,
      role: role,
      text: text,
      status: "complete",
      commandID: commandID,
      traces: traces,
      attachments: []
    )
  }
}
