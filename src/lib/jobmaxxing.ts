import { randomUUID } from "node:crypto";
import type {
  AgentCommandResult,
  AgentEvent,
  ApplicationPack,
  BrowserPlan,
  BrowserRisk,
  InterviewMode,
  InterviewPack,
  JobInput,
  JobRecord,
  JobmaxxingStore,
  PermissionMode,
  WhatsAppAnalyzedMessage,
  WhatsAppThreadProfile,
  UserProfile,
  WritingAudit
} from "./types";
import { normalizeExternalUrl } from "./urls";

const stopWords = new Set([
  "about",
  "after",
  "also",
  "and",
  "are",
  "but",
  "for",
  "from",
  "have",
  "into",
  "our",
  "that",
  "the",
  "their",
  "this",
  "with",
  "will",
  "you",
  "your"
]);

const protectedDomains = [
  "linkedin.com",
  "indeed.com",
  "glassdoor.com",
  "ziprecruiter.com"
];

const slopPhrases = [
  "elevate",
  "unleash",
  "seamless",
  "next-gen",
  "game-changing",
  "passionate",
  "thrilled",
  "excited to apply",
  "dynamic team",
  "fast-paced environment",
  "innovative solutions",
  "cutting-edge",
  "delve",
  "realm",
  "landscape",
  "journey",
  "testament",
  "not only",
  "but also",
  "the role maps to",
  "maps to work",
  "maps best",
  "highest-friction",
  "real bottleneck",
  "uniquely positioned",
  "uniquely qualified",
  "aligns perfectly",
  "perfectly aligned",
  "looking forward to the opportunity",
  "would be a great fit",
  "deeply passionate",
  "i can start on",
  "if useful, i can",
  "the posting asks",
  "your posting asks",
  "i can do this for you",
  "happy to hear back",
  "or to show something i have built",
  "one concrete example:",
  "long/short idea work",
  "sector-agnostic",
  "market-data tooling",
  "where i can be useful",
  "tied to the team's"
];

const weaselWords = ["might", "could", "should", "various", "several", "very", "really", "significant"];

const minEvidenceRelevance = 2;

const unsupportedClaimPhrases = [
  "strong fit",
  "great fit",
  "perfect fit",
  "relevant experience",
  "proven track record",
  "uniquely qualified",
  "deep experience",
  "extensive experience",
  "i can help",
  "i would bring",
  "i have shipped",
  "i have built"
];

const candidateClaimPattern =
  /\b(i|my)\s+(built|designed|shipped|led|owned|created|configured|delivered|automated|improved|reduced|increased|launched|managed|implemented|worked|have|can|bring|background|experience)\b/i;

const communicationStopWords = new Set([
  "about",
  "after",
  "also",
  "and",
  "are",
  "but",
  "can",
  "for",
  "from",
  "have",
  "just",
  "like",
  "not",
  "that",
  "the",
  "then",
  "this",
  "with",
  "you",
  "your",
  "was",
  "what",
  "when",
  "will"
]);

export function extractKeywords(text: string, limit = 16): string[] {
  const counts = new Map<string, number>();
  for (const raw of text.toLowerCase().match(/[a-z][a-z0-9+-]{2,}/g) ?? []) {
    if (stopWords.has(raw)) {
      continue;
    }
    counts.set(raw, (counts.get(raw) ?? 0) + 1);
  }

  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || b[0].length - a[0].length || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([word]) => word);
}

export function createJobRecord(input: JobInput, profile: UserProfile): JobRecord {
  const role = normalizeUserFacingText(cleanRequired(input.role, "role"));
  const keywords = extractKeywords(`${role} ${input.description}`).map(normalizeUserFacingText);
  const score = scoreJob(profile, { ...input, role });
  const sourceUrl = normalizeExternalUrl(input.sourceUrl);
  return {
    id: randomUUID(),
    company: cleanRequired(input.company, "company"),
    role,
    sourceUrl,
    description: cleanRequired(input.description, "description"),
    stage: "saved",
    matchScore: score.score,
    matchReasons: score.reasons,
    risks: score.risks,
    keywords,
    nextActions: buildNextActions(score.score, score.risks),
    documents: null,
    ledger: [],
    notes: input.notes?.trim() ?? "",
    dateLabel: input.dateLabel?.trim() ?? ""
  };
}

export function scoreJob(
  profile: UserProfile,
  job: Pick<JobInput, "role" | "description" | "sourceUrl">
): { score: number; reasons: string[]; risks: string[] } {
  const haystack = `${job.role} ${job.description}`.toLowerCase();
  const targetHits = profile.targetRoles.filter((role) => hasAnyToken(haystack, role));
  const evidenceHits = profile.strengths.filter((fact) => evidenceRelevanceScore(fact, haystack) >= minEvidenceRelevance);
  const dealBreakerHits = profile.dealBreakers.filter((item) => hasAnyToken(haystack, item));
  const locationHits = profile.locations.filter((location) => haystack.includes(location.toLowerCase()));

  let score = 34;
  score += Math.min(targetHits.length * 16, 26);
  score += Math.min(evidenceHits.length * 12, 30);
  score += Math.min(locationHits.length * 6, 10);
  score -= dealBreakerHits.length * 18;
  if (haystack.includes("senior") || haystack.includes("staff") || haystack.includes("founding")) {
    score += 6;
  }
  if (!haystack.includes("salary") && !haystack.includes("compensation") && !haystack.includes("equity")) {
    score -= 5;
  }

  const reasons = [
    ...targetHits.map((role) => `Target role overlap: ${role}.`),
    ...evidenceHits.map((fact) => `Evidence match: ${fact.label}.`),
    ...locationHits.map((location) => `Location constraint may fit: ${location}.`)
  ];
  const risks = [
    ...dealBreakerHits.map((item) => `Potential deal breaker mentioned: ${item}.`),
    ...(!haystack.includes("salary") && !haystack.includes("compensation")
      ? ["Compensation is not visible in the saved description."]
      : []),
    ...(evidenceHits.length === 0 ? ["No saved evidence clearly supports the main job themes."] : [])
  ];

  return {
    score: Math.max(8, Math.min(96, score)),
    reasons: reasons.length > 0 ? reasons : ["Needs manual review; no strong profile overlap found yet."],
    risks
  };
}

export function buildApplicationPack(profile: UserProfile, job: JobRecord): ApplicationPack {
  const role = normalizeUserFacingText(job.role);
  const evidence = pickEvidence(profile, job, 3);
  const bullets = evidence.map(
    (fact) => `${fact.proof} Evidence for ${role}: ${fact.label}.`
  );
  const trace = evidence.flatMap((fact, index) => [
    traceClaim(`${fact.proof} Evidence for ${role}: ${fact.label}.`, fact, `resume bullet ${index + 1}`),
    traceClaim(`${fact.label}: ${fact.proof}`, fact, `cover letter evidence ${index + 1}`)
  ]);
  const keywordLine = job.keywords.slice(0, 6).join(", ");
  const missingEvidence = buildEvidenceGaps(job, evidence);
  const assumptions = [
    `Role priorities are inferred from the saved job text: ${keywordLine || "no keywords extracted"}.`,
    ...(evidence.length === 0 && !hasExperienceDetail(profile)
      ? ["No saved evidence is relevant enough to claim strong fit."]
      : [])
  ];
  const broadLine = buildBroadWorkLine(profile, job, evidence);
  const sampleLine = buildSpecificSampleLine(profile, job, evidence);
  const proofBackedFit =
    evidence.length > 0 || hasExperienceDetail(profile)
      ? [broadLine, sampleLine].filter(Boolean).join(" ")
      : "Do not claim fit yet. Add saved evidence or experience writeups that match the role first.";
  const recruiterProof = sampleLine || broadLine || "Reviewing the role before claiming fit.";

  return {
    resumeHeadline: `${role} candidate focused on ${keywordLine || "clear proof and useful work"}`,
    resumeBullets: bullets,
    coverLetter: [
      `I am interested in the ${role} role at ${job.company}.`,
      broadLine || "The saved profile needs matching evidence before this application should be sent.",
      sampleLine ||
        (evidence.length === 0 && !hasExperienceDetail(profile)
          ? "Before submitting, add a concrete project writeup with one specific sample."
          : ""),
      "My CV is attached. I would look forward to hearing back from you and learning more about the role."
    ]
      .filter(Boolean)
      .join("\n\n"),
    screeningAnswers: [
      {
        question: "Why are you interested in this role?",
        answer: `I am interested in the ${role} role at ${job.company}.`
      },
      {
        question: "Why are you a strong fit?",
        answer: proofBackedFit
      },
      {
        question: "Anything else we should know?",
        answer: "Claims stay clear, plain, and tied to saved proof or experience writeups."
      }
    ],
    recruiterMessage: `Use only after identifying a recruiter or hiring-team contact. Hi, I am interested in the ${role} role at ${job.company}. ${recruiterProof} I would look forward to hearing back from you and learning more about the role.`,
    followUpMessage: `Hi, following up on interest in the ${role} role at ${job.company}. I would look forward to hearing back from you and learning more about the role.`,
    claimTrace: [
      ...trace,
      ...evidence.map((fact) => traceClaim(asFirstPersonProof(fact.proof), fact, "screening answer")),
      ...(evidence[0] ? [traceClaim(recruiterProof, evidence[0], "contact message")] : [])
    ],
    assumptions,
    missingEvidence
  };
}

/** Turn saved proof into a first-person sentence for outreach. */
export function asFirstPersonProof(proof: string): string {
  const clean = proof.trim().replace(/\s+/g, " ");
  if (!clean) return "";
  const withPeriod = /[.!?]$/.test(clean) ? clean : `${clean}.`;
  if (/\bi\b/i.test(withPeriod.slice(0, 24))) {
    return withPeriod.charAt(0).toUpperCase() + withPeriod.slice(1);
  }
  if (
    /^(built|created|researched|designed|led|revived|applied|contracted|supported|developed|shipped|owned|implemented|worked)\b/i.test(
      withPeriod
    )
  ) {
    return `I ${withPeriod.charAt(0).toLowerCase()}${withPeriod.slice(1)}`;
  }
  if (/^last summer\b/i.test(withPeriod) && !/\bi\b/i.test(withPeriod.slice(0, 40))) {
    return withPeriod.replace(/^last summer\s+/i, "Last summer I ");
  }
  return withPeriod;
}

function hasExperienceDetail(profile: UserProfile): boolean {
  return (profile.experience ?? []).some(
    (entry) =>
      entry.summary.trim().length > 0 ||
      entry.projects.some((project) => project.detail.trim().length > 0 || project.specificSample.trim().length > 0)
  );
}

function scoreExperienceText(text: string, job: JobRecord): number {
  const haystack = `${job.role} ${job.description} ${job.keywords.join(" ")}`.toLowerCase();
  return text
    .toLowerCase()
    .split(/[^a-z0-9+-]+/)
    .filter((token) => token.length > 3 && !stopWords.has(token) && haystack.includes(token)).length;
}

/** Broad themes for cover letters: not a full bio, not a single bullet. */
export function buildBroadWorkLine(
  profile: UserProfile,
  job: JobRecord,
  evidence: UserProfile["strengths"]
): string {
  const rankedExperience = [...(profile.experience ?? [])]
    .map((entry) => ({
      entry,
      score:
        scoreExperienceText(`${entry.title} ${entry.organization} ${entry.summary} ${entry.bullets.join(" ")}`, job) +
        entry.projects.reduce(
          (sum, project) =>
            sum + scoreExperienceText(`${project.name} ${project.summary} ${project.tags.join(" ")}`, job),
          0
        )
    }))
    .sort((left, right) => right.score - left.score);

  const top = rankedExperience[0];
  if (top && top.score >= minEvidenceRelevance) {
    // Broad block only: do not list project summaries here, or the sample repeats them.
    const overview = top.entry.summary.trim();
    if (overview) {
      return overview.endsWith(".") ? overview : `${overview}.`;
    }
  }

  if (evidence.length >= 2) {
    return `Most of the recent work sits around ${evidence
      .slice(0, 3)
      .map((fact) => fact.label.toLowerCase())
      .join(", ")}. The common thread is building useful tools and keeping the results easy to check.`;
  }
  if (evidence[0]) {
    const proof = evidence[0].proof.replace(/^[Ii]\s+/, "").replace(/\.$/, "");
    return `Most of the recent work involves ${proof.charAt(0).toLowerCase()}${proof.slice(1)}.`;
  }
  return "";
}

/** One concrete sample from deep project writeups when available. */
export function buildSpecificSampleLine(
  profile: UserProfile,
  job: JobRecord,
  evidence: UserProfile["strengths"]
): string {
  const projects = (profile.experience ?? []).flatMap((entry) =>
    entry.projects.map((project) => ({
      entry,
      project,
      score:
        scoreExperienceText(
          `${entry.organization} ${project.name} ${project.summary} ${project.detail} ${project.specificSample} ${project.tags.join(" ")}`,
          job
        ) + (project.specificSample.trim() || project.detail.trim() ? 2 : 0)
    }))
  );
  projects.sort((left, right) => right.score - left.score);
  const best = projects[0];
  if (best && best.score >= minEvidenceRelevance) {
    // Prefer the dug-in sample or full detail, not the short summary (summary belongs in broad).
    const sample = best.project.specificSample.trim() || best.project.detail.trim();
    if (sample) {
      const body = sample.endsWith(".") ? sample : `${sample}.`;
      if (/^(for example|last summer|during|one day|on one)\b/i.test(body)) {
        return body.charAt(0).toUpperCase() + body.slice(1);
      }
      return `For example, ${body.charAt(0).toLowerCase()}${body.slice(1)}`;
    }
  }

  if (evidence[0]) {
    const proof = evidence[0].proof.replace(/^[Ii]\s+/, "");
    return `For example, ${proof.charAt(0).toLowerCase()}${proof.slice(1)}${/[.!?]$/.test(proof) ? "" : "."}`;
  }
  return "";
}

export function formatExperienceForPrompt(profile: UserProfile): string {
  const entries = profile.experience ?? [];
  if (entries.length === 0) {
    return "- No deep experience writeups yet. Ask the user to add company/project detail beyond CV bullets.";
  }
  return entries
    .map((entry) => {
      const projectBlock =
        entry.projects.length === 0
          ? "  - Projects: none saved yet. Add project-level detail for interviews and samples."
          : entry.projects
              .map(
                (project) =>
                  `  - Project: ${project.name}\n    Summary: ${project.summary || "(empty)"}\n    Detail: ${project.detail || "(empty)"}\n    Specific sample: ${project.specificSample || "(empty)"}\n    Tools: ${project.tools.join(", ") || "n/a"}\n    Metrics: ${project.metrics.join(", ") || "n/a"}`
              )
              .join("\n");
      return [
        `- ${entry.title} @ ${entry.organization} (${entry.period || "period n/a"}, ${entry.location || "location n/a"})`,
        `  Overview: ${entry.summary || "(empty)"}`,
        `  CV bullets: ${entry.bullets.join(" | ") || "(none)"}`,
        projectBlock
      ].join("\n");
    })
    .join("\n");
}

export function normalizeUserFacingText(value: string): string {
  const protectedSourceRole = "__SOURCE_WORKING_STUDENT__";
  return (value ?? "")
    .replaceAll("&amp;", "&")
    .replace(/\bAIML\s*-\s*/g, "")
    .replace(/\bAIML\b/g, "AI and ML")
    .replace(/\bAI\/ML\b/g, "AI and ML")
    .replace(/\bData\s*\/\s*ML\s*\/\s*AI Intern\b/g, "Data, ML, and AI Intern")
    .replace(/\bData\s*\/\s*ML\s*\/\s*AI\b/g, "Data, ML, and AI")
    .replace(/\bIntern Applied AI\s*&\s*AI-Platform\b/g, "Applied AI and AI Platform Intern")
    .replace(/\bApplied AI\s*&\s*AI-Platform Intern\b/g, "Applied AI and AI Platform Intern")
    .replace(/Daten trifft auf Systeme: Trainee-Programm, 80-100%/g, "Data and Systems Trainee Program, 80-100%")
    .replace(/\bContracted as working student\b/g, `Contracted as a working student (source role title: ${protectedSourceRole})`)
    .replace(/\bsource role title: Working Student\b/g, `source role title: ${protectedSourceRole}`)
    .replaceAll(protectedSourceRole, "working student")
    .replace(
      /\bApple Mail contract evidence: Local Candidate Vertrag\.pdf\b/g,
      "Apple Mail contract evidence: Local Candidate contract.pdf (original German filename: Local Candidate Vertrag.pdf)"
    )
    .replace(/\s+/g, " ")
    .trim();
}

export function auditWriting(text: string, profile: UserProfile): WritingAudit {
  const flags: string[] = [];
  const rewrites: string[] = [];
  const sentences = text.split(/[.!?]+/).map((sentence) => sentence.trim()).filter(Boolean);
  const lower = text.toLowerCase();
  const evidenceReferences = findEvidenceReferences(text, profile);
  const unsupportedClaims = findUnsupportedClaims(sentences, profile);

  for (const sentence of sentences) {
    const words = sentence.split(/\s+/).filter(Boolean);
    if (words.length > 30) {
      flags.push(`Long sentence has ${words.length} words: "${sentence.slice(0, 90)}".`);
      rewrites.push("Split long sentences into one claim, one proof point, and one next step.");
    }
  }

  for (const phrase of slopPhrases) {
    if (lower.includes(phrase)) {
      flags.push(`AI-slop phrase detected: "${phrase}".`);
      rewrites.push(`Replace "${phrase}" with a concrete fact or delete it.`);
    }
  }

  for (const word of weaselWords) {
    const pattern = new RegExp(`\\b${word}\\b`, "i");
    if (pattern.test(text)) {
      flags.push(`Weasel word detected: "${word}".`);
      rewrites.push(`Replace "${word}" with a direct claim, scope, or uncertainty label.`);
    }
  }

  if (profile.strengths.length === 0) {
    flags.push("No saved evidence is available.");
    rewrites.push("Add reviewed evidence before making candidate claims.");
  } else if (evidenceReferences.length === 0) {
    flags.push("No saved evidence is referenced directly.");
    rewrites.push("Add one saved evidence fact or remove the unsupported claim.");
  }

  for (const claim of unsupportedClaims) {
    flags.push(`Unsupported claim: "${claim}".`);
    rewrites.push("Either cite saved evidence in the same sentence or mark the statement as an assumption.");
  }

  const score = Math.max(0, 100 - flags.length * 10 - unsupportedClaims.length * 8);
  const ready = score >= 85 && unsupportedClaims.length === 0 && evidenceReferences.length > 0;
  return {
    score,
    ready,
    flags: flags.length ? flags : ["Ready: concise, direct, and evidence-backed."],
    rewrites: rewrites.length ? [...new Set(rewrites)] : ["Keep the draft direct and proof-backed."],
    unsupportedClaims,
    evidenceReferences,
    prompt: buildWritingPrompt(profile, text)
  };
}

export function buildWritingPrompt(profile: UserProfile, draft = ""): string {
  const rules = profile.writingRules
    .map((rule) => `- ${rule.label}: ${rule.instruction}`)
    .join("\n");
  const memory = profile.promptMemory.map((item) => `- ${item}`).join("\n");
  const evidence = profile.strengths
    .map((fact) => `- ${fact.label}: ${fact.proof}`)
    .join("\n");
  const style = profile.styleGuide.map((item) => `- ${item}`).join("\n");
  const experienceBlock = formatExperienceForPrompt(profile);

  return [
    "You are Jobmaxxing's application writing agent.",
    "Goal: help the user get a job with clear, humble, proof-backed writing the reader can trust.",
    "",
    "The only two questions a cover letter or outreach must answer:",
    "1. Is this person interested in this role?",
    "2. Have they done anything like this, and does the work look real?",
    "If a sentence does not answer one of those, delete it.",
    "",
    "Voice:",
    "- Sound competent and calm, not salesy and not self-deprecating.",
    "- Prefer 'I am interested in...' over 'I am applying for...' or service pitches.",
    "- Vary sentence openings. Do not stack many consecutive sentences that start with I.",
    "- Write full polite sentences in the close. Do not bark orders like 'CV is attached.'",
    "- Stay true to the user. Never reshape the story to flatter a company.",
    "",
    "Audience:",
    "- First reader is often HR or a general hiring contact, not a trading specialist.",
    "- Write so a smart non-expert understands every sentence.",
    "- Use plain words for finance work: say 'research on stocks to buy or sell' instead of unexplained 'long/short idea work'.",
    "- Add a few words when they improve clarity. Do not compress into jargon.",
    "- Still respect the company: choose proof that fits the role, but do not lecture them about their business.",
    "",
    "Writing rules:",
    rules,
    "",
    "Style guide:",
    style || "- No extra style notes.",
    "",
    "User voice memory:",
    memory || "- No learned preferences yet.",
    "",
    "Allowed CV-level evidence:",
    evidence || "- No saved evidence yet.",
    "",
    "Deep experience and project writeups (prefer these for samples and interview prep):",
    experienceBlock,
    "",
    "Evidence policy:",
    "- Base every material claim on saved evidence, experience writeups, or a labeled assumption.",
    "- CV bullets are short. Project detail and specific samples are for depth.",
    "- Quantify when numbers exist. Otherwise use precise past work, scope, or mechanism.",
    "- Name the real product or system when the user built one (app, platform, tool), not vague 'workflows' if a stronger noun fits.",
    "- Use only relevant proof. Do not dump every project into one letter.",
    "- Broad section and sample section must not repeat the same phrases.",
    "- Put unsupported claims under Missing evidence or Assumptions.",
    "",
    "Company research vs company prose:",
    "- Read mission, culture, values, and role text to choose relevant proof and tone.",
    "- Do not restate what the company already knows about itself.",
    "- Do not paraphrase the job posting back at them.",
    "- Do not offer to start on their bottleneck or list tasks for their team.",
    "- Company mission may shape which proof you pick. It should rarely appear as letter prose.",
    "",
    "Draft structure for cover letters and outreach:",
    "1. Interest: 'I am interested in the [role] role at [company].'",
    "2. Broad relevant work: plain-English themes. No insider shorthand. No project dump.",
    "3. One specific sample: start with 'For example,' then dig into ONE part of ONE project (problem, what was built, what changed).",
    "4. Soft close in full sentences: 'My CV is attached. I would look forward to hearing back from you and learning more about the role.'",
    "5. No company lecture, no posting paraphrase, no service pitch.",
    "",
    "Good example shape:",
    "- I am interested in the Data, ML, and AI Intern role at Northstar Climate Bank.",
    "- Most of my recent work sits where market research meets software. That means cleaning messy information, building small tools that speed up analysis, and keeping the results clear enough that another person can check them.",
    "- For example, last summer during an investment internship, a lot of time went into the same news-and-notes grind: open several sources, copy pieces into a document, and try to compare what mattered. I built a process that pulled those inputs together, cleaned them, and turned them into a short structured summary someone could review before a research discussion. The point was not to replace judgment. The point was to stop redoing the same setup work every morning.",
    "- My CV is attached. I would look forward to hearing back from you and learning more about the role.",
    "",
    "Bad patterns:",
    "- 'One concrete example:' as a stiff label instead of 'For example,'",
    "- Compressed jargon: 'long/short idea work', 'market-data tooling', 'sector-agnostic'",
    "- Repeating the same research phrase in broad and sample blocks",
    "- Stacking two projects into the sample instead of digging into one",
    "- 'CV is attached.' as a barked fragment",
    "- I-I-I stacks, company lectures, posting paraphrase, service pitches",
    "",
    "Banned empty language:",
    "- 'the role maps to', 'maps to work', 'highest-friction', 'real bottleneck'",
    "- 'the posting asks', 'your posting asks', 'I can start on', 'if useful, I can'",
    "- 'one concrete example:', 'happy to hear back', 'CV is attached.' as a lone barked line",
    "- 'uniquely qualified', 'aligns perfectly', 'thrilled'",
    "",
    "Process:",
    "1. Identify the reader (often HR first) and the two decisions: interested? capable?",
    "2. Open with interest in the named role.",
    "3. Write a plain-English broad block from experience overview only.",
    "4. Dig into one specific sample from project specificSample/detail. No second project in that paragraph.",
    "5. Close with full polite sentences about the CV and hearing back.",
    "6. Audit for jargon, repetition, I-stacks, company lectures, and barked fragments.",
    "7. Return a clear draft plus a claim trace, assumptions, and missing evidence.",
    "",
    draft ? `Draft to improve:\n${draft}` : "Ask for the draft or job context before writing."
  ].join("\n");
}

export function buildBrowserPlan(profile: UserProfile, request: string, sourceUrl = ""): BrowserPlan {
  const domain = getDomain(`${request} ${sourceUrl}`);
  const protectedSite = protectedDomains.some((site) => domain.endsWith(site));
  const mode: PermissionMode = protectedSite ? "manual_only" : profile.permissions.browser;
  const risk: BrowserRisk = protectedSite ? "high" : mode === "manual_only" ? "low" : "medium";

  return {
    risk,
    mode,
    allowed: [
      "Open pages the user explicitly requests.",
      "Prepare copied text, answers, and checklists.",
      "Record user-approved notes in the local ledger.",
      "Stop at review screens before any external submission."
    ],
    blocked: [
      "No hidden scraping, fake accounts, captcha bypass, or rate-limit bypass.",
      "No application submission unless the user performs the final action.",
      ...(protectedSite
        ? ["No LinkedIn or protected job-board automation; use manual assist and copy-ready materials."]
        : []),
      ...(profile.permissions.allowExternalSubmission ? [] : ["External submission is disabled in permissions."])
    ],
    userCheckpoint: protectedSite
      ? "Use Jobmaxxing to prepare materials, then let the user operate the protected site manually."
      : "Ask the user to approve the filled content before leaving Jobmaxxing or touching a submit control.",
    recommendedSteps: [
      "Confirm the target role and source URL.",
      "Generate the application pack and screening answers.",
      "Open the destination only if the user requests it.",
      "Fill or copy content only within the configured permission mode.",
      "Log exactly what was proposed and what the user approved."
    ]
  };
}

export function buildInterviewPack(profile: UserProfile, job: JobRecord, mode: InterviewMode): InterviewPack {
  const evidence = pickEvidence(profile, job, 3);
  const roleKeywords = job.keywords.slice(0, 5);
  return {
    mode,
    company: job.company,
    role: job.role,
    warmup: [
      `Give the concise story for why ${job.company} and why ${job.role}.`,
      "Explain the strongest saved evidence without overclaiming.",
      "Name the first business problem you would investigate."
    ],
    technical: roleKeywords.map((keyword) => `Walk through a project where ${keyword} mattered.`),
    behavioral: [
      "Tell me about a time you had to turn ambiguity into a shipped system.",
      "Tell me about a time you disagreed with a stakeholder and still moved the work forward.",
      "What is a failure you would not repeat?"
    ],
    scorecard: [
      "Specificity: answers include concrete systems, constraints, and outcomes.",
      "Truthfulness: every strong claim maps to saved evidence.",
      "Role fit: answers connect back to the company's likely pain.",
      "Brevity: answers land in under two minutes unless asked to go deeper."
    ],
    researchTasks: [
      `Find ${job.company}'s business model, customers, and recent product changes.`,
      "Identify the hiring manager or likely team lead from public information only.",
      `Prepare three questions that prove real interest in ${job.role}.`,
      evidence[0]
        ? `Tie ${evidence[0].label.toLowerCase()} to the role's first likely project.`
        : "Add more saved evidence before the interview."
    ]
  };
}

export function analyzeWhatsAppThread(input: {
  threadId: string;
  displayName: string;
  jid: string;
  messages: WhatsAppAnalyzedMessage[];
  companyName: string;
  personName: string;
  purpose?: string;
}): WhatsAppThreadProfile {
  const messages = input.messages.filter((message) => message.text.trim().length > 0);
  const outgoing = messages.filter((message) => message.fromMe);
  const incoming = messages.filter((message) => !message.fromMe);
  const topics = topCommunicationTopics(messages.map((message) => message.text));
  const firstName = input.personName.trim().split(/\s+/)[0] || input.displayName;
  const purpose = input.purpose?.trim() || "ask for useful hiring context or the right person to speak with";
  const directFormat = directMessageFormat(outgoing);
  const directDraft = [
    `Hey ${firstName}, quick one.`,
    `I’m looking at ${input.companyName} and wanted your read.`,
    purpose,
    "Would you point me to the right person or tell me what to watch for?"
  ].join(" ");
  const emailDraft = [
    `Subject: Quick question on ${input.companyName}`,
    "",
    `Hi ${firstName},`,
    "",
    `I am looking at ${input.companyName} and wanted to ask for your perspective.`,
    purpose,
    "",
    "Would you be open to pointing me toward the right person or sharing what I should understand first?",
    "",
    "Best,",
    "[Candidate]"
  ].join("\n");

  return {
    threadId: input.threadId,
    displayName: input.displayName,
    jid: input.jid,
    messageCount: messages.length,
    outgoingCount: outgoing.length,
    incomingCount: incoming.length,
    lastMessagePreview: messages.at(-1)?.text.slice(0, 180) ?? "",
    styleSummary: styleSummary(outgoing),
    relationshipSummary:
      messages.length === 0
        ? `No readable text history found for ${input.displayName}.`
        : `Imported ${messages.length} readable messages with ${input.displayName}. Repeated topics: ${topics.slice(0, 5).join(", ") || "none"}.`,
    topics,
    directMessageFormat: directFormat,
    emailFormat: "Email should be more structured than WhatsApp: subject, context, proof, one ask.",
    suggestedDirectMessage: directDraft,
    suggestedEmailMessage: emailDraft,
    allowedForAI: true
  };
}

function styleSummary(outgoing: WhatsAppAnalyzedMessage[]): string {
  if (outgoing.length === 0) {
    return "No outgoing text messages were found, so no personal writing style was learned.";
  }
  const words = outgoing.flatMap((message) => message.text.trim().split(/\s+/).filter(Boolean));
  const averageWords = Math.max(1, Math.round(words.length / outgoing.length));
  const questionCount = outgoing.filter((message) => message.text.includes("?")).length;
  const emojiCount = outgoing.filter((message) => /\p{Extended_Pictographic}/u.test(message.text)).length;
  const lengthRule = averageWords <= 12 ? "short, chat-native messages" : "slightly fuller chat messages";
  const askRule = questionCount > Math.max(1, outgoing.length / 5) ? "often asks direct questions" : "usually states context before the ask";
  const emojiRule = emojiCount > Math.max(1, outgoing.length / 6) ? "uses emoji when tone matters" : "uses little emoji";
  return `Outgoing style uses ${lengthRule}, ${askRule}, and ${emojiRule}. Keep direct messages close to that cadence.`;
}

function directMessageFormat(outgoing: WhatsAppAnalyzedMessage[]): string {
  if (outgoing.length === 0) {
    return "Use one short opener, one context line, and one clear ask.";
  }
  const averageLength = outgoing.reduce((sum, message) => sum + message.text.length, 0) / outgoing.length;
  return averageLength < 80
    ? "Use one or two short bubbles. Start with context, then ask one concrete question."
    : "Use a compact paragraph. Give context first, then one concrete ask. Avoid email subject lines.";
}

function topCommunicationTopics(texts: string[]): string[] {
  const counts = new Map<string, number>();
  for (const text of texts) {
    for (const word of text.toLowerCase().match(/[a-z][a-z0-9+-]{3,}/g) ?? []) {
      if (!communicationStopWords.has(word)) {
        counts.set(word, (counts.get(word) ?? 0) + 1);
      }
    }
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 8)
    .map(([word]) => word);
}

export function buildAgentCommand(command: string, store: JobmaxxingStore): AgentCommandResult {
  const lower = command.toLowerCase();
  const intent = intentRoutes.find((route) => route.keywords.some((keyword) => lower.includes(keyword)))?.intent ?? "discover";
  const topJob = store.jobs.reduce<JobRecord | undefined>(
    (best, job) => (!best || job.matchScore > best.matchScore ? job : best),
    undefined
  );
  const safety = [
    "Keep every claim traceable to saved evidence.",
    "Prepare drafts and plans before touching external sites.",
    "Require a user checkpoint before any application submission."
  ];

  return {
    intent,
    summary: topJob
      ? `Best current target is ${topJob.role} at ${topJob.company} with score ${topJob.matchScore}.`
      : "No jobs are saved yet; start by adding a role or pasting a job description.",
    toolHints: buildToolHints(intent),
    safety,
    nextActions: buildIntentActions(intent, topJob)
  };
}

export function buildCompanyResearchPrompt(profile: UserProfile, job: JobRecord): string {
  return [
    `Research ${job.company} for the ${job.role} application.`,
    "",
    "Return:",
    "- what the company sells or invests in (for internal selection of proof only)",
    "- public mission, culture values, or stated goal, if any (internal use; do not dump into letters)",
    "- who likely buys, uses, or benefits from the work",
    "- recent public signals worth knowing",
    "- concrete work the role likely needs, taken from the posting and public sources",
    "- which 1-2 user proof points best answer 'interested?' and 'done similar work?'",
    "- hiring manager or team lead candidates from public sources only",
    "- three interview questions that prove real interest without flattery",
    "",
    "Writing guidance for any outreach draft that follows this research:",
    "- Answer only: is the user interested, and have they done similar work?",
    "- Open with 'I am interested in the [role] role at [company].'",
    "- Do not restate the company's business. They already know it.",
    "- Do not paraphrase the job posting.",
    "- Do not offer to start on their tasks or bottlenecks.",
    "- Close with CV attached and a soft offer to share more or show work.",
    "",
    "Constraints:",
    "- Separate facts from assumptions.",
    "- Do not scrape protected sites.",
    "- Do not invent people, revenue, funding, customers, culture, or mission.",
    "- Never recommend sycophantic or slogan-mirroring language.",
    "- Prefer 'user did X' over 'role maps to' or 'posting asks for'.",
    "- Tie recommendations to the user's evidence only when relevance is real.",
    "",
    "Relevant user evidence:",
    ...profile.strengths.map((fact) => `- ${fact.label}: ${fact.proof}`)
  ].join("\n");
}

export function applyLearning(profile: UserProfile, note: string, rating: number): UserProfile {
  const cleanNote = cleanRequired(note, "learning note");
  const boundedRating = Math.max(1, Math.min(5, Math.round(rating)));
  const memory = `Rated ${boundedRating}/5: ${cleanNote}`;
  return {
    ...profile,
    promptMemory: [memory, ...profile.promptMemory].slice(0, 20)
  };
}

export function createEvent(
  store: JobmaxxingStore,
  event: Omit<AgentEvent, "id" | "sequence">
): AgentEvent {
  const maxSequence = Math.max(0, ...store.events.map((item) => item.sequence));
  return {
    id: randomUUID(),
    sequence: maxSequence + 1,
    ...event
  };
}

function cleanRequired(value: string, label: string): string {
  const clean = value.trim();
  if (clean.length === 0) {
    throw new Error(`Missing required ${label}.`);
  }
  return clean;
}

function hasAnyToken(haystack: string, phrase: string): boolean {
  return phrase
    .toLowerCase()
    .split(/[^a-z0-9+-]+/)
    .filter(Boolean)
    .some((token) => haystack.includes(token));
}

function traceClaim(claim: string, fact: UserProfile["strengths"][number], location: string) {
  return {
    claim,
    evidenceId: fact.id,
    evidenceLabel: fact.label,
    location
  };
}

function pickEvidence(profile: UserProfile, job: JobRecord, limit: number) {
  const description = `${job.role} ${job.description}`;
  const scored = profile.strengths.map((fact) => ({
    fact,
    score: evidenceRelevanceScore(fact, description)
  }));
  return scored
    .filter((item) => item.score >= minEvidenceRelevance)
    .sort((a, b) => b.score - a.score || a.fact.label.localeCompare(b.fact.label))
    .slice(0, limit)
    .map((item) => item.fact);
}

function evidenceRelevanceScore(fact: UserProfile["strengths"][number], targetText: string): number {
  const targetTokens = new Set(normalizedTokens(targetText));
  const exactTarget = targetText.toLowerCase();
  let score = 0;

  for (const tag of fact.tags) {
    const tagText = tag.toLowerCase();
    const tagTokens = normalizedTokens(tag);
    if (tagText.length > 0 && exactTarget.includes(tagText)) {
      score += 3;
    } else if (tagTokens.some((token) => targetTokens.has(token))) {
      score += 2;
    }
  }

  const factTokens = normalizedTokens(`${fact.label} ${fact.proof}`);
  score += Math.min(3, factTokens.filter((token) => targetTokens.has(token)).length);
  return score;
}

function normalizedTokens(text: string): string[] {
  return (text.toLowerCase().match(/[a-z][a-z0-9+-]{2,}/g) ?? [])
    .map((token) => token.replace(/s$/, ""))
    .filter((token) => !stopWords.has(token));
}

function buildEvidenceGaps(job: JobRecord, evidence: UserProfile["strengths"]): string[] {
  if (evidence.length === 0) {
    return [
      `No saved evidence meets the relevance threshold for ${job.role} at ${job.company}.`,
      `Add proof for one of these role themes: ${job.keywords.slice(0, 6).join(", ") || "the core requirement"}.`
    ];
  }

  const coveredTags = new Set(evidence.flatMap((fact) => fact.tags.map((tag) => tag.toLowerCase())));
  const uncovered = job.keywords.filter((keyword) => !coveredTags.has(keyword.toLowerCase())).slice(0, 4);
  return uncovered.length > 0 ? [`No saved evidence directly covers these role themes yet: ${uncovered.join(", ")}.`] : [];
}

function findEvidenceReferences(text: string, profile: UserProfile): string[] {
  const lower = text.toLowerCase();
  const textTokens = new Set(normalizedTokens(text));
  return profile.strengths
    .filter((fact) => {
      const label = fact.label.toLowerCase();
      const tagHit = fact.tags.some((tag) => normalizedTokens(tag).some((token) => textTokens.has(token)));
      const proofHit = normalizedTokens(fact.proof).filter((token) => textTokens.has(token)).length >= 2;
      return lower.includes(label) || tagHit || proofHit;
    })
    .map((fact) => fact.label);
}

function findUnsupportedClaims(sentences: string[], profile: UserProfile): string[] {
  return sentences.filter((sentence) => {
    const lower = sentence.toLowerCase();
    if (isAssumptionOrGap(sentence) || hasGroundedEvidenceReference(sentence, profile)) {
      return false;
    }
    return candidateClaimPattern.test(sentence) || unsupportedClaimPhrases.some((phrase) => lower.includes(phrase));
  });
}

function hasGroundedEvidenceReference(sentence: string, profile: UserProfile): boolean {
  const lower = sentence.toLowerCase();
  const textTokens = new Set(normalizedTokens(sentence));
  return profile.strengths.some((fact) => {
    const tagMatches = fact.tags.filter((tag) => normalizedTokens(tag).some((token) => textTokens.has(token))).length;
    const proofMatches = normalizedTokens(fact.proof).filter((token) => textTokens.has(token)).length;
    return lower.includes(fact.label.toLowerCase()) || tagMatches >= 2 || proofMatches >= 2;
  });
}

function isAssumptionOrGap(sentence: string): boolean {
  const lower = sentence.toLowerCase();
  return [
    "assumption",
    "assume",
    "appears",
    "seems",
    "likely",
    "not confirmed",
    "needs more evidence",
    "need more evidence",
    "before claiming",
    "should not claim",
    "do not claim",
    "missing evidence"
  ].some((marker) => lower.includes(marker));
}

function buildNextActions(score: number, risks: string[]): string[] {
  if (score >= 82) {
    return [
      "Build application pack.",
      "Research hiring manager and company priorities.",
      "Prepare user-reviewed browser steps."
    ];
  }
  if (score >= 58) {
    return [
      "Clarify missing fit evidence.",
      "Check compensation and location constraints.",
      "Draft only after risks are resolved."
    ];
  }
  return [
    "Save for reference but do not prioritize yet.",
    risks[0] ?? "Find stronger evidence before applying.",
    "Search for closer target roles."
  ];
}

function getDomain(text: string): string {
  const match = text.match(/https?:\/\/([^/\s]+)/i);
  return match?.[1]?.replace(/^www\./, "").toLowerCase() ?? "";
}

const intentRoutes: Array<{ intent: AgentCommandResult["intent"]; keywords: string[] }> = [
  { intent: "goal", keywords: ["goal", "/goal", "objective", "success criteria"] },
  { intent: "interview", keywords: ["interview", "mock", "onsite", "panel"] },
  { intent: "intelligence", keywords: ["market", "competitor", "competitors", "job board", "source", "sources", "playbook", "features", "landscape"] },
  { intent: "research", keywords: ["research", "company", "hiring manager"] },
  { intent: "profile", keywords: ["linkedin", "profile"] },
  { intent: "network", keywords: ["outreach", "recruiter", "network", "follow up"] },
  { intent: "integrate", keywords: ["hermes", "telegram", "codex", "claude", "cursor", "opencode", "grok", "plugin", "plugins", "connection", "connections", "google", "gmail", "drive", "calendar", "github", "figma", "railway", "hugging face", "microsoft", "outlook", "onedrive", "notion", "linear"] },
  { intent: "apply", keywords: ["apply", "application", "cover", "resume", "screening"] },
  { intent: "track", keywords: ["track", "status", "ledger", "pipeline"] }
];

function buildToolHints(intent: AgentCommandResult["intent"]): string[] {
  switch (intent) {
    case "goal":
      return ["jobmaxxing_status", "jobmaxxing_automation_plan", "jobmaxxing_command"];
    case "intelligence":
      return ["jobmaxxing_market_research", "jobmaxxing_automation_plan", "jobmaxxing_command"];
    case "apply":
      return ["jobmaxxing_draft_application", "jobmaxxing_audit_text", "jobmaxxing_browser_plan"];
    case "interview":
      return ["jobmaxxing_interview_pack", "jobmaxxing_company_research_prompt"];
    case "research":
      return ["jobmaxxing_company_research_prompt", "jobmaxxing_log_activity"];
    case "integrate":
      return ["jobmaxxing_status", "jobmaxxing_hermes_status", "jobmaxxing_browser_plan"];
    case "profile":
      return ["jobmaxxing_status", "jobmaxxing_log_activity"];
    case "network":
      return ["jobmaxxing_draft_application", "jobmaxxing_log_activity"];
    case "track":
      return ["jobmaxxing_status", "jobmaxxing_log_activity"];
    case "discover":
      return ["jobmaxxing_add_job", "jobmaxxing_browser_plan"];
  }
}

function buildIntentActions(intent: AgentCommandResult["intent"], topJob: JobRecord | undefined): string[] {
  const roleLabel = topJob ? `${topJob.role} at ${topJob.company}` : "the next saved role";
  switch (intent) {
    case "goal":
      return ["Restate the job-search objective.", "Break it into sourcing, drafting, interview prep, and validation steps.", "Log only user-approved external actions."];
    case "intelligence":
      return ["Open the intelligence catalog.", "Choose a source or playbook.", "Route the next agent command with safety gates."];
    case "apply":
      return [`Draft the application pack for ${roleLabel}.`, "Run claim trace review.", "Ask for final user approval."];
    case "interview":
      return [`Build a mock interview pack for ${roleLabel}.`, "Research the company.", "Run one text rehearsal."];
    case "research":
      return [`Prepare a company brief for ${roleLabel}.`, "Find people and product context from public sources."];
    case "integrate":
      return ["Use MCP for agent tools.", "Keep Hermes as a linked local dependency.", "Document Telegram setup."];
    case "profile":
      return ["Review LinkedIn headline.", "Convert profile bullets into evidence facts.", "Remove unsupported claims."];
    case "network":
      return ["Draft recruiter outreach.", "Draft a follow-up.", "Log the contact and response."];
    case "track":
      return ["Update stage.", "Log what changed.", "Pick the next highest-score role."];
    case "discover":
      return ["Find high-fit roles.", "Paste job descriptions into Jobmaxxing.", "Skip low-signal roles fast."];
  }
}
