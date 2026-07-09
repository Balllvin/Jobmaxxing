import { mkdir, open, readFile, rename, rm, stat } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { dirname, resolve } from "node:path";
import { defaultStore } from "./seed";
import { normalizeCompanies } from "./companies";
import { normalizeUserFacingText } from "./jobmaxxing";
import { normalizeExternalUrl } from "./urls";
import type {
  ApplicationPack,
  AgentEvent,
  CompanyPerson,
  CompanyProfile,
  ContactRecord,
  JobRecord,
  JobmaxxingStatus,
  JobmaxxingStore,
  MutationResult,
  UserProfile
} from "./types";

let writeQueue: Promise<void> = Promise.resolve();
const lockRetryMs = 25;
const lockTimeoutMs = 10_000;
const staleLockMs = 30_000;

export function getDataPath(): string {
  return resolve(process.env.JOBMAXXING_DATA_PATH ?? "data/jobmaxxing.json");
}

export async function readStore(path = getDataPath()): Promise<JobmaxxingStore> {
  try {
    const raw = await readFile(path, "utf8");
    const parsed = JSON.parse(raw) as JobmaxxingStore;
    validateStore(parsed);
    return normalizeStore(parsed);
  } catch (error) {
    if (isMissingFile(error)) {
      return structuredClone(defaultStore);
    }
    throw new Error(`Could not read Jobmaxxing data from ${path}: ${toErrorMessage(error)}`, {
      cause: error
    });
  }
}

export async function writeStore(store: JobmaxxingStore, path = getDataPath()): Promise<void> {
  return withStoreLock(path, () => writeStoreFile(store, path));
}

export async function updateStore(
  mutator: (store: JobmaxxingStore) => JobmaxxingStore,
  path = getDataPath()
): Promise<JobmaxxingStore> {
  const operation = writeQueue.then(async () => {
    return withStoreLock(path, async () => {
      const current = await readStore(path);
      const next = mutator(structuredClone(current));
      const withRevision = { ...next, revision: current.revision + 1 };
      await writeStoreFile(withRevision, path);
      return withRevision;
    });
  });
  writeQueue = operation.then(
    () => undefined,
    () => undefined
  );
  return operation;
}

export async function readStoreStatus(path = getDataPath()): Promise<JobmaxxingStatus> {
  return buildStoreStatus(await readStore(path));
}

export function buildMutationResult(
  store: JobmaxxingStore,
  detail: Omit<MutationResult, "ok" | "revision" | "status" | "store"> = {},
  includeStore = false
): MutationResult {
  return {
    ok: true,
    revision: store.revision,
    status: buildStoreStatus(store),
    ...detail,
    ...(includeStore ? { store } : {})
  };
}

export function buildStoreStatus(store: JobmaxxingStore): JobmaxxingStatus {
  const jobs = store.jobs.slice(0, 20).map((job) => ({
    id: job.id,
    company: job.company,
    role: job.role,
    stage: job.stage,
    matchScore: job.matchScore,
    nextAction: job.nextActions[0] ?? "",
    riskCount: job.risks.length,
    ledgerCount: job.ledger.length,
    dateLabel: job.dateLabel
  }));
  const companies = store.companies.slice(0, 20).map((company) => ({
    id: company.id,
    name: company.name,
    category: company.category,
    relationship: company.relationship,
    applicationCount: company.applicationIds.length,
    peopleCount: company.people.length,
    researchStatus: company.research.status,
    nextAction: company.nextActions[0] ?? ""
  }));
  const contacts = (store.contacts ?? []).slice(0, 20).map((contact) => ({
    id: contact.id,
    name: contact.name,
    role: contact.role,
    companyNames: contact.companyLinks.map((link) => link.companyName).slice(0, 3),
    relationship: contact.relationship,
    researchStatus: contact.research.status,
    hasWhatsApp: Boolean(contact.communicationProfile?.whatsApp?.jid)
  }));
  const topJob = store.jobs.reduce<JobRecord | undefined>(
    (best, job) => (!best || job.matchScore > best.matchScore ? job : best),
    undefined
  );
  return {
    schema: store.schema,
    revision: store.revision,
    profile: {
      name: store.profile.name,
      targetRoles: store.profile.targetRoles,
      locations: store.profile.locations,
      preferredModelTier: store.profile.preferredModelTier,
      evidenceCount: store.profile.strengths.length,
      promptMemoryCount: store.profile.promptMemory.length
    },
    goal: store.currentGoal,
    counts: {
      jobs: store.jobs.length,
      events: store.events.length,
      companies: store.companies.length,
      contacts: store.contacts?.length ?? 0,
      agentRuns: store.agentRuns?.length ?? 0
    },
    jobs,
    companies,
    contacts,
    connectors: store.connectors.map((connector) => ({
      id: connector.id,
      label: connector.label,
      enabled: connector.enabled,
      connected: connector.connected,
      category: connector.category
    })),
    hermes: {
      defaultModelTier: store.hermes.defaultModelTier,
      requiredSkills: store.hermes.requiredSkills.length,
      requiredToolsets: store.hermes.requiredToolsets.length,
      enabledConnectors: store.hermes.enabledConnectors.length
    },
    nextActions: topJob
      ? [`Focus ${topJob.role} at ${topJob.company}.`, ...topJob.nextActions.slice(0, 3)]
      : ["Save a target role.", "Attach proof.", "Prepare a user-reviewed application pack."]
  };
}

async function writeStoreFile(store: JobmaxxingStore, path: string): Promise<void> {
  validateStore(store);
  await mkdir(dirname(path), { recursive: true });
  const tempPath = `${path}.${process.pid}.${randomUUID()}.tmp`;
  try {
    const handle = await open(tempPath, "w");
    try {
      await handle.writeFile(`${JSON.stringify(store, null, 2)}\n`, "utf8");
      await handle.sync();
    } finally {
      await handle.close();
    }
    await rename(tempPath, path);
  } catch (error) {
    await rm(tempPath, { force: true }).catch((cleanupError: unknown) => {
      console.warn(`Could not remove temporary Jobmaxxing store file ${tempPath}: ${toErrorMessage(cleanupError)}`);
    });
    throw error;
  }
}

async function withStoreLock<T>(path: string, operation: () => Promise<T>): Promise<T> {
  await mkdir(dirname(path), { recursive: true });
  const lockPath = `${path}.lock`;
  const started = Date.now();
  let handle = await tryAcquireLock(lockPath);
  while (!handle) {
    if (Date.now() - started > lockTimeoutMs) {
      throw new Error(`Timed out waiting for Jobmaxxing data lock at ${lockPath}.`);
    }
    await removeStaleLock(lockPath);
    await delay(lockRetryMs);
    handle = await tryAcquireLock(lockPath);
  }
  try {
    return await operation();
  } finally {
    await handle.close();
    await rm(lockPath, { force: true });
  }
}

async function tryAcquireLock(lockPath: string) {
  try {
    const handle = await open(lockPath, "wx");
    await handle.writeFile(`${process.pid}\n`, "utf8");
    return handle;
  } catch (error) {
    if (isExistingFile(error)) {
      return null;
    }
    throw error;
  }
}

async function removeStaleLock(lockPath: string): Promise<void> {
  const info = await stat(lockPath).catch((error: unknown) => {
    if (isMissingFile(error)) {
      return null;
    }
    throw error;
  });
  if (!info || Date.now() - info.mtimeMs < staleLockMs) {
    return;
  }
  await rm(lockPath, { force: true });
}

function delay(ms: number): Promise<void> {
  return new Promise((resolveDelay) => {
    setTimeout(resolveDelay, ms);
  });
}

export async function saveProfile(profile: UserProfile): Promise<JobmaxxingStore> {
  return updateStore((store) => ({ ...store, profile }));
}

export async function saveJob(job: JobRecord): Promise<JobmaxxingStore> {
  return updateStore((store) => {
    const existing = store.jobs.findIndex((item) => item.id === job.id);
    const jobs =
      existing === -1
        ? [job, ...store.jobs]
        : store.jobs.map((item, index) => (index === existing ? job : item));
    return { ...store, jobs };
  });
}

export async function addEvent(event: AgentEvent): Promise<JobmaxxingStore> {
  return updateStore((store) => {
    if (event.jobId && !store.jobs.some((job) => job.id === event.jobId)) {
      throw new Error(`Cannot attach event to missing job: ${event.jobId}`);
    }
    const jobs = event.jobId
      ? store.jobs.map((job) => (job.id === event.jobId ? { ...job, ledger: [event, ...job.ledger] } : job))
      : store.jobs;
    return {
      ...store,
      jobs,
      events: [event, ...store.events]
    };
  });
}

export function findJobOrThrow(store: JobmaxxingStore, jobId: string): JobRecord {
  const job = store.jobs.find((item) => item.id === jobId);
  if (!job) {
    throw new Error(`Job not found: ${jobId}`);
  }
  return job;
}

function validateStore(store: JobmaxxingStore): void {
  if (store.schema !== "jobmaxxing-store") {
    throw new Error("Unexpected Jobmaxxing store schema.");
  }
  if (
    !store.profile ||
    typeof store.profile !== "object" ||
    Array.isArray(store.profile) ||
    !Array.isArray(store.jobs) ||
    !Array.isArray(store.events)
  ) {
    throw new Error("Jobmaxxing store is missing required sections.");
  }
}

function normalizeStore(store: JobmaxxingStore): JobmaxxingStore {
  const revision = Number.isInteger(store.revision) && store.revision > 0 ? store.revision : defaultStore.revision;
  const jobs = store.jobs.map(normalizeJobForDisplay);
  const companies = normalizeCompanies({
    companies: Array.isArray(store.companies) ? store.companies : defaultStore.companies,
    jobs
  }).map(normalizeCompanyForDisplay);
  const profile = normalizeProfileForDisplay({
    ...defaultStore.profile,
    ...store.profile,
    experience: Array.isArray(store.profile.experience) ? store.profile.experience : defaultStore.profile.experience,
    writingRules: store.profile.writingRules?.length ? store.profile.writingRules : defaultStore.profile.writingRules,
    modelTiers: store.profile.modelTiers?.length ? store.profile.modelTiers : defaultStore.profile.modelTiers,
    preferredModelTier: store.profile.preferredModelTier || defaultStore.profile.preferredModelTier,
    permissions: {
      ...defaultStore.profile.permissions,
      ...store.profile.permissions
    }
  });
  return {
    ...store,
    revision,
    currentGoal: store.currentGoal,
    hermes: {
      ...defaultStore.hermes,
      ...store.hermes
    },
    companies,
    contacts: normalizeContacts(store.contacts, companies),
    agentRuns: Array.isArray(store.agentRuns) ? store.agentRuns : [],
    connectors: normalizeConnectors(store.connectors),
    jobs,
    profile
  };
}

function normalizeContacts(existingContacts: ContactRecord[] | undefined, companies: CompanyProfile[]): ContactRecord[] {
  const contacts = Array.isArray(existingContacts) ? structuredClone(existingContacts) : [];
  const index = buildContactIndex(contacts);
  for (const company of companies) {
    for (const person of company.people ?? []) {
      upsertContactInPlace(contacts, index, contactFromCompanyPerson(person, company));
    }
  }
  return contacts
    .map(normalizeContactForDisplay)
    .sort((left, right) => left.name.localeCompare(right.name));
}

function contactFromCompanyPerson(person: CompanyPerson, company: CompanyProfile): ContactRecord {
  const sourceUrl = person.sourceUrl ?? "";
  const linkedInUrl = sourceUrl.toLowerCase().includes("linkedin.com") ? sourceUrl : "";
  const phone = sourceUrl.toLowerCase().startsWith("tel:") ? sourceUrl.replace(/^tel:/i, "") : "";
  const role = normalizeUserFacingText(person.title);
  return normalizeContactForDisplay({
    id: person.id,
    name: person.name,
    role,
    jobDescription: "",
    linkedInUrl,
    phone,
    email: "",
    location: "",
    sourceUrl,
    relationship: person.relationship,
    howMet: "",
    notes: person.notes,
    personalNotes: "",
    projectNotes: "",
    companyLinks: [
      {
        id: `${person.id}-${company.id}-link`,
        companyId: company.id,
        companyName: company.name,
        role,
        relationship: person.relationship,
        notes: person.notes,
        sourceUrl
      }
    ],
    research: {
      status: "Not researched",
      summary: "No public contact research saved yet.",
      publicFacts: [],
      sourceUrls: [],
      openQuestions: [
        `What does ${person.name} do now?`,
        "How does the user know this person?",
        "Which company or application does this contact help with?"
      ],
      proposedAdditions: []
    },
    communicationProfile: person.communicationProfile
  });
}

function upsertContactInPlace(
  contacts: ContactRecord[],
  index: Map<string, number>,
  incoming: ContactRecord
): void {
  const whatsAppJid = incoming.communicationProfile?.whatsApp?.jid ?? "";
  const matchKeys = [
    contactIndexKey("id", incoming.id),
    incoming.phone ? contactIndexKey("phone", incoming.phone) : "",
    incoming.linkedInUrl ? contactIndexKey("linkedin", incoming.linkedInUrl.toLowerCase()) : "",
    whatsAppJid ? contactIndexKey("whatsapp", whatsAppJid) : "",
    ...incoming.companyLinks.map((link) => contactIndexKey("name-company", `${incoming.name.toLowerCase()}|${link.companyId}`))
  ].filter(Boolean);
  const existingIndex = matchKeys.map((key) => index.get(key)).find((value) => value !== undefined);
  if (existingIndex === undefined) {
    contacts.unshift(incoming);
    for (const [key, value] of index.entries()) {
      index.set(key, value + 1);
    }
    indexContact(contacts[0], 0, index);
    return;
  }
  const merged = normalizeContactForDisplay(contacts[existingIndex]);
  const companyLinks = [...merged.companyLinks];
  for (const link of incoming.companyLinks) {
    if (!companyLinks.some((existing) => existing.companyId === link.companyId)) {
      companyLinks.push(link);
    }
  }
  contacts[existingIndex] = {
    ...merged,
    role: merged.role || incoming.role,
    jobDescription: merged.jobDescription || incoming.jobDescription,
    linkedInUrl: merged.linkedInUrl || incoming.linkedInUrl,
    phone: merged.phone || incoming.phone,
    email: merged.email || incoming.email,
    location: merged.location || incoming.location,
    sourceUrl: merged.sourceUrl || incoming.sourceUrl,
    relationship: merged.relationship || incoming.relationship,
    howMet: merged.howMet || incoming.howMet,
    notes: joinUnique([merged.notes, incoming.notes]),
    personalNotes: joinUnique([merged.personalNotes, incoming.personalNotes]),
    projectNotes: joinUnique([merged.projectNotes, incoming.projectNotes]),
    companyLinks,
    communicationProfile: merged.communicationProfile ?? incoming.communicationProfile
  };
  indexContact(contacts[existingIndex], existingIndex, index);
}

function buildContactIndex(contacts: ContactRecord[]): Map<string, number> {
  const index = new Map<string, number>();
  contacts.forEach((contact, position) => indexContact(contact, position, index));
  return index;
}

function indexContact(contact: ContactRecord, position: number, index: Map<string, number>): void {
  index.set(contactIndexKey("id", contact.id), position);
  if (contact.phone) {
    index.set(contactIndexKey("phone", contact.phone), position);
  }
  if (contact.linkedInUrl) {
    index.set(contactIndexKey("linkedin", contact.linkedInUrl.toLowerCase()), position);
  }
  const whatsAppJid = contact.communicationProfile?.whatsApp?.jid;
  if (whatsAppJid) {
    index.set(contactIndexKey("whatsapp", whatsAppJid), position);
  }
  for (const link of contact.companyLinks) {
    index.set(contactIndexKey("name-company", `${contact.name.toLowerCase()}|${link.companyId}`), position);
  }
}

function contactIndexKey(kind: string, value: string): string {
  return `${kind}:${value}`;
}

function joinUnique(values: string[]): string {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))].join("\n");
}

function normalizeConnectors(connectors: JobmaxxingStore["connectors"] | undefined): JobmaxxingStore["connectors"] {
  const current = Array.isArray(connectors) ? connectors : [];
  const defaultIDs = new Set(defaultStore.connectors.map((connector) => connector.id));
  const knownConnectors = defaultStore.connectors.map((defaultConnector) => {
    const existing = current.find((connector) => connector.id === defaultConnector.id);
    if (!existing) {
      return defaultConnector;
    }
    return {
      ...defaultConnector,
      enabled: existing.enabled,
      connected: existing.enabled ? existing.connected : false
    };
  });
  return [
    ...knownConnectors,
    ...current.filter((connector) => !defaultIDs.has(connector.id))
  ];
}

function normalizeJobForDisplay(job: JobRecord): JobRecord {
  const sourceUrl = safeStoredExternalUrl(job.sourceUrl);
  const role = normalizeUserFacingText(job.role);
  const documents = job.documents ? normalizeApplicationPack(job.documents) : null;
  const normalized = {
    ...job,
    role,
    sourceUrl,
    description: normalizeUserFacingText(job.description),
    keywords: job.keywords.map(normalizeUserFacingText),
    documents
  };
  if (job.sourceUrl.trim() && !sourceUrl) {
    const risk = "Invalid source URL was removed during store normalization.";
    return {
      ...normalized,
      risks: normalized.risks.includes(risk) ? normalized.risks : [...normalized.risks, risk]
    };
  }
  return normalized;
}

function normalizeApplicationPack(pack: ApplicationPack): ApplicationPack {
  return {
    ...pack,
    resumeHeadline: normalizeUserFacingText(pack.resumeHeadline),
    resumeBullets: pack.resumeBullets.map(normalizeUserFacingText),
    coverLetter: normalizeDraftBodyText(pack.coverLetter),
    screeningAnswers: pack.screeningAnswers.map((answer) => ({
      question: normalizeDraftBodyText(answer.question),
      answer: normalizeDraftBodyText(answer.answer)
    })),
    recruiterMessage: normalizeUserFacingText(pack.recruiterMessage),
    followUpMessage: normalizeUserFacingText(pack.followUpMessage)
  };
}

function normalizeDraftBodyText(value: string): string {
  return isSourceLanguageArtifact(value) ? value : normalizeUserFacingText(value);
}

function isSourceLanguageArtifact(value: string): boolean {
  return /\b(Sehr geehrte|Ich bewerbe mich|Finanzthemen|Schweizerdeutsch|Warum VZ)\b/i.test(value);
}

function normalizeProfileForDisplay(profile: UserProfile): UserProfile {
  return {
    ...profile,
    targetRoles: profile.targetRoles.map(normalizeUserFacingText),
    strengths: profile.strengths.map((fact) => ({
      ...fact,
      label: normalizeUserFacingText(fact.label),
      proof: normalizeUserFacingText(fact.proof),
      tags: fact.tags.map(normalizeUserFacingText)
    })),
    experience: (profile.experience ?? []).map((entry) => ({
      ...entry,
      title: normalizeUserFacingText(entry.title),
      organization: normalizeUserFacingText(entry.organization),
      location: normalizeUserFacingText(entry.location),
      period: normalizeUserFacingText(entry.period),
      summary: normalizeUserFacingText(entry.summary),
      bullets: entry.bullets.map(normalizeUserFacingText),
      sourceUrl: entry.sourceUrl ?? "",
      projects: (entry.projects ?? []).map((project) => ({
        ...project,
        name: normalizeUserFacingText(project.name),
        summary: normalizeUserFacingText(project.summary),
        detail: normalizeUserFacingText(project.detail),
        specificSample: normalizeUserFacingText(project.specificSample),
        tools: project.tools.map(normalizeUserFacingText),
        metrics: project.metrics.map(normalizeUserFacingText),
        tags: project.tags.map(normalizeUserFacingText),
        sourceUrl: project.sourceUrl ?? ""
      }))
    })),
    promptMemory: profile.promptMemory.map(normalizeUserFacingText)
  };
}

function normalizeCompanyForDisplay(company: CompanyProfile): CompanyProfile {
  return {
    ...company,
    summary: normalizeUserFacingText(company.summary),
    submittedMaterials: company.submittedMaterials.map((material) => ({
      ...material,
      title: normalizeUserFacingText(material.title),
      summary: normalizeUserFacingText(material.summary)
    })),
    people: company.people.map((person) => ({
      ...person,
      name: normalizeUserFacingText(person.name),
      title: normalizeUserFacingText(person.title),
      notes: normalizeUserFacingText(person.notes)
    })),
    research: {
      ...company.research,
      websitePages: company.research.websitePages.map((page) => ({
        ...page,
        title: normalizeUserFacingText(page.title),
        summary: normalizeUserFacingText(page.summary)
      })),
      hiringSignals: company.research.hiringSignals.map(normalizeUserFacingText)
    }
  };
}

function normalizeContactForDisplay(contact: ContactRecord): ContactRecord {
  const name = normalizedContactName(contact);
  return {
    ...contact,
    name,
    role: normalizeUserFacingText(contact.role),
    jobDescription: normalizeUserFacingText(contact.jobDescription),
    notes: normalizeUserFacingText(contact.notes),
    companyLinks: contact.companyLinks.map((link) => ({
      ...link,
      role: normalizeUserFacingText(link.role),
      notes: normalizeUserFacingText(link.notes)
    })),
    research: {
      ...contact.research,
      summary: normalizeUserFacingText(contact.research.summary),
      publicFacts: contact.research.publicFacts.map(normalizeUserFacingText),
      openQuestions: contact.research.openQuestions.map(normalizeUserFacingText),
      proposedAdditions: contact.research.proposedAdditions.map(normalizeUserFacingText)
    }
  };
}

function normalizedContactName(contact: ContactRecord): string {
  return normalizeUserFacingText(contact.name);
}

function safeStoredExternalUrl(value: string): string {
  try {
    return normalizeExternalUrl(value);
  } catch {
    return "";
  }
}

function isMissingFile(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT";
}

function isExistingFile(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error && error.code === "EEXIST";
}

function toErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
