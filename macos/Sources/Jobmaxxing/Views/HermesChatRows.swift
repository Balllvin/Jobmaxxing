import AppKit
import SwiftUI

struct ChatMessageRow: View {
  let message: HermesChatMessage
  var showsDiagnosticContent = false
  var usesHermesPresentation = true
  let onReply: () -> Void
  let onCopy: () -> Void
  @State private var expandedLongText = false
  @State private var expandedHiddenDetails = false

  private var isUser: Bool {
    message.role.lowercased() == "user"
  }

  private var isRunning: Bool {
    message.status.trimmed.lowercased() == "running"
  }

  private var visibleTraces: [HermesTraceStep] {
    if showsDiagnosticContent {
      return message.traces
    }
    return message.traces.filter { trace in
      let hiddenTools = [
        "reasoning",
        "slash",
        "jobmaxxing_status",
        "jobmaxxing_hermes_status",
        "jobmaxxing_toolset",
        "hermes",
        "hermes chat --cli -q",
        "subagents"
      ]
      let hiddenLabels = [
        "hermes",
        "hermes live session",
        "load local context",
        "live session",
        "prepare reply",
        "select agent toolset",
        "read local state"
      ]
      return !hiddenTools.contains(trace.toolName.trimmed.lowercased())
        && !hiddenLabels.contains(trace.label.trimmed.lowercased())
    }
  }

  private var shouldShowMessageText: Bool {
    !displayText.trimmed.isEmpty
  }

  private var displayText: String {
    guard usesHermesPresentation else { return message.text }
    return HermesTranscriptPresentation.displayText(for: message, showsDiagnosticContent: showsDiagnosticContent)
  }

  private var shouldCollapseText: Bool {
    guard usesHermesPresentation else { return false }
    return HermesTranscriptPresentation.shouldCollapseDefaultText(for: message, displayText: displayText, showsDiagnosticContent: showsDiagnosticContent)
  }

  private var visibleText: String {
    guard shouldCollapseText, !expandedLongText else { return displayText }
    return HermesTranscriptPresentation.preview(displayText)
  }

  private var hiddenDetails: String? {
    guard usesHermesPresentation, !showsDiagnosticContent else { return nil }
    return HermesTranscriptPresentation.hiddenDefaultDetails(for: message)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      if isUser {
        Spacer(minLength: 48)
      }

      VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
        if !isUser && isRunning {
          HStack(spacing: 6) {
            ProgressView()
              .scaleEffect(0.55)
              .frame(width: 14, height: 14)
            Text("Waiting for reply")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        if !isUser && !visibleTraces.isEmpty {
          CompactTraceDisclosure(traces: visibleTraces)
        }

        if shouldShowMessageText {
          MarkdownMessageView(text: visibleText, alignment: isUser ? .trailing : .leading)
            .font(.body)
            .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        }

        if shouldCollapseText {
          Button(expandedLongText ? "Show less" : "Show full message") {
            expandedLongText.toggle()
          }
          .buttonStyle(LiquidPressButtonStyle())
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .help(expandedLongText ? "Collapse message" : "Show full message")
        }

        if let hiddenDetails {
          Button(expandedHiddenDetails ? "Hide verification details" : "Show verification details") {
            expandedHiddenDetails.toggle()
          }
          .buttonStyle(LiquidPressButtonStyle())
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .help(expandedHiddenDetails ? "Hide verification details" : "Show verification details")

          if expandedHiddenDetails {
            MarkdownMessageView(text: hiddenDetails, alignment: isUser ? .trailing : .leading)
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
          }
        }

        if let attachments = message.attachments, !attachments.isEmpty {
          FlowTags(items: attachments.map(\.title))
        }

        if shouldShowMessageText {
          HStack(spacing: 8) {
            Button(action: onReply) {
              Image(systemName: "arrowshape.turn.up.left")
                .frame(width: 44, height: 44)
            }
            .buttonStyle(LiquidPressButtonStyle())
            .accessibilityLabel("Reply")
            .help("Reply")

            Button(action: onCopy) {
              Image(systemName: isUser && message.commandID != nil ? "terminal" : "doc.on.doc")
                .frame(width: 44, height: 44)
            }
            .buttonStyle(LiquidPressButtonStyle())
            .accessibilityLabel(copyButtonLabel)
            .help(copyButtonLabel)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .padding(isUser ? 10 : 0)
      .frame(maxWidth: isUser ? 620 : 760, alignment: isUser ? .trailing : .leading)
      .fixedSize(horizontal: false, vertical: true)
      .background(isUser ? Color.accentColor.opacity(0.09) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .layoutPriority(1)

      if !isUser {
        Spacer(minLength: 48)
      }
    }
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var copyButtonLabel: String {
    isUser && message.commandID != nil ? "Copy command" : "Copy text"
  }
}

struct HermesTranscriptSections {
  let visibleMessages: [HermesChatMessage]
  let diagnosticMessages: [HermesChatMessage]

  var latestUsefulAssistant: HermesChatMessage? {
    visibleMessages.last { message in
      message.role.lowercased() == "assistant" && !message.text.trimmed.isEmpty
    }
  }
}

enum HermesTranscriptPresentation {
  static func sections(for messages: [HermesChatMessage]) -> HermesTranscriptSections {
    var visibleMessages: [HermesChatMessage] = []
    var diagnosticMessages: [HermesChatMessage] = []
    for message in messages {
      if isDiagnostic(message) {
        diagnosticMessages.append(message)
      } else {
        visibleMessages.append(message)
      }
    }
    return HermesTranscriptSections(visibleMessages: visibleMessages, diagnosticMessages: diagnosticMessages)
  }

  static func isDiagnostic(_ message: HermesChatMessage) -> Bool {
    if let commandID = message.commandID?.trimmed.lowercased(),
       diagnosticCommandIDs.contains(commandID) {
      return true
    }
    let text = message.text.trimmed.lowercased()
    if diagnosticTextFragments.contains(where: { text.contains($0) }) {
      return true
    }
    return message.traces.contains(where: isDiagnosticTrace)
  }

  static func displayText(for message: HermesChatMessage, showsDiagnosticContent: Bool) -> String {
    if showsDiagnosticContent {
      return message.text
    }
    return userFacingText(message.text)
  }

  static func hiddenDefaultDetails(for message: HermesChatMessage) -> String? {
    guard let detail = diagnosticTail(in: message.text) else { return nil }
    return detail
  }

  static func latestSummary(from message: HermesChatMessage?) -> String {
    guard let message else {
      return "Ready for company research, applications, contacts, and interview prep."
    }
    return preview(userFacingText(message.text), limit: 190)
  }

  static func shouldCollapseDefaultText(
    for message: HermesChatMessage,
    displayText: String,
    showsDiagnosticContent: Bool
  ) -> Bool {
    !showsDiagnosticContent
      && message.role.lowercased() == "user"
      && displayText.count > longUserMessageLimit
  }

  static func preview(_ text: String, limit: Int = longUserMessagePreviewLimit) -> String {
    let trimmed = text.trimmed
    guard trimmed.count > limit else { return trimmed }
    return String(trimmed.prefix(limit)).trimmed + "..."
  }

  private static func isDiagnosticTrace(_ trace: HermesTraceStep) -> Bool {
    let toolName = trace.toolName.trimmed.lowercased()
    let label = trace.label.trimmed.lowercased()
    let detail = trace.detail.trimmed.lowercased()
    return diagnosticTraceFragments.contains { fragment in
      toolName.contains(fragment) || label.contains(fragment) || detail.contains(fragment)
    }
  }

  private static func userFacingText(_ text: String) -> String {
    var result = textWithoutDiagnosticTail(text)
    result = result.replacingOccurrences(
      of: #"/Users/[^\s,.)\]]*Jobmaxxing/(?:data|Data)/jobmaxxing\.json"#,
      with: "the local Jobmaxxing data file",
      options: .regularExpression
    )
    result = result.replacingOccurrences(
      of: #"/Users/[^\s,.)\]]+"#,
      with: "local file",
      options: .regularExpression
    )
    result = result.replacingOccurrences(of: "browser handoff plans", with: "browser plans", options: .caseInsensitive)
    result = result.replacingOccurrences(of: "browser handoff plan", with: "browser plan", options: .caseInsensitive)
    return result
  }

  private static func textWithoutDiagnosticTail(_ text: String) -> String {
    guard let range = diagnosticTailRange(in: text) else { return text }
    return String(text[..<range.lowerBound]).trimmed
  }

  private static func diagnosticTail(in text: String) -> String? {
    guard let range = diagnosticTailRange(in: text) else { return nil }
    return String(text[range.lowerBound...]).trimmed
  }

  private static func diagnosticTailRange(in text: String) -> Range<String.Index>? {
    let markers = [
      "\nVerification:",
      "\nValidation:",
      "\nDiagnostics:"
    ]
    return markers.compactMap { marker in
      text.range(of: marker, options: .caseInsensitive)
    }.min { lhs, rhs in
      lhs.lowerBound < rhs.lowerBound
    }
  }

  private static let diagnosticCommandIDs: Set<String> = [
    "plugins",
    "status",
    "update",
    "yolo"
  ]

  private static let diagnosticTextFragments = [
    "checking hermes checkout",
    "checking hermes tracked files",
    "hermes cli status",
    "hermes checkout has local changes",
    "hermes git check did not complete",
    "hermes_allow_dirty",
    "module not founderror",
    "packagedescription.package.__allocating_init",
    "timed out running git",
    "available tools"
  ]

  private static let diagnosticTraceFragments = [
    "/status",
    "/yolo",
    "git diff-index",
    "git status",
    "hermes_update.sh",
    "jobmaxxing_hermes_status",
    "jobmaxxing_status",
    "read local state",
    "scripts/hermes_update.sh",
    "select agent toolset",
    "terminal"
  ]

  private static let longUserMessageLimit = 900
  private static let longUserMessagePreviewLimit = 640
}

enum InlineTagRenderer {
  static let visibleTitles = [
    HermesNativeCommandCatalog.visibleTitles,
    [
    "Connections",
    "Why",
    "Dashboard",
    "Chat",
    "Application",
    "Applications",
    "Company",
    "Companies",
    "Contact",
    "Contacts",
    "Document",
    "Writing",
    "Interview",
    "Interviews",
    "Browser",
    "Gmail",
    "Drive",
    "Google Docs",
    "Google Calendar",
    "Google Sheets",
    "Google Slides",
    "GitHub",
    "Telegram",
    "WhatsApp",
    "Outlook",
    "Microsoft 365",
    "OneDrive",
    "Word",
    "Figma",
    "Railway",
    "Hugging Face",
    "Linear",
    "Notion",
    "Apple Mail",
    "Local Documents",
    "OpenAI",
    "Grok",
    "xAI",
    "OpenCode",
    "Cursor"
    ]
  ].flatMap { $0 }.uniqued
}

private struct CompactTraceDisclosure: View {
  let traces: [HermesTraceStep]
  @State private var expanded = false

  private var summary: String {
    let label = traces.first(where: { $0.toolName.trimmed.lowercased() != "reasoning" })?.label
      ?? traces.first?.label
      ?? "Details"
    return displayLabel(label)
  }

  private func displayLabel(_ label: String) -> String {
    let normalized = label.trimmed.lowercased()
    if normalized == "hermes" {
      return "Hermes"
    }
    if normalized.contains("live session") {
      return "Live session"
    }
    return label
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Button {
        expanded.toggle()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.caption.weight(.semibold))
          Text(summary)
            .font(.caption.weight(.semibold))
          Spacer()
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(LiquidPressButtonStyle())
      .help(expanded ? "Hide details" : "Show details")

      if expanded {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(traces) { trace in
            HermesTraceRow(trace: trace)
          }
        }
      }
    }
  }
}

private struct HermesTraceRow: View {
  let trace: HermesTraceStep

  private var labelText: String {
    let normalized = trace.label.trimmed.lowercased()
    if normalized == "hermes" {
      return "Hermes"
    }
    if normalized.contains("live session") {
      return "Live session"
    }
    return trace.label
  }

  private var statusText: String? {
    let status = trace.status.trimmed.lowercased()
    guard status != "complete" else { return nil }
    if status == "running" {
      return "Working"
    }
    return trace.status
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(labelText)
          .font(.caption.weight(.semibold))
        if let statusText = statusText {
          Text(statusText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
      }
      if !trace.detail.trimmed.isEmpty {
        Text(trace.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
      }
    }
    .padding(.vertical, 3)
  }
}

struct AttachmentChip: View {
  let document: CandidateDocument
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: document.kind.lowercased().contains("image") ? "photo" : "doc.text")
      Text(document.title)
        .lineLimit(1)
      Button(action: onRemove) {
        Image(systemName: "xmark")
          .font(.caption2.weight(.bold))
          .frame(width: 44, height: 44)
      }
      .buttonStyle(LiquidPressButtonStyle())
      .accessibilityLabel("Remove attachment")
      .help("Remove attachment")
    }
    .font(.caption.weight(.semibold))
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 5))
  }
}
