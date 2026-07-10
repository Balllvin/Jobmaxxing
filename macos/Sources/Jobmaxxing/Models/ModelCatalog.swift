import Foundation

struct ModelChoice: Identifiable, Hashable, Codable {
  let id: String
  let label: String
  let detail: String
  let reasoningLevels: [ReasoningChoice]

  init(id: String, label: String, detail: String, reasoningLevels: [ReasoningChoice] = []) {
    self.id = id
    self.label = label
    self.detail = detail
    self.reasoningLevels = reasoningLevels
  }
}

struct ReasoningChoice: Identifiable, Hashable, Codable {
  let id: String
  let label: String
  let detail: String
}

enum ModelDiscoveryKind: Hashable {
  case openAICompatible
  case openCodeCLI(providerID: String)
  case unavailable
}

struct ModelProviderChoice: Identifiable, Hashable {
  let id: String
  let name: String
  let group: String
  let baseURL: String
  let keyReference: String
  let setupHint: String
  let aliases: [String]
  let models: [ModelChoice]
  let discovery: ModelDiscoveryKind

  func matches(route: ModelRoute) -> Bool {
    let provider = route.provider.lowercased()
    return provider == name.lowercased() || aliases.contains(provider)
  }
}

enum ModelCatalog {
  static let openAIReasoningLevels = [
    ReasoningChoice(id: "none", label: "none", detail: "No reasoning where the selected OpenAI model supports it."),
    ReasoningChoice(id: "minimal", label: "minimal", detail: "Smallest reasoning budget."),
    ReasoningChoice(id: "low", label: "low", detail: "Faster and cheaper reasoning."),
    ReasoningChoice(id: "medium", label: "medium", detail: "Default balanced reasoning."),
    ReasoningChoice(id: "high", label: "high", detail: "Higher reasoning budget for important work."),
    ReasoningChoice(id: "xhigh", label: "xhigh", detail: "Highest OpenAI reasoning setting for supported models.")
  ]

  static let deepSeekReasoningLevels = [
    ReasoningChoice(id: "low", label: "low", detail: "OpenCode DeepSeek low reasoning effort."),
    ReasoningChoice(id: "medium", label: "medium", detail: "OpenCode DeepSeek medium reasoning effort."),
    ReasoningChoice(id: "high", label: "high", detail: "OpenCode DeepSeek high reasoning effort."),
    ReasoningChoice(id: "max", label: "max", detail: "OpenCode DeepSeek maximum reasoning effort.")
  ]

  static let grokReasoningLevels = [
    ReasoningChoice(id: "low", label: "low", detail: "Faster Grok reasoning."),
    ReasoningChoice(id: "medium", label: "medium", detail: "Balanced Grok reasoning."),
    ReasoningChoice(id: "high", label: "high", detail: "Higher Grok reasoning budget for important work.")
  ]

  static let providers: [ModelProviderChoice] = [
    ModelProviderChoice(
      id: "openai",
      name: "OpenAI",
      group: "Cloud model provider",
      baseURL: "https://api.openai.com/v1",
      keyReference: "OPENAI_API_KEY",
      setupHint: "Connect OpenAI, then refresh the models available to your account.",
      aliases: ["openai api"],
      models: [
        ModelChoice(
          id: "gpt-5.5",
          label: "GPT-5.5",
          detail: "Default writing and final-review model.",
          reasoningLevels: openAIReasoningLevels
        ),
        ModelChoice(id: "gpt-5.5-pro", label: "GPT-5.5 Pro", detail: "OpenAI reasoning model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.4", label: "GPT-5.4", detail: "OpenAI reasoning model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.4-mini", label: "GPT-5.4 Mini", detail: "OpenAI reasoning model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.4-nano", label: "GPT-5.4 Nano", detail: "OpenAI reasoning model.", reasoningLevels: openAIReasoningLevels)
      ],
      discovery: .openAICompatible
    ),
    ModelProviderChoice(
      id: "xai",
      name: "xAI",
      group: "Cloud model provider",
      baseURL: "https://api.x.ai/v1",
      keyReference: "XAI_API_KEY or Grok/Hermes OAuth",
      setupHint: "Connect xAI, then refresh the models available to your account.",
      aliases: ["grok", "x-ai", "x.ai", "xai-oauth", "grok-oauth", "grok build"],
      models: [
        ModelChoice(
          id: "grok-4.5",
          label: "Grok 4.5",
          detail: "Default Grok Build and xAI chat model.",
          reasoningLevels: grokReasoningLevels
        ),
        ModelChoice(
          id: "grok-4.3",
          label: "Grok 4.3",
          detail: "xAI Grok 4.3 for writing and review routes.",
          reasoningLevels: grokReasoningLevels
        ),
        ModelChoice(
          id: "grok-build-0.1",
          label: "Grok Build 0.1",
          detail: "xAI coding model.",
          reasoningLevels: grokReasoningLevels
        )
      ],
      discovery: .openAICompatible
    ),
    ModelProviderChoice(
      id: "opencode-go",
      name: "OpenCode Go",
      group: "OpenCode subscription",
      baseURL: "https://opencode.ai/zen/go/v1",
      keyReference: "OPENCODE_GO_API_KEY",
      setupHint: "In OpenCode, run /connect and choose OpenCode Go. Then refresh this catalog.",
      aliases: ["opencode go", "opencode-go"],
      models: [
        ModelChoice(id: "glm-5.2", label: "GLM-5.2", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "glm-5.1", label: "GLM-5.1", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "kimi-k2.7-code", label: "Kimi K2.7 Code", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "kimi-k2.6", label: "Kimi K2.6", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "mimo-v2.5", label: "MiMo-V2.5", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "mimo-v2.5-pro", label: "MiMo-V2.5-Pro", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "minimax-m3", label: "MiniMax M3", detail: "OpenCode Go model.", reasoningLevels: []),
        ModelChoice(id: "minimax-m2.7", label: "MiniMax M2.7", detail: "OpenCode Go model.", reasoningLevels: []),
        ModelChoice(id: "minimax-m2.5", label: "MiniMax M2.5", detail: "OpenCode Go model.", reasoningLevels: []),
        ModelChoice(id: "qwen3.7-max", label: "Qwen3.7 Max", detail: "OpenCode Go model.", reasoningLevels: []),
        ModelChoice(id: "qwen3.7-plus", label: "Qwen3.7 Plus", detail: "OpenCode Go model.", reasoningLevels: []),
        ModelChoice(id: "qwen3.6-plus", label: "Qwen3.6 Plus", detail: "OpenCode Go model.", reasoningLevels: []),
        ModelChoice(id: "deepseek-v4-pro", label: "DeepSeek V4 Pro", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "deepseek-v4-flash", label: "DeepSeek V4 Flash", detail: "OpenCode Go model.", reasoningLevels: deepSeekReasoningLevels)
      ],
      discovery: .openCodeCLI(providerID: "opencode-go")
    ),
    ModelProviderChoice(
      id: "opencode-zen",
      name: "OpenCode Zen",
      group: "OpenCode API",
      baseURL: "https://opencode.ai/zen/v1",
      keyReference: "OPENCODE_ZEN_API_KEY",
      setupHint: "In OpenCode, run /connect and choose OpenCode Zen. Then refresh this catalog.",
      aliases: ["opencode zen", "opencode-zen"],
      models: [
        ModelChoice(id: "gpt-5.5", label: "GPT-5.5", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.5-pro", label: "GPT-5.5 Pro", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.4", label: "GPT-5.4", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.4-pro", label: "GPT-5.4 Pro", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.4-mini", label: "GPT-5.4 Mini", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.4-nano", label: "GPT-5.4 Nano", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.3-codex", label: "GPT-5.3 Codex", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.3-codex-spark", label: "GPT-5.3 Codex Spark", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.2", label: "GPT-5.2", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.2-codex", label: "GPT-5.2 Codex", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.1", label: "GPT-5.1", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.1-codex", label: "GPT-5.1 Codex", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.1-codex-max", label: "GPT-5.1 Codex Max", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5.1-codex-mini", label: "GPT-5.1 Codex Mini", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5", label: "GPT-5", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5-codex", label: "GPT-5 Codex", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "gpt-5-nano", label: "GPT-5 Nano", detail: "OpenCode Zen model.", reasoningLevels: openAIReasoningLevels),
        ModelChoice(id: "claude-fable-5", label: "Claude Fable 5", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-opus-4-8", label: "Claude Opus 4.8", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-opus-4-7", label: "Claude Opus 4.7", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-opus-4-6", label: "Claude Opus 4.6", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-opus-4-5", label: "Claude Opus 4.5", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-sonnet-5", label: "Claude Sonnet 5", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-sonnet-4-6", label: "Claude Sonnet 4.6", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-sonnet-4-5", label: "Claude Sonnet 4.5", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "claude-haiku-4-5", label: "Claude Haiku 4.5", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "gemini-3.5-flash", label: "Gemini 3.5 Flash", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "gemini-3.1-pro", label: "Gemini 3.1 Pro", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "gemini-3-flash", label: "Gemini 3 Flash", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "qwen3.7-max", label: "Qwen3.7 Max", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "qwen3.7-plus", label: "Qwen3.7 Plus", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "qwen3.6-plus", label: "Qwen3.6 Plus", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "qwen3.5-plus", label: "Qwen3.5 Plus", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "deepseek-v4-pro", label: "DeepSeek V4 Pro", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "deepseek-v4-flash", label: "DeepSeek V4 Flash", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "minimax-m3", label: "MiniMax M3", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "minimax-m2.7", label: "MiniMax M2.7", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "minimax-m2.5", label: "MiniMax M2.5", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "glm-5.2", label: "GLM-5.2", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "glm-5.1", label: "GLM-5.1", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "glm-5", label: "GLM-5", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "kimi-k2.7-code", label: "Kimi K2.7 Code", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "kimi-k2.6", label: "Kimi K2.6", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "kimi-k2.5", label: "Kimi K2.5", detail: "OpenCode Zen model.", reasoningLevels: deepSeekReasoningLevels),
        ModelChoice(id: "grok-4.5", label: "Grok 4.5", detail: "OpenCode Zen model.", reasoningLevels: grokReasoningLevels),
        ModelChoice(id: "grok-build-0.1", label: "Grok Build 0.1", detail: "OpenCode Zen model.", reasoningLevels: grokReasoningLevels),
        ModelChoice(id: "big-pickle", label: "Big Pickle", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "mimo-v2.5-free", label: "MiMo-V2.5 Free", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "north-mini-code-free", label: "North Mini Code Free", detail: "OpenCode Zen model.", reasoningLevels: []),
        ModelChoice(id: "nemotron-3-ultra-free", label: "Nemotron 3 Ultra Free", detail: "OpenCode Zen model.", reasoningLevels: [])
      ],
      discovery: .openCodeCLI(providerID: "opencode")
    ),
    ModelProviderChoice(
      id: "cursor",
      name: "Cursor",
      group: "Local editor agent",
      baseURL: "cursor://local",
      keyReference: "Cursor account",
      setupHint: "Use Cursor only when a route should call the local Cursor agent programmatically.",
      aliases: ["cursor agent"],
      models: [
        ModelChoice(id: "cursor", label: "Cursor Agent", detail: "Cursor account model selected by the local Cursor agent CLI.")
      ],
      discovery: .unavailable
    )
  ]

  static func provider(for route: ModelRoute) -> ModelProviderChoice {
    providers.first(where: { $0.matches(route: route) })
      ?? providers[0]
  }

  static func provider(id: String) -> ModelProviderChoice? {
    providers.first { $0.id == id }
  }

  static func model(for route: ModelRoute) -> ModelChoice? {
    let provider = provider(for: route)
    return provider.models.first { $0.id == route.model }
  }

  static func models(for provider: ModelProviderChoice, inventory: ModelInventory?, retaining modelID: String? = nil) -> [ModelChoice] {
    let known = provider.models
    let discovered = (inventory?.modelIDs ?? []).map { id in
      ModelChoice(id: id, label: id, detail: "Available from this configured provider.")
    }
    var byID = Dictionary(uniqueKeysWithValues: known.map { ($0.id, $0) })
    for model in discovered where byID[model.id] == nil {
      byID[model.id] = model
    }
    if let modelID, !modelID.trimmed.isEmpty, byID[modelID] == nil {
      byID[modelID] = ModelChoice(id: modelID, label: modelID, detail: "Saved model. Refresh this provider before changing it.")
    }
    return byID.values.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
  }

  static func reasoningLevels(for route: ModelRoute) -> [ReasoningChoice] {
    model(for: route)?.reasoningLevels ?? []
  }

  static func defaultReasoning(for route: ModelRoute) -> String? {
    let levels = reasoningLevels(for: route)
    guard !levels.isEmpty else { return nil }
    if let current = route.reasoningEffort, levels.contains(where: { $0.id == current }) {
      return current
    }
    return levels.first?.id
  }
}
