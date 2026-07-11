import Foundation
import PDFKit

struct PreparedDocumentImport: @unchecked Sendable {
  let document: CandidateDocument
  let indexStatus: DocumentIndexStatus
}

struct PreparedDocumentImportBatch: @unchecked Sendable {
  let documents: [PreparedDocumentImport]
  let failures: [String]
}

enum DocumentImportPipeline {
  private static let maxTextBytes = 500_000
  private static let maxPDFPages = 25
  private static let maxTextCharacters = 200_000

  static func prepare(urls: [URL]) throws -> PreparedDocumentImportBatch {
    let documentsURL = try appSupportURL().appendingPathComponent("Documents", isDirectory: true)
    try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)

    var documents: [PreparedDocumentImport] = []
    var failures: [String] = []
    for originalURL in urls {
      let didAccess = originalURL.startAccessingSecurityScopedResource()
      defer {
        if didAccess { originalURL.stopAccessingSecurityScopedResource() }
      }
      do {
        let fileName = originalURL.lastPathComponent
        let destination = uniqueDestination(in: documentsURL, fileName: fileName)
        try FileManager.default.copyItem(at: originalURL, to: destination)
        let text = extractText(from: destination)
        let document = CandidateDocument(
          id: UUID().uuidString,
          title: originalURL.deletingPathExtension().lastPathComponent,
          fileName: fileName,
          filePath: destination.path,
          kind: destination.pathExtension.isEmpty ? "file" : destination.pathExtension.lowercased(),
          summary: summarize(text: text, fallback: fileName),
          extractedText: text,
          linkedEvidenceIDs: []
        )
        let started = Date()
        let indexStatus: DocumentIndexStatus
        do {
          try DocumentDatabase.shared.upsert(document)
          indexStatus = DocumentIndexStatus(
            documentID: document.id,
            documentTitle: document.title,
            durationMilliseconds: elapsedMilliseconds(since: started),
            succeeded: true,
            message: "Imported and indexed \(document.fileName)."
          )
        } catch {
          indexStatus = DocumentIndexStatus(
            documentID: document.id,
            documentTitle: document.title,
            durationMilliseconds: elapsedMilliseconds(since: started),
            succeeded: false,
            message: "Imported \(document.fileName), but local search indexing failed: \(error.localizedDescription)"
          )
        }
        documents.append(PreparedDocumentImport(document: document, indexStatus: indexStatus))
      } catch {
        failures.append("Could not import \(originalURL.lastPathComponent): \(error.localizedDescription)")
      }
    }
    return PreparedDocumentImportBatch(documents: documents, failures: failures)
  }

  private static func uniqueDestination(in directory: URL, fileName: String) -> URL {
    let base = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    let ext = URL(fileURLWithPath: fileName).pathExtension
    let candidate = directory.appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }
    let suffix = UUID().uuidString.prefix(8)
    let nextName = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
    return directory.appendingPathComponent(nextName)
  }

  private static func extractText(from url: URL) -> String {
    let ext = url.pathExtension.lowercased()
    if ext == "pdf", let document = PDFDocument(url: url) {
      return (0..<min(document.pageCount, maxPDFPages))
        .compactMap { document.page(at: $0)?.string }
        .joined(separator: "\n")
        .trimmed
        .bounded(to: maxTextCharacters)
    }
    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    guard fileSize <= maxTextBytes else { return "" }
    if ["txt", "md", "csv", "json", "html", "rtf"].contains(ext),
       let text = try? String(contentsOf: url, encoding: .utf8) {
      return text.trimmed.bounded(to: maxTextCharacters)
    }
    return ""
  }

  private static func summarize(text: String, fallback: String) -> String {
    let normalized = text.replacingOccurrences(of: "\n", with: " ").trimmed
    if normalized.isEmpty {
      return "Imported \(fallback). Add notes or promote it to evidence after review."
    }
    return String(normalized.prefix(240))
  }

  private static func appSupportURL() throws -> URL {
    try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ).appendingPathComponent("Jobmaxxing", isDirectory: true)
  }

  private static func elapsedMilliseconds(since start: Date) -> Int {
    max(0, Int(Date().timeIntervalSince(start) * 1_000))
  }
}
