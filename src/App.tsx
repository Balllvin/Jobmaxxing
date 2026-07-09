import {
  ArrowClockwise,
  Brain,
  Briefcase,
  CheckCircle,
  FileText,
  ListChecks,
  MagnifyingGlass,
  Plus,
  ShieldCheck,
  TerminalWindow,
  WarningCircle
} from "@phosphor-icons/react";
import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import type {
  AgentCommandResult,
  AgentEvent,
  ApplicationStage,
  BrowserPlan,
  InterviewMode,
  InterviewPack,
  JobRecord,
  JobmaxxingStore,
  WritingAudit
} from "./lib/types";
import { isSafeExternalUrl } from "./lib/urls";

type LoadState = "loading" | "ready" | "error";

const stages: ApplicationStage[] = [
  "saved",
  "researching",
  "drafting",
  "ready_to_apply",
  "applied",
  "interviewing",
  "offer",
  "closed"
];

const stageLabels: Record<ApplicationStage, string> = {
  saved: "Saved",
  researching: "Researching",
  drafting: "Drafting",
  ready_to_apply: "Ready",
  applied: "Applied",
  interviewing: "Interview",
  offer: "Offer",
  closed: "Closed"
};

const emptyJob = {
  company: "",
  role: "",
  sourceUrl: "",
  description: "",
  notes: ""
};

export default function App() {
  const [loadState, setLoadState] = useState<LoadState>("loading");
  const [store, setStore] = useState<JobmaxxingStore | null>(null);
  const [busy, setBusy] = useState("");
  const [selectedJobId, setSelectedJobId] = useState("");
  const [jobForm, setJobForm] = useState(emptyJob);
  const [actor, setActor] = useState<AgentEvent["actor"]>("codex");
  const [command, setCommand] = useState("Find the highest-leverage next action for my job search.");
  const [commandResult, setCommandResult] = useState<AgentCommandResult | null>(null);
  const [browserPlan, setBrowserPlan] = useState<BrowserPlan | null>(null);
  const [interviewPack, setInterviewPack] = useState<InterviewPack | null>(null);
  const [interviewAnswer, setInterviewAnswer] = useState("");
  const [writingText, setWritingText] = useState(
    "I am excited to apply because your innovative company is changing the landscape with cutting-edge AI."
  );
  const [writingAudit, setWritingAudit] = useState<WritingAudit | null>(null);
  const [learningNote, setLearningNote] = useState("Shorter contact messages work better when I know the recipient.");
  const [learningRating, setLearningRating] = useState(5);
  const [evidenceForm, setEvidenceForm] = useState({ label: "", proof: "", tags: "" });
  const [experienceForm, setExperienceForm] = useState({
    title: "",
    organization: "",
    location: "",
    period: "",
    summary: "",
    bullets: "",
    projectName: "",
    projectSummary: "",
    projectDetail: "",
    projectSample: "",
    projectTools: "",
    projectMetrics: "",
    projectTags: ""
  });
  const [configStatus, setConfigStatus] = useState<Array<{ id: string; envVar: string; configured: boolean }>>([]);
  const [error, setError] = useState("");

  useEffect(() => {
    void load();
  }, []);

  const selectedJob = useMemo(
    () => store?.jobs.find((job) => job.id === selectedJobId) ?? store?.jobs[0] ?? null,
    [selectedJobId, store]
  );

  const stats = useMemo(() => {
    const jobs = store?.jobs ?? [];
    return {
      total: jobs.length,
      ready: jobs.filter((job) => job.stage === "ready_to_apply").length,
      interviews: jobs.filter((job) => job.stage === "interviewing").length,
      average: jobs.length
        ? Math.round(jobs.reduce((sum, job) => sum + job.matchScore, 0) / jobs.length)
        : 0
    };
  }, [store]);

  async function load(): Promise<void> {
    try {
      setLoadState("loading");
      const [next, config] = await Promise.all([
        api<JobmaxxingStore>("/api/state?include=store"),
        api<Array<{ id: string; envVar: string; configured: boolean }>>("/api/config/status")
      ]);
      setStore(next);
      setConfigStatus(config);
      setSelectedJobId((current) => (next.jobs.some((job) => job.id === current) ? current : next.jobs[0]?.id ?? ""));
      setLoadState("ready");
      setError("");
    } catch (nextError) {
      setLoadState("error");
      setError(toMessage(nextError));
    }
  }

  async function runAction(label: string, action: () => Promise<void>): Promise<void> {
    try {
      setBusy(label);
      setError("");
      await action();
    } catch (nextError) {
      setError(`${label} failed: ${toMessage(nextError)}`);
    } finally {
      setBusy("");
    }
  }

  async function createJob(): Promise<void> {
    const next = await api<JobmaxxingStore>("/api/jobs?include=store", {
      method: "POST",
      body: JSON.stringify(jobForm)
    });
    setStore(next);
    setSelectedJobId(next.jobs[0]?.id ?? "");
    setJobForm(emptyJob);
  }

  async function updateStage(job: JobRecord, stage: ApplicationStage): Promise<void> {
    await patchJob(job, { stage });
  }

  async function updateNotes(job: JobRecord, notes: string): Promise<void> {
    await patchJob(job, { notes });
  }

  async function patchJob(job: JobRecord, body: Partial<Pick<JobRecord, "stage" | "notes" | "dateLabel" | "description">>): Promise<void> {
    const next = await api<JobmaxxingStore>(`/api/jobs/${encodeURIComponent(job.id)}?include=store`, {
      method: "PATCH",
      body: JSON.stringify(body)
    });
    setStore(next);
  }

  async function draft(job: JobRecord): Promise<void> {
    const next = await api<JobmaxxingStore>("/api/draft?include=store", {
      method: "POST",
      body: JSON.stringify({ jobId: job.id })
    });
    setStore(next);
  }

  async function runCommand(): Promise<void> {
    const result = await api<AgentCommandResult>("/api/agent/command", {
      method: "POST",
      body: JSON.stringify({ command })
    });
    setCommandResult(result);
  }

  async function planBrowser(job: JobRecord): Promise<void> {
    const result = await api<BrowserPlan>("/api/browser/plan", {
      method: "POST",
      body: JSON.stringify({
        request: `Prepare browser assist for ${job.company} ${job.role}`,
        sourceUrl: job.sourceUrl
      })
    });
    setBrowserPlan(result);
  }

  async function prepareInterview(job: JobRecord, mode: InterviewMode): Promise<void> {
    const result = await api<InterviewPack>("/api/interview", {
      method: "POST",
      body: JSON.stringify({ jobId: job.id, mode })
    });
    setInterviewPack(result);
  }

  async function recordLearning(): Promise<void> {
    await recordLearningWith(learningNote, learningRating);
  }

  async function recordLearningWith(note: string, rating: number): Promise<void> {
    const next = await api<JobmaxxingStore>("/api/learning?include=store", {
      method: "POST",
      body: JSON.stringify({ note, rating })
    });
    setStore(next);
  }

  async function auditText(): Promise<void> {
    const result = await api<WritingAudit>("/api/writing/audit", {
      method: "POST",
      body: JSON.stringify({ text: writingText })
    });
    setWritingAudit(result);
  }

  async function logEvent(input: Omit<AgentEvent, "id" | "sequence">): Promise<void> {
    const next = await api<JobmaxxingStore>("/api/events?include=store", {
      method: "POST",
      body: JSON.stringify(input)
    });
    setStore(next);
  }

  function selectedJobOrThrow(): JobRecord {
    if (!selectedJob) {
      throw new Error("Select a role before logging activity.");
    }
    return selectedJob;
  }

  async function saveEvidence(): Promise<void> {
    if (!store) {
      return;
    }
    const tags = evidenceForm.tags
      .split(",")
      .map((tag) => tag.trim())
      .filter(Boolean);
    const profile = {
      ...store.profile,
      experience: store.profile.experience ?? [],
      strengths: [
        {
          id: `fact-${evidenceForm.label.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
          label: evidenceForm.label,
          proof: evidenceForm.proof,
          tags
        },
        ...store.profile.strengths
      ]
    };
    const next = await api<JobmaxxingStore>("/api/profile?include=store", {
      method: "PUT",
      body: JSON.stringify({ profile })
    });
    setStore(next);
    setEvidenceForm({ label: "", proof: "", tags: "" });
  }

  async function saveExperience(): Promise<void> {
    if (!store) {
      return;
    }
    const organization = experienceForm.organization.trim();
    const title = experienceForm.title.trim();
    if (!organization || !title) {
      throw new Error("Organization and role title are required for experience writeups.");
    }
    const splitList = (value: string) =>
      value
        .split(/[,\n]/)
        .map((item) => item.trim())
        .filter(Boolean);
    const projectName = experienceForm.projectName.trim();
    const project =
      projectName.length > 0
        ? {
            id: `proj-${projectName.toLowerCase().replace(/[^a-z0-9]+/g, "-")}-${Date.now()}`,
            name: projectName,
            summary: experienceForm.projectSummary.trim(),
            detail: experienceForm.projectDetail.trim(),
            specificSample: experienceForm.projectSample.trim(),
            tools: splitList(experienceForm.projectTools),
            metrics: splitList(experienceForm.projectMetrics),
            tags: splitList(experienceForm.projectTags),
            sourceUrl: ""
          }
        : null;
    const existing = [...(store.profile.experience ?? [])];
    const matchIndex = existing.findIndex(
      (entry) =>
        entry.organization.toLowerCase() === organization.toLowerCase() &&
        entry.title.toLowerCase() === title.toLowerCase()
    );
    if (matchIndex >= 0) {
      const current = existing[matchIndex];
      existing[matchIndex] = {
        ...current,
        location: experienceForm.location.trim() || current.location,
        period: experienceForm.period.trim() || current.period,
        summary: experienceForm.summary.trim() || current.summary,
        bullets: splitList(experienceForm.bullets).length ? splitList(experienceForm.bullets) : current.bullets,
        projects: project ? [project, ...current.projects] : current.projects
      };
    } else {
      existing.unshift({
        id: `exp-${organization.toLowerCase().replace(/[^a-z0-9]+/g, "-")}-${Date.now()}`,
        title,
        organization,
        location: experienceForm.location.trim(),
        period: experienceForm.period.trim(),
        summary: experienceForm.summary.trim(),
        bullets: splitList(experienceForm.bullets),
        projects: project ? [project] : [],
        sourceUrl: ""
      });
    }
    const next = await api<JobmaxxingStore>("/api/profile?include=store", {
      method: "PUT",
      body: JSON.stringify({
        profile: {
          ...store.profile,
          experience: existing
        }
      })
    });
    setStore(next);
    setExperienceForm({
      title: "",
      organization: "",
      location: "",
      period: "",
      summary: "",
      bullets: "",
      projectName: "",
      projectSummary: "",
      projectDetail: "",
      projectSample: "",
      projectTools: "",
      projectMetrics: "",
      projectTags: ""
    });
  }

  async function savePreferredTier(tierId: string): Promise<void> {
    if (!store) {
      return;
    }
    const next = await api<JobmaxxingStore>("/api/profile?include=store", {
      method: "PUT",
      body: JSON.stringify({
        profile: {
          ...store.profile,
          preferredModelTier: tierId
        }
      })
    });
    setStore(next);
  }

  if (loadState === "loading") {
    return <LoadingShell />;
  }

  if (loadState === "error" || !store) {
    return (
      <main className="min-h-[100dvh] bg-[#f4f4f0] text-[#111111]">
        <section className="mx-auto flex min-h-[100dvh] max-w-[1400px] items-center px-4">
          <div className="w-full border border-[#111111] bg-[#f4f4f0] p-8">
            <WarningCircle size={32} weight="bold" />
            <h1 className="mt-4 text-4xl font-black uppercase">Jobmaxxing could not start</h1>
            <p className="mt-3 max-w-[65ch] text-sm leading-6 text-[#44403c]">{error}</p>
            <button className="mt-6 action-button" onClick={() => void load()}>
              <ArrowClockwise size={18} weight="bold" /> Retry
            </button>
          </div>
        </section>
      </main>
    );
  }

  const preferredTier =
    store.profile.modelTiers.find((tier) => tier.id === store.profile.preferredModelTier) ??
    store.profile.modelTiers[0];

  return (
    <main className="min-h-[100dvh] bg-[#f4f4f0] text-[#111111]">
      <div className="mx-auto max-w-[1400px] px-4 py-4 sm:px-6 lg:px-8">
        <header className="grid gap-px border border-[#111111] bg-[#111111] md:grid-cols-[1fr_0.9fr]">
          <section className="bg-[#f4f4f0] p-5 md:p-7">
            <div className="flex flex-wrap items-center gap-3 text-xs uppercase">
              <span className="inline-flex items-center gap-2 border border-[#111111] px-2 py-1">
                <ShieldCheck size={15} weight="bold" /> Consent-first
              </span>
              <span className="inline-flex items-center gap-2 border border-[#111111] px-2 py-1">
                <TerminalWindow size={15} weight="bold" /> MCP ready
              </span>
            </div>
            <h1 className="mt-5 max-w-4xl text-5xl font-black uppercase leading-none md:text-7xl">
              Jobmaxxing
            </h1>
            <p className="mt-4 max-w-[65ch] text-base leading-7 text-[#44403c]">
              One local cockpit for finding roles, tracking applications, drafting proof-backed
              materials, preparing interviews, and letting agents work without crossing consent lines.
            </p>
          </section>
          <section className="grid grid-cols-2 gap-px bg-[#111111] sm:grid-cols-4 md:grid-cols-2">
            <Metric label="Tracked" value={stats.total} />
            <Metric label="Ready" value={stats.ready} />
            <Metric label="Interview" value={stats.interviews} />
            <Metric label="Avg score" value={stats.average} />
          </section>
        </header>

        {error ? (
          <div className="mt-4 flex items-start gap-3 border border-[#9f2f2d] bg-[#fdebec] p-4 text-sm text-[#9f2f2d]">
            <WarningCircle size={19} weight="bold" />
            <p>{error}</p>
          </div>
        ) : null}
        {busy ? (
          <div className="mt-4 border border-[#111111] bg-[#edf3ec] p-3 text-sm text-[#346538]">
            Working: {busy}
          </div>
        ) : null}

        <section className="mt-4 grid gap-4 lg:grid-cols-[1.2fr_0.8fr]">
          <Panel title="Application Ledger" icon={<Briefcase size={20} weight="bold" />}>
            {store.jobs.length === 0 ? (
              <EmptyState title="No jobs saved" body="Paste a role on the right to start scoring." />
            ) : (
              <div className="divide-y divide-[#111111] border border-[#111111]">
                {store.jobs.map((job) => (
                  <button
                    key={job.id}
                    className={`grid w-full gap-3 p-4 text-left transition active:translate-y-px md:grid-cols-[1fr_140px_120px] ${
                      selectedJob?.id === job.id ? "bg-[#fbf3db]" : "bg-[#f4f4f0] hover:bg-[#ffffff]"
                    }`}
                    onClick={() => setSelectedJobId(job.id)}
                  >
                    <span>
                      <span className="block text-sm font-black uppercase">{job.role}</span>
                      <span className="mt-1 block text-sm text-[#44403c]">{job.company}</span>
                      <span className="mt-2 block text-xs text-[#44403c]">
                        Next: {job.nextActions[0] ?? "Pick next action."}
                      </span>
                    </span>
                    <span className="font-mono text-3xl font-black">{job.matchScore}</span>
                    <span className="grid gap-2 text-xs uppercase">
                      <span className="self-start border border-[#111111] px-2 py-1">{stageLabels[job.stage]}</span>
                      <span>{job.risks.length} risks</span>
                      <span>{job.ledger[0]?.summary ?? "No activity yet"}</span>
                    </span>
                  </button>
                ))}
              </div>
            )}
          </Panel>

          <Panel title="Job Intake" icon={<Plus size={20} weight="bold" />}>
            <div className="grid gap-3">
              <Field label="Company">
                <input
                  className="input"
                  value={jobForm.company}
                  onChange={(event) => setJobForm({ ...jobForm, company: event.target.value })}
                  placeholder="Kestrel Health Systems"
                />
              </Field>
              <Field label="Role">
                <input
                  className="input"
                  value={jobForm.role}
                  onChange={(event) => setJobForm({ ...jobForm, role: event.target.value })}
                  placeholder="AI Workflow Engineer"
                />
              </Field>
              <Field label="Source URL">
                <input
                  className="input"
                  value={jobForm.sourceUrl}
                  onChange={(event) => setJobForm({ ...jobForm, sourceUrl: event.target.value })}
                  placeholder="https://company.example/careers/role"
                />
              </Field>
              <Field label="Job Description">
                <textarea
                  className="input min-h-32 resize-y"
                  value={jobForm.description}
                  onChange={(event) => setJobForm({ ...jobForm, description: event.target.value })}
                  placeholder="Paste responsibilities, requirements, compensation, location, and application notes."
                />
              </Field>
              <button className="action-button" disabled={Boolean(busy)} onClick={() => void runAction("Create job", createJob)}>
                <Plus size={18} weight="bold" /> Score and save
              </button>
            </div>
          </Panel>
        </section>

        <section className="mt-4 grid gap-4 lg:grid-cols-[0.9fr_1.1fr]">
          <Panel title="Agent Command Center" icon={<Brain size={20} weight="bold" />}>
            <Field label="Actor">
              <select className="input" value={actor} onChange={(event) => setActor(event.target.value as AgentEvent["actor"])}>
                {["codex", "claude", "cursor", "opencode", "grok", "hermes", "user"].map((item) => (
                  <option key={item} value={item}>
                    {item}
                  </option>
                ))}
              </select>
            </Field>
            <Field label="Command">
              <textarea
                className="input min-h-24"
                value={command}
                onChange={(event) => setCommand(event.target.value)}
              />
            </Field>
            <button className="mt-3 action-button" disabled={Boolean(busy)} onClick={() => void runAction("Route command", runCommand)}>
              <TerminalWindow size={18} weight="bold" /> Route command
            </button>
            {commandResult ? (
              <div className="mt-4 space-y-3 text-sm">
                <StatusLine label="Intent" value={commandResult.intent} />
                <p className="leading-6 text-[#44403c]">{commandResult.summary}</p>
                <Checklist items={commandResult.nextActions} />
                <Checklist title="Safety gates" items={commandResult.safety} />
                <div className="flex flex-wrap gap-2">
                  {commandResult.toolHints.map((tool) => (
                    <span key={tool} className="border border-[#111111] bg-[#ffffff] px-2 py-1 font-mono text-xs">
                      {tool}
                    </span>
                  ))}
                </div>
                <button
                  className="secondary-button"
                  disabled={Boolean(busy) || !selectedJob}
                  onClick={() =>
                    void runAction("Log command", () => {
                      const job = selectedJobOrThrow();
                      return logEvent({
                        actor,
                        approval: "proposed",
                        jobId: job.id,
                        summary: commandResult.summary,
                        type: "tracking"
                      });
                    })
                  }
                >
                  <ListChecks size={18} weight="bold" /> Stage log entry
                </button>
              </div>
            ) : null}
          </Panel>

          <Panel title="Selected Role Dossier" icon={<FileText size={20} weight="bold" />}>
            {selectedJob ? (
              <RoleDossier
                job={selectedJob}
                onDraft={() => void runAction("Draft application", () => draft(selectedJob))}
                onBrowserPlan={() => void runAction("Build browser plan", () => planBrowser(selectedJob))}
                onInterview={(mode) => void runAction("Prepare interview", () => prepareInterview(selectedJob, mode))}
                onStage={(stage) => void runAction("Update stage", () => updateStage(selectedJob, stage))}
                onNotes={(notes) => void runAction("Save notes", () => updateNotes(selectedJob, notes))}
              />
            ) : (
              <EmptyState title="Select a role" body="The dossier appears after a role is saved or selected." />
            )}
          </Panel>
        </section>

        <section className="mt-4 grid gap-4 lg:grid-cols-2">
          <Panel title="Browser Safety Plan" icon={<ShieldCheck size={20} weight="bold" />}>
            {browserPlan ? (
              <div className="space-y-4 text-sm">
                <StatusLine label="Risk" value={browserPlan.risk} />
                <StatusLine label="Mode" value={browserPlan.mode} />
                <p className="border border-[#111111] bg-[#fbf3db] p-3 leading-6">{browserPlan.userCheckpoint}</p>
                <Checklist title="Browser steps" items={browserPlan.recommendedSteps} />
                <div className="grid gap-4 md:grid-cols-2">
                  <Checklist title="Allowed" items={browserPlan.allowed} />
                  <Checklist title="Blocked" items={browserPlan.blocked} />
                </div>
                <button
                  className="secondary-button"
                  disabled={Boolean(busy) || !selectedJob}
                  onClick={() =>
                    void runAction("Approve browser plan", () => {
                      const job = selectedJobOrThrow();
                      return logEvent({
                        actor,
                        approval: "approved_by_user",
                        jobId: job.id,
                        summary: "User approved the browser plan.",
                        type: "browser_plan"
                      });
                    })
                  }
                >
                  <ShieldCheck size={18} weight="bold" /> Log approval
                </button>
              </div>
            ) : (
              <EmptyState title="No browser plan yet" body="Generate one from a selected role before opening the destination." />
            )}
          </Panel>

          <Panel title="Mock Interview" icon={<ListChecks size={20} weight="bold" />}>
            {interviewPack ? (
              <div className="grid gap-4 text-sm">
                <StatusLine label="Mode" value={`${interviewPack.mode} for ${interviewPack.role} at ${interviewPack.company}`} />
                <div className="grid gap-4 md:grid-cols-2">
                  <Checklist title="Warmup" items={interviewPack.warmup} />
                  <Checklist title="Technical" items={interviewPack.technical} />
                  <Checklist title="Behavioral" items={interviewPack.behavioral} />
                  <Checklist title="Research tasks" items={interviewPack.researchTasks} />
                </div>
                <Checklist title="Scorecard" items={interviewPack.scorecard} />
                <Field label="Practice answer">
                  <textarea
                    className="input min-h-24"
                    value={interviewAnswer}
                    onChange={(event) => setInterviewAnswer(event.target.value)}
                    placeholder="Write an answer here, then save the feedback into learning memory."
                  />
                </Field>
                <button
                  className="secondary-button"
                  disabled={Boolean(busy)}
                  onClick={() => {
                    const note = `Interview practice feedback: ${interviewAnswer}`;
                    setLearningNote(note);
                    void runAction("Save interview feedback", () => recordLearningWith(note, learningRating));
                  }}
                >
                  <Brain size={18} weight="bold" /> Save feedback
                </button>
              </div>
            ) : (
              <EmptyState title="No mock interview loaded" body="Choose text, call, onsite, or panel from the role dossier." />
            )}
          </Panel>
        </section>

        <section className="mt-4 grid gap-4">
          <Panel title="Experience writeups" icon={<Briefcase size={20} weight="bold" />}>
            <p className="text-sm leading-6 text-[#44403c]">
              CV bullets stay short. Use this section for every company or organization and every project under it.
              Drafts and interview prep pull broad themes and one specific sample from these writeups.
            </p>
            <div className="mt-4 grid gap-4">
              {(store.profile.experience ?? []).length === 0 ? (
                <EmptyState
                  title="No deep experience saved yet"
                  body="Add roles and project detail so applications can go beyond thin CV lines."
                />
              ) : (
                (store.profile.experience ?? []).map((entry) => (
                  <article key={entry.id} className="border border-[#111111] bg-[#ffffff] p-4">
                    <div className="flex flex-wrap items-baseline justify-between gap-2">
                      <h3 className="text-sm font-black uppercase">
                        {entry.title} · {entry.organization}
                      </h3>
                      <span className="text-xs font-semibold uppercase tracking-wide text-[#57534e]">
                        {[entry.period, entry.location].filter(Boolean).join(" · ")}
                      </span>
                    </div>
                    {entry.summary ? <p className="mt-2 text-sm leading-6 text-[#44403c]">{entry.summary}</p> : null}
                    {entry.bullets.length > 0 ? (
                      <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-[#44403c]">
                        {entry.bullets.map((bullet) => (
                          <li key={bullet}>{bullet}</li>
                        ))}
                      </ul>
                    ) : null}
                    <div className="mt-3 grid gap-3">
                      {entry.projects.length === 0 ? (
                        <p className="text-xs uppercase tracking-wide text-[#78716c]">No projects under this role yet.</p>
                      ) : (
                        entry.projects.map((project) => (
                          <div key={project.id} className="border border-[#d6d3d1] bg-[#f4f4f0] p-3">
                            <h4 className="text-sm font-black uppercase">{project.name}</h4>
                            {project.summary ? (
                              <p className="mt-1 text-sm leading-6 text-[#44403c]">
                                <span className="font-semibold">Summary: </span>
                                {project.summary}
                              </p>
                            ) : null}
                            {project.detail ? (
                              <p className="mt-1 text-sm leading-6 text-[#44403c]">
                                <span className="font-semibold">Detail: </span>
                                {project.detail}
                              </p>
                            ) : null}
                            {project.specificSample ? (
                              <p className="mt-1 text-sm leading-6 text-[#44403c]">
                                <span className="font-semibold">Specific sample: </span>
                                {project.specificSample}
                              </p>
                            ) : null}
                            <div className="mt-2 flex flex-wrap gap-2">
                              {[...project.tools, ...project.metrics, ...project.tags].slice(0, 8).map((tag) => (
                                <span key={tag} className="bg-[#edf3ec] px-2 py-1 text-xs text-[#346538]">
                                  {tag}
                                </span>
                              ))}
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </article>
                ))
              )}
            </div>
            <div className="mt-4 grid gap-3 border border-[#111111] bg-[#ffffff] p-4">
              <h3 className="text-sm font-black uppercase">Add or extend experience</h3>
              <div className="grid gap-3 md:grid-cols-2">
                <Field label="Role title">
                  <input
                    className="input"
                    value={experienceForm.title}
                    onChange={(event) => setExperienceForm({ ...experienceForm, title: event.target.value })}
                    placeholder="Investment Intern"
                  />
                </Field>
                <Field label="Organization / company">
                  <input
                    className="input"
                    value={experienceForm.organization}
                    onChange={(event) => setExperienceForm({ ...experienceForm, organization: event.target.value })}
                    placeholder="ARR Investment Partners"
                  />
                </Field>
                <Field label="Location">
                  <input
                    className="input"
                    value={experienceForm.location}
                    onChange={(event) => setExperienceForm({ ...experienceForm, location: event.target.value })}
                    placeholder="London"
                  />
                </Field>
                <Field label="Period">
                  <input
                    className="input"
                    value={experienceForm.period}
                    onChange={(event) => setExperienceForm({ ...experienceForm, period: event.target.value })}
                    placeholder="Summer 2025"
                  />
                </Field>
              </div>
              <Field label="Broad overview of this role">
                <textarea
                  className="input min-h-20"
                  value={experienceForm.summary}
                  onChange={(event) => setExperienceForm({ ...experienceForm, summary: event.target.value })}
                  placeholder="What this stint was about in plain language."
                />
              </Field>
              <Field label="CV bullets (comma or newline separated)">
                <textarea
                  className="input min-h-16"
                  value={experienceForm.bullets}
                  onChange={(event) => setExperienceForm({ ...experienceForm, bullets: event.target.value })}
                  placeholder="Short bullet one, short bullet two"
                />
              </Field>
              <h4 className="text-xs font-black uppercase tracking-wide text-[#57534e]">Optional project under this role</h4>
              <Field label="Project name">
                <input
                  className="input"
                  value={experienceForm.projectName}
                  onChange={(event) => setExperienceForm({ ...experienceForm, projectName: event.target.value })}
                  placeholder="Stock research application"
                />
              </Field>
              <Field label="Project summary (CV-level)">
                <textarea
                  className="input min-h-16"
                  value={experienceForm.projectSummary}
                  onChange={(event) => setExperienceForm({ ...experienceForm, projectSummary: event.target.value })}
                  placeholder="One or two short lines for resumes."
                />
              </Field>
              <Field label="Project detail (full writeup)">
                <textarea
                  className="input min-h-28"
                  value={experienceForm.projectDetail}
                  onChange={(event) => setExperienceForm({ ...experienceForm, projectDetail: event.target.value })}
                  placeholder="Everything useful for interviews: problem, approach, tools, constraints, outcomes."
                />
              </Field>
              <Field label="Specific sample (one concrete walkthrough)">
                <textarea
                  className="input min-h-20"
                  value={experienceForm.projectSample}
                  onChange={(event) => setExperienceForm({ ...experienceForm, projectSample: event.target.value })}
                  placeholder="One story an interviewer can dig into."
                />
              </Field>
              <div className="grid gap-3 md:grid-cols-3">
                <Field label="Tools">
                  <input
                    className="input"
                    value={experienceForm.projectTools}
                    onChange={(event) => setExperienceForm({ ...experienceForm, projectTools: event.target.value })}
                    placeholder="Python, market data APIs"
                  />
                </Field>
                <Field label="Metrics">
                  <input
                    className="input"
                    value={experienceForm.projectMetrics}
                    onChange={(event) => setExperienceForm({ ...experienceForm, projectMetrics: event.target.value })}
                    placeholder="32.48% return"
                  />
                </Field>
                <Field label="Tags">
                  <input
                    className="input"
                    value={experienceForm.projectTags}
                    onChange={(event) => setExperienceForm({ ...experienceForm, projectTags: event.target.value })}
                    placeholder="equity, AI, portfolio"
                  />
                </Field>
              </div>
              <button
                className="action-button"
                disabled={Boolean(busy)}
                onClick={() => void runAction("Save experience", saveExperience)}
              >
                <Plus size={18} weight="bold" /> Save experience writeup
              </button>
            </div>
          </Panel>
        </section>

        <section className="mt-4 grid gap-4 lg:grid-cols-[1fr_0.9fr]">
          <Panel title="Profile Evidence" icon={<CheckCircle size={20} weight="bold" />}>
            <div className="grid gap-px border border-[#111111] bg-[#111111] md:grid-cols-3">
              {store.profile.strengths.map((fact) => (
                <article key={fact.id} className="bg-[#f4f4f0] p-4">
                  <h3 className="text-sm font-black uppercase">{fact.label}</h3>
                  <p className="mt-3 text-sm leading-6 text-[#44403c]">{fact.proof}</p>
                  <div className="mt-3 flex flex-wrap gap-2">
                    {fact.tags.slice(0, 4).map((tag) => (
                      <span key={tag} className="bg-[#edf3ec] px-2 py-1 text-xs text-[#346538]">
                        {tag}
                      </span>
                    ))}
                  </div>
                </article>
              ))}
            </div>
            <div className="mt-4 grid gap-3 border border-[#111111] bg-[#ffffff] p-4">
              <h3 className="text-sm font-black uppercase">Add short evidence</h3>
              <Field label="Label">
                <input
                  className="input"
                  value={evidenceForm.label}
                  onChange={(event) => setEvidenceForm({ ...evidenceForm, label: event.target.value })}
                  placeholder="Closed enterprise pilot"
                />
              </Field>
              <Field label="Proof">
                <textarea
                  className="input min-h-20"
                  value={evidenceForm.proof}
                  onChange={(event) => setEvidenceForm({ ...evidenceForm, proof: event.target.value })}
                  placeholder="Short proof line for claim tracing."
                />
              </Field>
              <Field label="Tags">
                <input
                  className="input"
                  value={evidenceForm.tags}
                  onChange={(event) => setEvidenceForm({ ...evidenceForm, tags: event.target.value })}
                  placeholder="sales, enterprise, automation"
                />
              </Field>
              <button className="action-button" disabled={Boolean(busy)} onClick={() => void runAction("Save evidence", saveEvidence)}>
                <Plus size={18} weight="bold" /> Save evidence
              </button>
            </div>
          </Panel>

          <Panel title="Writing Lab" icon={<MagnifyingGlass size={20} weight="bold" />}>
            <Field label="Draft to audit">
              <textarea
                className="input min-h-24"
                value={writingText}
                onChange={(event) => setWritingText(event.target.value)}
              />
            </Field>
            <button className="mt-3 action-button" disabled={Boolean(busy)} onClick={() => void runAction("Audit writing", auditText)}>
              <MagnifyingGlass size={18} weight="bold" /> Audit slop
            </button>
            {writingAudit ? (
              <div className="mt-4">
                <StatusLine label="Writing score" value={String(writingAudit.score)} />
                <Checklist title="Flags" items={writingAudit.flags} />
                <Checklist title="Rewrite rules" items={writingAudit.rewrites} />
              </div>
            ) : null}
            <Field label="Feedback note">
              <textarea
                className="input min-h-20"
                value={learningNote}
                onChange={(event) => setLearningNote(event.target.value)}
              />
            </Field>
            <Field label="Rating">
              <input
                className="input"
                type="number"
                min={1}
                max={5}
                value={learningRating}
                onChange={(event) => setLearningRating(Number(event.target.value))}
              />
            </Field>
            <button className="mt-3 action-button" disabled={Boolean(busy)} onClick={() => void runAction("Save learning", recordLearning)}>
              <Brain size={18} weight="bold" /> Save learning
            </button>
            <Checklist items={store.profile.promptMemory.slice(0, 5)} />
          </Panel>
        </section>

        <section className="mt-4">
          <Panel title="Model Tiers And Integrations" icon={<TerminalWindow size={20} weight="bold" />}>
            <div className="mb-4 grid gap-px border border-[#111111] bg-[#111111] md:grid-cols-[1fr_260px]">
              <div className="bg-[#f4f4f0] p-4">
                <h3 className="text-sm font-black uppercase">Default agent tier</h3>
                <p className="mt-2 text-sm leading-6 text-[#44403c]">
                  {preferredTier?.bestFor ?? "Choose the model tier agents should use first."}
                </p>
              </div>
              <div className="bg-[#f4f4f0] p-4">
                <Field label="Tier">
                  <select
                    className="input"
                    value={preferredTier?.id ?? ""}
                    onChange={(event) => void runAction("Save model tier", () => savePreferredTier(event.target.value))}
                  >
                    {store.profile.modelTiers.map((tier) => (
                      <option key={tier.id} value={tier.id}>
                        {tier.label}
                      </option>
                    ))}
                  </select>
                </Field>
              </div>
            </div>
            <div className="grid gap-px border border-[#111111] bg-[#111111] lg:grid-cols-3">
              {store.profile.modelTiers.map((tier) => (
                <article key={tier.id} className="bg-[#f4f4f0] p-4">
                  <div className="flex items-start justify-between gap-3">
                    <h3 className="text-sm font-black uppercase">{tier.label}</h3>
                    <span className="border border-[#111111] px-2 py-1 text-xs uppercase">{tier.cost}</span>
                  </div>
                  <p className="mt-3 text-sm leading-6 text-[#44403c]">{tier.bestFor}</p>
                  <dl className="mt-4 grid gap-2 text-sm">
                    <div className="flex justify-between gap-3 border-t border-[#111111] pt-2">
                      <dt className="font-black uppercase">Provider</dt>
                      <dd>{tier.provider}</dd>
                    </div>
                    <div className="flex justify-between gap-3 border-t border-[#111111] pt-2">
                      <dt className="font-black uppercase">Model</dt>
                      <dd>{tier.model}</dd>
                    </div>
                    <div className="flex justify-between gap-3 border-t border-[#111111] pt-2">
                      <dt className="font-black uppercase">Env var</dt>
                      <dd className="font-mono">{tier.envVar}</dd>
                    </div>
                    <div className="flex justify-between gap-3 border-t border-[#111111] pt-2">
                      <dt className="font-black uppercase">Status</dt>
                      <dd>
                        {configStatus.find((item) => item.id === tier.id)?.configured ? "configured" : "not configured"}
                      </dd>
                    </div>
                  </dl>
                </article>
              ))}
            </div>
          </Panel>
        </section>
      </div>
    </main>
  );
}

function RoleDossier({
  job,
  onDraft,
  onBrowserPlan,
  onInterview,
  onStage,
  onNotes
}: {
  job: JobRecord;
  onDraft: () => void;
  onBrowserPlan: () => void;
  onInterview: (mode: InterviewMode) => void;
  onStage: (stage: ApplicationStage) => void;
  onNotes: (notes: string) => void;
}) {
  const [notes, setNotes] = useState(job.notes);

  useEffect(() => {
    setNotes(job.notes);
  }, [job.notes]);

  return (
    <div className="grid gap-4">
      <div className="grid gap-px border border-[#111111] bg-[#111111] md:grid-cols-[1fr_160px]">
        <div className="bg-[#f4f4f0] p-4">
          <h2 className="text-2xl font-black uppercase">{job.role}</h2>
          <p className="mt-1 text-sm text-[#44403c]">{job.company}</p>
          <p className="mt-3 max-h-28 overflow-hidden text-sm leading-6 text-[#44403c]">{job.description}</p>
        </div>
        <div className="bg-[#f4f4f0] p-4">
          <span className="font-mono text-5xl font-black">{job.matchScore}</span>
          <p className="mt-2 text-xs uppercase">Fit score</p>
        </div>
      </div>
      <div className="flex flex-wrap gap-2">
        <button className="action-button" onClick={onDraft}>
          <FileText size={18} weight="bold" /> Draft pack
        </button>
        <button className="secondary-button" onClick={onBrowserPlan}>
          <ShieldCheck size={18} weight="bold" /> Browser plan
        </button>
        {(["text", "call", "onsite", "panel"] as InterviewMode[]).map((mode) => (
          <button key={mode} className="secondary-button" onClick={() => onInterview(mode)}>
            {mode}
          </button>
        ))}
      </div>
      <Field label="Stage">
        <select className="input" value={job.stage} onChange={(event) => onStage(event.target.value as ApplicationStage)}>
          {stages.map((stage) => (
            <option key={stage} value={stage}>
              {stageLabels[stage]}
            </option>
          ))}
        </select>
      </Field>
      <div className="grid gap-4 md:grid-cols-2">
        <Field label="Notes">
          <textarea className="input min-h-24" value={notes} onChange={(event) => setNotes(event.target.value)} />
        </Field>
        <div className="grid gap-3 self-end">
          <button className="secondary-button" onClick={() => onNotes(notes)}>
            <FileText size={18} weight="bold" /> Save notes
          </button>
          {isSafeExternalUrl(job.sourceUrl) ? (
            <a className="secondary-button" href={job.sourceUrl} target="_blank" rel="noreferrer">
              Source
            </a>
          ) : (
            <span className="secondary-button opacity-60" aria-disabled="true">
              No valid source
            </span>
          )}
        </div>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        <Checklist title="Keywords" items={job.keywords.length ? job.keywords : ["No keywords extracted yet."]} />
        <Checklist title="Next actions" items={job.nextActions} />
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        <Checklist title="Reasons" items={job.matchReasons} />
        <Checklist title="Risks" items={job.risks.length ? job.risks : ["No major risk recorded yet."]} />
      </div>
      {job.documents ? (
        <div className="grid gap-4">
          <div className="border border-[#111111] bg-[#ffffff] p-4">
            <h3 className="text-sm font-black uppercase">Resume headline</h3>
            <p className="mt-3 text-sm leading-6 text-[#44403c]">{job.documents.resumeHeadline}</p>
          </div>
          <Checklist title="Resume bullets" items={job.documents.resumeBullets} />
          <div className="border border-[#111111] bg-[#ffffff] p-4">
            <h3 className="text-sm font-black uppercase">Cover letter</h3>
            <p className="mt-3 whitespace-pre-wrap text-sm leading-6 text-[#44403c]">{job.documents.coverLetter}</p>
          </div>
          <div className="grid gap-4 md:grid-cols-2">
            <div className="border border-[#111111] bg-[#ffffff] p-4">
              <h3 className="text-sm font-black uppercase">Contact message</h3>
              <p className="mt-3 text-sm leading-6 text-[#44403c]">{job.documents.recruiterMessage}</p>
            </div>
            <div className="border border-[#111111] bg-[#ffffff] p-4">
              <h3 className="text-sm font-black uppercase">Follow-up</h3>
              <p className="mt-3 text-sm leading-6 text-[#44403c]">{job.documents.followUpMessage}</p>
            </div>
          </div>
          <Checklist
            title="Screening answers"
            items={job.documents.screeningAnswers.map((answer) => `${answer.question}: ${answer.answer}`)}
          />
          <Checklist title="Claim trace" items={job.documents.claimTrace.map((claim) => `${claim.evidenceLabel}: ${claim.claim}`)} />
          {job.documents.claimTrace.length === 0 ? (
            <div className="border border-[#9f2f2d] bg-[#fdebec] p-3 text-sm text-[#9f2f2d]">
              Missing evidence trace. Add proof before submitting this application.
            </div>
          ) : null}
        </div>
      ) : null}
      <Checklist
        title="Activity"
        items={job.ledger.length ? job.ledger.map((event) => `${event.actor} ${event.approval}: ${event.summary}`) : ["No activity logged for this role yet."]}
      />
    </div>
  );
}

function LoadingShell() {
  return (
    <main className="min-h-[100dvh] bg-[#f4f4f0] p-4 text-[#111111]">
      <section className="mx-auto grid max-w-[1400px] gap-4 md:grid-cols-[1fr_0.7fr]">
        <div className="h-64 animate-pulse border border-[#111111] bg-[#eae8e3]" />
        <div className="h-64 animate-pulse border border-[#111111] bg-[#eae8e3]" />
        <div className="h-96 animate-pulse border border-[#111111] bg-[#eae8e3] md:col-span-2" />
      </section>
    </main>
  );
}

function Panel({ title, icon, children }: { title: string; icon: ReactNode; children: ReactNode }) {
  return (
    <section className="border border-[#111111] bg-[#f4f4f0]">
      <header className="flex items-center justify-between border-b border-[#111111] px-4 py-3">
        <h2 className="flex items-center gap-2 text-sm font-black uppercase">
          {icon}
          {title}
        </h2>
      </header>
      <div className="p-4">{children}</div>
    </section>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="grid gap-2 text-sm">
      <span className="font-black uppercase">{label}</span>
      {children}
    </label>
  );
}

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <div className="bg-[#f4f4f0] p-4">
      <data className="font-mono text-4xl font-black">{value}</data>
      <p className="mt-2 text-xs uppercase">{label}</p>
    </div>
  );
}

function Checklist({ title, items }: { title?: string; items: string[] }) {
  return (
    <div className="mt-4">
      {title ? <h3 className="mb-2 text-xs font-black uppercase">{title}</h3> : null}
      <ul className="space-y-2 text-sm leading-6 text-[#44403c]">
        {items.map((item) => (
          <li key={item} className="flex gap-2">
            <span className="mt-2 h-1.5 w-1.5 shrink-0 bg-[#e61919]" />
            <span>{item}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <div className="border border-dashed border-[#111111] bg-[#ffffff] p-6">
      <h3 className="text-sm font-black uppercase">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-[#44403c]">{body}</p>
    </div>
  );
}

function StatusLine({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between border-b border-[#111111] py-2 text-sm">
      <span className="font-black uppercase">{label}</span>
      <span className="font-mono">{value}</span>
    </div>
  );
}

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: {
      "content-type": "application/json",
      ...(init?.headers ?? {})
    }
  });
  if (!response.ok) {
    const body = await response.text();
    let message = response.statusText || `HTTP ${response.status}`;
    try {
      const parsed = JSON.parse(body) as { error?: string };
      message = parsed.error ?? message;
    } catch {
      const preview = body.slice(0, 180).replace(/\s+/g, " ");
      message = `Server returned non-JSON error response for ${path}: ${preview}`;
    }
    throw new Error(message);
  }
  return (await response.json()) as T;
}

function toMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
