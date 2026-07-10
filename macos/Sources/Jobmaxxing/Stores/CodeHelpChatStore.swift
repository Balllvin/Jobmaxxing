import Foundation

private struct CodeHelpChatState: Codable, Hashable {
  var messages: [HermesChatMessage]
}

@MainActor
final class CodeHelpChatStore: ObservableObject {
  @Published private(set) var messages: [HermesChatMessage]
  @Published private(set) var isRunning = false

  private let storageURL: URL
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()

  init(storageURL: URL? = nil) {
    self.storageURL = storageURL ?? Self.defaultStorageURL()
    let loaded = Self.loadMessages(from: self.storageURL)
    messages = Self.repairedMessages(loaded)
    if loaded != messages {
      persist()
    }
  }

  func send(question rawQuestion: String, replyID: String?, route: ModelRoute) {
    let question = rawQuestion.trimmed
    guard !question.isEmpty, !isRunning else { return }

    let replyContext = Self.replyContext(in: messages, replyID: replyID)
    let userMessage = HermesChatMessage(
      id: UUID().uuidString,
      role: "user",
      text: question,
      status: "complete",
      commandID: nil,
      traces: [],
      attachments: []
    )
    let responseID = UUID().uuidString
    let response = HermesChatMessage(
      id: responseID,
      role: "assistant",
      text: "",
      status: "running",
      commandID: nil,
      traces: [
        Self.trace(
          "Code Help",
          tool: "Medium model",
          status: "running",
          detail: "Searching the local repository with the Medium route."
        )
      ],
      attachments: []
    )
    messages.append(userMessage)
    messages.append(response)
    isRunning = true
    persist()

    let request = CodeHelpAgentRequest(question: question, replyContext: replyContext, route: route)
    Task {
      let result = await CodeHelpAgentRunner.respond(to: request)
      await MainActor.run {
        self.finish(responseID: responseID, result: result)
      }
    }
  }

  func replyTarget(id: String?) -> CodeHelpReplyContext? {
    Self.replyContext(in: messages, replyID: id)
  }

  static func replyContext(in messages: [HermesChatMessage], replyID: String?) -> CodeHelpReplyContext? {
    guard let replyID,
          let index = messages.firstIndex(where: { $0.id == replyID }) else { return nil }
    let message = messages[index]
    let previousUserQuestion: String?
    if message.role.lowercased() == "assistant" {
      previousUserQuestion = messages[..<index]
        .last { $0.role.lowercased() == "user" }?
        .text
        .trimmed
    } else {
      previousUserQuestion = nil
    }
    return CodeHelpReplyContext(
      messageID: message.id,
      role: message.role,
      text: message.text.trimmed,
      previousUserQuestion: previousUserQuestion?.isEmpty == true ? nil : previousUserQuestion
    )
  }

  private func finish(responseID: String, result: CodeHelpAgentResult) {
    guard let index = messages.firstIndex(where: { $0.id == responseID }) else {
      isRunning = false
      persist()
      return
    }
    let failed = result.traces.contains { $0.status == "failed" }
    messages[index] = HermesChatMessage(
      id: responseID,
      role: "assistant",
      text: result.text,
      status: failed ? "failed" : "complete",
      commandID: nil,
      traces: result.traces,
      attachments: []
    )
    isRunning = false
    persist()
  }

  private func persist() {
    do {
      try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try encoder.encode(CodeHelpChatState(messages: messages))
      try data.write(to: storageURL, options: [.atomic])
    } catch {
      print("Could not save Code Help chat: \(error)")
    }
  }

  private static func loadMessages(from url: URL) -> [HermesChatMessage] {
    guard let data = try? Data(contentsOf: url),
          let state = try? JSONDecoder().decode(CodeHelpChatState.self, from: data) else { return [] }
    return state.messages
  }

  private static func repairedMessages(_ messages: [HermesChatMessage]) -> [HermesChatMessage] {
    messages.map { message in
      guard message.status.trimmed.lowercased() == "running" else { return message }
      return HermesChatMessage(
        id: message.id,
        role: message.role,
        text: message.text.trimmed.isEmpty ? "The previous Code Help request did not finish." : message.text,
        status: "failed",
        commandID: message.commandID,
        traces: message.traces,
        attachments: message.attachments
      )
    }
  }

  private static func defaultStorageURL() -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
    return base
      .appendingPathComponent("Jobmaxxing", isDirectory: true)
      .appendingPathComponent("code-help-chat.json")
  }

  private static func trace(_ label: String, tool: String, status: String = "complete", detail: String) -> HermesTraceStep {
    HermesTraceStep(
      id: UUID().uuidString,
      label: label,
      status: status,
      toolName: tool,
      detail: detail
    )
  }
}
