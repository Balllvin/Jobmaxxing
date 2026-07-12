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
import { readStore, updateStore, writeStore } from "../lib/storage";
import { logActivityWorkflow, saveProfileWorkflow } from "../lib/workflows";
import { profileSchema } from "../lib/contracts";
import { normalizeCompanies } from "../lib/companies";

const execFileAsync = promisify(execFile);
const testProfile = {
  ...defaultStore.profile,
  name: "Morgan Ellis",
  targetRoles: ["AI Product Engineer", "Workflow Engineer"],
  locations: ["Zurich", "Remote"],
  compensationGoal: "A product role with clear ownership and room to build.",
  workAuthorization: "Eligible to work in Switzerland.",
  strengths: [
    {
      id: "fact-agent-systems",
      label: "Built agent workflows",
      proof: "Designed multi-step agent workflows with browser use, local data, review loops, and explicit safety gates.",
      tags: ["agents", "automation", "workflow", "browser", "review"]
    },
    {
      id: "fact-product-delivery",
      label: "Shipped workflow software",
      proof: "Built a TypeScript operations workspace with tested intake, review, and approval flows.",
      tags: ["product", "typescript", "testing", "operations"]
    },
    {
      id: "fact-finance-operations",
      label: "Worked with finance operations",
      proof: "Built decision dashboards over financial records and operational ledgers.",
      tags: ["finance", "operations", "data", "dashboards"]
    }
  ],
  experience: [
    {
      id: "exp-workflow-engineer",
      title: "Product Engineer",
      organization: "Cedar Systems",
      location: "Zurich",
      period: "Recent role",
      summary: "Built agent-assisted operations software for research and review teams.",
      bullets: [
        "Shipped TypeScript workflows with human approval gates.",
        "Added regression tests for intake and document review."
      ],
      projects: [
        {
          id: "proj-review-router",
          name: "Review router",
          summary: "Routed research requests through evidence lookup and approval.",
          detail: "Designed an inspectable workflow from request intake through evidence review and final approval.",
          specificSample:
            "A saved request moved through source lookup, draft generation, and a user approval gate before any external action.",
          tools: ["TypeScript", "local storage", "browser tools"],
          metrics: ["Covered each state transition with regression tests"],
          tags: ["agents", "workflow", "review"],
          sourceUrl: "https://example.com/work/review-router"
        }
      ],
      sourceUrl: "https://example.com/work"
    }
  ],
  dealBreakers: ["No product ownership"],
  styleGuide: ["Use plain language and concrete evidence."],
  promptMemory: ["Prefer one detailed project sample over a list of shallow claims."]
} satisfies typeof defaultStore.profile;

const savedJob = createJobRecord(
  {
    company: "Northstar Climate Bank",
    role: "AI Product Engineer",
    description: "Own agent workflows, dashboards, finance data, testing, and operational automation."
  },
  testProfile
);
const storeWithSavedJob = {
  ...defaultStore,
  profile: testProfile,
  jobs: [savedJob]
};

describe("jobmaxxing core", () => {
  it("starts with an empty candidate story and no private identity or path", () => {
    expect(defaultStore.profile).toMatchObject({
      name: "",
      targetRoles: [],
      locations: [],
      compensationGoal: "",
      workAuthorization: "",
      strengths: [],
      experience: [],
      dealBreakers: [],
      styleGuide: [],
      promptMemory: []
    });
    expect(defaultStore.profile.permissions.hermesAgentPath).toBe("");
    expect(defaultStore.hermes.agentPath).toBe("");
    expect(JSON.stringify(defaultStore)).not.toMatch(/\/(Users|home)\//);
  });

  it("starts without inferred companies or applications", () => {
    expect(defaultStore.jobs).toEqual([]);
    expect(defaultStore.companies).toEqual([]);
  });

  it("keeps saved profiles strict while allowing an empty unsaved bootstrap", () => {
    expect(() => profileSchema.parse(defaultStore.profile)).toThrow();
    expect(profileSchema.parse(testProfile).name).toBe(testProfile.name);
  });

  it("preserves an explicit empty company list even when jobs exist", () => {
    expect(normalizeCompanies({ companies: [], jobs: [savedJob] })).toEqual([]);
  });

  it("scores evidence-backed agent roles higher than unrelated roles", () => {
    const agentRole = scoreJob(testProfile, {
      role: "Agent Workflow Engineer",
      description: "Build browser automation, agent review loops, TypeScript workflows, and approval surfaces."
    });
    const unrelatedRole = scoreJob(testProfile, {
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
      testProfile
    );

    const pack = buildApplicationPack(testProfile, job);

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
      testProfile
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
        testProfile
      )
    ).toThrow("Unsupported URL scheme");
  });

  it("normalizes generic display drift without rewriting profile provenance", async () => {
    const dir = await mkdtemp(join(tmpdir(), "jobmaxxing-normalize-"));
    const path = join(dir, "store.json");
    const sourceProof = "Contracted as a research assistant at Cedar Systems to support reporting.";
    const sourceMemory = "Source file: candidate-record.pdf";
    const rawPack = buildApplicationPack(testProfile, savedJob);
    const driftedJob = {
      ...savedJob,
      id: "job-language-drift",
      company: "Aster Rail",
      role: "Intern Applied AI &amp; AI-Platform",
      keywords: ["AIML", "agent-based workflows"],
      documents: {
        ...rawPack,
        resumeHeadline: "Intern Applied AI &amp; AI-Platform candidate",
        recruiterMessage: "Hi, I found the Data / ML / AI Intern role.",
        followUpMessage: "Following up on Finance &amp; Engineering.",
        coverLetter: "Sehr geehrte Frau Malcolm,\n\nIch bewerbe mich für das Trainee-Programm Finance trifft auf Engineering."
      }
    };
    const driftedContact = {
      id: "marisol-live",
      name: "Marisol",
      role: "Operations hiring contact",
      jobDescription: "",
      linkedInUrl: "https://example.com/people/marisol-vega",
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
          id: "marisol-aster",
          companyId: "aster-rail",
          companyName: "Aster Rail",
          role: "Operations hiring contact",
          relationship: "Hiring contact",
          notes: "",
          sourceUrl: ""
        }
      ],
      research: {
        status: "Enhanced",
        summary: "A public source identifies this contact as Marisol Vega.",
        publicFacts: ["A public source identifies this contact as Marisol Vega."],
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
            ...testProfile,
            strengths: [
              {
                id: "fact-contract",
                label: "Reporting contract",
                proof: sourceProof,
                tags: ["Research Assistant"]
              }
            ],
            promptMemory: [sourceMemory]
          },
          contacts: [driftedContact]
        },
        path
      );

      const normalized = await readStore(path);
      const job = normalized.jobs[0];

      expect(normalizeUserFacingText("AIML - Machine Learning Research Engineer")).toBe("Machine Learning Research Engineer");
      expect(job.role).toBe("Applied AI and AI Platform Intern");
      expect(job.keywords).toContain("AI and ML");
      expect(job.documents?.resumeHeadline).toBe("Applied AI and AI Platform Intern candidate");
      expect(job.documents?.recruiterMessage).toContain("Data, ML, and AI Intern");
      expect(job.documents?.followUpMessage).toContain("Finance & Engineering");
      expect(job.documents?.coverLetter).toContain("Sehr geehrte Frau Malcolm");
      expect(normalized.contacts?.[0].name).toBe("Marisol");
      expect(normalized.profile.strengths[0].proof).toBe(sourceProof);
      expect(normalized.profile.strengths[0].tags).toEqual(["Research Assistant"]);
      expect(normalized.profile.promptMemory).toEqual([sourceMemory]);
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
      testProfile
    );

    const pack = buildApplicationPack(testProfile, job);

    expect(pack.resumeBullets).toEqual([]);
    expect(pack.claimTrace).toEqual([]);
    expect(pack.missingEvidence.join(" ")).toContain("No saved evidence");
    expect(pack.coverLetter).toContain("needs matching evidence");
    expect(pack.recruiterMessage).not.toContain("agent workflows");
  });

  it("blocks protected-site browser automation by default", () => {
    const plan = buildBrowserPlan(
      testProfile,
      "Apply to this role",
      "https://www.linkedin.com/jobs/view/example"
    );

    expect(plan.mode).toBe("manual_only");
    expect(plan.risk).toBe("high");
    expect(plan.blocked.join(" ")).toContain("No LinkedIn");
  });

  it("builds mock interview packs for saved jobs", () => {
    const pack = buildInterviewPack(testProfile, savedJob, "call");

    expect(pack.mode).toBe("call");
    expect(pack.warmup.length).toBeGreaterThan(1);
    expect(pack.scorecard.join(" ")).toContain("Truthfulness");
  });

  it("audits AI slop and emits a rewrite prompt", () => {
    const audit = auditWriting(
      "I am excited to apply because your innovative company is changing the landscape with cutting-edge AI.",
      testProfile
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
      testProfile
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
      testProfile
    );
    const pack = buildApplicationPack(testProfile, job);
    expect(testProfile.experience.length).toBeGreaterThan(0);
    expect(pack.coverLetter).toMatch(/For example,/);
    expect(pack.coverLetter).toContain("My CV is attached");
    expect(pack.coverLetter.split("\n\n").length).toBeGreaterThanOrEqual(3);
  });

  it("identifies unsupported candidate claims instead of passing weak drafts", () => {
    const audit = auditWriting(
      "I have shipped global payment systems and I am a strong fit for this high-scale payments role.",
      testProfile
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
      testProfile
    );

    expect(audit.ready).toBe(true);
    expect(audit.score).toBeGreaterThanOrEqual(85);
    expect(audit.unsupportedClaims).toEqual([]);
    expect(audit.evidenceReferences).toContain("Built agent workflows");
  });

  it("accepts evidence references through case-insensitive tags", () => {
    const audit = auditWriting("I built work around deepseek-v4-flash and opencode routing.", {
      ...testProfile,
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
      senderName: testProfile.name,
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
    expect(profile.suggestedEmailMessage).toContain(testProfile.name);
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
        ...testProfile,
        modelTiers: [
          {
            ...testProfile.modelTiers[0],
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
      const legacyProfile = { ...defaultStore.profile } as Partial<(typeof defaultStore)["profile"]>;
      delete legacy.revision;
      delete legacy.hermes;
      delete legacy.connectors;
      delete legacy.companies;
      delete legacyProfile.name;
      delete legacyProfile.targetRoles;
      delete legacyProfile.locations;
      delete legacyProfile.compensationGoal;
      delete legacyProfile.workAuthorization;
      delete legacyProfile.strengths;
      delete legacyProfile.experience;
      delete legacyProfile.dealBreakers;
      delete legacyProfile.styleGuide;
      delete legacyProfile.promptMemory;
      legacy.profile = legacyProfile as (typeof defaultStore)["profile"];
      await writeFile(path, `${JSON.stringify(legacy, null, 2)}\n`, "utf8");

      const normalized = await readStore(path);
      expect(normalized.revision).toBe(defaultStore.revision);
      expect(normalized.hermes.defaultModelTier).toBe("final-review");
      expect(normalized.connectors.map((connector) => connector.id)).toContain("hermes");
      expect(normalized.companies).toEqual([]);
      expect(normalized.profile).toMatchObject({
        name: "",
        targetRoles: [],
        locations: [],
        strengths: [],
        experience: [],
        promptMemory: []
      });

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

  it("rejects malformed profiles before saving", async () => {
    await expect(saveProfileWorkflow({} as never)).rejects.toThrow();
  });
});
