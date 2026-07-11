import Foundation

struct HermesHighAgentRequest {
  var userText: String
  var visibleUserText: String
  var commandID: String?
  var route: ModelRoute
  var context: String
  var attachmentTitles: [String]
  var updateCommand: String
}

struct HermesHighAgentResult {
  var text: String
  var traces: [HermesTraceStep]
}

enum HermesHighAgentRunner {
  typealias ProgressHandler = @MainActor (HermesHighAgentResult) -> Void
  private static let nativeSession = HermesNativeCLISession()

  static func respond(to request: HermesHighAgentRequest, progress: ProgressHandler? = nil) async -> HermesHighAgentResult {
    if request.commandID == "update" {
      return await runUpdate(command: request.updateCommand, progress: progress)
    }
    if let commandID = request.commandID {
      return await runSlashCommand(commandID: commandID, request: request, progress: progress)
    }
    return await runHermesMessage(request: request, progress: progress)
  }

  private static func runHermesMessage(request: HermesHighAgentRequest, progress: ProgressHandler?) async -> HermesHighAgentResult {
    await nativeSession.runTurn(
      input: sessionPrompt(for: request),
      displayTool: "hermes chat --cli -Q",
      commandID: nil,
      timeout: 240,
      progress: progress
    )
  }

  private static func sessionPrompt(for request: HermesHighAgentRequest) -> String {
    var promptParts = [
      "Reply to the user in Markdown from the live Hermes session.",
      "Use the installed Jobmaxxing layer, MCP tools, saved evidence, and safety policy.",
      "Do not expose CLI progress as the final answer.",
      "User message: \(oneLine(request.visibleUserText))",
      "Jobmaxxing context: \(oneLine(request.context))"
    ]
    if !request.attachmentTitles.isEmpty {
      promptParts.append("Attachments: \(request.attachmentTitles.joined(separator: ", "))")
    }
    return promptParts.joined(separator: " ").trimmed
  }

  private static func oneLine(_ value: String) -> String {
    value
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private static func runSlashCommand(
    commandID: String,
    request: HermesHighAgentRequest,
    progress: ProgressHandler?
  ) async -> HermesHighAgentResult {
    let commandText = HermesNativeCommandCatalog.commandText(
      commandID: commandID,
      rawText: request.userText,
      visibleText: request.visibleUserText
    )
    return await nativeSession.runTurn(
      input: commandText,
      displayTool: commandText,
      commandID: commandID,
      timeout: commandID == "queue" ? 300 : 120,
      progress: progress
    )
  }

  private static func runUpdate(command: String, progress: ProgressHandler?) async -> HermesHighAgentResult {
    let result = await runRepoScript(command, timeout: 600) { partialOutput in
      await progress?(HermesHighAgentResult(
        text: "",
        traces: [
          trace(
            "Hermes update",
            tool: command,
            status: "running",
            detail: progressDetail(from: partialOutput, fallback: "Running the official Hermes update path.")
          )
        ]
      ))
    }
    let output = cleanedOutput(result.output)
    if result.exitCode != 0 {
      return failure(hermesFailureMessage(from: output, exitCode: result.exitCode), tool: command)
    }
    return HermesHighAgentResult(
      text: output.trimmed.isEmpty ? "Update finished." : output,
      traces: [
        trace("Hermes update", tool: command, detail: "Ran the official Hermes update path and reinstalled the Jobmaxxing layer.")
      ]
    )
  }

  private static func runRepoScript(
    _ repoRelativePath: String,
    timeout: TimeInterval,
    progress: (@Sendable (String) async -> Void)? = nil
  ) async -> ProcessResult {
    await Task.detached {
      guard let repoRoot = RepoRootResolver.find() else {
        return ProcessResult(exitCode: -1, output: "Could not find repository root from app bundle.")
      }
      let scriptURL = repoRoot.appendingPathComponent(repoRelativePath)
      guard FileManager.default.fileExists(atPath: scriptURL.path) else {
        return ProcessResult(exitCode: -1, output: "Script not found: \(scriptURL.path)")
      }
      let result = await run(ProcessCommand(
        executableURL: URL(fileURLWithPath: "/bin/bash"),
        arguments: [scriptURL.path],
        stdin: nil,
        currentDirectoryURL: repoRoot,
        timeout: timeout,
        progress: progress
      ))
      return result
    }.value
  }

  fileprivate static func hermesExecutableURL() -> URL? {
    let environment = ProcessInfo.processInfo.environment
    let candidates = [
      environment["HERMES_BIN"],
      "\(NSHomeDirectory())/.local/bin/hermes",
      "/opt/homebrew/bin/hermes",
      "/usr/local/bin/hermes"
    ].compactMap { $0?.trimmed }.filter { !$0.isEmpty }
    return candidates
      .map { URL(fileURLWithPath: $0) }
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }

  static func usefulSlashOutput(_ output: String, commandText: String) -> String {
    let rawLines = output
      .components(separatedBy: .newlines)
      .map(\.trimmed)
      .filter { !$0.isEmpty }
    let commandIndex = rawLines.lastIndex { line in
      line == commandText || line.contains(commandText) || line.hasSuffix(commandText)
    }
    let resultSlice = commandIndex.map { rawLines.dropFirst($0 + 1) } ?? rawLines[...]
    let lines = resultSlice.filter { line in
      !line.isEmpty
        && !line.hasPrefix("╭")
        && !line.hasPrefix("╰")
        && !line.hasPrefix("│")
        && !line.hasPrefix("─")
        && !line.hasPrefix("❯")
        && !line.hasPrefix("⚕")
        && !line.hasPrefix("●")
        && !line.hasPrefix("Hermes Agent v")
        && !line.hasPrefix("Welcome to Hermes Agent")
        && !line.hasPrefix("Warning: Input is not a terminal")
        && !line.hasPrefix("Session:")
        && !line.hasPrefix("Resume this session")
        && !line.hasPrefix("Duration:")
        && !line.hasPrefix("Messages:")
        && !line.hasPrefix("Goodbye")
        && !line.hasPrefix("Shutting down")
        && !line.contains("Shutting down")
        && !line.hasPrefix("to customize.")
        && !line.contains("Available Tools")
        && !line.contains("Available Skills")
        && !line.contains("Type your message or /help")
        && !line.contains("legacy OpenClaw")
        && !line.contains("Tip:")
        && line != "/quit"
        && line != "⚙️  /quit"
    }
    let joined = lines.joined(separator: "\n").trimmed
    return joined.isEmpty ? "Done." : joined
  }

  static func cleanedOutput(_ output: String) -> String {
    output
      .replacingOccurrences(of: #"\x1B\[[0-9;?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\x1B\][^\u{0007}]*(\u{0007}|\x1B\\)"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: "\u{001B}", with: "")
      .replacingOccurrences(of: #"\r"#, with: "\n", options: .regularExpression)
      .components(separatedBy: .newlines)
      .map { $0.trimmed }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
      .trimmed
  }

  static func progressDetail(from output: String, fallback: String) -> String {
    let cleaned = cleanedOutput(output)
    guard !cleaned.isEmpty else { return fallback }
    return cleaned.components(separatedBy: .newlines).suffix(12).joined(separator: "\n")
  }

  fileprivate static func hermesFailureMessage(from diagnostic: String, exitCode: Int32) -> String {
    let detail = diagnostic.trimmed.isEmpty ? "No Hermes output." : cleanedOutput(diagnostic)
    return "Hermes failed with exit \(exitCode).\n\n\(detail)"
  }

  private struct ProcessCommand {
    var executableURL: URL
    var arguments: [String]
    var stdin: String?
    var currentDirectoryURL: URL
    var timeout: TimeInterval
    var progress: (@Sendable (String) async -> Void)? = nil
  }

  private struct ProcessResult {
    var exitCode: Int32
    var output: String
  }

  private static func run(
    _ command: ProcessCommand,
    progress: (@Sendable (String) async -> Void)? = nil
  ) async -> ProcessResult {
    await Task.detached {
      let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("jobmaxxing-hermes-\(UUID().uuidString).log")
      FileManager.default.createFile(atPath: outputURL.path, contents: nil)
      guard let outputHandle = try? FileHandle(forWritingTo: outputURL) else {
        return ProcessResult(exitCode: -1, output: "Could not create process output file.")
      }
      defer {
        try? outputHandle.close()
        try? FileManager.default.removeItem(at: outputURL)
      }

      let process = Process()
      process.executableURL = command.executableURL
      process.arguments = command.arguments
      process.currentDirectoryURL = command.currentDirectoryURL

      let inputPipe = Pipe()
      process.standardOutput = outputHandle
      process.standardError = outputHandle
      if command.stdin != nil {
        process.standardInput = inputPipe
      }

      do {
        try process.run()
      } catch {
        return ProcessResult(exitCode: -1, output: error.localizedDescription)
      }

      if let stdin = command.stdin {
        inputPipe.fileHandleForWriting.write(Data(stdin.utf8))
        try? inputPipe.fileHandleForWriting.close()
      }

      let progressHandler = progress ?? command.progress
      let deadline = Date().addingTimeInterval(command.timeout)
      var lastProgress = ""
      var lastProgressEmit = Date.distantPast
      var nextProgressRead = Date.distantPast
      while process.isRunning && Date() < deadline {
        if let progressHandler, Date() >= nextProgressRead {
          nextProgressRead = Date().addingTimeInterval(0.75)
          try? outputHandle.synchronize()
          let data = (try? Data(contentsOf: outputURL)) ?? Data()
          let output = String(data: data, encoding: .utf8)?.trimmed ?? ""
          let shouldHeartbeat = Date().timeIntervalSince(lastProgressEmit) >= 2
          if output != lastProgress || shouldHeartbeat {
            lastProgress = output
            lastProgressEmit = Date()
            await progressHandler(output)
          }
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
      }
      if process.isRunning {
        process.interrupt()
        try? await Task.sleep(nanoseconds: 500_000_000)
        if process.isRunning {
          process.terminate()
        }
        return ProcessResult(exitCode: -2, output: "Timed out running \(command.executableURL.lastPathComponent).")
      }
      try? outputHandle.synchronize()
      let data = (try? Data(contentsOf: outputURL)) ?? Data()
      return ProcessResult(
        exitCode: process.terminationStatus,
        output: String(data: data, encoding: .utf8)?.trimmed ?? ""
      )
    }.value
  }

  fileprivate static func failure(_ text: String, tool: String) -> HermesHighAgentResult {
    HermesHighAgentResult(text: text, traces: [trace("Hermes", tool: tool, status: "failed", detail: text)])
  }

  fileprivate static func trace(_ label: String, tool: String, status: String = "complete", detail: String) -> HermesTraceStep {
    HermesTraceStep(
      id: UUID().uuidString,
      label: label,
      status: status,
      toolName: tool,
      detail: detail
    )
  }
}

private actor HermesNativeCLISession {
  private var process: Process?
  private var inputPipe: Pipe?
  private var outputURL: URL?
  private var outputHandle: FileHandle?
  private var turnInProgress = false

  func runTurn(
    input: String,
    displayTool: String,
    commandID: String?,
    timeout: TimeInterval,
    progress: HermesHighAgentRunner.ProgressHandler?
  ) async -> HermesHighAgentResult {
    let commandText = input.trimmed
    guard !commandText.isEmpty else {
      return HermesHighAgentRunner.failure("Nothing was sent to Hermes.", tool: displayTool)
    }

    guard beginTurn() else {
      return HermesHighAgentRunner.failure(
        "Hermes is already working on another request. Wait for it to finish, then try again.",
        tool: displayTool
      )
    }
    defer { turnInProgress = false }

    guard !Task.isCancelled else {
      return HermesHighAgentRunner.failure("Hermes request cancelled.", tool: displayTool)
    }

    guard await startIfNeeded() else {
      return HermesHighAgentRunner.failure(
        "Hermes is not available to the native app. Install Hermes or set HERMES_BIN to the executable path.",
        tool: "hermes chat --cli -Q"
      )
    }
    guard let inputPipe, let outputURL else {
      return HermesHighAgentRunner.failure("Hermes session did not expose stdin/stdout.", tool: "hermes chat --cli -Q")
    }

    let startOffset = fileSize(outputURL)
    let sentinel = shouldAppendStatusSentinel(commandID: commandID) ? "\n/status" : ""
    let wireText = commandText + sentinel + "\n"
    inputPipe.fileHandleForWriting.write(Data(wireText.utf8))

    return await collectTurnOutput(
      from: startOffset,
      input: commandText,
      displayTool: displayTool,
      commandID: commandID,
      timeout: timeout,
      progress: progress
    )
  }

  private func beginTurn() -> Bool {
    guard !turnInProgress else { return false }
    turnInProgress = true
    return true
  }

  private func startIfNeeded() async -> Bool {
    if process?.isRunning == true {
      return true
    }
    stop()
    guard let repoRoot = RepoRootResolver.find(),
          let hermesURL = HermesHighAgentRunner.hermesExecutableURL() else {
      return false
    }

    let nextOutputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("jobmaxxing-hermes-session-\(UUID().uuidString).log")
    FileManager.default.createFile(atPath: nextOutputURL.path, contents: nil)
    guard let outputHandle = try? FileHandle(forWritingTo: nextOutputURL) else {
      return false
    }

    let nextInputPipe = Pipe()
    let nextProcess = Process()
    nextProcess.executableURL = hermesURL
    nextProcess.arguments = ["chat", "--cli", "-Q"]
    nextProcess.currentDirectoryURL = repoRoot
    nextProcess.standardInput = nextInputPipe
    nextProcess.standardOutput = outputHandle
    nextProcess.standardError = outputHandle
    nextProcess.environment = sessionEnvironment(repoRoot: repoRoot)

    do {
      try nextProcess.run()
    } catch {
      try? outputHandle.close()
      try? FileManager.default.removeItem(at: nextOutputURL)
      return false
    }

    process = nextProcess
    inputPipe = nextInputPipe
    outputURL = nextOutputURL
    self.outputHandle = outputHandle
    try? await Task.sleep(nanoseconds: 1_500_000_000)
    return nextProcess.isRunning
  }

  private func collectTurnOutput(
    from startOffset: UInt64,
    input: String,
    displayTool: String,
    commandID: String?,
    timeout: TimeInterval,
    progress: HermesHighAgentRunner.ProgressHandler?
  ) async -> HermesHighAgentResult {
    guard let outputURL else {
      return HermesHighAgentRunner.failure("Hermes output log was unavailable.", tool: displayTool)
    }

    guard let readHandle = try? FileHandle(forReadingFrom: outputURL) else {
      return HermesHighAgentRunner.failure("Hermes output log could not be opened.", tool: displayTool)
    }
    defer { try? readHandle.close() }
    do {
      try readHandle.seek(toOffset: startOffset)
    } catch {
      return HermesHighAgentRunner.failure("Hermes output log could not be read: \(error.localizedDescription)", tool: displayTool)
    }

    let deadline = Date().addingTimeInterval(timeout)
    var raw = ""
    var lastChange = Date()
    var lastProgressEmit = Date.distantPast
    while Date() < deadline {
      if Task.isCancelled {
        stop()
        return HermesHighAgentRunner.failure("Hermes request cancelled.", tool: displayTool)
      }
      let nextData = (try? readHandle.readToEnd()) ?? Data()
      if !nextData.isEmpty {
        raw.append(String(decoding: nextData, as: UTF8.self))
        lastChange = Date()
      }
      if Date().timeIntervalSince(lastProgressEmit) >= 2 {
        lastProgressEmit = Date()
        await progress?(HermesHighAgentResult(
          text: "",
          traces: [
            HermesHighAgentRunner.trace(
              "Hermes live session",
              tool: displayTool,
              status: "running",
              detail: HermesHighAgentRunner.progressDetail(
                from: raw,
                fallback: "Waiting for the live Hermes session."
              )
            )
          ]
        ))
      }
      if isTurnComplete(raw, commandID: commandID, idleFor: Date().timeIntervalSince(lastChange)) {
        return result(from: raw, input: input, displayTool: displayTool, commandID: commandID)
      }
      if process?.isRunning != true {
        return result(from: raw, input: input, displayTool: displayTool, commandID: commandID)
      }
      do {
        try await Task.sleep(nanoseconds: 200_000_000)
      } catch {
        stop()
        return HermesHighAgentRunner.failure("Hermes request cancelled.", tool: displayTool)
      }
    }

    stop()
    return HermesHighAgentRunner.failure(
      "Timed out waiting for the live Hermes session to finish this turn.",
      tool: displayTool
    )
  }

  private func result(from raw: String, input: String, displayTool: String, commandID: String?) -> HermesHighAgentResult {
    let text = displayText(from: raw, input: input, commandID: commandID)
    return HermesHighAgentResult(
      text: text.isEmpty ? "Hermes finished without a visible reply." : text,
      traces: [
        HermesHighAgentRunner.trace(
          "Hermes live session",
          tool: displayTool,
          detail: "Ran through one persistent official Hermes CLI session."
        )
      ]
    )
  }

  private func shouldAppendStatusSentinel(commandID: String?) -> Bool {
    commandID != "status" && commandID != "quit" && commandID != "update"
  }

  private func isTurnComplete(_ raw: String, commandID: String?, idleFor: TimeInterval) -> Bool {
    if commandID == "quit" {
      return process?.isRunning != true || raw.contains("Goodbye")
    }
    if shouldAppendStatusSentinel(commandID: commandID) {
      return raw.contains("Hermes CLI Status") && idleFor >= 1.0
    }
    if commandID == "status" {
      return raw.contains("Hermes CLI Status") && idleFor >= 1.0
    }
    return idleFor >= 4.0 && !HermesHighAgentRunner.cleanedOutput(raw).isEmpty
  }

  private func displayText(from raw: String, input: String, commandID: String?) -> String {
    let cleaned = HermesHighAgentRunner.cleanedOutput(raw)
    if commandID == "status" {
      return statusOutput(from: cleaned)
    }

    let lines = cleaned.components(separatedBy: .newlines)
    let beforeStatus = lines.prefix { line in
      !line.contains("/status") && line != "Hermes CLI Status"
    }
    let withoutEcho = dropCommandEcho(Array(beforeStatus), input: input)
    return usefulOutput(from: withoutEcho, commandText: input)
  }

  private func statusOutput(from cleaned: String) -> String {
    let lines = cleaned.components(separatedBy: .newlines)
    guard let statusIndex = lines.lastIndex(of: "Hermes CLI Status") else {
      return usefulOutput(from: lines, commandText: "/status")
    }
    return lines[statusIndex...]
      .filter { line in
        !line.contains("/quit")
          && !line.contains("Shutting down")
          && !line.contains("Goodbye")
      }
      .joined(separator: "\n")
      .trimmed
  }

  private func dropCommandEcho(_ lines: [String], input: String) -> [String] {
    let inputPrefix = String(input.prefix(80))
    guard let commandIndex = lines.lastIndex(where: { line in
      line == input || line.contains(inputPrefix) || line.hasSuffix(inputPrefix)
    }) else {
      return lines
    }
    return Array(lines.dropFirst(commandIndex + 1))
  }

  private func usefulOutput(from lines: [String], commandText: String) -> String {
    let filtered = lines.filter { line in
      !line.isEmpty
        && !line.hasPrefix("╭")
        && !line.hasPrefix("╰")
        && !line.hasPrefix("│")
        && !line.hasPrefix("─")
        && !line.hasPrefix("❯")
        && !line.hasPrefix("⚕")
        && !line.hasPrefix("●")
        && !line.hasPrefix("Hermes Agent v")
        && !line.hasPrefix("Welcome to Hermes Agent")
        && !line.hasPrefix("Warning: Input is not a terminal")
        && !line.hasPrefix("Session:")
        && !line.hasPrefix("Resume this session")
        && !line.hasPrefix("Duration:")
        && !line.hasPrefix("Messages:")
        && !line.hasPrefix("Goodbye")
        && !line.hasPrefix("Shutting down")
        && !line.contains("Shutting down")
        && !line.hasPrefix("to customize.")
        && !line.contains("Available Tools")
        && !line.contains("Available Skills")
        && !line.contains("Type your message or /help")
        && !line.contains("legacy OpenClaw")
        && !line.contains("Tip:")
        && line != commandText
    }
    return filtered.joined(separator: "\n").trimmed
  }

  private func sessionEnvironment(repoRoot: URL) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    let configuredLayerHome = environment["JOBMAXXING_HERMES_LAYER_HOME"]?.trimmed
    let layerHome = configuredLayerHome?.isEmpty == false
      ? configuredLayerHome!
      : "\(NSHomeDirectory())/.jobmaxxing/hermes-layer"
    environment["JOBMAXXING_ROOT"] = repoRoot.path
    environment["JOBMAXXING_MCP_COMMAND"] = "npm run mcp --prefix \(repoRoot.path)"
    environment["JOBMAXXING_HERMES_LAYER"] = "\(layerHome)/jobmaxxing.hermes.json"
    environment["JOBMAXXING_HERMES_SYSTEM_PROMPT"] = "\(layerHome)/prompts/jobmaxxing-system.md"
    return environment
  }

  private func fileSize(_ url: URL) -> UInt64 {
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value
    return size ?? 0
  }

  private func stop() {
    if process?.isRunning == true {
      process?.interrupt()
      process?.terminate()
    }
    try? inputPipe?.fileHandleForWriting.close()
    try? outputHandle?.close()
    if let outputURL {
      try? FileManager.default.removeItem(at: outputURL)
    }
    process = nil
    inputPipe = nil
    outputURL = nil
    outputHandle = nil
  }
}
