import { spawn } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const tempDir = await mkdtemp(join(tmpdir(), "jobmaxxing-smoke-"));
const dataPath = join(tempDir, "store.json");
const child = spawn("npx", ["tsx", "src/server.ts"], {
  cwd: process.cwd(),
  env: {
    ...process.env,
    PORT: "4194",
    JOBMAXXING_DATA_PATH: dataPath
  },
  stdio: ["ignore", "pipe", "pipe"]
});
let childOutput = "";
let lastConnectionError = "";

child.stdout?.on("data", (chunk: Buffer) => {
  childOutput += chunk.toString("utf8");
});

child.stderr?.on("data", (chunk: Buffer) => {
  childOutput += chunk.toString("utf8");
});

try {
  await waitForServer();
  const health = await getJson<{ ok: boolean }>("http://127.0.0.1:4194/api/health");
  const created = await postJson<{ ok: boolean; job: { id: string }; status: { counts: { jobs: number } } }>("http://127.0.0.1:4194/api/jobs", {
    company: "Smoke Test Systems",
    role: "AI Workflow Engineer",
    description: "Build agent workflows, application materials, and interview preparation with user approval."
  });
  const state = await getJson<{ counts: { jobs: number }; jobs: unknown[] }>("http://127.0.0.1:4194/api/state");
  const command = await postJson<{ intent: string }>("http://127.0.0.1:4194/api/agent/command", {
    command: "Prepare my next application"
  });
  const intelligence = await getJson<{ competitors: unknown[]; playbooks: unknown[] }>(
    "http://127.0.0.1:4194/api/intelligence"
  );
  const companies = await getJson<Array<{ id: string }>>("http://127.0.0.1:4194/api/companies");
  const research = await postJson<{ research: { status: string } }>("http://127.0.0.1:4194/api/companies/research", {
    companyId: companies[0]?.id
  });
  const playbook = await postJson<{ id: string }>("http://127.0.0.1:4194/api/intelligence/playbook", {
    goal: "interview"
  });
  const audit = await postJson<{ score: number }>("http://127.0.0.1:4194/api/writing/audit", {
    text: "I am thrilled to join your innovative team and elevate the hiring landscape."
  });

  assert(Boolean(health.ok), "health failed");
  assert(created.ok && Boolean(created.job.id) && created.status.counts.jobs === 1, "job creation failed");
  assert(state.counts.jobs > 0 && Array.isArray(state.jobs), "state status missing jobs");
  assert(command.intent === "apply", "command routing failed");
  assert(intelligence.competitors.length > 5, "intelligence catalog failed");
  assert(companies.length > 0, "company profiles failed");
  assert(research.research.status === "Agent research packet ready", "company research packet failed");
  assert(playbook.id === "interview-war-room", "playbook routing failed");
  assert(audit.score < 100, "writing audit failed");
  console.log("Smoke checks passed.");
} finally {
  child.kill();
  await rm(tempDir, { recursive: true, force: true });
}

async function waitForServer(): Promise<void> {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    if (child.exitCode !== null) {
      throw new Error(`Server exited early with code ${child.exitCode}.\n${childOutput}`);
    }
    try {
      await getJson("http://127.0.0.1:4194/api/health");
      return;
    } catch (error) {
      lastConnectionError = error instanceof Error ? error.message : String(error);
      await new Promise((resolve) => setTimeout(resolve, 150));
    }
  }
  throw new Error(`Server did not become ready. Last error: ${lastConnectionError}\n${childOutput}`);
}

async function getJson<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}`);
  }
  return (await response.json()) as T;
}

async function postJson<T>(url: string, body: unknown): Promise<T> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}`);
  }
  return (await response.json()) as T;
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}
