import Foundation

struct LocalScriptRunResult: Hashable {
  var output: String
  var exitCode: Int32
  var didTimeOut: Bool
  var wasCancelled: Bool

  var displayText: String {
    if wasCancelled {
      return output.trimmed.isEmpty ? "Cancelled." : "Cancelled.\n\(output.trimmed)"
    }
    if didTimeOut {
      return output.trimmed.isEmpty ? "ERROR: Timed out." : "ERROR: Timed out.\n\(output.trimmed)"
    }
    if exitCode == 0 {
      return output.trimmed.isEmpty ? "Finished." : output.trimmed
    }
    return output.trimmed.isEmpty ? "Command failed with exit \(exitCode)." : output.trimmed
  }
}

private final class LocalScriptRunOperation: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var cancelled = false

  var isCancelled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return cancelled
  }

  func setProcess(_ process: Process) {
    lock.lock()
    if cancelled {
      process.terminate()
    } else {
      self.process = process
    }
    lock.unlock()
  }

  func cancel() {
    lock.lock()
    cancelled = true
    let runningProcess = process
    lock.unlock()

    guard runningProcess?.isRunning == true else { return }
    runningProcess?.interrupt()
    Thread.sleep(forTimeInterval: 0.2)
    if runningProcess?.isRunning == true {
      runningProcess?.terminate()
    }
  }
}

enum LocalScriptRunner {
  static func runAsync(repoRelativePath: String, arguments: [String] = [], timeout: TimeInterval = 120) async -> LocalScriptRunResult {
    guard let repoRoot = RepoRootResolver.find() else {
      return LocalScriptRunResult(output: "Could not find repository root from app bundle.", exitCode: -1, didTimeOut: false, wasCancelled: false)
    }

    let scriptURL = repoRoot.appendingPathComponent(repoRelativePath)
    guard FileManager.default.fileExists(atPath: scriptURL.path) else {
      return LocalScriptRunResult(output: "Script not found: \(scriptURL.path)", exitCode: -1, didTimeOut: false, wasCancelled: false)
    }

    return await runAsync(
      executable: "/bin/bash",
      arguments: [scriptURL.path] + arguments,
      currentDirectoryURL: repoRoot,
      timeout: timeout
    )
  }

  static func run(repoRelativePath: String, arguments: [String] = [], timeout: TimeInterval? = nil) -> String {
    guard let repoRoot = RepoRootResolver.find() else {
      return "Could not find repository root from app bundle."
    }

    let scriptURL = repoRoot.appendingPathComponent(repoRelativePath)
    guard FileManager.default.fileExists(atPath: scriptURL.path) else {
      return "Script not found: \(scriptURL.path)"
    }

    return run(executable: "/bin/bash", arguments: [scriptURL.path] + arguments, currentDirectoryURL: repoRoot, timeout: timeout)
  }

  static func runAsync(
    executable: String,
    arguments: [String] = [],
    currentDirectoryURL: URL? = nil,
    timeout: TimeInterval = 120
  ) async -> LocalScriptRunResult {
    let operation = LocalScriptRunOperation()
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
          continuation.resume(returning: runResult(
            executable: executable,
            arguments: arguments,
            currentDirectoryURL: currentDirectoryURL,
            timeout: timeout,
            operation: operation
          ))
        }
      }
    } onCancel: {
      operation.cancel()
    }
  }

  static func run(
    executable: String,
    arguments: [String] = [],
    currentDirectoryURL: URL? = nil,
    timeout: TimeInterval? = nil
  ) -> String {
    runResult(
      executable: executable,
      arguments: arguments,
      currentDirectoryURL: currentDirectoryURL,
      timeout: timeout,
      operation: nil
    ).displayText
  }

  private static func runResult(
    executable: String,
    arguments: [String],
    currentDirectoryURL: URL?,
    timeout: TimeInterval?,
    operation: LocalScriptRunOperation?
  ) -> LocalScriptRunResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectoryURL

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      operation?.setProcess(process)
      if let timeout {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline && operation?.isCancelled != true {
          Thread.sleep(forTimeInterval: 0.1)
        }
        if operation?.isCancelled == true {
          stop(process)
          return LocalScriptRunResult(output: readOutput(from: pipe), exitCode: process.terminationStatus, didTimeOut: false, wasCancelled: true)
        }
        if process.isRunning {
          stop(process)
          return LocalScriptRunResult(output: readOutput(from: pipe), exitCode: process.terminationStatus, didTimeOut: true, wasCancelled: false)
        }
      } else {
        process.waitUntilExit()
      }
      return LocalScriptRunResult(output: readOutput(from: pipe), exitCode: process.terminationStatus, didTimeOut: false, wasCancelled: false)
    } catch {
      return LocalScriptRunResult(output: error.localizedDescription, exitCode: -1, didTimeOut: false, wasCancelled: operation?.isCancelled == true)
    }
  }

  private static func stop(_ process: Process) {
    process.interrupt()
    Thread.sleep(forTimeInterval: 0.3)
    if process.isRunning {
      process.terminate()
    }
  }

  private static func readOutput(from pipe: Pipe) -> String {
    String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmed ?? ""
  }
}
