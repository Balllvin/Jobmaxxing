import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { describe, expect, it } from "vitest";
import { createJobRecord } from "../lib/jobmaxxing";
import { defaultStore } from "../lib/seed";
import { buildStoreStatus, readStore, writeStore } from "../lib/storage";

const testProfile = {
  ...defaultStore.profile,
  name: "Morgan Ellis",
  targetRoles: ["AI Workflow Engineer"],
  locations: ["Remote"],
  compensationGoal: "A product role with clear ownership.",
  workAuthorization: "Eligible to work.",
  strengths: [],
  experience: [],
  dealBreakers: [],
  styleGuide: [],
  promptMemory: []
};

const testCompany = {
  id: "example-systems",
  name: "Example Systems",
  website: "https://example.com/careers",
  linkedInUrl: "",
  category: "Target company",
  size: "50-100",
  headquarters: "Remote",
  publicStatus: "Private",
  summary: "Synthetic test fixture.",
  relationship: "Application target",
  applicationIds: [],
  submittedMaterials: [],
  people: [],
  research: {
    status: "Source notes saved",
    confidence: 60,
    websitePages: [],
    products: [],
    businessModel: "Subscription software",
    leadership: [],
    hiringSignals: [],
    risks: [],
    openQuestions: [],
    sourceUrls: ["https://example.com/careers"],
    agentPlan: []
  },
  nextActions: [],
  notes: "Synthetic test fixture."
};

describe("storage performance", () => {
  it("includes Grok as a default model connector", () => {
    const grok = defaultStore.connectors.find((connector) => connector.id === "xai");
    expect(grok).toMatchObject({
      id: "xai",
      label: "Grok",
      provider: "xAI",
      enabled: true,
      connected: false
    });
    expect(defaultStore.hermes.enabledConnectors).toContain("xai");
  });

  it("does not turn disabled or default connectors into connected rows", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-connector-state-"));
    const path = join(dir, "store.json");
    try {
      await writeStore(
        {
          ...defaultStore,
          connectors: [
            { ...defaultStore.connectors[0], id: "openai", enabled: false, connected: true },
            { ...defaultStore.connectors[1], id: "opencode", enabled: true, connected: false }
          ]
        },
        path
      );

      const normalized = await readStore(path);
      expect(normalized.connectors.find((connector) => connector.id === "openai")).toMatchObject({
        enabled: false,
        connected: false
      });
      expect(normalized.connectors.find((connector) => connector.id === "hermes")?.connected).toBe(false);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("keeps large status payloads compact instead of returning full store data", () => {
    const baseJob = createJobRecord(
      {
        company: "Payload Company",
        role: "Payload Role",
        description: "Build local-first job search workflows."
      },
      testProfile
    );
    const largeStore = {
      ...defaultStore,
      jobs: Array.from({ length: 120 }, (_, index) => ({
        ...baseJob,
        id: `job-${index}`,
        company: `Company ${index}`,
        role: `Role ${index}`,
        description: "Large saved job description ".repeat(120),
        notes: "Large private note ".repeat(80),
        ledger: Array.from({ length: 12 }, (_, eventIndex) => ({
          id: `event-${index}-${eventIndex}`,
          actor: "codex" as const,
          approval: "proposed" as const,
          jobId: `job-${index}`,
          sequence: index * 100 + eventIndex,
          summary: "Detailed event summary ".repeat(20),
          type: "tracking" as const
        }))
      })),
      events: Array.from({ length: 600 }, (_, index) => ({
        id: `store-event-${index}`,
        actor: "codex" as const,
        approval: "proposed" as const,
        jobId: `job-${index % 120}`,
        sequence: index,
        summary: "Full event detail ".repeat(25),
        type: "tracking" as const
      }))
    };

    const status = buildStoreStatus(largeStore);
    const fullBytes = Buffer.byteLength(JSON.stringify(largeStore));
    const statusBytes = Buffer.byteLength(JSON.stringify(status));

    expect(status.counts.jobs).toBe(120);
    expect(status.jobs).toHaveLength(20);
    expect(statusBytes).toBeLessThan(fullBytes / 8);
    expect(JSON.stringify(status)).not.toContain("Large saved job description");
  });

  it("normalizes large company and contact graphs without repeated lookup blowups", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-large-"));
    const path = join(dir, "store.json");
    const baseJob = createJobRecord(
      {
        company: "Large Company",
        role: "Large Role",
        description: "Build agents, documents, contacts, and application flows."
      },
      testProfile
    );
    const jobs = Array.from({ length: 600 }, (_, index) => ({
      ...baseJob,
      id: `large-job-${index}`,
      company: `Large Company ${index % 160}`,
      role: `Large Role ${index}`,
      description: `Build agents, documents, contacts, and application flows ${index}.`
    }));
    const companies = Array.from({ length: 160 }, (_, index) => ({
      ...testCompany,
      id: `large-company-${index}`,
      name: `Large Company ${index}`,
      applicationIds: [],
      people: Array.from({ length: 3 }, (_, personIndex) => ({
        id: `large-person-${index}-${personIndex}`,
        name: `Person ${index}-${personIndex}`,
        title: "Hiring context",
        sourceUrl: `https://example.com/people/${index}-${personIndex}`,
        relationship: "Potential hiring context",
        notes: "Imported from company profile."
      }))
    }));

    try {
      await writeStore({ ...defaultStore, profile: testProfile, jobs, companies }, path);
      const started = performance.now();
      const normalized = await readStore(path);
      const elapsedMs = performance.now() - started;

      expect(normalized.companies.length).toBeGreaterThanOrEqual(160);
      expect(normalized.contacts?.length).toBe(480);
      expect(elapsedMs).toBeLessThan(1500);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});
