import type { JobmaxxingStore } from "./types";
import { defaultCompanyProfiles } from "./companies";

export const defaultStore: JobmaxxingStore = {
  schema: "jobmaxxing-store",
  revision: 1,
  currentGoal: undefined,
  profile: {
    name: "Local Candidate",
    targetRoles: ["AI product engineer", "founding engineer", "automation engineer"],
    locations: ["remote", "Zurich", "London", "New York"],
    compensationGoal: "High-upside role with strong base, equity, or clear contracting budget.",
    workAuthorization: "User should confirm eligibility per role before applying.",
    strengths: [
      {
        id: "fact-agent-systems",
        label: "Built agent workflows",
        proof:
          "Designed multi-step agent workflows with browser use, local data, review loops, and explicit safety gates.",
        tags: ["agents", "automation", "workflow", "browser", "review"]
      },
      {
        id: "fact-product-speed",
        label: "Ships product quickly",
        proof:
          "Turns vague product goals into working local apps with tests, documentation, and a clear user workflow.",
        tags: ["product", "frontend", "typescript", "testing", "documentation"]
      },
      {
        id: "fact-finance-domain",
        label: "Understands finance and operations",
        proof:
          "Has worked with financial workflows, local ledgers, account data, and decision dashboards.",
        tags: ["finance", "operations", "data", "dashboard"]
      }
    ],
    experience: [
      {
        id: "exp-agent-product-work",
        title: "Builder",
        organization: "Independent projects",
        location: "Remote",
        period: "Recent work",
        summary:
          "Built agent systems, local products, and finance-facing tools with review gates and clear proof.",
        bullets: [
          "Designed multi-step agent workflows with browser use, local data, and safety gates.",
          "Shipped local apps with tests and documentation.",
          "Worked with financial workflows, ledgers, and decision dashboards."
        ],
        projects: [
          {
            id: "proj-agent-workflows",
            name: "Agent workflow systems",
            summary: "Multi-step agent workflows with review loops.",
            detail:
              "Designed agent workflows that combine browser use, local data, review loops, and explicit safety gates before external actions. Focus stayed on inspectable steps rather than black-box automation.",
            specificSample:
              "One system routes a task through research, local evidence lookup, draft generation, and a human approval gate before any external send or submit.",
            tools: ["TypeScript", "agents", "browser tools"],
            metrics: [],
            tags: ["agents", "automation", "review"],
            sourceUrl: ""
          }
        ],
        sourceUrl: ""
      }
    ],
    dealBreakers: ["Unclear ownership", "No room to automate", "Heavy meeting culture"],
    styleGuide: [
      "Write like a competent operator, not a generic applicant.",
      "Answer interest and capability. Broad themes first, then one specific sample.",
      "Open with 'I am interested in the [role] role at [company].'",
      "Vary sentence openings. Do not stack many sentences starting with I.",
      "Sound humble and capable. Prefer concrete past work over self-praise or service pitches.",
      "Do not restate the company, paraphrase the posting, or offer to start on their tasks.",
      "Write for HR first: plain English, no insider finance shorthand unless explained.",
      "Broad themes first, then 'For example,' and dig into one specific piece of work.",
      "Do not repeat the same phrase in the broad block and the example.",
      "Close in full sentences: My CV is attached. I would look forward to hearing back from you and learning more about the role.",
      "Avoid inflated claims that are not backed by saved evidence."
    ],
    writingRules: [
      {
        id: "amazon-short-sentences",
        label: "Short sentences",
        instruction: "Keep most sentences under 30 words. Split long chains before they hide the point.",
        severity: "required"
      },
      {
        id: "amazon-subject-verb-object",
        label: "Subject-verb-object",
        instruction: "Use direct subject-verb-object sentences. Name the actor and action.",
        severity: "required"
      },
      {
        id: "amazon-data-over-adjectives",
        label: "Proof over adjectives",
        instruction: "Replace adjectives with concrete evidence, numbers, scope, or constraints.",
        severity: "required"
      },
      {
        id: "amazon-no-weasel",
        label: "No weasel words",
        instruction: "Avoid vague hedges like might, could, should, various, several, very, and really.",
        severity: "required"
      },
      {
        id: "anti-ai-slop",
        label: "Anti-slop voice",
        instruction: "Avoid generic AI phrasing, inflated arcs, patronizing brand flattery, and unsupported enthusiasm.",
        severity: "required"
      },
      {
        id: "clear-interest",
        label: "Clear interest",
        instruction: "Open with interest in the named role. Prefer 'I am interested in the [role] role at [company]' over 'I am applying for'.",
        severity: "required"
      },
      {
        id: "two-questions-only",
        label: "Two questions only",
        instruction: "Every sentence must help answer: is the user interested, or have they done similar work that looks real? Delete the rest.",
        severity: "required"
      },
      {
        id: "proof-not-mapping",
        label: "Proof not mapping talk",
        instruction: "Show similar work with facts. Do not write 'the role maps to', restate the posting, or lecture the company about itself.",
        severity: "required"
      },
      {
        id: "humble-confidence",
        label: "Humble confidence",
        instruction: "Sound grounded. Prefer 'I built X' over self-praise, begging, unique-fit claims, or 'I can start on Y for you'.",
        severity: "required"
      },
      {
        id: "broad-then-specific",
        label: "Broad then specific",
        instruction: "After interest, give a plain-English broad picture of relevant work. Then start a sample with 'For example,' and dig into ONE part of ONE project. Do not repeat the same phrases in both blocks.",
        severity: "required"
      },
      {
        id: "know-your-audience",
        label: "Know your audience",
        instruction: "Write for HR or a general hiring reader first. Prefer plain words over compressed finance jargon. Add words when they improve clarity.",
        severity: "required"
      },
      {
        id: "vary-sentence-openings",
        label: "Vary sentence openings",
        instruction: "Avoid stacking many sentences that start with I. Mix noun-led and time-led openings while staying clear and active.",
        severity: "preferred"
      },
      {
        id: "soft-close-no-service-pitch",
        label: "Soft close, no service pitch",
        instruction: "Close in full polite sentences: 'My CV is attached. I would look forward to hearing back from you and learning more about the role.' Never bark 'CV is attached.' Never pitch free labor.",
        severity: "required"
      },
      {
        id: "company-truth-not-flattery",
        label: "Company truth, not flattery",
        instruction: "Use company mission or culture to choose proof and tone, not as prose in the letter. Never mirror slogans or worship the brand.",
        severity: "required"
      }
    ],
    modelTiers: [
      {
        id: "cheap-drafts",
        label: "Light",
        bestFor: "Keyword extraction, first-pass summaries, and low-risk rewrite variants.",
        provider: "OpenCode",
        model: "deepseek-v4-flash",
        reasoningEffort: "low",
        envVar: "OPENCODE_GO_URL",
        cost: "low"
      },
      {
        id: "standard-writing",
        label: "Medium",
        bestFor: "Cover letters, outreach, screening answers, and company research synthesis.",
        provider: "OpenAI",
        model: "gpt-5.5",
        reasoningEffort: "medium",
        envVar: "OPENAI_API_KEY",
        cost: "medium"
      },
      {
        id: "final-review",
        label: "High",
        bestFor: "Final application packs, interview stories, claim audit, and important outreach.",
        provider: "OpenAI",
        model: "gpt-5.5",
        reasoningEffort: "high",
        envVar: "OPENAI_API_KEY",
        cost: "high"
      }
    ],
    preferredModelTier: "standard-writing",
    promptMemory: [
      "Outreach shape: interest + plain broad work + 'For example,' dug-in sample + full-sentence close.",
      "Open with 'I am interested in the [role] role'. Do not lead with 'I am applying for'.",
      "Write for HR first. Explain finance work in plain English. No long/short jargon without explanation.",
      "Use deep experience/project writeups for samples. Dig into one part. Do not repeat broad phrases in the sample.",
      "Vary sentence openings. Avoid I-I-I stacks.",
      "Close: My CV is attached. I would look forward to hearing back from you and learning more about the role.",
      "No 'role maps to', no posting paraphrase, no company lecture, no service pitch.",
      "Prioritize roles where agents, automation, product speed, or finance workflows matter."
    ],
    permissions: {
      browser: "manual_only",
      allowLinkedInAutomation: false,
      allowExternalSubmission: false,
      telegramWebhookUrl: "",
      hermesAgentPath: "~/.hermes/hermes-agent"
    }
  },
  hermes: {
    agentPath: "~/.hermes/hermes-agent",
    layerPath: "~/.jobmaxxing/hermes-layer",
    defaultModelTier: "final-review",
    updateCommand: "scripts/hermes_update.sh",
    requiredSkills: ["jobmaxxing-orchestrator"],
    requiredToolsets: ["jobmaxxing-core", "browser", "subagents"],
    enabledConnectors: [
      "hermes",
      "telegram",
      "whatsapp",
      "openai",
      "xai",
      "opencode",
      "cursor",
      "google-drive",
      "google-docs",
      "gmail",
      "google-calendar",
      "google-sheets",
      "google-slides",
      "github",
      "local-documents",
      "apple-mail"
    ]
  },
  connectors: [
    {
      id: "openai",
      label: "OpenAI",
      provider: "OpenAI",
      purpose: "Model provider for Medium and High routes.",
      enabled: true,
      connected: false
    },
    {
      id: "xai",
      label: "Grok",
      provider: "xAI",
      purpose: "Grok model routes via XAI_API_KEY, Hermes xAI OAuth, or Grok Build login.",
      enabled: true,
      connected: false,
      category: "Models",
      capabilities: ["Medium", "High", "review", "Grok"]
    },
    {
      id: "opencode",
      label: "OpenCode Go",
      provider: "OpenCode",
      purpose: "Model provider for the Light route through DeepSeek V4 Flash.",
      enabled: true,
      connected: false
    },
    {
      id: "cursor",
      label: "Cursor",
      provider: "Cursor",
      purpose: "Programmatic local model route when Cursor exposes an agent bridge.",
      enabled: true,
      connected: false
    },
    {
      id: "hermes",
      label: "Agent",
      provider: "Agent",
      purpose: "Local orchestration tool for slash update, review, and workflow coordination.",
      enabled: true,
      connected: false
    },
    {
      id: "telegram",
      label: "Telegram",
      provider: "Telegram",
      purpose: "Chat delivery and alerts.",
      enabled: true,
      connected: false
    },
    {
      id: "whatsapp",
      label: "WhatsApp",
      provider: "WhatsApp",
      purpose: "Local thread intelligence for linked people.",
      enabled: true,
      connected: false,
      category: "Agent tools",
      capabilities: ["messages", "style", "drafts"]
    },
    {
      id: "google-drive",
      label: "Google Drive",
      provider: "Google",
      purpose: "Import resumes, work samples, offer docs, and interview prep docs.",
      enabled: true,
      connected: false
    },
    {
      id: "google-docs",
      label: "Google Docs",
      provider: "Google",
      purpose: "Edit CVs, letters, and notes.",
      enabled: true,
      connected: false
    },
    {
      id: "gmail",
      label: "Gmail",
      provider: "Google",
      purpose: "Recruiting email search and drafts.",
      enabled: true,
      connected: false
    },
    {
      id: "google-calendar",
      label: "Google Calendar",
      provider: "Google",
      purpose: "Interview scheduling and follow-ups.",
      enabled: true,
      connected: false
    },
    {
      id: "google-sheets",
      label: "Google Sheets",
      provider: "Google",
      purpose: "Application trackers and tables.",
      enabled: true,
      connected: false
    },
    {
      id: "google-slides",
      label: "Google Slides",
      provider: "Google",
      purpose: "Portfolio and interview decks.",
      enabled: true,
      connected: false
    },
    {
      id: "microsoft-365",
      label: "Microsoft 365",
      provider: "Microsoft",
      purpose: "Office account route.",
      enabled: false,
      connected: false
    },
    {
      id: "outlook",
      label: "Outlook",
      provider: "Microsoft",
      purpose: "Recruiting email search and drafts.",
      enabled: false,
      connected: false
    },
    {
      id: "onedrive",
      label: "OneDrive",
      provider: "Microsoft",
      purpose: "Resume and proof storage.",
      enabled: false,
      connected: false
    },
    {
      id: "word",
      label: "Word",
      provider: "Microsoft",
      purpose: "DOCX CV and letter edits.",
      enabled: false,
      connected: false
    },
    {
      id: "github",
      label: "GitHub",
      provider: "GitHub",
      purpose: "Proof repositories and project evidence.",
      enabled: true,
      connected: false
    },
    {
      id: "figma",
      label: "Figma",
      provider: "Figma",
      purpose: "Design proof and portfolio assets.",
      enabled: false,
      connected: false
    },
    {
      id: "railway",
      label: "Railway",
      provider: "Railway",
      purpose: "Deployment proof and service URLs.",
      enabled: false,
      connected: false
    },
    {
      id: "hugging-face",
      label: "Hugging Face",
      provider: "Hugging Face",
      purpose: "Models, Spaces, datasets, and papers.",
      enabled: false,
      connected: false
    },
    {
      id: "linear",
      label: "Linear",
      provider: "Linear",
      purpose: "Job-search task tracking.",
      enabled: false,
      connected: false
    },
    {
      id: "notion",
      label: "Notion",
      provider: "Notion",
      purpose: "Notes and application CRM records.",
      enabled: false,
      connected: false
    },
    {
      id: "local-documents",
      label: "Local documents",
      provider: "Local files",
      purpose: "CVs, contracts, writing samples, and proof files stored on this Mac.",
      enabled: true,
      connected: true
    },
    {
      id: "apple-mail",
      label: "Apple Mail",
      provider: "Local mail",
      purpose: "User-approved local evidence search for writing style, contracts, and application history.",
      enabled: true,
      connected: false
    }
  ],
  companies: defaultCompanyProfiles,
  jobs: [],
  events: []
};
