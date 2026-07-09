import Foundation

enum RepoRootResolver {
  static func find(from bundleURL: URL = Bundle.main.bundleURL) -> URL? {
    var candidate = bundleURL.deletingLastPathComponent()
    for _ in 0..<8 {
      if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("scripts/install_codex_mcp.sh").path) {
        return candidate
      }
      candidate.deleteLastPathComponent()
    }
    return nil
  }
}
