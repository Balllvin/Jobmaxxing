export type ApplicationStage =
  | "saved"
  | "researching"
  | "drafting"
  | "ready_to_apply"
  | "applied"
  | "interviewing"
  | "offer"
  | "closed";

export type PermissionMode = "manual_only" | "assist_fill" | "autonomous_prepare";

export type InterviewMode = "text" | "call" | "onsite" | "panel";

export type BrowserRisk = "low" | "medium" | "high";

export interface EvidenceFact {
  id: string;
  label: string;
  proof: string;
  tags: string[];
}

/** One project under a company or organization, with CV-level and deep writeups. */
export interface ExperienceProject {
  id: string;
  name: string;
  /** Short CV-style summary. */
  summary: string;
  /** Full explanation for interviews, drafts, and claim review. */
  detail: string;
  /** One concrete sample anecdote or walkthrough. */
  specificSample: string;
  tools: string[];
  metrics: string[];
  tags: string[];
  sourceUrl: string;
}

/** Role or stint at a company/organization, with nested project writeups. */
export interface ExperienceEntry {
  id: string;
  title: string;
  organization: string;
  location: string;
  period: string;
  /** Broad overview of the stint. */
  summary: string;
  /** CV-style bullets. */
  bullets: string[];
  projects: ExperienceProject[];
  sourceUrl: string;
}

export interface UserProfile {
  name: string;
  targetRoles: string[];
  locations: string[];
  compensationGoal: string;
  workAuthorization: string;
  strengths: EvidenceFact[];
  /** Deep experience writeups beyond CV bullets. Used for drafts and interview prep. */
  experience: ExperienceEntry[];
  dealBreakers: string[];
  styleGuide: string[];
  writingRules: WritingRule[];
  modelTiers: ModelTier[];
  preferredModelTier: string;
  promptMemory: string[];
  permissions: {
    browser: PermissionMode;
    allowLinkedInAutomation: boolean;
    allowExternalSubmission: boolean;
    telegramWebhookUrl: string;
    hermesAgentPath: string;
  };
}

export interface WritingRule {
  id: string;
  label: string;
  instruction: string;
  severity: "required" | "preferred";
}

export interface ModelTier {
  id: string;
  label: string;
  bestFor: string;
  provider: string;
  model: string;
  reasoningEffort?: "none" | "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
  envVar: string;
  cost: "low" | "medium" | "high";
}

export interface HermesLayerConfig {
  agentPath: string;
  layerPath: string;
  defaultModelTier: string;
  updateCommand: string;
  requiredSkills: string[];
  requiredToolsets: string[];
  enabledConnectors: string[];
}

export interface IntegrationConnector {
  id: string;
  label: string;
  provider: string;
  purpose: string;
  enabled: boolean;
  connected: boolean;
  category?: string;
  capabilities?: string[];
}

export interface JobRecord {
  id: string;
  company: string;
  role: string;
  sourceUrl: string;
  description: string;
  stage: ApplicationStage;
  matchScore: number;
  matchReasons: string[];
  risks: string[];
  keywords: string[];
  nextActions: string[];
  documents: ApplicationPack | null;
  ledger: AgentEvent[];
  notes: string;
  dateLabel: string;
}

export interface ApplicationPack {
  resumeHeadline: string;
  resumeBullets: string[];
  coverLetter: string;
  screeningAnswers: ScreeningAnswer[];
  recruiterMessage: string;
  followUpMessage: string;
  claimTrace: ClaimTrace[];
  assumptions: string[];
  missingEvidence: string[];
}

export interface ScreeningAnswer {
  question: string;
  answer: string;
}

export interface ClaimTrace {
  claim: string;
  evidenceId: string;
  evidenceLabel: string;
  location?: string;
}

export interface AgentEvent {
  id: string;
  sequence: number;
  type: "research" | "draft" | "browser_plan" | "interview" | "tracking" | "learning";
  actor: "user" | "codex" | "claude" | "cursor" | "opencode" | "grok" | "hermes" | "system";
  summary: string;
  jobId: string;
  approval: "not_needed" | "proposed" | "approved_by_user" | "rejected_by_user";
}

export interface BrowserPlan {
  risk: BrowserRisk;
  mode: PermissionMode;
  allowed: string[];
  blocked: string[];
  userCheckpoint: string;
  recommendedSteps: string[];
}

export interface InterviewPack {
  mode: InterviewMode;
  company: string;
  role: string;
  warmup: string[];
  technical: string[];
  behavioral: string[];
  scorecard: string[];
  researchTasks: string[];
}

export interface AgentCommandResult {
  intent:
    | "discover"
    | "intelligence"
    | "apply"
    | "research"
    | "interview"
    | "network"
    | "profile"
    | "integrate"
    | "track"
    | "goal";
  summary: string;
  toolHints: string[];
  safety: string[];
  nextActions: string[];
}

export interface WritingAudit {
  score: number;
  ready: boolean;
  flags: string[];
  rewrites: string[];
  unsupportedClaims: string[];
  evidenceReferences: string[];
  prompt: string;
}

export interface JobmaxxingStore {
  schema: "jobmaxxing-store";
  revision: number;
  profile: UserProfile;
  hermes: HermesLayerConfig;
  currentGoal?: JobmaxxingGoal;
  connectors: IntegrationConnector[];
  companies: CompanyProfile[];
  contacts?: ContactRecord[];
  agentRuns?: ResearchAgentRun[];
  jobs: JobRecord[];
  events: AgentEvent[];
}

export interface JobSummary {
  id: string;
  company: string;
  role: string;
  stage: ApplicationStage;
  matchScore: number;
  nextAction: string;
  riskCount: number;
  ledgerCount: number;
  dateLabel: string;
}

export interface CompanySummary {
  id: string;
  name: string;
  category: string;
  relationship: string;
  applicationCount: number;
  peopleCount: number;
  researchStatus: string;
  nextAction: string;
}

export interface ContactSummary {
  id: string;
  name: string;
  role: string;
  companyNames: string[];
  relationship: string;
  researchStatus: string;
  hasWhatsApp: boolean;
}

export interface JobmaxxingStatus {
  schema: JobmaxxingStore["schema"];
  revision: number;
  profile: {
    name: string;
    targetRoles: string[];
    locations: string[];
    preferredModelTier: string;
    evidenceCount: number;
    promptMemoryCount: number;
  };
  goal?: JobmaxxingGoal;
  counts: {
    jobs: number;
    events: number;
    companies: number;
    contacts: number;
    agentRuns: number;
  };
  jobs: JobSummary[];
  companies: CompanySummary[];
  contacts: ContactSummary[];
  connectors: Array<Pick<IntegrationConnector, "id" | "label" | "enabled" | "connected" | "category">>;
  hermes: {
    defaultModelTier: string;
    requiredSkills: number;
    requiredToolsets: number;
    enabledConnectors: number;
  };
  nextActions: string[];
}

export interface MutationResult {
  ok: true;
  revision: number;
  status: JobmaxxingStatus;
  job?: JobRecord;
  event?: AgentEvent;
  company?: CompanyProfile;
  profile?: UserProfile;
  store?: JobmaxxingStore;
}

export interface JobmaxxingGoal {
  id: string;
  objective: string;
  status: "active" | "complete" | "blocked";
  successCriteria: string[];
  nextSteps: string[];
}

export interface CompanyProfile {
  id: string;
  name: string;
  website: string;
  linkedInUrl: string;
  category: string;
  size: string;
  headquarters: string;
  publicStatus: string;
  summary: string;
  relationship: string;
  applicationIds: string[];
  submittedMaterials: CompanySubmission[];
  people: CompanyPerson[];
  research: CompanyResearch;
  nextActions: string[];
  notes: string;
}

export interface CompanySubmission {
  id: string;
  jobId: string;
  materialType: string;
  title: string;
  summary: string;
  sourceUrl: string;
  status: string;
}

export interface CompanyPerson {
  id: string;
  name: string;
  title: string;
  sourceUrl: string;
  relationship: string;
  notes: string;
  communicationProfile?: PersonCommunicationProfile;
}

export interface ContactRecord {
  id: string;
  name: string;
  role: string;
  jobDescription: string;
  linkedInUrl: string;
  phone: string;
  email: string;
  location: string;
  sourceUrl: string;
  relationship: string;
  howMet: string;
  notes: string;
  personalNotes: string;
  projectNotes: string;
  companyLinks: ContactCompanyLink[];
  research: ContactResearchProfile;
  communicationProfile?: PersonCommunicationProfile;
}

export interface ContactCompanyLink {
  id: string;
  companyId: string;
  companyName: string;
  role: string;
  relationship: string;
  notes: string;
  sourceUrl: string;
}

export interface ContactResearchProfile {
  status: string;
  summary: string;
  publicFacts: string[];
  sourceUrls: string[];
  openQuestions: string[];
  proposedAdditions: string[];
}

export interface ResearchAgentRun {
  id: string;
  contextKind: "contact" | "company";
  contextId: string;
  title: string;
  agentName: string;
  modelTier: "Light" | "Medium" | "High" | string;
  status: string;
  summary: string;
  trace: ResearchAgentTraceStep[];
  proposedAdditions: string[];
}

export interface ResearchAgentTraceStep {
  id: string;
  title: string;
  detail: string;
  status: string;
  kind?: "reasoning" | "tool" | string;
  toolName?: string;
}

export interface PersonCommunicationProfile {
  whatsApp?: WhatsAppThreadProfile;
  appWideRules: string[];
}

export interface WhatsAppThreadProfile {
  threadId: string;
  displayName: string;
  jid: string;
  messageCount: number;
  outgoingCount: number;
  incomingCount: number;
  lastMessagePreview: string;
  styleSummary: string;
  relationshipSummary: string;
  topics: string[];
  directMessageFormat: string;
  emailFormat: string;
  suggestedDirectMessage: string;
  suggestedEmailMessage: string;
  allowedForAI: boolean;
}

export interface WhatsAppAnalyzedMessage {
  fromMe: boolean;
  text: string;
}

export interface CompanyResearch {
  status: string;
  confidence: number;
  websitePages: CompanyResearchPage[];
  products: string[];
  businessModel: string;
  leadership: string[];
  hiringSignals: string[];
  risks: string[];
  openQuestions: string[];
  sourceUrls: string[];
  agentPlan: string[];
}

export interface CompanyResearchPage {
  id: string;
  title: string;
  url: string;
  summary: string;
}

export interface JobInput {
  company: string;
  role: string;
  sourceUrl?: string;
  description: string;
  notes?: string;
  dateLabel?: string;
}

export interface CompetitorApp {
  id: string;
  name: string;
  category: string;
  url: string;
  summary: string;
  usefulPatterns: string[];
  gaps: string[];
  jobmaxxingResponse: string[];
}

export interface JobBoardSource {
  id: string;
  name: string;
  category: string;
  url: string;
  bestFor: string;
  usefulSignals: string[];
  deterministicSteps: string[];
  agentSteps: string[];
  safetyChecks: string[];
}

export interface AutomationPlaybook {
  id: string;
  title: string;
  goal: string;
  trigger: string;
  deterministicSteps: string[];
  agentSteps: string[];
  safetyChecks: string[];
  outputs: string[];
}

export interface MarketComplaint {
  id: string;
  pattern: string;
  impact: string;
  jobmaxxingResponse: string;
  sourceUrl: string;
}

export interface MarketIntelligence {
  competitors: CompetitorApp[];
  jobBoards: JobBoardSource[];
  playbooks: AutomationPlaybook[];
  complaints: MarketComplaint[];
  opportunities: string[];
}
