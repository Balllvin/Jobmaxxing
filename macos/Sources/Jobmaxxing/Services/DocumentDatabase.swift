import Foundation
import SQLite3

final class DocumentDatabase {
  static let shared = DocumentDatabase()

  private init() {}

  func upsert(_ document: CandidateDocument) throws {
    let url = try Self.databaseURL()
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
      throw DocumentDatabaseError.openFailed(Self.errorMessage(database))
    }
    defer { sqlite3_close(database) }

    try execute(Self.createSQL, database: database)
    try bindAndStep(Self.upsertSQL, database: database, values: [
      document.id,
      document.title,
      document.fileName,
      document.filePath,
      document.kind,
      document.summary,
      document.extractedText,
      document.linkedEvidenceIDs.joined(separator: ",")
    ])
  }

  private func execute(_ sql: String, database: OpaquePointer) throws {
    var error: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
      let message = error.map { String(cString: $0) } ?? Self.errorMessage(database)
      sqlite3_free(error)
      throw DocumentDatabaseError.statementFailed(message)
    }
  }

  private func bindAndStep(_ sql: String, database: OpaquePointer, values: [String]) throws {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
      throw DocumentDatabaseError.statementFailed(Self.errorMessage(database))
    }
    defer { sqlite3_finalize(statement) }

    for (index, value) in values.enumerated() {
      sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
    }

    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw DocumentDatabaseError.statementFailed(Self.errorMessage(database))
    }
  }

  private static func databaseURL() throws -> URL {
    try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    .appendingPathComponent("Jobmaxxing", isDirectory: true)
    .appendingPathComponent("documents.sqlite")
  }

  private static func errorMessage(_ database: OpaquePointer?) -> String {
    guard let database, let pointer = sqlite3_errmsg(database) else {
      return "Unknown SQLite error."
    }
    return String(cString: pointer)
  }

  private static let createSQL = """
  CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    kind TEXT NOT NULL,
    summary TEXT NOT NULL,
    extracted_text TEXT NOT NULL,
    linked_evidence_ids TEXT NOT NULL
  );
  """

  private static let upsertSQL = """
  INSERT INTO documents (
    id,
    title,
    file_name,
    file_path,
    kind,
    summary,
    extracted_text,
    linked_evidence_ids
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT(id) DO UPDATE SET
    title = excluded.title,
    file_name = excluded.file_name,
    file_path = excluded.file_path,
    kind = excluded.kind,
    summary = excluded.summary,
    extracted_text = excluded.extracted_text,
    linked_evidence_ids = excluded.linked_evidence_ids;
  """
}

private enum DocumentDatabaseError: LocalizedError {
  case openFailed(String)
  case statementFailed(String)

  var errorDescription: String? {
    switch self {
    case .openFailed(let message):
      "Could not open Jobmaxxing document database: \(message)"
    case .statementFailed(let message):
      "Could not write Jobmaxxing document database: \(message)"
    }
  }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
