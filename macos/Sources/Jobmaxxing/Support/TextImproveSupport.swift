import Foundation

enum TextImproveSupport {
  static func rewritePrompt(
    currentText: String,
    feedback: String,
    context: String,
    kind: String
  ) -> String {
    let kindLabel = kind.trimmed.isEmpty ? "text" : kind.trimmed
    let current = currentText.trimmed.isEmpty ? "(empty)" : currentText.trimmed
    let userFeedback = feedback.trimmed
    let extra = context.trimmed

    return """
    Rewrite this \(kindLabel).

    USER FEEDBACK (highest priority — implement this first):
    \(userFeedback)

    CURRENT TEXT:
    \(current)

    OTHER CONTEXT (secondary — use only when it helps the user feedback):
    \(extra.isEmpty ? "(none)" : extra)

    Instructions:
    - Prioritize the user's feedback over default writing rules, style guides, and template habits.
    - Keep claims factual. Do not invent proof, employers, metrics, or people.
    - If feedback conflicts with style rules, follow the feedback.
    - Preserve useful facts from the current text unless the user asked to remove or change them.
    - Return only the rewritten \(kindLabel). No preamble, no markdown fences, no explanation.
    """
  }

  static func cleanOutput(_ raw: String) -> String {
    var text = raw.trimmed
    if text.hasPrefix("```") {
      var lines = text.components(separatedBy: .newlines)
      if lines.first?.hasPrefix("```") == true {
        lines.removeFirst()
      }
      if lines.last?.hasPrefix("```") == true {
        lines.removeLast()
      }
      text = lines.joined(separator: "\n").trimmed
    }

    let lower = text.lowercased()
    let prefixes = [
      "here is the rewritten",
      "here's the rewritten",
      "rewritten text:",
      "updated text:",
      "sure,",
      "of course,"
    ]
    for prefix in prefixes where lower.hasPrefix(prefix) {
      if let range = text.range(of: "\n") {
        text = String(text[range.upperBound...]).trimmed
      }
      break
    }
    return text.trimmed
  }

  static func bullets(from text: String) -> [String] {
    text
      .components(separatedBy: .newlines)
      .map { line in
        var value = line.trimmed
        while value.hasPrefix("-") || value.hasPrefix("•") || value.hasPrefix("*") {
          value = String(value.dropFirst()).trimmed
        }
        return value
      }
      .filter { !$0.isEmpty }
  }
}
