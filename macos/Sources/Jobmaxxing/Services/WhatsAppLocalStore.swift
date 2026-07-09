import Foundation
import SQLite3

final class WhatsAppLocalStore {
  let databasePath: String

  init(databasePath: String) {
    self.databasePath = databasePath
  }

  static var defaultDatabasePath: String {
    "\(NSHomeDirectory())/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"
  }

  static func isReadableDatabase(at path: String) -> Bool {
    FileManager.default.isReadableFile(atPath: path)
  }

  func databaseCounts() throws -> (threads: Int, messages: Int) {
    try withDatabase { database in
      let threads = try scalarInt("SELECT COUNT(*) FROM ZWACHATSESSION", database: database)
      let messages = try scalarInt("SELECT COUNT(*) FROM ZWAMESSAGE", database: database)
      return (threads, messages)
    }
  }

  func searchThreads(query rawQuery: String, limit: Int = 24) throws -> [WhatsAppThreadCandidate] {
    let query = rawQuery.trimmed
    let pattern = "%\(query.lowercased())%"
    return try withDatabase { database in
      var statement: OpaquePointer?
      let sql = """
      SELECT
        chat.Z_PK,
        COALESCE(NULLIF(chat.ZPARTNERNAME, ''), NULLIF(chat.ZCONTACTIDENTIFIER, ''), chat.ZCONTACTJID, 'Unknown'),
        COALESCE(ZCONTACTJID, ''),
        COALESCE(ZMESSAGECOUNTER, 0)
      FROM ZWACHATSESSION chat
      WHERE COALESCE(ZREMOVED, 0) = 0
        AND (
          ? = '%%'
          OR lower(COALESCE(chat.ZPARTNERNAME, '')) LIKE ?
          OR lower(COALESCE(chat.ZCONTACTIDENTIFIER, '')) LIKE ?
          OR lower(COALESCE(chat.ZCONTACTJID, '')) LIKE ?
        )
      ORDER BY COALESCE(ZLASTMESSAGEDATE, 0) DESC, Z_PK DESC
      LIMIT ?
      """
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw WhatsAppLocalStoreError.statement(Self.errorMessage(database))
      }
      defer { sqlite3_finalize(statement) }

      sqlite3_bind_text(statement, 1, pattern, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(statement, 2, pattern, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(statement, 3, pattern, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(statement, 4, pattern, -1, SQLITE_TRANSIENT)
      sqlite3_bind_int(statement, 5, Int32(limit))

      var results: [WhatsAppThreadCandidate] = []
      while sqlite3_step(statement) == SQLITE_ROW {
        let sessionID = sqlite3_column_int64(statement, 0)
        let displayName = Self.columnString(statement, 1)
        let jid = Self.columnString(statement, 2)
        let count = Int(sqlite3_column_int(statement, 3))
        results.append(
          WhatsAppThreadCandidate(
            id: "\(sessionID)",
            chatSessionID: sessionID,
            displayName: displayName,
            jid: jid,
            messageCount: count,
            lastMessagePreview: "",
            databasePath: databasePath
          )
        )
      }
      return results
    }
  }

  func importThread(_ candidate: WhatsAppThreadCandidate) throws -> WhatsAppThreadProfile {
    let messages = try loadMessages(chatSessionID: candidate.chatSessionID)
    let outgoing = messages.filter(\.isFromMe)
    let incoming = messages.filter { !$0.isFromMe }
    let topics = Self.topics(from: messages.map(\.text))
    let style = Self.styleSummary(outgoing: outgoing)
    let relationship = Self.relationshipSummary(displayName: candidate.displayName, messages: messages, topics: topics)
    return WhatsAppThreadProfile(
      threadID: candidate.id,
      chatSessionID: candidate.chatSessionID,
      displayName: candidate.displayName,
      jid: candidate.jid,
      databasePath: databasePath,
      messageCount: messages.count,
      outgoingCount: outgoing.count,
      incomingCount: incoming.count,
      lastMessagePreview: candidate.lastMessagePreview,
      styleSummary: style,
      relationshipSummary: relationship,
      topics: topics,
      directMessageFormat: Self.directMessageFormat(outgoing: outgoing),
      emailFormat: "Email should be more structured than this thread: subject, one proof line, one clear ask, no chat shorthand.",
      suggestedDirectMessage: "",
      suggestedEmailMessage: "",
      allowedForAI: true,
      messages: messages.enumerated().map { index, message in
        WhatsAppThreadMessage(
          id: "\(candidate.id)-\(index)",
          isFromMe: message.isFromMe,
          text: message.text,
          senderName: message.senderName,
          senderJID: message.senderJID
        )
      }
    )
  }

  private func loadMessages(chatSessionID: Int64) throws -> [WhatsAppLocalMessage] {
    try withDatabase { database in
      var statement: OpaquePointer?
      let sql = """
      SELECT
        COALESCE(ZISFROMME, 0),
        COALESCE(ZTEXT, ''),
        COALESCE(ZPUSHNAME, ''),
        COALESCE(ZFROMJID, ''),
        COALESCE(ZMESSAGEDATE, 0)
      FROM ZWAMESSAGE
      WHERE ZCHATSESSION = ?
        AND ZTEXT IS NOT NULL
        AND length(trim(ZTEXT)) > 0
      ORDER BY COALESCE(ZMESSAGEDATE, 0) ASC, Z_PK ASC
      """
      guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw WhatsAppLocalStoreError.statement(Self.errorMessage(database))
      }
      defer { sqlite3_finalize(statement) }

      sqlite3_bind_int64(statement, 1, chatSessionID)

      var messages: [WhatsAppLocalMessage] = []
      while sqlite3_step(statement) == SQLITE_ROW {
        let isFromMe = sqlite3_column_int(statement, 0) == 1
        let text = Self.columnString(statement, 1).trimmed
        guard !text.isEmpty else { continue }
        messages.append(
          WhatsAppLocalMessage(
            isFromMe: isFromMe,
            text: text,
            senderName: Self.columnString(statement, 2),
            senderJID: Self.columnString(statement, 3),
            rawTimestamp: sqlite3_column_double(statement, 4)
          )
        )
      }
      return messages
    }
  }

  private func withDatabase<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
    guard FileManager.default.fileExists(atPath: databasePath) else {
      throw WhatsAppLocalStoreError.notFound(databasePath)
    }
    var database: OpaquePointer?
    let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
    guard sqlite3_open_v2(databasePath, &database, flags, nil) == SQLITE_OK, let database else {
      throw WhatsAppLocalStoreError.open(Self.errorMessage(database))
    }
    defer { sqlite3_close(database) }
    return try work(database)
  }

  private func scalarInt(_ sql: String, database: OpaquePointer) throws -> Int {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      throw WhatsAppLocalStoreError.statement(Self.errorMessage(database))
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else {
      throw WhatsAppLocalStoreError.statement(Self.errorMessage(database))
    }
    return Int(sqlite3_column_int(statement, 0))
  }

  private static func columnString(_ statement: OpaquePointer, _ index: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: pointer)
  }

  private static func errorMessage(_ database: OpaquePointer?) -> String {
    guard let database, let pointer = sqlite3_errmsg(database) else {
      return "Unknown SQLite error."
    }
    return String(cString: pointer)
  }

  private static func styleSummary(outgoing: [WhatsAppLocalMessage]) -> String {
    guard !outgoing.isEmpty else {
      return "No outgoing text messages were found in this thread, so no personal writing style was learned."
    }
    let texts = outgoing.map(\.text)
    let words = texts.flatMap { $0.split(whereSeparator: \.isWhitespace) }
    let averageWords = max(1, words.count / max(1, texts.count))
    let questionRate = texts.filter { $0.contains("?") }.count
    let emojiRate = texts.filter { $0.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) }.count
    let line = averageWords <= 12 ? "short, chat-native messages" : "slightly fuller chat messages"
    let ask = questionRate > max(1, texts.count / 5) ? "often asks direct questions" : "usually states context before the ask"
    let emoji = emojiRate > max(1, texts.count / 6) ? "uses emoji when tone matters" : "uses little emoji"
    return "Outgoing style uses \(line), \(ask), and \(emoji). Keep direct messages close to that cadence."
  }

  private static func directMessageFormat(outgoing: [WhatsAppLocalMessage]) -> String {
    guard !outgoing.isEmpty else {
      return "Use one short opener, one context line, and one clear ask."
    }
    let averageLength = outgoing.map { $0.text.count }.reduce(0, +) / max(1, outgoing.count)
    if averageLength < 80 {
      return "Use one or two short bubbles. Start with context, then ask one concrete question."
    }
    return "Use a compact paragraph. Give context first, then one concrete ask. Avoid email subject lines."
  }

  private static func relationshipSummary(displayName: String, messages: [WhatsAppLocalMessage], topics: [String]) -> String {
    let count = messages.count
    guard count > 0 else {
      return "No readable text history found for \(displayName)."
    }
    let topicText = topics.isEmpty ? "no stable repeated topics" : topics.prefix(5).joined(separator: ", ")
    return "Imported \(count) readable messages with \(displayName). Repeated topics: \(topicText). Use this only for drafts or relationship context after the person is linked."
  }

  private static func topics(from texts: [String]) -> [String] {
    let stop = Set([
      "about", "after", "also", "and", "are", "but", "can", "for", "from", "have", "just", "like",
      "not", "that", "the", "then", "this", "with", "you", "your", "was", "what", "when", "will"
    ])
    var counts: [String: Int] = [:]
    for text in texts {
      let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
      for word in words where word.count > 3 && !stop.contains(word) {
        counts[word, default: 0] += 1
      }
    }
    return counts
      .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
      .prefix(8)
      .map(\.key)
  }
}

private struct WhatsAppLocalMessage {
  var isFromMe: Bool
  var text: String
  var senderName: String
  var senderJID: String
  var rawTimestamp: Double
}

private enum WhatsAppLocalStoreError: LocalizedError {
  case notFound(String)
  case open(String)
  case statement(String)

  var errorDescription: String? {
    switch self {
    case .notFound(let path):
      "WhatsApp database was not found at \(path). Open WhatsApp once, then refresh the connector path."
    case .open(let message):
      "Could not open the WhatsApp database: \(message)"
    case .statement(let message):
      "Could not read the WhatsApp database: \(message)"
    }
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
