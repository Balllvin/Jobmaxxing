import * as z from "zod/v4";
import { isSafeExternalUrl } from "./urls";

const optionalExternalUrlSchema = z
  .string()
  .optional()
  .refine((value) => value === undefined || value.trim() === "" || isSafeExternalUrl(value), {
    message: "Use a valid http or https URL."
  });

export const stageSchema = z.enum([
  "saved",
  "researching",
  "drafting",
  "ready_to_apply",
  "applied",
  "interviewing",
  "offer",
  "closed"
]);

export const jobInputSchema = z.object({
  company: z.string().min(1),
  role: z.string().min(1),
  sourceUrl: optionalExternalUrlSchema,
  description: z.string().min(1),
  notes: z.string().optional(),
  dateLabel: z.string().optional()
});

export const jobIdSchema = z.object({ jobId: z.string().min(1) });

export const companyIdSchema = z.object({ companyId: z.string().min(1) });

export const patchJobSchema = z.object({
  stage: stageSchema.optional(),
  notes: z.string().optional(),
  dateLabel: z.string().optional(),
  description: z.string().min(1).optional()
});

export const interviewSchema = z.object({
  jobId: z.string().min(1),
  mode: z.enum(["text", "call", "onsite", "panel"]).default("text")
});

export const browserPlanSchema = z.object({
  request: z.string().min(1),
  sourceUrl: optionalExternalUrlSchema
});

export const commandSchema = z.object({
  command: z.string().min(1)
});

export const automationPlanSchema = z.object({
  playbookId: z.string().optional(),
  goal: z.string().optional()
});

export const learningSchema = z.object({
  note: z.string().min(1),
  rating: z.number()
});

const evidenceFactSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
  proof: z.string().min(1),
  tags: z.array(z.string())
});

const experienceProjectSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  summary: z.string(),
  detail: z.string(),
  specificSample: z.string(),
  tools: z.array(z.string()),
  metrics: z.array(z.string()),
  tags: z.array(z.string()),
  sourceUrl: z.string()
});

const experienceEntrySchema = z.object({
  id: z.string().min(1),
  title: z.string().min(1),
  organization: z.string().min(1),
  location: z.string(),
  period: z.string(),
  summary: z.string(),
  bullets: z.array(z.string()),
  projects: z.array(experienceProjectSchema),
  sourceUrl: z.string()
});

const writingRuleSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
  instruction: z.string().min(1),
  severity: z.enum(["required", "preferred"])
});

const modelTierSchema = z.object({
  id: z.string().min(1),
  label: z.string().min(1),
  bestFor: z.string().min(1),
  provider: z.string().min(1),
  model: z.string().min(1),
  envVar: z.string().min(1),
  reasoningEffort: z.enum(["none", "minimal", "low", "medium", "high", "xhigh", "max"]).optional(),
  cost: z.enum(["low", "medium", "high"])
});

export const profileSchema = z.object({
  name: z.string().min(1),
  targetRoles: z.array(z.string()),
  locations: z.array(z.string()),
  compensationGoal: z.string(),
  workAuthorization: z.string(),
  strengths: z.array(evidenceFactSchema),
  experience: z.array(experienceEntrySchema).default([]),
  dealBreakers: z.array(z.string()),
  styleGuide: z.array(z.string()),
  writingRules: z.array(writingRuleSchema).min(1),
  modelTiers: z.array(modelTierSchema).min(1),
  preferredModelTier: z.string().min(1),
  promptMemory: z.array(z.string()),
  permissions: z.object({
    browser: z.enum(["manual_only", "assist_fill", "autonomous_prepare"]),
    allowLinkedInAutomation: z.boolean(),
    allowExternalSubmission: z.boolean(),
    telegramWebhookUrl: z.string(),
    hermesAgentPath: z.string()
  })
});

export const eventSchema = z.object({
  type: z.enum(["research", "draft", "browser_plan", "interview", "tracking", "learning"]),
  actor: z.enum(["user", "codex", "claude", "cursor", "opencode", "grok", "hermes", "system"]),
  summary: z.string().min(1),
  jobId: z.string().min(1),
  approval: z.enum(["not_needed", "proposed", "approved_by_user", "rejected_by_user"]).default("not_needed")
});

export const writingAuditSchema = z.object({
  text: z.string().min(1)
});

export const writingPromptSchema = z.object({
  draft: z.string().optional()
});

export type EventInput = z.infer<typeof eventSchema>;
