import Foundation

struct ModelChoice: Identifiable, Hashable {
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

struct ReasoningChoice: Identifiable, Hashable {
  let id: String
  let label: String
  let detail: String
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
      setupHint: "Use OpenAI for the Medium and High tiers.",
      aliases: ["openai api"],
      models: [
        ModelChoice(
          id: "gpt-5.5",
          label: "GPT-5.5",
          detail: "Default writing and final-review model.",
          reasoningLevels: openAIReasoningLevels
        )
      ]
    ),
    ModelProviderChoice(
      id: "xai",
      name: "xAI",
      group: "Cloud model provider",
      baseURL: "https://api.x.ai/v1",
      keyReference: "XAI_API_KEY or Grok/Hermes OAuth",
      setupHint: "Use Grok through XAI_API_KEY, Hermes xAI OAuth, or Grok Build login.",
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
          id: "grok-4.20-0309-reasoning",
          label: "Grok 4.20 Reasoning",
          detail: "Higher-reasoning Grok route for important hiring work.",
          reasoningLevels: grokReasoningLevels
        )
      ]
    ),
    ModelProviderChoice(
      id: "opencode",
      name: "OpenCode",
      group: "Local agent bridge",
      baseURL: "http://127.0.0.1:8787/v1",
      keyReference: "Local OpenCode auth",
      setupHint: "Use OpenCode Go for the Light tier.",
      aliases: ["opencode go", "opencode zen"],
      models: [
        ModelChoice(
          id: "deepseek-v4-flash",
          label: "DeepSeek V4 Flash",
          detail: "Available through the local OpenCode Go bridge.",
          reasoningLevels: deepSeekReasoningLevels
        )
      ]
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
      ]
    )
  ]

  static func provider(for route: ModelRoute) -> ModelProviderChoice {
    providers.first(where: { $0.matches(route: route) })
      ?? providers.first { provider in provider.models.contains { $0.id == route.model } }
      ?? providers[0]
  }

  static func provider(id: String) -> ModelProviderChoice? {
    providers.first { $0.id == id }
  }

  static func model(for route: ModelRoute) -> ModelChoice? {
    let provider = provider(for: route)
    return provider.models.first { $0.id == route.model } ?? provider.models.first
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
