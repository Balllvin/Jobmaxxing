#!/usr/bin/env node
import {
  buildAgentCommand,
  buildBrowserPlan
} from "./lib/jobmaxxing";
import { buildAutomationPlaybook, buildMarketIntelligence } from "./lib/intelligence";
import { readStore } from "./lib/storage";
import { addJobWorkflow, draftApplicationWorkflow } from "./lib/workflows";

const args = process.argv.slice(2);
const command = args[0] ?? "status";

try {
  if (command === "status") {
    print(await readStore());
  } else if (command === "add-job") {
    const store = await addJobWorkflow({
      company: readFlag("company"),
      role: readFlag("role"),
      description: readFlag("description"),
      sourceUrl: readOptionalFlag("source-url"),
      notes: readOptionalFlag("notes")
    });
    print(store.jobs[0]);
  } else if (command === "draft") {
    const jobId = readFlag("job");
    const store = await draftApplicationWorkflow(jobId);
    const job = store.jobs.find((item) => item.id === jobId);
    print(job?.documents ?? job);
  } else if (command === "browser-plan") {
    const store = await readStore();
    print(buildBrowserPlan(store.profile, readFlag("request"), readOptionalFlag("source-url")));
  } else if (command === "intelligence") {
    print(buildMarketIntelligence());
  } else if (command === "playbook") {
    print(buildAutomationPlaybook({ playbookId: readOptionalFlag("id"), goal: readOptionalFlag("goal") }));
  } else if (command === "command") {
    print(buildAgentCommand(readFlag("text"), await readStore()));
  } else {
    throw new Error(`Unknown command: ${command}`);
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}

function readFlag(name: string): string {
  const value = readOptionalFlag(name);
  if (!value) {
    throw new Error(`Missing --${name}.`);
  }
  return value;
}

function readOptionalFlag(name: string): string {
  const index = args.indexOf(`--${name}`);
  return index === -1 ? "" : args[index + 1] ?? "";
}

function print(value: unknown): void {
  console.log(JSON.stringify(value, null, 2));
}
