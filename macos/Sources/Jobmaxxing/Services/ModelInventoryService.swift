import Foundation

enum ModelInventoryService {
  static func discover(provider: ModelProviderChoice, keyReference: String? = nil) async throws -> [String] {
    switch provider.discovery {
    case .openAICompatible:
      return try await discoverOpenAICompatible(provider: provider, keyReference: keyReference)
    case let .openCodeCLI(providerID):
      return try await discoverOpenCode(providerID: providerID)
    case .unavailable:
      throw ModelInventoryError.message("This provider does not expose a model catalog to Jobmaxxing.")
    }
  }

  static func modelIDs(fromOpenCodeOutput output: String, providerID: String) -> [String] {
    let prefix = "\(providerID)/"
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._:-"))
    let ids = output.components(separatedBy: .whitespacesAndNewlines).compactMap { token -> String? in
      guard let range = token.range(of: prefix) else { return nil }
      let candidate = token[range.upperBound...]
      let id = String(candidate.unicodeScalars.prefix { allowed.contains($0) })
      return id.trimmed.isEmpty ? nil : id
    }
    return ids.uniqued.sorted()
  }

  private static func discoverOpenAICompatible(provider: ModelProviderChoice, keyReference: String?) async throws -> [String] {
    let configuredKeyReference = keyReference?.trimmed ?? ""
    let resolvedKeyReference = configuredKeyReference.isEmpty ? provider.keyReference : configuredKeyReference
    guard let token = apiToken(for: provider, keyReference: resolvedKeyReference), !token.trimmed.isEmpty else {
      throw ModelInventoryError.message("Set \(resolvedKeyReference) before refreshing this catalog.")
    }
    guard let url = URL(string: provider.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/models") else {
      throw ModelInventoryError.message("The \(provider.name) models URL is invalid.")
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
      throw ModelInventoryError.message("\(provider.name) returned HTTP \(status) while listing models.")
    }
    let decoded = try JSONDecoder().decode(OpenAICompatibleModels.self, from: data)
    let ids = decoded.data.map(\.id).filter { !$0.trimmed.isEmpty }.uniqued.sorted()
    guard !ids.isEmpty else {
      throw ModelInventoryError.message("\(provider.name) returned no models for this account.")
    }
    return ids
  }

  private static func discoverOpenCode(providerID: String) async throws -> [String] {
    let executable = FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.opencode/bin/opencode")
      ? "\(NSHomeDirectory())/.opencode/bin/opencode"
      : "/usr/bin/env"
    let arguments = executable == "/usr/bin/env"
      ? ["opencode", "models", providerID, "--refresh"]
      : ["models", providerID, "--refresh"]
    let result = await LocalScriptRunner.runAsync(executable: executable, arguments: arguments, timeout: 30)
    guard result.exitCode == 0, !result.didTimeOut else {
      throw ModelInventoryError.message("OpenCode could not refresh \(providerID). \(result.displayText)")
    }
    let ids = modelIDs(fromOpenCodeOutput: result.output, providerID: providerID)
    guard !ids.isEmpty else {
      throw ModelInventoryError.message("OpenCode did not return models for \(providerID). Run /connect in OpenCode, then try again.")
    }
    return ids
  }

  private static func apiToken(for provider: ModelProviderChoice, keyReference: String) -> String? {
    let environment = ProcessInfo.processInfo.environment
    if let token = environment[keyReference], !token.trimmed.isEmpty {
      return token
    }
    switch provider.id {
    case "openai": return environment["OPENAI_API_KEY"]
    case "xai": return environment["XAI_API_KEY"]
    default: return nil
    }
  }
}

private struct OpenAICompatibleModels: Decodable {
  struct Model: Decodable {
    let id: String
  }

  let data: [Model]
}

private enum ModelInventoryError: LocalizedError {
  case message(String)

  var errorDescription: String? {
    switch self {
    case let .message(value): value
    }
  }
}
