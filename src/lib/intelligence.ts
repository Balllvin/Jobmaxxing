import type {
  AutomationPlaybook,
  JobBoardSource,
  MarketComplaint,
  MarketIntelligence,
  CompetitorApp
} from "./types";

export const competitorApps: CompetitorApp[] = [
  {
    id: "teal",
    name: "Teal",
    category: "Tracker and resume workspace",
    url: "https://www.tealhq.com/tools/job-tracker",
    summary: "Job tracker, browser save flow, keywords, notes, statuses, resumes, and contact/company organization.",
    usefulPatterns: ["Save from many boards", "Keyword review", "Pipeline stages", "Weekly goals"],
    gaps: ["Writing can still become generic", "Not an agent command center", "Browser actions live outside the app"],
    jobmaxxingResponse: ["Evidence-first tracker", "Agent command routing", "Local documents and claim trace"]
  },
  {
    id: "simplify",
    name: "Simplify",
    category: "Autofill and copilot extension",
    url: "https://simplify.jobs/copilot",
    summary: "Autofills repetitive fields, generates tailored answers, and tracks submitted applications.",
    usefulPatterns: ["Application autofill", "Question answer drafting", "Automatic tracking", "Browser extension reach"],
    gaps: ["User still needs fit judgment", "Autofill does not prove claims", "Platform trust depends on browser context"],
    jobmaxxingResponse: ["Manual-submit policy", "Claim-backed answers", "Deterministic form data preparation"]
  },
  {
    id: "huntr",
    name: "Huntr",
    category: "Job CRM and resume builder",
    url: "https://huntr.co/",
    summary: "Job board, notes, dates, contact tracker, interview tracker, map view, resume tools, and one-click autofill.",
    usefulPatterns: ["Purpose-built job CRM", "Interview tracking", "Contact tracking", "Saved posting details"],
    gaps: ["Less agent-native", "Limited programmable workflow handoff", "Needs stronger source intelligence"],
    jobmaxxingResponse: ["MCP-first tools", "Agent playbooks", "Source-by-source safety gates"]
  },
  {
    id: "jobscan",
    name: "Jobscan",
    category: "ATS optimization",
    url: "https://www.jobscan.co/",
    summary: "Compares resume to job listings, exposes keyword and formatting gaps, and supports review-before-send auto apply.",
    usefulPatterns: ["ATS match report", "Missing skill detection", "Resume formatting checks", "Review-before-send"],
    gaps: ["Can over-optimize keywords", "ATS scoring is not the same as hiring fit", "Weak on application operations"],
    jobmaxxingResponse: ["Keyword extraction as one signal", "Human-readable evidence gap map", "No keyword stuffing"]
  },
  {
    id: "rezi",
    name: "Rezi",
    category: "Resume and cover letter builder",
    url: "https://www.rezi.ai/",
    summary: "Resume builder and AI writing tool focused on ATS-friendly resumes, cover letters, and content scoring.",
    usefulPatterns: ["Resume scoring", "ATS templates", "Cover letter generation", "Bullet rewrites"],
    gaps: ["Can reward formatting compliance over actual proof", "Needs stronger source and outcome tracking"],
    jobmaxxingResponse: ["Application pack diff", "Evidence coverage checks", "Readable proof over keyword stuffing"]
  },
  {
    id: "resume-worded",
    name: "Resume Worded",
    category: "Resume feedback",
    url: "https://resumeworded.com/",
    summary: "Resume and LinkedIn profile review with structured feedback, scoring, and improvement suggestions.",
    usefulPatterns: ["Resume rubric", "LinkedIn review", "Actionable feedback", "Score history"],
    gaps: ["Feedback can be detached from specific target roles", "No browser or recruiter workflow"],
    jobmaxxingResponse: ["Role-specific score", "Evidence-linked rewrites", "Profile-to-application consistency"]
  },
  {
    id: "loopcv",
    name: "LoopCV",
    category: "Always-on auto apply",
    url: "https://www.loopcv.pro/jobseekers/",
    summary: "Runs job searches, applies across boards, sends outreach, and tracks opens, replies, boards, and CV versions.",
    usefulPatterns: ["Continuous search campaigns", "Board performance metrics", "Email outreach", "Parallel searches"],
    gaps: ["High-volume apply can damage signal", "Protected-site automation risk", "Quality depends on filters"],
    jobmaxxingResponse: ["Quality-first source queue", "Human submit gate", "Weekly board ROI review"]
  },
  {
    id: "lazyapply",
    name: "LazyApply",
    category: "Auto-apply extension",
    url: "https://lazyapply.com/",
    summary: "Browser-based auto-apply workflow for applying to many roles across job boards.",
    usefulPatterns: ["High-volume automation", "Board-specific flows", "Fast repetitive form handling"],
    gaps: ["Quality and support concerns are common with auto-apply tools", "Mass volume can hurt candidate signal"],
    jobmaxxingResponse: ["Daily caps by quality score", "Manual protected-site mode", "Outcome learning before scaling"]
  },
  {
    id: "aihawk",
    name: "AIHawk",
    category: "Open-source application agent",
    url: "https://github.com/feder-cr/jobs_applier_ai_agent_aihawk",
    summary: "Open-source agent pattern for automated job applications and answer generation.",
    usefulPatterns: ["Scriptable pipeline", "Open-source inspectability", "Agent exception handling"],
    gaps: ["Automation can collide with site rules", "Needs consent, source trust, and evidence gates"],
    jobmaxxingResponse: ["Open local ledger", "Protected-domain policy", "Human approval before external action"]
  },
  {
    id: "sonara",
    name: "Sonara",
    category: "AI job search automation",
    url: "https://www.sonara.ai/",
    summary: "Learns the user profile, finds jobs, and applies to relevant openings until the user is hired.",
    usefulPatterns: ["Profile intake", "Continuous matching", "Done-for-you flow", "Wide funnel"],
    gaps: ["Opaque decisions", "Hard to inspect every claim", "Can drift from user voice"],
    jobmaxxingResponse: ["Auditable decisions", "User voice memory", "Agent runs with visible evidence"]
  },
  {
    id: "interviewing-io",
    name: "interviewing.io",
    category: "Interview prep",
    url: "https://interviewing.io/",
    summary: "Mock technical interviews and practice with experienced interviewers.",
    usefulPatterns: ["Realistic practice", "Feedback loops", "Technical drill structure"],
    gaps: ["Separate from application evidence and company research", "Can be expensive or scheduling-heavy"],
    jobmaxxingResponse: ["Evidence-based answer drills", "Company-specific practice", "Transcript critique"]
  },
  {
    id: "big-interview",
    name: "Big Interview",
    category: "Interview prep",
    url: "https://www.biginterview.com/",
    summary: "Interview training, question libraries, practice recordings, and coaching workflows.",
    usefulPatterns: ["Question banks", "Video practice", "Rubrics", "Role preparation"],
    gaps: ["Not integrated with actual saved jobs and proof links", "Less agent-programmable"],
    jobmaxxingResponse: ["Saved-job war room", "Proof-linked story bank", "Mode-specific mock sessions"]
  },
  {
    id: "final-round-ai",
    name: "Final Round AI",
    category: "Interview assistant",
    url: "https://www.finalroundai.com/",
    summary: "AI interview preparation and live interview assistance product category.",
    usefulPatterns: ["Transcript analysis", "Question prediction", "Real-time answer support"],
    gaps: ["Stealth live assistance can become misrepresentation", "Prep and live cheating must stay separated"],
    jobmaxxingResponse: ["Prep-only transcripts", "No stealth live answers", "Practice critique with evidence trace"]
  },
  {
    id: "wellfound",
    name: "Wellfound",
    category: "Startup job board",
    url: "https://wellfound.com/",
    summary: "Startup roles with founder access, salary/equity signals, profile-based applying, and featured candidate workflows.",
    usefulPatterns: ["Salary and equity upfront", "Founder contact", "Profile as application", "Startup-specific signals"],
    gaps: ["Narrower market coverage", "Profile quality matters heavily", "Follow-up still manual"],
    jobmaxxingResponse: ["Startup-specific fit score", "Founder outreach drafts", "Compensation question prep"]
  },
  {
    id: "welcome-to-the-jungle",
    name: "Welcome to the Jungle",
    category: "Matching and company research",
    url: "https://www.welcometothejungle.com/en",
    summary: "Matches users to roles, lets recruiters find profiles, and exposes richer company pages.",
    usefulPatterns: ["Company culture research", "Profile-driven matching", "Recruiter inbound", "Candidate coach"],
    gaps: ["Company story can outweigh hard proof", "Coverage varies by geography", "Needs external tracking"],
    jobmaxxingResponse: ["Company research brief", "Role fit notes", "External tracker ingestion"]
  },
  {
    id: "linkedin",
    name: "LinkedIn Jobs",
    category: "Networked job board",
    url: "https://www.linkedin.com/help/linkedin/answer/a511260",
    summary: "Search, filters, alerts, saved jobs, Easy Apply, external apply, Open to Work, and network context.",
    usefulPatterns: ["Network graph", "Job alerts", "Saved jobs", "Easy Apply", "Profile leverage"],
    gaps: ["Application volume is noisy", "Protected-site automation constraints", "Generic outreach is ignored"],
    jobmaxxingResponse: ["Manual LinkedIn assist", "Referral map", "Proof-backed outreach"]
  },
  {
    id: "glassdoor",
    name: "Glassdoor",
    category: "Reviews and salary intelligence",
    url: "https://www.glassdoor.com/index.htm",
    summary: "Jobs, anonymous reviews, salary comparisons, company ratings, and workplace discussion.",
    usefulPatterns: ["Review mining", "Salary research", "Interview expectations", "Company risk checks"],
    gaps: ["Crowdsourced data needs verification", "Not enough workflow control", "Review sentiment can be noisy"],
    jobmaxxingResponse: ["Research brief with uncertainty labels", "Compensation prep", "Company risk summary"]
  }
];

export const jobBoardSources: JobBoardSource[] = [
  {
    id: "linkedin-jobs",
    name: "LinkedIn Jobs",
    category: "Network and protected board",
    url: "https://www.linkedin.com/jobs",
    bestFor: "Warm referrals, recruiter context, saved searches, and profile-driven discovery.",
    usefulSignals: ["Mutual connections", "Hiring team", "Applicant count", "Open to Work fit", "Company posts"],
    deterministicSteps: ["Normalize job URL", "Extract company and role", "Dedupe saved jobs", "Record alert query"],
    agentSteps: ["Draft referral ask", "Review profile gaps", "Write concise contact message"],
    safetyChecks: ["No hidden scraping", "No auto-submit", "No messages without user approval"]
  },
  {
    id: "indeed",
    name: "Indeed",
    category: "High-volume job board",
    url: "https://www.indeed.com/",
    bestFor: "Broad market coverage, salary comparisons, reviews, alerts, and quick screening.",
    usefulSignals: ["Posting freshness", "Salary", "Review context", "Location fit", "Qualification prompts"],
    deterministicSteps: ["Extract role facts", "Flag salary visibility", "Track employer duplicates"],
    agentSteps: ["Assess noisy postings", "Prepare screening answers", "Compare similar roles"],
    safetyChecks: ["Manual submit by default", "Avoid duplicate applications", "Verify employer legitimacy"]
  },
  {
    id: "greenhouse",
    name: "Greenhouse",
    category: "ATS",
    url: "https://www.greenhouse.com/",
    bestFor: "Direct company applications with clearer role pages and structured questions.",
    usefulSignals: ["Department", "Office", "Application questions", "Source company domain"],
    deterministicSteps: ["Parse ATS URL", "Save questions", "Map required fields", "Snapshot posting text"],
    agentSteps: ["Tailor answers", "Build proof map", "Prepare browser steps"],
    safetyChecks: ["Stop before submit", "Do not invent required fields", "Keep file uploads explicit"]
  },
  {
    id: "lever",
    name: "Lever",
    category: "ATS",
    url: "https://www.lever.co/",
    bestFor: "Direct startup and tech applications with compact posting pages.",
    usefulSignals: ["Team", "location", "custom questions", "company careers page"],
    deterministicSteps: ["Parse posting", "Extract question set", "Dedupe company role pair"],
    agentSteps: ["Generate answers", "Find team context", "Draft follow-up"],
    safetyChecks: ["User controls final submit", "No fabricated work authorization", "No unsupported claims"]
  },
  {
    id: "workday",
    name: "Workday",
    category: "Enterprise ATS",
    url: "https://www.workday.com/",
    bestFor: "Large-company roles where application forms are long and repetitive.",
    usefulSignals: ["Requisition ID", "location", "business unit", "application status"],
    deterministicSteps: ["Store profile field answers", "Track account domain", "Flag repeated questions"],
    agentSteps: ["Prepare answers", "Summarize why the form is worth completing", "Write follow-up notes"],
    safetyChecks: ["No credential storage", "No captcha bypass", "User reviews every field"]
  },
  {
    id: "wellfound-source",
    name: "Wellfound",
    category: "Startup board",
    url: "https://wellfound.com/",
    bestFor: "Startup salary/equity visibility, founder contact, and fast profile-based applications.",
    usefulSignals: ["Salary", "equity", "founder access", "company stage", "remote fit"],
    deterministicSteps: ["Extract compensation range", "Capture equity", "Tag startup stage"],
    agentSteps: ["Write founder note", "Prepare equity questions", "Research funding and customers"],
    safetyChecks: ["Verify current company data", "Separate facts from assumptions", "No fake enthusiasm"]
  },
  {
    id: "glassdoor-source",
    name: "Glassdoor",
    category: "Company intelligence",
    url: "https://www.glassdoor.com/index.htm",
    bestFor: "Salary, review, interview, and culture risk research before applying or interviewing.",
    usefulSignals: ["Salary range", "review themes", "interview reports", "CEO approval", "benefits"],
    deterministicSteps: ["Attach research URL", "Record salary range", "Capture recurring review themes"],
    agentSteps: ["Summarize risk", "Prepare interview questions", "Check compensation leverage"],
    safetyChecks: ["Mark crowdsourced data as uncertain", "Cross-check claims", "Avoid quoting private posts"]
  },
  {
    id: "ziprecruiter",
    name: "ZipRecruiter",
    category: "Job board and alerts",
    url: "https://www.ziprecruiter.com/mobile",
    bestFor: "One-tap applications, viewed-application alerts, salary search, and broad listings.",
    usefulSignals: ["Viewed notification", "one-tap eligibility", "salary data", "local job alerts"],
    deterministicSteps: ["Record one-tap status", "Track viewed alerts", "Dedupe syndicated jobs"],
    agentSteps: ["Decide whether quick apply is too weak", "Draft short note", "Plan follow-up"],
    safetyChecks: ["No blind one-tap apply", "Review note before send", "Avoid duplicate syndicated roles"]
  }
];

export const automationPlaybooks: AutomationPlaybook[] = [
  {
    id: "source-radar",
    title: "Source Radar",
    goal: "Find high-fit roles across boards without flooding the funnel.",
    trigger: "User asks for new roles, source strategy, or a job-board playbook.",
    deterministicSteps: ["Run saved search templates", "Normalize URLs", "Dedupe company-role pairs", "Score keyword overlap"],
    agentSteps: ["Reject noisy roles", "Explain fit gaps", "Prioritize top targets", "Suggest referral paths"],
    safetyChecks: ["Do not scrape protected pages without user action", "Keep rejected roles inspectable"],
    outputs: ["Ranked target list", "Rejected-role reasons", "Search query updates"]
  },
  {
    id: "ats-field-kit",
    title: "ATS Field Kit",
    goal: "Turn a long application form into approved, reusable answers.",
    trigger: "User pastes a job form or asks for browser steps.",
    deterministicSteps: ["Extract field labels", "Match known profile answers", "Detect required uploads", "Flag missing facts"],
    agentSteps: ["Draft custom answers", "Ask for missing facts", "Create a user-review checklist"],
    safetyChecks: ["No invented employment facts", "No credential capture", "No final submit"],
    outputs: ["Copy-ready answer set", "Missing fact list", "Browser checkpoint"]
  },
  {
    id: "resume-gap-map",
    title: "Resume Gap Map",
    goal: "Show what the resume proves, what the role asks for, and what cannot be claimed.",
    trigger: "User imports a resume or saves a new role.",
    deterministicSteps: ["Extract JD keywords", "Extract resume terms", "Compute missing terms", "Attach source document IDs"],
    agentSteps: ["Separate real gaps from wording gaps", "Rewrite bullets with proof", "Warn against keyword stuffing"],
    safetyChecks: ["Every added claim needs evidence", "Keep unsupported gaps visible"],
    outputs: ["Gap matrix", "Resume bullet edits", "Claim trace"]
  },
  {
    id: "source-trust-check",
    title: "Source Trust Check",
    goal: "Catch scams, stale posts, duplicate syndication, and weak source signals before applying.",
    trigger: "User saves a role from an unfamiliar source or a high-volume board.",
    deterministicSteps: ["Compare job domain to company domain", "Check salary visibility", "Detect duplicate role URLs", "Flag vague remote terms"],
    agentSteps: ["Assess scam risk", "Research company legitimacy", "Decide whether to skip or request clarification"],
    safetyChecks: ["Do not enter personal data into suspicious forms", "Never pay to apply", "Verify recruiter identity"],
    outputs: ["Source trust score", "Scam flags", "Skip-or-continue recommendation"]
  },
  {
    id: "application-pack-diff",
    title: "Application Pack Diff",
    goal: "Show exactly what changed from the base resume or draft and why it changed.",
    trigger: "User generates a role-specific application pack.",
    deterministicSteps: ["Compare base and tailored bullets", "Map changed phrases", "Attach evidence IDs", "Flag unsupported additions"],
    agentSteps: ["Explain why each change helps", "Remove overfitting", "Rewrite weak claims"],
    safetyChecks: ["No hidden additions", "No unsupported metrics", "No keyword stuffing"],
    outputs: ["Diff summary", "Claim trace", "Approval checklist"]
  },
  {
    id: "recruiter-brief",
    title: "Recruiter Brief",
    goal: "Prepare concise outreach that sounds human and references one proof link.",
    trigger: "User finds a recruiter, founder, or likely hiring manager.",
    deterministicSteps: ["Save contact URL", "Link target job", "Select strongest evidence", "Build follow-up reminder"],
    agentSteps: ["Draft first message", "Draft follow-up", "Research public context", "Trim slop"],
    safetyChecks: ["No mass messaging", "User approves before sending", "No private-data assumptions"],
    outputs: ["Initial message", "Follow-up", "Contact ledger entry"]
  },
  {
    id: "contact-ledger",
    title: "Contact Ledger",
    goal: "Track recruiters, founders, referrals, messages, and follow-up cadence without sales-spam behavior.",
    trigger: "User finds a contact or asks for outreach.",
    deterministicSteps: ["Link person to role", "Record source URL", "Schedule follow-up", "Track response state"],
    agentSteps: ["Draft one-message outreach", "Personalize from public facts", "Recommend whether to follow up"],
    safetyChecks: ["No mass messaging", "No private-data assumptions", "Respect opt-outs"],
    outputs: ["Contact record", "Approved message", "Follow-up state"]
  },
  {
    id: "interview-war-room",
    title: "Interview War Room",
    goal: "Prepare stories, research, questions, and scorecards for every interview format.",
    trigger: "Job moves to interviewing or user requests practice.",
    deterministicSteps: ["Collect job facts", "Attach company URLs", "Select interview mode", "Build question bank"],
    agentSteps: ["Write story outlines", "Generate role-specific questions", "Critique practice answers"],
    safetyChecks: ["Do not fabricate company facts", "Label assumptions", "Avoid memorized-sounding answers"],
    outputs: ["Interview pack", "Practice scorecard", "Company research brief"]
  },
  {
    id: "interview-transcript-review",
    title: "Interview Transcript Review",
    goal: "Turn practice transcripts into sharper stories and targeted drills.",
    trigger: "User imports a mock interview transcript or writes practice answers.",
    deterministicSteps: ["Split questions and answers", "Measure answer length", "Detect missing proof", "Tag repeated weak claims"],
    agentSteps: ["Critique answer structure", "Suggest stronger evidence", "Create next practice drill"],
    safetyChecks: ["Prep only", "No stealth live interview assistance", "No fabricated experience"],
    outputs: ["Transcript scorecard", "Story edits", "Next drills"]
  },
  {
    id: "weekly-hunt-retro",
    title: "Weekly Hunt Retro",
    goal: "Learn which sources, resume versions, and message styles create real replies.",
    trigger: "User asks what to improve or enough events have accumulated.",
    deterministicSteps: ["Aggregate saved roles", "Count stages", "Compare source outcomes", "List stale follow-ups"],
    agentSteps: ["Spot weak patterns", "Suggest next experiments", "Update writing memory"],
    safetyChecks: ["Do not overfit tiny samples", "Keep recommendations reversible"],
    outputs: ["Source ROI", "Next experiments", "Prompt memory updates"]
  }
];

export const marketComplaints: MarketComplaint[] = [
  {
    id: "bot-spray",
    pattern: "Mass auto-apply tools bury thoughtful applications in low-quality volume.",
    impact: "Recruiters tighten filters, add more screening, and thoughtful candidates lose signal.",
    jobmaxxingResponse: "Optimize for fit, proof, and user-approved actions instead of raw application count.",
    sourceUrl: "https://www.reddit.com/r/recruitinghell/comments/1tt50ml/autoapplying_bots_are_killing_honest_job_seekers/"
  },
  {
    id: "workday-fatigue",
    pattern: "Long ATS forms cause applicants to abandon roles mid-process.",
    impact: "Good roles are skipped because repetitive forms consume too much time.",
    jobmaxxingResponse: "Prepare reusable field kits and missing-fact prompts while keeping the user in control.",
    sourceUrl: "https://simplify.jobs/blog/why-candidates-hate-workday"
  },
  {
    id: "ai-slop",
    pattern: "Generic AI resumes and cover letters make candidates sound interchangeable.",
    impact: "Applications can look polished but empty, weakening trust with recruiters.",
    jobmaxxingResponse: "Use Amazon-style writing, user voice memory, proof links, and slop audits before sending.",
    sourceUrl: "https://www.businessinsider.com/mistakes-job-seekers-avoid-using-ai-resumes-cover-letters-networking-2026-4"
  },
  {
    id: "opaque-tools",
    pattern: "Done-for-you tools hide why a job was selected or what got submitted.",
    impact: "Users cannot learn, debug, or confidently explain their own application strategy.",
    jobmaxxingResponse: "Expose command history, evidence trace, source reasoning, and approval state in the local ledger.",
    sourceUrl: "https://www.sonara.ai/"
  }
];

export function buildMarketIntelligence(): MarketIntelligence {
  return {
    competitors: competitorApps,
    jobBoards: jobBoardSources,
    playbooks: automationPlaybooks,
    complaints: marketComplaints,
    opportunities: [
      "Source radar that ranks opportunities before application work begins.",
      "Source trust checks for scams, stale posts, duplicate syndication, and vague remote roles.",
      "ATS field kits that make repetitive applications deterministic and reviewable.",
      "Resume gap maps that separate real missing evidence from simple wording gaps.",
      "Application pack diffs that explain every role-specific change before sending.",
      "Contact ledgers for recruiters, founders, referrals, follow-ups, and consent state.",
      "Human-submit browser mode for protected sites, with copy-ready answers.",
      "Prep-only interview transcript review with no stealth live-answer assistance.",
      "Recruiter and founder outreach that uses one proof link instead of generic praise.",
      "Weekly hunt retros that update prompts, source strategy, and model routing from outcomes."
    ]
  };
}

export function buildAutomationPlaybook(input: { playbookId?: string; goal?: string }): AutomationPlaybook {
  const normalizedGoal = input.goal?.toLowerCase().trim() ?? "";
  const exact = input.playbookId
    ? automationPlaybooks.find((playbook) => playbook.id === input.playbookId)
    : undefined;
  if (exact) {
    return exact;
  }

  const goalTokens = normalizedGoal.split(/[^a-z0-9]+/).filter((token) => token.length > 2);
  const byGoal = goalTokens.length
    ? automationPlaybooks
        .map((playbook, index) => {
          const text = [playbook.id, playbook.title, playbook.goal, playbook.trigger, ...playbook.outputs]
            .join(" ")
            .toLowerCase();
          const score = goalTokens.filter((token) => text.includes(token)).length;
          return { playbook, score, index };
        })
        .sort((a, b) => b.score - a.score || a.index - b.index)
        .find((item) => item.score > 0)?.playbook
    : undefined;

  return byGoal ?? automationPlaybooks[0];
}
