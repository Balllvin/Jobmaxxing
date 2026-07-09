import Foundation

struct HermesNativeCommand: Identifiable, Hashable {
  let id: String
  let title: String
  let detail: String
  let category: String
  let aliases: [String]
  let argsHint: String
  let subcommands: [String]
  let cliOnly: Bool
  let gatewayOnly: Bool

  init(
    id: String,
    title: String,
    detail: String,
    category: String,
    aliases: [String],
    argsHint: String = "",
    subcommands: [String] = [],
    cliOnly: Bool = false,
    gatewayOnly: Bool = false
  ) {
    self.id = id
    self.title = title
    self.detail = detail
    self.category = category
    self.aliases = aliases
    self.argsHint = argsHint
    self.subcommands = subcommands
    self.cliOnly = cliOnly
    self.gatewayOnly = gatewayOnly
  }

  var tokens: [String] {
    [id] + aliases
  }
}

enum HermesNativeCommandCatalog {
  private static let fallbackCommands: [HermesNativeCommand] = [
    HermesNativeCommand(id: "new", title: "New", detail: "Start a new session (fresh session ID + history) (usage: /new [name])", category: "Session", aliases: ["reset"]),
    HermesNativeCommand(id: "topic", title: "Topic", detail: "Manage topic sessions", category: "Session", aliases: []),
    HermesNativeCommand(id: "clear", title: "Clear", detail: "Clear screen and start a new session", category: "Session", aliases: []),
    HermesNativeCommand(id: "redraw", title: "Redraw", detail: "Force a full UI repaint (recovers from terminal drift)", category: "Session", aliases: []),
    HermesNativeCommand(id: "history", title: "History", detail: "Show conversation history", category: "Session", aliases: []),
    HermesNativeCommand(id: "save", title: "Save", detail: "Save the current conversation", category: "Session", aliases: []),
    HermesNativeCommand(id: "retry", title: "Retry", detail: "Retry the last message (resend to agent)", category: "Session", aliases: []),
    HermesNativeCommand(id: "undo", title: "Undo", detail: "Back up N user turns and re-prompt (default 1) (usage: /undo [N])", category: "Session", aliases: []),
    HermesNativeCommand(id: "title", title: "Title", detail: "Set a title for the current session (usage: /title [name])", category: "Session", aliases: []),
    HermesNativeCommand(id: "handoff", title: "Handoff", detail: "Hand off this session to a messaging platform (Telegram, Discord, etc.) (usage: /handoff <platform>)", category: "Session", aliases: []),
    HermesNativeCommand(id: "branch", title: "Branch", detail: "Branch the current session (explore a different path) (usage: /branch [name])", category: "Session", aliases: ["fork"]),
    HermesNativeCommand(id: "compress", title: "Compress", detail: "Compress conversation context (add 'here [N]' to keep recent N turns; --preview shows what would happen) (usage: /compress [here [N] | focus topic | --preview|--dry-run])", category: "Session", aliases: ["compact"]),
    HermesNativeCommand(id: "rollback", title: "Rollback", detail: "List or restore filesystem checkpoints (usage: /rollback [number])", category: "Session", aliases: []),
    HermesNativeCommand(id: "snapshot", title: "Snapshot", detail: "Create or restore state snapshots of Hermes config/state (usage: /snapshot [create|restore <id>|prune])", category: "Session", aliases: ["snap"]),
    HermesNativeCommand(id: "stop", title: "Stop", detail: "Kill all running background processes", category: "Session", aliases: []),
    HermesNativeCommand(id: "approve", title: "Approve", detail: "Approve a pending dangerous command (usage: /approve [session|always])", category: "Session", aliases: []),
    HermesNativeCommand(id: "deny", title: "Deny", detail: "Deny a pending dangerous command (optionally with a reason) (usage: /deny [all] [reason])", category: "Session", aliases: []),
    HermesNativeCommand(id: "background", title: "Background", detail: "Run a prompt in the background (usage: /background <prompt>)", category: "Session", aliases: ["bg", "btw"]),
    HermesNativeCommand(id: "agents", title: "Agents", detail: "Show active agents and running tasks", category: "Session", aliases: ["tasks"]),
    HermesNativeCommand(id: "queue", title: "Queue", detail: "Queue a prompt for the next turn (doesn't interrupt) (usage: /queue <prompt>)", category: "Session", aliases: ["q"]),
    HermesNativeCommand(id: "steer", title: "Steer", detail: "Inject a message after the next tool call without interrupting (usage: /steer <prompt>)", category: "Session", aliases: []),
    HermesNativeCommand(id: "goal", title: "Goal", detail: "Set a standing goal Hermes works on across turns until achieved (usage: /goal [text | draft <text> | show | pause | resume | clear | status | wait <pid> | unwait])", category: "Session", aliases: []),
    HermesNativeCommand(id: "subgoal", title: "Subgoal", detail: "Add or manage extra criteria on the active goal (usage: /subgoal [text | remove N | clear])", category: "Session", aliases: []),
    HermesNativeCommand(id: "status", title: "Status", detail: "Show session, model, token, and context info", category: "Session", aliases: []),
    HermesNativeCommand(id: "whoami", title: "Whoami", detail: "Show your slash command access (admin / user)", category: "Info", aliases: []),
    HermesNativeCommand(id: "profile", title: "Profile", detail: "Show active profile name and home directory", category: "Info", aliases: []),
    HermesNativeCommand(id: "sethome", title: "Sethome", detail: "Set this chat as the home channel", category: "Session", aliases: ["set-home"]),
    HermesNativeCommand(id: "resume", title: "Resume", detail: "Resume a previously-named session (usage: /resume [name])", category: "Session", aliases: []),
    HermesNativeCommand(id: "sessions", title: "Sessions", detail: "Browse and resume previous sessions", category: "Session", aliases: []),
    HermesNativeCommand(id: "config", title: "Config", detail: "Show current configuration", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "model", title: "Model", detail: "Switch model (persists by default) (usage: /model [model] [--provider name] [--global|--session] [--refresh])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "gquota", title: "Gquota", detail: "Show Google Gemini quota status", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "personality", title: "Personality", detail: "Set a predefined personality (usage: /personality [name])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "statusbar", title: "Statusbar", detail: "Toggle the context/model status bar", category: "Configuration", aliases: ["sb"]),
    HermesNativeCommand(id: "verbose", title: "Verbose", detail: "Cycle tool progress display: off -> new -> all -> verbose -> log", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "footer", title: "Footer", detail: "Toggle gateway runtime-metadata footer on final replies (usage: /footer [on|off|status])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "yolo", title: "Yolo", detail: "Toggle YOLO mode (skip all dangerous command approvals)", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "reasoning", title: "Reasoning", detail: "Manage reasoning effort and display (usage: /reasoning [level|show|hide|full|clamp])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "fast", title: "Fast", detail: "Toggle fast mode - OpenAI Priority Processing / Anthropic Fast Mode (Normal/Fast) (usage: /fast [normal|fast|status])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "skin", title: "Skin", detail: "Show or change the display skin/theme (usage: /skin [name])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "indicator", title: "Indicator", detail: "Pick the TUI busy-indicator style (usage: /indicator [kaomoji|emoji|unicode|ascii])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "voice", title: "Voice", detail: "Toggle voice mode (usage: /voice [on|off|tts|status])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "busy", title: "Busy", detail: "Control what Enter does while Hermes is working (usage: /busy [queue|steer|interrupt|status])", category: "Configuration", aliases: []),
    HermesNativeCommand(id: "tools", title: "Tools", detail: "Manage tools: /tools [list|disable|enable] [name...] (usage: /tools [list|disable|enable] [name...])", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "toolsets", title: "Toolsets", detail: "List available toolsets", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "skills", title: "Skills", detail: "Search, install, inspect, or manage skills", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "cron", title: "Cron", detail: "Manage scheduled tasks (usage: /cron [subcommand])", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "curator", title: "Curator", detail: "Background skill maintenance (status, run, pin, archive, list-archived) (usage: /curator [subcommand])", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "kanban", title: "Kanban", detail: "Multi-profile collaboration board (tasks, links, comments) (usage: /kanban [subcommand])", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "reload", title: "Reload", detail: "Reload .env variables into the running session", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "reload-mcp", title: "Reload Mcp", detail: "Reload MCP servers from config", category: "Tools & Skills", aliases: ["reload_mcp"]),
    HermesNativeCommand(id: "reload-skills", title: "Reload Skills", detail: "Re-scan ~/.hermes/skills/ for newly installed or removed skills", category: "Tools & Skills", aliases: ["reload_skills"]),
    HermesNativeCommand(id: "browser", title: "Browser", detail: "Connect browser tools to your live Chromium-family browser via CDP (usage: /browser [connect|disconnect|status])", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "plugins", title: "Plugins", detail: "List installed plugins and their status", category: "Tools & Skills", aliases: []),
    HermesNativeCommand(id: "commands", title: "Commands", detail: "Browse all commands and skills (paginated) (usage: /commands [page])", category: "Info", aliases: []),
    HermesNativeCommand(id: "help", title: "Help", detail: "Show available commands", category: "Info", aliases: []),
    HermesNativeCommand(id: "restart", title: "Restart", detail: "Gracefully restart the gateway after draining active runs", category: "Session", aliases: []),
    HermesNativeCommand(id: "usage", title: "Usage", detail: "Show token usage and rate limits for the current session", category: "Info", aliases: []),
    HermesNativeCommand(id: "insights", title: "Insights", detail: "Show usage insights and analytics (usage: /insights [days])", category: "Info", aliases: []),
    HermesNativeCommand(id: "platforms", title: "Platforms", detail: "Show gateway/messaging platform status", category: "Info", aliases: ["gateway"]),
    HermesNativeCommand(id: "copy", title: "Copy", detail: "Copy the last assistant response to clipboard (usage: /copy [number])", category: "Info", aliases: []),
    HermesNativeCommand(id: "paste", title: "Paste", detail: "Attach clipboard image from your clipboard", category: "Info", aliases: []),
    HermesNativeCommand(id: "image", title: "Image", detail: "Attach a local image file for your next prompt (usage: /image <path>)", category: "Info", aliases: []),
    HermesNativeCommand(id: "update", title: "Update", detail: "Update Hermes Agent to the latest version", category: "Info", aliases: []),
    HermesNativeCommand(id: "debug", title: "Debug", detail: "Upload debug report (system info + logs) and get shareable links (usage: /debug [nous|local])", category: "Info", aliases: []),
    HermesNativeCommand(id: "quit", title: "Quit", detail: "Exit the CLI (use --delete to also remove session history) (usage: /quit [--delete])", category: "Exit", aliases: ["exit"])
  ]

  static let commands: [HermesNativeCommand] = loadCommands()
  static let commandIDs = commands.map(\.id)
  static let visibleTitles = commands.map(\.title)

  private struct CommandCatalogPayload: Decodable {
    let commands: [CommandPayload]
  }

  private struct CommandPayload: Decodable {
    let id: String
    let title: String?
    let detail: String
    let category: String
    let aliases: [String]?
    let argsHint: String?
    let subcommands: [String]?
    let cliOnly: Bool?
    let gatewayOnly: Bool?

    var nativeCommand: HermesNativeCommand? {
      let normalizedID = id.trimmed.lowercased()
      guard !normalizedID.isEmpty else { return nil }
      let cleanTitle = (title ?? "").trimmed
      let cleanDetail = detail.trimmed
      let cleanCategory = category.trimmed
      return HermesNativeCommand(
        id: normalizedID,
        title: cleanTitle.isEmpty ? HermesNativeCommandCatalog.generatedTitle(for: normalizedID) : cleanTitle,
        detail: cleanDetail.isEmpty ? "Hermes command" : cleanDetail,
        category: cleanCategory.isEmpty ? "Hermes" : cleanCategory,
        aliases: aliases ?? [],
        argsHint: argsHint ?? "",
        subcommands: subcommands ?? [],
        cliOnly: cliOnly ?? false,
        gatewayOnly: gatewayOnly ?? false
      )
    }
  }

  private static func loadCommands() -> [HermesNativeCommand] {
    for url in commandCatalogURLs() {
      guard let data = try? Data(contentsOf: url),
            let payload = try? JSONDecoder().decode(CommandCatalogPayload.self, from: data) else { continue }
      let loaded = uniquedCommands(payload.commands.compactMap(\.nativeCommand))
      if !loaded.isEmpty {
        return loaded
      }
    }
    return fallbackCommands
  }

  private static func commandCatalogURLs() -> [URL] {
    var urls: [URL] = []
    let environment = ProcessInfo.processInfo.environment
    if let explicit = environment["JOBMAXXING_HERMES_COMMANDS"]?.trimmed, !explicit.isEmpty {
      urls.append(URL(fileURLWithPath: explicit))
    }
    urls.append(
      URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".jobmaxxing")
        .appendingPathComponent("hermes-layer")
        .appendingPathComponent("hermes-commands.json")
    )
    if let repoRoot = RepoRootResolver.find() {
      urls.append(
        repoRoot
          .appendingPathComponent("hermes")
          .appendingPathComponent("hermes-commands.json")
      )
    }
    return urls
  }

  private static func uniquedCommands(_ commands: [HermesNativeCommand]) -> [HermesNativeCommand] {
    var seen = Set<String>()
    return commands.filter { command in
      guard !seen.contains(command.id) else { return false }
      seen.insert(command.id)
      return true
    }
  }
  static let persistentSessionCommandIDs: Set<String> = [
    "approve",
    "background",
    "branch",
    "busy",
    "clear",
    "commands",
    "compress",
    "copy",
    "deny",
    "handoff",
    "history",
    "image",
    "new",
    "paste",
    "queue",
    "redraw",
    "restart",
    "resume",
    "rollback",
    "save",
    "sessions",
    "sethome",
    "snapshot",
    "steer",
    "stop",
    "title",
    "topic",
    "undo",
    "yolo"
  ]

  static func requiresPersistentSession(_ id: String) -> Bool {
    guard let command = command(id: id) else { return false }
    return persistentSessionCommandIDs.contains(command.id)
  }

  static func resolve(_ rawID: String) -> String? {
    let normalized = rawID.trimmed.lowercased()
    guard !normalized.isEmpty else { return nil }
    return commands.first { command in
      command.id == normalized || command.aliases.contains(normalized)
    }?.id
  }

  static func command(id: String) -> HermesNativeCommand? {
    let canonical = resolve(id) ?? id.trimmed.lowercased()
    return commands.first { $0.id == canonical }
  }

  static func title(for id: String) -> String {
    command(id: id)?.title ?? generatedTitle(for: id)
  }

  static func commandID(from text: String) -> String? {
    let trimmed = text.trimmed
    guard !trimmed.isEmpty else { return nil }
    if trimmed.hasPrefix("/") {
      let token = trimmed.dropFirst().split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
      let normalized = token.trimmed.lowercased()
      guard !normalized.isEmpty else { return nil }
      return resolve(normalized) ?? normalized
    }
    return commands.first { command in
      startsWithVisibleCommand(command, text: trimmed)
    }?.id
  }

  private static func generatedTitle(for id: String) -> String {
    id
      .replacingOccurrences(of: "_", with: "-")
      .split(separator: "-")
      .map { word in String(word.prefix(1)).uppercased() + String(word.dropFirst()) }
      .joined(separator: " ")
  }

  static func commandText(commandID: String, rawText: String, visibleText: String) -> String {
    let raw = rawText.trimmed
    if raw.hasPrefix("/") {
      return raw
    }
    let visible = visibleText.trimmed
    guard let command = command(id: commandID) else {
      return raw.isEmpty ? "/\(commandID)" : raw
    }
    let payload = payloadAfterVisibleCommand(command, text: visible)
      ?? payloadAfterVisibleCommand(command, text: raw)
      ?? ""
    return payload.isEmpty ? "/\(command.id)" : "/\(command.id) \(payload)"
  }

  private static func startsWithVisibleCommand(_ command: HermesNativeCommand, text: String) -> Bool {
    guard text.localizedCaseInsensitiveCompare(command.title) == .orderedSame
      || text.lowercased().hasPrefix(command.title.lowercased() + " ") else { return false }
    return true
  }

  private static func payloadAfterVisibleCommand(_ command: HermesNativeCommand, text: String) -> String? {
    let trimmed = text.trimmed
    if trimmed.localizedCaseInsensitiveCompare(command.title) == .orderedSame {
      return ""
    }
    let prefix = command.title + " "
    guard trimmed.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
    return String(trimmed.dropFirst(prefix.count)).trimmed
  }
}
