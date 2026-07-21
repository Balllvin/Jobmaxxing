import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { createJobRecord } from "../lib/jobmaxxing";
import { defaultStore } from "../lib/seed";
import { buildStoreStatus, readStore, writeStore } from "../lib/storage";

const testCompany = {
  id: "example-fixture-co",
  name: "Example Fixture Co",
  website: "https://example.com/careers",
  linkedInUrl: "",
  category: "Target company",
  size: "50-100",
  headquarters: "Example City",
  publicStatus: "Private",
  summary: "Builds operations software for regulated teams.",
  relationship: "Application target",
  applicationIds: [],
  submittedMaterials: [],
  people: [],
  research: {
    status: "Source notes saved",
    confidence: 60,
    websitePages: [],
    products: ["Operations workspace"],
    businessModel: "Subscription software",
    leadership: [],
    hiringSignals: ["workflow engineering"],
    risks: [],
    openQuestions: [],
    sourceUrls: ["https://example.com/careers"],
    agentPlan: []
  },
  nextActions: [],
  notes: "Synthetic test fixture."
} satisfies (typeof defaultStore.companies)[number];

describe("storage status and normalization", () => {
  it("never restores a connected state for disabled connectors", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-connector-state-"));
    const path = join(dir, "store.json");
    try {
      await writeFile(
        path,
        `${JSON.stringify(
          {
            ...defaultStore,
            connectors: [
              { ...defaultStore.connectors[0], id: "openai", enabled: false, connected: true },
              { ...defaultStore.connectors[1], id: "opencode", enabled: true, connected: false }
            ]
          },
          null,
          2
        )}\n`,
        "utf8"
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

  it("returns a compact status instead of full saved-job payloads", () => {
    const baseJob = createJobRecord(
      {
        company: "Example Payload Co",
        role: "Example Role",
        description: "Build local-first job search workflows."
      },
      defaultStore.profile
    );
    const largeStore = {
      ...defaultStore,
      jobs: Array.from({ length: 120 }, (_, index) => ({
        ...baseJob,
        id: `job-${index}`,
        company: `Example Company ${index}`,
        role: `Example Role ${index}`,
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

  it("normalizes large company and contact graphs", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-large-"));
    const path = join(dir, "store.json");
    const baseJob = createJobRecord(
      {
        company: "Example Large Co",
        role: "Example Large Role",
        description: "Build agents, documents, contacts, and application flows."
      },
      defaultStore.profile
    );
    const jobs = Array.from({ length: 600 }, (_, index) => ({
      ...baseJob,
      id: `large-job-${index}`,
      company: `Example Large Company ${index % 160}`,
      role: `Example Large Role ${index}`,
      description: `Build agents, documents, contacts, and application flows ${index}.`
    }));
    const companies = Array.from({ length: 160 }, (_, index) => ({
      ...testCompany,
      id: `large-company-${index}`,
      name: `Example Large Company ${index}`,
      applicationIds: [],
      people: Array.from({ length: 3 }, (_, personIndex) => ({
        id: `large-person-${index}-${personIndex}`,
        name: `Example Person ${index}-${personIndex}`,
        title: "Hiring context",
        sourceUrl: `https://example.com/people/${index}-${personIndex}`,
        relationship: "Potential hiring context",
        notes: "Imported from company profile."
      }))
    }));

    try {
      await writeStore({ ...defaultStore, jobs, companies }, path);
      const normalized = await readStore(path);

      expect(normalized.companies.length).toBeGreaterThanOrEqual(160);
      expect(normalized.contacts?.length).toBe(480);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });
});
