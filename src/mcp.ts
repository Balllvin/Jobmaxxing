#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as z from "zod/v4";
import {
  buildAgentCommand,
  buildBrowserPlan,
  auditWriting,
  buildWritingPrompt,
  buildCompanyResearchPrompt
} from "./lib/jobmaxxing";
import {
  browserPlanSchema,
  automationPlanSchema,
  companyIdSchema,
  commandSchema,
  eventSchema,
  interviewSchema,
  jobIdSchema,
  jobInputSchema,
  writingAuditSchema,
  writingPromptSchema
} from "./lib/contracts";
import { buildAutomationPlaybook, buildMarketIntelligence } from "./lib/intelligence";
import { buildMutationResult, buildStoreStatus, findJobOrThrow, readStore, readStoreStatus } from "./lib/storage";
import {
  addJobWorkflow,
  buildInterviewWorkflow,
  draftApplicationWorkflow,
  logActivityWorkflow,
  prepareCompanyResearchWorkflow
} from "./lib/workflows";

const server = new McpServer({
  name: "jobmaxxing",
  version: "complete"
});
const companyProfilesInputSchema = z.object({
  detail: z.enum(["summary", "full"]).optional()
});

server.registerTool(
  "jobmaxxing_status",
  {
    description: "Read compact local Jobmaxxing status, counts, top jobs, company summaries, and next recommended actions.",
    inputSchema: {}
  },
  async () => textResult(await readStoreStatus())
);

server.registerTool(
  "jobmaxxing_hermes_status",
  {
    description: "Read Hermes layer configuration, connector availability, required skills, and slash update command.",
    inputSchema: {}
  },
  async () => {
    const store = await readStore();
    const status = buildStoreStatus(store);
    return textResult({
      hermes: store.hermes,
      connectors: status.connectors,
      defaultHighRoute: store.profile.modelTiers.find((tier) => tier.id === store.hermes.defaultModelTier),
      requiredJobmaxxingTools: [
        "jobmaxxing_status",
        "jobmaxxing_add_job",
        "jobmaxxing_draft_application",
        "jobmaxxing_interview_pack",
        "jobmaxxing_market_research",
        "jobmaxxing_automation_plan",
        "jobmaxxing_company_profiles",
        "jobmaxxing_company_research_packet",
        "jobmaxxing_browser_plan",
        "jobmaxxing_log_activity",
        "jobmaxxing_audit_text",
        "jobmaxxing_style_prompt",
        "jobmaxxing_company_research_prompt",
        "jobmaxxing_command"
      ]
    });
  }
);

server.registerTool(
  "jobmaxxing_market_research",
  {
    description:
      "Return the Jobmaxxing intelligence catalog: competitor apps, job boards, user complaints, automation playbooks, and feature opportunities.",
    inputSchema: {}
  },
  async () => textResult(buildMarketIntelligence())
);

server.registerTool(
  "jobmaxxing_automation_plan",
  {
    description:
      "Return a deterministic-plus-agent playbook for a job-search workflow such as sourcing, ATS forms, resume gaps, outreach, interviews, or weekly retros.",
    inputSchema: automationPlanSchema.shape
  },
  async (input) => textResult(buildAutomationPlaybook(input))
);

server.registerTool(
  "jobmaxxing_add_job",
  {
    description:
      "Mutates local Jobmaxxing state: add a job to the application ledger, score it against the saved profile, attach an initial evidence-gated application pack, and sync the company profile.",
    inputSchema: jobInputSchema.shape
  },
  async (input) => {
    const store = await addJobWorkflow(input);
    return textResult(buildMutationResult(store, { job: store.jobs[0] }));
  }
);

server.registerTool(
  "jobmaxxing_draft_application",
  {
    description:
      "Mutates local Jobmaxxing state: regenerate the saved job's evidence-gated application pack, set the job to drafting, and add a proposed company submission record.",
    inputSchema: jobIdSchema.shape
  },
  async ({ jobId }) => {
    const store = await draftApplicationWorkflow(jobId);
    return textResult(buildMutationResult(store, { job: store.jobs.find((job) => job.id === jobId) }));
  }
);

server.registerTool(
  "jobmaxxing_interview_pack",
  {
    description: "Prepare a mock interview pack for text, call, onsite, or panel practice.",
    inputSchema: interviewSchema.shape
  },
  async ({ jobId, mode }) => {
    return textResult(await buildInterviewWorkflow(jobId, mode));
  }
);

server.registerTool(
  "jobmaxxing_browser_plan",
  {
    description:
      "Create a browser-use plan with consent gates. This never submits applications and blocks protected-site automation by default.",
    inputSchema: browserPlanSchema.shape
  },
  async ({ request, sourceUrl }) => {
    const store = await readStore();
    return textResult(buildBrowserPlan(store.profile, request, sourceUrl ?? ""));
  }
);

server.registerTool(
  "jobmaxxing_log_activity",
  {
    description:
      "Mutates local Jobmaxxing state: append an auditable event to the global ledger and the referenced saved job ledger.",
    inputSchema: eventSchema.shape
  },
  async (input) => {
    const store = await logActivityWorkflow(input);
    return textResult(buildMutationResult(store, { event: store.events[0] }));
  }
);

server.registerTool(
  "jobmaxxing_audit_text",
  {
    description: "Audit application text for Amazon-style clarity, AI slop, weak claims, and missing evidence.",
    inputSchema: writingAuditSchema.shape
  },
  async ({ text }) => {
    const store = await readStore();
    return textResult(auditWriting(text, store.profile));
  }
);

server.registerTool(
  "jobmaxxing_style_prompt",
  {
    description: "Return the current self-improving writing prompt with Amazon rules, anti-slop rules, and user voice memory.",
    inputSchema: writingPromptSchema.shape
  },
  async ({ draft }) => {
    const store = await readStore();
    return textResult({ prompt: buildWritingPrompt(store.profile, draft ?? "") });
  }
);

server.registerTool(
  "jobmaxxing_company_profiles",
  {
    description:
      "Read compact company profile summaries by default. Pass detail=full only when application history, people maps, sources, and research details are needed.",
    inputSchema: companyProfilesInputSchema.shape
  },
  async ({ detail }) => {
    const store = await readStore();
    return textResult(detail === "full" ? store.companies : buildStoreStatus(store).companies);
  }
);

server.registerTool(
  "jobmaxxing_company_research_packet",
  {
    description:
      "Mutates local Jobmaxxing state: prepare and save an agent-ready company research packet with public/private source-review tasks and people-mapping safety gates.",
    inputSchema: companyIdSchema.shape
  },
  async ({ companyId }) => textResult(await prepareCompanyResearchWorkflow(companyId))
);

server.registerTool(
  "jobmaxxing_company_research_prompt",
  {
    description: "Return a fact-vs-assumption company research prompt for a saved job.",
    inputSchema: jobIdSchema.shape
  },
  async ({ jobId }) => {
    const store = await readStore();
    const job = findJobOrThrow(store, jobId);
    return textResult({ prompt: buildCompanyResearchPrompt(store.profile, job) });
  }
);

server.registerTool(
  "jobmaxxing_command",
  {
    description: "Route a natural-language job-search command into the right Jobmaxxing workflow.",
    inputSchema: commandSchema.shape
  },
  async ({ command }) => textResult(buildAgentCommand(command, await readStore()))
);

function textResult(value: unknown) {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify(value, null, 2)
      }
    ]
  };
}

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Jobmaxxing MCP server running on stdio.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
