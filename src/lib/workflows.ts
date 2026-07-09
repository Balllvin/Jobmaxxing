import { randomUUID } from "node:crypto";
import {
  applyLearning,
  buildApplicationPack,
  buildInterviewPack,
  createJobRecord,
  scoreJob
} from "./jobmaxxing";
import { addCompanySubmission, prepareCompanyResearch, syncCompanyForJob } from "./companies";
import { findJobOrThrow, readStore, updateStore } from "./storage";
import { companyIdSchema, profileSchema, type EventInput } from "./contracts";
import type {
  ApplicationStage,
  CompanyProfile,
  InterviewMode,
  JobInput,
  JobRecord,
  JobmaxxingStore,
  UserProfile
} from "./types";

export async function saveProfileWorkflow(profile: UserProfile): Promise<JobmaxxingStore> {
  const nextProfile = profileSchema.parse(profile);
  return updateStore((store) => ({ ...store, profile: nextProfile }));
}

export async function addJobWorkflow(input: JobInput): Promise<JobmaxxingStore> {
  return updateStore((store) => {
    const job = createJobRecord(input, store.profile);
    job.documents = buildApplicationPack(store.profile, job);
    return { ...store, companies: syncCompanyForJob(store.companies, job), jobs: [job, ...store.jobs] };
  });
}

export async function patchJobWorkflow(
  jobId: string,
  body: Partial<{ stage: ApplicationStage; notes: string; dateLabel: string; description: string }>
): Promise<JobmaxxingStore> {
  return updateStore((store) => {
    const current = findJobOrThrow(store, jobId);
    const rescored =
      body.description && body.description !== current.description
        ? scoreJob(store.profile, { role: current.role, description: body.description, sourceUrl: current.sourceUrl })
        : null;
    const next: JobRecord = {
      ...current,
      ...body,
      ...(rescored
        ? {
            matchScore: rescored.score,
            matchReasons: rescored.reasons,
            risks: rescored.risks
          }
        : {})
    };
    return {
      ...store,
      companies: syncCompanyForJob(store.companies, next),
      jobs: store.jobs.map((job) => (job.id === jobId ? next : job))
    };
  });
}

export async function draftApplicationWorkflow(jobId: string): Promise<JobmaxxingStore> {
  return updateStore((store) => {
    const job = findJobOrThrow(store, jobId);
    const documents = buildApplicationPack(store.profile, job);
    const nextJob = { ...job, documents, stage: "drafting" as const };
    return {
      ...store,
      companies: addCompanySubmission(syncCompanyForJob(store.companies, nextJob), nextJob, {
        materialType: "Application draft",
        title: "Proof-linked application pack",
        summary: "Generated headline, resume bullets, cover letter, contact message, screening answers, and claim trace.",
        sourceUrl: job.sourceUrl,
        status: "Proposed"
      }),
      jobs: store.jobs.map((item) => (item.id === jobId ? nextJob : item))
    };
  });
}

export async function prepareCompanyResearchWorkflow(companyId: string): Promise<CompanyProfile> {
  const parsed = companyIdSchema.parse({ companyId });
  let prepared: CompanyProfile | null = null;
  await updateStore((store) => {
    prepared = prepareCompanyResearch(store, parsed.companyId);
    return {
      ...store,
      companies: store.companies.map((company) => (company.id === parsed.companyId ? prepared as CompanyProfile : company))
    };
  });
  if (!prepared) {
    throw new Error(`Company not found: ${parsed.companyId}`);
  }
  return prepared;
}

export async function buildInterviewWorkflow(jobId: string, mode: InterviewMode) {
  const store = await readStore();
  const job = findJobOrThrow(store, jobId);
  return buildInterviewPack(store.profile, job, mode);
}

export async function recordLearningWorkflow(note: string, rating: number): Promise<JobmaxxingStore> {
  return updateStore((store) => ({
    ...store,
    profile: applyLearning(store.profile, note, rating)
  }));
}

export async function logActivityWorkflow(input: EventInput): Promise<JobmaxxingStore> {
  return updateStore((store) => {
    findJobOrThrow(store, input.jobId);
    const maxSequence = Math.max(0, ...store.events.map((item) => item.sequence));
    const event = {
      id: randomUUID(),
      sequence: maxSequence + 1,
      ...input
    };
    const jobs = store.jobs.map((job) => (job.id === event.jobId ? { ...job, ledger: [event, ...job.ledger] } : job));
    return {
      ...store,
      jobs,
      events: [event, ...store.events]
    };
  });
}
