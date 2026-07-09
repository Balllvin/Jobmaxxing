# Writing System

Jobmaxxing writing exists to get interviews, not to sound like a generic AI assistant.

## Amazon-Style Rules

These rules are embedded in the profile and used by `jobmaxxing_audit_text`:

- Keep most sentences under 30 words.
- Use subject-verb-object sentences.
- Replace adjectives with data, scope, constraints, or concrete proof.
- Remove weasel words such as might, could, should, various, several, very, and really.
- Spell out assumptions instead of presenting them as facts.
- Write for the reader's decision.
- Make every strong claim traceable to saved evidence.
- State the ask clearly in the first 1-2 sentences.
- Prefer active voice and the fewest words that keep full meaning.
- Quantify when numbers exist; otherwise use precise past work or mechanisms.

Research references:

- PRFAQ writing culture summary: https://www.theprfaq.com/articles/amazon-writing-culture
- Amazonian writing discussion: https://medium.com/%40apappascs/write-like-an-amazonian-14-tips-for-clear-and-persuasive-communication-e2a11afc7362
- First Principles writing notes: https://www.firstprinciples.ventures/insights/four-tips-to-write-like-amazon

## Anti-Slop Rules

Avoid:

- polished fake arcs
- vague enthusiasm
- patronizing company flattery
- empty fit language such as "the role maps to", "maps to work", "highest-friction", or "real bottleneck"
- unique-fit claims such as "uniquely qualified" or "aligns perfectly"
- generic claims any candidate could make
- over-tailored brand language or slogan mirroring
- begging or over-grateful framing
- inflated keywords without proof
- em-dash-heavy rhythm
- "not only X but also Y"
- phrases such as elevate, unleash, seamless, next-gen, game-changing, cutting-edge, journey, landscape, realm, and testament

## Humble Confidence

Readers only need two answers:

1. Is this person interested in this role?
2. Have they done anything like this, and does it look real?

Good pattern:

1. Interest: "I am interested in the [role] role at [company]."
2. Broad relevant work in plain English: themes and scope. No insider shorthand.
3. Specific sample: start with "For example," then dig into ONE part of ONE project.
4. Soft close in full sentences: "My CV is attached. I would look forward to hearing back from you and learning more about the role."

Write for HR first. Add words when they improve clarity. Do not compress into jargon.
Vary sentence openings. Avoid I-I-I stacks. Do not repeat the same phrase in broad and sample.

Bad pattern:

- "I am applying for..." when interest language is enough
- "The role maps to work I have already done..."
- "Company X invests in Y..." (they already know)
- "The posting asks for A, B, and C..."
- "I can start on one concrete task for your team..."
- "I would focus first on the highest-friction bottleneck..."
- "I share your passion for democratizing finance..."
- Any rewrite that makes the user sound like they worship the brand

Company mission, culture, or goals should guide proof selection and tone.
They should rarely appear as prose in the letter.

Do not invent mission fit. Do not beg. Do not pitch free labor.

Research references:

- AI-generated applications creating generic resume issues: https://www.techradar.com/pro/what-makes-a-cv-stand-out-is-the-personal-touch-you-add-to-it-even-professional-cv-writers-are-warning-not-to-use-ai-to-write-a-resume
- Discussion of AI slop in professional writing: https://www.linkedin.com/posts/liz-fosslien_stop-the-slop-i-review-a-lot-of-writing-activity-7437479510847127552-2rMM
- Discussion of real LinkedIn post voice: https://www.linkedin.com/posts/abidc_just-say-no-to-ai-slop-if-youre-using-activity-7356064388367204354-5mHO

## Learning Loop

The user can save:

- writing they liked
- writing they disliked
- recruiter replies
- interview feedback
- applications that got responses
- applications that went nowhere

Those notes become `promptMemory`. Agents should load `jobmaxxing_style_prompt` before writing important materials.

## Drafting Prompt Contract

Every writing agent should:

1. Identify the reader.
2. Answer only: interested? done similar work?
3. Open with interest in the named role.
4. Select 1-2 relevant saved evidence facts as proof.
5. Use company research to choose proof, not to lecture the company.
6. Draft with direct sentences and humble confidence.
7. Soft close. No service pitch.
8. Audit for slop, mapping talk, posting paraphrase, flattery, and unsupported claims.
9. Return the draft and claim trace.
10. Ask for user approval before external use.

## Evidence And Claim Gates

Jobmaxxing must not use saved evidence as filler. A fact can enter a draft only when its labels, tags, or proof overlap the saved role text. If no saved fact meets that relevance bar, the draft must show `Missing evidence` instead of inventing fit.

Final-ready writing must pass `jobmaxxing_audit_text` or the native Writing audit. A ready audit requires:

- no generic excitement or inflated praise
- no weasel wording
- no long sentence hiding multiple claims
- at least one saved evidence reference
- no unsupported candidate claim

Unsupported claims are candidate claims such as "I have shipped...", "I can...", "strong fit", or "proven track record" when the same sentence does not cite saved evidence. Agents should either cite the saved fact, mark the statement as an assumption, or remove it.

Local documents become writing evidence only after the user imports the file, reviews the summary, and promotes it to evidence. The evidence keeps a `file://` source link so drafts can cite the reviewed proof. Do not cite an imported document as proof before promotion.

## Experience And Project Writeups

CV bullets are not enough for interviews or strong samples. Profile experience stores:

- organization / company
- role and period
- broad overview of the stint
- CV-style bullets
- nested projects with:
  - short summary
  - full detail writeup
  - one specific sample anecdote
  - tools, metrics, tags, and source links

Use strengths for short proof labels. Use experience projects for depth. Drafts and interview prep should pull samples from project detail when available.
