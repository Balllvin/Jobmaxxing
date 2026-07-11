import Foundation
import SwiftUI

struct JobmaxxingStorageAlert: Identifiable, Hashable {
  let id = UUID()
  var title: String
  var message: String
}

func connectorAvailabilitySummary(for connectors: [IntegrationConnector]) -> String {
  func displayName(_ connector: IntegrationConnector) -> String {
    connector.id == "hermes" ? "Agent" : connector.label
  }

  func names(matching predicate: (IntegrationConnector) -> Bool) -> String {
    let values = connectors
      .filter { !($0.isHidden ?? false) && predicate($0) }
      .map(displayName)
      .sorted()
    return values.isEmpty ? "none" : values.compactJoined
  }

  let ready = names { $0.isEnabled && $0.isConnected }
  let setup = names { $0.isEnabled && !$0.isConnected }
  let off = names { !$0.isEnabled }
  return "Ready: \(ready). Set up: \(setup). Off: \(off)."
}

func canonicalCredentialReference(from hint: String) -> String? {
  guard let candidate = hint.trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init),
        credentialReferenceHasValidSyntax(candidate) else {
    return nil
  }
  return candidate
}

func isValidCredentialReference(
  _ value: String,
  expectedReference: String? = nil,
  environment: [String: String] = ProcessInfo.processInfo.environment
) -> Bool {
  let reference = value.trimmed
  guard !reference.isEmpty else { return true }
  guard credentialReferenceHasValidSyntax(reference) else { return false }
  if reference == expectedReference?.trimmed { return true }
  return !(environment[reference] ?? "").trimmed.isEmpty
}

private func credentialReferenceHasValidSyntax(_ reference: String) -> Bool {
  let bytes = Array(reference.utf8)
  guard !bytes.isEmpty, bytes.count <= 128 else { return false }
  guard bytes[0] == 95 || (65...90).contains(bytes[0]) else { return false }
  return bytes.dropFirst().allSatisfy { byte in
    byte == 95 || (65...90).contains(byte) || (48...57).contains(byte)
  }
}

private struct StoreLoadResult {
  var state: JobmaxxingState
  var alert: JobmaxxingStorageAlert?
  var shouldPersistMigrations: Bool
}

struct DocumentImportOutcome {
  let importedDocuments: [CandidateDocument]
  let failures: [String]

  var summary: String {
    let importedCount = importedDocuments.count
    let outcome = importedCount == 0
      ? "No files were imported."
      : "Imported \(importedCount) file\(importedCount == 1 ? "" : "s")."
    return failures.isEmpty ? outcome : "\(outcome) \(failures.joined(separator: " "))"
  }
}

@MainActor
final class JobmaxxingStore: ObservableObject {
  private static let minEvidenceRelevance = 2
  private static let slopPhrases = ["excited", "innovative", "cutting-edge", "passionate", "dynamic", "landscape", "thrilled", "seamless", "next-gen", "game-changing", "journey", "realm", "testament"]
  private static let weaselWords = ["might", "could", "should", "various", "several", "very", "really", "significant"]
  private static let unsupportedClaimPhrases = ["strong fit", "great fit", "perfect fit", "relevant experience", "proven track record", "uniquely qualified", "deep experience", "extensive experience", "i can help", "i would bring", "i have shipped", "i have built"]
  private static let stopWords: Set<String> = ["about", "after", "also", "and", "are", "but", "for", "from", "have", "into", "our", "that", "the", "their", "this", "with", "will", "you", "your"]
  private static let maxHermesTranscriptMessages = 160

  @Published private(set) var state: JobmaxxingState
  @Published private(set) var storageAlert: JobmaxxingStorageAlert?
  @Published private(set) var connectorCheckResults: [String: ConnectorCheckResult] = [:]
  @Published private(set) var modelInventoryStatus: [String: String] = [:]
  @Published var selectedJobID: String?
  @Published var selectedDocumentID: String?
  @Published var selectedCompanyID: String?
  @Published var selectedHermesThreadID: String?

  private let fileManager = FileManager.default
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()
  private let stateFileURL: URL?

  init(stateURL: URL? = nil) {
    self.stateFileURL = stateURL
    let loadResult = Self.loadState(from: stateURL)
    state = loadResult.state
    storageAlert = loadResult.alert
    migrateDefaults(persistChanges: loadResult.shouldPersistMigrations)
    selectedJobID = state.jobs.first?.id
    selectedDocumentID = state.documents.first?.id
    selectedCompanyID = companyProfiles.first?.id
    selectedHermesThreadID = hermesChatState.selectedThreadID

    Task { @MainActor [weak self] in
      // Cursor authentication can require launching its CLI. Let the app paint first,
      // then run the bounded probe off the main actor.
      await Task.yield()
      _ = await self?.refreshIntegrationConnector(id: "cursor")
    }
  }

  func clearStorageAlert() {
    storageAlert = nil
  }

  func reportStorageIssue(title: String, message: String) {
    storageAlert = JobmaxxingStorageAlert(title: title, message: message)
  }

  var selectedJob: JobRecord? {
    guard let selectedJobID else { return state.jobs.first }
    return state.jobs.first(where: { $0.id == selectedJobID }) ?? state.jobs.first
  }

  var selectedDocument: CandidateDocument? {
    guard let selectedDocumentID else { return state.documents.first }
    return state.documents.first(where: { $0.id == selectedDocumentID }) ?? state.documents.first
  }

  var companyProfiles: [CompanyProfile] {
    state.companyProfiles ?? []
  }

  var contacts: [ContactRecord] {
    state.contacts ?? []
  }

  var agentRuns: [ResearchAgentRun] {
    state.agentRuns ?? []
  }

  var selectedCompany: CompanyProfile? {
    guard let selectedCompanyID else { return companyProfiles.first }
    return companyProfiles.first(where: { $0.id == selectedCompanyID }) ?? companyProfiles.first
  }

  func contacts(for companyID: String) -> [ContactRecord] {
    contacts
      .filter { contact in
        contact.companyLinks.contains(where: { $0.companyID == companyID })
      }
      .sorted { left, right in
        left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
      }
  }

  func companyName(for companyID: String) -> String {
    companyProfiles.first(where: { $0.id == companyID })?.name ?? companyID
  }

  func agentRuns(forContactID contactID: String) -> [ResearchAgentRun] {
    agentRuns.filter { $0.contextKind == "contact" && $0.contextID == contactID }
  }

  func agentRuns(forCompanyID companyID: String) -> [ResearchAgentRun] {
    let linkedContactIDs = Set(contacts(for: companyID).map(\.id))
    return agentRuns.filter { run in
      (run.contextKind == "company" && run.contextID == companyID)
        || (run.contextKind == "contact" && linkedContactIDs.contains(run.contextID))
    }
  }

  func agentRuns(for contactIDs: [String]) -> [ResearchAgentRun] {
    let ids = Set(contactIDs)
    guard !ids.isEmpty else { return agentRuns }
    return agentRuns.filter { $0.contextKind == "contact" && ids.contains($0.contextID) }
  }

  var enabledModelRoutes: [ModelRoute] {
    state.modelRoutes.filter(\.isEnabled)
  }

  func modelChoices(for provider: ModelProviderChoice, retaining modelID: String? = nil) -> [ModelChoice] {
    let inventory = state.modelInventories?.first(where: { $0.providerID == provider.id })
    return ModelCatalog.models(for: provider, inventory: inventory, retaining: modelID)
  }

  func modelInventoryMessage(for providerID: String) -> String? {
    modelInventoryStatus[providerID]
  }

  func modelKeyReference(for provider: ModelProviderChoice) -> String {
    guard let field = integrationConnectors
      .first(where: { $0.id == provider.id })?
      .configFields?
      .first(where: { $0.id == "api-key-ref" }) else {
      return canonicalCredentialReference(from: provider.keyReference) ?? ""
    }
    let expected = canonicalCredentialReference(from: field.placeholder)
    let configured = field.value.trimmed
    if !configured.isEmpty,
       isValidCredentialReference(configured, expectedReference: expected) {
      return configured
    }
    return expected ?? ""
  }

  func refreshModelInventory(for provider: ModelProviderChoice) async {
    modelInventoryStatus[provider.id] = "Refreshing models…"
    do {
      let modelIDs = try await ModelInventoryService.discover(
        provider: provider,
        keyReference: modelKeyReference(for: provider)
      )
      var inventories = state.modelInventories ?? []
      let next = ModelInventory(providerID: provider.id, modelIDs: modelIDs)
      if let index = inventories.firstIndex(where: { $0.providerID == provider.id }) {
        inventories[index] = next
      } else {
        inventories.append(next)
      }
      state.modelInventories = inventories
      modelInventoryStatus[provider.id] = "\(modelIDs.count) models available."
      persist()
    } catch {
      modelInventoryStatus[provider.id] = error.localizedDescription
    }
  }

  var hermesSettings: HermesSettings {
    state.hermes ?? Self.defaultHermesSettings
  }

  var hermesChatState: HermesChatState {
    state.hermesChat ?? Self.defaultHermesChatState
  }

  var selectedHermesThread: HermesChatThread? {
    let chat = hermesChatState
    return chat.threads.first
  }

  var integrationConnectors: [IntegrationConnector] {
    state.integrationConnectors ?? Self.defaultIntegrationConnectors
  }

  var profileExperience: [ProfileExperience] {
    state.profile.experience ?? Self.defaultProfileExperience
  }

  var profileEducation: [ProfileEducation] {
    state.profile.education ?? []
  }

  var profileSkills: [String] {
    state.profile.skills ?? Self.defaultProfileSkills
  }

  var profileProjects: [ProfileProject] {
    state.profile.profileProjects ?? Self.defaultProfileProjects
  }

  var profileMemory: [ProfileMemory] {
    state.profile.personalMemory ?? Self.defaultProfileMemory
  }

  var competitorApps: [CompetitorApp] {
    state.competitorApps ?? Self.defaultCompetitorApps
  }

  var jobBoardSources: [JobBoardSource] {
    state.jobBoardSources ?? Self.defaultJobBoardSources
  }

  var automationPlaybooks: [AutomationPlaybook] {
    state.automationPlaybooks ?? Self.defaultAutomationPlaybooks
  }

  var marketComplaints: [MarketComplaint] {
    state.marketComplaints ?? Self.defaultMarketComplaints
  }

  func addJob(company: String, role: String, sourceURL: String, description: String, notes: String) {
    let cleanRole = Self.normalizedUserFacingText(role.trimmed)
    let score = score(role: cleanRole, description: description)
    let rawSourceURL = sourceURL.trimmed
    let normalizedSourceURL = ExternalURL.normalizedWebURL(rawSourceURL)?.absoluteString ?? ""
    let sourceRisks = normalizedSourceURL.isEmpty
      ? [rawSourceURL.isEmpty ? "Missing source URL" : "Invalid source URL was not saved"]
      : []
    let job = JobRecord(
      id: UUID().uuidString,
      company: company.trimmed,
      role: cleanRole,
      sourceURL: normalizedSourceURL,
      description: description.trimmed,
      stage: .saved,
      score: score,
      keywords: extractKeywords(from: "\(cleanRole) \(description)").map(Self.normalizedUserFacingText),
      risks: sourceRisks,
      nextActions: ["Attach proof", "Draft application", "Plan browser steps"],
      notes: notes.trimmed,
      draft: nil
    )
    state.jobs.insert(job, at: 0)
    selectedJobID = job.id
    upsertCompanyFromJob(job)
    log(jobID: job.id, actor: "user", title: "Saved role", detail: "\(company) - \(cleanRole)", approval: "not needed")
    persist()
  }

  func updateStage(jobID: String, stage: JobStage) {
    guard let index = state.jobs.firstIndex(where: { $0.id == jobID }) else { return }
    state.jobs[index].stage = stage
    syncCompanyApplication(job: state.jobs[index])
    log(jobID: jobID, actor: "user", title: "Updated stage", detail: stage.label, approval: "not needed")
    persist()
  }

  func updateNotes(jobID: String, notes: String) {
    guard let index = state.jobs.firstIndex(where: { $0.id == jobID }) else { return }
    state.jobs[index].notes = notes
    persist()
  }

  func updateDraftCoverLetter(jobID: String, coverLetter: String) {
    guard let index = state.jobs.firstIndex(where: { $0.id == jobID }), var draft = state.jobs[index].draft else { return }
    draft.coverLetter = coverLetter
    state.jobs[index].draft = Self.normalizedDraftForDisplay(draft)
    persist()
  }

  func updateDraftRecruiterMessage(jobID: String, message: String) {
    guard let index = state.jobs.firstIndex(where: { $0.id == jobID }), var draft = state.jobs[index].draft else { return }
    draft.recruiterMessage = message
    state.jobs[index].draft = Self.normalizedDraftForDisplay(draft)
    persist()
  }

  func updateDraftResumeBullets(jobID: String, bullets: [String]) {
    guard let index = state.jobs.firstIndex(where: { $0.id == jobID }), var draft = state.jobs[index].draft else { return }
    draft.resumeBullets = bullets
    state.jobs[index].draft = Self.normalizedDraftForDisplay(draft)
    persist()
  }

  func updateDraftHeadline(jobID: String, headline: String) {
    guard let index = state.jobs.firstIndex(where: { $0.id == jobID }), var draft = state.jobs[index].draft else { return }
    draft.headline = headline
    state.jobs[index].draft = Self.normalizedDraftForDisplay(draft)
    persist()
  }

  /// Rewrites text from user feedback via Hermes. Returns cleaned text, or `ERROR: …` on failure.
  func rewriteTextWithFeedback(
    currentText: String,
    feedback: String,
    context: String,
    kind: String
  ) async -> String {
    let userFeedback = feedback.trimmed
    guard !userFeedback.isEmpty else {
      return "ERROR: Add feedback first."
    }

    let prompt = TextImproveSupport.rewritePrompt(
      currentText: currentText,
      feedback: userFeedback,
      context: [context.trimmed, hermesHighAgentContext()].filter { !$0.isEmpty }.joined(separator: "\n\n"),
      kind: kind
    )
    let request = hermesHighAgentRequest(
      rawText: prompt,
      visibleText: "Rewrite \(kind.trimmed.isEmpty ? "text" : kind) from user feedback",
      commandID: nil,
      attachments: []
    )
    let result = await HermesHighAgentRunner.respond(to: request)
    if result.traces.contains(where: { $0.status.trimmed.lowercased() == "failed" }) {
      let message = result.text.trimmed.isEmpty ? "Rewrite failed." : result.text.trimmed
      return message.hasPrefix("ERROR:") ? message : "ERROR: \(message)"
    }
    let cleaned = TextImproveSupport.cleanOutput(result.text)
    if cleaned.isEmpty {
      return "ERROR: Rewrite returned empty text."
    }
    if cleaned.lowercased().hasPrefix("error") || cleaned.localizedCaseInsensitiveContains("could not find repository") {
      return cleaned.hasPrefix("ERROR:") ? cleaned : "ERROR: \(cleaned)"
    }
    return cleaned
  }

  func generateDraft(jobID: String) {
    guard let index = state.jobs.firstIndex(where: { $0.id == jobID }) else { return }
    let job = state.jobs[index]
    let evidence = rankedEvidence(for: job)
    let evidenceLines = evidence.map { item in
      item.sourceURL.isEmpty ? "\(item.title): \(item.proof)" : "\(item.title): \(item.proof) (\(item.sourceURL))"
    }
    let links = evidence.compactMap { $0.sourceURL.isEmpty ? nil : $0.sourceURL }
    let strongest = evidence.first
    let secondary = evidence.dropFirst().first
    let keywordLine = job.keywords.prefix(5).joined(separator: ", ")
    let missingEvidence = missingEvidence(for: job, evidence: evidence)
    let assumptions = [
      "Role priorities are inferred from saved job text: \(keywordLine.isEmpty ? "no keywords extracted" : keywordLine)."
    ] + (evidence.isEmpty ? ["No saved evidence is relevant enough to claim strong fit."] : [])
    let headlineProof = evidence.isEmpty ? "evidence gap" : "proof in \(job.keywords.prefix(4).joined(separator: ", "))"
    let claimTrace = evidence.enumerated().flatMap { index, item in
      [
        Self.claimTrace(item: item, claim: "\(item.title): \(item.proof)", location: "resume bullet \(index + 1)"),
        Self.claimTrace(item: item, claim: "\(item.title): \(item.proof)", location: "cover letter evidence \(index + 1)")
      ]
    }
    let coverLetter = [
      "I am interested in \(job.role) at \(job.company) because the saved role text points to \(keywordLine.isEmpty ? "requirements that need proof before applying" : keywordLine).",
      strongest.map { "The clearest proof is \($0.title). \($0.proof)\($0.sourceURL.isEmpty ? "" : " Link: \($0.sourceURL).")" } ?? "",
      secondary.map { "A second relevant example is \($0.title). \($0.proof)\($0.sourceURL.isEmpty ? "" : " Link: \($0.sourceURL).")" } ?? "",
      evidence.isEmpty ? "I should not claim strong fit until a reviewed project, document, or metric supports the role." : "For this role, I would keep each claim tied to saved proof."
    ].filter { !$0.isEmpty }.joined(separator: "\n\n")

    state.jobs[index].draft = ApplicationDraft(
      headline: "\(job.role) candidate with \(headlineProof)",
      resumeBullets: evidenceLines.prefix(4).map { "Built proof: \($0)" },
      coverLetter: coverLetter,
      recruiterMessage: evidence.isEmpty
        ? "Use only after identifying a recruiter or hiring-team contact. Hi, I found \(job.role) at \(job.company). I am checking which saved proof is relevant before making a fit claim."
        : "Use only after identifying a recruiter or hiring-team contact. Hi, I found \(job.role) at \(job.company). I have saved proof in \(evidence.prefix(2).map(\.title).joined(separator: ", ")). Relevant links: \(links.prefix(2).joined(separator: " "))",
      screeningAnswers: [
        "Why this role: the saved role text points to \(job.keywords.prefix(4).joined(separator: ", ")).",
        evidence.isEmpty ? "Why me: do not claim strong fit yet. Add saved evidence that matches the role first." : "Why me: the claim is backed by \(evidence.map(\.title).joined(separator: ", ")).",
        "Anything else: each material claim should stay concise, proof-backed, and useful to the hiring decision."
      ],
      evidenceLinks: links,
      claimTrace: claimTrace,
      assumptions: assumptions,
      missingEvidence: missingEvidence
    )
    state.jobs[index].stage = .drafting
    syncCompanyApplication(job: state.jobs[index])
    addCompanySubmission(
      job: state.jobs[index],
      materialType: "Application draft",
      title: "Proof-linked application pack",
      summary: "Generated headline, resume bullets, cover letter, contact message, screening answers, and evidence links.",
      sourceURL: job.sourceURL,
      status: "Proposed"
    )
    log(jobID: jobID, actor: "codex", title: "Generated draft pack", detail: "Draft uses \(evidence.count) evidence items and \(links.count) links.", approval: "proposed")
    persist()
  }

  func importDocuments(from urls: [URL]) async throws -> DocumentImportOutcome {
    let batch = try await Task.detached(priority: .userInitiated) {
      try DocumentImportPipeline.prepare(urls: urls)
    }.value

    for item in batch.documents {
      state.documents.insert(item.document, at: 0)
      selectedDocumentID = item.document.id
    }
    state.documentIndexStatus = batch.documents.first(where: { !$0.indexStatus.succeeded })?.indexStatus
      ?? batch.documents.last?.indexStatus
    if !batch.documents.isEmpty {
      persist()
    }
    return DocumentImportOutcome(
      importedDocuments: batch.documents.map(\.document),
      failures: batch.failures
    )
  }

  func promoteDocumentToEvidence(documentID: String, title: String, tags: String) {
    guard let document = state.documents.first(where: { $0.id == documentID }) else { return }
    let evidence = EvidenceItem(
      id: UUID().uuidString,
      title: title.trimmed.isEmpty ? document.title : title.trimmed,
      proof: document.summary,
      sourceURL: "file://\(document.filePath)",
      tags: tags.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty },
      strength: 4
    )
    state.profile.evidence.insert(evidence, at: 0)
    if let index = state.documents.firstIndex(where: { $0.id == documentID }) {
      state.documents[index].linkedEvidenceIDs.append(evidence.id)
      indexDocument(state.documents[index])
    }
    persist()
  }

  func updateDocumentTitle(documentID: String, title: String) {
    let cleaned = title.trimmed
    guard !cleaned.isEmpty,
          let index = state.documents.firstIndex(where: { $0.id == documentID }) else { return }
    state.documents[index].title = cleaned
    indexDocument(state.documents[index])
    persist()
  }

  func audit(text: String) -> WritingAuditResult {
    var flags: [String] = []
    var rewriteRules: [String] = []
    let lower = text.lowercased()
    let sentences = Self.sentences(in: text)
    let longSentences = sentences.filter { $0.split(separator: " ").count > 30 }
    let evidenceReferences = Self.evidenceReferences(in: text, evidence: state.profile.evidence)
    let unsupportedClaims = Self.unsupportedClaims(in: sentences, evidence: state.profile.evidence)

    for phrase in Self.slopPhrases where lower.contains(phrase) {
      flags.append("AI-slop phrase: \"\(phrase)\"")
      rewriteRules.append("Replace generic praise with a concrete fact or delete it.")
    }
    for word in Self.weaselWords where Self.containsWord(word, in: lower) {
      flags.append("Weasel word: \"\(word)\"")
      rewriteRules.append("Replace hedges with a direct claim, scope, or uncertainty label.")
    }
    if state.profile.evidence.isEmpty {
      flags.append("No saved evidence is available")
      rewriteRules.append("Add reviewed evidence before making candidate claims.")
    } else if evidenceReferences.isEmpty {
      flags.append("No saved evidence is referenced directly")
      rewriteRules.append("Reference saved evidence or remove the unsupported claim.")
    }
    for claim in unsupportedClaims {
      flags.append("Unsupported claim: \"\(claim)\"")
      rewriteRules.append("Cite saved evidence in the same sentence or label it as an assumption.")
    }
    if !longSentences.isEmpty {
      flags.append("Long sentence")
      rewriteRules.append("Split long sentences into one claim, one proof point, and one next step.")
    }

    let score = max(0, 100 - flags.count * 10 - unsupportedClaims.count * 8)
    let ready = score >= 85 && unsupportedClaims.isEmpty && !evidenceReferences.isEmpty
    let defaultRules = [
      "Name the thing built.",
      "Reference saved evidence or attach file-backed proof.",
      "Use subject-verb-object sentences.",
      "Replace praise with evidence."
    ]
    let auditRules = rewriteRules.isEmpty ? defaultRules : Array(Set(rewriteRules)).sorted()
    let rememberedRules = state.promptMemory.prefix(10).map { "Saved rule: \($0)" }
    return WritingAuditResult(
      score: score,
      ready: ready,
      flags: flags.isEmpty ? ["Ready: concise, direct, and evidence-backed."] : flags,
      rewriteRules: (auditRules + rememberedRules).uniqued,
      unsupportedClaims: unsupportedClaims,
      evidenceReferences: evidenceReferences
    )
  }

  func recordPromptMemory(_ note: String) {
    let trimmed = note.trimmed
    guard !trimmed.isEmpty else { return }
    state.promptMemory.insert(trimmed, at: 0)
    state.promptMemory = Array(state.promptMemory.prefix(20))
    persist()
  }

  func makeBrowserPlan(request: String, sourceURL: String) -> BrowserPlan {
    let rawSourceURL = sourceURL.trimmed
    let normalizedSourceURL = ExternalURL.normalizedWebURL(rawSourceURL)?.absoluteString ?? ""
    if !rawSourceURL.isEmpty && normalizedSourceURL.isEmpty {
      return BrowserPlan(
        risk: "High",
        checkpoint: "Enter a valid http or https source URL before building browser steps.",
        steps: [
          "Replace the unsafe source URL.",
          "Rebuild the browser plan.",
          "Pause before opening any external page."
        ],
        blocked: ["Unsafe source URL", "No browser opening", "No final submit without review"]
      )
    }

    let protectedSite = normalizedSourceURL.lowercased().contains("linkedin") || request.lowercased().contains("linkedin")
    let risk = protectedSite ? "High" : "Medium"
    let blocked = protectedSite && !state.browserPolicy.allowLinkedInAutomation
      ? ["No LinkedIn auto-submit", "No message sending", "No profile changes without review"]
      : ["No final submit without review"]
    let sourceStep = normalizedSourceURL.isEmpty ? "Find or paste the source page." : "Open the validated source page."
    return BrowserPlan(
      risk: risk,
      checkpoint: "User reviews every form field before any external submission.",
      steps: [
        sourceStep,
        "Extract role requirements and recruiter signals.",
        "Prepare fields from the approved draft pack.",
        "Pause for user review before external action.",
        "Log the outcome in the application ledger."
      ],
      blocked: blocked
    )
  }

  private func syncTelegramConnectorFromChatSettings(_ settings: HermesChatSettings) {
    var connectors = integrationConnectors
    guard let index = connectors.firstIndex(where: { $0.id == "telegram" }) else { return }
    connectors[index].configFields = (connectors[index].configFields ?? []).map { field in
      var next = field
      if field.id == "bot-token-ref" {
        next.value = settings.telegramBotTokenReference
      } else if field.id == "chat-id" {
        next.value = settings.telegramChatID
      } else if field.id == "webhook-url" {
        next.value = settings.webhookURL
      }
      return next
    }
    connectors[index].isConnected = Self.detectConnection(for: connectors[index])
    state.integrationConnectors = connectors
  }

  private func syncLegacyTelegramSettings(connectorID: String, fieldID: String, value: String) {
    guard connectorID == "telegram", var chat = state.hermesChat else { return }
    switch fieldID {
    case "bot-token-ref":
      chat.settings.telegramBotTokenReference = value.trimmed
    case "chat-id":
      chat.settings.telegramChatID = value.trimmed
    case "webhook-url":
      chat.settings.webhookURL = value.trimmed
    default:
      return
    }
    state.hermesChat = chat
  }

  private func connectorAvailabilityText() -> String {
    connectorAvailabilitySummary(for: integrationConnectors)
  }

  private func sanitizeHermesChatMessages() -> Bool {
    var chat = Self.normalizedSingleHermesChat(hermesChatState)
    guard let index = chat.threads.firstIndex(where: { $0.id == Self.defaultHermesThreadID }) else { return false }
    let original = chat
    let sanitizedMessages = chat.threads[index].messages.compactMap { message in
      var next = message
      if next.text == "Message Hermes or use a slash command." {
        next.text = "Send a message or attach a file."
      }
      if next.role.lowercased() == "assistant", next.commandID == "plugins" {
        next.text = "Connections checked."
        if let traceIndex = next.traces.firstIndex(where: { $0.toolName == "jobmaxxing_connectors" }) {
          next.traces[traceIndex].detail = connectorAvailabilityText()
        }
      }
      if next.role.lowercased() == "user",
         let commandID = next.commandID,
         next.text == "Connections checked." {
        next.text = Self.displayTitle(forHermesCommandID: commandID)
      }
      if next.role == "assistant" {
        if Self.isHermesProgressPlaceholder(next.text) {
          next.text = next.status == "running" ? "This response stopped before completion. Send it again." : ""
        }
        if let commandID = next.commandID {
          next.text = Self.cleanedLegacyHermesCommandText(next.text, commandID: commandID)
          if commandID == "yolo", next.text.contains("needs a live Hermes session") {
            next.text = "Previous /yolo was not run because the native bridge was not live yet. Send /yolo again to toggle it in the live Hermes session."
          }
          next.traces = next.traces.map { trace in
            var repairedTrace = trace
            if repairedTrace.label == "Agent" {
              repairedTrace.label = "Hermes"
            }
            if repairedTrace.detail == "Ran Agent oneshot through the installed CLI." {
              repairedTrace.detail = "Ran Hermes oneshot through the installed CLI."
            }
            return repairedTrace
          }
        }
        if next.status == "running" {
          next.status = "failed"
          if next.text.trimmed.isEmpty || Self.isHermesProgressPlaceholder(next.text) {
            next.text = "This response stopped before completion. Send it again."
          }
          next.traces = next.traces.map { trace in
            var repairedTrace = trace
            if repairedTrace.status == "running" {
              repairedTrace.status = "failed"
              repairedTrace.detail = "The app stopped before this turn finished."
            }
            return repairedTrace
          }
        }
        next.text = next.text
          .replacingOccurrences(of: Self.legacyBrowserConnectorName, with: "browser")
          .replacingOccurrences(of: "Goal route: ", with: "")
          .replacingOccurrences(of: "Application route: ", with: "")
          .replacingOccurrences(of: "Document route: ", with: "")
          .replacingOccurrences(of: "Browser route: ", with: "")
          .replacingOccurrences(of: "Interview route: ", with: "")
          .replacingOccurrences(of: "source roles,", with: "Source roles,")
        next.traces = next.traces.map(Self.upgradedTraceForDisplay)
      }
      next.attachments = next.attachments ?? []
      return next
    }
    chat.threads[index].messages = Self.boundedHermesMessages(Self.repairedHermesTranscript(sanitizedMessages))
    chat.threads[index].summary = chat.threads[index].messages.last?.text ?? "Ready"
    chat.selectedThreadID = Self.defaultHermesThreadID
    state.hermesChat = chat
    selectedHermesThreadID = Self.defaultHermesThreadID
    return chat != original
  }

  private static func isHermesProgressPlaceholder(_ text: String) -> Bool {
    [
      "Running Hermes.",
      "Updating Hermes.",
      "Running High agent.",
      "Updating Agent."
    ].contains(text.trimmed)
  }

  static func cleanedLegacyHermesCommandText(_ text: String, commandID: String) -> String {
    let lines = text
      .replacingOccurrences(of: #"\x1B\[[0-9;?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\x1B\][^\u{0007}]*(\u{0007}|\x1B\\)"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: "\u{001B}", with: "")
      .components(separatedBy: .newlines)
      .map(\.trimmed)
      .filter { line in
        !line.isEmpty
          && !line.hasPrefix("╭")
          && !line.hasPrefix("╰")
          && !line.hasPrefix("│")
          && !line.hasPrefix("─")
          && !line.hasPrefix("❯")
          && !line.hasPrefix("⚕")
          && !line.hasPrefix("●")
          && !line.hasPrefix("Hermes Agent v")
          && !line.hasPrefix("Agent Agent v")
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
      }
      .map { line in
        line
          .replacingOccurrences(of: "Checking Agent checkout state:", with: "Checking Hermes checkout state:")
          .replacingOccurrences(of: "Checking Agent tracked files:", with: "Checking Hermes tracked files:")
          .replacingOccurrences(of: "Agent checkout", with: "Hermes checkout")
          .replacingOccurrences(of: "Agent git check", with: "Hermes git check")
          .replacingOccurrences(of: "Agent fast-forward", with: "Hermes fast-forward")
          .replacingOccurrences(of: "Jobmaxxing Agent layer", with: "Jobmaxxing Hermes layer")
          .replacingOccurrences(of: "Agent:", with: "Hermes:")
          .replacingOccurrences(of: "Keep Agent configured", with: "Keep Hermes configured")
          .replacingOccurrences(of: "⚡ ", with: "")
          .replacingOccurrences(of: "—", with: "-")
      }
    if commandID == "yolo", lines.contains(where: { $0.contains("YOLO mode") }) {
      return lines.first(where: { $0.contains("YOLO mode") }) ?? "/yolo completed."
    }
    let joined = lines.joined(separator: "\n").trimmed
    return joined.isEmpty ? text.trimmed : joined
  }

  static func repairedHermesTranscript(_ messages: [HermesChatMessage]) -> [HermesChatMessage] {
    var repaired: [HermesChatMessage] = []
    for message in messages {
      if message.role.lowercased() == "assistant",
         message.commandID == nil,
         message.text.hasPrefix("Interpreting “Yolo” as:"),
         let previous = repaired.last,
         previous.role.lowercased() == "user",
         previous.commandID == nil,
         previous.text.trimmed.localizedCaseInsensitiveCompare("Yolo") == .orderedSame {
        repaired.removeLast()
        continue
      }
      if message.role.lowercased() == "assistant",
         let commandID = message.commandID,
         repaired.last?.role.lowercased() != "user" {
        repaired.append(
          HermesChatMessage(
            id: "recovered-user-\(message.id)",
            role: "user",
            text: displayTitle(forHermesCommandID: commandID),
            status: "complete",
            commandID: commandID,
            traces: [],
            attachments: []
          )
        )
      }
      repaired.append(message)
    }
    return repaired
  }

  private static func trace(_ label: String, tool: String, status: String = "complete", detail: String = "") -> HermesTraceStep {
    displaySafeTrace(HermesTraceStep(
      id: UUID().uuidString,
      label: label,
      status: status,
      toolName: tool,
      detail: detail
    ))
  }

  private static func displaySafeTrace(_ trace: HermesTraceStep) -> HermesTraceStep {
    var next = trace
    next.label = next.label
      .replacingOccurrences(of: legacyBrowserConnectorName, with: "browser")
    next.detail = next.detail
      .replacingOccurrences(of: legacyBrowserConnectorName, with: "browser")
    return next
  }

  private static func upgradedTraceForDisplay(_ trace: HermesTraceStep) -> HermesTraceStep {
    var next = displaySafeTrace(trace)
    if next.label.hasPrefix("Command /") {
      let commandID = String(next.label.dropFirst("Command /".count)).trimmed
      next.label = "\(displayTitle(forHermesCommandID: commandID)) selected"
      next.detail = "Used the selected route as metadata for this turn. The transcript stays clean."
      return next
    }
    switch next.label {
    case "Read Jobmaxxing state", "Read local state":
      next.label = "Read local state"
      if !next.detail.contains("Loaded the local job-search state") {
        next.detail = "Loaded the local job-search state before answering: \(next.detail). This keeps the response grounded in saved data."
      }
    case "Set workflow goal":
      next.label = "Set goal"
    case "Load Jobmaxxing Agent layer", "Load agent route":
      next.label = "Prepare reply"
      next.detail = "Checked saved job-search context before answering."
    case "Select Agent toolset":
      next.detail = "Selected only the tools needed for this turn."
    case "Inspect connector inventory":
      next.label = "Check connections"
    case "Command /plugins", "Command /connections":
      next.label = "Connections selected"
      next.detail = "Used the selected route as metadata for this turn. The transcript stays clean."
    case "Reasoning":
      next.label = "Why this route"
    default:
      if next.detail.trimmed.isEmpty {
        next.detail = "Completed."
      }
    }
    return next
  }

  static func hermesCommandID(from text: String) -> String? {
    HermesNativeCommandCatalog.commandID(from: text)
  }

  static func hermesCommandIDs(from text: String) -> [String] {
    var commandIDs: [String] = []
    if let leadingCommand = HermesNativeCommandCatalog.commandID(from: text) {
      commandIDs.append(leadingCommand)
    }

    let nsText = text as NSString
    let fullRange = NSRange(location: 0, length: nsText.length)
    if let rawRegex = try? NSRegularExpression(pattern: #"[/@$]([A-Za-z][A-Za-z0-9_-]*)"#) {
      for match in rawRegex.matches(in: text, range: fullRange) where match.numberOfRanges > 1 {
        let rawID = nsText.substring(with: match.range(at: 1))
        if let commandID = HermesNativeCommandCatalog.resolve(rawID) ?? canonicalHermesCommandID(rawID),
           knownHermesCommandIDs.contains(commandID) {
          commandIDs.append(commandID)
        }
      }
    }

    for commandID in knownHermesCommandIDs {
      let title = displayTitle(forHermesCommandID: commandID)
      let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: title))\b"#
      guard let titleRegex = try? NSRegularExpression(pattern: pattern) else { continue }
      if titleRegex.firstMatch(in: text, range: fullRange) != nil {
        commandIDs.append(commandID)
      }
    }
    return commandIDs.uniqued
  }

  private static func canonicalHermesCommandID(_ rawCommandID: String) -> String? {
    let normalized = rawCommandID.trimmed.lowercased()
    guard !normalized.isEmpty else { return nil }
    switch normalized {
    case "app", "apply":
      return "application"
    case "apps":
      return "applications"
    case "co":
      return "company"
    case "cos":
      return "companies"
    case "person", "people":
      return "contact"
    case "docs", "doc", "files", "file", "proof":
      return "document"
    case "mail", "email":
      return "gmail"
    case "calendar":
      return "outlook"
    default:
      return normalized
    }
  }

  static func displayTitle(forHermesCommandID commandID: String) -> String {
    if let command = HermesNativeCommandCatalog.command(id: commandID) {
      return command.title
    }
    switch commandID.lowercased() {
    case "dashboard":
      return "Dashboard"
    case "chat":
      return "Chat"
    case "goal":
      return "Goal"
    case "company", "companies":
      return "Company"
    case "contact", "contacts":
      return "Contact"
    case "application", "applications", "apply":
      return "Application"
    case "doc", "document", "documents":
      return "Document"
    case "writing":
      return "Writing"
    case "browser":
      return "Browser"
    case "interview", "interviews":
      return "Interview"
    case "telegram":
      return "Telegram"
    case "gmail":
      return "Gmail"
    case "drive":
      return "Drive"
    case "github":
      return "GitHub"
    case "whatsapp":
      return "WhatsApp"
    case "outlook":
      return "Outlook"
    case "plugins", "connections":
      return "Connections"
    case "why":
      return "Why"
    case "update":
      return "Update"
    case "yolo":
      return "Yolo"
    case "status":
      return "Status"
    case "help":
      return "Help"
    case "tools":
      return "Tools"
    case "memory":
      return "Memory"
    case "google-docs":
      return "Google Docs"
    case "google-calendar":
      return "Google Calendar"
    case "google-sheets":
      return "Google Sheets"
    case "google-slides":
      return "Google Slides"
    case "microsoft-365":
      return "Microsoft 365"
    case "onedrive":
      return "OneDrive"
    case "word":
      return "Word"
    case "figma":
      return "Figma"
    case "railway":
      return "Railway"
    case "hugging-face":
      return "Hugging Face"
    case "linear":
      return "Linear"
    case "notion":
      return "Notion"
    case "apple-mail":
      return "Apple Mail"
    case "local-documents":
      return "Local Documents"
    case "openai":
      return "OpenAI"
    case "opencode-go":
      return "OpenCode Go"
    case "opencode-zen":
      return "OpenCode Zen"
    case "cursor":
      return "Cursor"
    default:
      return commandID
        .split(separator: "-")
        .map { word in String(word.prefix(1)).uppercased() + String(word.dropFirst()) }
        .joined(separator: " ")
    }
  }

  static func visibleHermesUserText(_ text: String, commandID: String?, attachments: [CandidateDocument]) -> String {
    let trimmed = text.trimmed
    if !trimmed.isEmpty {
      return trimmed
    }
    if let commandID {
      return displayTitle(forHermesCommandID: commandID)
    }
    if !attachments.isEmpty {
      return "Attached \(attachments.count) file\(attachments.count == 1 ? "" : "s")."
    }
    return ""
  }

  private static let knownHermesCommandIDs = [
    HermesNativeCommandCatalog.commandIDs,
    [
    "goal",
    "connections",
    "why",
    "update",
    "dashboard",
    "chat",
    "application",
    "applications",
    "company",
    "companies",
    "contact",
    "contacts",
    "document",
    "writing",
    "interview",
    "interviews",
    "browser",
    "gmail",
    "drive",
    "github",
    "telegram",
    "whatsapp",
    "outlook"
    ]
  ].flatMap { $0 }.uniqued

  private static func hermesThreadTitle(from prompt: String) -> String {
    let trimmed = prompt.trimmed
    guard !trimmed.isEmpty else { return "New chat" }
    let words = trimmed.split(separator: " ").prefix(7).joined(separator: " ")
    return words.count > 54 ? String(words.prefix(54)) : words
  }

  private static let defaultHermesThreadID = "agent-chat"
  private static let legacyBrowserConnectorName = ["Chro", "me"].joined()

  private static func emptyHermesThread(messages: [HermesChatMessage] = []) -> HermesChatThread {
    let boundedMessages = boundedHermesMessages(messages)
    return HermesChatThread(
      id: defaultHermesThreadID,
      title: "Chat",
      summary: boundedMessages.last?.text ?? "Ready",
      status: "ready",
      sequence: 1,
      messages: boundedMessages
    )
  }

  private static func normalizedSingleHermesChat(_ chat: HermesChatState) -> HermesChatState {
    let messages = chat.threads
      .sorted { $0.sequence < $1.sequence }
      .flatMap(\.messages)
    var next = chat
    let defaultCommandIDs = defaultHermesChatState.settings.enabledCommandIDs
    for commandID in defaultCommandIDs where !next.settings.enabledCommandIDs.contains(commandID) {
      next.settings.enabledCommandIDs.append(commandID)
    }
    next.threads = [emptyHermesThread(messages: messages)]
    next.selectedThreadID = defaultHermesThreadID
    return next
  }

  private static func boundedHermesMessages(_ messages: [HermesChatMessage]) -> [HermesChatMessage] {
    guard messages.count > maxHermesTranscriptMessages else { return messages }
    return Array(messages.suffix(maxHermesTranscriptMessages))
  }

  private static func telegramToken(from reference: String) -> String? {
    let ref = reference.trimmed
    guard !ref.isEmpty else { return nil }
    if let envValue = ProcessInfo.processInfo.environment[ref], !envValue.trimmed.isEmpty {
      return envValue.trimmed
    }
    return nil
  }

  func createInterview(jobID: String, mode: InterviewMode) {
    guard let job = state.jobs.first(where: { $0.id == jobID }) else { return }
    let session = InterviewSession(
      id: UUID().uuidString,
      jobID: jobID,
      mode: mode,
      questions: [
        "Walk me through one shipped system that maps to \(job.role).",
        "What did you build, what changed, and where is the proof?",
        "How would you approach the first week at \(job.company)?",
        "Tell me about a time an automation failed and how you repaired it."
      ],
      scorecard: ["Specific proof", "Clear tradeoffs", "No invented claims", "Concise answer", "Relevant links"],
      notes: ""
    )
    state.interviewSessions.insert(session, at: 0)
    log(jobID: jobID, actor: "codex", title: "Prepared interview", detail: "\(mode.label) practice for \(job.company)", approval: "not needed")
    persist()
  }

  func updateInterviewNotes(sessionID: String, notes: String) {
    guard let index = state.interviewSessions.firstIndex(where: { $0.id == sessionID }) else { return }
    state.interviewSessions[index].notes = notes
    persist()
  }

  @discardableResult
  func updateModelRoute(_ route: ModelRoute) -> Bool {
    guard let index = state.modelRoutes.firstIndex(where: { $0.id == route.id }) else { return false }
    let provider = ModelCatalog.provider(for: route)
    let expectedReference = modelKeyReference(for: provider)
    guard isValidCredentialReference(route.keyReference, expectedReference: expectedReference) else {
      recordCredentialReferenceError(connectorID: provider.id)
      return false
    }
    state.modelRoutes[index] = normalizedModelRoute(route)
    persist()
    return true
  }

  func updateHermesSettings(_ settings: HermesSettings) {
    state.hermes = settings
    persist()
  }

  func updateIntegrationConnector(_ connector: IntegrationConnector) {
    var connectors = integrationConnectors
    if let index = connectors.firstIndex(where: { $0.id == connector.id }) {
      connectors[index] = connector
    } else {
      connectors.append(connector)
    }
    applyIntegrationConnectors(connectors)
  }

  @discardableResult
  func refreshIntegrationConnector(id: String) async -> ConnectorCheckResult {
    var connectors = integrationConnectors
    guard let index = connectors.firstIndex(where: { $0.id == id }) else {
      let missing = ConnectorCheckResult(
        connectorID: id,
        isConnected: false,
        summary: "Connector not found",
        detail: "This connector is not in the local Jobmaxxing list.",
        checkedAt: Date()
      )
      recordConnectorCheck(missing)
      return missing
    }
    var connector = connectors[index]
    let detected = await Self.detectConnectionIncludingProcessProbe(for: connector)
    connector.isConnected = detected
    connectors[index] = connector
    applyIntegrationConnectors(connectors)
    let result = Self.makeConnectorCheckResult(for: connector, isConnected: detected)
    recordConnectorCheck(result)
    return result
  }

  func refreshAllIntegrationConnectors() async {
    var connectors = integrationConnectors
    var results: [String: ConnectorCheckResult] = connectorCheckResults
    let checkedAt = Date()
    for index in connectors.indices {
      let detected = await Self.detectConnectionIncludingProcessProbe(for: connectors[index])
      connectors[index].isConnected = detected
      let result = Self.makeConnectorCheckResult(for: connectors[index], isConnected: detected, checkedAt: checkedAt)
      results[result.connectorID] = result
    }
    applyIntegrationConnectors(connectors)
    connectorCheckResults = results
  }

  @discardableResult
  func updateConnectorConfig(connectorID: String, fieldID: String, value: String) -> Bool {
    var connectors = integrationConnectors
    guard let index = connectors.firstIndex(where: { $0.id == connectorID }) else { return false }
    var fields = connectors[index].configFields ?? []
    guard let fieldIndex = fields.firstIndex(where: { $0.id == fieldID }) else { return false }
    let isSensitiveField = fields[fieldIndex].isSecret
      || fields[fieldIndex].id.contains("token")
      || fields[fieldIndex].id.contains("key")
    let expectedReference = canonicalCredentialReference(from: fields[fieldIndex].placeholder)
    if isSensitiveField,
       !isValidCredentialReference(value, expectedReference: expectedReference) {
      recordCredentialReferenceError(connectorID: connectorID, expectedReference: expectedReference)
      return false
    }
    fields[fieldIndex].value = value
    connectors[index].configFields = fields
    let detected = Self.detectConnection(for: connectors[index])
    connectors[index].isConnected = detected
    syncLegacyTelegramSettings(connectorID: connectorID, fieldID: fieldID, value: value)
    applyIntegrationConnectors(connectors)
    recordConnectorCheck(Self.makeConnectorCheckResult(for: connectors[index], isConnected: detected))
    return true
  }

  func setConnectorHidden(id: String, isHidden: Bool) {
    var connectors = integrationConnectors
    guard let index = connectors.firstIndex(where: { $0.id == id }) else { return }
    connectors[index].isHidden = isHidden
    applyIntegrationConnectors(connectors)
  }

  func disconnectConnector(id: String) {
    var connectors = integrationConnectors
    guard let index = connectors.firstIndex(where: { $0.id == id }) else { return }
    connectors[index].isConnected = false
    connectors[index].isEnabled = false
    connectors[index].configFields = connectors[index].configFields?.map { field in
      var next = field
      if field.isSecret || field.id.contains("token") || field.id.contains("key") {
        next.value = ""
      }
      return next
    }
    var nextState = state
    for routeIndex in nextState.modelRoutes.indices
      where ModelCatalog.provider(for: nextState.modelRoutes[routeIndex]).id == id {
      nextState.modelRoutes[routeIndex].keyReference = ""
    }
    if id == "telegram", var chat = nextState.hermesChat {
      chat.settings.telegramBotTokenReference = ""
      nextState.hermesChat = chat
    }
    state = nextState
    applyIntegrationConnectors(connectors)
    recordConnectorCheck(
      ConnectorCheckResult(
        connectorID: id,
        isConnected: false,
        summary: "Turned off",
        detail: "All locally saved credential references were cleared, and Jobmaxxing will not use this connector until you activate it again.",
        checkedAt: Date()
      )
    )
  }

  func hasSavedCredentialReference(for connectorID: String) -> Bool {
    if let connector = integrationConnectors.first(where: { $0.id == connectorID }),
       (connector.configFields ?? []).contains(where: { field in
         let sensitive = field.isSecret || field.id.contains("token") || field.id.contains("key")
         return sensitive && !field.value.trimmed.isEmpty
       }) {
      return true
    }
    if state.modelRoutes.contains(where: { route in
      ModelCatalog.provider(for: route).id == connectorID && !route.keyReference.trimmed.isEmpty
    }) {
      return true
    }
    return connectorID == "telegram"
      && !(state.hermesChat?.settings.telegramBotTokenReference.trimmed ?? "").isEmpty
  }

  func lastConnectorCheck(for id: String) -> ConnectorCheckResult? {
    connectorCheckResults[id]
  }

  private func applyIntegrationConnectors(_ connectors: [IntegrationConnector]) {
    var next = state
    next.integrationConnectors = connectors
    for index in next.modelRoutes.indices {
      let provider = ModelCatalog.provider(for: next.modelRoutes[index])
      let keyField = connectors
        .first(where: { $0.id == provider.id })?
        .configFields?
        .first(where: { $0.id == "api-key-ref" })
      let configuredKeyReference = keyField?.value.trimmed ?? ""
      let expectedReference = keyField.flatMap { canonicalCredentialReference(from: $0.placeholder) }
      if !configuredKeyReference.isEmpty,
         isValidCredentialReference(configuredKeyReference, expectedReference: expectedReference) {
        next.modelRoutes[index].keyReference = configuredKeyReference
      }
      let isConnected = connectors.first(where: { $0.id == provider.id }).map { $0.isEnabled && $0.isConnected } ?? false
      next.modelRoutes[index].isConnected = isConnected
    }
    // Full state assignment so @Published always notifies SwiftUI for nested connector changes.
    state = next
    persist()
  }

  private func recordConnectorCheck(_ result: ConnectorCheckResult) {
    var next = connectorCheckResults
    next[result.connectorID] = result
    connectorCheckResults = next
  }

  private func recordCredentialReferenceError(connectorID: String, expectedReference: String? = nil) {
    let expected = expectedReference.map { " Use \($0), or another variable already available to this app." } ?? ""
    recordConnectorCheck(
      ConnectorCheckResult(
        connectorID: connectorID,
        isConnected: false,
        summary: "Use an environment variable reference",
        detail: "Raw tokens and API keys are not stored in Jobmaxxing state.\(expected)",
        checkedAt: Date()
      )
    )
  }

  private static func makeConnectorCheckResult(
    for connector: IntegrationConnector,
    isConnected: Bool,
    checkedAt: Date = Date()
  ) -> ConnectorCheckResult {
    if !connector.isEnabled {
      return ConnectorCheckResult(
        connectorID: connector.id,
        isConnected: false,
        summary: "Off",
        detail: "\(connector.label) is off. Activate it, finish setup, then check again.",
        checkedAt: checkedAt
      )
    }
    if isConnected {
      return ConnectorCheckResult(
        connectorID: connector.id,
        isConnected: true,
        summary: "Ready",
        detail: connectorReadyDetail(for: connector),
        checkedAt: checkedAt
      )
    }
    return ConnectorCheckResult(
      connectorID: connector.id,
      isConnected: false,
      summary: "Still needs setup",
      detail: connectorSetupGuidance(for: connector),
      checkedAt: checkedAt
    )
  }

  nonisolated static func connectorSetupGuidance(for connector: IntegrationConnector) -> String {
    switch connector.id {
    case "openai":
      return "Set OPENAI_API_KEY in the environment that launches Jobmaxxing, then press Check setup again."
    case "xai", "grok":
      return "Set XAI_API_KEY, run hermes model with xAI Grok OAuth, or run grok login, then press Check setup again."
    case "opencode-go":
      return "In OpenCode, run /connect, choose OpenCode Go, and finish the sign-in or API-key flow. Then press Check setup again."
    case "opencode-zen":
      return "In OpenCode, run /connect, choose OpenCode Zen, and finish the sign-in or API-key flow. Then press Check setup again."
    case "cursor":
      return "Run Cursor Agent login or set CURSOR_API_KEY, confirm cursor agent models works, then press Check setup again."
    case "hermes":
      return "Install the hermes binary at ~/.local/bin/hermes (or set HERMES_BIN), then press Check setup again."
    case "telegram":
      return "Set a bot token reference and chat ID in the fields below, keep polling off unless you intend live sync, then press Check setup again."
    case "whatsapp":
      return "Open WhatsApp Desktop once so ChatStorage.sqlite exists, confirm the database path below, then press Check setup again."
    case "google-drive", "google-docs", "gmail", "google-calendar", "google-sheets", "google-slides":
      return "Sign in with gcloud application-default credentials, set GOOGLE_APPLICATION_CREDENTIALS / GOOGLE_OAUTH_CLIENT_ID, or enter a profile name below, then press Check setup again."
    case "microsoft-365", "outlook", "onedrive", "word":
      return "Set MICROSOFT_CLIENT_ID or MSGRAPH_CLIENT_ID, or enter tenant/mailbox fields below, then press Check setup again."
    case "github":
      return "Run gh auth login or set GITHUB_TOKEN / GH_TOKEN, then press Check setup again."
    case "figma":
      return "Set FIGMA_TOKEN in the app environment, then press Check setup again."
    case "railway":
      return "Run railway login or set RAILWAY_TOKEN, then press Check setup again."
    case "hugging-face":
      return "Set HF_TOKEN or HUGGINGFACE_TOKEN, or create ~/.cache/huggingface/token, then press Check setup again."
    case "linear":
      return "Set LINEAR_API_KEY in the app environment, then press Check setup again."
    case "notion":
      return "Set NOTION_TOKEN in the app environment, then press Check setup again."
    case "local-documents":
      return "Local documents should always be ready. Press Check setup again; if it still fails, restart Jobmaxxing."
    case "apple-mail":
      return "Open Apple Mail once so ~/Library/Mail exists, then press Check setup again."
    default:
      return "Finish auth or local setup for \(connector.label), then press Check setup again."
    }
  }

  nonisolated private static func connectorReadyDetail(for connector: IntegrationConnector) -> String {
    switch connector.id {
    case "openai":
      return "Found OPENAI_API_KEY (or the configured key reference) for Medium/High routes."
    case "xai", "grok":
      return "Found Grok auth via XAI_API_KEY, Hermes xAI credentials, or Grok Build login."
    case "opencode-go":
      return "OpenCode Go is authenticated in OpenCode or through its configured API-key variable."
    case "opencode-zen":
      return "OpenCode Zen is authenticated in OpenCode or through its configured API-key variable."
    case "cursor":
      return "Cursor Agent auth is available and returned usable models."
    case "hermes":
      return "Found the local hermes executable."
    case "telegram":
      return "Found bot token and chat ID for manual Telegram sync."
    case "whatsapp":
      return "WhatsApp local database is readable for linked-thread intelligence."
    case "google-drive", "google-docs", "gmail", "google-calendar", "google-sheets", "google-slides":
      return "Found Google credentials, ADC file, or a configured profile."
    case "microsoft-365", "outlook", "onedrive", "word":
      return "Found Microsoft app credentials or configured tenant/mailbox fields."
    case "github":
      return "Found GitHub token or gh hosts login."
    case "figma":
      return "Found FIGMA_TOKEN."
    case "railway":
      return "Found Railway token or local railway auth state."
    case "hugging-face":
      return "Found Hugging Face token credentials."
    case "linear":
      return "Found LINEAR_API_KEY."
    case "notion":
      return "Found NOTION_TOKEN."
    case "local-documents":
      return "Local document import path is available."
    case "apple-mail":
      return "Found the local Apple Mail library for evidence search."
    default:
      return "Local readiness check passed for \(connector.label)."
    }
  }

  @discardableResult
  func updateHermesChatSettings(_ settings: HermesChatSettings) -> Bool {
    let expectedReference = "TELEGRAM_BOT_TOKEN"
    guard isValidCredentialReference(
      settings.telegramBotTokenReference,
      expectedReference: expectedReference
    ) else {
      recordCredentialReferenceError(connectorID: "telegram", expectedReference: expectedReference)
      return false
    }
    var chat = hermesChatState
    chat.settings = settings
    chat.selectedThreadID = Self.defaultHermesThreadID
    state.hermesChat = chat
    syncTelegramConnectorFromChatSettings(settings)
    persist()
    return true
  }

  func selectHermesThread(id: String) {
    var chat = hermesChatState
    chat.selectedThreadID = Self.defaultHermesThreadID
    selectedHermesThreadID = Self.defaultHermesThreadID
    state.hermesChat = chat
    persist()
  }

  @discardableResult
  func createHermesThread(initialPrompt: String = "") -> String {
    var chat = hermesChatState
    chat.threads = [Self.emptyHermesThread()]
    chat.selectedThreadID = Self.defaultHermesThreadID
    selectedHermesThreadID = Self.defaultHermesThreadID
    state.hermesChat = chat
    persist()
    return Self.defaultHermesThreadID
  }

  func sendHermesMessage(_ rawText: String, commandID explicitCommandID: String? = nil, attachments: [CandidateDocument] = []) {
    let text = rawText.trimmed
    let commandID = explicitCommandID ?? Self.hermesCommandID(from: text)
    guard !text.isEmpty || !attachments.isEmpty || commandID != nil else { return }
    var chat = hermesChatState
    chat = Self.normalizedSingleHermesChat(chat)
    guard let index = chat.threads.firstIndex(where: { $0.id == Self.defaultHermesThreadID }) else { return }

    let attachmentRecords = attachments.map {
      HermesChatAttachment(id: $0.id, title: $0.title, kind: $0.kind, filePath: $0.filePath)
    }
    let userMessage = HermesChatMessage(
      id: UUID().uuidString,
      role: "user",
      text: Self.visibleHermesUserText(text, commandID: commandID, attachments: attachments),
      status: "complete",
      commandID: commandID,
      traces: [],
      attachments: attachmentRecords
    )
    let responseID = UUID().uuidString
    let response = HermesChatMessage(
      id: responseID,
      role: "assistant",
      text: "",
      status: "running",
      commandID: commandID,
      traces: [
        Self.trace(
          commandID == "update" ? "Hermes update" : "Hermes",
          tool: commandID == "update" ? hermesSettings.updateCommand : "hermes",
          status: "running",
          detail: commandID == "update" ? "Updating Hermes through the official Hermes command." : "Waiting for Hermes."
        )
      ],
      attachments: []
    )
    let request = hermesHighAgentRequest(
      rawText: text,
      visibleText: userMessage.text,
      commandID: commandID,
      attachments: attachments
    )
    chat.threads[index].messages.append(userMessage)
    chat.threads[index].messages.append(response)
    chat.threads[index].messages = Self.boundedHermesMessages(chat.threads[index].messages)
    chat.threads[index].summary = "Working"
    chat.threads[index].status = response.status
    chat.selectedThreadID = Self.defaultHermesThreadID
    selectedHermesThreadID = Self.defaultHermesThreadID
    state.hermesChat = chat
    persist()
    Task {
      let result = await HermesHighAgentRunner.respond(to: request) { progress in
        self.updateHermesResponse(id: responseID, result: progress, commandID: commandID, persistProgress: false)
      }
      await MainActor.run {
        self.finishHermesResponse(id: responseID, result: result, commandID: commandID)
      }
    }
  }

  private func finishHermesResponse(id responseID: String, result: HermesHighAgentResult, commandID: String?) {
    updateHermesResponse(id: responseID, result: result, commandID: commandID, persistProgress: true)
  }

  @MainActor
  private func updateHermesResponse(
    id responseID: String,
    result: HermesHighAgentResult,
    commandID: String?,
    persistProgress: Bool
  ) {
    var chat = hermesChatState
    if chat.threads.first(where: { $0.id == Self.defaultHermesThreadID }) == nil {
      chat = Self.normalizedSingleHermesChat(chat)
    }
    guard let threadIndex = chat.threads.firstIndex(where: { $0.id == Self.defaultHermesThreadID }),
          let messageIndex = chat.threads[threadIndex].messages.firstIndex(where: { $0.id == responseID }) else { return }
    let isFailed = result.traces.contains(where: { $0.status == "failed" })
    let isRunning = result.traces.contains(where: { $0.status == "running" })
    let nextMessage = HermesChatMessage(
      id: responseID,
      role: "assistant",
      text: result.text,
      status: isFailed ? "failed" : (isRunning ? "running" : "complete"),
      commandID: commandID,
      traces: result.traces.map(Self.displaySafeTrace),
      attachments: []
    )
    guard chat.threads[threadIndex].messages[messageIndex] != nextMessage else { return }
    chat.threads[threadIndex].messages[messageIndex] = nextMessage
    chat.threads[threadIndex].summary = result.text.trimmed.isEmpty ? (isRunning ? "Working" : "Ready") : result.text
    chat.threads[threadIndex].status = nextMessage.status
    chat.selectedThreadID = Self.defaultHermesThreadID
    selectedHermesThreadID = Self.defaultHermesThreadID
    state.hermesChat = chat
    if persistProgress {
      persist()
    }
  }

  private func hermesHighAgentRequest(
    rawText: String,
    visibleText: String,
    commandID: String?,
    attachments: [CandidateDocument]
  ) -> HermesHighAgentRequest {
    let route = state.modelRoutes.first(where: { $0.id == hermesSettings.defaultModelRouteID })
      ?? state.modelRoutes.first(where: { $0.id == "final-review" })
      ?? Self.defaultState.modelRoutes.first(where: { $0.id == "final-review" })!
    return HermesHighAgentRequest(
      userText: rawText,
      visibleUserText: visibleText,
      commandID: commandID,
      route: route,
      context: hermesHighAgentContext(),
      attachmentTitles: attachments.map(\.title),
      updateCommand: hermesSettings.updateCommand
    )
  }

  private func hermesHighAgentContext() -> String {
    let selectedCompanyText = selectedCompany.map { company in
      [
        "Selected company: \(company.name)",
        "Summary: \(company.summary)",
        "Research status: \(company.research.status)",
        "Source URLs: \(company.research.sourceURLs.compactJoined)"
      ].joined(separator: "\n")
    } ?? "Selected company: none"
    let selectedJobText = selectedJob.map { job in
      [
        "Selected application: \(job.company), \(job.role)",
        "Stage: \(job.stage.label)",
        "Source URL: \(job.sourceURL)",
        "Description: \(String(job.description.prefix(1200)))"
      ].joined(separator: "\n")
    } ?? "Selected application: none"
    let goalText = state.currentGoal.map { "Goal: \($0.objective)" } ?? "Goal: none"
    let evidenceText = state.profile.evidence.prefix(8).map { "\($0.title): \($0.proof)" }.joined(separator: "\n")
    let writingRules = state.promptMemory.prefix(10).joined(separator: "\n")
    let selectedCompanyContacts = selectedCompany.map { company in
      contacts(for: company.id)
        .prefix(10)
        .map(Self.hermesContactContextLine)
        .joined(separator: "\n")
    } ?? ""
    let savedCompaniesText = companyProfiles.prefix(12).map { company in
      let people = company.people.prefix(5).map { person in
        [person.name, person.title, person.relationship].filter { !$0.trimmed.isEmpty }.joined(separator: " - ")
      }.joined(separator: "; ")
      return [
        company.name,
        company.website,
        people.isEmpty ? nil : "people: \(people)"
      ].compactMap { $0 }.joined(separator: " | ")
    }.joined(separator: "\n")
    let savedContactsText = contacts.prefix(16).map(Self.hermesContactContextLine).joined(separator: "\n")
    return [
      "Output: answer User in Markdown. Use headings, bullets, code fences, and tables when they make the response easier to scan.",
      "State rule: before creating a company or contact, match saved records by company, person name, role, LinkedIn/source URL, phone/email, or WhatsApp JID. Update matching records instead of creating duplicates.",
      "Research rule: if User asks about a public company fact, tool, person, system name, or unresolved clue, search or prepare browser steps before marking it unknown. Keep facts sourced, label assumptions, and do not leave a public unknown unresolved when lookup tools are available.",
      goalText,
      selectedCompanyText,
      "Selected company contacts:",
      selectedCompanyContacts.isEmpty ? "None saved for the selected company." : selectedCompanyContacts,
      selectedJobText,
      "Candidate: \(state.profile.name)",
      "Target roles: \(state.profile.targetRoles.compactJoined)",
      "Locations: \(state.profile.locations.compactJoined)",
      "Saved companies:",
      savedCompaniesText.isEmpty ? "None saved." : savedCompaniesText,
      "Saved contacts:",
      savedContactsText.isEmpty ? "None saved." : savedContactsText,
      "Evidence:",
      evidenceText.isEmpty ? "None saved." : evidenceText,
      "Saved writing rules:",
      writingRules.isEmpty ? "None saved." : writingRules,
      "Safety: do not submit applications, send messages, edit external profiles, bypass captchas, or claim unsourced facts."
    ].joined(separator: "\n\n")
  }

  private static func hermesContactContextLine(_ contact: ContactRecord) -> String {
    let companies = contact.companyLinks.map(\.companyName).compactJoined
    let whatsApp = contact.communicationProfile?.whatsApp.map { profile in
      "WhatsApp: \(profile.jid), \(profile.messageCount) messages"
    } ?? ""
    return [
      contact.name,
      contact.role,
      companies.isEmpty ? "" : "Companies: \(companies)",
      contact.linkedInURL.trimmed.isEmpty ? "" : "LinkedIn: \(contact.linkedInURL)",
      contact.phone.trimmed.isEmpty ? "" : "Phone: \(contact.phone)",
      contact.email.trimmed.isEmpty ? "" : "Email: \(contact.email)",
      whatsApp,
      contact.research.summary.trimmed.isEmpty ? "" : "Research: \(String(contact.research.summary.prefix(500)))",
      contact.notes.trimmed.isEmpty ? "" : "Notes: \(String(contact.notes.prefix(300)))"
    ].filter { !$0.trimmed.isEmpty }.joined(separator: " | ")
  }

  func syncTelegramMessages() async -> String {
    guard let connector = integrationConnectors.first(where: { $0.id == "telegram" }),
          connector.isEnabled else {
      return "Enable Telegram in Settings before syncing messages."
    }
    var chat = hermesChatState
    chat = Self.normalizedSingleHermesChat(chat)
    let settings = chat.settings
    let chatID = Self.configValue("chat-id", in: connector)
    guard !chatID.isEmpty else { return "Set Telegram chat ID." }
    guard let token = Self.telegramToken(from: Self.configValue("bot-token-ref", in: connector)) else {
      return "Set Telegram bot token."
    }

    var components = URLComponents(string: "https://api.telegram.org/bot\(token)/getUpdates")
    var queryItems = [
      URLQueryItem(name: "timeout", value: "0"),
      URLQueryItem(name: "allowed_updates", value: "[\"message\"]")
    ]
    if let last = settings.telegramLastUpdateID {
      queryItems.append(URLQueryItem(name: "offset", value: "\(last + 1)"))
    }
    components?.queryItems = queryItems
    guard let url = components?.url else { return "Could not build Telegram request." }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      let payload = try JSONDecoder().decode(TelegramUpdatesResponse.self, from: data)
      guard payload.ok else { return "Telegram returned an error." }
      var imported = 0
      var lastUpdate = settings.telegramLastUpdateID
      guard let index = chat.threads.firstIndex(where: { $0.id == Self.defaultHermesThreadID }) else {
        return "Chat state unavailable."
      }
      let existingIDs = Set(chat.threads[index].messages.map(\.id))
      for update in payload.result {
        lastUpdate = max(lastUpdate ?? update.updateID, update.updateID)
        guard String(update.message?.chat.id ?? 0) == chatID,
              let text = update.message?.text?.trimmed,
              !text.isEmpty else { continue }
        let messageID = "telegram-\(update.updateID)"
        guard !existingIDs.contains(messageID) else { continue }
        chat.threads[index].messages.append(
          HermesChatMessage(
            id: messageID,
            role: "user",
            text: text,
            status: "complete",
            commandID: Self.hermesCommandID(from: text),
            traces: [
              Self.trace("Telegram sync", tool: "telegram", detail: "update \(update.updateID)")
            ],
            attachments: []
          )
        )
        chat.threads[index].summary = text
        imported += 1
      }
      chat.threads[index].messages = Self.boundedHermesMessages(chat.threads[index].messages)
      chat.settings.telegramLastUpdateID = lastUpdate
      chat.selectedThreadID = Self.defaultHermesThreadID
      state.hermesChat = chat
      if imported > 0 {
        persist()
      } else if lastUpdate != settings.telegramLastUpdateID {
        persist()
      }
      return imported == 1 ? "Synced 1 message." : "Synced \(imported) messages."
    } catch {
      return error.localizedDescription
    }
  }

  func updateProfile(_ profile: CandidateProfile) {
    state.profile = profile
    persist()
  }

  func addCompany(name: String, website: String, linkedInURL: String, category: String, relationship: String, notes: String) {
    let trimmedName = name.trimmed
    guard !trimmedName.isEmpty else { return }
    var profiles = companyProfiles
    let id = Self.companyID(for: trimmedName)
    if let index = profiles.firstIndex(where: { $0.id == id }) {
      profiles[index].website = website.trimmed
      profiles[index].linkedInURL = linkedInURL.trimmed
      profiles[index].category = category.trimmed.isEmpty ? profiles[index].category : category.trimmed
      profiles[index].relationship = relationship.trimmed.isEmpty ? profiles[index].relationship : relationship.trimmed
      profiles[index].notes = notes.trimmed
    } else {
      profiles.insert(
        CompanyProfile(
          id: id,
          name: trimmedName,
          website: website.trimmed,
          linkedInURL: linkedInURL.trimmed,
          category: category.trimmed.isEmpty ? "Target company" : category.trimmed,
          size: "Unknown",
          headquarters: "Unknown",
          publicStatus: "Unknown",
          summary: "Company profile created locally. Add research notes or run the agent research plan.",
          relationship: relationship.trimmed.isEmpty ? "Target" : relationship.trimmed,
          applicationIDs: [],
          experienceIDs: [],
          submittedMaterials: [],
          people: [],
          research: Self.emptyCompanyResearch(companyName: trimmedName, website: website.trimmed, linkedInURL: linkedInURL.trimmed),
          nextActions: Self.companyNextActions(name: trimmedName),
          notes: notes.trimmed
        ),
        at: 0
      )
    }
    state.companyProfiles = profiles
    selectedCompanyID = id
    persist()
  }

  func updateCompany(_ company: CompanyProfile) {
    var profiles = companyProfiles
    if let index = profiles.firstIndex(where: { $0.id == company.id }) {
      profiles[index] = company
    } else {
      profiles.insert(company, at: 0)
    }
    state.companyProfiles = profiles
    persist()
  }

  func updateCompanyNotes(companyID: String, notes: String) {
    guard var company = companyProfiles.first(where: { $0.id == companyID }) else { return }
    company.notes = notes
    updateCompany(company)
  }

  func prepareCompanyResearch(companyID: String) {
    guard var company = companyProfiles.first(where: { $0.id == companyID }) else { return }
    let linkedJobs = state.jobs.filter { company.applicationIDs.contains($0.id) }
    let sourceURLs = ([company.website, company.linkedInURL] + linkedJobs.map(\.sourceURL))
      .map(\.trimmed)
      .filter { !$0.isEmpty }
    let pages = sourceURLs.enumerated().map { index, url in
      CompanyResearchPage(
        id: "company-page-\(company.id)-\(index)",
        title: pageTitle(for: url, companyName: company.name),
        url: url,
        summary: "Planned source review. Open and review this source before saving any new fact."
      )
    }
    company.research = CompanyResearch(
      status: "Research plan ready",
      confidence: pages.isEmpty ? 25 : 48,
      websitePages: pages,
      products: company.research.products.isEmpty ? ["Identify products from homepage, docs, pricing, case studies, and careers pages."] : company.research.products,
      businessModel: company.research.businessModel.trimmed.isEmpty ? "Unknown until source review." : company.research.businessModel,
      leadership: company.research.leadership,
      hiringSignals: linkedJobs.flatMap(\.keywords).uniqued + company.research.hiringSignals,
      risks: company.research.risks.isEmpty ? ["Do not infer private facts from LinkedIn profiles.", "Cross-check public/private company claims before writing application material."] : company.research.risks,
      openQuestions: [
        "What does the company sell and who pays?",
        "Which team owns the role?",
        "Who are likely hiring managers, recruiters, founders, or adjacent employees?",
        "What proof from the user best maps to this company's current work?",
        "What should not be claimed yet?"
      ],
      sourceURLs: sourceURLs.uniqued,
      agentPlan: Self.companyAgentPlan(name: company.name, website: company.website, linkedInURL: company.linkedInURL)
    )
    company.nextActions = [
      "Run approved browser research over source URLs.",
      "Add likely hiring people with source links.",
      "Map each application claim to evidence.",
      "Generate company-specific interview questions."
    ]
    updateCompany(company)
  }

  @discardableResult
  func addContact(
    companyID: String,
    name: String,
    role: String,
    jobDescription: String,
    linkedInURL: String,
    phone: String,
    email: String,
    location: String,
    sourceURL: String,
    relationship: String,
    howMet: String,
    notes: String,
    personalNotes: String,
    projectNotes: String
  ) -> String? {
    let normalizedName = name.trimmed
    guard !normalizedName.isEmpty else { return nil }
    let company = companyProfiles.first(where: { $0.id == companyID })
    let resolvedSourceURL = sourceURL.trimmed.isEmpty ? linkedInURL.trimmed : sourceURL.trimmed
    let contactID = UUID().uuidString
    let contact = ContactRecord(
      id: contactID,
      name: normalizedName,
      role: role.trimmed,
      jobDescription: jobDescription.trimmed,
      linkedInURL: linkedInURL.trimmed,
      phone: phone.trimmed,
      email: email.trimmed,
      location: location.trimmed,
      sourceURL: resolvedSourceURL,
      relationship: relationship.trimmed.isEmpty ? "Contact" : relationship.trimmed,
      howMet: howMet.trimmed,
      notes: notes.trimmed,
      personalNotes: personalNotes.trimmed,
      projectNotes: projectNotes.trimmed,
      companyLinks: company.map {
        [
          ContactCompanyLink(
            id: Self.contactCompanyLinkID(contactID: contactID, companyID: $0.id),
            companyID: $0.id,
            companyName: $0.name,
            role: role.trimmed,
            relationship: relationship.trimmed.isEmpty ? "Contact" : relationship.trimmed,
            notes: notes.trimmed,
            sourceURL: resolvedSourceURL
          )
        ]
      } ?? [],
      research: Self.emptyContactResearch(name: normalizedName),
      communicationProfile: nil
    )
    var next = contacts
    let upserted = Self.contactsByUpserting(contact: contact, into: next, company: company)
    next = upserted.contacts
    state.contacts = next
    persist()
    return upserted.contactID
  }

  func addCompanyPerson(companyID: String, name: String, title: String, sourceURL: String, relationship: String, notes: String) {
    _ = addContact(
      companyID: companyID,
      name: name,
      role: title,
      jobDescription: "",
      linkedInURL: sourceURL.lowercased().contains("linkedin.com") ? sourceURL : "",
      phone: sourceURL.lowercased().hasPrefix("tel:") ? sourceURL.replacingOccurrences(of: "tel:", with: "") : "",
      email: "",
      location: "",
      sourceURL: sourceURL,
      relationship: relationship,
      howMet: "",
      notes: notes,
      personalNotes: "",
      projectNotes: ""
    )
  }

  func addCompanyPersonFromWhatsApp(
    companyID: String,
    candidate: WhatsAppThreadCandidate,
    fallbackName: String,
    title: String,
    relationship: String,
    notes: String
  ) async -> String {
    guard companyProfiles.contains(where: { $0.id == companyID }) else {
      return "Choose a company first."
    }
    let displayName = candidate.displayName.trimmed
    let fallback = fallbackName.trimmed
    let name = displayName.isEmpty || displayName.contains("@") ? fallback : displayName
    guard !name.isEmpty else {
      return "Add a name before saving this contact."
    }
    guard let contactID = addContact(
      companyID: companyID,
      name: name,
      role: title,
      jobDescription: "",
      linkedInURL: "",
      phone: "",
      email: "",
      location: "",
      sourceURL: candidate.jid.trimmed.isEmpty ? "" : "whatsapp:\(candidate.jid)",
      relationship: relationship.trimmed.isEmpty ? "Contact" : relationship.trimmed,
      howMet: "WhatsApp",
      notes: [notes, displayName == name ? "" : "WhatsApp display name: \(displayName)"]
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: "\n"),
      personalNotes: "",
      projectNotes: ""
    ) else {
      return "Could not save \(name)."
    }
    return await importWhatsAppThread(companyID: companyID, personID: contactID, candidate: candidate)
  }

  func addWhatsAppContactMetadata(
    companyID: String,
    candidate: WhatsAppThreadCandidate,
    fallbackName: String,
    title: String,
    relationship: String,
    notes: String
  ) async -> WhatsAppContactSaveResult {
    guard companyProfiles.contains(where: { $0.id == companyID }) else {
      return WhatsAppContactSaveResult(status: "Choose a company first.", contactID: nil)
    }
    let name = Self.whatsAppContactName(candidate: candidate, fallbackName: fallbackName)
    guard !name.isEmpty else {
      return WhatsAppContactSaveResult(status: "Add a name before saving this contact.", contactID: nil)
    }
    let phone = Self.phoneNumber(fromWhatsAppCandidate: candidate)
    let sourceURL = candidate.jid.trimmed.isEmpty ? "" : "whatsapp:\(candidate.jid)"
    guard let contactID = addContact(
      companyID: companyID,
      name: name,
      role: title,
      jobDescription: "",
      linkedInURL: "",
      phone: phone,
      email: "",
      location: "",
      sourceURL: sourceURL,
      relationship: relationship.trimmed.isEmpty ? "Contact" : relationship.trimmed,
      howMet: "WhatsApp",
      notes: [notes]
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .joined(separator: "\n"),
      personalNotes: "",
      projectNotes: ""
    ) else {
      return WhatsAppContactSaveResult(status: "Could not save \(name).", contactID: nil)
    }
    let status = await importWhatsAppThread(companyID: companyID, personID: contactID, candidate: candidate)
    return WhatsAppContactSaveResult(status: status, contactID: contactID)
  }

  func addLatestWhatsAppContactMetadata(companyID: String) async -> WhatsAppContactSaveResult {
    let candidates: [WhatsAppThreadCandidate]
    do {
      let path = whatsAppDatabasePath()
      candidates = try await Task.detached(priority: .userInitiated) {
        try WhatsAppLocalStore(databasePath: path).searchThreads(query: "")
      }.value
    } catch {
      return WhatsAppContactSaveResult(status: error.localizedDescription, contactID: nil)
    }
    guard !candidates.isEmpty else {
      return WhatsAppContactSaveResult(status: "No WhatsApp threads were found.", contactID: nil)
    }
    guard let candidate = candidates.first(where: { !isWhatsAppCandidateSaved($0) }) else {
      return WhatsAppContactSaveResult(status: "Latest WhatsApp senders are already saved.", contactID: nil)
    }
    return await addWhatsAppContactMetadata(
      companyID: companyID,
      candidate: candidate,
      fallbackName: "",
      title: "",
      relationship: "Contact",
      notes: ""
    )
  }

  private func isWhatsAppCandidateSaved(_ candidate: WhatsAppThreadCandidate) -> Bool {
    let jid = candidate.jid.trimmed
    let sourceURL = jid.isEmpty ? "" : "whatsapp:\(jid)"
    let phone = Self.phoneNumber(fromWhatsAppCandidate: candidate)
    return contacts.contains { contact in
      (!phone.isEmpty && contact.phone.trimmed == phone)
        || (!sourceURL.isEmpty && contact.sourceURL.trimmed == sourceURL)
        || (!jid.isEmpty && contact.communicationProfile?.whatsApp?.jid.trimmed == jid)
    }
  }

  func linkContactToCompany(contactID: String, companyID: String, role: String, relationship: String, notes: String) {
    guard let company = companyProfiles.first(where: { $0.id == companyID }),
          let index = contacts.firstIndex(where: { $0.id == contactID }) else { return }
    var next = contacts
    next[index] = Self.contactByLinking(
      next[index],
      to: company,
      role: role,
      relationship: relationship,
      notes: notes,
      sourceURL: next[index].sourceURL
    )
    state.contacts = next
    persist()
  }

  func updateContact(_ contact: ContactRecord) {
    var next = contacts
    if let index = next.firstIndex(where: { $0.id == contact.id }) {
      next[index] = contact
    } else {
      next.insert(contact, at: 0)
    }
    state.contacts = next
    persist()
  }

  func contactAgentMessages(contactID: String) -> [HermesChatMessage] {
    contacts.first(where: { $0.id == contactID })?.agentMessages ?? []
  }

  func sendContactAgentMessage(contactID: String, text rawText: String, modelTier: String) -> String {
    let text = rawText.trimmed
    guard !text.isEmpty else { return "Write a task for the local planner." }
    guard let index = contacts.firstIndex(where: { $0.id == contactID }) else {
      return "Choose a contact first."
    }
    var nextContacts = contacts
    let userMessage = HermesChatMessage(
      id: UUID().uuidString,
      role: "user",
      text: text,
      status: "complete",
      commandID: nil,
      traces: [],
      attachments: []
    )
    let result = runContactAgent(contact: nextContacts[index], userText: text, modelTier: modelTier)
    var contact = result.contact
    let assistantMessage = HermesChatMessage(
      id: UUID().uuidString,
      role: "assistant",
      text: result.text,
      status: "complete",
      commandID: nil,
      traces: result.traces,
      attachments: []
    )
    var messages = contact.agentMessages ?? []
    messages.append(userMessage)
    messages.append(assistantMessage)
    contact.agentMessages = messages.suffix(30).map { $0 }
    nextContacts[index] = contact
    state.contacts = nextContacts
    persist()
    return "Prepared a local result for \(contact.name). No model or browser research ran."
  }

  func runContactQuickAction(contactID: String, action: String, modelTier: String) -> String {
    let prompt: String
    switch action {
    case "deep-profile":
      prompt = "Prepare a local profile plan from the saved contact, company, source URLs, and linked WhatsApp context. Separate saved facts from open questions. Do not claim that a model, search, or browser ran."
    case "find-email":
      prompt = "Check whether a reliable email address is saved. If not, prepare a source-review checklist and do not guess an address or claim a search ran."
    case "draft-follow-up":
      prompt = "Draft a manual follow-up from the saved contact and conversation context. Keep it concise and ready to copy. Do not send."
    case "chrome-research":
      prompt = "Prepare a browser research plan for the saved public profile and source targets. Do not claim any page was reviewed or any fact was found until the user reviews it."
    default:
      prompt = action
    }
    return sendContactAgentMessage(contactID: contactID, text: prompt, modelTier: modelTier)
  }

  func enhanceContact(contactID: String) -> String {
    let result = enhanceContactWithoutPersist(contactID: contactID)
    persist()
    return result
  }

  func enhanceContacts(contactIDs: [String]) -> String {
    let ids = contactIDs.isEmpty ? contacts.map(\.id) : contactIDs
    var enhanced = 0
    for id in ids {
      if contacts.contains(where: { $0.id == id }) {
        _ = enhanceContactWithoutPersist(contactID: id)
        enhanced += 1
      }
    }
    persist()
    return enhanced == 1 ? "Prepared 1 local contact plan." : "Prepared \(enhanced) local contact plans."
  }

  private func enhanceContactWithoutPersist(contactID: String) -> String {
    guard let index = contacts.firstIndex(where: { $0.id == contactID }) else {
      return "Choose a contact first."
    }
    var nextContacts = contacts
    var contact = nextContacts[index]
    let primaryCompany = contact.companyLinks.first
    let company = primaryCompany.flatMap { link in companyProfiles.first(where: { $0.id == link.companyID }) }
    let sources = [contact.linkedInURL, contact.sourceURL, primaryCompany?.sourceURL ?? ""]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .uniqued
    let profile = Self.deepContactResearchProfile(contact: contact, company: company, sources: sources)
    contact.research.status = "Local plan ready"
    contact.research.summary = profile.summary
    contact.research.publicFacts = profile.publicFacts.uniqued
    contact.research.sourceURLs = (profile.sourceURLs + contact.research.sourceURLs).uniqued
    contact.research.openQuestions = profile.openQuestions
    contact.research.proposedAdditions = profile.proposedAdditions
    nextContacts[index] = contact
    state.contacts = nextContacts
    appendAgentRuns(Self.contactAgentRuns(contact: contact, companyName: primaryCompany?.companyName ?? "No company linked"))
    return "Prepared a local profile plan for \(contact.name). No model or browser research ran."
  }

  func enhanceCompany(companyID: String) -> String {
    guard var company = companyProfiles.first(where: { $0.id == companyID }) else {
      return "Choose a company first."
    }
    prepareCompanyResearch(companyID: companyID)
    company = companyProfiles.first(where: { $0.id == companyID }) ?? company
    let linkedContacts = contacts(for: companyID)
    appendAgentRuns(Self.companyAgentRuns(company: company, linkedContacts: linkedContacts))
    persist()
    return "Prepared a local research plan for \(company.name). No browser or model research ran."
  }

  private func appendAgentRuns(_ runs: [ResearchAgentRun]) {
    guard !runs.isEmpty else { return }
    let keys = Set(runs.map { "\($0.contextKind)|\($0.contextID)|\($0.title)" })
    state.agentRuns = runs + agentRuns.filter { !keys.contains("\($0.contextKind)|\($0.contextID)|\($0.title)") }
  }

  private func contactRecord(forLegacyPersonID personID: String, company: CompanyProfile) -> ContactRecord? {
    guard let legacy = company.people.first(where: { $0.id == personID }) else { return nil }
    let contact = Self.contact(from: legacy, company: company)
    var next = contacts
    let result = Self.contactsByUpserting(contact: contact, into: next, company: company)
    next = result.contacts
    state.contacts = next
    return next.first(where: { $0.id == result.contactID })
  }

  private func legacyPerson(from contact: ContactRecord) -> CompanyPerson {
    CompanyPerson(
      id: contact.id,
      name: contact.name,
      title: contact.role,
      sourceURL: contact.sourceURL,
      relationship: contact.relationship,
      notes: contact.notes,
      communicationProfile: contact.communicationProfile
    )
  }

  func searchWhatsAppThreads(query: String) async -> WhatsAppThreadSearchResult {
    let path = whatsAppDatabasePath()
    do {
      let result = try await Task.detached(priority: .userInitiated) {
        let localStore = WhatsAppLocalStore(databasePath: path)
        return (
          counts: try localStore.databaseCounts(),
          candidates: try localStore.searchThreads(query: query)
        )
      }.value
      let counts = result.counts
      let candidates = result.candidates
      let status = candidates.isEmpty
        ? "No WhatsApp thread matched. Try a name, phone fragment, or leave search blank."
        : "Searched \(counts.threads) threads and \(counts.messages) messages. Pick one thread to grant access."
      return WhatsAppThreadSearchResult(status: status, candidates: candidates)
    } catch {
      return WhatsAppThreadSearchResult(status: error.localizedDescription, candidates: [])
    }
  }

  func importWhatsAppThread(companyID: String, personID: String, candidate: WhatsAppThreadCandidate) async -> String {
    guard let company = companyProfiles.first(where: { $0.id == companyID }) else {
      return "Choose a company first."
    }
    var nextContacts = contacts
    var resolvedPersonID = personID
    if !nextContacts.contains(where: { $0.id == resolvedPersonID }),
       let migrated = contactRecord(forLegacyPersonID: personID, company: company) {
      nextContacts = contacts
      resolvedPersonID = migrated.id
      if !nextContacts.contains(where: { $0.id == migrated.id }) {
        nextContacts.insert(migrated, at: 0)
      }
    }
    guard let contactIndex = nextContacts.firstIndex(where: { $0.id == resolvedPersonID }) else {
      return "Select a saved person before granting WhatsApp access."
    }
    do {
      var profile = try await Task.detached(priority: .userInitiated) {
        try WhatsAppLocalStore(databasePath: candidate.databasePath).importThread(candidate)
      }.value
      let existingMessages = nextContacts[contactIndex].communicationProfile?.whatsApp?.messages ?? []
      if !existingMessages.isEmpty {
        let existingIDs = Set(existingMessages.map(\.id))
        let existingContent = Set(existingMessages.map {
          "\($0.isFromMe)|\($0.senderJID)|\($0.text)"
        })
        let additions = (profile.messages ?? []).filter { message in
          !existingIDs.contains(message.id)
            && !existingContent.contains("\(message.isFromMe)|\(message.senderJID)|\(message.text)")
        }
        profile.messages = existingMessages + additions
      }
      nextContacts[contactIndex] = Self.contactByApplyingWhatsAppProfile(
        nextContacts[contactIndex],
        profile: profile,
        candidate: candidate,
        company: company
      )
      let person = legacyPerson(from: nextContacts[contactIndex])
      profile = Self.profileByAddingDrafts(profile, company: company, person: person, purpose: "Ask for useful hiring context or a warm introduction.")
      nextContacts[contactIndex] = Self.contactByLinking(
        nextContacts[contactIndex],
        to: company,
        role: nextContacts[contactIndex].role,
        relationship: nextContacts[contactIndex].relationship,
        notes: "",
        sourceURL: nextContacts[contactIndex].sourceURL
      )
      nextContacts[contactIndex].communicationProfile = PersonCommunicationProfile(
        whatsApp: profile,
        appWideRules: Self.whatsAppAppWideRules
      )
      addWhatsAppPromptMemoryIfNeeded()
      state.contacts = nextContacts
      persist()
      let retainedCount = profile.messages?.count ?? 0
      return "Linked WhatsApp for \(nextContacts[contactIndex].name). The source reports \(profile.messageCount) messages; \(retainedCount) saved or recent readable messages are available locally."
    } catch {
      return error.localizedDescription
    }
  }

  func refreshWhatsAppThread(contactID: String) async -> String {
    guard let contact = contacts.first(where: { $0.id == contactID }) else {
      return "Choose a contact first."
    }
    guard let companyID = contact.companyLinks.first?.companyID else {
      return "Link this contact to a company first."
    }
    if let profile = contact.communicationProfile?.whatsApp {
      let candidate = WhatsAppThreadCandidate(
        id: profile.threadID,
        chatSessionID: profile.chatSessionID,
        displayName: profile.displayName,
        jid: profile.jid,
        messageCount: profile.messageCount,
        lastMessagePreview: profile.lastMessagePreview,
        databasePath: profile.databasePath
      )
      return await importWhatsAppThread(companyID: companyID, personID: contact.id, candidate: candidate)
    }

    let whatsAppJID = contact.sourceURL.trimmed.lowercased().hasPrefix("whatsapp:")
      ? String(contact.sourceURL.trimmed.dropFirst("whatsapp:".count))
      : ""
    let queries = [whatsAppJID, contact.phone, contact.name]
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .uniqued
    guard !queries.isEmpty else {
      return "Add a phone number or WhatsApp source before refreshing."
    }
    let databasePath = whatsAppDatabasePath()
    for query in queries {
      do {
        let candidates = try await Task.detached(priority: .userInitiated) {
          try WhatsAppLocalStore(databasePath: databasePath).searchThreads(query: query, limit: 8)
        }.value
        if let candidate = candidates.first(where: { candidate in
          let candidatePhone = Self.phoneNumber(fromWhatsAppCandidate: candidate)
          return (!whatsAppJID.isEmpty && candidate.jid == whatsAppJID)
            || (!contact.phone.trimmed.isEmpty && candidatePhone == contact.phone.trimmed)
            || candidate.displayName.localizedCaseInsensitiveContains(contact.name)
        }) {
          return await importWhatsAppThread(companyID: companyID, personID: contact.id, candidate: candidate)
        }
      } catch {
        return error.localizedDescription
      }
    }
    return "No matching WhatsApp thread found for \(contact.name)."
  }

  func draftContactMessages(companyID: String, personID: String, purpose: String) -> String {
    guard let company = companyProfiles.first(where: { $0.id == companyID }),
          let contactIndex = contacts.firstIndex(where: { $0.id == personID }),
          var whatsApp = contacts[contactIndex].communicationProfile?.whatsApp else {
      return "Grant WhatsApp access for this person first."
    }
    var nextContacts = contacts
    let person = legacyPerson(from: nextContacts[contactIndex])
    whatsApp = Self.profileByAddingDrafts(whatsApp, company: company, person: person, purpose: purpose)
    var communication = nextContacts[contactIndex].communicationProfile ?? PersonCommunicationProfile()
    communication.whatsApp = whatsApp
    communication.appWideRules = Self.whatsAppAppWideRules
    nextContacts[contactIndex].communicationProfile = communication
    state.contacts = nextContacts
    persist()
    return "Drafted WhatsApp and email variants for \(nextContacts[contactIndex].name)."
  }

  func draftWhatsAppReply(contactID: String) -> String {
    guard let companyID = contacts.first(where: { $0.id == contactID })?.companyLinks.first?.companyID else {
      return "Link this contact to a company first."
    }
    return draftContactMessages(companyID: companyID, personID: contactID, purpose: "Reply to the latest incoming WhatsApp message.")
  }

  private func whatsAppDatabasePath() -> String {
    guard let connector = integrationConnectors.first(where: { $0.id == "whatsapp" }) else {
      return WhatsAppLocalStore.defaultDatabasePath
    }
    let configured = Self.configValue("database-path", in: connector).trimmed
    return configured.isEmpty ? WhatsAppLocalStore.defaultDatabasePath : Self.expandedHomePath(configured)
  }

  private func addWhatsAppPromptMemoryIfNeeded() {
    for rule in Self.whatsAppAppWideRules where !state.promptMemory.contains(rule) {
      state.promptMemory.append(rule)
    }
  }

  func prepareLinkedInImport(sourceURL: String) {
    var profile = state.profile
    let trimmedURL = sourceURL.trimmed
    if !trimmedURL.isEmpty {
      profile.linkedInURL = trimmedURL
    }
    profile.linkedInImportPlan = ProfileImportPlan(
      sourceURL: trimmedURL.isEmpty ? (profile.linkedInURL ?? "") : trimmedURL,
      status: "Ready for browser steps",
      checkpoint: "Open LinkedIn only with the user visible, read profile details, then save structured fields back into Profile.",
      steps: [
        "Open the LinkedIn profile with the user logged in.",
        "Read headline, about, experience, education, skills, certifications, projects, and contact-safe public links.",
        "Do not click apply, message, edit profile, endorse, or export private data.",
        "Convert visible profile facts into structured profile memory and evidence candidates.",
        "Ask for approval before replacing existing profile fields."
      ],
      fields: [
        "Headline",
        "About",
        "Experience",
        "Education",
        "Skills",
        "Certifications",
        "Projects",
        "Featured links",
        "Writing voice signals"
      ],
      blocked: [
        "No hidden scraping",
        "No connection requests",
        "No messages",
        "No profile edits",
        "No job submissions"
      ]
    )
    state.profile = profile
    persist()
  }

  func addProfileMemory(kind: String, title: String, detail: String, source: String, strength: Int) {
    let normalizedTitle = title.trimmed
    let normalizedDetail = detail.trimmed
    guard !normalizedTitle.isEmpty, !normalizedDetail.isEmpty else { return }

    var profile = state.profile
    var memory = profile.personalMemory ?? Self.defaultProfileMemory
    memory.insert(
      ProfileMemory(
        id: UUID().uuidString,
        kind: kind.trimmed.isEmpty ? "Preference" : kind.trimmed,
        title: normalizedTitle,
        detail: normalizedDetail,
        source: source.trimmed.isEmpty ? "User note" : source.trimmed,
        strength: max(1, min(5, strength))
      ),
      at: 0
    )
    profile.personalMemory = Array(memory.prefix(40))
    state.profile = profile
    persist()
  }

  func updateBrowserPolicy(_ policy: BrowserPolicy) {
    state.browserPolicy = policy
    persist()
  }

  private func log(jobID: String, actor: String, title: String, detail: String, approval: String) {
    let nextSequence = (state.events.map(\.sequence).max() ?? 0) + 1
    state.events.insert(
      ActivityEvent(
        id: UUID().uuidString,
        sequence: nextSequence,
        actor: actor,
        jobID: jobID,
        title: title,
        detail: detail,
        approval: approval
      ),
      at: 0
    )
  }

  private func persist() {
    do {
      try save()
      storageAlert = nil
    } catch {
      let target = (try? resolvedStateURL().path) ?? "the Jobmaxxing state file"
      storageAlert = JobmaxxingStorageAlert(
        title: "Could not save Jobmaxxing state",
        message: "Your latest change is visible in this app session, but it was not written to \(target). Check file permissions or disk space, then try again. Error: \(error.localizedDescription)"
      )
      print("Could not save Jobmaxxing state to \(target): \(error)")
    }
  }

  private func indexDocument(_ document: CandidateDocument) {
    let started = Date()
    do {
      try DocumentDatabase.shared.upsert(document)
      recordDocumentIndexStatus(
        document: document,
        started: started,
        succeeded: true,
        message: "Indexed \(document.fileName)."
      )
    } catch {
      recordDocumentIndexStatus(
        document: document,
        started: started,
        succeeded: false,
        message: "Could not index \(document.fileName): \(error.localizedDescription)"
      )
      print("Could not index Jobmaxxing document \(document.filePath): \(error)")
    }
  }

  private func recordDocumentIndexStatus(
    document: CandidateDocument,
    started: Date,
    succeeded: Bool,
    message: String
  ) {
    state.documentIndexStatus = DocumentIndexStatus(
      documentID: document.id,
      documentTitle: document.title,
      durationMilliseconds: max(0, Int(Date().timeIntervalSince(started) * 1000)),
      succeeded: succeeded,
      message: message
    )
  }

  private func migrateDefaults(persistChanges: Bool) {
    var changed = false
    if state.hermes == nil {
      state.hermes = Self.defaultHermesSettings
      changed = true
    }
    if state.hermesChat == nil {
      state.hermesChat = Self.defaultHermesChatState
      changed = true
    } else if let chat = state.hermesChat {
      var normalized = Self.normalizedSingleHermesChat(chat)
      if normalized.settings.telegramBotTokenReference == "TELEGRAM_BOT_TOKEN" {
        normalized.settings.telegramBotTokenReference = ""
      }
      if normalized != chat {
        state.hermesChat = normalized
        changed = true
      }
    }
    if let connectors = state.integrationConnectors {
      let normalized = Self.normalizedOpenCodeConnectors(connectors)
      if normalized != connectors {
        state.integrationConnectors = normalized
        changed = true
      }
    }
    if state.integrationConnectors == nil {
      state.integrationConnectors = Self.defaultIntegrationConnectors
      changed = true
    } else {
      let connectors = integrationConnectors
      let defaultIDs = Set(Self.defaultIntegrationConnectors.map { $0.id })
      var existingByID: [String: IntegrationConnector] = [:]
      for connector in connectors where existingByID[connector.id] == nil {
        existingByID[connector.id] = connector
      }
      let mergedDefaults = Self.defaultIntegrationConnectors.map { defaultConnector in
        guard let existing = existingByID[defaultConnector.id] else {
          return defaultConnector
        }
        return Self.connectorByMerging(defaultConnector: defaultConnector, existing: existing)
      }
      let unknownConnectors = connectors.filter { !defaultIDs.contains($0.id) }
      let mergedConnectors = mergedDefaults + unknownConnectors
      if mergedConnectors != connectors {
        changed = true
      }
      state.integrationConnectors = mergedConnectors
    }
    if refreshIntegrationConnectionFlags() {
      changed = true
    }
    if sanitizeHermesChatMessages() {
      changed = true
    }
    let existingRouteIDs = Set(state.modelRoutes.map(\.id))
    let missingRoutes = Self.defaultState.modelRoutes.filter { !existingRouteIDs.contains($0.id) }
    if !missingRoutes.isEmpty {
      state.modelRoutes.append(contentsOf: missingRoutes)
      changed = true
    }
    if normalizeLegacyModelRoutes() {
      changed = true
    }
    if mergeIntelligenceDefaults() {
      changed = true
    }
    if applyProfileDefaults() {
      changed = true
    }
    if mergeCompanyProfilesDefaults() {
      changed = true
    }
    if migrateLegacyCompanyPeopleToContacts() {
      changed = true
    }
    if normalizeWhatsAppContactProfiles() {
      changed = true
    }
    if state.agentRuns == nil {
      state.agentRuns = []
      changed = true
    }
    if normalizeAgentRuns() {
      changed = true
    }
    if normalizeUserVisibleState() {
      changed = true
    }
    if changed && persistChanges {
      persist()
    }
  }

  private func normalizeUserVisibleState() -> Bool {
    let original = try? encoder.encode(state)
    state.profile = Self.normalizedProfileForDisplay(state.profile)
    state.jobs = state.jobs.map(Self.normalizedJobForDisplay)
    state.documents = state.documents.map(Self.normalizedDocumentForDisplay)
    state.events = state.events.map(Self.normalizedEventForDisplay)
    state.interviewSessions = state.interviewSessions.map(Self.normalizedInterviewForDisplay)
    state.companyProfiles = state.companyProfiles?.map(Self.normalizedCompanyForDisplay)
    state.contacts = state.contacts?.map(Self.normalizedContactForDisplay)
    state.promptMemory = state.promptMemory.map(Self.normalizedUserFacingText)
    return original != (try? encoder.encode(state))
  }

  private static func normalizedProfileForDisplay(_ profile: CandidateProfile) -> CandidateProfile {
    var next = profile
    next.headline = next.headline.map(normalizedUserFacingText)
    next.about = next.about.map(normalizedUserFacingText)
    next.targetRoles = next.targetRoles.map(normalizedUserFacingText)
    next.compensationGoal = normalizedUserFacingText(next.compensationGoal)
    next.writingPreferences = next.writingPreferences.map(normalizedUserFacingText)
    next.evidence = next.evidence.map { evidence in
      var normalized = evidence
      normalized.title = normalizedUserFacingText(normalized.title)
      normalized.proof = normalizedUserFacingText(normalized.proof)
      normalized.sourceURL = normalizedSourceReference(normalized.sourceURL)
      normalized.tags = normalized.tags.map(normalizedUserFacingText)
      return normalized
    }
    next.experience = next.experience?.map { experience in
      var normalized = experience
      normalized.title = normalizedUserFacingText(normalized.title)
      normalized.summary = normalizedUserFacingText(normalized.summary)
      normalized.bullets = normalized.bullets.map(normalizedUserFacingText)
      normalized.sourceURL = normalizedSourceReference(normalized.sourceURL)
      normalized.projects = experience.projects?.map { project in
        var nextProject = project
        nextProject.name = normalizedUserFacingText(nextProject.name)
        nextProject.summary = normalizedUserFacingText(nextProject.summary)
        nextProject.detail = normalizedUserFacingText(nextProject.detail)
        nextProject.specificSample = normalizedUserFacingText(nextProject.specificSample)
        nextProject.tools = nextProject.tools.map(normalizedUserFacingText)
        nextProject.metrics = nextProject.metrics.map(normalizedUserFacingText)
        nextProject.tags = nextProject.tags.map(normalizedUserFacingText)
        nextProject.sourceURL = normalizedSourceReference(nextProject.sourceURL)
        return nextProject
      }
      return normalized
    }
    next.skills = next.skills?.map(normalizedUserFacingText)
    next.profileProjects = next.profileProjects?.map { project in
      var normalized = project
      normalized.summary = normalizedUserFacingText(normalized.summary)
      normalized.tags = normalized.tags.map(normalizedUserFacingText)
      return normalized
    }
    next.personalMemory = next.personalMemory?.map { memory in
      var normalized = memory
      normalized.title = normalizedUserFacingText(normalized.title)
      normalized.detail = normalizedUserFacingText(normalized.detail)
      return normalized
    }
    next.linkedInImportPlan = next.linkedInImportPlan.map { plan in
      var normalized = plan
      normalized.fields = normalized.fields.map(normalizedUserFacingText)
      normalized.steps = normalized.steps.map(normalizedUserFacingText)
      return normalized
    }
    return next
  }

  private static func normalizedJobForDisplay(_ job: JobRecord) -> JobRecord {
    var next = job
    next.role = normalizedUserFacingText(next.role)
    next.description = normalizedUserFacingText(next.description)
    next.keywords = next.keywords.map(normalizedUserFacingText)
    next.notes = normalizedUserFacingText(next.notes)
    next.nextActions = next.nextActions.map(normalizedUserFacingText)
    next.draft = next.draft.map(normalizedDraftForDisplay)
    return next
  }

  private static func normalizedDocumentForDisplay(_ document: CandidateDocument) -> CandidateDocument {
    var next = document
    next.title = normalizedUserFacingText(next.title)
    next.summary = normalizedUserFacingText(next.summary)
    return next
  }

  private static func normalizedEventForDisplay(_ event: ActivityEvent) -> ActivityEvent {
    var next = event
    next.title = normalizedUserFacingText(next.title)
    next.detail = normalizedUserFacingText(next.detail)
    return next
  }

  private static func normalizedInterviewForDisplay(_ interview: InterviewSession) -> InterviewSession {
    var next = interview
    next.questions = next.questions.map(normalizedUserFacingText)
    next.scorecard = next.scorecard.map(normalizedUserFacingText)
    next.notes = normalizedUserFacingText(next.notes)
    return next
  }

  private static func normalizedDraftForDisplay(_ draft: ApplicationDraft) -> ApplicationDraft {
    var next = draft
    next.headline = normalizedUserFacingText(next.headline)
    next.resumeBullets = next.resumeBullets.map(normalizedUserFacingText)
    next.coverLetter = normalizedDraftBodyText(next.coverLetter)
    next.recruiterMessage = normalizedUserFacingText(next.recruiterMessage)
    next.screeningAnswers = next.screeningAnswers.map(normalizedDraftBodyText)
    next.evidenceLinks = next.evidenceLinks.map(normalizedSourceReference)
    next.claimTrace = next.claimTrace?.map { trace in
      var normalized = trace
      normalized.evidenceLabel = normalizedUserFacingText(normalized.evidenceLabel)
      normalized.location = normalizedUserFacingText(normalized.location)
      return normalized
    }
    next.assumptions = next.assumptions?.map(normalizedUserFacingText)
    next.missingEvidence = next.missingEvidence?.map(normalizedUserFacingText)
    return next
  }

  private static func normalizedCompanyForDisplay(_ company: CompanyProfile) -> CompanyProfile {
    var next = company
    next.website = normalizedSourceReference(next.website)
    next.summary = normalizedUserFacingText(next.summary)
    next.submittedMaterials = next.submittedMaterials.map { material in
      var normalized = material
      normalized.materialType = normalizedUserFacingText(normalized.materialType)
      normalized.title = normalizedUserFacingText(normalized.title)
      normalized.summary = normalizedUserFacingText(normalized.summary)
      normalized.sourceURL = normalizedSourceReference(normalized.sourceURL)
      return normalized
    }
    next.people = next.people.map { person in
      var normalized = person
      normalized.name = normalizedUserFacingText(normalized.name)
      normalized.title = normalizedUserFacingText(normalized.title)
      normalized.notes = normalizedUserFacingText(normalized.notes)
      return normalized
    }
    next.research = normalizedCompanyResearchForDisplay(next.research)
    next.nextActions = next.nextActions.map(normalizedUserFacingText)
    next.notes = normalizedUserFacingText(next.notes)
    return next
  }

  private static func normalizedCompanyResearchForDisplay(_ research: CompanyResearch) -> CompanyResearch {
    var next = research
    next.websitePages = next.websitePages.map { page in
      var normalized = page
      normalized.title = normalizedUserFacingText(normalized.title)
      normalized.url = normalizedSourceReference(normalized.url)
      normalized.summary = normalizedUserFacingText(normalized.summary)
      return normalized
    }
    next.products = next.products.map(normalizedUserFacingText)
    next.businessModel = normalizedUserFacingText(next.businessModel)
    next.hiringSignals = next.hiringSignals.map(normalizedUserFacingText)
    next.risks = next.risks.map(normalizedUserFacingText)
    next.openQuestions = next.openQuestions.map(normalizedUserFacingText)
    next.sourceURLs = next.sourceURLs.map(normalizedSourceReference)
    next.agentPlan = next.agentPlan.map(normalizedUserFacingText)
    return next
  }

  private static func normalizedContactForDisplay(_ contact: ContactRecord) -> ContactRecord {
    var next = contact
    next.name = normalizedContactName(next)
    next.role = normalizedUserFacingText(next.role)
    next.jobDescription = normalizedUserFacingText(next.jobDescription)
    next.notes = normalizedUserFacingText(next.notes)
    next.personalNotes = normalizedUserFacingText(next.personalNotes)
    next.projectNotes = normalizedUserFacingText(next.projectNotes)
    next.companyLinks = next.companyLinks.map { link in
      var normalized = link
      normalized.role = normalizedUserFacingText(normalized.role)
      normalized.notes = normalizedUserFacingText(normalized.notes)
      return normalized
    }
    next.research.summary = normalizedUserFacingText(next.research.summary)
    next.research.publicFacts = next.research.publicFacts.map(normalizedUserFacingText)
    next.research.openQuestions = next.research.openQuestions.map(normalizedUserFacingText)
    next.research.proposedAdditions = next.research.proposedAdditions.map(normalizedUserFacingText)
    next.agentMessages = next.agentMessages?.map { message in
      var normalized = message
      normalized.traces = normalized.traces.map { trace in
        var normalizedTrace = trace
        normalizedTrace.detail = normalizedUserFacingText(normalizedTrace.detail)
        return normalizedTrace
      }
      return normalized
    }
    return next
  }

  private static func normalizedContactName(_ contact: ContactRecord) -> String {
    let name = normalizedUserFacingText(contact.name)
    let context = ([contact.linkedInURL, contact.sourceURL, contact.research.summary] + contact.research.publicFacts + contact.research.sourceURLs)
      .joined(separator: " ")
      .lowercased()
    if name == "Example Contact", context.contains("example-contact") || context.contains("example-contact dehin") {
      return "Example Contact"
    }
    return name
  }

  private static func normalizedSourceReference(_ value: String) -> String {
    value.replacingOccurrences(
      of: "Apple Mail contract evidence: Example User Vertrag.pdf",
      with: "Apple Mail contract evidence: Example User contract.pdf (original German filename: Example User Vertrag.pdf)"
    )
  }

  private static func normalizedDraftBodyText(_ value: String) -> String {
    isSourceLanguageArtifact(value) ? value : normalizedUserFacingText(value)
  }

  private static func isSourceLanguageArtifact(_ value: String) -> Bool {
    value.range(of: #"\b(Sehr geehrte|Ich bewerbe mich|Finanzthemen|Schweizerdeutsch|Warum VZ)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
  }

  static func normalizedUserFacingText(_ value: String) -> String {
    let protectedWerkstudent = "__SOURCE_WERKSTUDENT__"
    var next = value
      .replacingOccurrences(of: "&amp;", with: "&")
      .replacingOccurrences(of: #"\bAIML\s*-\s*"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\bAIML\b"#, with: "AI and ML", options: .regularExpression)
      .replacingOccurrences(of: #"\bAI/ML\b"#, with: "AI and ML", options: .regularExpression)
      .replacingOccurrences(of: #"\bData\s*/\s*ML\s*/\s*AI Intern\b"#, with: "Data, ML, and AI Intern", options: .regularExpression)
      .replacingOccurrences(of: #"\bIntern Applied AI\s*&\s*AI-Platform\b"#, with: "Applied AI and AI Platform Intern", options: .regularExpression)
      .replacingOccurrences(of: #"\bApplied AI\s*&\s*AI-Platform Intern\b"#, with: "Applied AI and AI Platform Intern", options: .regularExpression)
      .replacingOccurrences(of: "Finance trifft auf Engineering: Trainee-Programm beim VZ, 80-100%", with: "Finance and Engineering Trainee Program at VZ, 80-100%")
      .replacingOccurrences(of: "Contracted as Werkstudent", with: "Contracted as a working student (source role title: \(protectedWerkstudent))")
      .replacingOccurrences(of: #"\bWerkstudent\b"#, with: "Working Student", options: .regularExpression)
      .replacingOccurrences(of: "source role title: Working Student", with: "source role title: \(protectedWerkstudent)")
      .replacingOccurrences(of: protectedWerkstudent, with: "Werkstudent")
      .replacingOccurrences(
        of: "Apple Mail contract evidence: Example User Vertrag.pdf",
        with: "Apple Mail contract evidence: Example User contract.pdf (original German filename: Example User Vertrag.pdf)"
      )
    next = next.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    return next.trimmed
  }

  private func normalizeAgentRuns() -> Bool {
    guard var runs = state.agentRuns else { return false }
    var changed = false
    let staleContextKeys = Set(
      runs
        .filter { run in
          run.trace.contains { step in
            let tool = (step.toolName ?? "").trimmed
            return tool == "web_search" || tool == "local_state" || tool == "browser"
          }
        }
        .map { "\($0.contextKind)|\($0.contextID)" }
    )
    if !staleContextKeys.isEmpty {
      runs.removeAll { staleContextKeys.contains("\($0.contextKind)|\($0.contextID)") }
      for contact in contacts where staleContextKeys.contains("contact|\(contact.id)") {
        runs.insert(contentsOf: Self.contactAgentRuns(contact: contact, companyName: contact.companyLinks.first?.companyName ?? "No company linked"), at: 0)
      }
      for company in companyProfiles where staleContextKeys.contains("company|\(company.id)") {
        runs.insert(contentsOf: Self.companyAgentRuns(company: company, linkedContacts: contacts(for: company.id)), at: 0)
      }
      changed = true
    }
    runs = runs.map { run in
      var next = run
      if ["Queued", "Needs URL", "Needs approval"].contains(next.status) {
        next.status = "Not run"
        changed = true
      }
      next.proposedAdditions = []
      next.trace = next.trace.map { step in
        var normalized = step
        if normalized.kind == nil {
          normalized.kind = step.title.localizedCaseInsensitiveContains("tool") || step.title.localizedCaseInsensitiveContains("source") || step.title.localizedCaseInsensitiveContains("contacts") ? "tool" : "reasoning"
          changed = true
        }
        if normalized.toolName == nil, normalized.kind == "tool" {
          normalized.toolName = "local_state"
          changed = true
        }
        return normalized
      }
      return next
    }
    state.agentRuns = runs
    return changed
  }

  private func normalizeWhatsAppContactProfiles() -> Bool {
    var nextContacts = contacts
    var changed = false
    for index in nextContacts.indices {
      guard var profile = nextContacts[index].communicationProfile?.whatsApp,
            !(profile.messages ?? []).isEmpty,
            let companyID = nextContacts[index].companyLinks.first?.companyID,
            let company = companyProfiles.first(where: { $0.id == companyID }) else { continue }
      let candidate = WhatsAppThreadCandidate(
        id: profile.threadID,
        chatSessionID: profile.chatSessionID,
        displayName: profile.displayName,
        jid: profile.jid,
        messageCount: profile.messageCount,
        lastMessagePreview: profile.lastMessagePreview,
        databasePath: profile.databasePath
      )
      var contact = Self.contactByApplyingWhatsAppProfile(nextContacts[index], profile: profile, candidate: candidate, company: company)
      profile = Self.profileByAddingDrafts(profile, company: company, person: legacyPerson(from: contact), purpose: "Reply to the latest incoming WhatsApp message.")
      var communication = contact.communicationProfile ?? PersonCommunicationProfile()
      communication.whatsApp = profile
      communication.appWideRules = Self.whatsAppAppWideRules
      contact.communicationProfile = communication
      if contact != nextContacts[index] {
        nextContacts[index] = contact
        changed = true
      }
    }
    if changed {
      state.contacts = nextContacts
    }
    return changed
  }

  private func migrateLegacyCompanyPeopleToContacts() -> Bool {
    var next = state.contacts ?? []
    var changed = state.contacts == nil
    for company in companyProfiles {
      for person in company.people {
        let contact = Self.contact(from: person, company: company)
        let result = Self.contactsByUpserting(contact: contact, into: next, company: company)
        if result.contacts != next {
          next = result.contacts
          changed = true
        }
      }
    }
    if changed {
      state.contacts = next.sorted { left, right in
        left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
      }
    }
    return changed
  }

  private func mergeCompanyProfilesDefaults() -> Bool {
    var changed = false
    let shouldSeedSampleCompanies = state.companyProfiles == nil
    var profiles = state.companyProfiles ?? Self.defaultCompanyProfiles
    if state.companyProfiles == nil {
      changed = true
    }

    let existingIDs = Set(profiles.map(\.id))
    let missingDefaults = Self.defaultCompanyProfiles.filter { !existingIDs.contains($0.id) }
    if !missingDefaults.isEmpty {
      profiles.append(contentsOf: missingDefaults)
      changed = true
    }

    for job in state.jobs {
      let result = Self.companyBySyncing(job: job, into: profiles)
      if result.changed {
        profiles = result.profiles
        changed = true
      }
    }

    for experience in profileExperience {
      let organization = experience.organization.trimmed
      guard !organization.isEmpty,
            !["Project", "Open-source project"].contains(organization) else { continue }
      let id = Self.companyID(for: organization)
      if let index = profiles.firstIndex(where: { $0.id == id }) {
        if !profiles[index].experienceIDs.contains(experience.id) {
          profiles[index].experienceIDs.append(experience.id)
          changed = true
        }
        if profiles[index].summary.trimmed.isEmpty || profiles[index].summary.localizedCaseInsensitiveContains("created locally") {
          profiles[index].summary = experience.summary
          changed = true
        }
      } else {
        profiles.append(
          CompanyProfile(
            id: id,
            name: organization,
            website: experience.sourceURL,
            linkedInURL: "",
            category: "Experience",
            size: "Unknown",
            headquarters: experience.location,
            publicStatus: "Unknown",
            summary: experience.summary,
            relationship: "Worked with",
            applicationIDs: [],
            experienceIDs: [experience.id],
            submittedMaterials: [],
            people: [],
            research: Self.emptyCompanyResearch(companyName: organization, website: experience.sourceURL, linkedInURL: ""),
            nextActions: Self.companyNextActions(name: organization),
            notes: experience.bullets.joined(separator: "\n")
          )
        )
        changed = true
      }
    }

    if shouldSeedSampleCompanies {
      for project in profileProjects {
        let id = Self.companyID(for: project.name)
        if !profiles.contains(where: { $0.id == id }) {
          profiles.append(
            CompanyProfile(
              id: id,
              name: project.name,
              website: project.url,
              linkedInURL: "",
              category: "User proof",
              size: "Unknown",
              headquarters: "Unknown",
              publicStatus: "Unknown",
              summary: project.summary,
              relationship: "Built by user",
              applicationIDs: [],
              experienceIDs: [],
              submittedMaterials: [],
              people: [],
              research: Self.emptyCompanyResearch(companyName: project.name, website: project.url, linkedInURL: ""),
              nextActions: Self.companyNextActions(name: project.name),
              notes: ""
            )
          )
          changed = true
        }
      }
    }

    state.companyProfiles = profiles.sorted { left, right in
      if left.relationship == right.relationship {
        return left.name < right.name
      }
      return left.relationship < right.relationship
    }
    return changed
  }

  private func applyProfileDefaults() -> Bool {
    var changed = false
    if state.profile.name.trimmed == "User" {
      state.profile.name = "Example User"
      changed = true
    }
    if (state.profile.headline ?? "").trimmed.isEmpty {
      state.profile.headline = "AI product engineer building agentic tools, finance research systems, and local-first automation."
      changed = true
    }
    if (state.profile.about ?? "").trimmed.isEmpty {
      state.profile.about = "Builds proof-backed AI workflows: agent control planes, finance research systems, safe browser workflows, local-first macOS apps, and review loops that make generated work inspectable."
      changed = true
    }
    if state.profile.experience == nil {
      state.profile.experience = Self.defaultProfileExperience
      changed = true
    }
    if state.profile.skills == nil {
      state.profile.skills = Self.defaultProfileSkills
      changed = true
    }
    if state.profile.profileProjects == nil {
      state.profile.profileProjects = Self.defaultProfileProjects
      changed = true
    }
    if state.profile.personalMemory == nil {
      state.profile.personalMemory = Self.defaultProfileMemory
      changed = true
    }
    if state.profile.certifications == nil {
      state.profile.certifications = []
      changed = true
    }
    if state.profile.education == nil {
      state.profile.education = []
      changed = true
    }
    return changed
  }

  private func mergeIntelligenceDefaults() -> Bool {
    var changed = false
    if state.competitorApps == nil {
      state.competitorApps = Self.defaultCompetitorApps
      changed = true
    } else {
      let existingIDs = Set((state.competitorApps ?? []).map(\.id))
      let missing = Self.defaultCompetitorApps.filter { !existingIDs.contains($0.id) }
      if !missing.isEmpty {
        state.competitorApps?.append(contentsOf: missing)
        changed = true
      }
    }
    if state.jobBoardSources == nil {
      state.jobBoardSources = Self.defaultJobBoardSources
      changed = true
    } else {
      let existingIDs = Set((state.jobBoardSources ?? []).map(\.id))
      let missing = Self.defaultJobBoardSources.filter { !existingIDs.contains($0.id) }
      if !missing.isEmpty {
        state.jobBoardSources?.append(contentsOf: missing)
        changed = true
      }
    }
    if state.automationPlaybooks == nil {
      state.automationPlaybooks = Self.defaultAutomationPlaybooks
      changed = true
    } else {
      let existingIDs = Set((state.automationPlaybooks ?? []).map(\.id))
      let missing = Self.defaultAutomationPlaybooks.filter { !existingIDs.contains($0.id) }
      if !missing.isEmpty {
        state.automationPlaybooks?.append(contentsOf: missing)
        changed = true
      }
    }
    if state.marketComplaints == nil {
      state.marketComplaints = Self.defaultMarketComplaints
      changed = true
    } else {
      let existingIDs = Set((state.marketComplaints ?? []).map(\.id))
      let missing = Self.defaultMarketComplaints.filter { !existingIDs.contains($0.id) }
      if !missing.isEmpty {
        state.marketComplaints?.append(contentsOf: missing)
        changed = true
      }
    }
    return changed
  }

  private func normalizeLegacyModelRoutes() -> Bool {
    var changed = false
    for index in state.modelRoutes.indices {
      if state.modelRoutes[index].provider == "OpenCode" {
        state.modelRoutes[index].provider = "OpenCode Go"
        state.modelRoutes[index].baseURL = "https://opencode.ai/zen/go/v1"
        state.modelRoutes[index].keyReference = "OPENCODE_GO_API_KEY"
        changed = true
      }
    }
    let allowedIDs = Set(["cheap-drafts", "standard-writing", "final-review"])
    let nextRoutes = Self.defaultState.modelRoutes.compactMap { defaultRoute -> ModelRoute? in
      guard allowedIDs.contains(defaultRoute.id) else { return nil }
      var route = state.modelRoutes.first(where: { $0.id == defaultRoute.id }) ?? defaultRoute
      route.label = defaultRoute.label
      route = normalizedModelRoute(route, defaultRoute: defaultRoute)
      if route.purpose.trimmed.isEmpty || !allowedIDs.contains(route.id) {
        route.purpose = defaultRoute.purpose
      }
      return route
    }
    if state.modelRoutes != nextRoutes {
      state.modelRoutes = nextRoutes
      changed = true
    }
    return changed
  }

  private func normalizedModelRoute(_ route: ModelRoute, defaultRoute: ModelRoute? = nil) -> ModelRoute {
    var next = route
    let provider = ModelCatalog.provider(for: next)
    if provider.id == "openai", next.keyReference.localizedCaseInsensitiveContains("codex account") {
      next.keyReference = "OPENAI_API_KEY"
    }
    let reasoningLevels = ModelCatalog.reasoningLevels(for: next)
    if reasoningLevels.isEmpty {
      next.reasoningEffort = nil
    } else if let effort = next.reasoningEffort, reasoningLevels.contains(where: { $0.id == effort }) {
      next.reasoningEffort = effort
    } else if let fallback = defaultRoute?.reasoningEffort, reasoningLevels.contains(where: { $0.id == fallback }) {
      next.reasoningEffort = fallback
    } else {
      next.reasoningEffort = reasoningLevels.first?.id
    }
    if let connector = integrationConnectors.first(where: { $0.id == provider.id }) {
      next.isConnected = connector.isEnabled && connector.isConnected
    }
    return next
  }

  @discardableResult
  private func refreshIntegrationConnectionFlags() -> Bool {
    var connectors = integrationConnectors
    var changed = false
    for index in connectors.indices {
      let detected = Self.detectConnection(for: connectors[index])
      if connectors[index].isConnected != detected {
        connectors[index].isConnected = detected
        changed = true
      }
    }
    if changed {
      var next = state
      next.integrationConnectors = connectors
      for index in next.modelRoutes.indices {
        let provider = ModelCatalog.provider(for: next.modelRoutes[index])
        let isConnected = connectors.first(where: { $0.id == provider.id }).map { $0.isEnabled && $0.isConnected } ?? false
        next.modelRoutes[index].isConnected = isConnected
      }
      state = next
      return true
    }
    return syncModelRouteConnectionFlags()
  }

  @discardableResult
  private func syncModelRouteConnectionFlags() -> Bool {
    var next = state
    var changed = false
    let connectors = next.integrationConnectors ?? Self.defaultIntegrationConnectors
    for index in next.modelRoutes.indices {
      let provider = ModelCatalog.provider(for: next.modelRoutes[index])
      let isConnected = connectors.first(where: { $0.id == provider.id }).map { $0.isEnabled && $0.isConnected } ?? false
      if next.modelRoutes[index].isConnected != isConnected {
        next.modelRoutes[index].isConnected = isConnected
        changed = true
      }
    }
    if changed {
      state = next
    }
    return changed
  }

  private static func detectConnection(for connector: IntegrationConnector) -> Bool {
    guard connector.isEnabled else { return false }
    switch connector.id {
    case "openai":
      let keyRef = configValue("api-key-ref", in: connector)
      return hasEnvironmentValue("OPENAI_API_KEY") || (!keyRef.trimmed.isEmpty && hasEnvironmentValue(keyRef))
    case "xai", "grok":
      let keyRef = configValue("api-key-ref", in: connector)
      return isGrokAuthenticated(keyReference: keyRef)
    case "opencode-go":
      return isOpenCodeProviderConnected("opencode-go", environmentKeys: ["OPENCODE_GO_API_KEY", "OPENCODE_API_KEY"])
    case "opencode-zen":
      return isOpenCodeProviderConnected("opencode", environmentKeys: ["OPENCODE_ZEN_API_KEY", "OPENCODE_API_KEY"])
    case "cursor":
      // Process-backed authentication checks are intentionally excluded here.
      // This path is used during store initialization and live field editing.
      return hasEnvironmentValue("CURSOR_API_KEY")
    case "hermes":
      return FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.local/bin/hermes")
    case "telegram":
      let tokenRef = configValue("bot-token-ref", in: connector)
      let chatID = configValue("chat-id", in: connector)
      return !chatID.trimmed.isEmpty && telegramToken(from: tokenRef) != nil
    case "whatsapp":
      let path = configValue("database-path", in: connector)
      return WhatsAppLocalStore.isReadableDatabase(at: path.isEmpty ? WhatsAppLocalStore.defaultDatabasePath : expandedHomePath(path))
    case "google-drive", "google-docs", "gmail", "google-calendar", "google-sheets", "google-slides":
      return hasAnyEnvironmentValue(["GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_OAUTH_CLIENT_ID"])
        || FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.config/gcloud/application_default_credentials.json")
        || !configValue("profile", in: connector).trimmed.isEmpty
    case "microsoft-365", "outlook", "onedrive", "word":
      return hasAnyEnvironmentValue(["MICROSOFT_CLIENT_ID", "MSGRAPH_CLIENT_ID"])
        || !configValue("tenant", in: connector).trimmed.isEmpty
        || !configValue("mailbox", in: connector).trimmed.isEmpty
    case "github":
      return hasAnyEnvironmentValue(["GITHUB_TOKEN", "GH_TOKEN"])
        || FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.config/gh/hosts.yml")
    case "figma":
      return hasAnyEnvironmentValue(["FIGMA_TOKEN"])
    case "railway":
      return hasAnyEnvironmentValue(["RAILWAY_TOKEN"])
        || FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.railway")
    case "hugging-face":
      return hasAnyEnvironmentValue(["HF_TOKEN", "HUGGINGFACE_TOKEN"])
        || FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.cache/huggingface/token")
    case "linear":
      return hasAnyEnvironmentValue(["LINEAR_API_KEY"])
    case "notion":
      return hasAnyEnvironmentValue(["NOTION_TOKEN"])
    case "local-documents":
      return true
    case "apple-mail":
      return FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Mail")
    default:
      return false
    }
  }

  private static func normalizedOpenCodeConnectors(_ connectors: [IntegrationConnector]) -> [IntegrationConnector] {
    var normalized: [IntegrationConnector] = []
    for connector in connectors {
      let wasLegacy = connector.id == "opencode"
      var next = connector
      if wasLegacy {
        next.id = "opencode-go"
        next.label = "OpenCode Go"
        next.provider = "OpenCode Go"
        next.purpose = "OpenCode Go subscription models."
        next.configFields = [connectorField("api-key-ref", "API key variable", placeholder: "OPENCODE_GO_API_KEY", isSecret: true)]
      }
      if let index = normalized.firstIndex(where: { $0.id == next.id }) {
        if !wasLegacy {
          normalized[index] = next
        }
      } else {
        normalized.append(next)
      }
    }
    return normalized
  }

  private static func connectorByMerging(defaultConnector: IntegrationConnector, existing: IntegrationConnector) -> IntegrationConnector {
    let existingFields = existing.configFields ?? []
    let mergedFields = (defaultConnector.configFields ?? []).map { defaultField in
      guard let existingField = existingFields.first(where: { $0.id == defaultField.id }) else {
        return defaultField
      }
      return ConnectorConfigField(
        id: defaultField.id,
        label: defaultField.label,
        value: existingField.value,
        placeholder: defaultField.placeholder,
        isSecret: defaultField.isSecret
      )
    }
    return IntegrationConnector(
      id: defaultConnector.id,
      label: defaultConnector.label,
      provider: defaultConnector.provider,
      purpose: defaultConnector.purpose,
      isEnabled: existing.isEnabled,
      isConnected: false,
      category: defaultConnector.category,
      capabilities: defaultConnector.capabilities,
      configFields: mergedFields,
      isHidden: existing.isHidden
    )
  }

  private static func configValue(_ fieldID: String, in connector: IntegrationConnector) -> String {
    connector.configFields?.first(where: { $0.id == fieldID })?.value.trimmed ?? ""
  }

  private static func expandedHomePath(_ path: String) -> String {
    NSString(string: path).expandingTildeInPath
  }

  private static func contactByApplyingWhatsAppProfile(
    _ contact: ContactRecord,
    profile: WhatsAppThreadProfile,
    candidate: WhatsAppThreadCandidate,
    company: CompanyProfile
  ) -> ContactRecord {
    var next = contact
    let messages = profile.messages ?? []
    let inferredName = bestWhatsAppContactName(profile: profile, messages: messages)
    if !inferredName.isEmpty, shouldReplaceWhatsAppPlaceholderName(next.name, candidate: candidate) {
      next.name = inferredName
      next.research.openQuestions = next.research.openQuestions
        .filter { !$0.localizedCaseInsensitiveContains("what does \(contact.name) do now?") }
    }
    let phone = phoneNumber(fromWhatsAppCandidate: candidate)
    if next.phone.trimmed.isEmpty, !phone.isEmpty {
      next.phone = phone
    }
    if next.howMet.trimmed.isEmpty {
      next.howMet = "WhatsApp"
    }
    if next.relationship.trimmed.isEmpty || next.relationship == "WhatsApp contact" || next.relationship == "Contact" {
      next.relationship = "Hiring contact"
    }
    next.notes = cleanedWhatsAppImportNotes(next.notes)
    if messages.contains(where: { !$0.isFromMe && $0.text.localizedCaseInsensitiveContains("supply chain") && $0.text.localizedCaseInsensitiveContains("intern") }) {
      if next.role.trimmed.isEmpty {
        next.role = "Supply Chain internship contact"
      }
      next.notes = joinedUnique([
        next.notes,
        "Asked to schedule a brief call about a Supply Chain internship at \(company.name)."
      ])
    }
    return next
  }

  private static func profileByAddingDrafts(_ profile: WhatsAppThreadProfile, company: CompanyProfile, person: CompanyPerson, purpose: String) -> WhatsAppThreadProfile {
    var next = profile
    let firstName = person.name.split(separator: " ").first.map(String.init) ?? person.name
    if latestUnansweredIncomingText(profile.messages ?? []) == nil, !(profile.messages ?? []).isEmpty {
      next.suggestedDirectMessage = ""
      next.suggestedEmailMessage = ""
      return next
    }
    if let reply = suggestedWhatsAppReply(profile: profile, firstName: firstName, companyName: company.name) {
      next.suggestedDirectMessage = reply
      next.suggestedEmailMessage = ""
      return next
    }
    let cleanPurpose = purpose.trimmed.isEmpty ? "ask for useful hiring context or the right person to speak with" : purpose.trimmed
    let companyContext = company.applicationIDs.isEmpty ? company.summary : "\(company.name) has \(company.applicationIDs.count) tracked role(s) in Jobmaxxing."
    next.suggestedDirectMessage = [
      "Hey \(firstName), quick one.",
      "I’m looking at \(company.name) and wanted your read.",
      cleanPurpose,
      "Would you point me to the right person or tell me what to watch for?"
    ].joined(separator: " ")
    next.suggestedEmailMessage = [
      "Subject: Quick question on \(company.name)",
      "",
      "Hi \(firstName),",
      "",
      "I am looking at \(company.name) and wanted to ask for your perspective.",
      companyContext,
      "",
      cleanPurpose,
      "",
      "Would you be open to pointing me toward the right person or sharing what I should understand first?",
      "",
      "Best,",
      "User"
    ].joined(separator: "\n")
    return next
  }

  private static func suggestedWhatsAppReply(profile: WhatsAppThreadProfile, firstName: String, companyName: String) -> String? {
    guard let latestIncoming = latestUnansweredIncomingText(profile.messages ?? []) else {
      return nil
    }
    let name = firstName.trimmed.isEmpty || firstName.contains("+") ? nameFromWhatsAppSignature(messages: profile.messages ?? []) : firstName
    let greetingName = name.trimmed.isEmpty ? "" : " \(name)"
    let lower = latestIncoming.lowercased()
    if lower.contains("18:00") || lower.contains("18:30") || lower.contains("would that be okay") {
      return [
        "Good afternoon\(greetingName),",
        "",
        "Yes, 18:00-18:30 works for me. Please call me when you are ready.",
        "",
        "Kind regards,",
        "User"
      ].joined(separator: "\n")
    }
    if lower.contains("today") && lower.contains("tomorrow") && (lower.contains("call") || lower.contains("available")) {
      let opportunity = lower.contains("supply chain") && lower.contains("intern")
        ? "the internship opportunity with the Supply Chain team"
        : "the opportunity"
      return [
        "Good afternoon\(greetingName),",
        "",
        "Thank you for reaching out and for the context. I would be very interested to discuss \(opportunity).",
        "",
        "I am free for the rest of today, so please let me know what time works best for you. I am also free tomorrow if that would suit you better.",
        "",
        "Kind regards,",
        "User"
      ].joined(separator: "\n")
    }
    if lower.contains("call") || lower.contains("available") {
      return [
        "Good afternoon\(greetingName),",
        "",
        "Thank you for reaching out. I would be happy to speak.",
        "",
        "I am free for the rest of the day, so please let me know what time works best for you. I am also free tomorrow if that would fit better.",
        "",
        "Kind regards,",
        "User"
      ].joined(separator: "\n")
    }
    return nil
  }

  private static func latestUnansweredIncomingText(_ messages: [WhatsAppThreadMessage]) -> String? {
    guard let latestIncomingIndex = messages.lastIndex(where: { !$0.isFromMe }) else {
      return nil
    }
    if let latestOutgoingIndex = messages.lastIndex(where: { $0.isFromMe }), latestOutgoingIndex > latestIncomingIndex {
      return nil
    }
    let text = messages[latestIncomingIndex].text.trimmed
    return text.isEmpty ? nil : text
  }

  private static func bestWhatsAppContactName(profile: WhatsAppThreadProfile, messages: [WhatsAppThreadMessage]) -> String {
    let signatureName = nameFromWhatsAppSignature(messages: messages)
    if !signatureName.isEmpty {
      return signatureName
    }
    let displayName = profile.displayName.trimmed
    return isLikelyPersonName(displayName) ? displayName : ""
  }

  private static func nameFromWhatsAppSignature(messages: [WhatsAppThreadMessage]) -> String {
    for message in messages.reversed() where !message.isFromMe {
      let lines = message.text
        .components(separatedBy: .newlines)
        .map { $0.trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ",.")) }
        .filter { !$0.isEmpty }
      for index in lines.indices.dropLast() {
        let signoff = lines[index].lowercased()
        if ["best", "kind regards", "regards", "thanks", "thank you"].contains(signoff) {
          let candidate = lines[lines.index(after: index)]
          if isLikelyPersonName(candidate) {
            return candidate
          }
        }
      }
    }
    return ""
  }

  private static func isLikelyPersonName(_ value: String) -> Bool {
    let clean = value.trimmed
    guard (2...40).contains(clean.count) else { return false }
    guard clean.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
    return clean.rangeOfCharacter(from: .letters) != nil && clean.split(separator: " ").count <= 3
  }

  private static func shouldReplaceWhatsAppPlaceholderName(_ name: String, candidate: WhatsAppThreadCandidate) -> Bool {
    let clean = name.trimmed
    let phone = phoneNumber(fromWhatsAppCandidate: candidate)
    return clean.isEmpty
      || clean == "WhatsApp contact"
      || clean == "Unknown WhatsApp sender"
      || clean == candidate.displayName
      || clean == phone
      || clean.filter(\.isNumber) == phone.filter(\.isNumber)
      || phoneNumber(fromWhatsAppLabel: clean) == "+\(clean.filter(\.isNumber))"
  }

  private static func cleanedWhatsAppImportNotes(_ notes: String) -> String {
    notes
      .components(separatedBy: .newlines)
      .map(\.trimmed)
      .filter { line in
        !line.isEmpty
          && !line.localizedCaseInsensitiveContains("message body was not read")
          && !line.localizedCaseInsensitiveContains("message bodies were not read")
          && !line.localizedCaseInsensitiveContains("whatsapp thread has")
          && !line.localizedCaseInsensitiveContains("added from latest whatsapp metadata")
          && !line.localizedCaseInsensitiveContains("added from whatsapp search")
          && !line.localizedCaseInsensitiveContains("whatsapp access granted")
      }
      .uniqued
      .joined(separator: "\n")
  }

  private static func companyByUpserting(person: CompanyPerson, into company: CompanyProfile) -> CompanyProfile {
    var next = company
    let newWhatsAppJID = person.communicationProfile?.whatsApp?.jid.trimmed ?? ""
    if let index = next.people.firstIndex(where: { existing in
      existing.name.caseInsensitiveCompare(person.name) == .orderedSame ||
        (!newWhatsAppJID.isEmpty && existing.communicationProfile?.whatsApp?.jid == newWhatsAppJID)
    }) {
      var merged = next.people[index]
      merged.title = person.title.isEmpty ? merged.title : person.title
      merged.sourceURL = person.sourceURL.isEmpty ? merged.sourceURL : person.sourceURL
      merged.relationship = person.relationship.isEmpty ? merged.relationship : person.relationship
      merged.notes = [merged.notes, person.notes]
        .map(\.trimmed)
        .filter { !$0.isEmpty }
        .uniqued
        .joined(separator: "\n")
      merged.communicationProfile = person.communicationProfile ?? merged.communicationProfile
      next.people.remove(at: index)
      next.people.insert(merged, at: 0)
    } else {
      next.people.insert(person, at: 0)
    }
    return next
  }

  private static func emptyContactResearch(name: String) -> ContactResearchProfile {
    ContactResearchProfile(
      status: "Not researched",
      summary: "No public contact research saved yet.",
      publicFacts: [],
      sourceURLs: [],
      openQuestions: [
        "What does \(name) do now?",
        "How does the user know this person?",
        "Which company or application does this contact help with?"
      ],
      proposedAdditions: []
    )
  }

  static func phoneNumber(fromWhatsAppJID jid: String) -> String {
    let localPart = jid.trimmed.split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
    guard jid.trimmed.hasSuffix("@s.whatsapp.net") else { return "" }
    guard !localPart.contains("-") else { return "" }
    let digits = localPart.filter(\.isNumber)
    guard digits.count >= 7 else { return "" }
    return "+\(digits)"
  }

  static func phoneNumber(fromWhatsAppLabel label: String) -> String {
    let clean = label.trimmed
    let digits = clean.filter(\.isNumber)
    guard digits.count >= 7 else { return "" }
    guard clean.contains("+") || clean.contains(" ") || clean.contains("-") else { return "" }
    return "+\(digits)"
  }

  static func phoneNumber(fromWhatsAppCandidate candidate: WhatsAppThreadCandidate) -> String {
    let fromJID = phoneNumber(fromWhatsAppJID: candidate.jid)
    return fromJID.isEmpty ? phoneNumber(fromWhatsAppLabel: candidate.displayName) : fromJID
  }

  static func whatsAppContactName(candidate: WhatsAppThreadCandidate, fallbackName: String) -> String {
    let displayName = candidate.displayName.trimmed
    let fallback = fallbackName.trimmed
    let phone = phoneNumber(fromWhatsAppCandidate: candidate)
    if !displayName.isEmpty,
       !displayName.contains("@"),
       displayName != candidate.jid,
       displayName != phone,
       displayName.filter(\.isNumber) != phone.filter(\.isNumber) {
      return displayName
    }
    if !fallback.isEmpty {
      return fallback
    }
    return phone.isEmpty ? "Unknown WhatsApp sender" : phone
  }

  private static func contactCompanyLinkID(contactID: String, companyID: String) -> String {
    "\(contactID)-\(companyID)-link"
  }

  private static func contact(from person: CompanyPerson, company: CompanyProfile) -> ContactRecord {
    let source = person.sourceURL.trimmed
    let linkedInURL = source.lowercased().contains("linkedin.com") ? source : ""
    let phone = source.lowercased().hasPrefix("tel:") ? source.replacingOccurrences(of: "tel:", with: "") : ""
    return ContactRecord(
      id: person.id,
      name: person.name,
      role: person.title,
      jobDescription: "",
      linkedInURL: linkedInURL,
      phone: phone,
      email: "",
      location: "",
      sourceURL: source,
      relationship: person.relationship,
      howMet: "",
      notes: person.notes,
      personalNotes: "",
      projectNotes: "",
      companyLinks: [
        ContactCompanyLink(
          id: contactCompanyLinkID(contactID: person.id, companyID: company.id),
          companyID: company.id,
          companyName: company.name,
          role: person.title,
          relationship: person.relationship,
          notes: person.notes,
          sourceURL: source
        )
      ],
      research: emptyContactResearch(name: person.name),
      communicationProfile: person.communicationProfile
    )
  }

  private static func contactsByUpserting(contact: ContactRecord, into contacts: [ContactRecord], company: CompanyProfile?) -> (contacts: [ContactRecord], contactID: String) {
    var next = contacts
    let incomingWhatsAppJID = contact.communicationProfile?.whatsApp?.jid.trimmed ?? ""
    let incomingLinkedIn = contact.linkedInURL.trimmed.lowercased()
    let incomingPhone = contact.phone.trimmed
    let incomingCompanyIDs = Set(contact.companyLinks.map(\.companyID))

    if let index = next.firstIndex(where: { existing in
      let existingCompanyIDs = Set(existing.companyLinks.map(\.companyID))
      let sharesCompany = !incomingCompanyIDs.isDisjoint(with: existingCompanyIDs)
      return existing.id == contact.id
        || (!incomingPhone.isEmpty && existing.phone.trimmed == incomingPhone)
        || (!incomingLinkedIn.isEmpty && existing.linkedInURL.trimmed.lowercased() == incomingLinkedIn)
        || (!incomingWhatsAppJID.isEmpty && existing.communicationProfile?.whatsApp?.jid == incomingWhatsAppJID)
        || (existing.name.caseInsensitiveCompare(contact.name) == .orderedSame && (sharesCompany || existing.companyLinks.isEmpty || incomingCompanyIDs.isEmpty))
    }) {
      var merged = next[index]
      merged.role = merged.role.trimmed.isEmpty ? contact.role : merged.role
      merged.jobDescription = merged.jobDescription.trimmed.isEmpty ? contact.jobDescription : merged.jobDescription
      merged.linkedInURL = merged.linkedInURL.trimmed.isEmpty ? contact.linkedInURL : merged.linkedInURL
      merged.phone = merged.phone.trimmed.isEmpty ? contact.phone : merged.phone
      merged.email = merged.email.trimmed.isEmpty ? contact.email : merged.email
      merged.location = merged.location.trimmed.isEmpty ? contact.location : merged.location
      merged.sourceURL = merged.sourceURL.trimmed.isEmpty ? contact.sourceURL : merged.sourceURL
      merged.relationship = merged.relationship.trimmed.isEmpty || merged.relationship == "Contact" ? contact.relationship : merged.relationship
      merged.howMet = merged.howMet.trimmed.isEmpty ? contact.howMet : merged.howMet
      merged.notes = joinedUnique([merged.notes, contact.notes])
      merged.personalNotes = joinedUnique([merged.personalNotes, contact.personalNotes])
      merged.projectNotes = joinedUnique([merged.projectNotes, contact.projectNotes])
      merged.research.sourceURLs = (merged.research.sourceURLs + contact.research.sourceURLs).uniqued
      merged.research.openQuestions = (merged.research.openQuestions + contact.research.openQuestions).uniqued
      merged.research.proposedAdditions = (merged.research.proposedAdditions + contact.research.proposedAdditions).uniqued
      merged.communicationProfile = merged.communicationProfile ?? contact.communicationProfile
      for link in contact.companyLinks {
        if let linkedCompany = company, link.companyID == linkedCompany.id {
          merged = contactByLinking(
            merged,
            to: linkedCompany,
            role: link.role,
            relationship: link.relationship,
            notes: link.notes,
            sourceURL: link.sourceURL
          )
        } else if !merged.companyLinks.contains(where: { $0.companyID == link.companyID }) {
          merged.companyLinks.append(link)
        }
      }
      next.remove(at: index)
      next.insert(merged, at: 0)
      return (next, merged.id)
    }

    next.insert(contact, at: 0)
    return (next, contact.id)
  }

  private static func contactByLinking(_ contact: ContactRecord, to company: CompanyProfile, role: String, relationship: String, notes: String, sourceURL: String) -> ContactRecord {
    var next = contact
    let linkID = contactCompanyLinkID(contactID: contact.id, companyID: company.id)
    let cleanRole = role.trimmed
    let cleanRelationship = relationship.trimmed.isEmpty ? "Contact" : relationship.trimmed
    let cleanNotes = notes.trimmed
    let cleanSourceURL = sourceURL.trimmed
    if let index = next.companyLinks.firstIndex(where: { $0.companyID == company.id }) {
      var link = next.companyLinks[index]
      link.companyName = company.name
      link.role = link.role.trimmed.isEmpty ? cleanRole : link.role
      link.relationship = link.relationship.trimmed.isEmpty || link.relationship == "Contact" ? cleanRelationship : link.relationship
      link.notes = joinedUnique([link.notes, cleanNotes])
      link.sourceURL = link.sourceURL.trimmed.isEmpty ? cleanSourceURL : link.sourceURL
      next.companyLinks[index] = link
    } else {
      next.companyLinks.append(
        ContactCompanyLink(
          id: linkID,
          companyID: company.id,
          companyName: company.name,
          role: cleanRole,
          relationship: cleanRelationship,
          notes: cleanNotes,
          sourceURL: cleanSourceURL
        )
      )
    }
    next.role = next.role.trimmed.isEmpty ? cleanRole : next.role
    next.relationship = next.relationship.trimmed.isEmpty || next.relationship == "Contact" ? cleanRelationship : next.relationship
    next.sourceURL = next.sourceURL.trimmed.isEmpty ? cleanSourceURL : next.sourceURL
    return next
  }

  private static func joinedUnique(_ values: [String]) -> String {
    values
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .uniqued
      .joined(separator: "\n")
  }

  private struct ContactAgentResult {
    var contact: ContactRecord
    var text: String
    var traces: [HermesTraceStep]
    var modelTier: String
  }

  private func runContactAgent(contact original: ContactRecord, userText: String, modelTier _: String) -> ContactAgentResult {
    var contact = original
    let tier = "Local"
    let company = contact.companyLinks.first.flatMap { link in companyProfiles.first(where: { $0.id == link.companyID }) }
    let lower = userText.lowercased()
    let wantsEmail = lower.contains("email")
    let wantsDraft = lower.contains("draft") || lower.contains("follow-up") || lower.contains("reply") || lower.contains("message")
    let wantsChrome = lower.contains("chrome") || lower.contains("browser") || lower.contains("linkedin")
    let sources = ([
      contact.linkedInURL,
      contact.sourceURL,
      company?.website ?? "",
      company?.linkedInURL ?? ""
    ] + (company?.research.sourceURLs ?? []))
      .map(\.trimmed)
      .filter { !$0.isEmpty }
      .uniqued
    contact.research = Self.deepContactResearchProfile(contact: contact, company: company, sources: sources)
    let draft = wantsDraft ? Self.followUpDraft(for: contact) : ""
    let emailStatus = wantsEmail || lower.contains("deep") || lower.contains("profile")
      ? Self.emailSearchStatus(for: contact)
      : ""
    var responseSections = [
      "Local plan prepared from saved data for \(contact.name). No model, search, or browser research ran.",
      Self.contactProfileAnswer(contact: contact, company: company),
      emailStatus
    ].filter { !$0.trimmed.isEmpty }
    if !draft.isEmpty {
      responseSections.append("Draft follow-up:\n\(draft)")
    }
    if wantsChrome {
      responseSections.append(Self.chromeResearchHandoff(for: contact, sources: sources))
    }
    let traces = [
      Self.trace("Prepare local plan", tool: "local_planner", detail: "Review saved context for \(contact.name). No model or browser ran."),
      Self.trace("Read contact record", tool: "local_state", detail: Self.contactTraceSnapshot(contact)),
      Self.trace("Read linked WhatsApp thread", tool: "whatsapp", detail: Self.contactWhatsAppProfileSummary(contact: contact)),
      Self.trace("Public profile targets", tool: wantsChrome ? "chrome" : "browser", status: "planned", detail: sources.isEmpty ? "No public source is saved yet." : sources.joined(separator: "\n")),
      Self.trace("Write contact profile", tool: "state_write", detail: Self.contactResearchWriteSummary(contact)),
      Self.trace("Safety boundary", tool: "reasoning", detail: "Draft-only communications. No WhatsApp message, email, LinkedIn message, or external form was sent.")
    ]
    return ContactAgentResult(
      contact: contact,
      text: responseSections.joined(separator: "\n\n"),
      traces: traces,
      modelTier: tier
    )
  }

  private static func deepContactResearchProfile(contact: ContactRecord, company: CompanyProfile?, sources: [String]) -> ContactResearchProfile {
    let companyName = company?.name ?? contact.companyLinks.first?.companyName ?? "No company linked"
    var publicFacts: [String] = []
    if !contact.linkedInURL.trimmed.isEmpty {
      publicFacts.append("Saved public profile: \(contact.linkedInURL.trimmed).")
    }
    if !contact.role.trimmed.isEmpty {
      publicFacts.append("Saved role/title: \(contact.role.trimmed).")
    }
    if let company {
      publicFacts.append("Company context: \(company.summary.trimmed.isEmpty ? company.name : company.summary.trimmed)")
    }
    let conversationSummary = contactWhatsAppProfileSummary(contact: contact)
    let summary = [
      "\(contact.name) is saved as a \(contact.role.trimmed.isEmpty ? "contact" : contact.role.trimmed) linked to \(companyName).",
      conversationSummary,
      contact.email.trimmed.isEmpty ? "Email is not saved yet." : "Email is saved.",
      contact.linkedInURL.trimmed.isEmpty ? "LinkedIn is not saved yet." : "LinkedIn is saved and should be treated as the public profile target."
    ]
      .filter { !$0.trimmed.isEmpty }
      .joined(separator: " ")
    let proposedAdditions = [
      contact.email.trimmed.isEmpty ? "Find a reliable email only from a reviewed source or ask directly; do not guess one." : "",
      contact.linkedInURL.trimmed.isEmpty ? "Use Browser to find and review a public LinkedIn or personal profile." : "Use the saved LinkedIn URL as the public profile target and verify identity before citing it externally.",
      "Keep WhatsApp conversation context person-scoped and draft-only.",
      "When drafting replies, use the latest unanswered incoming WhatsApp message, the signed name, and a distinct closing from the sender."
    ].filter { !$0.trimmed.isEmpty }
    let openQuestions = [
      contact.email.trimmed.isEmpty ? "What is a reliable email address for \(contact.name)?" : "",
      contact.linkedInURL.trimmed.isEmpty ? "Which reviewed public profile belongs to \(contact.name)?" : "Is the saved public profile confirmed as this exact contact?",
      "What is \(contact.name)'s role in the hiring process?",
      "Which remaining details need a reviewed source before they can be used?"
    ].filter { !$0.trimmed.isEmpty }
    return ContactResearchProfile(
      status: "Local plan ready",
      summary: summary,
      publicFacts: publicFacts.uniqued,
      sourceURLs: (sources + (company?.research.sourceURLs ?? [])).uniqued,
      openQuestions: openQuestions.uniqued,
      proposedAdditions: proposedAdditions.uniqued
    )
  }

  private static func contactProfileAnswer(contact: ContactRecord, company: CompanyProfile?) -> String {
    [
      "Local profile summary:",
      contact.research.summary,
      "",
      "Key sourced facts:",
      contact.research.publicFacts.map { "- \($0)" }.joined(separator: "\n"),
      "",
      "Still not reliable enough to claim:",
      contact.research.openQuestions.map { "- \($0)" }.joined(separator: "\n")
    ].joined(separator: "\n").trimmed
  }

  private static func emailSearchStatus(for contact: ContactRecord) -> String {
    if !contact.email.trimmed.isEmpty {
      return "Saved email: \(contact.email.trimmed)."
    }
    return "Saved email check: no email is stored. No search ran, and no address was guessed."
  }

  private static func chromeResearchHandoff(for contact: ContactRecord, sources: [String]) -> String {
    [
      "Browser research plan:",
      "Open the saved public profile and source URLs.",
      "Review the experience timeline, current role, prior roles, education, certifications, skills, and visible posts.",
      "Write back only visible sourced facts.",
      "Targets:",
      sources.map { "- \($0)" }.joined(separator: "\n")
    ].joined(separator: "\n")
  }

  private static func followUpDraft(for contact: ContactRecord) -> String {
    let firstName = contact.name.split(separator: " ").first.map(String.init) ?? contact.name
    return [
      "Good afternoon \(firstName),",
      "",
      "Thank you for getting in touch.",
      "",
      "I would be happy to send over any additional information that would be useful. Please let me know if there is anything specific you would like from me before the next step.",
      "",
      "Kind regards,",
      "User"
    ].joined(separator: "\n")
  }

  private static func contactWhatsAppProfileSummary(contact: ContactRecord) -> String {
    guard let profile = contact.communicationProfile?.whatsApp,
          let firstIncoming = profile.messages?.first(where: { !$0.isFromMe })?.text.trimmed else {
      return "No linked WhatsApp conversation is saved."
    }
    var points: [String] = []
    if firstIncoming.localizedCaseInsensitiveContains("Adil Kourbal") {
      points.append("The saved thread mentions Adil Kourbal.")
    }
    if firstIncoming.localizedCaseInsensitiveContains("Supply Chain") && firstIncoming.localizedCaseInsensitiveContains("intern") {
      points.append("The saved thread mentions a supply-chain internship.")
    }
    if firstIncoming.localizedCaseInsensitiveContains("brief call") {
      points.append("\(contact.name) asked for a brief call.")
    }
    if profile.messages?.contains(where: { !$0.isFromMe && $0.text.contains("18:00") }) == true {
      points.append("The saved conversation includes a proposed time around 18:00.")
    }
    return points.isEmpty ? "WhatsApp thread is saved for context and reply drafting." : points.joined(separator: " ")
  }

  private static func contactAgentRuns(contact: ContactRecord, companyName: String) -> [ResearchAgentRun] {
    let linkedInTarget = contact.linkedInURL.trimmed.isEmpty
      ? "\(contact.name) \(companyName) LinkedIn"
      : contact.linkedInURL.trimmed
    let publicQuery = "\(contact.name) \(companyName) role profile"
    return [
      researchAgentRun(
        contextKind: "contact",
        contextID: contact.id,
        title: "Profile inputs",
        agentName: "Local planner",
        status: "Prepared",
        summary: "",
        proposedAdditions: [],
        trace: [
          ("reasoning", "Objective", "", "Prepare a profile plan for \(contact.name) from saved fields only. Do not invent public facts or rewrite private notes.", "done"),
          ("tool", "Read contact record", "Local state", contactTraceSnapshot(contact), "done"),
          ("tool", "Read WhatsApp thread", "Local state", contactWhatsAppProfileSummary(contact: contact), "done"),
          ("tool", "Write research fields", "State write", contactResearchWriteSummary(contact), "done"),
          ("reasoning", "Boundary", "", "Public facts stay empty unless a source URL has been reviewed and saved. Private WhatsApp context stays person-scoped.", "done")
        ]
      ),
      researchAgentRun(
        contextKind: "contact",
        contextID: contact.id,
        title: "Public source plan",
        agentName: "Local planner",
        status: "Planned",
        summary: "",
        proposedAdditions: [],
        trace: [
          ("reasoning", "Decision", "", "The native app does not silently scrape LinkedIn or protected pages. It prepares visible public lookup targets and waits for approval.", "planned"),
          ("tool", "Prepare public query", "Search plan", publicQuery, "planned"),
          ("tool", "Prepare LinkedIn target", "Browser plan", linkedInTarget, "planned"),
          ("reasoning", "Use result", "", "Only paste reviewed facts back into the contact after checking the opened source. Do not mark unsourced facts as researched.", "planned")
        ]
      ),
      researchAgentRun(
        contextKind: "contact",
        contextID: contact.id,
        title: "Contact synthesis",
        agentName: "Local planner",
        status: "Prepared",
        summary: "",
        proposedAdditions: [],
        trace: [
          ("tool", "Read relationship context", "Local state", contactRelationshipTrace(contact), "done"),
          ("reasoning", "Message boundary", "", "Direct-message suggestions may use linked WhatsApp context only for this exact person. Email drafts stay more structured than chat drafts.", "done"),
          ("tool", "Update contact profile", "State write", contact.research.summary, "done"),
          ("reasoning", "Visible output", "", "The directory card should show name, company, role, contact info, and tags only. The opened contact owns the full details.", "done")
        ]
      )
    ]
  }

  private static func companyAgentRuns(company: CompanyProfile, linkedContacts: [ContactRecord]) -> [ResearchAgentRun] {
    [
      researchAgentRun(
        contextKind: "company",
        contextID: company.id,
        title: "Company source scout",
        agentName: "Local planner",
        status: "Planned",
        summary: "",
        proposedAdditions: [],
        trace: [
          ("reasoning", "Objective", "", "Build a source map from saved company fields and visible sources. Do not claim new public facts without a reviewed URL.", "planned"),
          ("tool", "Read source list", "Local state", company.research.sourceURLs.isEmpty ? "No saved sources yet." : company.research.sourceURLs.joined(separator: "\n"), "done"),
          ("tool", "Prepare source query", "Search plan", "\(company.name) official website careers leadership investor news", "planned")
        ]
      ),
      researchAgentRun(
        contextKind: "company",
        contextID: company.id,
        title: "People map",
        agentName: "Local planner",
        status: "Planned",
        summary: "",
        proposedAdditions: [],
        trace: [
          ("reasoning", "Objective", "", "Map linked people before writing outreach or interview prep.", "planned"),
          ("tool", "Read contacts", "Local state", linkedContacts.isEmpty ? "No linked contacts." : linkedContacts.map { "\($0.name): \($0.role)" }.joined(separator: "\n"), "done"),
          ("reasoning", "Boundary", "", "Relationship notes can guide drafts, but outreach stays manual and user-approved.", "planned")
        ]
      ),
      researchAgentRun(
        contextKind: "company",
        contextID: company.id,
        title: "Research synthesis",
        agentName: "Local planner",
        status: "Planned",
        summary: "",
        proposedAdditions: [],
        trace: [
          ("reasoning", "Inputs", "", "Combine saved company summary, public source list, linked contacts, application roles, and user proof.", "planned"),
          ("tool", "Read company", "Local state", "\(company.name): \(company.summary)", "done"),
          ("reasoning", "Output", "", "Separate sourced company facts, user evidence, private notes, and assumptions before writing.", "planned")
        ]
      )
    ]
  }

  private static func contactTraceSnapshot(_ contact: ContactRecord) -> String {
    [
      "Name: \(contact.name)",
      "Role: \(emptyFallback(contact.role, fallback: "None saved"))",
      "Companies: \(emptyFallback(contact.companyLinks.map(\.companyName).joined(separator: ", "), fallback: "None linked"))",
      "LinkedIn: \(emptyFallback(contact.linkedInURL, fallback: "None saved"))",
      "Phone: \(emptyFallback(contact.phone, fallback: "None saved"))",
      "Email: \(emptyFallback(contact.email, fallback: "None saved"))",
      "WhatsApp linked: \(contact.communicationProfile?.whatsApp == nil ? "No" : "Yes")"
    ].joined(separator: "\n")
  }

  private static func contactResearchWriteSummary(_ contact: ContactRecord) -> String {
    [
      "Status: \(emptyFallback(contact.research.status, fallback: "Not prepared"))",
      "Summary: \(emptyFallback(contact.research.summary, fallback: "None"))",
      "Public facts: \(emptyFallback(contact.research.publicFacts.joined(separator: "; "), fallback: "None"))",
      "Saved sources: \(emptyFallback(contact.research.sourceURLs.joined(separator: ", "), fallback: "None"))",
      "Open questions: \(emptyFallback(contact.research.openQuestions.joined(separator: "; "), fallback: "None"))"
    ].joined(separator: "\n")
  }

  private static func contactRelationshipTrace(_ contact: ContactRecord) -> String {
    [
      "Relationship: \(emptyFallback(contact.relationship, fallback: "None saved"))",
      "How met: \(emptyFallback(contact.howMet, fallback: "None saved"))",
      "Notes: \(emptyFallback(contact.notes, fallback: "None saved"))",
      "Personal context: \(emptyFallback(contact.personalNotes, fallback: "None saved"))"
    ].joined(separator: "\n")
  }

  private static func emptyFallback(_ value: String, fallback: String) -> String {
    let trimmed = value.trimmed
    return trimmed.isEmpty ? fallback : trimmed
  }

  private static func researchAgentRun(
    contextKind: String,
    contextID: String,
    title: String,
    agentName: String,
    status: String,
    summary: String,
    proposedAdditions: [String],
    trace: [(String, String, String, String, String)]
  ) -> ResearchAgentRun {
    ResearchAgentRun(
      id: UUID().uuidString,
      contextKind: contextKind,
      contextID: contextID,
      title: title,
      agentName: agentName,
      modelTier: "Local",
      status: status,
      summary: summary,
      trace: trace.map { item in
        ResearchAgentTraceStep(id: UUID().uuidString, title: item.1, detail: item.3, status: item.4, kind: item.0, toolName: item.2.isEmpty ? nil : item.2)
      },
      proposedAdditions: proposedAdditions
    )
  }

  private static let whatsAppAppWideRules = [
    "WhatsApp/direct messages should mirror the specific thread: short, conversational, and one clear ask.",
    "Email drafts should be more structured than WhatsApp: subject, context, proof, one ask.",
    "Private chat intelligence can be used only for a person after the user links that exact thread."
  ]

  private static func hasAnyEnvironmentValue(_ names: [String]) -> Bool {
    names.contains { hasEnvironmentValue($0) }
  }

  private static func hasEnvironmentValue(_ name: String) -> Bool {
    let key = name.trimmed
    guard !key.isEmpty else { return false }
    return !(ProcessInfo.processInfo.environment[key] ?? "").trimmed.isEmpty
  }

  private static func isOpenCodeProviderConnected(_ providerID: String, environmentKeys: [String]) -> Bool {
    if hasAnyEnvironmentValue(environmentKeys) {
      return true
    }
    let authURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/share/opencode/auth.json")
    guard let data = try? Data(contentsOf: authURL),
          let auth = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return false
    }
    return auth[providerID] != nil
  }

  private static func isGrokAuthenticated(keyReference: String = "") -> Bool {
    if hasEnvironmentValue("XAI_API_KEY") {
      return true
    }
    if !keyReference.trimmed.isEmpty, hasEnvironmentValue(keyReference) {
      return true
    }
    if hasHermesXAIAuth() {
      return true
    }
    return hasGrokBuildAuth()
  }

  /// Hermes stores xAI API or SuperGrok OAuth under `~/.hermes/auth.json`.
  private static func hasHermesXAIAuth() -> Bool {
    let path = "\(NSHomeDirectory())/.hermes/auth.json"
    guard let root = readJSONObject(atPath: path) else { return false }
    if let providers = root["providers"] as? [String: Any],
       providers.keys.contains(where: isXAIAuthProviderKey) {
      return true
    }
    if let pool = root["credential_pool"] as? [String: Any],
       pool.keys.contains(where: isXAIAuthProviderKey) {
      return true
    }
    if let pool = root["credential_pool"] as? [[String: Any]] {
      return pool.contains { entry in
        let provider = (entry["provider"] as? String)
          ?? (entry["id"] as? String)
          ?? (entry["name"] as? String)
          ?? ""
        return isXAIAuthProviderKey(provider)
      }
    }
    return false
  }

  /// Grok Build stores browser/OAuth session tokens under `~/.grok/auth.json`.
  private static func hasGrokBuildAuth() -> Bool {
    let path = "\(NSHomeDirectory())/.grok/auth.json"
    guard let root = readJSONObject(atPath: path), !root.isEmpty else { return false }
    for (_, value) in root {
      guard let entry = value as? [String: Any] else { continue }
      let token = ((entry["key"] as? String)
        ?? (entry["access_token"] as? String)
        ?? (entry["token"] as? String)
        ?? "").trimmed
      if !token.isEmpty {
        return true
      }
      let refresh = ((entry["refresh_token"] as? String) ?? "").trimmed
      if !refresh.isEmpty {
        return true
      }
    }
    return false
  }

  private static func isXAIAuthProviderKey(_ key: String) -> Bool {
    let normalized = key.trimmed.lowercased()
    return normalized == "xai"
      || normalized == "xai-oauth"
      || normalized == "x-ai"
      || normalized == "x-ai-oauth"
      || normalized == "grok"
      || normalized == "grok-oauth"
      || normalized == "xai-grok-oauth"
  }

  private static func readJSONObject(atPath path: String) -> [String: Any]? {
    guard FileManager.default.fileExists(atPath: path),
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return object
  }

  private static func detectConnectionIncludingProcessProbe(for connector: IntegrationConnector) async -> Bool {
    guard connector.isEnabled else { return false }
    guard connector.id == "cursor" else { return detectConnection(for: connector) }
    return await isCursorAgentAuthenticated()
  }

  private static func isCursorAgentAuthenticated() async -> Bool {
    if !(ProcessInfo.processInfo.environment["CURSOR_API_KEY"] ?? "").trimmed.isEmpty {
      return true
    }
    let helperPath = NSHomeDirectory() + "/.local/bin/cursor-agent"
    if FileManager.default.isExecutableFile(atPath: helperPath) {
      let result = await LocalScriptRunner.runAsync(
        executable: helperPath,
        arguments: ["models"],
        timeout: 8
      )
      return result.exitCode == 0 && !result.didTimeOut && cursorModelListIsUsable(result.output)
    }
    let appCLI = "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    if FileManager.default.isExecutableFile(atPath: appCLI) {
      let result = await LocalScriptRunner.runAsync(
        executable: appCLI,
        arguments: ["agent", "models"],
        timeout: 8
      )
      return result.exitCode == 0 && !result.didTimeOut && cursorModelListIsUsable(result.output)
    }
    return false
  }

  private static func cursorModelListIsUsable(_ output: String) -> Bool {
    let normalized = output.trimmed.lowercased()
    guard !normalized.isEmpty else { return false }
    if normalized.contains("not logged in") || normalized.contains("no models available") {
      return false
    }
    return true
  }

  private func upsertCompanyFromJob(_ job: JobRecord) {
    var profiles = companyProfiles
    let result = Self.companyBySyncing(job: job, into: profiles)
    profiles = result.profiles
    state.companyProfiles = profiles
    selectedCompanyID = Self.companyID(for: job.company)
  }

  private func syncCompanyApplication(job: JobRecord) {
    var profiles = companyProfiles
    let result = Self.companyBySyncing(job: job, into: profiles)
    profiles = result.profiles
    state.companyProfiles = profiles
  }

  private func addCompanySubmission(job: JobRecord, materialType: String, title: String, summary: String, sourceURL: String, status: String) {
    var profiles = companyProfiles
    let syncResult = Self.companyBySyncing(job: job, into: profiles)
    profiles = syncResult.profiles
    let companyID = Self.companyID(for: job.company)
    guard let index = profiles.firstIndex(where: { $0.id == companyID }) else { return }
    let submissionID = "\(companyID)-\(job.id)-\(materialType.lowercased().replacingOccurrences(of: " ", with: "-"))"
    let submission = CompanySubmission(
      id: submissionID,
      jobID: job.id,
      materialType: materialType,
      title: title,
      summary: summary,
      sourceURL: sourceURL.trimmed,
      status: status
    )
    if let existingIndex = profiles[index].submittedMaterials.firstIndex(where: { $0.id == submissionID }) {
      profiles[index].submittedMaterials[existingIndex] = submission
    } else {
      profiles[index].submittedMaterials.insert(submission, at: 0)
    }
    state.companyProfiles = profiles
  }

  private func pageTitle(for url: String, companyName: String) -> String {
    let lower = url.lowercased()
    if lower.contains("linkedin.com") {
      return "\(companyName) LinkedIn"
    }
    if lower.contains("jobs") || lower.contains("careers") {
      return "\(companyName) careers"
    }
    return "\(companyName) source"
  }

  private static func loadState(from overrideURL: URL?) -> StoreLoadResult {
    do {
      let url = try overrideURL ?? stateURL()
      guard FileManager.default.fileExists(atPath: url.path) else {
        return StoreLoadResult(state: defaultState, alert: nil, shouldPersistMigrations: false)
      }
      let data = try Data(contentsOf: url)
      do {
        return StoreLoadResult(
          state: try JSONDecoder().decode(JobmaxxingState.self, from: data),
          alert: nil,
          shouldPersistMigrations: true
        )
      } catch {
        return recoveredDefaultState(from: url, data: data, error: error)
      }
    } catch {
      return StoreLoadResult(
        state: defaultState,
        alert: JobmaxxingStorageAlert(
          title: "Could not load Jobmaxxing state",
          message: "Jobmaxxing opened with a temporary default state because the saved state file could not be read. No replacement file was written. Error: \(error.localizedDescription)"
        ),
        shouldPersistMigrations: false
      )
    }
  }

  private static func recoveredDefaultState(from url: URL, data: Data, error: Error) -> StoreLoadResult {
    do {
      let backupURL = try backupCorruptState(at: url, data: data)
      return StoreLoadResult(
        state: defaultState,
        alert: JobmaxxingStorageAlert(
          title: "Recovered from corrupt Jobmaxxing state",
          message: "The saved state file could not be decoded, so Jobmaxxing opened a temporary default state and copied the unreadable file to \(backupURL.path). Review the backup before saving over the original. Error: \(error.localizedDescription)"
        ),
        shouldPersistMigrations: false
      )
    } catch {
      return StoreLoadResult(
        state: defaultState,
        alert: JobmaxxingStorageAlert(
          title: "Could not back up corrupt Jobmaxxing state",
          message: "The saved state file could not be decoded, and the backup failed. Jobmaxxing opened a temporary default state and did not replace the original file at \(url.path). Error: \(error.localizedDescription)"
        ),
        shouldPersistMigrations: false
      )
    }
  }

  private static func backupCorruptState(at url: URL, data: Data) throws -> URL {
    let backupURL = url
      .deletingLastPathComponent()
      .appendingPathComponent("\(url.lastPathComponent).corrupt-\(UUID().uuidString).backup")
    try data.write(to: backupURL, options: [.atomic])
    return backupURL
  }

  private func save() throws {
    let url = try resolvedStateURL()
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder.encode(state)
    try data.write(to: url, options: [.atomic])
  }

  private func resolvedStateURL() throws -> URL {
    try stateFileURL ?? Self.stateURL()
  }

  private func score(role: String, description: String) -> Int {
    let haystack = "\(role) \(description)".lowercased()
    var score = 48
    for evidence in state.profile.evidence {
      if Self.evidenceRelevanceScore(evidence, targetText: haystack) >= Self.minEvidenceRelevance {
        score += 7
      }
    }
    if haystack.contains("agent") || haystack.contains("automation") { score += 12 }
    if haystack.contains("browser") || haystack.contains("workflow") { score += 8 }
    if haystack.contains("finance") || haystack.contains("research") { score += 6 }
    return min(98, score)
  }

  private func extractKeywords(from text: String) -> [String] {
    let candidates = ["agent", "automation", "browser", "workflow", "ai", "product", "finance", "research", "typescript", "swift", "backend", "frontend", "data", "review", "approval"]
    let lower = text.lowercased()
    let found = candidates.filter { lower.contains($0) }
    return found.isEmpty ? ["proof", "ownership", "execution"] : found
  }

  private func rankedEvidence(for job: JobRecord) -> [EvidenceItem] {
    let haystack = "\(job.role) \(job.description)"
    return state.profile.evidence
      .map { item in (item, Self.evidenceRelevanceScore(item, targetText: haystack)) }
      .filter { _, relevance in relevance >= Self.minEvidenceRelevance }
      .sorted { left, right in
        let leftScore = left.1 * 10 + left.0.strength
        let rightScore = right.1 * 10 + right.0.strength
        return leftScore == rightScore ? left.0.title < right.0.title : leftScore > rightScore
      }
      .map(\.0)
  }

  private func missingEvidence(for job: JobRecord, evidence: [EvidenceItem]) -> [String] {
    if evidence.isEmpty {
      return [
        "No saved evidence meets the relevance threshold for \(job.role) at \(job.company).",
        "Add proof for one of these role themes: \(job.keywords.prefix(6).joined(separator: ", "))."
      ]
    }
    let coveredTags = Set(evidence.flatMap { $0.tags.map { $0.lowercased() } })
    let uncovered = job.keywords.filter { !coveredTags.contains($0.lowercased()) }.prefix(4)
    return uncovered.isEmpty ? [] : ["No saved evidence directly covers these role themes yet: \(uncovered.joined(separator: ", "))."]
  }

  private static func claimTrace(item: EvidenceItem, claim: String, location: String) -> ApplicationClaimTrace {
    ApplicationClaimTrace(
      id: UUID().uuidString,
      claim: claim,
      evidenceID: item.id,
      evidenceLabel: item.title,
      location: location
    )
  }

  private static func evidenceRelevanceScore(_ evidence: EvidenceItem, targetText: String) -> Int {
    let target = Set(normalizedTokens(targetText))
    let exactTarget = targetText.lowercased()
    var score = 0
    for tag in evidence.tags {
      let tagText = tag.lowercased()
      let tagTokens = normalizedTokens(tag)
      if !tagText.isEmpty && exactTarget.contains(tagText) {
        score += 3
      } else if tagTokens.contains(where: { target.contains($0) }) {
        score += 2
      }
    }
    let factMatches = normalizedTokens("\(evidence.title) \(evidence.proof)").filter { target.contains($0) }.count
    score += min(3, factMatches)
    return score
  }

  private static func normalizedTokens(_ text: String) -> [String] {
    let lower = text.lowercased()
    let regex = try? NSRegularExpression(pattern: "[a-z][a-z0-9+-]{2,}")
    let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
    return (regex?.matches(in: lower, range: range) ?? [])
      .compactMap { match in
        guard let tokenRange = Range(match.range, in: lower) else { return nil }
        var token = String(lower[tokenRange])
        if token.hasSuffix("s") {
          token.removeLast()
        }
        return token
      }
      .filter { !stopWords.contains($0) }
  }

  private static func sentences(in text: String) -> [String] {
    text
      .split(whereSeparator: { ".!?".contains($0) })
      .map { String($0).trimmed }
      .filter { !$0.isEmpty }
  }

  private static func evidenceReferences(in text: String, evidence: [EvidenceItem]) -> [String] {
    let lower = text.lowercased()
    let textTokens = Set(normalizedTokens(text))
    return evidence.compactMap { item in
      let tagHit = item.tags.contains { tag in
        normalizedTokens(tag).contains { textTokens.contains($0) }
      }
      let proofHit = normalizedTokens(item.proof).filter { textTokens.contains($0) }.count >= 2
      let sourceHit = !item.sourceURL.isEmpty && lower.contains(item.sourceURL.lowercased())
      return lower.contains(item.title.lowercased()) || tagHit || proofHit || sourceHit ? item.title : nil
    }
  }

  private static func unsupportedClaims(in sentences: [String], evidence: [EvidenceItem]) -> [String] {
    let claimStarts = [
      "i built",
      "i designed",
      "i shipped",
      "i led",
      "i owned",
      "i created",
      "i configured",
      "i delivered",
      "i automated",
      "i improved",
      "i reduced",
      "i increased",
      "i launched",
      "i managed",
      "i implemented",
      "i worked",
      "i have",
      "i can",
      "i bring",
      "my background",
      "my experience"
    ]
    return sentences.filter { sentence in
      let lower = sentence.lowercased()
      if isAssumptionOrGap(sentence) || hasGroundedEvidenceReference(in: sentence, evidence: evidence) {
        return false
      }
      return claimStarts.contains(where: { lower.contains($0) })
        || unsupportedClaimPhrases.contains(where: { lower.contains($0) })
    }
  }

  private static func hasGroundedEvidenceReference(in sentence: String, evidence: [EvidenceItem]) -> Bool {
    let lower = sentence.lowercased()
    let textTokens = Set(normalizedTokens(sentence))
    return evidence.contains { item in
      let tagMatches = item.tags.filter { tag in
        normalizedTokens(tag).contains { textTokens.contains($0) }
      }.count
      let proofMatches = normalizedTokens(item.proof).filter { textTokens.contains($0) }.count
      return lower.contains(item.title.lowercased()) || tagMatches >= 2 || proofMatches >= 2
    }
  }

  private static func isAssumptionOrGap(_ sentence: String) -> Bool {
    let lower = sentence.lowercased()
    return ["assumption", "assume", "appears", "seems", "likely", "not confirmed", "needs more evidence", "need more evidence", "before claiming", "should not claim", "do not claim", "missing evidence"].contains { lower.contains($0) }
  }

  private static func containsWord(_ word: String, in lower: String) -> Bool {
    lower
      .split { !$0.isLetter && !$0.isNumber }
      .contains { $0 == word }
  }

  private static func appSupportURL() throws -> URL {
    try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ).appendingPathComponent("Jobmaxxing", isDirectory: true)
  }

  private static func stateURL() throws -> URL {
    try appSupportURL().appendingPathComponent("state.json")
  }

  private static func documentsURL() throws -> URL {
    try appSupportURL().appendingPathComponent("Documents", isDirectory: true)
  }
}

private struct TelegramUpdatesResponse: Decodable {
  let ok: Bool
  let result: [TelegramUpdate]
}

private struct TelegramUpdate: Decodable {
  let updateID: Int
  let message: TelegramMessage?

  enum CodingKeys: String, CodingKey {
    case updateID = "update_id"
    case message
  }
}

private struct TelegramMessage: Decodable {
  let text: String?
  let chat: TelegramChat
}

private struct TelegramChat: Decodable {
  let id: Int64
}

extension JobmaxxingStore {
  static let defaultHermesSettings = HermesSettings(
    installPath: "\(NSHomeDirectory())/.hermes/hermes-agent",
    layerPath: "\(NSHomeDirectory())/.jobmaxxing/hermes-layer",
    defaultModelRouteID: "final-review",
    updateCommand: "scripts/hermes_update.sh",
    isLayerInstalled: FileManager.default.fileExists(
      atPath: "\(NSHomeDirectory())/.jobmaxxing/hermes-layer/jobmaxxing.hermes.json"
    )
  )

  static let defaultHermesChatState = HermesChatState(
    settings: HermesChatSettings(
      telegramBotTokenReference: "",
      telegramChatID: "",
      webhookURL: "",
      traceVerbosity: "high",
      enabledCommandIDs: [
        "dashboard",
        "chat",
        "application",
        "applications",
        "company",
        "companies",
        "contact",
        "contacts",
        "document",
        "writing",
        "interview",
        "interviews",
        "browser",
        "goal",
        "gmail",
        "drive",
        "github",
        "telegram",
        "whatsapp",
        "outlook",
        "plugins",
        "connections",
        "why",
        "update",
        "yolo",
        "status",
        "help",
        "tools",
        "memory",
        "google-docs",
        "google-calendar",
        "google-sheets",
        "google-slides",
        "microsoft-365",
        "onedrive",
        "word",
        "figma",
        "railway",
        "hugging-face",
        "linear",
        "notion",
        "apple-mail",
        "local-documents",
        "openai",
        "opencode",
        "cursor"
      ],
      telegramLastUpdateID: nil
    ),
    threads: [
      HermesChatThread(
        id: defaultHermesThreadID,
        title: "Chat",
        summary: "Ready",
        status: "ready",
        sequence: 1,
        messages: [
          HermesChatMessage(
            id: "agent-home-message",
            role: "assistant",
            text: "Send a message or attach a file.",
            status: "complete",
            commandID: nil,
            traces: [
              HermesTraceStep(
                id: "agent-home-trace",
                label: "Prepare reply",
                status: "complete",
                toolName: "jobmaxxing_hermes_status",
                detail: "Checked saved job-search context before answering."
              )
            ],
            attachments: []
          )
        ]
      )
    ],
    selectedThreadID: defaultHermesThreadID
  )

  static func connectorField(
    _ id: String,
    _ label: String,
    placeholder: String = "",
    value: String = "",
    isSecret: Bool = false
  ) -> ConnectorConfigField {
    ConnectorConfigField(id: id, label: label, value: value, placeholder: placeholder, isSecret: isSecret)
  }

  static let defaultIntegrationConnectors = [
    IntegrationConnector(
      id: "openai",
      label: "OpenAI",
      provider: "OpenAI",
      purpose: "Medium and High model routes.",
      isEnabled: true,
      isConnected: JobmaxxingStore.hasEnvironmentValue("OPENAI_API_KEY"),
      category: "Models",
      capabilities: ["Medium", "High", "review"],
      configFields: [
        connectorField("api-key-ref", "API key variable", placeholder: "OPENAI_API_KEY", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "xai",
      label: "Grok",
      provider: "xAI",
      purpose: "Grok model routes via XAI_API_KEY, Hermes xAI OAuth, or Grok Build login.",
      isEnabled: true,
      isConnected: JobmaxxingStore.isGrokAuthenticated(),
      category: "Models",
      capabilities: ["Medium", "High", "review", "Grok"],
      configFields: [
        connectorField("api-key-ref", "API key variable", placeholder: "XAI_API_KEY", isSecret: true),
        connectorField("auth-source", "Auth source", placeholder: "auto | hermes | grok-build | api-key", value: "auto")
      ]
    ),
    IntegrationConnector(
      id: "opencode-go",
      label: "OpenCode Go",
      provider: "OpenCode Go",
      purpose: "OpenCode Go subscription models.",
      isEnabled: true,
      isConnected: JobmaxxingStore.isOpenCodeProviderConnected("opencode-go", environmentKeys: ["OPENCODE_GO_API_KEY", "OPENCODE_API_KEY"]),
      category: "Models",
      capabilities: ["subscription", "coding models"],
      configFields: [
        connectorField("api-key-ref", "API key variable", placeholder: "OPENCODE_GO_API_KEY", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "opencode-zen",
      label: "OpenCode Zen",
      provider: "OpenCode Zen",
      purpose: "OpenCode Zen API models.",
      isEnabled: true,
      isConnected: JobmaxxingStore.isOpenCodeProviderConnected("opencode", environmentKeys: ["OPENCODE_ZEN_API_KEY", "OPENCODE_API_KEY"]),
      category: "Models",
      capabilities: ["API", "coding models"],
      configFields: [
        connectorField("api-key-ref", "API key variable", placeholder: "OPENCODE_ZEN_API_KEY", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "cursor",
      label: "Cursor",
      provider: "Cursor",
      purpose: "Programmatic editor agent route.",
      isEnabled: true,
      isConnected: JobmaxxingStore.hasEnvironmentValue("CURSOR_API_KEY"),
      category: "Models",
      capabilities: ["agent", "code", "local"],
      configFields: [
        connectorField("api-key-ref", "Key ref", placeholder: "CURSOR_API_KEY or Cursor login", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "hermes",
      label: "Agent",
      provider: "Agent",
      purpose: "Local orchestration and slash commands.",
      isEnabled: true,
      isConnected: FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.local/bin/hermes"),
      category: "Agent tools",
      capabilities: ["chat", "traces", "commands"],
      configFields: [
        connectorField("install-path", "Path", value: "\(NSHomeDirectory())/.hermes/hermes-agent")
      ]
    ),
    IntegrationConnector(
      id: "telegram",
      label: "Telegram",
      provider: "Telegram",
      purpose: "Manual chat sync only. Background polling stays off unless the user explicitly enables it.",
      isEnabled: false,
      isConnected: false,
      category: "Agent tools",
      capabilities: ["chat", "alerts", "commands"],
      configFields: [
        connectorField("bot-token-ref", "Bot token ref", placeholder: "TELEGRAM_BOT_TOKEN", isSecret: true),
        connectorField("chat-id", "Chat ID", placeholder: "Your Telegram chat ID"),
        connectorField("webhook-url", "Webhook", placeholder: "Optional webhook URL"),
        connectorField("polling", "Polling", placeholder: "off", value: "off")
      ]
    ),
    IntegrationConnector(
      id: "whatsapp",
      label: "WhatsApp",
      provider: "WhatsApp",
      purpose: "Local thread intelligence for linked people.",
      isEnabled: true,
      isConnected: WhatsAppLocalStore.isReadableDatabase(at: WhatsAppLocalStore.defaultDatabasePath),
      category: "Agent tools",
      capabilities: ["messages", "style", "drafts"],
      configFields: [
        connectorField("database-path", "Database", value: WhatsAppLocalStore.defaultDatabasePath)
      ]
    ),
    IntegrationConnector(
      id: "google-drive",
      label: "Google Drive",
      provider: "Google",
      purpose: "Documents and proof files.",
      isEnabled: true,
      isConnected: false,
      category: "Google",
      capabilities: ["files", "proof", "import"],
      configFields: [
        connectorField("profile", "Profile", placeholder: "Codex Google Drive connector"),
        connectorField("root-folder", "Folder", placeholder: "Optional Drive folder")
      ]
    ),
    IntegrationConnector(
      id: "google-docs",
      label: "Google Docs",
      provider: "Google",
      purpose: "CVs, letters, and notes.",
      isEnabled: true,
      isConnected: false,
      category: "Google",
      capabilities: ["edit", "draft", "export"],
      configFields: [
        connectorField("profile", "Profile", placeholder: "Codex Google Docs connector")
      ]
    ),
    IntegrationConnector(
      id: "gmail",
      label: "Gmail",
      provider: "Google",
      purpose: "Recruiting email drafts.",
      isEnabled: true,
      isConnected: false,
      category: "Google",
      capabilities: ["search", "draft", "threads"],
      configFields: [
        connectorField("profile", "Profile", placeholder: "Codex Gmail connector")
      ]
    ),
    IntegrationConnector(
      id: "google-calendar",
      label: "Google Calendar",
      provider: "Google",
      purpose: "Interview scheduling.",
      isEnabled: true,
      isConnected: false,
      category: "Google",
      capabilities: ["availability", "events", "follow-up"],
      configFields: [
        connectorField("calendar-id", "Calendar", placeholder: "primary")
      ]
    ),
    IntegrationConnector(
      id: "google-sheets",
      label: "Google Sheets",
      provider: "Google",
      purpose: "Application trackers.",
      isEnabled: true,
      isConnected: false,
      category: "Google",
      capabilities: ["tables", "tracking", "analysis"],
      configFields: [
        connectorField("sheet-id", "Sheet", placeholder: "Optional tracker sheet")
      ]
    ),
    IntegrationConnector(
      id: "google-slides",
      label: "Google Slides",
      provider: "Google",
      purpose: "Portfolio and interview decks.",
      isEnabled: true,
      isConnected: false,
      category: "Google",
      capabilities: ["decks", "portfolio", "prep"],
      configFields: [
        connectorField("profile", "Profile", placeholder: "Codex Google Slides connector")
      ]
    ),
    IntegrationConnector(
      id: "microsoft-365",
      label: "Microsoft 365",
      provider: "Microsoft",
      purpose: "Office account route.",
      isEnabled: false,
      isConnected: false,
      category: "Microsoft",
      capabilities: ["Office", "Graph", "files"],
      configFields: [
        connectorField("tenant", "Tenant", placeholder: "Tenant or account"),
        connectorField("client-id", "Client ID", placeholder: "Optional Graph client")
      ]
    ),
    IntegrationConnector(
      id: "outlook",
      label: "Outlook",
      provider: "Microsoft",
      purpose: "Recruiting email drafts.",
      isEnabled: false,
      isConnected: false,
      category: "Microsoft",
      capabilities: ["mail", "draft", "threads"],
      configFields: [
        connectorField("mailbox", "Mailbox", placeholder: "Primary mailbox")
      ]
    ),
    IntegrationConnector(
      id: "onedrive",
      label: "OneDrive",
      provider: "Microsoft",
      purpose: "Resume and proof storage.",
      isEnabled: false,
      isConnected: false,
      category: "Microsoft",
      capabilities: ["files", "proof", "export"],
      configFields: [
        connectorField("folder", "Folder", placeholder: "Optional OneDrive folder")
      ]
    ),
    IntegrationConnector(
      id: "word",
      label: "Word",
      provider: "Microsoft",
      purpose: "DOCX CV and letter edits.",
      isEnabled: false,
      isConnected: false,
      category: "Microsoft",
      capabilities: ["edit", "docx", "export"],
      configFields: [
        connectorField("profile", "Profile", placeholder: "Microsoft 365 profile")
      ]
    ),
    IntegrationConnector(
      id: "github",
      label: "GitHub",
      provider: "GitHub",
      purpose: "Proof repositories.",
      isEnabled: true,
      isConnected: JobmaxxingStore.hasAnyEnvironmentValue(["GITHUB_TOKEN", "GH_TOKEN"])
        || FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.config/gh/hosts.yml"),
      category: "Proof",
      capabilities: ["repos", "PRs", "evidence"],
      configFields: [
        connectorField("token-ref", "Token ref", placeholder: "GITHUB_TOKEN or gh auth", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "figma",
      label: "Figma",
      provider: "Figma",
      purpose: "Design proof and portfolios.",
      isEnabled: false,
      isConnected: JobmaxxingStore.hasAnyEnvironmentValue(["FIGMA_TOKEN"]),
      category: "Proof",
      capabilities: ["files", "design", "portfolio"],
      configFields: [
        connectorField("token-ref", "Token ref", placeholder: "FIGMA_TOKEN", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "railway",
      label: "Railway",
      provider: "Railway",
      purpose: "Deployment proof.",
      isEnabled: false,
      isConnected: JobmaxxingStore.hasAnyEnvironmentValue(["RAILWAY_TOKEN"])
        || FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.railway"),
      category: "Proof",
      capabilities: ["deployments", "logs", "URLs"],
      configFields: [
        connectorField("token-ref", "Token ref", placeholder: "RAILWAY_TOKEN", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "hugging-face",
      label: "Hugging Face",
      provider: "Hugging Face",
      purpose: "Models, Spaces, and datasets.",
      isEnabled: false,
      isConnected: JobmaxxingStore.hasAnyEnvironmentValue(["HF_TOKEN", "HUGGINGFACE_TOKEN"])
        || FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/.cache/huggingface/token"),
      category: "Proof",
      capabilities: ["models", "Spaces", "papers"],
      configFields: [
        connectorField("token-ref", "Token ref", placeholder: "HF_TOKEN", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "linear",
      label: "Linear",
      provider: "Linear",
      purpose: "Job-search task tracking.",
      isEnabled: false,
      isConnected: JobmaxxingStore.hasAnyEnvironmentValue(["LINEAR_API_KEY"]),
      category: "Work",
      capabilities: ["issues", "planning", "status"],
      configFields: [
        connectorField("api-key-ref", "Key ref", placeholder: "LINEAR_API_KEY", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "notion",
      label: "Notion",
      provider: "Notion",
      purpose: "Notes and application CRM.",
      isEnabled: false,
      isConnected: JobmaxxingStore.hasAnyEnvironmentValue(["NOTION_TOKEN"]),
      category: "Work",
      capabilities: ["notes", "tables", "CRM"],
      configFields: [
        connectorField("token-ref", "Token ref", placeholder: "NOTION_TOKEN", isSecret: true)
      ]
    ),
    IntegrationConnector(
      id: "local-documents",
      label: "Local documents",
      provider: "Local files",
      purpose: "CVs, contracts, proof files.",
      isEnabled: true,
      isConnected: true,
      category: "Local",
      capabilities: ["CV", "contracts", "proof"],
      configFields: [
        connectorField("folder", "Folder", value: "Application Support/Jobmaxxing/Documents")
      ]
    ),
    IntegrationConnector(
      id: "apple-mail",
      label: "Apple Mail",
      provider: "Local mail",
      purpose: "Local evidence and writing style.",
      isEnabled: true,
      isConnected: FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Library/Mail"),
      category: "Local",
      capabilities: ["style", "contracts", "history"],
      configFields: [
        connectorField("mail-root", "Mail root", value: "~/Library/Mail")
      ]
    )
  ]

  static let defaultProfileSkills = [
    "Agent workflows",
    "SwiftUI macOS apps",
    "Browser automation handoffs",
    "MCP tooling",
    "Prompt engineering",
    "Finance research systems",
    "Provider routing",
    "Backend services",
    "Frontend product surfaces",
    "Review loops",
    "Telegram integrations",
    "Local-first tools"
  ]

  static let defaultProfileExperience: [ProfileExperience] = [
    ProfileExperience(
      id: "profile-exp-marauder",
      title: "Built Marauder finance workspace",
      organization: "Project",
      location: "Remote",
      period: "Recent work",
      summary: "Built a multi-surface finance research system with desktop terminal, PWA, Smaug control plane, notebook, QuantLab, backend, shared contracts, and provider routing.",
      bullets: [
        "Connected research, notebooks, provider routing, and deployment into one workspace.",
        "Shipped usable surfaces instead of isolated demos.",
        "Kept claims backed by live project links."
      ],
      sourceURL: "https://marauder-main.up.railway.app",
      projects: [
        ProfileExperienceProject(
          id: "profile-exp-marauder-core",
          name: "Finance research workspace",
          summary: "Multi-surface finance research product with provider routing.",
          detail: "Connected research, notebooks, provider routing, and deployment into one workspace so claims stay backed by live surfaces instead of isolated demos.",
          specificSample: "One path runs a research question through provider-routed tools, notebook notes, and a reviewable output surface without losing source context.",
          tools: ["TypeScript", "provider routing", "notebooks"],
          metrics: [],
          tags: ["finance", "research", "product"],
          sourceURL: "https://marauder-main.up.railway.app"
        )
      ]
    ),
    ProfileExperience(
      id: "profile-exp-smaug",
      title: "Built Smaug agent control plane",
      organization: "Project",
      location: "Remote",
      period: "Recent work",
      summary: "Built an assistant and operations control plane with harnesses, memory links, tools, workflow runs, Telegram integration, and runner visibility.",
      bullets: [
        "Designed the control plane around inspectable agent runs.",
        "Linked memory, tools, Telegram intake, and workflow status.",
        "Focused on operational visibility rather than black-box automation."
      ],
      sourceURL: "https://smaug.up.railway.app",
      projects: [
        ProfileExperienceProject(
          id: "profile-exp-smaug-core",
          name: "Agent control plane",
          summary: "Inspectable agent runs with memory, tools, and Telegram intake.",
          detail: "Designed the control plane around inspectable agent runs and linked memory, tools, Telegram intake, and workflow status.",
          specificSample: "A task enters through Telegram or the UI, routes through tools with memory links, and only proceeds after review-visible state is recorded.",
          tools: ["agents", "Telegram", "workflow runner"],
          metrics: [],
          tags: ["agents", "automation", "ops"],
          sourceURL: "https://smaug.up.railway.app"
        )
      ]
    ),
    ProfileExperience(
      id: "profile-exp-jobmaxxing",
      title: "Built Jobmaxxing",
      organization: "Open-source project",
      location: "Local macOS",
      period: "Current work",
      summary: "Built a local-first job-search operating system with MCP tools, browser safety gates, writing memory, and native macOS workspace.",
      bullets: [
        "Created a native workspace for applications, documents, writing, interviews, safe browser planning, and agent routing.",
        "Added proof-linked writing rules to avoid generic AI application text.",
        "Layered Codex and Hermes-style orchestration into a local app workflow."
      ],
      sourceURL: "https://github.com/Balllvin/Jobmaxxing",
      projects: [
        ProfileExperienceProject(
          id: "profile-exp-jobmaxxing-core",
          name: "Evidence-backed hiring workspace",
          summary: "Native job-search workspace with writing audits and browser safety gates.",
          detail: "Built a local-first job-search OS with applications, company research, experience writeups, writing audits, and approval gates before external actions.",
          specificSample: "A draft application pack pulls broad experience themes plus one project sample, then fails audit if claims lack saved proof.",
          tools: ["SwiftUI", "MCP", "Hermes"],
          metrics: [],
          tags: ["macos", "job search", "writing"],
          sourceURL: "https://github.com/Balllvin/Jobmaxxing"
        )
      ]
    )
  ]

  static let defaultProfileProjects: [ProfileProject] = [
    ProfileProject(
      id: "profile-project-marauder",
      name: "Marauder",
      url: "https://marauder-main.up.railway.app",
      summary: "Finance research workspace with multi-surface product architecture and provider routing.",
      tags: ["finance", "research", "product", "agents"]
    ),
    ProfileProject(
      id: "profile-project-quant-lab",
      name: "Quant Lab",
      url: "https://quant-lab-production.up.railway.app",
      summary: "Strategy testing surface with baselines, notes, and proof-first interpretation.",
      tags: ["finance", "data", "testing"]
    ),
    ProfileProject(
      id: "profile-project-smaug",
      name: "Smaug",
      url: "https://smaug.up.railway.app",
      summary: "Agent control plane with workflow visibility, tools, memory links, and Telegram intake.",
      tags: ["agents", "automation", "workflow"]
    ),
    ProfileProject(
      id: "profile-project-jobmaxxing",
      name: "Jobmaxxing",
      url: "https://github.com/Balllvin/Jobmaxxing",
      summary: "Native macOS job-search workspace with Codex/Hermes tooling, evidence memory, and browser safety gates.",
      tags: ["macos", "swift", "job search", "mcp"]
    )
  ]

  static let defaultProfileMemory: [ProfileMemory] = [
    ProfileMemory(
      id: "profile-memory-direct-writing",
      kind: "Writing",
      title: "Direct proof-first writing",
      detail: "Recruiter and application text should name what was built, include one useful link, and avoid hype.",
      source: "User preference",
      strength: 5
    ),
    ProfileMemory(
      id: "profile-memory-anti-slop",
      kind: "Writing",
      title: "No generic excitement language",
      detail: "Avoid phrases like excited, innovative, passionate, dynamic, and cutting-edge unless the sentence also contains concrete evidence.",
      source: "Prompt memory",
      strength: 5
    ),
    ProfileMemory(
      id: "profile-memory-agentic-products",
      kind: "Positioning",
      title: "Strongest positioning",
      detail: "Best-fit roles involve agent platforms, automation, browser workflows, applied AI tools, finance research systems, or founder-style product engineering.",
      source: "Evidence library",
      strength: 4
    )
  ]

  static let defaultCompanyProfiles: [CompanyProfile] = [
    CompanyProfile(
      id: "marauder",
      name: "Marauder",
      website: "https://marauder-main.up.railway.app",
      linkedInURL: "",
      category: "User proof",
      size: "Project",
      headquarters: "Local-first",
      publicStatus: "Private project",
      summary: "Finance research workspace with desktop terminal, PWA, Smaug control plane, notebook, QuantLab, backend, shared contracts, and provider routing.",
      relationship: "Built by user",
      applicationIDs: [],
      experienceIDs: ["profile-exp-marauder"],
      submittedMaterials: [],
      people: [],
      research: companyResearch(
        status: "Known from user evidence",
        confidence: 72,
        website: "https://marauder-main.up.railway.app",
        products: ["Finance research workspace", "Provider-routed research surfaces"],
        businessModel: "User-built proof project, not an employer.",
        hiringSignals: ["finance", "research", "product", "backend", "frontend", "agents"]
      ),
      nextActions: ["Use as proof for finance, agent, research, backend, frontend, and product roles.", "Keep links attached when used in contact messages."],
      notes: ""
    ),
    CompanyProfile(
      id: "smaug",
      name: "Smaug",
      website: "https://smaug.up.railway.app",
      linkedInURL: "",
      category: "User proof",
      size: "Project",
      headquarters: "Local-first",
      publicStatus: "Private project",
      summary: "Assistant and operations control plane with harnesses, memory links, tools, workflow runs, Telegram integration, and runner visibility.",
      relationship: "Built by user",
      applicationIDs: [],
      experienceIDs: ["profile-exp-smaug"],
      submittedMaterials: [],
      people: [],
      research: companyResearch(
        status: "Known from user evidence",
        confidence: 72,
        website: "https://smaug.up.railway.app",
        products: ["Agent control plane", "Workflow runner visibility", "Telegram intent intake"],
        businessModel: "User-built proof project, not an employer.",
        hiringSignals: ["agents", "automation", "workflow", "telegram", "tools"]
      ),
      nextActions: ["Use as proof for agent platform and operations automation roles.", "Attach the link when writing about workflow visibility."],
      notes: ""
    ),
    CompanyProfile(
      id: "quant-lab",
      name: "Quant Lab",
      website: "https://quant-lab-production.up.railway.app",
      linkedInURL: "",
      category: "User proof",
      size: "Project",
      headquarters: "Local-first",
      publicStatus: "Private project",
      summary: "Strategy testing surface that turns a rule into a backend-backed result with baselines, notes, and proof-first interpretation.",
      relationship: "Built by user",
      applicationIDs: [],
      experienceIDs: [],
      submittedMaterials: [],
      people: [],
      research: companyResearch(
        status: "Known from user evidence",
        confidence: 68,
        website: "https://quant-lab-production.up.railway.app",
        products: ["Strategy testing", "Baseline comparison", "Proof-first interpretation"],
        businessModel: "User-built proof project, not an employer.",
        hiringSignals: ["finance", "data", "research", "testing"]
      ),
      nextActions: ["Use as proof for finance, data, and research tooling roles.", "Attach only when the target role values testable systems."],
      notes: ""
    ),
    CompanyProfile(
      id: "jobmaxxing",
      name: "Jobmaxxing",
      website: "https://github.com/Balllvin/Jobmaxxing",
      linkedInURL: "",
      category: "User proof",
      size: "Open-source project",
      headquarters: "Local macOS",
      publicStatus: "Open-source",
      summary: "Native macOS job-search workspace with Codex/Hermes tooling, evidence memory, company profiles, browser safety gates, and local state.",
      relationship: "Built by user",
      applicationIDs: [],
      experienceIDs: ["profile-exp-jobmaxxing"],
      submittedMaterials: [],
      people: [],
      research: companyResearch(
        status: "Known from repository",
        confidence: 70,
        website: "https://github.com/Balllvin/Jobmaxxing",
        products: ["Native job-search workspace", "Company profiles", "MCP tools", "Browser safety plans"],
        businessModel: "Open-source local-first tool.",
        hiringSignals: ["agents", "macos", "swift", "mcp", "job search"]
      ),
      nextActions: ["Use as proof for native macOS, local-first agents, and hiring workflow roles.", "Link to the repository when the role values inspectable code."],
      notes: ""
    )
  ]

  static func companyID(for name: String) -> String {
    let scalars = name.lowercased().unicodeScalars.map { scalar -> Character in
      CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
    }
    let collapsed = String(scalars)
      .split(separator: "-")
      .joined(separator: "-")
    return collapsed.isEmpty ? UUID().uuidString : collapsed
  }

  static func emptyCompanyResearch(companyName: String, website: String, linkedInURL: String) -> CompanyResearch {
    let sourceURLs = [website, linkedInURL].map(\.trimmed).filter { !$0.isEmpty }
    return CompanyResearch(
      status: "Not researched",
      confidence: 0,
      websitePages: sourceURLs.enumerated().map { index, url in
        CompanyResearchPage(
          id: "company-page-\(companyID(for: companyName))-\(index)",
          title: url.lowercased().contains("linkedin.com") ? "\(companyName) LinkedIn" : "\(companyName) source",
          url: url,
          summary: "Not read yet."
        )
      },
      products: [],
      businessModel: "",
      leadership: [],
      hiringSignals: [],
      risks: [],
      openQuestions: ["What does this company do?", "Who should the user talk to?", "Which proof best maps to their work?"],
      sourceURLs: sourceURLs,
      agentPlan: companyAgentPlan(name: companyName, website: website, linkedInURL: linkedInURL)
    )
  }

  static func companyResearch(status: String, confidence: Int, website: String, products: [String], businessModel: String, hiringSignals: [String]) -> CompanyResearch {
    CompanyResearch(
      status: status,
      confidence: confidence,
      websitePages: [
        CompanyResearchPage(
          id: "company-page-\(companyID(for: website))-known",
          title: "Primary source",
          url: website,
          summary: "Seeded from existing user evidence."
        )
      ],
      products: products,
      businessModel: businessModel,
      leadership: [],
      hiringSignals: hiringSignals,
      risks: ["Do not present user-built proof projects as prior employers."],
      openQuestions: ["Which target companies value this proof most?"],
      sourceURLs: [website],
      agentPlan: companyAgentPlan(name: website, website: website, linkedInURL: "")
    )
  }

  static func companyNextActions(name: String) -> [String] {
    [
      "Build source map for \(name).",
      "Find likely hiring people and save public profile links.",
      "Map saved roles to user evidence.",
      "Prepare company-specific outreach and interview questions."
    ]
  }

  static func companyAgentPlan(name: String, website: String, linkedInURL: String) -> [String] {
    let sources = [website, linkedInURL].filter { !$0.trimmed.isEmpty }
    let sourceStep = sources.isEmpty
      ? "Find the company homepage, careers page, LinkedIn company page, and reliable public sources."
      : "Read saved sources first: \(sources.joined(separator: ", "))."
    return [
      sourceStep,
      "Summarize products, customers, business model, company stage, leadership, and current hiring signals.",
      "For public companies, collect investor relations, filings, earnings, leadership, products, and risk notes. For private companies, use website, jobs, blogs, press, funding pages, and public people profiles.",
      "On LinkedIn, only inspect visible public/profile pages with user approval. Save names, roles, links, and why they matter; do not message or connect.",
      "Read the entire reachable company site map that is relevant to hiring: homepage, product, pricing, customers, docs, blog, about, careers, and job pages.",
      "Separate facts from assumptions. Every material application claim must trace to user evidence or company source.",
      "Produce: company brief, people map, role-fit memo, application claim map, outreach draft, interview question bank, and open research gaps."
    ]
  }

  static func companyBySyncing(job: JobRecord, into profiles: [CompanyProfile]) -> (profiles: [CompanyProfile], changed: Bool) {
    var profiles = profiles
    let id = companyID(for: job.company)
    if let index = profiles.firstIndex(where: { $0.id == id }) {
      var company = profiles[index]
      if !company.applicationIDs.contains(job.id) {
        company.applicationIDs.append(job.id)
      }
      if company.website.trimmed.isEmpty {
        company.website = job.sourceURL
      }
      if !job.sourceURL.trimmed.isEmpty, !company.research.sourceURLs.contains(job.sourceURL) {
        company.research.sourceURLs.append(job.sourceURL)
      }
      company.research.hiringSignals = (company.research.hiringSignals + job.keywords).uniqued
      company.nextActions = (company.nextActions + job.nextActions).uniqued
      profiles[index] = company
      return (profiles, true)
    }

    profiles.insert(
      CompanyProfile(
        id: id,
        name: job.company,
        website: job.sourceURL,
        linkedInURL: "",
        category: "Target company",
        size: "Unknown",
        headquarters: "Unknown",
        publicStatus: "Unknown",
        summary: "Company profile created from saved role: \(job.role).",
        relationship: "Application target",
        applicationIDs: [job.id],
        experienceIDs: [],
        submittedMaterials: [],
        people: [],
        research: emptyCompanyResearch(companyName: job.company, website: job.sourceURL, linkedInURL: ""),
        nextActions: (companyNextActions(name: job.company) + job.nextActions).uniqued,
        notes: job.notes
      ),
      at: 0
    )
    return (profiles, true)
  }

  static let defaultCompetitorApps: [CompetitorApp] = [
    CompetitorApp(
      id: "teal",
      name: "Teal",
      category: "Tracker and resume workspace",
      url: "https://www.tealhq.com/tools/job-tracker",
      summary: "Tracks jobs, saves roles from job boards, reviews keywords, manages statuses, notes, resumes, contacts, and companies.",
      usefulPatterns: ["Save from many boards", "Keyword review", "Pipeline stages", "Weekly goals"],
      gaps: ["Writing can still become generic", "Not agent-native", "Browser work sits outside the command loop"],
      jobmaxxingResponse: ["Evidence-first tracker", "Agent command routing", "Local documents and claim trace"]
    ),
    CompetitorApp(
      id: "simplify",
      name: "Simplify",
      category: "Autofill and copilot extension",
      url: "https://simplify.jobs/copilot",
      summary: "Autofills repetitive fields, drafts tailored answers, and tracks submitted applications from the browser.",
      usefulPatterns: ["Application autofill", "Question answer drafting", "Automatic tracking", "Browser reach"],
      gaps: ["Autofill does not prove claims", "Fit judgment still belongs to the user", "Trust depends on browser context"],
      jobmaxxingResponse: ["Manual-submit policy", "Claim-backed answers", "Deterministic form data preparation"]
    ),
    CompetitorApp(
      id: "huntr",
      name: "Huntr",
      category: "Job CRM and resume builder",
      url: "https://huntr.co/",
      summary: "Combines job tracking, resumes, cover letters, contacts, interview tracking, notes, map view, and autofill.",
      usefulPatterns: ["Purpose-built CRM", "Interview tracking", "Contact tracking", "Saved posting details"],
      gaps: ["Less programmable", "Limited source strategy", "Agent handoff is not the main surface"],
      jobmaxxingResponse: ["MCP-first tools", "Agent playbooks", "Source-by-source safety gates"]
    ),
    CompetitorApp(
      id: "jobscan",
      name: "Jobscan",
      category: "ATS optimization",
      url: "https://www.jobscan.co/",
      summary: "Compares resumes to job listings, exposes missing keywords, checks ATS formatting, and supports review-before-send apply.",
      usefulPatterns: ["ATS match report", "Missing skill detection", "Formatting checks", "Review-before-send"],
      gaps: ["Keyword scores can be overused", "ATS fit is not hiring fit", "Weak on operations"],
      jobmaxxingResponse: ["Keyword extraction as one signal", "Human-readable evidence gap map", "No keyword stuffing"]
    ),
    CompetitorApp(
      id: "rezi",
      name: "Rezi",
      category: "Resume and cover letter builder",
      url: "https://www.rezi.ai/",
      summary: "Resume builder and AI writing tool focused on ATS-friendly resumes, cover letters, and content scoring.",
      usefulPatterns: ["Resume scoring", "ATS templates", "Cover letter generation", "Bullet rewrites"],
      gaps: ["Can reward formatting compliance over actual proof", "Needs stronger source and outcome tracking"],
      jobmaxxingResponse: ["Application pack diff", "Evidence coverage checks", "Readable proof over keyword stuffing"]
    ),
    CompetitorApp(
      id: "resume-worded",
      name: "Resume Worded",
      category: "Resume feedback",
      url: "https://resumeworded.com/",
      summary: "Resume and LinkedIn profile review with structured feedback, scoring, and improvement suggestions.",
      usefulPatterns: ["Resume rubric", "LinkedIn review", "Actionable feedback", "Score history"],
      gaps: ["Feedback can be detached from specific target roles", "No browser or recruiter workflow"],
      jobmaxxingResponse: ["Role-specific score", "Evidence-linked rewrites", "Profile-to-application consistency"]
    ),
    CompetitorApp(
      id: "loopcv",
      name: "LoopCV",
      category: "Always-on auto apply",
      url: "https://www.loopcv.pro/jobseekers/",
      summary: "Runs job searches, applies across boards, sends outreach, and tracks replies, board performance, and CV versions.",
      usefulPatterns: ["Continuous campaigns", "Board metrics", "Email outreach", "Parallel searches"],
      gaps: ["High-volume apply can damage signal", "Protected-site automation risk", "Quality depends on filters"],
      jobmaxxingResponse: ["Quality-first source queue", "Human submit gate", "Weekly source ROI"]
    ),
    CompetitorApp(
      id: "lazyapply",
      name: "LazyApply",
      category: "Auto-apply extension",
      url: "https://lazyapply.com/",
      summary: "Browser-based auto-apply workflow for applying to many roles across job boards.",
      usefulPatterns: ["High-volume automation", "Board-specific flows", "Fast repetitive form handling"],
      gaps: ["Quality and support concerns are common with auto-apply tools", "Mass volume can hurt candidate signal"],
      jobmaxxingResponse: ["Daily caps by quality score", "Manual protected-site mode", "Outcome learning before scaling"]
    ),
    CompetitorApp(
      id: "aihawk",
      name: "AIHawk",
      category: "Open-source application agent",
      url: "https://github.com/feder-cr/jobs_applier_ai_agent_aihawk",
      summary: "Open-source agent pattern for automated job applications and answer generation.",
      usefulPatterns: ["Scriptable pipeline", "Open-source inspectability", "Agent exception handling"],
      gaps: ["Automation can collide with site rules", "Needs consent, source trust, and evidence gates"],
      jobmaxxingResponse: ["Open local ledger", "Protected-domain policy", "Human approval before external action"]
    ),
    CompetitorApp(
      id: "sonara",
      name: "Sonara",
      category: "AI job search automation",
      url: "https://www.sonara.ai/",
      summary: "Learns the user, finds jobs, and applies to relevant openings until the user gets hired.",
      usefulPatterns: ["Profile intake", "Continuous matching", "Done-for-you flow", "Wide funnel"],
      gaps: ["Opaque decisions", "Hard to inspect claims", "Can drift from user voice"],
      jobmaxxingResponse: ["Auditable runs", "User voice memory", "Visible evidence"]
    ),
    CompetitorApp(
      id: "interviewing-io",
      name: "interviewing.io",
      category: "Interview prep",
      url: "https://interviewing.io/",
      summary: "Mock technical interviews and practice with experienced interviewers.",
      usefulPatterns: ["Realistic practice", "Feedback loops", "Technical drill structure"],
      gaps: ["Separate from application evidence and company research", "Can be scheduling-heavy"],
      jobmaxxingResponse: ["Evidence-based answer drills", "Company-specific practice", "Transcript critique"]
    ),
    CompetitorApp(
      id: "big-interview",
      name: "Big Interview",
      category: "Interview prep",
      url: "https://www.biginterview.com/",
      summary: "Interview training, question libraries, practice recordings, and coaching workflows.",
      usefulPatterns: ["Question banks", "Video practice", "Rubrics", "Role preparation"],
      gaps: ["Not integrated with actual saved jobs and proof links", "Less agent-programmable"],
      jobmaxxingResponse: ["Saved-job war room", "Proof-linked story bank", "Mode-specific mock sessions"]
    ),
    CompetitorApp(
      id: "final-round-ai",
      name: "Final Round AI",
      category: "Interview assistant",
      url: "https://www.finalroundai.com/",
      summary: "AI interview preparation and live interview assistance product category.",
      usefulPatterns: ["Transcript analysis", "Question prediction", "Real-time answer support"],
      gaps: ["Stealth live assistance can become misrepresentation", "Prep and live cheating must stay separated"],
      jobmaxxingResponse: ["Prep-only transcripts", "No stealth live answers", "Practice critique with evidence trace"]
    ),
    CompetitorApp(
      id: "wellfound",
      name: "Wellfound",
      category: "Startup job board",
      url: "https://wellfound.com/",
      summary: "Startup roles with founder access, upfront salary/equity, profile-based apply, and featured candidate workflows.",
      usefulPatterns: ["Salary and equity upfront", "Founder contact", "Profile application", "Startup signals"],
      gaps: ["Narrower market", "Profile quality matters heavily", "Follow-up is still manual"],
      jobmaxxingResponse: ["Startup fit score", "Founder outreach drafts", "Compensation question prep"]
    ),
    CompetitorApp(
      id: "welcome-to-the-jungle",
      name: "Welcome to the Jungle",
      category: "Matching and company research",
      url: "https://www.welcometothejungle.com/en",
      summary: "Matches users to roles, lets recruiters find profiles, and exposes richer company pages.",
      usefulPatterns: ["Company culture research", "Profile matching", "Recruiter inbound", "Candidate coach"],
      gaps: ["Company story can outweigh proof", "Coverage varies by geography", "Needs external tracking"],
      jobmaxxingResponse: ["Company research brief", "Role fit notes", "External tracker ingestion"]
    ),
    CompetitorApp(
      id: "linkedin",
      name: "LinkedIn Jobs",
      category: "Networked job board",
      url: "https://www.linkedin.com/help/linkedin/answer/a511260",
      summary: "Search, filters, alerts, saved jobs, Easy Apply, external apply, Open to Work, and network context.",
      usefulPatterns: ["Network graph", "Job alerts", "Saved jobs", "Easy Apply", "Profile leverage"],
      gaps: ["High application noise", "Protected-site automation constraints", "Generic outreach is ignored"],
      jobmaxxingResponse: ["Manual LinkedIn assist", "Referral map", "Proof-backed outreach"]
    ),
    CompetitorApp(
      id: "glassdoor",
      name: "Glassdoor",
      category: "Reviews and salary intelligence",
      url: "https://www.glassdoor.com/index.htm",
      summary: "Combines jobs, anonymous reviews, salary comparisons, company ratings, and workplace discussion.",
      usefulPatterns: ["Review mining", "Salary research", "Interview expectations", "Company risk checks"],
      gaps: ["Crowdsourced data needs verification", "Review sentiment can be noisy", "Workflow control is limited"],
      jobmaxxingResponse: ["Research brief with uncertainty labels", "Compensation prep", "Company risk summary"]
    )
  ]

  static let defaultJobBoardSources: [JobBoardSource] = [
    JobBoardSource(
      id: "linkedin-jobs",
      name: "LinkedIn Jobs",
      category: "Network and protected board",
      url: "https://www.linkedin.com/jobs",
      bestFor: "Warm referrals, recruiter context, saved searches, and profile-driven discovery.",
      usefulSignals: ["Mutual connections", "Hiring team", "Applicant count", "Open to Work fit", "Company posts"],
      deterministicSteps: ["Normalize job URL", "Extract company and role", "Dedupe saved jobs", "Record alert query"],
      agentSteps: ["Draft referral ask", "Review profile gaps", "Write concise contact message"],
      safetyChecks: ["No hidden scraping", "No auto-submit", "No messages without user approval"]
    ),
    JobBoardSource(
      id: "indeed",
      name: "Indeed",
      category: "High-volume board",
      url: "https://www.indeed.com/",
      bestFor: "Broad market coverage, salary comparisons, reviews, alerts, and quick screening.",
      usefulSignals: ["Posting freshness", "Salary", "Review context", "Location fit", "Qualification prompts"],
      deterministicSteps: ["Extract role facts", "Flag salary visibility", "Track employer duplicates"],
      agentSteps: ["Assess noisy postings", "Prepare screening answers", "Compare similar roles"],
      safetyChecks: ["Manual submit by default", "Avoid duplicate applications", "Verify employer legitimacy"]
    ),
    JobBoardSource(
      id: "greenhouse",
      name: "Greenhouse",
      category: "ATS",
      url: "https://www.greenhouse.com/",
      bestFor: "Direct company applications with clearer role pages and structured questions.",
      usefulSignals: ["Department", "Office", "Application questions", "Company domain"],
      deterministicSteps: ["Parse ATS URL", "Save questions", "Map required fields", "Snapshot posting text"],
      agentSteps: ["Tailor answers", "Build proof map", "Prepare browser steps"],
      safetyChecks: ["Stop before submit", "Do not invent required fields", "Keep uploads explicit"]
    ),
    JobBoardSource(
      id: "lever",
      name: "Lever",
      category: "ATS",
      url: "https://www.lever.co/",
      bestFor: "Direct startup and tech applications with compact posting pages.",
      usefulSignals: ["Team", "Location", "Custom questions", "Company careers page"],
      deterministicSteps: ["Parse posting", "Extract question set", "Dedupe company role pair"],
      agentSteps: ["Generate answers", "Find team context", "Draft follow-up"],
      safetyChecks: ["User controls final submit", "No fabricated work authorization", "No unsupported claims"]
    ),
    JobBoardSource(
      id: "workday",
      name: "Workday",
      category: "Enterprise ATS",
      url: "https://www.workday.com/",
      bestFor: "Large-company roles where application forms are long and repetitive.",
      usefulSignals: ["Requisition ID", "Location", "Business unit", "Application status"],
      deterministicSteps: ["Store profile field answers", "Track account domain", "Flag repeated questions"],
      agentSteps: ["Prepare answers", "Summarize whether the form is worth finishing", "Write follow-up notes"],
      safetyChecks: ["No credential storage", "No captcha bypass", "User reviews every field"]
    ),
    JobBoardSource(
      id: "wellfound-source",
      name: "Wellfound",
      category: "Startup board",
      url: "https://wellfound.com/",
      bestFor: "Startup salary/equity visibility, founder contact, and profile-based applications.",
      usefulSignals: ["Salary", "Equity", "Founder access", "Company stage", "Remote fit"],
      deterministicSteps: ["Extract compensation range", "Capture equity", "Tag startup stage"],
      agentSteps: ["Write founder note", "Prepare equity questions", "Research funding and customers"],
      safetyChecks: ["Verify current company data", "Separate facts from assumptions", "No fake enthusiasm"]
    ),
    JobBoardSource(
      id: "glassdoor-source",
      name: "Glassdoor",
      category: "Company intelligence",
      url: "https://www.glassdoor.com/index.htm",
      bestFor: "Salary, review, interview, and culture risk research before applying or interviewing.",
      usefulSignals: ["Salary range", "Review themes", "Interview reports", "CEO approval", "Benefits"],
      deterministicSteps: ["Attach research URL", "Record salary range", "Capture recurring review themes"],
      agentSteps: ["Summarize risk", "Prepare interview questions", "Check compensation leverage"],
      safetyChecks: ["Mark crowdsourced data as uncertain", "Cross-check claims", "Avoid quoting private posts"]
    ),
    JobBoardSource(
      id: "ziprecruiter",
      name: "ZipRecruiter",
      category: "Job board and alerts",
      url: "https://www.ziprecruiter.com/mobile",
      bestFor: "One-tap applications, viewed-application alerts, salary search, and broad listings.",
      usefulSignals: ["Viewed notification", "One-tap eligibility", "Salary data", "Local job alerts"],
      deterministicSteps: ["Record one-tap status", "Track viewed alerts", "Dedupe syndicated jobs"],
      agentSteps: ["Decide whether quick apply is too weak", "Draft short note", "Plan follow-up"],
      safetyChecks: ["No blind one-tap apply", "Review note before send", "Avoid duplicate syndicated roles"]
    )
  ]

  static let defaultAutomationPlaybooks: [AutomationPlaybook] = [
    AutomationPlaybook(
      id: "source-radar",
      title: "Source Radar",
      goal: "Find high-fit roles across boards without flooding the funnel.",
      trigger: "User asks for new roles, source strategy, or a job-board playbook.",
      deterministicSteps: ["Run saved search templates", "Normalize URLs", "Dedupe company-role pairs", "Score keyword overlap"],
      agentSteps: ["Reject noisy roles", "Explain fit gaps", "Prioritize targets", "Suggest referral paths"],
      safetyChecks: ["Do not scrape protected pages without user action", "Keep rejected roles inspectable"],
      outputs: ["Ranked target list", "Rejected-role reasons", "Search query updates"]
    ),
    AutomationPlaybook(
      id: "ats-field-kit",
      title: "ATS Field Kit",
      goal: "Turn a long application form into approved, reusable answers.",
      trigger: "User pastes a job form or asks for browser steps.",
      deterministicSteps: ["Extract field labels", "Match known profile answers", "Detect required uploads", "Flag missing facts"],
      agentSteps: ["Draft custom answers", "Ask for missing facts", "Create review checklist"],
      safetyChecks: ["No invented employment facts", "No credential capture", "No final submit"],
      outputs: ["Copy-ready answers", "Missing fact list", "Browser checkpoint"]
    ),
    AutomationPlaybook(
      id: "resume-gap-map",
      title: "Resume Gap Map",
      goal: "Show what the resume proves, what the role asks for, and what cannot be claimed.",
      trigger: "User imports a resume or saves a new role.",
      deterministicSteps: ["Extract JD keywords", "Extract resume terms", "Compute missing terms", "Attach source document IDs"],
      agentSteps: ["Separate real gaps from wording gaps", "Rewrite bullets with proof", "Warn against keyword stuffing"],
      safetyChecks: ["Every added claim needs evidence", "Keep unsupported gaps visible"],
      outputs: ["Gap matrix", "Resume bullet edits", "Claim trace"]
    ),
    AutomationPlaybook(
      id: "source-trust-check",
      title: "Source Trust Check",
      goal: "Catch scams, stale posts, duplicate syndication, and weak source signals before applying.",
      trigger: "User saves a role from an unfamiliar source or a high-volume board.",
      deterministicSteps: ["Compare job domain to company domain", "Check salary visibility", "Detect duplicate role URLs", "Flag vague remote terms"],
      agentSteps: ["Assess scam risk", "Research company legitimacy", "Decide whether to skip or request clarification"],
      safetyChecks: ["Do not enter personal data into suspicious forms", "Never pay to apply", "Verify recruiter identity"],
      outputs: ["Source trust score", "Scam flags", "Skip-or-continue recommendation"]
    ),
    AutomationPlaybook(
      id: "application-pack-diff",
      title: "Application Pack Diff",
      goal: "Show exactly what changed from the base resume or draft and why it changed.",
      trigger: "User generates a role-specific application pack.",
      deterministicSteps: ["Compare base and tailored bullets", "Map changed phrases", "Attach evidence IDs", "Flag unsupported additions"],
      agentSteps: ["Explain why each change helps", "Remove overfitting", "Rewrite weak claims"],
      safetyChecks: ["No hidden additions", "No unsupported metrics", "No keyword stuffing"],
      outputs: ["Diff summary", "Claim trace", "Approval checklist"]
    ),
    AutomationPlaybook(
      id: "recruiter-brief",
      title: "Recruiter Brief",
      goal: "Prepare concise outreach that sounds human and references one proof link.",
      trigger: "User finds a recruiter, founder, or likely hiring manager.",
      deterministicSteps: ["Save contact URL", "Link target job", "Select strongest evidence", "Build reminder"],
      agentSteps: ["Draft first message", "Draft follow-up", "Research public context", "Trim slop"],
      safetyChecks: ["No mass messaging", "User approves before sending", "No private-data assumptions"],
      outputs: ["Initial message", "Follow-up", "Contact ledger entry"]
    ),
    AutomationPlaybook(
      id: "contact-ledger",
      title: "Contact Ledger",
      goal: "Track recruiters, founders, referrals, messages, and follow-up cadence without sales-spam behavior.",
      trigger: "User finds a contact or asks for outreach.",
      deterministicSteps: ["Link person to role", "Record source URL", "Schedule follow-up", "Track response state"],
      agentSteps: ["Draft one-message outreach", "Personalize from public facts", "Recommend whether to follow up"],
      safetyChecks: ["No mass messaging", "No private-data assumptions", "Respect opt-outs"],
      outputs: ["Contact record", "Approved message", "Follow-up state"]
    ),
    AutomationPlaybook(
      id: "interview-war-room",
      title: "Interview War Room",
      goal: "Prepare stories, research, questions, and scorecards for every interview format.",
      trigger: "Job moves to interviewing or user requests practice.",
      deterministicSteps: ["Collect job facts", "Attach company URLs", "Select interview mode", "Build question bank"],
      agentSteps: ["Write story outlines", "Generate role questions", "Critique practice answers"],
      safetyChecks: ["Do not fabricate company facts", "Label assumptions", "Avoid memorized answers"],
      outputs: ["Interview pack", "Practice scorecard", "Company research brief"]
    ),
    AutomationPlaybook(
      id: "interview-transcript-review",
      title: "Interview Transcript Review",
      goal: "Turn practice transcripts into sharper stories and targeted drills.",
      trigger: "User imports a mock interview transcript or writes practice answers.",
      deterministicSteps: ["Split questions and answers", "Measure answer length", "Detect missing proof", "Tag repeated weak claims"],
      agentSteps: ["Critique answer structure", "Suggest stronger evidence", "Create next practice drill"],
      safetyChecks: ["Prep only", "No stealth live interview assistance", "No fabricated experience"],
      outputs: ["Transcript scorecard", "Story edits", "Next drills"]
    ),
    AutomationPlaybook(
      id: "weekly-hunt-retro",
      title: "Weekly Hunt Retro",
      goal: "Learn which sources, resume versions, and message styles create real replies.",
      trigger: "User asks what to improve or enough events have accumulated.",
      deterministicSteps: ["Aggregate saved roles", "Count stages", "Compare source outcomes", "List stale follow-ups"],
      agentSteps: ["Spot weak patterns", "Suggest experiments", "Update writing memory"],
      safetyChecks: ["Do not overfit tiny samples", "Keep recommendations reversible"],
      outputs: ["Source ROI", "Next experiments", "Prompt memory updates"]
    )
  ]

  static let defaultMarketComplaints: [MarketComplaint] = [
    MarketComplaint(
      id: "bot-spray",
      pattern: "Mass auto-apply tools bury thoughtful applications in low-quality volume.",
      impact: "Recruiters tighten filters, add screening, and strong candidates lose signal.",
      jobmaxxingResponse: "Optimize for fit, proof, and user-approved actions instead of raw application count.",
      sourceURL: "https://www.reddit.com/r/recruitinghell/comments/1tt50ml/autoapplying_bots_are_killing_honest_job_seekers/"
    ),
    MarketComplaint(
      id: "workday-fatigue",
      pattern: "Long ATS forms cause applicants to abandon roles mid-process.",
      impact: "Good roles are skipped because repetitive forms consume too much time.",
      jobmaxxingResponse: "Prepare reusable field kits and missing-fact prompts while keeping the user in control.",
      sourceURL: "https://simplify.jobs/blog/why-candidates-hate-workday"
    ),
    MarketComplaint(
      id: "ai-slop",
      pattern: "Generic AI resumes and cover letters make candidates sound interchangeable.",
      impact: "Applications can look polished but empty, weakening recruiter trust.",
      jobmaxxingResponse: "Use Amazon-style writing, user voice memory, proof links, and slop audits before sending.",
      sourceURL: "https://www.businessinsider.com/mistakes-job-seekers-avoid-using-ai-resumes-cover-letters-networking-2026-4"
    ),
    MarketComplaint(
      id: "opaque-tools",
      pattern: "Done-for-you tools hide why a job was selected or what got submitted.",
      impact: "Users cannot learn, debug, or confidently explain their own application strategy.",
      jobmaxxingResponse: "Expose command history, evidence trace, source reasoning, and approval state in the local ledger.",
      sourceURL: "https://www.sonara.ai/"
    )
  ]

  static let defaultState = JobmaxxingState(
    profile: CandidateProfile(
      name: "Example User",
      headline: "AI product engineer building agentic tools, finance research systems, and local-first automation.",
      linkedInURL: "",
      about: "Builds proof-backed AI workflows: agent control planes, finance research systems, safe browser workflows, local-first macOS apps, and review loops that make generated work inspectable.",
      targetRoles: ["AI product engineer", "founding engineer", "automation engineer"],
      locations: ["Remote", "Zurich", "London", "New York"],
      workAuthorization: "Confirm per role before applying.",
      compensationGoal: "High-upside role with strong base, equity, or clear contracting budget.",
      writingPreferences: [
        "Write directly and with proof.",
        "Use Amazon-style short sentences.",
        "Remove hype unless it is backed by a link.",
        "Name the shipped thing, not just the skill."
      ],
      evidence: [
        EvidenceItem(
          id: "evidence-marauder",
          title: "Built Marauder finance workspace",
          proof: "Built a multi-surface finance research system with desktop terminal, PWA, Smaug control plane, notebook, QuantLab, backend, shared contracts, and provider routing.",
          sourceURL: "https://marauder-main.up.railway.app",
          tags: ["finance", "research", "product", "backend", "frontend", "agents"],
          strength: 5
        ),
        EvidenceItem(
          id: "evidence-quantlab",
          title: "Built Quant Lab",
          proof: "Built a strategy testing surface that turns a rule into a backend-backed result with baselines, notes, and proof-first interpretation.",
          sourceURL: "https://quant-lab-production.up.railway.app",
          tags: ["finance", "data", "research", "testing"],
          strength: 5
        ),
        EvidenceItem(
          id: "evidence-smaug",
          title: "Built Smaug agent control plane",
          proof: "Built an assistant and operations control plane with harnesses, memory links, tools, workflow runs, Telegram integration, and runner visibility.",
          sourceURL: "https://smaug.up.railway.app",
          tags: ["agents", "automation", "workflow", "telegram", "tools"],
          strength: 5
        ),
        EvidenceItem(
          id: "evidence-jobmaxxing",
          title: "Built Jobmaxxing",
          proof: "Built this local-first job-search operating system with MCP tools, browser safety gates, writing memory, and native macOS workspace.",
          sourceURL: "https://github.com/Balllvin/Jobmaxxing",
          tags: ["agents", "macos", "swift", "mcp", "job search"],
          strength: 4
        )
      ],
      experience: defaultProfileExperience,
      education: [],
      skills: defaultProfileSkills,
      certifications: [],
      profileProjects: defaultProfileProjects,
      personalMemory: defaultProfileMemory,
      linkedInImportPlan: nil
    ),
    jobs: [],
    documents: [],
    documentIndexStatus: nil,
    events: [],
    modelRoutes: [
      ModelRoute(
        id: "cheap-drafts",
        label: "Light",
        provider: "OpenCode Go",
        model: "deepseek-v4-flash",
        reasoningEffort: "low",
        purpose: "Cheap extraction, keywording, summaries, and low-risk first drafts.",
        baseURL: "https://opencode.ai/zen/go/v1",
        keyReference: "OPENCODE_GO_API_KEY",
        isEnabled: true,
        isConnected: JobmaxxingStore.isOpenCodeProviderConnected("opencode-go", environmentKeys: ["OPENCODE_GO_API_KEY", "OPENCODE_API_KEY"])
      ),
      ModelRoute(
        id: "standard-writing",
        label: "Medium",
        provider: "OpenAI",
        model: "gpt-5.5",
        reasoningEffort: "medium",
        purpose: "Normal application writing, screening answers, and company research synthesis.",
        baseURL: "https://api.openai.com/v1",
        keyReference: "OPENAI_API_KEY",
        isEnabled: true,
        isConnected: JobmaxxingStore.hasEnvironmentValue("OPENAI_API_KEY")
      ),
      ModelRoute(
        id: "final-review",
        label: "High",
        provider: "OpenAI",
        model: "gpt-5.5",
        reasoningEffort: "high",
        purpose: "High-stakes application packs, interview stories, claim audit.",
        baseURL: "https://api.openai.com/v1",
        keyReference: "OPENAI_API_KEY",
        isEnabled: true,
        isConnected: JobmaxxingStore.hasEnvironmentValue("OPENAI_API_KEY")
      )
    ],
    hermes: defaultHermesSettings,
    hermesChat: defaultHermesChatState,
    integrationConnectors: defaultIntegrationConnectors,
    browserPolicy: BrowserPolicy(
      permissionMode: .manualOnly,
      allowLinkedInAutomation: false,
      allowExternalSubmission: false,
      requireFinalHumanSubmit: true
    ),
    interviewSessions: [],
    promptMemory: [
      "Use contact messages only after identifying the recruiter or hiring-team recipient.",
      "Application text must name shipped products and include links.",
      "No generic excitement language."
    ],
    competitorApps: defaultCompetitorApps,
    jobBoardSources: defaultJobBoardSources,
    automationPlaybooks: defaultAutomationPlaybooks,
    marketComplaints: defaultMarketComplaints,
    companyProfiles: defaultCompanyProfiles,
    contacts: [],
    agentRuns: []
  )
}
