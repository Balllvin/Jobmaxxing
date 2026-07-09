import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { extname, join, resolve } from "node:path";
import * as z from "zod/v4";
import {
  buildAgentCommand,
  buildBrowserPlan,
  auditWriting,
  buildWritingPrompt
} from "./lib/jobmaxxing";
import {
  automationPlanSchema,
  browserPlanSchema,
  companyIdSchema,
  commandSchema,
  eventSchema,
  interviewSchema,
  jobIdSchema,
  jobInputSchema,
  learningSchema,
  patchJobSchema,
  profileSchema,
  writingAuditSchema,
  writingPromptSchema
} from "./lib/contracts";
import { buildAutomationPlaybook, buildMarketIntelligence } from "./lib/intelligence";
import { buildMutationResult, buildStoreStatus, readStore, readStoreStatus } from "./lib/storage";
import {
  addJobWorkflow,
  buildInterviewWorkflow,
  draftApplicationWorkflow,
  logActivityWorkflow,
  patchJobWorkflow,
  prepareCompanyResearchWorkflow,
  recordLearningWorkflow,
  saveProfileWorkflow
} from "./lib/workflows";
import type { JobmaxxingStore, MutationResult } from "./lib/types";

const port = Number(process.env.PORT ?? 4174);
const staticArgIndex = process.argv.indexOf("--static");
const staticRoot = staticArgIndex === -1 ? "" : resolve(process.argv[staticArgIndex + 1] ?? "dist");

const server = createServer(async (request, response) => {
  try {
    await route(request, response);
  } catch (error) {
    handleRouteError(request, response, error);
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Jobmaxxing API listening on http://127.0.0.1:${port}`);
});

async function route(request: IncomingMessage, response: ServerResponse): Promise<void> {
  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "127.0.0.1"}`);

  if (url.pathname === "/api/health") {
    sendJson(response, 200, { ok: true, service: "jobmaxxing" });
    return;
  }

  if (url.pathname === "/api/state" && request.method === "GET") {
    sendJson(response, 200, wantsFullStore(url) ? await readStore() : await readStoreStatus());
    return;
  }

  if (url.pathname === "/api/status" && request.method === "GET") {
    sendJson(response, 200, await readStoreStatus());
    return;
  }

  if (url.pathname === "/api/profile" && request.method === "PUT") {
    const body = await readBody(
      request,
      z.object({ profile: profileSchema })
    );
    const store = await saveProfileWorkflow(body.profile);
    sendMutation(response, url, store, { profile: store.profile });
    return;
  }

  if (url.pathname === "/api/jobs" && request.method === "POST") {
    const store = await addJobWorkflow(await readBody(request, jobInputSchema));
    sendMutation(response, url, store, { job: store.jobs[0] }, 201);
    return;
  }

  if (url.pathname.startsWith("/api/jobs/") && request.method === "PATCH") {
    const jobId = decodeURIComponent(url.pathname.replace("/api/jobs/", ""));
    const store = await patchJobWorkflow(jobId, await readBody(request, patchJobSchema));
    sendMutation(response, url, store, { job: store.jobs.find((job) => job.id === jobId) });
    return;
  }

  if (url.pathname === "/api/draft" && request.method === "POST") {
    const body = await readBody(request, jobIdSchema);
    const store = await draftApplicationWorkflow(body.jobId);
    sendMutation(response, url, store, { job: store.jobs.find((job) => job.id === body.jobId) });
    return;
  }

  if (url.pathname === "/api/interview" && request.method === "POST") {
    const body = await readBody(request, interviewSchema);
    sendJson(response, 200, await buildInterviewWorkflow(body.jobId, body.mode));
    return;
  }

  if (url.pathname === "/api/browser/plan" && request.method === "POST") {
    const store = await readStore();
    const body = await readBody(request, browserPlanSchema);
    sendJson(response, 200, buildBrowserPlan(store.profile, body.request, body.sourceUrl ?? ""));
    return;
  }

  if (url.pathname === "/api/agent/command" && request.method === "POST") {
    const store = await readStore();
    const body = await readBody(request, commandSchema);
    sendJson(response, 200, buildAgentCommand(body.command, store));
    return;
  }

  if (url.pathname === "/api/intelligence" && request.method === "GET") {
    sendJson(response, 200, buildMarketIntelligence());
    return;
  }

  if (url.pathname === "/api/intelligence/playbook" && request.method === "POST") {
    sendJson(response, 200, buildAutomationPlaybook(await readBody(request, automationPlanSchema)));
    return;
  }

  if (url.pathname === "/api/companies" && request.method === "GET") {
    const store = await readStore();
    sendJson(response, 200, url.searchParams.get("detail") === "full" ? store.companies : buildStoreStatus(store).companies);
    return;
  }

  if (url.pathname === "/api/companies/research" && request.method === "POST") {
    const body = await readBody(request, companyIdSchema);
    sendJson(response, 200, await prepareCompanyResearchWorkflow(body.companyId));
    return;
  }

  if (url.pathname === "/api/learning" && request.method === "POST") {
    const body = await readBody(request, learningSchema);
    const store = await recordLearningWorkflow(body.note, body.rating);
    sendMutation(response, url, store, { profile: store.profile });
    return;
  }

  if (url.pathname === "/api/writing/audit" && request.method === "POST") {
    const store = await readStore();
    const body = await readBody(request, writingAuditSchema);
    sendJson(response, 200, auditWriting(body.text, store.profile));
    return;
  }

  if (url.pathname === "/api/writing/prompt" && request.method === "POST") {
    const store = await readStore();
    const body = await readBody(request, writingPromptSchema);
    sendJson(response, 200, { prompt: buildWritingPrompt(store.profile, body.draft ?? "") });
    return;
  }

  if (url.pathname === "/api/events" && request.method === "POST") {
    const body = await readBody(request, eventSchema);
    const store = await logActivityWorkflow(body);
    sendMutation(response, url, store, { event: store.events[0] }, 201);
    return;
  }

  if (url.pathname === "/api/export" && request.method === "GET") {
    sendJson(response, 200, await readStore());
    return;
  }

  if (url.pathname === "/api/config/status" && request.method === "GET") {
    const store = await readStore();
    sendJson(
      response,
      200,
      store.profile.modelTiers.map((tier) => ({
        id: tier.id,
        envVar: tier.envVar,
        configured: Boolean(process.env[tier.envVar])
      }))
    );
    return;
  }

  if (staticRoot) {
    await serveStatic(url.pathname, response);
    return;
  }

  sendJson(response, 404, { error: `No route for ${request.method ?? "GET"} ${url.pathname}` });
}

async function readJson(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    size += buffer.byteLength;
    if (size > 1_000_000) {
      throw new HttpError(413, "Request body is too large.");
    }
    chunks.push(buffer);
  }
  if (chunks.length === 0) {
    return {};
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8")) as unknown;
  } catch (error) {
    throw new HttpError(400, `Malformed JSON body: ${toErrorMessage(error)}`);
  }
}

async function readBody<T extends z.ZodType>(request: IncomingMessage, schema: T): Promise<z.infer<T>> {
  const parsed = schema.safeParse(await readJson(request));
  if (!parsed.success) {
    const message = parsed.error.issues
      .map((issue) => `${issue.path.join(".") || "body"}: ${issue.message}`)
      .join("; ");
    throw new HttpError(400, message);
  }
  return parsed.data;
}

function sendJson(response: ServerResponse, status: number, body: unknown): void {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store"
  });
  response.end(`${JSON.stringify(body, null, 2)}\n`);
}

function sendMutation(
  response: ServerResponse,
  url: URL,
  store: JobmaxxingStore,
  detail: Omit<MutationResult, "ok" | "revision" | "status" | "store">,
  status = 200
): void {
  sendJson(response, status, wantsFullStore(url) ? store : buildMutationResult(store, detail));
}

function wantsFullStore(url: URL): boolean {
  return url.searchParams.get("include") === "store" || url.searchParams.get("full") === "1";
}

async function serveStatic(pathname: string, response: ServerResponse): Promise<void> {
  const safePath = pathname === "/" ? "/index.html" : pathname;
  const filePath = resolve(join(staticRoot, safePath));
  const isAsset = extname(filePath) !== "";
  if (!filePath.startsWith(staticRoot)) {
    sendJson(response, 403, { error: "Static path is outside the configured root." });
    return;
  }
  try {
    const info = await stat(filePath);
    if (!info.isFile()) {
      throw new Error("Not a file.");
    }
    pipeFile(response, filePath, contentType(filePath));
  } catch (error) {
    if (isMissingFile(error) && !isAsset) {
      pipeFile(response, join(staticRoot, "index.html"), "text/html; charset=utf-8");
      return;
    }
    sendJson(response, isMissingFile(error) ? 404 : 500, {
      error: isMissingFile(error) ? "Static file not found." : "Could not serve static file."
    });
  }
}

function pipeFile(response: ServerResponse, filePath: string, type: string): void {
  const stream = createReadStream(filePath);
  stream.on("error", (error) => {
    console.error(`Static stream failed for ${filePath}: ${toErrorMessage(error)}`);
    if (!response.headersSent) {
      sendJson(response, 500, { error: "Could not stream static file." });
    } else {
      response.destroy(error);
    }
  });
  response.writeHead(200, { "content-type": type });
  stream.pipe(response);
}

function contentType(filePath: string): string {
  switch (extname(filePath)) {
    case ".css":
      return "text/css; charset=utf-8";
    case ".js":
      return "application/javascript; charset=utf-8";
    case ".svg":
      return "image/svg+xml";
    case ".json":
      return "application/json; charset=utf-8";
    default:
      return "text/html; charset=utf-8";
  }
}

function handleRouteError(request: IncomingMessage, response: ServerResponse, error: unknown): void {
  if (error instanceof HttpError) {
    sendJson(response, error.status, { error: error.message });
    return;
  }
  if (error instanceof Error && (error.message.startsWith("Job not found:") || error.message.startsWith("Cannot attach event"))) {
    sendJson(response, 404, { error: error.message });
    return;
  }
  const path = request.url ?? "/";
  console.error(`Unexpected ${request.method ?? "GET"} ${path} failure: ${toErrorMessage(error)}`, error);
  sendJson(response, 500, {
    error: `Unexpected server error while handling ${request.method ?? "GET"} ${path}. Check the server logs.`
  });
}

function isMissingFile(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error && error.code === "ENOENT";
}

function toErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string
  ) {
    super(message);
  }
}
