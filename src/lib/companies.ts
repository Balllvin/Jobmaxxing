import type { CompanyProfile, CompanyResearch, CompanyResearchPage, CompanySubmission, JobRecord, JobmaxxingStore } from "./types";
import { normalizeExternalUrl } from "./urls";

export const defaultCompanyProfiles: CompanyProfile[] = [];

export function normalizeCompanies(store: Pick<JobmaxxingStore, "companies" | "jobs">): CompanyProfile[] {
  const companies = store.companies?.length ? structuredClone(store.companies) : structuredClone(defaultCompanyProfiles);
  const index = buildCompanyIndex(companies);
  for (const job of store.jobs) {
    syncCompanyForJobInPlace(companies, index, job);
  }
  return companies;
}

export function syncCompanyForJob(companies: CompanyProfile[], job: JobRecord): CompanyProfile[] {
  const next = structuredClone(companies);
  syncCompanyForJobInPlace(next, buildCompanyIndex(next), job);
  return next;
}

function syncCompanyForJobInPlace(
  companies: CompanyProfile[],
  index: Map<string, number>,
  job: JobRecord
): void {
  const id = companyId(job.company);
  const sourceUrl = normalizeStoredExternalUrl(job.sourceUrl);
  const existingIndex = index.get(id) ?? index.get(job.company.toLowerCase());
  if (existingIndex === undefined) {
    companies.unshift({
      id,
      name: job.company,
      website: sourceUrl,
      linkedInUrl: "",
      category: "Target company",
      size: "Unknown",
      headquarters: "Unknown",
      publicStatus: "Unknown",
      summary: `Company profile created from saved role: ${job.role}.`,
      relationship: "Application target",
      applicationIds: [job.id],
      submittedMaterials: [],
      people: [],
      research: emptyCompanyResearch(job.company, sourceUrl, ""),
      nextActions: uniqueStrings([...companyNextActions(job.company), ...job.nextActions]),
      notes: job.notes
    });
    for (const [key, value] of index.entries()) {
      index.set(key, value + 1);
    }
    index.set(id, 0);
    index.set(job.company.toLowerCase(), 0);
    return;
  }

  const company = companies[existingIndex];
  company.applicationIds = uniqueStrings([...(company.applicationIds ?? []), job.id]);
  company.website = company.website || sourceUrl;
  company.research = company.research ?? emptyCompanyResearch(company.name, company.website, company.linkedInUrl);
  company.research.sourceUrls = uniqueStrings([...(company.research.sourceUrls ?? []), sourceUrl].filter(Boolean));
  company.research.hiringSignals = uniqueStrings([...(company.research.hiringSignals ?? []), ...job.keywords]);
  company.nextActions = uniqueStrings([...(company.nextActions ?? []), ...job.nextActions]);
  companies[existingIndex] = company;
}

function buildCompanyIndex(companies: CompanyProfile[]): Map<string, number> {
  const index = new Map<string, number>();
  companies.forEach((company, position) => {
    index.set(company.id, position);
    index.set(company.name.toLowerCase(), position);
  });
  return index;
}

export function addCompanySubmission(
  companies: CompanyProfile[],
  job: JobRecord,
  material: Omit<CompanySubmission, "id" | "jobId">
): CompanyProfile[] {
  const next = syncCompanyForJob(companies, job);
  const companyIndex = next.findIndex((company) => company.id === companyId(job.company));
  if (companyIndex === -1) return next;
  const id = `${companyId(job.company)}-${job.id}-${slug(material.materialType)}`;
  const submission: CompanySubmission = { id, jobId: job.id, ...material };
  const existing = next[companyIndex].submittedMaterials.findIndex((item) => item.id === id);
  if (existing === -1) {
    next[companyIndex].submittedMaterials.unshift(submission);
  } else {
    next[companyIndex].submittedMaterials[existing] = submission;
  }
  return next;
}

export function prepareCompanyResearch(store: JobmaxxingStore, companyIdValue: string): CompanyProfile {
  const company = store.companies.find((item) => item.id === companyIdValue);
  if (!company) {
    throw new Error(`Company not found: ${companyIdValue}`);
  }
  const jobs = store.jobs.filter((job) => company.applicationIds.includes(job.id));
  const sources = uniqueStrings([company.website, company.linkedInUrl, ...jobs.map((job) => job.sourceUrl)].filter(Boolean));
  return {
    ...company,
    research: {
      status: "Agent research packet ready",
      confidence: sources.length ? 48 : 25,
      websitePages: sources.map((url, index) => researchPage(company.name, url, index)),
      products: company.research.products.length
        ? company.research.products
        : ["Identify products from homepage, docs, pricing, case studies, and careers pages."],
      businessModel: company.research.businessModel || "Unknown until source review.",
      leadership: company.research.leadership,
      hiringSignals: uniqueStrings([...company.research.hiringSignals, ...jobs.flatMap((job) => job.keywords)]),
      risks: company.research.risks.length
        ? company.research.risks
        : ["Do not infer private facts from LinkedIn profiles.", "Cross-check public/private company claims."],
      openQuestions: [
        "What does the company sell and who pays?",
        "Which team owns the role?",
        "Who are likely hiring managers, recruiters, founders, or adjacent employees?",
        "What proof from the user best maps to this company's current work?",
        "What should not be claimed yet?"
      ],
      sourceUrls: sources,
      agentPlan: companyAgentPlan(company.website, company.linkedInUrl)
    },
    nextActions: [
      "Run approved browser research over source URLs.",
      "Add likely hiring people with source links.",
      "Map each application claim to evidence.",
      "Generate company-specific interview questions."
    ]
  };
}

export function companyId(name: string): string {
  return slug(name) || "company";
}

function emptyCompanyResearch(companyName: string, website: string, linkedInUrl: string): CompanyResearch {
  const sources = [website, linkedInUrl].filter(Boolean);
  return {
    status: "Not researched",
    confidence: 0,
    websitePages: sources.map((url, index) => researchPage(companyName, url, index)),
    products: [],
    businessModel: "",
    leadership: [],
    hiringSignals: [],
    risks: [],
    openQuestions: ["What does this company do?", "Who should the user talk to?", "Which proof best maps to their work?"],
    sourceUrls: sources,
    agentPlan: companyAgentPlan(website, linkedInUrl)
  };
}

function researchPage(companyName: string, url: string, index: number): CompanyResearchPage {
  const lower = url.toLowerCase();
  return {
    id: `company-page-${companyId(companyName)}-${index}`,
    title: lower.includes("linkedin.com") ? `${companyName} LinkedIn` : `${companyName} source`,
    url,
    summary: "Queued for agent reading. Paste notes or let an approved browser agent summarize this source."
  };
}

function companyNextActions(name: string): string[] {
  return [
    `Build source map for ${name}.`,
    "Find likely hiring people and save public profile links.",
    "Map saved roles to user evidence.",
    "Prepare company-specific outreach and interview questions."
  ];
}

function companyAgentPlan(website: string, linkedInUrl: string): string[] {
  const sources = [website, linkedInUrl].filter(Boolean);
  return [
    sources.length
      ? `Read saved sources first: ${sources.join(", ")}.`
      : "Find the company homepage, careers page, LinkedIn company page, and reliable public sources.",
    "Summarize products, customers, business model, company stage, leadership, current hiring signals, and any public mission or culture values.",
    "For public companies, collect investor relations, filings, earnings, leadership, products, and risk notes. For private companies, use website, jobs, blogs, press, funding pages, and public people profiles.",
    "On LinkedIn, only inspect visible public/profile pages with user approval. Save names, roles, links, and why they matter; do not message or connect.",
    "Read the relevant company site map: homepage, product, pricing, customers, docs, blog, about, careers, and job pages.",
    "Separate facts from assumptions. Every material application claim must trace to user evidence or company source.",
    "When drafting company-focused writing: open with interest in the role, show 1-2 proof facts, soft-close with CV. Do not restate the company, paraphrase the posting, or pitch free labor.",
    "Produce: company brief, people map, role-fit memo, application claim map, outreach draft, interview question bank, and open research gaps."
  ];
}

function slug(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function uniqueStrings(values: string[]): string[] {
  const seen = new Set<string>();
  return values.filter((value) => {
    const key = value.trim().toLowerCase();
    if (!key || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function normalizeStoredExternalUrl(value: string): string {
  try {
    return normalizeExternalUrl(value);
  } catch {
    return "";
  }
}
