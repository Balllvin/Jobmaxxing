import AppKit
import Foundation

struct ExternalOpenResult: Hashable {
  let ok: Bool
  let message: String
}

enum ExternalURL {
  static func normalizedWebURL(_ rawValue: String) -> URL? {
    let trimmed = rawValue.trimmed
    guard !trimmed.isEmpty else { return nil }
    let candidate = trimmed.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression) == nil
      ? "https://\(trimmed)"
      : trimmed
    guard let url = URL(string: candidate),
          let scheme = url.scheme?.lowercased(),
          ["http", "https"].contains(scheme),
          url.host?.trimmed.isEmpty == false else {
      return nil
    }
    return url
  }

  @discardableResult
  static func openWebURL(_ rawValue: String, label: String = "URL") -> ExternalOpenResult {
    guard let url = normalizedWebURL(rawValue) else {
      return ExternalOpenResult(ok: false, message: "\(label) is not a valid http or https URL.")
    }
    if NSWorkspace.shared.open(url) {
      return ExternalOpenResult(ok: true, message: "Opened \(url.absoluteString)")
    }
    return ExternalOpenResult(ok: false, message: "macOS could not open \(url.absoluteString).")
  }

  @discardableResult
  static func openWebURLInChrome(_ rawValue: String, label: String = "URL") -> ExternalOpenResult {
    guard let url = normalizedWebURL(rawValue) else {
      return ExternalOpenResult(ok: false, message: "\(label) is not a valid http or https URL.")
    }
    guard let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") else {
      return openWebURL(url.absoluteString, label: label)
    }
    NSWorkspace.shared.open(
      [url],
      withApplicationAt: chromeURL,
      configuration: NSWorkspace.OpenConfiguration()
    )
    return ExternalOpenResult(ok: true, message: "Opened \(url.absoluteString) in Chrome.")
  }
}
