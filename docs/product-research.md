# Product Research

## Market Pattern

Public research shows six broad categories:

- autonomous auto-apply agents
- commercial resume/job trackers
- autofill/browser extensions
- ATS and resume optimization tools
- job boards and company intelligence sites
- local-first job command centers
- platform-native AI assistants

Examples:

- ApplyPilot: https://github.com/Pickle-Pixel/ApplyPilot
- AIHawk: https://github.com/feder-cr/jobs_applier_ai_agent_aihawk
- career-ops: https://career-ops.org/
- Simplify: https://simplify.jobs/copilot
- Teal: https://www.tealhq.com/tools/job-tracker
- Huntr: https://huntr.co/
- Jobscan: https://www.jobscan.co/
- Rezi: https://www.rezi.ai/
- Resume Worded: https://resumeworded.com/
- LoopCV: https://www.loopcv.pro/jobseekers/
- Sonara: https://www.sonara.ai/
- LazyApply: https://lazyapply.com/
- AIHawk: https://github.com/feder-cr/jobs_applier_ai_agent_aihawk
- interviewing.io: https://interviewing.io/
- Big Interview: https://www.biginterview.com/
- Final Round AI: https://www.finalroundai.com/
- LinkedIn Jobs: https://www.linkedin.com/help/linkedin/answer/a511260
- Wellfound: https://wellfound.com/
- Welcome to the Jungle: https://www.welcometothejungle.com/en
- Glassdoor: https://www.glassdoor.com/index.htm
- ZipRecruiter: https://www.ziprecruiter.com/mobile

## What Competitors Actually Do

- Teal and Huntr organize the job search: save jobs, track stages, attach notes, manage resumes, and keep contacts in one place.
- Simplify reduces repetitive form filling: autofill, tailored answers, and automatic tracking after submission.
- Jobscan, Rezi, and Resume Worded optimize resume quality: keyword gaps, ATS formatting, match reports, resume scoring, and profile feedback.
- LoopCV and Sonara push toward automation: match jobs from multiple sources, apply in bulk or continuously, and track responses.
- LazyApply and AIHawk show the high-volume browser-agent pattern: script the repetitive work, generate answers, and handle exceptions.
- Interviewing tools prepare candidates with human mocks, AI mocks, transcripts, rubrics, and sometimes risky live assistance.
- LinkedIn, Wellfound, Welcome to the Jungle, Glassdoor, and ZipRecruiter own source-specific signals: network graph, salary/equity, company culture, reviews, alerts, one-tap apply, and profile-based matching.

## Product Opening

The market already has tools that promise high-volume applying. That is not the durable wedge.

Jobmaxxing should win by being:

- local-first
- consent-first
- evidence-backed
- agent-native
- writing-quality obsessed
- strong on tracking and interview preparation
- source-aware: each board and ATS gets a different workflow
- deterministic where possible: parse, dedupe, score, and track before asking an agent to judge or write

## Feature Requirements

- application ledger
- profile evidence vault
- job intake and scoring
- source intelligence catalog
- competitor feature matrix
- deterministic-plus-agent automation playbooks
- job-board safety policies by source
- source trust checks for scams, stale posts, vague remote roles, and duplicate syndicated listings
- application pack diffs that show what changed and which evidence supports it
- contact ledger for recruiters, founders, referrals, cadence, and consent state
- interview transcript review for practice sessions only
- proof-backed application pack
- recruiter outreach drafts
- follow-up drafts
- company and people research prompts
- mock interview packs
- LinkedIn profile improvement checklist
- browser action plan with policy gates
- model tier settings
- user writing memory
- MCP and CLI integration

## Complaints To Design Against

- Auto-apply tools can bury thoughtful applications in low-quality volume: https://www.reddit.com/r/recruitinghell/comments/1tt50ml/autoapplying_bots_are_killing_honest_job_seekers/
- Workday-style forms drive abandonment because they are long and repetitive: https://simplify.jobs/blog/why-candidates-hate-workday
- AI-generated applications can sound polished but generic: https://www.businessinsider.com/mistakes-job-seekers-avoid-using-ai-resumes-cover-letters-networking-2026-4
- Done-for-you tools can hide why a job was chosen or what was submitted.
- Live interview copilots can cross into misrepresentation if they feed answers during real interviews.

Jobmaxxing therefore exposes the source plan, deterministic steps, agent steps, safety gates, and command history.
Interview tooling stays prep-only: transcripts, mock sessions, story drills, and critique are allowed; stealth live-answer assistance is not.

## Known Risks

- protected-site automation can violate site rules
- mass applications can damage candidate signal
- AI-generated writing can look generic
- unsupported claims can create integrity and interview risk
- too many MCP tools can burn agent context

The implementation therefore keeps the default MCP tool set compact and uses staged approval rather than hidden action.
