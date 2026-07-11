import Foundation

enum AppSection: String, CaseIterable, Identifiable, Codable {
  case dashboard
  case chat
  case applications
  case companies
  case contacts
  case writing
  case interviews
  case browser
  case settings

  var id: String { rawValue }

  static let primarySections: [AppSection] = [
    .dashboard,
    .chat,
    .applications,
    .companies,
    .contacts,
    .writing,
    .interviews,
    .browser
  ]

  var title: String {
    switch self {
    case .dashboard: "Dashboard"
    case .chat: "Chat"
    case .applications: "Applications"
    case .companies: "Companies"
    case .contacts: "Contacts"
    case .writing: "Writing"
    case .interviews: "Interviews"
    case .browser: "Browser"
    case .settings: "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .dashboard: "rectangle.grid.2x2"
    case .chat: "message"
    case .applications: "briefcase"
    case .companies: "building.2"
    case .contacts: "person.crop.circle"
    case .writing: "text.badge.checkmark"
    case .interviews: "person.wave.2"
    case .browser: "safari"
    case .settings: "gearshape"
    }
  }
}

enum JobStage: String, CaseIterable, Identifiable, Codable {
  case saved
  case researching
  case drafting
  case ready
  case applied
  case interviewing
  case offer
  case closed

  var id: String { rawValue }

  var label: String {
    switch self {
    case .saved: "Open"
    case .researching: "Researching"
    case .drafting: "Drafting"
    case .ready: "Review"
    case .applied: "Applied"
    case .interviewing: "Interviewing"
    case .offer: "Offer"
    case .closed: "Closed"
    }
  }
}

enum PermissionMode: String, CaseIterable, Identifiable, Codable {
  case manualOnly
  case assistFill
  case autonomousPrepare

  var id: String { rawValue }

  var label: String {
    switch self {
    case .manualOnly: "Manual only"
    case .assistFill: "Assist fill"
    case .autonomousPrepare: "Autonomous prepare"
    }
  }
}

enum InterviewMode: String, CaseIterable, Identifiable, Codable {
  case text
  case call
  case onsite
  case panel

  var id: String { rawValue }
  var label: String { rawValue.capitalized }
}

struct JobmaxxingState: Codable {
  var profile: CandidateProfile
  var jobs: [JobRecord]
  var documents: [CandidateDocument]
  var documentIndexStatus: DocumentIndexStatus?
  var events: [ActivityEvent]
  /// Retained for lossless round-tripping after the standalone Command surface was removed.
  /// Do not expose this as a new workflow; existing private history must survive saves.
  var commandRuns: [CommandRun]? = nil
  var modelRoutes: [ModelRoute]
  var modelInventories: [ModelInventory]? = nil
  var hermes: HermesSettings?
  var hermesChat: HermesChatState?
  var currentGoal: JobmaxxingGoal? = nil
  var integrationConnectors: [IntegrationConnector]?
  var browserPolicy: BrowserPolicy
  var interviewSessions: [InterviewSession]
  var promptMemory: [String]
  var competitorApps: [CompetitorApp]?
  var jobBoardSources: [JobBoardSource]?
  var automationPlaybooks: [AutomationPlaybook]?
  var marketComplaints: [MarketComplaint]?
  var companyProfiles: [CompanyProfile]?
  var contacts: [ContactRecord]?
  var agentRuns: [ResearchAgentRun]?
}

struct JobmaxxingGoal: Identifiable, Codable, Hashable {
  var id: String
  var objective: String
  var status: String
  var successCriteria: [String]
  var nextSteps: [String]
}

struct CommandRun: Identifiable, Codable, Hashable {
  var id: String
  var command: String
  var actor: String
  var modelRouteID: String
  var result: String
  var toolHints: [String]
  var safety: [String]
}

struct CandidateProfile: Codable {
  var name: String
  var headline: String? = nil
  var linkedInURL: String? = nil
  var about: String? = nil
  var targetRoles: [String]
  var locations: [String]
  var workAuthorization: String
  var compensationGoal: String
  var writingPreferences: [String]
  var evidence: [EvidenceItem]
  var experience: [ProfileExperience]? = nil
  var education: [ProfileEducation]? = nil
  var skills: [String]? = nil
  var certifications: [String]? = nil
  var profileProjects: [ProfileProject]? = nil
  var personalMemory: [ProfileMemory]? = nil
  var linkedInImportPlan: ProfileImportPlan? = nil
}

struct ProfileExperience: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var organization: String
  var location: String
  var period: String
  var summary: String
  var bullets: [String]
  var sourceURL: String
  /// Nested project writeups beyond CV bullets. Used for drafts and interview prep.
  var projects: [ProfileExperienceProject]? = nil
}

struct ProfileExperienceProject: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  /// Short CV-style summary.
  var summary: String
  /// Full explanation for interviews and deep drafting.
  var detail: String
  /// One concrete sample anecdote or walkthrough.
  var specificSample: String
  var tools: [String]
  var metrics: [String]
  var tags: [String]
  var sourceURL: String
}

struct ProfileEducation: Identifiable, Codable, Hashable {
  var id: String
  var school: String
  var credential: String
  var period: String
  var notes: String
}

struct ProfileProject: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var url: String
  var summary: String
  var tags: [String]
}

struct ProfileMemory: Identifiable, Codable, Hashable {
  var id: String
  var kind: String
  var title: String
  var detail: String
  var source: String
  var strength: Int
}

struct ProfileImportPlan: Codable, Hashable {
  var sourceURL: String
  var status: String
  var checkpoint: String
  var steps: [String]
  var fields: [String]
  var blocked: [String]
}

struct EvidenceItem: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var proof: String
  var sourceURL: String
  var tags: [String]
  var strength: Int
}

struct JobRecord: Identifiable, Codable, Hashable {
  var id: String
  var company: String
  var role: String
  var sourceURL: String
  var description: String
  var stage: JobStage
  var score: Int
  var keywords: [String]
  var risks: [String]
  var nextActions: [String]
  var notes: String
  var draft: ApplicationDraft?
}

struct CompanyProfile: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var website: String
  var linkedInURL: String
  var category: String
  var size: String
  var headquarters: String
  var publicStatus: String
  var summary: String
  var relationship: String
  var applicationIDs: [String]
  var experienceIDs: [String]
  var submittedMaterials: [CompanySubmission]
  var people: [CompanyPerson]
  var research: CompanyResearch
  var nextActions: [String]
  var notes: String
}

struct CompanySubmission: Identifiable, Codable, Hashable {
  var id: String
  var jobID: String
  var materialType: String
  var title: String
  var summary: String
  var sourceURL: String
  var status: String
}

struct CompanyPerson: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var title: String
  var sourceURL: String
  var relationship: String
  var notes: String
  var communicationProfile: PersonCommunicationProfile? = nil
}

struct ContactRecord: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var role: String
  var jobDescription: String
  var linkedInURL: String
  var phone: String
  var email: String
  var location: String
  var sourceURL: String
  var relationship: String
  var howMet: String
  var notes: String
  var personalNotes: String
  var projectNotes: String
  var companyLinks: [ContactCompanyLink]
  var research: ContactResearchProfile
  var communicationProfile: PersonCommunicationProfile? = nil
  var agentMessages: [HermesChatMessage]? = nil
}

struct ContactCompanyLink: Identifiable, Codable, Hashable {
  var id: String
  var companyID: String
  var companyName: String
  var role: String
  var relationship: String
  var notes: String
  var sourceURL: String
}

struct ContactResearchProfile: Codable, Hashable {
  var status: String
  var summary: String
  var publicFacts: [String]
  var sourceURLs: [String]
  var openQuestions: [String]
  var proposedAdditions: [String]
}

struct ResearchAgentRun: Identifiable, Codable, Hashable {
  var id: String
  var contextKind: String
  var contextID: String
  var title: String
  var agentName: String
  var modelTier: String
  var status: String
  var summary: String
  var trace: [ResearchAgentTraceStep]
  var proposedAdditions: [String]
}

struct ResearchAgentTraceStep: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var detail: String
  var status: String
  var kind: String? = nil
  var toolName: String? = nil
}

struct PersonCommunicationProfile: Codable, Hashable {
  var whatsApp: WhatsAppThreadProfile? = nil
  var appWideRules: [String] = []
}

struct WhatsAppThreadCandidate: Identifiable, Codable, Hashable, Sendable {
  var id: String
  var chatSessionID: Int64
  var displayName: String
  var jid: String
  var messageCount: Int
  var lastMessagePreview: String
  var databasePath: String
}

struct WhatsAppThreadSearchResult: Hashable, Sendable {
  var status: String
  var candidates: [WhatsAppThreadCandidate]
}

struct WhatsAppContactSaveResult: Hashable, Sendable {
  var status: String
  var contactID: String?
}

struct WhatsAppThreadProfile: Codable, Hashable, Sendable {
  var threadID: String
  var chatSessionID: Int64
  var displayName: String
  var jid: String
  var databasePath: String
  var messageCount: Int
  var outgoingCount: Int
  var incomingCount: Int
  var lastMessagePreview: String
  var styleSummary: String
  var relationshipSummary: String
  var topics: [String]
  var directMessageFormat: String
  var emailFormat: String
  var suggestedDirectMessage: String
  var suggestedEmailMessage: String
  var allowedForAI: Bool
  var messages: [WhatsAppThreadMessage]? = nil
}

struct WhatsAppThreadMessage: Identifiable, Codable, Hashable, Sendable {
  var id: String
  var isFromMe: Bool
  var text: String
  var senderName: String
  var senderJID: String
}

struct CompanyResearch: Codable, Hashable {
  var status: String
  var confidence: Int
  var websitePages: [CompanyResearchPage]
  var products: [String]
  var businessModel: String
  var leadership: [String]
  var hiringSignals: [String]
  var risks: [String]
  var openQuestions: [String]
  var sourceURLs: [String]
  var agentPlan: [String]
}

struct CompanyResearchPage: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var url: String
  var summary: String
}

struct ApplicationDraft: Codable, Hashable {
  var headline: String
  var resumeBullets: [String]
  var coverLetter: String
  var recruiterMessage: String
  var screeningAnswers: [String]
  var evidenceLinks: [String]
  var claimTrace: [ApplicationClaimTrace]? = nil
  var assumptions: [String]? = nil
  var missingEvidence: [String]? = nil
}

struct ApplicationClaimTrace: Identifiable, Codable, Hashable {
  var id: String
  var claim: String
  var evidenceID: String
  var evidenceLabel: String
  var location: String
}

struct CandidateDocument: Identifiable, Codable, Hashable, Sendable {
  var id: String
  var title: String
  var fileName: String
  var filePath: String
  var kind: String
  var summary: String
  var extractedText: String
  var linkedEvidenceIDs: [String]
}

struct DocumentIndexStatus: Codable, Hashable {
  var documentID: String
  var documentTitle: String
  var durationMilliseconds: Int
  var succeeded: Bool
  var message: String
}

struct ActivityEvent: Identifiable, Codable, Hashable {
  var id: String
  var sequence: Int
  var actor: String
  var jobID: String
  var title: String
  var detail: String
  var approval: String
}

struct ModelRoute: Identifiable, Codable, Hashable {
  var id: String
  var label: String
  var provider: String
  var model: String
  var reasoningEffort: String?
  var purpose: String
  var baseURL: String
  var keyReference: String
  var isEnabled: Bool
  var isConnected: Bool
}

struct ModelInventory: Codable, Hashable {
  var providerID: String
  var modelIDs: [String]
}

struct HermesSettings: Codable, Hashable {
  var installPath: String
  var layerPath: String
  var defaultModelRouteID: String
  var updateCommand: String
  var isLayerInstalled: Bool
}

struct IntegrationConnector: Identifiable, Codable, Hashable {
  var id: String
  var label: String
  var provider: String
  var purpose: String
  var isEnabled: Bool
  var isConnected: Bool
  var category: String? = nil
  var capabilities: [String]? = nil
  var configFields: [ConnectorConfigField]? = nil
  var isHidden: Bool? = nil
}

struct ConnectorCheckResult: Identifiable, Equatable, Hashable {
  var id: String { connectorID }
  var connectorID: String
  var isConnected: Bool
  var summary: String
  var detail: String
  var checkedAt: Date
}

struct ConnectorConfigField: Identifiable, Codable, Hashable {
  var id: String
  var label: String
  var value: String
  var placeholder: String
  var isSecret: Bool
}

struct HermesChatState: Codable, Hashable {
  var settings: HermesChatSettings
  var threads: [HermesChatThread]
  var selectedThreadID: String
}

struct HermesChatSettings: Codable, Hashable {
  var telegramBotTokenReference: String
  var telegramChatID: String
  var webhookURL: String
  var traceVerbosity: String
  var enabledCommandIDs: [String]
  var telegramLastUpdateID: Int? = nil
}

struct HermesChatThread: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var summary: String
  var status: String
  var sequence: Int
  var messages: [HermesChatMessage]
}

struct HermesChatMessage: Identifiable, Codable, Hashable {
  var id: String
  var role: String
  var text: String
  var status: String
  var commandID: String?
  var traces: [HermesTraceStep]
  var attachments: [HermesChatAttachment]? = nil
}

struct HermesChatAttachment: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var kind: String
  var filePath: String
}

struct HermesTraceStep: Identifiable, Codable, Hashable {
  var id: String
  var label: String
  var status: String
  var toolName: String
  var detail: String
}

struct BrowserPolicy: Codable, Hashable {
  var permissionMode: PermissionMode
  var allowLinkedInAutomation: Bool
  var allowExternalSubmission: Bool
  var requireFinalHumanSubmit: Bool
}

struct BrowserPlan: Hashable {
  var risk: String
  var checkpoint: String
  var steps: [String]
  var blocked: [String]
}

struct WritingAuditResult: Hashable {
  var score: Int
  var ready: Bool
  var flags: [String]
  var rewriteRules: [String]
  var unsupportedClaims: [String]
  var evidenceReferences: [String]
}

struct CompetitorApp: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var category: String
  var url: String
  var summary: String
  var usefulPatterns: [String]
  var gaps: [String]
  var jobmaxxingResponse: [String]
}

struct JobBoardSource: Identifiable, Codable, Hashable {
  var id: String
  var name: String
  var category: String
  var url: String
  var bestFor: String
  var usefulSignals: [String]
  var deterministicSteps: [String]
  var agentSteps: [String]
  var safetyChecks: [String]
}

struct AutomationPlaybook: Identifiable, Codable, Hashable {
  var id: String
  var title: String
  var goal: String
  var trigger: String
  var deterministicSteps: [String]
  var agentSteps: [String]
  var safetyChecks: [String]
  var outputs: [String]
}

struct MarketComplaint: Identifiable, Codable, Hashable {
  var id: String
  var pattern: String
  var impact: String
  var jobmaxxingResponse: String
  var sourceURL: String
}

struct InterviewSession: Identifiable, Codable, Hashable {
  var id: String
  var jobID: String
  var mode: InterviewMode
  var questions: [String]
  var scorecard: [String]
  var notes: String
}
