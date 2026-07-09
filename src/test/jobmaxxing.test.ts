import { existsSync } from "node:fs";
import { execFile } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { promisify } from "node:util";
import { describe, expect, it } from "vitest";
import {
  auditWriting,
  analyzeWhatsAppThread,
  buildAgentCommand,
  buildApplicationPack,
  buildBrowserPlan,
  buildInterviewPack,
  normalizeUserFacingText,
  createEvent,
  createJobRecord,
  scoreJob
} from "../lib/jobmaxxing";
import { buildAutomationPlaybook, buildMarketIntelligence } from "../lib/intelligence";
import { defaultStore } from "../lib/seed";
import { buildStoreStatus, readStore, updateStore, writeStore } from "../lib/storage";
import { logActivityWorkflow, saveProfileWorkflow } from "../lib/workflows";
import { profileSchema } from "../lib/contracts";

const execFileAsync = promisify(execFile);
const savedJob = createJobRecord(
  {
    company: "Northstar Climate Bank",
    role: "AI Product Engineer",
    description: "Own agent workflows, dashboards, finance data, testing, and operational automation."
  },
  defaultStore.profile
);
const storeWithSavedJob = {
  ...defaultStore,
  jobs: [savedJob]
};

describe("jobmaxxing core", () => {
  it("starts without sample target applications in production defaults", () => {
    expect(defaultStore.jobs).toEqual([]);
    expect(defaultStore.companies.map((company) => company.name)).not.toContain("HelioForge Robotics");
  });

  it("scores evidence-backed agent roles higher than unrelated roles", () => {
    const agentRole = scoreJob(defaultStore.profile, {
      role: "Agent Workflow Engineer",
      description: "Build browser automation, agent review loops, TypeScript workflows, and approval surfaces."
    });
    const unrelatedRole = scoreJob(defaultStore.profile, {
      role: "Restaurant General Manager",
      description: "Own kitchen staffing, vendor ordering, menu planning, and hospitality standards."
    });

    expect(agentRole.score).toBeGreaterThan(unrelatedRole.score);
    expect(agentRole.reasons.join(" ")).toContain("Evidence match");
  });

  it("creates proof-backed application packs with claim traces", () => {
    const job = createJobRecord(
      {
        company: "Northstar Climate Bank",
        role: "AI Product Engineer",
        description: "Own agent workflows, dashboards, finance data, testing, and operational automation."
      },
      defaultStore.profile
    );

    const pack = buildApplicationPack(defaultStore.profile, job);

    expect(pack.coverLetter).toContain(job.company);
    expect(pack.coverLetter).toContain("I am interested in the");
    expect(pack.coverLetter.toLowerCase()).not.toContain("i am applying for");
    expect(pack.coverLetter.toLowerCase()).not.toContain("maps to");
    expect(pack.coverLetter.toLowerCase()).not.toContain("highest-friction");
    expect(pack.coverLetter.toLowerCase()).not.toContain("real bottleneck");
    expect(pack.coverLetter.toLowerCase()).not.toContain("i can start on");
    expect(pack.coverLetter.toLowerCase()).not.toContain("the posting asks");
    expect(pack.coverLetter.toLowerCase()).not.toContain("happy to hear back");
    expect(pack.coverLetter.toLowerCase()).not.toContain("one concrete example");
    expect(pack.coverLetter).toContain("My CV is attached");
    expect(pack.coverLetter).toContain("I would look forward to hearing back from you");
    expect(pack.coverLetter.toLowerCase()).toMatch(/for example|relevant work|background|built|recent work/);
    expect(pack.resumeBullets.length).toBeGreaterThan(0);
    expect(pack.claimTrace.length).toBeGreaterThanOrEqual(pack.resumeBullets.length);
    expect(pack.missingEvidence.length).toBeGreaterThanOrEqual(0);
  });

  it("normalizes safe job source URLs and rejects unsafe schemes", () => {
    const job = createJobRecord(
      {
        company: "Kestrel Health Systems",
        role: "Workflow Engineer",
        description: "Build hiring workflow tools.",
        sourceUrl: "company.example/careers"
      },
      defaultStore.profile
    );

    expect(job.sourceUrl).toBe("https://company.example/careers");
    expect(() =>
      createJobRecord(
        {
          company: "Kestrel Health Systems",
          role: "Workflow Engineer",
          description: "Build hiring workflow tools.",
          sourceUrl: "javascript:alert(1)"
        },
        defaultStore.profile
      )
    ).toThrow("Unsupported URL scheme");
  });

  it("normalizes user-facing drift while preserving source-language artifacts", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-normalize-"));
    const path = join(dir, "store.json");
    const rawPack = buildApplicationPack(defaultStore.profile, savedJob);
    const driftedJob = {
      ...savedJob,
      id: "job-language-drift",
      company: "Example Robotics",
      role: "AI/ML Platform Engineer",
      keywords: ["AIML", "agent-based workflows"],
      documents: {
        ...rawPack,
        resumeHeadline: "AI/ML Platform Engineer candidate",
        recruiterMessage: "Hi, I found the Data / ML / AI role.",
        followUpMessage: "Following up on the AI/ML Platform Engineer role.",
        coverLetter: "Sehr geehrte Damen und Herren,\n\nIch bewerbe mich für die Platform Engineer Rolle."
      }
    };
    const driftedContact = {
      id: "jordan-live",
      name: "Jordan",
      role: "Supply Chain internship contact",
      jobDescription: "",
      linkedInUrl: "https://www.linkedin.com/in/jordan-rivera-example",
      phone: "",
      email: "",
      location: "",
      sourceUrl: "",
      relationship: "Hiring contact",
      howMet: "WhatsApp",
      notes: "",
      personalNotes: "",
      projectNotes: "",
      companyLinks: [
        {
          id: "jordan-example-robotics",
          companyId: "example-robotics",
          companyName: "Example Robotics",
          role: "Supply Chain internship contact",
          relationship: "Hiring contact",
          notes: "",
          sourceUrl: ""
        }
      ],
      research: {
        status: "Enhanced",
        summary: "LinkedIn public search identifies him as Jordan Rivera.",
        publicFacts: ["LinkedIn public search identifies him as Jordan Rivera."],
        sourceUrls: [],
        openQuestions: [],
        proposedAdditions: []
      }
    };
    try {
      await writeStore(
        {
          ...storeWithSavedJob,
          jobs: [driftedJob],
          profile: {
            ...defaultStore.profile,
            strengths: [
              {
                id: "fact-contract",
                label: "Example Analytics data tooling contract",
                proof: "Contracted as Working Student at Example Analytics Ltd to support reporting.",
                tags: ["Working Student"]
              }
            ],
            promptMemory: [
              "Example Analytics can be claimed as contracted Working Student work.",
              "Apple Mail contract evidence: Sample Candidate Vertrag.pdf"
            ]
          },
          contacts: [driftedContact]
        },
        path
      );

      const normalized = await readStore(path);
      const job = normalized.jobs[0];

      expect(normalizeUserFacingText("AIML - Machine Learning Research Engineer")).toBe("Machine Learning Research Engineer");
      expect(job.role).toBe("AI and ML Platform Engineer");
      expect(job.keywords).toContain("AI and ML");
      expect(job.documents?.resumeHeadline).toBe("AI and ML Platform Engineer candidate");
      expect(job.documents?.recruiterMessage).toContain("Data, ML, and AI role");
      expect(job.documents?.followUpMessage).toContain("AI and ML Platform Engineer role");
      expect(job.documents?.coverLetter).toContain("Sehr geehrte Damen und Herren");
      expect(normalized.contacts?.[0].name).toBe("Jordan");
      expect(normalized.profile.strengths[0].proof).toContain("Working Student");
      expect(normalized.profile.strengths[0].tags).toContain("Working Student");
      expect(normalized.profile.promptMemory.join(" ")).toContain("Sample Candidate Vertrag.pdf");
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("does not use zero-relevance evidence for no-evidence roles", () => {
    const job = createJobRecord(
      {
        company: "Harbor Bistro",
        role: "Restaurant General Manager",
        description: "Own kitchen staffing, vendor ordering, menu planning, hospitality standards, and food safety."
      },
      defaultStore.profile
    );

    const pack = buildApplicationPack(defaultStore.profile, job);

    expect(pack.resumeBullets).toEqual([]);
    expect(pack.claimTrace).toEqual([]);
    expect(pack.missingEvidence.join(" ")).toContain("No saved evidence");
    expect(pack.coverLetter).toContain("needs matching evidence");
    expect(pack.recruiterMessage).not.toContain("agent workflows");
  });

  it("blocks protected-site browser automation by default", () => {
    const plan = buildBrowserPlan(
      defaultStore.profile,
      "Apply to this role",
      "https://www.linkedin.com/jobs/view/example"
    );

    expect(plan.mode).toBe("manual_only");
    expect(plan.risk).toBe("high");
    expect(plan.blocked.join(" ")).toContain("No LinkedIn");
  });

  it("builds mock interview packs for saved jobs", () => {
    const pack = buildInterviewPack(defaultStore.profile, savedJob, "call");

    expect(pack.mode).toBe("call");
    expect(pack.warmup.length).toBeGreaterThan(1);
    expect(pack.scorecard.join(" ")).toContain("Truthfulness");
  });

  it("audits AI slop and emits a rewrite prompt", () => {
    const audit = auditWriting(
      "I am excited to apply because your innovative company is changing the landscape with cutting-edge AI.",
      defaultStore.profile
    );

    expect(audit.score).toBeLessThan(100);
    expect(audit.ready).toBe(false);
    expect(audit.flags.join(" ")).toContain("AI-slop");
    expect(audit.prompt).toContain("Writing rules");
    expect(audit.prompt).toContain("Humble confidence");
    expect(audit.prompt).toContain("two questions");
    expect(audit.prompt).toContain("I am interested in");
    expect(audit.prompt).toContain("Deep experience and project writeups");
    expect(audit.prompt).toContain("I would look forward to hearing back from you");
    expect(audit.prompt).toContain("Know your audience");
    expect(audit.prompt).toContain("Do not restate what the company");
  });

  it("flags empty mapping talk as AI slop", () => {
    const audit = auditWriting(
      "The role maps to work I have already done in agent workflows with browser use, local data, review loops, and explicit safety gates.",
      defaultStore.profile
    );

    expect(audit.ready).toBe(false);
    expect(audit.flags.join(" ").toLowerCase()).toContain("maps to");
  });

  it("uses deep experience writeups for a broad-then-specific cover letter", () => {
    const job = createJobRecord(
      {
        company: "Northstar Climate Bank",
        role: "AI Product Engineer",
        description: "Own agent workflows, dashboards, finance data, testing, and operational automation."
      },
      defaultStore.profile
    );
    const pack = buildApplicationPack(defaultStore.profile, job);
    expect(defaultStore.profile.experience.length).toBeGreaterThan(0);
    expect(pack.coverLetter).toMatch(/For example,/);
    expect(pack.coverLetter).toContain("My CV is attached");
    expect(pack.coverLetter.split("\n\n").length).toBeGreaterThanOrEqual(3);
  });

  it("identifies unsupported candidate claims instead of passing weak drafts", () => {
    const audit = auditWriting(
      "I have shipped global payment systems and I am a strong fit for this high-scale payments role.",
      defaultStore.profile
    );

    expect(audit.ready).toBe(false);
    expect(audit.unsupportedClaims).toEqual(
      expect.arrayContaining([
        "I have shipped global payment systems and I am a strong fit for this high-scale payments role"
      ])
    );
    expect(audit.flags.join(" ")).toContain("Unsupported claim");
  });

  it("passes concise drafts that cite saved evidence", () => {
    const audit = auditWriting(
      "I designed multi-step agent workflows with browser use, local data, review loops, and explicit safety gates.",
      defaultStore.profile
    );

    expect(audit.ready).toBe(true);
    expect(audit.score).toBeGreaterThanOrEqual(85);
    expect(audit.unsupportedClaims).toEqual([]);
    expect(audit.evidenceReferences).toContain("Built agent workflows");
  });

  it("accepts evidence references through case-insensitive tags", () => {
    const audit = auditWriting("I built work around deepseek-v4-flash and opencode routing.", {
      ...defaultStore.profile,
      strengths: [
        {
          id: "fact-opencode",
          label: "OpenCode route",
          proof: "Configured the cheap model route through OpenCode Go.",
          tags: ["OpenCode"]
        }
      ]
    });

    expect(audit.flags.join(" ")).not.toContain("No saved evidence");
  });

  it("routes agent commands to compact tool hints", () => {
    const result = buildAgentCommand("Draft a cover letter and browser plan", defaultStore);

    expect(result.intent).toBe("apply");
    expect(result.toolHints).toContain("jobmaxxing_audit_text");
  });

  it("routes integration commands through the Hermes status tool", () => {
    const result = buildAgentCommand("Set up Hermes and connector tools", defaultStore);

    expect(result.intent).toBe("integrate");
    expect(result.toolHints).toContain("jobmaxxing_hermes_status");
  });

  it("routes slash goal commands as workflow goals", () => {
    const result = buildAgentCommand("/goal find 10 Zurich AI jobs", defaultStore);

    expect(result.intent).toBe("goal");
    expect(result.toolHints).toContain("jobmaxxing_automation_plan");
    expect(result.nextActions.join(" ")).toContain("sourcing");
  });

  it("builds WhatsApp-specific relationship intelligence and separates email formatting", () => {
    const profile = analyzeWhatsAppThread({
      threadId: "thread-1",
      displayName: "Maya",
      jid: "41790000000@s.whatsapp.net",
      companyName: "Northstar Climate Bank",
      personName: "Maya Patel",
      purpose: "I want to understand who owns AI workflow hiring.",
      messages: [
        { fromMe: true, text: "Hey Maya, quick question?" },
        { fromMe: false, text: "Sure, what is up?" },
        { fromMe: true, text: "Do you know who owns the AI workflow team?" },
        { fromMe: false, text: "The platform group is probably closest to that." }
      ]
    });

    expect(profile.allowedForAI).toBe(true);
    expect(profile.styleSummary).toContain("direct questions");
    expect(profile.directMessageFormat).toContain("short");
    expect(profile.suggestedDirectMessage).toContain("Hey Maya");
    expect(profile.suggestedEmailMessage).toContain("Subject:");
    expect(profile.suggestedEmailMessage).not.toBe(profile.suggestedDirectMessage);
  });

  it("routes market and source commands through intelligence tools", () => {
    const result = buildAgentCommand("Research competitors, job boards, and source playbooks", defaultStore);

    expect(result.intent).toBe("intelligence");
    expect(result.toolHints).toContain("jobmaxxing_market_research");
    expect(result.toolHints).toContain("jobmaxxing_automation_plan");
  });

  it("returns a researched market catalog with agent and deterministic steps", () => {
    const catalog = buildMarketIntelligence();

    expect(catalog.competitors.map((item) => item.id)).toEqual(
      expect.arrayContaining(["teal", "simplify", "huntr", "jobscan", "loopcv", "linkedin"])
    );
    expect(catalog.jobBoards.map((item) => item.id)).toEqual(
      expect.arrayContaining(["linkedin-jobs", "greenhouse", "lever", "workday"])
    );
    expect(catalog.playbooks.every((playbook) => playbook.deterministicSteps.length > 0)).toBe(true);
    expect(catalog.playbooks.every((playbook) => playbook.agentSteps.length > 0)).toBe(true);
    expect(catalog.complaints.map((item) => item.id)).toContain("bot-spray");
  });

  it("selects automation playbooks by id or goal", () => {
    expect(buildAutomationPlaybook({ playbookId: "resume-gap-map" }).title).toBe("Resume Gap Map");
    expect(buildAutomationPlaybook({ goal: "interview practice" }).id).toBe("interview-war-room");
    expect(buildAutomationPlaybook({ goal: "unknown" }).id).toBe("source-radar");
  });

  it("defines a focused Hermes layer without shadowing native Hermes slash commands", async () => {
    const raw = await readFile(new URL("../../hermes/jobmaxxing.hermes.json", import.meta.url), "utf8");
    const manifest = JSON.parse(raw) as {
      defaultModelRouteId: string;
      slashCommands?: Record<string, { command: string }>;
      requiredJobmaxxingTools: string[];
      recommendedHermesToolsets: Array<{ id: string }>;
      skills: Array<{ id: string }>;
    };

    expect(manifest.defaultModelRouteId).toBe("final-review");
    expect(manifest.slashCommands).toBeUndefined();
    expect(manifest.skills.map((skill) => skill.id)).toContain("jobmaxxing-orchestrator");
    expect(manifest.requiredJobmaxxingTools).toContain("jobmaxxing_hermes_status");
    expect(manifest.requiredJobmaxxingTools).toContain("jobmaxxing_market_research");
    expect(manifest.requiredJobmaxxingTools).toContain("jobmaxxing_automation_plan");
    expect(manifest.requiredJobmaxxingTools).toContain("jobmaxxing_company_profiles");
    expect(manifest.requiredJobmaxxingTools).toContain("jobmaxxing_company_research_packet");
    expect(manifest.recommendedHermesToolsets.map((toolset) => toolset.id)).toEqual(
      expect.arrayContaining(["subagents", "google-drive", "gmail", "github", "linear"])
    );
    expect(defaultStore.profile.modelTiers).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: "cheap-drafts",
          provider: "OpenCode",
          model: "deepseek-v4-flash",
          reasoningEffort: "low"
        }),
        expect.objectContaining({
          id: "standard-writing",
          provider: "OpenAI",
          model: "gpt-5.5",
          reasoningEffort: "medium"
        }),
        expect.objectContaining({
          id: "final-review",
          provider: "OpenAI",
          model: "gpt-5.5",
          reasoningEffort: "high"
        })
      ])
    );
  });

  it("exports the Hermes registry for the native composer instead of relying on a stale static list", async () => {
    const tempDir = await mkdtemp(join(tmpdir(), "jm-hermes-registry-"));
    const hermesDir = join(tempDir, "hermes-agent");
    const cliDir = join(hermesDir, "hermes_cli");
    await mkdir(cliDir, { recursive: true });
    await writeFile(
      join(cliDir, "commands.py"),
      [
        "from dataclasses import dataclass",
        "@dataclass(frozen=True)",
        "class CommandDef:",
        "    name: str",
        "    description: str",
        "    category: str",
        "    aliases: tuple[str, ...] = ()",
        "    args_hint: str = ''",
        "    subcommands: tuple[str, ...] = ()",
        "    cli_only: bool = False",
        "    gateway_only: bool = False",
        "    gateway_config_gate: str | None = None",
        "COMMAND_REGISTRY: list[CommandDef] = [",
        "    CommandDef('codex-runtime', 'Toggle codex app-server runtime', 'Configuration', aliases=('codex_runtime',), args_hint='[auto|codex_app_server]'),",
        "    CommandDef('timestamps', 'Toggle timestamps', 'Configuration', aliases=('ts',), subcommands=('on', 'off', 'status'), cli_only=True),",
        "    CommandDef('memory', 'Manage memory sources', 'Tools & Skills'),",
        "    CommandDef('bundles', 'Manage bundles', 'Tools & Skills'),",
        "    CommandDef('pet', 'Open pet status', 'Tools & Skills'),",
        "    CommandDef('hatch', 'Hatch a pet', 'Tools & Skills'),",
        "    CommandDef('learn', 'Save a learning', 'Tools & Skills'),",
        "    CommandDef('suggestions', 'Review suggestions', 'Tools & Skills'),",
        "    CommandDef('blueprint', 'Open the blueprint', 'Tools & Skills'),",
        "    CommandDef('credits', 'Show credits', 'Info'),",
        "    CommandDef('billing', 'Show billing', 'Info'),",
        "    CommandDef('version', 'Show version', 'Info'),",
        "]",
        ""
      ].join("\n")
    );
    const outputPath = join(tempDir, "commands.json");
    try {
      await execFileAsync("python3", [
        "scripts/export_hermes_commands.py",
        "--hermes-path",
        hermesDir,
        "--output",
        outputPath
      ]);
      const exported = JSON.parse(await readFile(outputPath, "utf8")) as {
        commands: Array<{ id: string; aliases?: string[]; argsHint?: string; cliOnly?: boolean; subcommands?: string[] }>;
      };
      const exportedIDs = exported.commands.map((command) => command.id);
      expect(exportedIDs).toEqual([
        "codex-runtime",
        "timestamps",
        "memory",
        "bundles",
        "pet",
        "hatch",
        "learn",
        "suggestions",
        "blueprint",
        "credits",
        "billing",
        "version"
      ]);
      expect(exported.commands.find((command) => command.id === "codex-runtime")).toMatchObject({
        aliases: ["codex_runtime"],
        argsHint: "[auto|codex_app_server]"
      });
      expect(exported.commands.find((command) => command.id === "timestamps")).toMatchObject({
        cliOnly: true,
        subcommands: ["on", "off", "status"]
      });
    } finally {
      await rm(tempDir, { recursive: true, force: true });
    }

    const swiftCatalog = await readFile(
      new URL("../../macos/Sources/Jobmaxxing/Services/HermesNativeCommandCatalog.swift", import.meta.url),
      "utf8"
    );
    expect(swiftCatalog).toContain("JOBMAXXING_HERMES_COMMANDS");
    expect(swiftCatalog).toContain("hermes-commands.json");
    expect(swiftCatalog).toContain("fallbackCommands");
    expect(swiftCatalog).toContain("return resolve(normalized) ?? normalized");
  });

  it("keeps the installed Hermes command export aligned with the current upstream registry", async () => {
    const hermesDir = join(process.env.HOME ?? "", ".hermes", "hermes-agent");
    const installedCatalog = join(process.env.HOME ?? "", ".jobmaxxing", "hermes-layer", "hermes-commands.json");
    if (!existsSync(join(hermesDir, "hermes_cli", "commands.py")) || !existsSync(installedCatalog)) {
      return;
    }

    const tempDir = await mkdtemp(join(tmpdir(), "jm-hermes-live-registry-"));
    const outputPath = join(tempDir, "commands.json");
    try {
      await execFileAsync("python3", [
        "scripts/export_hermes_commands.py",
        "--hermes-path",
        hermesDir,
        "--output",
        outputPath
      ]);
      const current = JSON.parse(await readFile(outputPath, "utf8")) as {
        commands: Array<{ id: string; aliases?: string[]; gatewayOnly?: boolean; cliOnly?: boolean }>;
      };
      const installed = JSON.parse(await readFile(installedCatalog, "utf8")) as {
        commands: Array<{ id: string; aliases?: string[]; gatewayOnly?: boolean; cliOnly?: boolean }>;
      };

      expect(installed.commands.map((command) => command.id)).toEqual(current.commands.map((command) => command.id));
      expect(installed.commands.find((command) => command.id === "version")).toBeDefined();
      expect(installed.commands.find((command) => command.id === "topic")).toMatchObject({ gatewayOnly: true });
      expect(installed.commands.find((command) => command.id === "codex-runtime")).toMatchObject({
        aliases: ["codex_runtime"]
      });
    } finally {
      await rm(tempDir, { recursive: true, force: true });
    }
  });

  it("runs Hermes slash update through the official updater before refreshing the Jobmaxxing layer", async () => {
    const updateScript = await readFile(new URL("../../scripts/hermes_update.sh", import.meta.url), "utf8");

    expect(updateScript).toContain('"$HERMES_BIN" update "$@"');
    expect(updateScript).toContain('"$ROOT_DIR/scripts/install_hermes_layer.sh" --install');
    expect(updateScript.indexOf('"$HERMES_BIN" update "$@"')).toBeLessThan(
      updateScript.indexOf('"$ROOT_DIR/scripts/install_hermes_layer.sh" --install')
    );
  });

  it("accepts provider-specific reasoning levels", () => {
    for (const reasoningEffort of ["none", "minimal", "low", "medium", "high", "xhigh", "max"] as const) {
      profileSchema.parse({
        ...defaultStore.profile,
        modelTiers: [
          {
            ...defaultStore.profile.modelTiers[0],
            reasoningEffort
          }
        ]
      });
    }
  });

  it("keeps Hermes tool loading selective instead of dumping every connector into context", async () => {
    const raw = await readFile(new URL("../../hermes/tools/jobmaxxing-toolset.json", import.meta.url), "utf8");
    const toolset = JSON.parse(raw) as {
      alwaysAvailable: string[];
      loadWhenNeeded: Record<string, string[]>;
      blockedByDefault: string[];
    };

    expect(toolset.alwaysAvailable).toContain("jobmaxxing_hermes_status");
    expect(toolset.loadWhenNeeded.intelligence).toEqual(
      expect.arrayContaining(["jobmaxxing_market_research", "jobmaxxing_automation_plan"])
    );
    expect(toolset.loadWhenNeeded.companies).toEqual(
      expect.arrayContaining(["jobmaxxing_company_profiles", "jobmaxxing_company_research_packet"])
    );
    expect(toolset.loadWhenNeeded.documents).toEqual(expect.arrayContaining(["google-drive", "gmail"]));
    expect(toolset.loadWhenNeeded.directMessages).toEqual(expect.arrayContaining(["whatsapp", "telegram"]));
    expect(toolset.loadWhenNeeded.orchestration).toEqual(["subagents"]);
    expect(toolset.blockedByDefault).toContain("external_submit");
  });

  it("keeps missing store reads pure and writes only on explicit save", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-test-"));
    const path = join(dir, "store.json");
    try {
      const missing = await readStore(path);
      expect(existsSync(path)).toBe(false);
      expect(missing.schema).toBe("jobmaxxing-store");

      const event = createEvent(storeWithSavedJob, {
        actor: "codex",
        approval: "proposed",
        jobId: savedJob.id,
        summary: "Prepared a draft pack.",
        type: "draft"
      });
      await writeStore({ ...storeWithSavedJob, events: [event] }, path);

      const next = await readStore(path);
      expect(next.events[0].sequence).toBe(1);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("rejects corrupt store JSON without replacing it", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-corrupt-"));
    const path = join(dir, "store.json");
    try {
      await writeFile(path, "{not json", "utf8");

      await expect(readStore(path)).rejects.toThrow("Could not read Jobmaxxing data");
      expect(await readFile(path, "utf8")).toBe("{not json");
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("serializes concurrent store updates", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-concurrent-"));
    const path = join(dir, "store.json");
    const previous = process.env.JOBMAXXING_DATA_PATH;
    process.env.JOBMAXXING_DATA_PATH = path;
    try {
      await writeStore(storeWithSavedJob, path);
      await Promise.all(
        ["alpha", "bravo", "charlie", "delta"].map((label) =>
          updateStore((store) => ({
            ...store,
            events: [
              {
                actor: "codex",
                approval: "not_needed",
                id: label,
                jobId: store.jobs[0].id,
                sequence: store.events.length + 1,
                summary: label,
                type: "tracking"
              },
              ...store.events
            ]
          }))
        )
      );

      const next = await readStore(path);
      expect(next.events.map((event) => event.summary).sort()).toEqual(["alpha", "bravo", "charlie", "delta"]);
    } finally {
      if (previous === undefined) {
        delete process.env.JOBMAXXING_DATA_PATH;
      } else {
        process.env.JOBMAXXING_DATA_PATH = previous;
      }
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("serializes concurrent store updates from separate processes", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-process-concurrent-"));
    const path = join(dir, "store.json");
    try {
      await writeStore(storeWithSavedJob, path);
      const childScript = `
        import { updateStore } from "./src/lib/storage.ts";
        const label = process.argv.at(-1) ?? "unknown";
        async function main() {
          await updateStore((store) => ({
            ...store,
            events: [
              {
                actor: "codex",
                approval: "not_needed",
                id: label,
                jobId: store.jobs[0].id,
                sequence: store.events.length + 1,
                summary: label,
                type: "tracking"
              },
              ...store.events
            ]
          }));
        }
        main().catch((error) => {
          console.error(error);
          process.exit(1);
        });
      `;

      await Promise.all(
        ["echo", "foxtrot", "golf", "hotel"].map((label) =>
          execFileAsync("node_modules/.bin/tsx", ["-e", childScript, label], {
            cwd: process.cwd(),
            env: { ...process.env, JOBMAXXING_DATA_PATH: path }
          })
        )
      );

      const next = await readStore(path);
      expect(next.events.map((event) => event.summary).sort()).toEqual(["echo", "foxtrot", "golf", "hotel"]);
      expect(next.revision).toBe(defaultStore.revision + 4);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("rejects activity without a saved job", async () => {
    await expect(
      logActivityWorkflow({
        actor: "codex",
        approval: "not_needed",
        jobId: "",
        summary: "Detached activity should not be accepted.",
        type: "tracking"
      })
    ).rejects.toThrow("Job not found");
  });

  it("normalizes legacy stores before incrementing revisions", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-legacy-"));
    const path = join(dir, "store.json");
    const previous = process.env.JOBMAXXING_DATA_PATH;
    process.env.JOBMAXXING_DATA_PATH = path;
    try {
      const legacy = { ...defaultStore } as Partial<typeof defaultStore>;
      delete legacy.revision;
      delete legacy.hermes;
      delete legacy.connectors;
      await writeFile(path, `${JSON.stringify(legacy, null, 2)}\n`, "utf8");

      const normalized = await readStore(path);
      expect(normalized.revision).toBe(defaultStore.revision);
      expect(normalized.hermes.defaultModelTier).toBe("final-review");
      expect(normalized.connectors.map((connector) => connector.id)).toContain("hermes");

      const next = await updateStore((store) => ({ ...store }));
      expect(next.revision).toBe(defaultStore.revision + 1);
    } finally {
      if (previous === undefined) {
        delete process.env.JOBMAXXING_DATA_PATH;
      } else {
        process.env.JOBMAXXING_DATA_PATH = previous;
      }
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("preserves unknown connectors through normalization and saves", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-connectors-"));
    const path = join(dir, "store.json");
    const unknownConnector = {
      id: "future-connector",
      label: "Future Connector",
      provider: "Local",
      purpose: "Regression test connector.",
      enabled: true,
      connected: false
    };
    try {
      await writeStore(
        {
          ...defaultStore,
          connectors: [unknownConnector, ...defaultStore.connectors]
        },
        path
      );

      const normalized = await readStore(path);
      expect(normalized.connectors).toContainEqual(unknownConnector);

      const updated = await updateStore((store) => ({ ...store }), path);
      expect(updated.connectors).toContainEqual(unknownConnector);
      expect((await readStore(path)).connectors).toContainEqual(unknownConnector);
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

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

  it("keeps large status payloads compact instead of returning full store data", () => {
    const baseJob = createJobRecord(
      {
        company: "Payload Company",
        role: "Payload Role",
        description: "Build local-first job search workflows."
      },
      defaultStore.profile
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
      defaultStore.profile
    );
    const jobs = Array.from({ length: 600 }, (_, index) => ({
      ...baseJob,
      id: `large-job-${index}`,
      company: `Large Company ${index % 160}`,
      role: `Large Role ${index}`,
      description: `Build agents, documents, contacts, and application flows ${index}.`
    }));
    const companies = Array.from({ length: 160 }, (_, index) => ({
      id: `large-company-${index}`,
      name: `Large Company ${index}`,
      website: "https://example.com",
      linkedInUrl: "",
      category: "Target company",
      size: "Unknown",
      headquarters: "Unknown",
      publicStatus: "Unknown",
      summary: "Synthetic scale fixture.",
      relationship: "Application target",
      applicationIds: [],
      submittedMaterials: [],
      people: Array.from({ length: 3 }, (_, personIndex) => ({
        id: `large-person-${index}-${personIndex}`,
        name: `Person ${index}-${personIndex}`,
        title: "Hiring context",
        sourceUrl: `https://example.com/people/${index}-${personIndex}`,
        relationship: "Potential hiring context",
        notes: "Imported from company profile."
      })),
      research: {
        status: "Not researched",
        confidence: 0,
        websitePages: [],
        products: [],
        businessModel: "",
        leadership: [],
        hiringSignals: [],
        risks: [],
        openQuestions: [],
        sourceUrls: [],
        agentPlan: []
      },
      nextActions: [],
      notes: ""
    }));

    try {
      await writeStore({ ...storeWithSavedJob, jobs, companies }, path);
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

  it("rejects malformed profiles before saving", async () => {
    await expect(saveProfileWorkflow({} as never)).rejects.toThrow();
  });
});
