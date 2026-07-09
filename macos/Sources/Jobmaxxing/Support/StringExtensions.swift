import Foundation

extension String {
  var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func bounded(to limit: Int) -> String {
    guard count > limit else { return self }
    return String(prefix(limit))
  }
}

extension Array where Element == String {
  var compactJoined: String {
    filter { !$0.trimmed.isEmpty }.joined(separator: ", ")
  }

  var uniqued: [String] {
    var seen = Set<String>()
    return filter { value in
      let key = value.lowercased()
      guard !seen.contains(key) else { return false }
      seen.insert(key)
      return true
    }
  }
}
