import AppKit
import SwiftUI

struct HermesChatView: View {
  @EnvironmentObject private var store: JobmaxxingStore
  @Binding var draft: String
  @Binding var attachmentIDs: [String]
  @StateObject private var dictation = DictationController()
  @State private var composerHeight = ComposerMetrics.minHeight
  @State private var importing = false
  @State private var attachments: [CandidateDocument] = []
  @State private var syncStatus = ""
  @State private var isSyncingTelegram = false
  @State private var isImportingAttachments = false

  private var thread: HermesChatThread? {
    store.selectedHermesThread
  }

  private var transcriptSections: HermesTranscriptSections {
    HermesTranscriptPresentation.sections(for: thread?.messages ?? [])
  }

  private var isHermesRunning: Bool {
    thread?.messages.contains { $0.status.trimmed.lowercased() == "running" } == true
  }

  private var isTelegramEnabled: Bool {
    store.integrationConnectors.first(where: { $0.id == "telegram" })?.isEnabled == true
  }

  private var slashCommands: [SlashCommandSuggestion] {
    SlashCommandSuggestion.all
  }

  private var filteredSlashCommands: [SlashCommandSuggestion] {
    filteredSlashCommands(in: draft)
  }

  private func filteredSlashCommands(in text: String) -> [SlashCommandSuggestion] {
    guard let token = currentSlashToken(in: text) else { return [] }
    let trigger = String(token.prefix(1))
    let query = String(token.dropFirst()).lowercased()
    return slashCommands.filter { command in
      command.trigger == trigger
        && (query.isEmpty
        || command.id.contains(query)
        || command.aliases.contains(where: { $0.contains(query) })
        || command.title.lowercased().contains(query)
        || command.detail.lowercased().contains(query))
    }.sorted { lhs, rhs in
      suggestionRank(lhs, query: query) < suggestionRank(rhs, query: query)
    }
  }

  private func suggestionRank(_ command: SlashCommandSuggestion, query: String) -> Int {
    guard !query.isEmpty else { return 10 }
    let title = command.title.lowercased()
    if command.id == query || title == query { return 0 }
    if command.aliases.contains(query) { return 0 }
    if command.id.hasPrefix(query) || title.hasPrefix(query) { return 1 }
    if command.aliases.contains(where: { $0.hasPrefix(query) }) { return 1 }
    if command.id.contains(query) || title.contains(query) { return 2 }
    if command.aliases.contains(where: { $0.contains(query) }) { return 2 }
    return 3
  }

  private var recommendedSlashCommand: SlashCommandSuggestion? {
    recommendedSlashCommand(in: draft)
  }

  private func recommendedSlashCommand(in text: String) -> SlashCommandSuggestion? {
    guard let token = currentSlashToken(in: text) else { return nil }
    if let first = filteredSlashCommands(in: text).first {
      return first
    }
    let trigger = String(token.prefix(1))
    let scopedCommands = slashCommands.filter { $0.trigger == trigger }
    let lower = text.lowercased()
    let preferredID: String
    if trigger == "/" {
      if lower.contains("update") {
        preferredID = "update"
      } else if lower.contains("permission") || lower.contains("approval") || lower.contains("yolo") {
        preferredID = "yolo"
      } else if lower.contains("queue") {
        preferredID = "queue"
      } else if lower.contains("status") {
        preferredID = "status"
      } else {
        preferredID = "help"
      }
    } else if trigger == "@" {
      if lower.contains("drive") || lower.contains("doc") || lower.contains("resume") || lower.contains("cv") || lower.contains("proof") {
        preferredID = "drive"
      } else if lower.contains("github") || lower.contains("repo") || lower.contains("code") {
        preferredID = "github"
      } else if lower.contains("grok") || lower.contains("xai") || lower.contains("x.ai") {
        preferredID = "xai"
      } else if lower.contains("openai") || lower.contains("gpt") {
        preferredID = "openai"
      } else if lower.contains("telegram") || lower.contains("chat") {
        preferredID = "telegram"
      } else if lower.contains("whatsapp") || lower.contains("message") {
        preferredID = "whatsapp"
      } else if lower.contains("outlook") || lower.contains("calendar") {
        preferredID = "outlook"
      } else {
        preferredID = "gmail"
      }
    } else if lower.contains("gmail") || lower.contains("email") || lower.contains("mail") {
      preferredID = "gmail"
    } else if lower.contains("drive") || lower.contains("doc") || lower.contains("resume") || lower.contains("cv") || lower.contains("proof") {
      preferredID = "document"
    } else if lower.contains("company") || lower.contains("joining") || lower.contains("profile") {
      preferredID = "company"
    } else if lower.contains("contact") || lower.contains("recruiter") || lower.contains("referral") || lower.contains("person") {
      preferredID = "contact"
    } else if lower.contains("interview") || lower.contains("prep") {
      preferredID = "interview"
    } else if lower.contains("browser") || lower.contains("linkedin") || lower.contains("website") || lower.contains("site") {
      preferredID = "browser"
    } else if lower.contains("application") || lower.contains("apply") || lower.contains("role") {
      preferredID = "application"
    } else {
      preferredID = "goal"
    }
    return scopedCommands.first { $0.id == preferredID } ?? scopedCommands.first
  }

  private var currentSlashToken: String? {
    currentSlashToken(in: draft)
  }

  private func currentSlashToken(in text: String) -> String? {
    guard let last = text.unicodeScalars.last,
          !CharacterSet.whitespacesAndNewlines.contains(last) else { return nil }
    guard let token = text.split(whereSeparator: \.isWhitespace).last.map(String.init),
          let first = token.first,
          ["/", "$", "@"].contains(String(first)) else { return nil }
    return token
  }

  var body: some View {
    let sections = transcriptSections
    VStack(spacing: 0) {
      chatStateHeader(sections)
      transcript(sections)
      composer
    }
    .background(Color.clear)
    .onAppear {
      store.selectedHermesThreadID = store.hermesChatState.selectedThreadID
      attachments = attachmentIDs.compactMap { id in
        store.state.documents.first(where: { $0.id == id })
      }
    }
    .onChange(of: attachments.map(\.id)) { _, ids in
      attachmentIDs = ids
    }
    .onDisappear {
      attachmentIDs = attachments.map(\.id)
      dictation.cancel()
    }
    .fileImporter(
      isPresented: $importing,
      allowedContentTypes: DocumentImportTypes.allowed,
      allowsMultipleSelection: true
    ) { result in
      Task { @MainActor in
        isImportingAttachments = true
        defer { isImportingAttachments = false }
        do {
          let urls = try result.get()
          let outcome = try await store.importDocuments(from: urls)
          attachments.append(contentsOf: outcome.importedDocuments.filter { importedDocument in
            !attachments.contains(where: { $0.id == importedDocument.id })
          })
          syncStatus = outcome.failures.isEmpty
            ? (store.state.documentIndexStatus?.message ?? outcome.summary)
            : outcome.summary
        } catch {
          syncStatus = error.localizedDescription
        }
      }
    }
  }

  private func chatStateHeader(_ sections: HermesTranscriptSections) -> some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(routeTitle)
          .font(.headline.weight(.semibold))
          .foregroundStyle(.primary)
        Text(HermesTranscriptPresentation.latestSummary(from: sections.latestUsefulAssistant))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .textSelection(.enabled)
      }
      Spacer(minLength: 12)
      HStack(spacing: 8) {
        if isTelegramEnabled {
          Button {
            Task { await syncTelegram(silent: false) }
          } label: {
            Group {
              if isSyncingTelegram {
                ProgressView()
                  .scaleEffect(0.55)
              } else {
                Image(systemName: "arrow.triangle.2.circlepath")
              }
            }
            .frame(width: 44, height: 44)
          }
          .buttonStyle(LiquidPressButtonStyle())
          .disabled(isSyncingTelegram)
          .accessibilityLabel(isSyncingTelegram ? "Syncing Telegram" : "Sync Telegram")
          .help("Import new messages from the configured Telegram chat")
        }
        if isHermesRunning {
          ProgressView()
            .scaleEffect(0.55)
            .frame(width: 14, height: 14)
        }
        Text(isHermesRunning ? "Working" : "Ready")
          .font(.caption.weight(.semibold))
          .foregroundStyle(isHermesRunning ? Color.accentColor : Color.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 10)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color(nsColor: .separatorColor).opacity(0.7))
        .frame(height: 1)
    }
    .background(.bar)
  }

  private var routeTitle: String {
    let title = thread?.title.trimmed ?? ""
    return title.isEmpty ? "Chat · Hermes" : "\(title) · Hermes"
  }

  private func transcript(_ sections: HermesTranscriptSections) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          if sections.visibleMessages.isEmpty {
            ChatEmptyState()
          } else {
            ForEach(sections.visibleMessages) { message in
              ChatMessageRow(
                message: message,
                onReply: { reply(to: message) },
                onCopy: { copy(message) }
              )
                .id(message.id)
            }
          }
          if !sections.diagnosticMessages.isEmpty {
            TranscriptDiagnosticsDisclosure(messages: sections.diagnosticMessages) { message in
              reply(to: message)
            } onCopy: { message in
              copy(message)
            }
          }
          Color.clear
            .frame(height: 12)
            .id(Self.transcriptBottomID)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .onAppear {
        scrollToLatestMessage(with: proxy)
      }
      .onChange(of: thread?.messages.last?.id) { _, _ in
        scrollToLatestMessage(with: proxy)
      }
      .onChange(of: (thread?.messages.last?.text.count ?? 0) / 160) { _, _ in
        scrollToLatestMessage(with: proxy)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func scrollToLatestMessage(with proxy: ScrollViewProxy) {
    DispatchQueue.main.async {
      proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
    }
  }

  private static let transcriptBottomID = "hermes-transcript-bottom"

  private var composer: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !attachments.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(attachments) { document in
              AttachmentChip(document: document) {
                attachments.removeAll { $0.id == document.id }
              }
            }
          }
        }
      }

      if !filteredSlashCommands.isEmpty {
        SlashCommandPicker(commands: filteredSlashCommands) { command in
          select(command)
        }
      }

      if let status = composerStatus {
        HStack(spacing: 6) {
          if dictation.isTranscribing {
            ProgressView()
              .scaleEffect(0.55)
              .frame(width: 14, height: 14)
          }
          Text(status)
            .font(.caption)
            .foregroundStyle(composerStatusIsError ? Color.red : Color.secondary)
            .lineLimit(2)
            .textSelection(.enabled)
        }
      }

      HStack(alignment: .bottom, spacing: 6) {
        ComposerIconButton(
          systemName: "paperclip",
          accessibilityLabel: isImportingAttachments ? "Importing attachments" : "Attach files",
          isProminent: false,
          isLoading: isImportingAttachments
        ) {
          importing = true
        }
        .disabled(isImportingAttachments)
        .help("Attach files to this message")

        ZStack(alignment: .leading) {
          if draft.isEmpty {
            Text("Ask about a job, company, contact, or interview")
              .font(.body)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.tail)
              .minimumScaleFactor(0.85)
              .allowsTightening(true)
          }
          TaggedComposerTextView(text: $draft, height: $composerHeight) { currentText in
            guard let command = recommendedSlashCommand(in: currentText) else { return }
            select(command, in: currentText)
          } onSend: {
            send()
          }
          .frame(height: composerHeight)
          .disabled(isHermesRunning)
        }
        .padding(.horizontal, 10)
        .frame(height: composerHeight)
        .liquidGlassSurface(.strong, cornerRadius: AppTheme.radiusMedium, isInteractive: true)

        Button {
          toggleDictation()
        } label: {
          Group {
            if dictation.isTranscribing {
              ProgressView()
                .scaleEffect(0.6)
            } else {
              Image(systemName: dictation.isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(dictation.isRecording ? Color.red : Color.secondary)
            }
          }
          .frame(width: 44, height: 44)
        }
        .buttonStyle(LiquidPressButtonStyle())
        .disabled(dictation.isTranscribing)
        .accessibilityLabel(dictationButtonLabel)
        .help(dictationButtonHelp)

        ComposerIconButton(systemName: "paperplane.fill", accessibilityLabel: "Send message", isProminent: true) {
          send()
        }
        .disabled(!canSendMessage)
        .help("Send message")
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 14)
    .background(.bar)
  }

  private func select(_ command: SlashCommandSuggestion, in currentText: String? = nil) {
    let sourceText = currentText ?? draft
    let token = currentSlashToken(in: sourceText) ?? ""
    guard !token.isEmpty, let range = sourceText.range(of: token, options: .backwards) else {
      draft = [sourceText.trimmed, command.title].filter { !$0.isEmpty }.joined(separator: " ") + " "
      return
    }
    var nextDraft = sourceText
    nextDraft.replaceSubrange(range, with: command.title)
    if !nextDraft.hasSuffix(" ") {
      nextDraft += " "
    }
    draft = nextDraft
  }

  private func send() {
    guard canSendMessage else { return }
    store.sendHermesMessage(draft, attachments: attachments)
    draft = ""
    attachments = []
    composerHeight = ComposerMetrics.minHeight
    syncStatus = ""
  }

  private var canSendMessage: Bool {
    (!draft.trimmed.isEmpty || !attachments.isEmpty)
      && !dictation.isTranscribing
      && !isHermesRunning
  }

  private var composerStatus: String? {
    if dictation.isRecording {
      return "Recording"
    }
    if dictation.isTranscribing {
      return "Transcribing audio"
    }
    let dictationStatus = dictation.statusText.trimmed
    if !dictationStatus.isEmpty && !dictation.isRecording {
      return dictationStatus
    }
    return syncStatus.trimmed.isEmpty ? nil : syncStatus.trimmed
  }

  private var dictationButtonLabel: String {
    if dictation.isTranscribing {
      return "Transcribing audio"
    }
    return dictation.isRecording ? "Stop recording" : "Record voice"
  }

  private var dictationButtonHelp: String {
    if dictation.isTranscribing {
      return "Transcribing audio"
    }
    return dictation.isRecording ? "Stop and transcribe" : "Record voice"
  }

  private var composerStatusIsError: Bool {
    if case .error = dictation.phase {
      return true
    }
    return !syncStatus.trimmed.isEmpty && !syncStatus.lowercased().hasPrefix("synced")
  }

  private func copy(_ message: HermesChatMessage) {
    let text = copyableText(for: message)
    guard !text.trimmed.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    syncStatus = "Copied."
  }

  private func reply(to message: HermesChatMessage) {
    let quote = copyableText(for: message)
      .components(separatedBy: .newlines)
      .prefix(8)
      .map { "> \($0)" }
      .joined(separator: "\n")
    guard !quote.trimmed.isEmpty else { return }
    draft = [draft.trimmed, quote, ""].filter { !$0.isEmpty }.joined(separator: "\n")
  }

  private func copyableText(for message: HermesChatMessage) -> String {
    if message.role.lowercased() == "user", let commandID = message.commandID {
      return HermesNativeCommandCatalog.commandText(commandID: commandID, rawText: message.text, visibleText: message.text)
    }
    return message.text.trimmed
  }

  private func toggleDictation() {
    Task {
      if dictation.isRecording {
        let result = await dictation.stopAndTranscribe()
        if result.hasPrefix("ERROR:") {
          syncStatus = String(result.dropFirst("ERROR:".count)).trimmed
          return
        }
        let text = result.trimmed
        if !text.isEmpty {
          draft = [draft.trimmed, text].filter { !$0.isEmpty }.joined(separator: " ")
        }
      } else {
        if let error = await dictation.start() {
          syncStatus = error
        }
      }
    }
  }

  private func syncTelegram(silent: Bool) async {
    guard !isSyncingTelegram else { return }
    isSyncingTelegram = true
    defer { isSyncingTelegram = false }
    let result = await store.syncTelegramMessages()
    if !silent || result.contains("Synced 1") || result.lowercased().contains("error") {
      syncStatus = result
    }
  }
}

private struct ChatEmptyState: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Ask about a role, company, contact, or interview.")
        .font(.body.weight(.semibold))
      Text("Attach sources or ask what to do next.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 28)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct TranscriptDiagnosticsDisclosure: View {
  let messages: [HermesChatMessage]
  let onReply: (HermesChatMessage) -> Void
  let onCopy: (HermesChatMessage) -> Void
  @State private var expanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        expanded.toggle()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.caption.weight(.semibold))
          Text("Technical log")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          Text("Command output kept out of the chat")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer()
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(LiquidPressButtonStyle())
      .help(expanded ? "Hide diagnostics" : "Show diagnostics")

      if expanded {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(messages) { message in
            ChatMessageRow(
              message: message,
              showsDiagnosticContent: true,
              onReply: { onReply(message) },
              onCopy: { onCopy(message) }
            )
          }
        }
        .padding(.leading, 12)
      }
    }
    .padding(.top, 4)
  }
}

private struct ComposerIconButton: View {
  let systemName: String
  let accessibilityLabel: String
  let isProminent: Bool
  var isLoading = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Group {
        if isLoading {
          ProgressView()
            .controlSize(.small)
        } else {
          Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
        }
      }
      .frame(width: 44, height: 44)
      .contentShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(LiquidPressButtonStyle())
    .accessibilityLabel(accessibilityLabel)
    .foregroundStyle(isProminent ? AppTheme.accentForeground : Color.secondary)
    .background(isProminent ? AppTheme.accent : Color.clear)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(isProminent ? AppTheme.accent : Color.clear, lineWidth: 1)
    )
  }
}

private struct SlashCommandSuggestion: Identifiable, Hashable {
  let id: String
  let title: String
  let detail: String
  let trigger: String
  var aliases: [String] = []

  static let all: [SlashCommandSuggestion] = [
    HermesNativeCommandCatalog.commands.filter(Self.shouldSuggestHermesCommand).map {
      SlashCommandSuggestion(
        id: $0.id,
        title: $0.title,
        detail: $0.detail,
        trigger: "/",
        aliases: $0.aliases
      )
    },
    [
    SlashCommandSuggestion(id: "dashboard", title: "Dashboard", detail: "Application queue and next action", trigger: "$"),
    SlashCommandSuggestion(id: "chat", title: "Chat", detail: "Route work and inspect actions", trigger: "$"),
    SlashCommandSuggestion(id: "application", title: "Application", detail: "Draft, audit, next steps", trigger: "$"),
    SlashCommandSuggestion(id: "applications", title: "Applications", detail: "Open roles and draft packs", trigger: "$"),
    SlashCommandSuggestion(id: "company", title: "Company", detail: "Research and people map", trigger: "$"),
    SlashCommandSuggestion(id: "companies", title: "Companies", detail: "Company directory and profiles", trigger: "$"),
    SlashCommandSuggestion(id: "contact", title: "Contact", detail: "People, relationship context, outreach", trigger: "$"),
    SlashCommandSuggestion(id: "contacts", title: "Contacts", detail: "Recruiters, referrals, and warm paths", trigger: "$"),
    SlashCommandSuggestion(id: "document", title: "Document", detail: "Proof, source, or field checklist", trigger: "$"),
    SlashCommandSuggestion(id: "writing", title: "Writing", detail: "Draft, audit, and tighten text", trigger: "$"),
    SlashCommandSuggestion(id: "interview", title: "Interview", detail: "Practice pack and proof stories", trigger: "$"),
    SlashCommandSuggestion(id: "interviews", title: "Interviews", detail: "Prep, notes, and follow-up", trigger: "$"),
    SlashCommandSuggestion(id: "browser", title: "Browser", detail: "Safe browser plan", trigger: "$"),
    SlashCommandSuggestion(id: "gmail", title: "Gmail", detail: "Mail drafts and review", trigger: "@"),
    SlashCommandSuggestion(id: "drive", title: "Drive", detail: "Docs, Sheets, Slides files", trigger: "@"),
    SlashCommandSuggestion(id: "google-docs", title: "Google Docs", detail: "CVs, letters, and notes", trigger: "@"),
    SlashCommandSuggestion(id: "google-calendar", title: "Google Calendar", detail: "Interview scheduling", trigger: "@"),
    SlashCommandSuggestion(id: "google-sheets", title: "Google Sheets", detail: "Application trackers", trigger: "@"),
    SlashCommandSuggestion(id: "google-slides", title: "Google Slides", detail: "Portfolio decks", trigger: "@"),
    SlashCommandSuggestion(id: "github", title: "GitHub", detail: "Repos, issues, pull requests", trigger: "@"),
    SlashCommandSuggestion(id: "telegram", title: "Telegram", detail: "Incoming message sync", trigger: "@"),
    SlashCommandSuggestion(id: "whatsapp", title: "WhatsApp", detail: "Linked local thread context", trigger: "@"),
    SlashCommandSuggestion(id: "outlook", title: "Outlook", detail: "Mail and calendar", trigger: "@"),
    SlashCommandSuggestion(id: "microsoft-365", title: "Microsoft 365", detail: "Office account route", trigger: "@"),
    SlashCommandSuggestion(id: "onedrive", title: "OneDrive", detail: "Resume and proof storage", trigger: "@"),
    SlashCommandSuggestion(id: "word", title: "Word", detail: "DOCX CV and letter edits", trigger: "@"),
    SlashCommandSuggestion(id: "figma", title: "Figma", detail: "Design proof and portfolio", trigger: "@"),
    SlashCommandSuggestion(id: "railway", title: "Railway", detail: "Deployment proof", trigger: "@"),
    SlashCommandSuggestion(id: "hugging-face", title: "Hugging Face", detail: "Models and Spaces", trigger: "@"),
    SlashCommandSuggestion(id: "linear", title: "Linear", detail: "Job-search tasks", trigger: "@"),
    SlashCommandSuggestion(id: "notion", title: "Notion", detail: "Notes and CRM", trigger: "@"),
    SlashCommandSuggestion(id: "apple-mail", title: "Apple Mail", detail: "Local mail evidence", trigger: "@"),
    SlashCommandSuggestion(id: "local-documents", title: "Local Documents", detail: "Local proof files", trigger: "@"),
    SlashCommandSuggestion(id: "openai", title: "OpenAI", detail: "High and Medium model route", trigger: "@"),
    SlashCommandSuggestion(id: "xai", title: "Grok", detail: "xAI Grok model route", trigger: "@"),
    SlashCommandSuggestion(id: "opencode", title: "OpenCode", detail: "Light model route", trigger: "@"),
    SlashCommandSuggestion(id: "cursor", title: "Cursor", detail: "Local agent bridge", trigger: "@")
    ]
  ].flatMap { $0 }

  private static func shouldSuggestHermesCommand(_ command: HermesNativeCommand) -> Bool {
    suggestedHermesCommandIDs.contains(command.id)
  }

  private static let suggestedHermesCommandIDs: Set<String> = [
    "agents",
    "background",
    "branch",
    "codex-runtime",
    "compress",
    "debug",
    "fast",
    "goal",
    "handoff",
    "help",
    "model",
    "moa",
    "new",
    "personality",
    "profile",
    "queue",
    "reasoning",
    "resume",
    "retry",
    "sessions",
    "status",
    "steer",
    "stop",
    "subgoal",
    "title",
    "undo",
    "update",
    "usage",
    "version",
    "voice",
    "yolo"
  ]
}

private struct SlashCommandPicker: View {
  let commands: [SlashCommandSuggestion]
  let onSelect: (SlashCommandSuggestion) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(commands.prefix(10)) { command in
          Button {
            onSelect(command)
          } label: {
            HStack(spacing: 6) {
              Text(command.trigger)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(command.trigger == "@" ? Color.orange : Color.accentColor)
              Text(command.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator, lineWidth: 1))
          }
          .buttonStyle(LiquidPressButtonStyle())
          .help("\(command.trigger)\(command.id): \(command.detail)")
        }
      }
    }
  }
}
