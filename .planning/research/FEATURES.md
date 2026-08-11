# Feature Research

**Domain:** Exam-prep/certification-study content authoring (cloud data certs: AWS DEA-C01, GCP PDE, Azure DP-700)
**Researched:** 2026-08-11
**Confidence:** MEDIUM-HIGH (industry item-writing standards are well-documented publicly; CertFly-specific volume/tooling choices are project judgment calls, not externally verified)

## Feature Landscape

### Table Stakes (Users Expect These / Auditors Would Flag Their Absence)

Features/process steps that a "rigorous, defensible" content pipeline must have. Missing these = content is either low-quality (feels like a bad dump) or legally/reputationally risky (looks like a braindump).

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Blueprint-anchored domain/topic taxonomy with published weights** | Official exam guides (AWS DEA-C01, GCP PDE v4.2, Azure DP-700) publish domain % weights; a credible prep product must mirror that structure 1:1 so learners can trust "you're 80% ready" claims. Already the pattern in `content/*.yaml` (`weight_pct`, `order`). | LOW | Already implemented in schema — just needs full domain trees (see `docs/content-plan.md` "guia tem mais itens... completo na hora de escrever"). |
| **Originally-authored questions, never copied/paraphrased from real exam items or leaked dumps** | Vendors (AWS, Google, Microsoft) require every candidate to sign an NDA prohibiting disclosure of actual exam content; "brain dumps" are explicitly forbidden and detected via data forensics, with penalties up to certification revocation for both leakers and users of leaked content. A product built on dumped questions is a legal/reputational liability and also teaches memorization instead of understanding. | LOW (process, not code) | Already stated as policy in `content/aws-dea-c01.yaml` header and `docs/content-plan.md` line 8-12. Must remain a hard rule as volume scales to 50-80 Q/cert. |
| **Scenario-based prompts, not bare definitional recall** | Real cloud certs (AWS DEA-C01 in particular) test applied judgment ("given this constraint, which service?"), not "what does X stand for." Existing seed questions already follow this pattern (see Kinesis/S3-event examples). Recall-only questions are considered a classic item-writing flaw that inflates difficulty artificially or trivializes it. | MEDIUM | Requires SME-level familiarity with each service, not just the exam guide text — the harder part of authoring at scale. |
| **Per-choice explanations for every option (correct AND incorrect)** | Already CertFly's differentiator vs. static dump sites; explaining *why each distractor is wrong* is what turns a quiz into a learning tool and is explicitly called out as core-loop value prop in `docs/product-spec.md` ("recebe explicação didática... por que cada alternativa está certa/errada"). | LOW | Already implemented in schema (`choices[].explanation`). Must be maintained as volume scales — no shortcuts (e.g., no blank/lazy explanations on distractors). |
| **Plausible, homogeneous distractors (no "obviously wrong" filler options)** | Standard psychometric item-writing guidance: distractors must be plausible to someone who hasn't mastered the content, parallel in length/grammar/structure to the correct answer, and independent of each other — otherwise the item just tests test-taking skill, not domain knowledge. | MEDIUM | Requires deliberate distractor design per question (e.g., "a real but wrong-for-this-scenario AWS service," not "AWS Database Migration Service" as a random unrelated pick). Existing examples in `aws-dea-c01.yaml` already do this reasonably well. |
| **Full domain-weight coverage matching the official exam blueprint (all domains, not just top 2)** | This was an explicit product decision already made (`docs/product-spec.md` "MVP passa a cobrir o blueprint oficial completo"). Skipping low-weight domains (e.g., AWS Data Security & Governance 18%) leaves gaps that make the "mastery %" claim dishonest and leaves learners unprepared for a chunk of the real exam. | HIGH | This is the actual scope of the milestone — 50-80 Q/cert across ALL domains, not concentration in 1-2 easy domains. |
| **Minimum question volume per topic to avoid repetition** | Product already defines `MIN_QUESTIONS_SEEN_RATIO = 8/15` gate logic; with too few questions per topic, spaced repetition repeats the same items constantly, breaking the "feels fresh" experience and enabling rote memorization of specific items instead of concept mastery. | MEDIUM | `docs/content-plan.md` estimates ~15 Q/topic minimum; at 50-80 Q/cert across ~4-5 domains and ~11-14 topics, volume must be allocated proportionally to `weight_pct`, not evenly. |
| **Source citation per certification (exam guide version + URL) at the file level** | Already present as a YAML header comment per cert file. This is the traceability that lets you defend "we didn't copy the real exam" — you can point to the public blueprint you used and show original prose everywhere else. | LOW | Already done; must be kept current if AWS/Google/Microsoft revise their guide versions (e.g., DP-203 retirement precedent shows vendors do retire/revise exams). |
| **Content review/QA pass before merging new questions (peer or self-review checklist)** | Standard practice in credentialing: items go through SME review, editorial review, and bias/clarity review before going live — even at small scale, a lightweight version (correctness check, distractor plausibility check, no leading language) catches errors that erode learner trust. | LOW-MEDIUM | Solo-dev context means this can't be a formal committee — but a checklist (see Differentiators below) applied consistently is the pragmatic equivalent. |
| **No leading/trick language, no "all of the above"/"none of the above" filler** | Well-documented item-writing flaw category; trick wording and "all/none of the above" options measure test-savviness rather than domain knowledge and are explicitly flagged as anti-patterns in psychometric guidance (PSI, examSoft, ASC item-writing guides). | LOW | Easy to enforce via a style rule in `docs/content-plan.md` or a lint pass over the YAML. |

### Differentiators (Competitive Advantage vs. Static Dump Sites Like ExamTopics/Whizlabs)

Features that set CertFly's content apart. Not required for "defensible," but valuable given the product's stated differentiation (spaced repetition + genuine understanding vs. static dumps).

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Difficulty tagging per question (e.g., easy/medium/hard or Bloom's-level tag)** | Enables smarter SRS scheduling (surface harder items more/less often based on mastery trajectory) and lets the app calibrate "you're ready" signals more honestly than flat mastery %. Static dump sites don't do this. | MEDIUM | Not in current schema — would need a `difficulty` field added to `content/*.yaml` + loader (`scripts/seed_dev.py`) + motor logic to use it. Pure content-authoring cost is low (SME tags while writing); engineering cost is in wiring it into SRS weighting, which is a separate (deferred) concern. |
| **Task-statement-level traceability (map each question to a specific exam guide task statement, not just domain/topic)** | Official guides (esp. AWS) break domains into numbered task statements (e.g., "4.1 Define authorization/authentication..."). Tagging questions at that granularity gives learners (and the author) an auditable coverage matrix — "domain 4 has 18% weight and X questions across all Y task statements" — which is stronger evidence of blueprint fidelity than domain-level coverage alone. | MEDIUM | Content-authoring overhead only (one more metadata field); very defensible for future marketing claims ("built from the official blueprint, not third-party dumps") and useful QA tool to catch under-covered task statements before shipping a domain. |
| **Explicit distractor rationale categories (e.g., "wrong service," "right service wrong config," "plausible but outdated")** | Makes distractor authoring more rigorous and produces richer explanations automatically — a "right service, wrong region/deployment mode" distractor teaches a different lesson than "totally unrelated service," and tagging the type helps ensure variety across the 3-4 distractors of an item instead of accidentally writing 4 near-duplicates. | LOW-MEDIUM | Authoring discipline, not a schema requirement necessarily — could start as a private authoring note and later become a field if it proves useful for QA. |
| **Cross-domain scenario questions (question genuinely spans 2 topics within a domain)** | Real-world cloud engineering rarely respects the guide's topic boundaries (e.g., "ingest + secure" in one workflow). A modest number of these per domain better simulates real exam difficulty and signals higher content quality than sites that write one narrow fact-recall question per bullet. | MEDIUM | Should be a minority of the bank (e.g., 10-20%), not the default — most items still need to map cleanly to one topic for mastery tracking to mean anything. |
| **Versioned content changelog per certification (what changed when exam guide updates)** | Cloud vendors revise/retire exams (Azure DP-203→DP-700 already happened in this project's history). A lightweight changelog per cert file lets the team react fast when AWS/Google/Microsoft ship a new guide version, and signals rigor to any future audit ("here's proof we track blueprint changes"). | LOW | Could be as simple as a `# CHANGELOG` block in the YAML header or a `docs/content-changelog.md`. |

### Anti-Features (Commonly Tempting, Actually Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| **Scraping/adapting questions from ExamTopics, Whizlabs, or other third-party question banks "just to bootstrap volume faster"** | Fastest way to hit the 50-80 Q/cert target; these banks already have exam-guide-aligned structure. | Third-party dumps are themselves frequently sourced from leaked/braindumped real exam content, which is what vendors' NDAs and anti-fraud detection explicitly target; even "inspired by" paraphrasing of dump questions carries real legal/reputational risk and undermines the product's stated differentiation from exactly these competitors (`docs/product-spec.md` names ExamTopics/Whizlabs as the products CertFly differentiates against). | Author 100% original scenarios from the public exam guide's task statements + the team's own hands-on service knowledge; if unsure whether an idea is "too close" to a remembered dump question, don't write it. |
| **LLM-bulk-generating hundreds of questions with minimal review to hit volume fast** | Tempting given ~525-question long-term target and solo-dev bandwidth constraints; LLMs can draft plausible-looking MC items quickly. | LLM-drafted items frequently have technically-wrong "correct" answers, weak/implausible distractors, or subtly mirror common dump phrasing seen in training data — all invisible without SME review; shipping unreviewed content erodes trust fast in a study app where correctness is the entire product. | Use LLM assistance for drafting only, with mandatory human SME review/edit pass before merge (checklist: technical accuracy verified against current service docs, distractors plausible, no dump-adjacent phrasing, explanation quality checked). |
| **One universal "difficulty curve" applied uniformly regardless of domain weight** | Simpler to implement — same number of easy/medium/hard questions per topic regardless of exam weighting. | Produces a mastery signal that doesn't reflect real exam risk; a 34%-weight domain (AWS domain 1) deserves more depth and volume than an 18%-weight domain, and treating them identically wastes authoring effort on low-yield content. | Allocate question volume and difficulty spread proportional to each domain's official `weight_pct`, as already modeled in the YAML schema. |
| **Full exam-length practice simulations as part of this milestone's content work** | Natural-feeling companion to "50-80 Q/cert" content expansion; some competitors lead with full mock exams. | Explicitly out of MVP scope (`docs/product-spec.md`: "Fora do MVP... Simulado completo estilo prova real"); building simulation logic/UI now is scope creep relative to this milestone's actual goal (content volume + blueprint coverage), and a rushed simulado feature without proper timing/scoring rigor would itself need its own research pass. | Keep this milestone scoped to authoring the question bank; revisit full simulated exams as a separate, later feature once content volume/quality is proven. |
| **Community-submitted or crowdsourced questions to scale volume** | Attractive scaling lever once the app has users — "let power users contribute questions." | Reintroduces exactly the provenance/quality-control risk the whole "authored from official guides, not dumps" discipline exists to prevent; unvetted community content is how dump sites end up polluted with actual leaked exam questions in the first place. | If ever pursued, would need a strict SME review gate before any content ships — treat as a distinct, much-later feature with its own governance model, not a shortcut for this milestone. |

## Feature Dependencies

```
Blueprint-anchored domain/topic taxonomy (already built)
    └──requires──> Full domain trees per cert (content-plan.md gaps: GCP 5.x, AWS 4.x task statements)
                       └──requires──> Task-statement-level traceability (differentiator, optional but cheap to add now)

Scenario-based prompts + plausible distractors
    └──requires──> SME familiarity with each service (author-side skill, not code)
    └──enhances──> Per-choice explanations (richer explanations naturally follow good distractor design)

Difficulty tagging (differentiator)
    └──requires──> Schema change in content/*.yaml + scripts/seed_dev.py loader
    └──enhances──> Existing SRS/mastery motor (future work, not this milestone — tag now, wire in later)

Domain-weight-proportional volume allocation
    └──requires──> Full domain trees defined first (can't allocate proportionally to an incomplete taxonomy)

Original-authorship discipline ──conflicts──> Scraping/adapting third-party dumps (anti-feature)
Human SME review pass ──conflicts──> Bulk LLM-generation without review (anti-feature)
```

### Dependency Notes

- **Full domain trees require finishing the task-statement detail** noted as incomplete in `docs/content-plan.md` (GCP domain 5.x, AWS domain 4.x) — this is a prerequisite blocking-item before volume can be allocated correctly, not a nice-to-have.
- **Domain-weight-proportional allocation requires the full domain tree to exist first** — you can't proportion 50-80 questions across domains whose full topic list isn't yet enumerated.
- **Difficulty tagging is decoupled from the SRS motor for this milestone** — it can be authored now (cheap, one field) even though wiring it into scheduling logic is separate future work; don't block content authoring on motor changes.
- **Task-statement traceability enhances (doesn't require) the existing topic taxonomy** — it's an additive metadata layer for QA/coverage auditing, safe to add incrementally per domain as it's written.
- **Original-authorship discipline directly conflicts with any "borrow structure/wording from third-party banks" shortcut** — this is a hard boundary, not a tradeoff to be balanced against speed.

## MVP Definition

### Launch With (v1 of this content milestone)

Minimum viable for the 50-80 Q/cert / full-blueprint-coverage milestone to be defensible.

- [ ] Complete domain/topic taxonomy for all 3 certs (finish the "not yet detailed" task statements in GCP 5.x and AWS domain 4)
- [ ] 50-80 originally-authored questions per cert, allocated proportionally to each domain's official `weight_pct`
- [ ] Every question: realistic scenario prompt, 4 choices, 1 correct, per-choice explanation (existing schema/style, scaled up)
- [ ] Plausible, homogeneous distractors on every item (no throwaway obviously-wrong options)
- [ ] Minimum ~15 questions per topic to satisfy the existing `MIN_QUESTIONS_SEEN_RATIO = 8/15` gate without excessive repetition
- [ ] Self-review checklist applied per batch before merge (accuracy vs. current service docs, distractor plausibility, no dump-adjacent phrasing, explanation completeness)
- [ ] Source header per cert file kept current (exam guide version + URL), consistent with existing `aws-dea-c01.yaml` pattern

### Add After Validation (v1.x)

- [ ] Difficulty tagging per question — add once content volume is stable, wire into SRS weighting as a follow-up motor change
- [ ] Task-statement-level traceability metadata — add incrementally per domain as a QA/coverage aid
- [ ] Lightweight lint/CI check enforcing style rules (no "all of the above," required explanation fields present, distractor count = 4) directly on `content/*.yaml`

### Future Consideration (v2+)

- [ ] Cross-domain scenario questions (minority mix) — defer until base coverage per domain is solid
- [ ] Content changelog tracking exam guide revisions — worth doing once all 3 certs are at full coverage and the team needs to track vendor updates over time
- [ ] Full exam-length simulated practice tests — explicitly out of scope per `docs/product-spec.md`
- [ ] Community/crowdsourced question contribution — explicitly deferred, would need its own governance design

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Full domain/topic taxonomy completion | HIGH | LOW (research/writing, no code) | P1 |
| 50-80 originally-authored Q/cert, weight-proportional | HIGH | HIGH (content authoring at scale) | P1 |
| Plausible distractors + full explanations | HIGH | MEDIUM (authoring discipline per item) | P1 |
| Self-review checklist before merge | HIGH | LOW | P1 |
| Difficulty tagging | MEDIUM | LOW (schema) / MEDIUM (motor wiring, deferred) | P2 |
| Task-statement traceability metadata | MEDIUM | LOW | P2 |
| Content lint/CI style checks | MEDIUM | LOW-MEDIUM | P2 |
| Cross-domain scenario mix | LOW-MEDIUM | MEDIUM | P3 |
| Content changelog | LOW | LOW | P3 |
| Full simulated exams | HIGH (long-term) | HIGH | Out of scope this milestone |
| Community-submitted questions | MEDIUM (long-term) | HIGH (governance) | Out of scope this milestone |

**Priority key:**
- P1: Must have for this content milestone to be defensible and useful
- P2: Should have, cheap to add alongside P1 authoring work or immediately after
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | ExamTopics / dump-style sites | Whizlabs / Tutorials Dojo (paid question banks) | CertFly's Approach |
|---------|-------------------------------|--------------------------------------------------|---------------------|
| Question sourcing | Frequently traceable to leaked/remembered real exam questions (braindump-adjacent), high legal risk, low trust | Professionally authored but still largely static banks, no spaced repetition, weak explanation depth on many items | 100% originally authored from public official exam guides, explanations on every choice — already the stated differentiator (`docs/product-spec.md`) |
| Blueprint coverage | Uneven — mirrors whatever leaked questions exist, not the guide | Generally full-blueprint but sold as flat question sets, no visible weight-proportional design | Explicit weight-proportional volume allocation tied to `weight_pct` in schema |
| Learning mechanism | None — flashcard-style static list | Basic quiz mode, some have weak "review mode" | Spaced repetition (SM-2) + daily mastery gating — structural mechanic, not cosmetic gamification |
| Explanation quality | Often crowd-comment threads, inconsistent/unverified | Present but variable quality, often terse | Didactic explanation on correct AND incorrect choices, per product core loop |
| Difficulty signal | None | Rare tagging, inconsistent | Planned differentiator (v1.x): explicit difficulty tag feeding SRS weighting |

## Sources

- Item writing guidelines and distractor design: [PSI Item Writing and Exam Assembly in Credentialing](https://www.psiexams.com/knowledge-hub/item-writing-and-exam-assembly-in-credentialing-importance-and-best-practices/), [ExamSoft Best Practices in Constructing Multiple-Choice Exam Items](https://examsoft.com/resources/best-practices-in-constructing-multiple-choice-exam-items/), [PNCB Item Writing Manual](https://www.pncb.org/sites/default/files/resources/PNCB_Item_Writing_Manual.pdf), [ASC 2025 Item Writing Guide](https://assess.com/docs/ASC_Item-Writing-Guide_2025.pdf) — MEDIUM-HIGH confidence, established credentialing-industry standards, cross-corroborated across multiple independent testing organizations.
- Exam dump / braindump risk and vendor NDA enforcement: [CBT Nuggets: The Dangers of Exam Dumps](https://www.cbtnuggets.com/blog/career/career-progression/the-dangers-of-exam-dumps), [Digital Cloud Training: Why You Should Avoid AWS Exam Dumps](https://digitalcloud.training/why-you-should-avoid-aws-exam-dumps/), [AWS Training and Certification Blog: Protecting AWS Certification Value](https://aws.amazon.com/blogs/training-and-certification/protecting-aws-certification-value-through-security-measures) — MEDIUM-HIGH confidence, directly corroborates the legal-risk framing already assumed by this project's own docs.
- Project-internal sources: `.planning/PROJECT.md`, `docs/content-plan.md`, `docs/product-spec.md`, `content/aws-dea-c01.yaml` — HIGH confidence, first-party project state as of 2026-08-11.

---
*Feature research for: exam-prep/certification-study content authoring (cloud data certifications)*
*Researched: 2026-08-11*
